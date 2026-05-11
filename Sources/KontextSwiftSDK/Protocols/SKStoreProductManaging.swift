import KontextKit

/// Protocol for SKStoreProduct presentation.
///
/// Allows test injection of mock implementations and decouples the SDK
/// from the concrete `SKStoreProductManager` from KontextKit. Typed in
/// `Skan` rather than `[String: Any]`; the adapter translates to the
/// dict surface KontextKit accepts.
///
/// `dismiss()` is intentionally absent: Apple's `SKStoreProductViewController`
/// self-dismisses on user action, and KontextKit dismisses internally
/// when a new presentation arrives. The SDK has no programmatic-dismiss
/// caller.
@MainActor
protocol SKStoreProductManaging: Sendable {
    /// Presents the product page with full SKAdNetwork attribution.
    /// Returns `true` if the page actually displayed. Throws on
    /// validation/load errors so the SDK can route them through
    /// `ErrorCapture` for observability.
    func present(skan: Skan) async throws -> Bool

    /// Presents the product page for the given App Store item ID without
    /// SKAN attribution. Used as a fallback when no `Skan` is available
    /// but a raw `appStoreId` was supplied (per EXT-232).
    func present(itunesItem: String) async throws -> Bool
}

/// Adapts KontextKit's `SKStoreProductManager.shared` to the SDK's
/// typed protocol. KontextKit owns the typed async surface; this adapter
/// only translates the `Skan` ↔ dict boundary and propagates throws so
/// the call site can report via `session.reportError`.
final class KontextKitSKStoreProductAdapter: SKStoreProductManaging {
    private let underlying: SKStoreProductManager

    init(underlying: SKStoreProductManager = .shared) {
        self.underlying = underlying
    }

    func present(skan: Skan) async throws -> Bool {
        try await underlying.present(skan: skan.toRawDict())
    }

    func present(itunesItem: String) async throws -> Bool {
        try await underlying.present(skan: ["itunesItem": itunesItem])
    }
}
