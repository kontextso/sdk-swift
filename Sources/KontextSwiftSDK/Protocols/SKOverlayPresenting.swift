import Foundation

enum SKOverlayDisplayPosition: Sendable {
    case bottom
    case bottomRaised
}

@MainActor
protocol SKOverlayPresenting: Sendable {
    func present(
        appStoreId: String,
        position: SKOverlayDisplayPosition,
        dismissible: Bool
    ) async -> Bool

    func dismiss() async -> Bool
}

struct DefaultSKOverlayPresenter: SKOverlayPresenting {
    func present(
        appStoreId: String,
        position: SKOverlayDisplayPosition,
        dismissible: Bool
    ) async -> Bool {
        await SKOverlayManager.shared.present(
            appStoreId: appStoreId,
            position: position,
            dismissible: dismissible
        )
    }

    func dismiss() async -> Bool {
        await SKOverlayManager.shared.dismiss()
    }
}
