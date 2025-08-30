import UIKit

extension UIView {
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
}
