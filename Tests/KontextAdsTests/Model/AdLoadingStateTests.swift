import Combine
import Foundation
import Testing
@testable import KontextSwiftSDK

struct AdLoadingStateTests {
    @Test
    func webViewDataWithSameUrlAndUpdateDataAreEqual() {
        let url = URL(string: "https://example.com")
        let a = makeWebViewData(url: url)
        let b = makeWebViewData(url: url)
        #expect(a == b)
    }

    @Test
    func webViewDataWithDifferentUrlsAreNotEqual() {
        let a = makeWebViewData(url: URL(string: "https://example.com"))
        let b = makeWebViewData(url: URL(string: "https://other.com"))
        #expect(a != b)
    }

    @Test
    func webViewDataWithDifferentClosuresButSameUrlAreEqual() {
        let url = URL(string: "https://example.com")
        let a = makeWebViewData(url: url, onDispose: { })
        let b = makeWebViewData(url: url, onDispose: { _ = 1 + 1 })
        #expect(a == b)
    }

    @Test
    func webViewDataHashMatchesForEqualInstances() {
        let url = URL(string: "https://example.com")
        let a = makeWebViewData(url: url)
        let b = makeWebViewData(url: url)
        #expect(a.hashValue == b.hashValue)
    }
}

private func makeWebViewData(
    url: URL?,
    onDispose: @Sendable @escaping () -> Void = { }
) -> AdLoadingState.WebViewData {
    AdLoadingState.WebViewData(
        url: url,
        updateData: nil,
        onIFrameEvent: { _ in },
        onOMEvent: { _ in },
        onDispose: onDispose,
        events: Empty<InlineAdEvent, Never>().eraseToAnyPublisher()
    )
}
