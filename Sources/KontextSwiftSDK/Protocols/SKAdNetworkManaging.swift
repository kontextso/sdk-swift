import KontextKit

/// Protocol for SKAdNetwork impression lifecycle management.
///
/// Allows test injection of mock implementations and decouples the SDK
/// from the concrete `SKAdNetworkManager` from KontextKit. Typed in
/// `Skan` rather than `[String: Any]`; the adapter translates to the
/// dict surface KontextKit accepts. Errors propagate so call sites can
/// route them through `ErrorCapture` instead of being swallowed.
///
/// Mirrors Apple's SKAdNetwork lifecycle:
/// `init` → `start` → `end` (finalize attribution) → `dispose` (release).
@MainActor
protocol SKAdNetworkManaging: Sendable {
    func initImpression(skan: Skan) async throws
    func startImpression() async throws
    func endImpression() async throws
    func dispose() async throws
}

/// Adapts KontextKit's `SKAdNetworkManager.shared` to the SDK's typed
/// protocol. KontextKit already provides typed async methods; this
/// adapter only translates the Swift `Skan` ↔ dict boundary and
/// discards the `Bool` return from `start`/`end` (the SDK doesn't act
/// on those — failure manifests as a thrown error).
final class KontextKitSKAdNetworkAdapter: SKAdNetworkManaging {
    private let underlying: SKAdNetworkManager

    init(underlying: SKAdNetworkManager = .shared) {
        self.underlying = underlying
    }

    func initImpression(skan: Skan) async throws {
        try await underlying.initImpression(params: skan.toRawDict())
    }

    func startImpression() async throws {
        _ = try await underlying.startImpression()
    }

    func endImpression() async throws {
        _ = try await underlying.endImpression()
    }

    func dispose() async throws {
        try await underlying.dispose()
    }
}

// Referenced only from test mocks; analyze can't see across the test target.
// swiftlint:disable:next unused_declaration
enum SKAdNetworkAdapterError: Error {
    /// Used by mocks in tests to simulate a SKAN init failure.
    case initFailed
}
