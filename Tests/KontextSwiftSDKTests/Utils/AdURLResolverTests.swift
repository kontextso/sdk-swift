import Foundation
@testable import KontextSwiftSDK
import Testing

/// Pure-function URL resolution tests, lifted out of `ClickHandlingTests`
/// when `resolveAdUrl` was extracted from `Ad`. Tests no longer need to
/// construct an `Ad` (and therefore a `Session`) just to exercise URL
/// resolution.
struct AdURLResolverTests {
    private let adServerUrl = URL(string: "https://server.megabrain.co")!

    @Test func preservesHttpsUrls() {
        let resolved = resolveAdUrl("https://example.com/path", adServerUrl: adServerUrl)
        #expect(resolved == "https://example.com/path")
    }

    @Test func preservesHttpUrls() {
        let resolved = resolveAdUrl("http://example.com/page", adServerUrl: adServerUrl)
        #expect(resolved == "http://example.com/page")
    }

    @Test func resolvesServerRelativePaths() {
        let resolved = resolveAdUrl("/redirect/abc123", adServerUrl: adServerUrl)
        #expect(resolved == "https://server.megabrain.co/redirect/abc123")
    }

    @Test func preservesProtocolRelativeUrls() {
        // `//cdn.example.com/foo` resolves against the *iframe's*
        // protocol, not the ad server's. Prepending `adServerUrl` would
        // silently rewrite the host. Must pass through unchanged.
        let resolved = resolveAdUrl("//cdn.example.com/foo.png", adServerUrl: adServerUrl)
        #expect(resolved == "//cdn.example.com/foo.png")
    }

    @Test func preservesCustomSchemeUrls() {
        // Deep links — prepending `https://server` would break app
        // launch via URL scheme.
        #expect(resolveAdUrl("amazon://product/B0123", adServerUrl: adServerUrl) == "amazon://product/B0123")
        #expect(resolveAdUrl("fb://profile/123", adServerUrl: adServerUrl) == "fb://profile/123")
    }
}
