import Combine
import Foundation
import KontextKit

/// Bid assignment: links a Preload to the assistant message it was assigned to.
private struct AssignedBid {
    let preload: Preload
    let messageId: String
}

/// Core session manager and public API for the Kontext Ads Swift SDK.
///
/// A Session is created once per `KontextAds.createSession()` call and lives for
/// the duration of a single conversation. Publishers interact with Session directly
/// -- it exposes `addMessage()`, `createAd()`, `render()`, `destroy()`,
/// and `sendUserEvent()`.
@MainActor
public final class Session {
    /// Fully-resolved SDK configuration. Identity fields are immutable;
    /// preload-scoped fields can be updated via `updateOptions(_:)`.
    public private(set) var config: ResolvedConfig

    /// Server-assigned session ID, nil until first successful preload.
    public private(set) var sessionId: UUID?

    /// Whether the server has permanently disabled this session.
    public internal(set) var disabled = false

    /// Whether `destroy()` has been called.
    public private(set) var destroyed = false

    /// Preload timeout in ms (may be updated by /init).
    public internal(set) var preloadTimeout: TimeInterval = Constants.defaultPreloadTimeoutMs

    /// Whether `/error` POSTs are enabled for this session. Defaults to
    /// `true`; flipped to `false` only by an explicit `reportErrors:
    /// false` in the `/init` response. Local error logging always runs
    /// regardless — this only gates the network leg. `internal(set)`
    /// for tests; the publisher cannot override the server flag.
    internal private(set) var reportErrors = true

    /// Whether `Session.debug(...)` events are forwarded to `/debug`.
    /// Defaults to `false`; flipped to `true` only by an explicit
    /// `reportDebug: true` in the `/init` response. The publisher's
    /// `onDebugEvent` callback always fires regardless — this only
    /// gates the additional network leg, opted in per-user for
    /// targeted diagnostics.
    internal private(set) var reportDebug = false

    /// Combine publisher for ad lifecycle events.
    ///
    /// Delivers the same events as `onEvent` but as a reactive stream.
    /// Events are delivered on the main thread.
    public var eventPublisher: AnyPublisher<AdEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    private let eventSubject = PassthroughSubject<AdEvent, Never>()

    /// Conversation messages tracked by this session. Read-only from
    /// outside — callers must not mutate the returned array.
    public private(set) var messages: [Message] = []
    private var bids: [AssignedBid] = []
    private var bidUpdateListeners: [UUID: () -> Void] = [:]
    private var userEventSenders: [UUID: (UserEvent) -> Void] = [:]

    /// Collected advertising ID (IDFA), resolved at init.
    private var collectedAdvertisingId: String?

    /// Collected vendor ID (IDFV), resolved at init.
    private var collectedVendorId: String?

    /// At most one preload instance at a time.
    private var preloadInstance: Preload?

    /// Background task running the `/init` request. Held so `destroy()`
    /// can cancel it if the session is torn down before the request
    /// completes. Mirrors sdk-js's `Init.cancel()` via `AbortController`.
    private var initTask: Task<Void, Never>?

    /// Active ad instances keyed by messageId. By convention this is
    /// the assistant message's id — `updateBids()` only ever assigns
    /// bids to the latest assistant message, so an `Ad` created with
    /// any other id will resolve no bid.
    private var ads: [String: Ad] = [:]

    /// Debounced preload Task spawned by `addMessage`. Held so the next
    /// `addMessage` (or `destroy()`) can cancel a pending or in-flight
    /// preload — cancellation propagates through `Task.sleep` and is
    /// checked again before the result is applied.
    /// `internal` access so tests can observe cancellation state — the
    /// public surface stays unchanged.
    internal private(set) var preloadTask: Task<Void, Never>?

    /// Shared dependencies for this session.
    let dependencies: DependencyContainer

    /// Open Measurement manager shared by all ads in this session.
    var omManager: OMManaging { dependencies.omManager }

    init(config: ResolvedConfig, dependencies: DependencyContainer? = nil) {
        self.config = config
        self.dependencies = dependencies ?? .default()

        // Activate OM SDK
        self.omManager.activate()

        // Fire /init in the background -- non-blocking. Held so
        // destroy() can cancel it if the session is torn down before
        // the request completes (mirrors sdk-js's AbortController on Init).
        self.initTask = Task { [weak self] in
            await self?.fireInit()
        }

        // Collect IDFA/IDFV in the background
        Task { [weak self] in
            await self?.collectIFA()
        }
    }

