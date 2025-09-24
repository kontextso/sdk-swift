import UIKit

@MainActor
protocol URLOpening: Sendable {
    func canOpenURL(_ url: URL) -> Bool

    func open(
        _ url: URL,
        options: [UIApplication.OpenExternalURLOptionsKey: Any],
        completionHandler completion: (@MainActor @Sendable (Bool) -> Void)?
    )
}

extension UIApplication: @retroactive Sendable {}
extension UIApplication: URLOpening {}
