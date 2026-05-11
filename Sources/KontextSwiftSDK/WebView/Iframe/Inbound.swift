// CGFloat in ResizeData.height — analyze can't see it.
// swiftlint:disable:next unused_import
import CoreGraphics

/// Internal protocol vocabulary between `AdWebView` (parser) and `Ad`
/// (consumer). Models the iframe → SDK direction of the postMessage
/// protocol defined in `sdk-common/src/iframe-messaging.ts`.
///
/// Convention: every case ends in `Iframe` (matches the wire-protocol
/// names verbatim) and carries a single typed payload struct. Cases
/// without a payload have no associated value.
///
/// The `eventIframe(EventData)` case is the public-API channel: it
/// transports arbitrary `AdEvent`s the ad fires for the publisher's
/// `onEvent` handler. Everything else is SDK-internal lifecycle.
///
/// **Modal vs SKOverlay.** Although `sdk-common`'s `Component` type
/// includes `'modal' | 'skoverlay'`, in actual usage the
/// `*-component-iframe` family is always modal. SKOverlay has its own
/// dedicated message types (`open-skoverlay-iframe`,
/// `close-skoverlay-iframe`) and is modelled as separate IframeEvent
/// cases here.
///
/// **Defensive parsing.** All wire fields are read via dict casts
/// (`as?`); type mismatches return nil and the SDK silently drops the
/// invalid event rather than crashing. Optional enums (`Target`)
/// fall back to a documented default for missing/unknown strings.
///
/// Wire shapes intentionally not modelled here:
/// - `view-iframe` — same data arrives via `event-iframe`'s `ad.viewed`.
/// - `set-styles-iframe` — not used on mobile.
enum IframeEvent {
    case initIframe
    case resizeIframe(ResizeData)
    case showIframe
    case hideIframe
    case eventIframe(EventData)
    case errorIframe
    case clickIframe(ClickData)
    case adDoneIframe(AdDoneData)

    // Modal lifecycle. Component-tagged in the wire protocol but
    // modal-only in practice — see file-level note.
    case openComponentIframe(OpenComponentData)
    case initComponentIframe
    case closeComponentIframe
    case errorComponentIframe(ErrorComponentData)
    case adDoneComponentIframe

    // SKOverlay lifecycle (separate message types from the
    // component-iframe family).
    case openSKOverlayIframe(SKOverlayData)
    case closeSKOverlayIframe

    /// Click destination preference. `.browser` (default) routes to the
    /// system browser; `.inApp` requests `SFSafariViewController` and
    /// falls back to the system browser if it can't be presented.
    enum Target: String {
        case browser
        case inApp = "in-app"

        /// Parses a wire value into a typed `Target`. Missing or unknown
        /// values fall back to `.browser` — matches sdk-js's documented
        /// protocol default.
        static func from(_ raw: Any?) -> Target {
            guard let str = raw as? String else { return .browser }
            return Target(rawValue: str) ?? .browser
        }
    }

    /// Data associated with a `resize-iframe` event.
    struct ResizeData {
        let height: CGFloat

        /// Parses a `resize-iframe`'s `data` dict into `ResizeData`.
        /// Returns nil when the height field is missing or the value
        /// can't be coerced to a number — caller drops the event.
        static func from(dict: [String: Any]) -> ResizeData? {
            let raw = dict["height"]
            let height: CGFloat
            if let val = raw as? CGFloat {
                height = val
            } else if let val = raw as? Double {
                height = CGFloat(val)
            } else if let val = raw as? Int {
                height = CGFloat(val)
            } else {
                return nil
            }
            return ResizeData(height: height)
        }
    }

    /// Data associated with an `event-iframe` event — the iframe-side
    /// envelope for an `AdEvent`. `Ad.handleAdEvent` decodes `name`
    /// against the `AdEvent` cases and emits the typed equivalent to
    /// the publisher's `onEvent` callback.
    struct EventData {
        let name: String
        let payload: [String: Any]?

        /// Parses an `event-iframe`'s `data` dict. Missing/invalid
        /// `name` decays to "" — `Ad.handleAdEvent`'s default switch
        /// case drops unknown names so an empty name is harmless.
        static func from(dict: [String: Any]) -> EventData {
            EventData(
                name: dict["name"] as? String ?? "",
                payload: dict["payload"] as? [String: Any]
            )
        }
    }

    /// Data associated with a `click-iframe` event. Carries the URL +
    /// targeting hints used by the click handler plus the analytics
    /// identifiers (`id`, `content`, `messageId`) for protocol fidelity
    /// — the analytics fields are duplicated by `event-iframe`'s
    /// `ad.clicked` payload, but they're parsed here so future
    /// non-event consumers (or sdk-common alignment audits) don't lose
    /// information at the parse boundary.
    struct ClickData {
        let id: String?
        let content: String?
        let messageId: String?
        let url: String?
        let target: Target
        let fallbackUrl: String?
        let appStoreId: String?

        init(
            id: String? = nil,
            content: String? = nil,
            messageId: String? = nil,
            url: String? = nil,
            target: Target = .browser,
            fallbackUrl: String? = nil,
            appStoreId: String? = nil
        ) {
            self.id = id
            self.content = content
            self.messageId = messageId
            self.url = url
            self.target = target
            self.fallbackUrl = fallbackUrl
            self.appStoreId = appStoreId
        }

