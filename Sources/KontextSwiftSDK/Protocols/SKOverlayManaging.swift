import KontextKit

/// SKOverlay anchor position. Type alias to KontextKit's enum so the
/// SDK and KontextKit speak the same vocabulary at the boundary.
typealias SKOverlayPosition = SKOverlayManager.Position

/// Protocol for SKOverlay presentation.
///
/// Allows test injection of mock implementations and decouples the SDK
/// from the concrete `SKOverlayManager` from KontextKit. Two `present`
/// overloads mirror KontextKit's contract: full-SKAN attribution path
/// (when fidelity-1 data is available) and itunesItem-only path
/// (the overlay still displays — KontextKit just skips attribution).
/// Errors propagate so call sites can route them through `ErrorCapture`.
@MainActor
protocol SKOverlayManaging: Sendable {
    /// Presents the overlay with full SKAdNetwork (fidelity-1) attribution.
    /// Returns `true` if the overlay actually displayed.
    func present(skan: Skan, position: SKOverlayPosition, dismissible: Bool) async throws -> Bool

    /// Presents the overlay for the given App Store item ID without SKAN
    /// attribution. Used when only `itunesItem` is available.
    func present(itunesItem: String, position: SKOverlayPosition, dismissible: Bool) async throws -> Bool

    /// Dismisses any currently-presented overlay. Returns `true` if an
    /// overlay was dismissed. Throws on validation errors (no overlay,
    /// no active scene, dismiss-during-present, unsupported iOS).
    func dismiss() async throws -> Bool
}

/// Adapts KontextKit's `SKOverlayManager.shared` to the SDK's typed
/// protocol. KontextKit owns the typed async surface + the `Position`
/// enum; this adapter only translates the `Skan` ↔ dict boundary.
final class KontextKitSKOverlayAdapter: SKOverlayManaging {
    private let underlying: SKOverlayManager

    init(underlying: SKOverlayManager = .shared) {
        self.underlying = underlying
    }

    func present(skan: Skan, position: SKOverlayPosition, dismissible: Bool) async throws -> Bool {
        try await underlying.present(
            skan: skan.toRawDict(),
            position: position,
            dismissible: dismissible
        )
    }

    func present(itunesItem: String, position: SKOverlayPosition, dismissible: Bool) async throws -> Bool {
        try await underlying.present(
            skan: ["itunesItem": itunesItem],
            position: position,
            dismissible: dismissible
        )
    }

    func dismiss() async throws -> Bool {
        try await underlying.dismiss()
    }
}
