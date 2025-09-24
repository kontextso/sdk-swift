import OSLog
import StoreKit
import SwiftUI
import UIKit

struct StoreProductView: UIViewControllerRepresentable {
    struct Params: Identifiable {
        var id: Int { appStoreId ?? 0 }
        let appStoreId: Int?
    }

    private let params: Params
    private let isPresented: Binding<Bool>

    init(params: Params, isPresented: Binding<Bool>) {
        self.params = params
        self.isPresented = isPresented
    }

    func makeUIViewController(context: Context) -> StoreProductViewController {
        StoreProductViewController(
            appStoreId: params.appStoreId,
            isPresented: isPresented
        )
    }

    func updateUIViewController(_ uiViewController: StoreProductViewController, context: Context) {
        if isPresented.wrappedValue {
            uiViewController.presentStoreProduct()
        }
    }
}

// MARK: StoreProductViewController
final class StoreProductViewController: UIViewController {
    private let appStoreId: Int?
    private let isPresented: Binding<Bool>
    private var didPresent = false

    init(appStoreId: Int?, isPresented: Binding<Bool>) {
        self.appStoreId = appStoreId
        self.isPresented = isPresented

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func presentStoreProduct() {
        guard !didPresent else {
            return
        }

        let viewController = SKStoreProductViewController()
        viewController.delegate = self

        Task {
            do {
                let parameters = [SKStoreProductParameterITunesItemIdentifier: appStoreId]
                try await viewController.loadProduct(withParameters: parameters)
                present(viewController, animated: true)
                didPresent = true
            } catch {
                os_log(.error, "Failed to open SKStoreProductViewController \(self.appStoreId ?? 0)")
            }
        }
    }
}


// MARK: - SKStoreProductViewControllerDelegate
extension StoreProductViewController: SKStoreProductViewControllerDelegate {
    func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
        viewController.presentingViewController?.dismiss(animated: true, completion: nil)
        isPresented.wrappedValue = false
    }
}