        /// Parses a `click-iframe`'s `data` dict. All wire fields cast
        /// via `as?`; missing or wrongly-typed fields decay to nil
        /// (or `.browser` for `target`). Defensive parsing per the
        /// file-level policy — no crash on malformed data.
        static func from(dict: [String: Any]) -> ClickData {
            ClickData(
                id: dict["id"] as? String,
                content: dict["content"] as? String,
                messageId: dict["messageId"] as? String,
                url: dict["url"] as? String,
                target: Target.from(dict["target"]),
                fallbackUrl: dict["fallbackUrl"] as? String,
                appStoreId: dict["appStoreId"] as? String
            )
        }
    }

    /// Data associated with an `ad-done-iframe` event. Same protocol-
    /// fidelity rationale as `ClickData`. `cachedContent` is parsed but
    /// currently unused — v4 sdk-js explicitly defers cached-content
    /// support; sdk-swift mirrors that.
    struct AdDoneData {
        let id: String?
        let content: String?
        let messageId: String?
        let cachedContent: String?

        init(
            id: String? = nil,
            content: String? = nil,
            messageId: String? = nil,
            cachedContent: String? = nil
        ) {
            self.id = id
            self.content = content
            self.messageId = messageId
            self.cachedContent = cachedContent
        }

        /// Parses an `ad-done-iframe`'s `data` dict into a typed struct.
        /// Wire-format fields cast via `as?`; non-string values for any
        /// field decay to nil.
        static func from(dict: [String: Any]) -> AdDoneData {
            AdDoneData(
                id: dict["id"] as? String,
                content: dict["content"] as? String,
                messageId: dict["messageId"] as? String,
                cachedContent: dict["cachedContent"] as? String
            )
        }
    }

    /// Data associated with `error-component-iframe`. Server adds
    /// `{ message, errorType }` on top of the strict sdk-common type
    /// when the modal creative crashes, hits its React error boundary,
    /// or has no bid data — see v4 sdk-js's
    /// `processErrorComponentIframeMessage`. Both fields are optional;
    /// `Ad.handleErrorComponentIframe` falls back to defaults when
    /// missing.
    struct ErrorComponentData {
        let message: String?
        let errorType: String?

        init(message: String? = nil, errorType: String? = nil) {
            self.message = message
            self.errorType = errorType
        }

        /// Parses an `error-component-iframe`'s `data` dict. Both wire
        /// fields cast via `as?`; missing or non-string values decay
        /// to nil so the handler can apply its defaults.
        static func from(dict: [String: Any]) -> ErrorComponentData {
            ErrorComponentData(
                message: dict["message"] as? String,
                errorType: dict["errorType"] as? String
            )
        }
    }

    /// Data associated with `open-component-iframe`. Modal-only; if a
    /// future iframe build sends `component: 'skoverlay'` here it will
    /// be ignored at the dispatch boundary.
    struct OpenComponentData {
        let code: String?
        let timeout: Int
        let brightnessDelta: Double?
        let componentParams: [String: Any]?

        init(
            code: String? = nil,
            timeout: Int = Constants.defaultModalTimeoutMs,
            brightnessDelta: Double? = nil,
            componentParams: [String: Any]? = nil
        ) {
            self.code = code
            self.timeout = timeout > 0 ? timeout : Constants.defaultModalTimeoutMs
            self.brightnessDelta = brightnessDelta
            self.componentParams = componentParams
        }

        /// Parses an `open-component-iframe`'s `data` dict. `timeout`
        /// falls back to `Constants.defaultModalTimeoutMs` when missing
        /// or non-positive (clamping happens in the initializer).
        static func from(dict: [String: Any]) -> OpenComponentData {
            OpenComponentData(
                code: dict["code"] as? String,
                timeout: dict["timeout"] as? Int ?? Constants.defaultModalTimeoutMs,
                brightnessDelta: dict["brightnessDelta"] as? Double,
                componentParams: dict["componentParams"] as? [String: Any]
            )
        }
    }

    /// Data associated with `open-skoverlay-iframe`. SKAN attribution
    /// data is read from the bid (`currentBid.skan`) at the call site,
    /// not from this payload — the ad server doesn't send SKAN on the
    /// wire here.
    struct SKOverlayData {
        let position: String?
        let dismissible: Bool?
        let appStoreId: String?

        init(
            position: String? = nil,
            dismissible: Bool? = nil,
            appStoreId: String? = nil
        ) {
            self.position = position
            self.dismissible = dismissible
            self.appStoreId = appStoreId
        }

        /// Parses an `open-skoverlay-iframe`'s `data` dict into a typed
        /// struct. Wire-format fields cast via `as?`; missing or wrongly-
        /// typed values decay to nil.
        static func from(dict: [String: Any]) -> SKOverlayData {
            SKOverlayData(
                position: dict["position"] as? String,
                dismissible: dict["dismissible"] as? Bool,
                appStoreId: dict["appStoreId"] as? String
            )
        }
    }
}
