import Foundation

@MainActor
protocol SKStoreProductPresenting: Sendable {
    func present(skan: Skan) async -> Bool
    func dismiss() async -> Bool
}

struct DefaultSKStoreProductPresenter: SKStoreProductPresenting {
    func present(skan: Skan) async -> Bool {
        await SKStoreProductManager.shared.present(skan: skan)
    }

    func dismiss() async -> Bool {
        await SKStoreProductManager.shared.dismiss()
    }
}