    /// Collects IDFA and IDFV via KontextKit's startup flow.
    ///
    /// Handles ATT authorization (if enabled), iOS 14.5 version check,
    /// zero UUID normalization, and manual ID overrides — all in KontextKit.
    private func collectIFA() async {
        guard config.requestTrackingAuthorization else {
            // Skip ATT but still resolve IDs
            let ids = AdvertisingIdProvider.resolveIds(
                manualAdvertisingId: config.advertisingId,
                manualVendorId: config.vendorId
            )
            collectedAdvertisingId = ids.advertisingId
            collectedVendorId = ids.vendorId
            return
        }

        let ids = await TrackingAuthorizationManager.shared.runStartupFlow(
            manualAdvertisingId: config.advertisingId,
            manualVendorId: config.vendorId
        )
        // The ATT prompt can take many seconds; if `destroy()` ran
        // during the await, don't write to a dying session. Same race
        // shape as `fireInit`'s post-await guard.
        if destroyed { return }
        collectedAdvertisingId = ids.advertisingId
        collectedVendorId = ids.vendorId

        debug("ifa-collected", [
            "advertisingId": collectedAdvertisingId as Any,
            "vendorId": collectedVendorId as Any,
        ])
    }

    // MARK: - Public API

    /// Adds a message to the conversation.
    ///
    /// Fire-and-forget: synchronous return. For user messages, a debounced
    /// preload is fired in the background; its outcome is delivered via the
    /// `onEvent` callback (`.filled`, `.noFill`, `.error`, etc.) — not via
    /// a return value. Mirrors sdk-js's `addMessage(): void`.
    ///
    /// Preloads are debounced by 10ms — rapid consecutive calls (e.g. loading
    /// conversation history in a loop) coalesce into a single preload request.
    ///
    /// - Parameters:
    ///   - message: The message to add.
    ///   - options: Optional per-call configuration. When `trackOnly` is true,
    ///     the preload is still sent for analytics but bids are not processed.
    public func addMessage(_ message: Message, options: AddMessageOptions? = nil) {
        guard !destroyed else {
            // sdk-js throws here; we keep the silent return so a
            // misuse during teardown can't crash the publisher's app.
            // assertionFailure traps in DEBUG so the bug is loud
            // during development, no-op in release builds.
            assertionFailure("addMessage called after Session.destroy()")
            debug("addMessage-after-destroy")
            return
        }
        messages.append(message)
        // When the message-history cap is hit, sweep preloads tied to dropped
        // messages. Otherwise we leak preload + bid + SKAN payload memory across
        // long conversations.
        if messages.count > Constants.maxMessages {
            let dropCount = messages.count - Constants.maxMessages
            let droppedIds = messages.prefix(dropCount).map { $0.id }
            messages = Array(messages.suffix(Constants.maxMessages))
            for id in droppedIds {
                removePreload(id)
            }
        }
        debug("message-added", message)
        updateBids()

        // Only user messages reset the debounce. Assistant messages
        // arriving mid-flight must let the in-flight preload land so
        // `applyPreloadResult` → `updateBids` can assign the bid to
        // them. Mirrors sdk-js's `if (role !== 'user') return` placed
        // before `cancelPendingPreload()`.
        guard message.role == .user else { return }

        preloadTask?.cancel()

        if disabled {
            debug("addMessage-disabled")
            return
        }

        let trackOnly = options?.trackOnly ?? false

        // Snapshot the messages now so the preload always ends with
        // this user message, even if assistant messages arrive during
        // the debounce window — sdk-js parity.
        let messagesSnapshot = messages

        // Fire the debounced preload in the background — the result is
        // delivered via onEvent inside applyPreloadResult.
        preloadTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(Constants.addMessageDebounceMs) * 1_000_000)
            } catch {
                return  // cancelled during debounce window
            }
            guard let self, !self.destroyed else { return }

            let preload = self.startPreload(messages: messagesSnapshot)
            let result = await preload.requestAd(params: self.preloadParams(trackOnly: trackOnly))

            // `requestAd` is non-throwing, so cancellation during the
            // network call has to be checked explicitly here.
            if Task.isCancelled { return }
            self.applyPreloadResult(result, trackOnly: trackOnly)
        }
    }

    /// Live-update preload-scoped configuration on this session.
    ///
    /// The accepted fields (`variantId`, `regulatory`, `userEmail`,
    /// `advertisingId`, `vendorId`) are read from `config` at /preload
    /// request time, so the mutation takes effect on the next preload —
    /// no session recreation needed.
    ///
    /// Only non-nil fields are applied; fields left as `nil` are
    /// **not changed**. To clear a field, recreate the session.
    ///
    /// Auth-/server-identity fields and `character` are intentionally
    /// not accepted: auth changes mid-session would desync the /init
    /// registration, and switching `character` would leave the
    /// accumulated message history targeted at the wrong persona.
    /// Recreate the session for those.
    public func updateOptions(_ partial: MutablePublisherOptions) {
        guard !destroyed else {
            assertionFailure("updateOptions called after Session.destroy()")
            debug("updateOptions-after-destroy")
            return
        }
        if let v = partial.variantId { config.variantId = v }
        if let v = partial.regulatory { config.regulatory = v }
        if let v = partial.userEmail { config.userEmail = v }
        if let v = partial.advertisingId { config.advertisingId = v }
        if let v = partial.vendorId { config.vendorId = v }
        debug("options-updated", [
            "variantId": partial.variantId as Any,
            "regulatory": partial.regulatory as Any,
            "userEmail": partial.userEmail as Any,
            "advertisingId": partial.advertisingId as Any,
            "vendorId": partial.vendorId as Any,
        ])
    }

    // `destroyed`, `disabled`, `messages` are exposed directly via
    // `public private(set)` / `public internal(set)` on the storage
    // declarations above — Swift API Design Guidelines reserve methods
    // for actions, properties for state. Read them as
    // `session.destroyed`, `session.disabled`, `session.messages`.

    /// Creates an ad instance for the given message, or returns the
    /// existing one if an ad for the same `messageId` + `code` already
    /// exists. Idempotent — calling `createAd` repeatedly with the same
    /// arguments returns the same `Ad`.
    ///
    /// Options on subsequent calls (theme, etc.) are ignored — destroy
    /// the existing ad first to change them. Mirrors sdk-js's
    /// `Session.createAd`.
    ///
    /// The returned `Ad` should be rendered using `InlineAdUIView(ad:)`.
    public func createAd(_ messageId: String, options: AdOptions? = nil) -> Ad {
        // Unlike the other public mutators, `createAd` doesn't trap
        // here: `Ad.init` calls `session.subscribeBidUpdates(...)`,
        // which already traps in DEBUG when `destroyed` is true. Adding
        // an assertion here would just fire twice. Emit a debug event
        // so misuse is observable in release.
        if destroyed {
            debug("createAd-after-destroy", ["messageId": messageId])
        }
        let code = options?.code ?? Constants.defaultPlacementCode
        let key = adKey(messageId: messageId, code: code)

        if let existing = ads[key] {
            debug("createAd-returning-existing", ["messageId": messageId, "code": code])
            return existing
        }

        let ad = Ad(session: self, messageId: messageId, options: options)
        ads[key] = ad
        return ad
    }

    /// Destroys all active ads, cancels preloads, and cleans up resources.
    ///
    /// Idempotent: subsequent calls are no-ops. After destroy, public
    /// mutators (`addMessage`, `updateOptions`, `sendUserEvent`) emit a
    /// debug event and return without effect.
    public func destroy() {
        guard !destroyed else { return }
        destroyed = true

        // Order mirrors sdk-js: debounce → /init HTTP → /preload HTTP.
        preloadTask?.cancel()
        preloadTask = nil

        initTask?.cancel()
        initTask = nil

        preloadInstance?.cancel()
        preloadInstance = nil

        for (_, ad) in ads {
            ad.destroy()
        }
        ads.removeAll()
        bids.removeAll()
        messages.removeAll()
        userEventSenders.removeAll()
        bidUpdateListeners.removeAll()

        debug("destroyed")
    }

    /// Sends a user event from the publisher app into mounted ad iframes
    /// matching the given placement code. The code is embedded on the
    /// wire message; iframes whose configured code differs ignore the
    /// event (mirrors sdk-js's filter).
    ///
    /// - Parameters:
    ///   - name: Strongly-typed event identifier.
    ///   - payload: Free-form JSON-shaped payload.
    ///   - code: Target placement. Defaults to
    ///     `Constants.defaultPlacementCode` (`inlineAd`).
    public func sendUserEvent(
        _ name: UserEventName,
        payload: [String: Any]? = nil,
        code: String = Constants.defaultPlacementCode
    ) {
        guard !destroyed else {
            assertionFailure("sendUserEvent called after Session.destroy()")
            debug("sendUserEvent-after-destroy")
            return
        }
        let event = UserEvent(name: name, payload: payload, code: code)
        debug("send-user-event", [
            "name": name.rawValue,
            "code": code,
            "payload": payload as Any,
            "receivers": userEventSenders.count,
        ])
        for (_, sender) in userEventSenders {
            sender(event)
        }
    }

    // MARK: - Internal API (used by Ad and AdWebView)

    /// Returns the Preload assigned to the given message id, or nil if
    /// none has been assigned. Idiomatic Swift naming for sdk-js's
    /// `Session.getPreload`.
    func preload(messageId: String) -> Preload? {
        bids.first(where: { $0.messageId == messageId })?.preload
    }

    /// Returns the bid for the given message id + placement code, or
    /// nil if no such bid is tracked. Idiomatic Swift naming for
    /// sdk-js's `Session.getBid(messageId, code)`.
    func bid(messageId: String, code: String) -> Bid? {
        preload(messageId: messageId)?.bid(for: code)
    }

    /// Subscribes to bid-assignment notifications. The callback fires
    /// from `updateBids()` whenever a new bid is assigned to the latest
    /// assistant message — i.e., whenever an `Ad` should re-check
    /// whether its `messageId` now has a bid. Mirrors sdk-js's
    /// `Session.subscribeBidUpdates`.
    ///
    /// Callbacks run on the main actor (Session is `@MainActor`).
    /// Listeners are dropped wholesale by `destroy()`; the returned
    /// closure is the only way to unsubscribe earlier.
    ///
    /// Calling after `destroy()` is a misuse: there's no way for the
    /// notification to fire (no further preloads happen) and the
    /// registration would never be cleared. Traps in DEBUG to surface
    /// the bug; silent no-op in release.
    func subscribeBidUpdates(_ callback: @escaping () -> Void) -> () -> Void {
        guard !destroyed else {
            assertionFailure("subscribeBidUpdates called after Session.destroy()")
            debug("subscribeBidUpdates-after-destroy")
            return {}
        }
        let id = UUID()
        bidUpdateListeners[id] = callback
        return { [weak self] in
            self?.bidUpdateListeners.removeValue(forKey: id)
        }
    }

    /// Removes an ad from the session's tracking map. Called by `Ad.destroy()`.
    /// `code` is required because `ads` is keyed by `messageId:code`
    /// composite — multiple placements per message coexist.
    func removeAd(messageId: String, code: String) {
        ads.removeValue(forKey: adKey(messageId: messageId, code: code))
    }

    /// Cancels and removes the Preload assigned to `messageId`, but
    /// only if no ads still reference it. Mirrors sdk-js's
    /// `Session.removePreload`.
    ///
    /// The "still referenced?" guard matters in multi-placement
    /// scenarios: one message can carry an `inlineAd` and a `sidebar`
    /// concurrently, both sharing one preload. Destroying the inline
    /// ad must not yank the bid out from under the sidebar.
    ///
    /// Order requirement: callers must run `removeAd` *before*
    /// `removePreload` so the ads-map check sees the post-removal state.
    func removePreload(_ messageId: String) {
        let stillReferenced = ads.keys.contains { $0.hasPrefix("\(messageId):") }
        if stillReferenced {
            debug("removePreload-skip-still-referenced", ["messageId": messageId])
            return
        }

        if let preload = preload(messageId: messageId) {
            preload.cancel()
            if preloadInstance === preload {
                preloadInstance = nil
            }
        }
        bids.removeAll(where: { $0.messageId == messageId })
    }

    /// Registers a sender function for delivering user-event messages
    /// to one mounted ad iframe. Returns an unregister function.
    /// Called by `AdWebView.init`; the returned closure is invoked
    /// from `AdWebView.deinit` to drop the registration. Mirrors
    /// sdk-js's `Session.registerUserEventSender`.
    ///
    /// Senders are dropped wholesale by `destroy()`; the returned
    /// closure is the only way to unregister earlier.
    ///
    /// Calling after `destroy()` is a misuse: `sendUserEvent` itself
    /// no-ops post-destroy, so the registration would never be reached.
    /// Traps in DEBUG; silent no-op in release.
    func registerUserEventSender(_ sender: @escaping (UserEvent) -> Void) -> () -> Void {
        guard !destroyed else {
            assertionFailure("registerUserEventSender called after Session.destroy()")
            debug("registerUserEventSender-after-destroy")
            return {}
        }
        let id = UUID()
        userEventSenders[id] = sender
        return { [weak self] in
            self?.userEventSenders.removeValue(forKey: id)
        }
    }

    /// Emits an ad event to both the publisher's callback and the
    /// Combine publisher. Called from `Ad` to surface lifecycle events
    /// (height, viewed, clicked, render-started, etc.) and from
    /// `applyPreloadResult` for filled/error events.
    func emitEvent(_ event: AdEvent) {
        config.onEvent?(event)
        eventSubject.send(event)
    }

    /// Reports an error to the ad server for monitoring.
    /// Fire-and-forget — never throws or disrupts the SDK.
    ///
    /// Pass `bidId` when the failing operation is associated with a
    /// resolved bid (e.g. SKAN / OM lifecycle errors inside `Ad`); it's
    /// stored on the server's error log for cross-referencing. Encoded
    /// to lowercase string at this boundary so server-side log readers
    /// see a consistent canonical form across SDKs (sdk-js / sdk-kotlin
    /// also send lowercase via UUID's natural representation).
    func reportError(_ error: Error, source: String? = nil, bidId: UUID? = nil) {
        ErrorCapture.capture(error, source: source, context: ErrorContext(
            adServerUrl: config.adServerUrl,
            publisherToken: config.publisherToken,
            conversationId: config.conversationId,
            userId: config.userId,
            bidId: bidId?.uuidString.lowercased()
        ), reportEnabled: reportErrors)
    }

    // MARK: - Private

    /// Composite key for the `ads` dictionary. Lifted into a helper so
    /// the wire shape lives in one place.
    private func adKey(messageId: String, code: String) -> String {
        "\(messageId):\(code)"
    }

    /// Fires the /init request and applies the result.
    private func fireInit() async {
        let result = await Init.fetch(config: config)
        // Race: Init.fetch can resolve just before destroy() cancels
        // initTask. Without this guard, a destroyed session would set
        // `disabled`, emit `.error` to onEvent + Combine, and write
        // preloadTimeout. Mirrors sdk-js's `if (this.destroyed) return`.
        if destroyed { return }
        guard let result = result else { return }
        applyInitResult(result)
    }

    /// Applies an `/init` response to the session — disables on
    /// `enabled: false`, updates `preloadTimeout`, and propagates the
    /// `reportErrors` / `reportDebug` toggles. Split out of
    /// `fireInit` so tests can drive each branch without a real HTTP
    /// round-trip.
    internal func applyInitResult(_ result: InitResponseDTO) {
        if !result.enabled {
            disabled = true
            emitEvent(.error(.init(message: "Session is disabled", errCode: "session_disabled_by_init")))
            config.onDebugEvent?("Init: disabled", ["reason": "enabled=false"])
            return
        }

        if let timeout = result.preloadTimeout, timeout > 0 {
            preloadTimeout = TimeInterval(timeout)
            config.onDebugEvent?("Init: preload-timeout-updated", ["preloadTimeout": timeout])
        }

        // Apply server-controlled reporting toggles. Both are stable
        // for the session's lifetime — a fresh `/init` (i.e. session
        // recreation) is what flips them, mirroring how `disabled` /
        // `preloadTimeout` are applied.
        reportErrors = result.reportErrors
        reportDebug = result.reportDebug
        config.onDebugEvent?("Init: reporting-applied", [
            "reportErrors": result.reportErrors,
            "reportDebug": result.reportDebug
        ])
    }

    /// Emits a namespaced debug event.
    ///
    /// Local leg (`onDebugEvent`) always fires — that's the publisher's
    /// contract. Network leg (`POST /debug`) only fires when the server
    /// flipped `reportDebug: true` for this user via `/init`, off by
    /// default for privacy.
    private func debug(_ name: String, _ data: Any? = nil) {
        let qualified = "Session: \(name)"
        config.onDebugEvent?(qualified, data)
        guard reportDebug else { return }
        DebugCapture.capture(name: qualified, data: data, context: DebugContext(
            adServerUrl: config.adServerUrl,
            publisherToken: config.publisherToken,
            conversationId: config.conversationId,
            userId: config.userId,
            sessionId: sessionId?.uuidString.lowercased()
        ))
    }

    /// Starts a new preload operation for the given message snapshot.
    /// The snapshot is taken in `addMessage` so the preload always ends
    /// with the user message that triggered it, even if assistant
    /// messages arrive during the debounce window.
    private func startPreload(messages: [Message]) -> Preload {
        // cancel() on a completed preload is a no-op; the debounce
        // callback drops stale results via the `preloadTask`
        // cancellation check. Mirrors sdk-js.
        preloadInstance?.cancel()
        let preload = Preload(messages: messages)
        preloadInstance = preload
        debug("preload-instance-created", preload)
        return preload
    }

    /// Builds a `PreloadParams` snapshot from current session state.
    /// Builds the `PreloadParams` for a `/preload` request.
    /// `internal` (rather than private) so tests can pin the
    /// `trackOnly → isDisabled` mapping that drives the
    /// `Kontextso-Is-Disabled` header on the wire.
    internal func preloadParams(trackOnly: Bool = false) -> PreloadParams {
        PreloadParams(
            config: config,
            sessionId: sessionId,
            timeout: preloadTimeout,
            isDisabled: trackOnly,
            advertisingId: collectedAdvertisingId,
            vendorId: collectedVendorId,
            reportErrors: reportErrors
        )
    }

    /// Applies a PreloadResult to session state.
    ///
    /// trackOnly preloads (sent for analytics only when ads are
    /// suppressed) skip bid processing but still update sessionId if
    /// the server returned one. The server may also reply with an
    /// empty body for trackOnly — in that case `newSessionId` is nil
    /// and we leave the existing sessionId untouched.
    /// `internal` (not `private`) so tests can drive it without a
    /// URLProtocol stub for the whole preload chain.
    func applyPreloadResult(_ result: PreloadResult, trackOnly: Bool = false) {
        switch result {
        case .success(let bids, let newSessionId):
            // Guarded update — trackOnly responses can have a nil
            // sessionId (empty-body case). For non-trackOnly responses
            // the producer always passes non-nil; the guard is
            // defence-in-depth.
            if let newSessionId = newSessionId {
                sessionId = newSessionId
            }

            // When trackOnly, don't process bids -- preload was for analytics only.
            if trackOnly {
                preloadInstance = nil
                debug("preload-track-only-skip-bids")
                return
            }

            // Emit ad.filled per returned bid (mirrors sdk-js / sdk-kotlin
            // behavior — server returns one bid per matched placement code,
            // so the loop fans out to one event per code).
            for bid in bids {
                emitEvent(.filled(.init(bidId: bid.bidId, code: bid.code, revenue: bid.revenue)))
            }

            updateBids()

        case .failure(_, let event, let disableSession):
            if disableSession {
                disabled = true
                // Ensure publisher always sees ad.error when a preload
                // disables the session — matches the init disable path.
                // If the server already sent an explicit event, that
                // fires below instead of this synthesized one.
                if event == nil {
                    emitEvent(.error(.init(
                        message: "Session is disabled",
                        errCode: "session_disabled_by_preload"
                    )))
                }
            }
            if let event = event {
                emitEvent(event)
            }
        }
    }

    /// Tries to assign the latest preload bid to the latest assistant message.
    private func updateBids() {
        // 1) There must be an active preload with at least one bid
        guard let preload = preloadInstance, preload.hasBid else {
            debug("no-bid", ["messages": messages])
            return
        }

        // 2) Only assign to the last assistant message
        guard let lastMessage = messages.last, lastMessage.role == .assistant else {
            debug("no-last-message", ["messages": messages])
            return
        }

        // 3) Don't reassign: this preload is already linked to another
        //    message, or the last message already has a preload assigned.
        //    Identity-based (`===`) — mirrors sdk-js's
        //    `[...this.preloads.values()].includes(this.preloadInstance)`.
        let alreadyAssigned = bids.contains(where: { assignedBid in
            assignedBid.preload === preload || assignedBid.messageId == lastMessage.id
        })
        if alreadyAssigned {
            debug("bid-already-assigned", ["lastMessage": lastMessage])
            return
        }

        // 4) Link this preload to the last assistant message
        bids.append(AssignedBid(preload: preload, messageId: lastMessage.id))
        debug("bid-assigned", ["lastMessage": lastMessage])

        // 5) Notify all subscribers that new bids are available.
        // Snapshot the listeners before iterating: if a listener
        // synchronously calls `subscribeBidUpdates` (or its returned
        // unsubscribe), mutating `bidUpdateListeners` mid-iteration
        // is undefined behavior in Swift. Today's only listener
        // (`Ad.checkBid`) doesn't, but the contract doesn't forbid it.
        for listener in Array(bidUpdateListeners.values) {
            listener()
        }
    }
}
