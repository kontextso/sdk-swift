import Foundation

@MainActor
protocol SKStoreProductPresenting: Sendable {
    func present(appStoreId: String) async -> Bool
    func dismiss() async -> Bool
}

struct DefaultSKStoreProductPresenter: SKStoreProductPresenting {
    func present(appStoreId: String) async -> Bool {
        await SKStoreProductManager.shared.present(appStoreId: appStoreId)
    }

    func dismiss() async -> Bool {
        await SKStoreProductManager.shared.dismiss()
    }
}
