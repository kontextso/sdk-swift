import UIKit
@testable import KontextSwiftSDK

final class MockURLOpener: URLOpening {
    private var openedURLs: [URL] = []

    func canOpenURL(_ url: URL) -> Bool {
        true
    }
    
    func open(
        _ url: URL,
        options: [UIApplication.OpenExternalURLOptionsKey : Any],
        completionHandler completion: (@MainActor @Sendable (Bool) -> Void)?
    ) {
        openedURLs.append(url)
    }

    func didOpenURL(_ url: URL) -> Bool {
        let result = openedURLs.contains(url)
        return result
    }
}
