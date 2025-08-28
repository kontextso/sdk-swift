import UIKit

extension UIApplication {
    /// Returns the currently active key window
    var currentKeyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .filter { $0.isKeyWindow }
            .first
    }

    /// Returns the top most presented controller
    var topMostViewController: UIViewController? {
        guard let keyWindow = UIApplication.shared.currentKeyWindow else {
            return nil
        }

        var topController = keyWindow.rootViewController

        while let presentedViewController = topController?.presentedViewController {
            topController = presentedViewController
        }

        return topController
    }

    func presentOverContent(
        _ viewControllerToPresent: UIViewController,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        let presentationController = topMostViewController
        viewControllerToPresent.modalPresentationStyle = .fullScreen
        presentationController?.present(
            viewControllerToPresent,
            animated: animated,
            completion: completion
        )
    }

    func dismissTopMostViewController(
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        let presentationController = topMostViewController
        presentationController?.dismiss(
            animated: animated,
            completion: completion
        )
    }
}
