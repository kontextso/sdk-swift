import Foundation
@testable import KontextSwiftSDK
import Testing

/// Tests for `AdWebView.canonicalOrigin(of:)`, the helper that normalizes
/// a Swift `URL` into the canonical `scheme://host[:port]` form used by
/// browsers for `event.origin` / `URL.origin`.
///
/// Swift's `URL.absoluteString` is NOT spec-compliant — it preserves the
/// input string verbatim (with trailing slash, path, default port, etc.)
/// — so a strict equality check against `event.origin` breaks under
/// common publisher configurations. These tests pin the normalisation
/// rules to match sdk-js's `new URL(adServerUrl).origin`.
@MainActor
struct AdWebViewCanonicalOriginTests {

    @Test func bareUrl() {
        let url = URL(string: "https://example.com")!
        #expect(AdWebView.canonicalOrigin(of: url) == "https://example.com")
    }

    @Test func trailingSlashStripped() {
        let url = URL(string: "https://example.com/")!
        #expect(AdWebView.canonicalOrigin(of: url) == "https://example.com")
    }

    @Test func pathStripped() {
        let url = URL(string: "https://example.com/api/v1")!
        #expect(AdWebView.canonicalOrigin(of: url) == "https://example.com")
    }

    @Test func queryAndFragmentStripped() {
        let url = URL(string: "https://example.com/path?q=1#frag")!
        #expect(AdWebView.canonicalOrigin(of: url) == "https://example.com")
    }

    @Test func defaultHttpsPortStripped() {
        let url = URL(string: "https://example.com:443")!
        #expect(AdWebView.canonicalOrigin(of: url) == "https://example.com")
    }

    @Test func defaultHttpPortStripped() {
        let url = URL(string: "http://example.com:80")!
        #expect(AdWebView.canonicalOrigin(of: url) == "http://example.com")
    }

    @Test func nonDefaultHttpsPortKept() {
        let url = URL(string: "https://example.com:8443")!
        #expect(AdWebView.canonicalOrigin(of: url) == "https://example.com:8443")
    }

    @Test func nonDefaultHttpPortKept() {
        let url = URL(string: "http://example.com:8080")!
        #expect(AdWebView.canonicalOrigin(of: url) == "http://example.com:8080")
    }

    @Test func devLanIPWithPort() {
        // Mirrors the typical local dev configuration in ExampleSecrets.swift.
        let url = URL(string: "http://192.168.0.10:3002")!
        #expect(AdWebView.canonicalOrigin(of: url) == "http://192.168.0.10:3002")
    }

    @Test func schemeLowercased() {
        let url = URL(string: "HTTPS://example.com")!
        #expect(AdWebView.canonicalOrigin(of: url) == "https://example.com")
    }

    @Test func hostLowercased() {
        let url = URL(string: "https://Example.COM")!
        #expect(AdWebView.canonicalOrigin(of: url) == "https://example.com")
    }

    @Test func productionDefault() {
        // Matches Constants.defaultAdServerUrl — the no-op baseline.
        let url = URL(string: "https://server.megabrain.co")!
        #expect(AdWebView.canonicalOrigin(of: url) == "https://server.megabrain.co")
    }

    @Test func combinedTrailingSlashAndDefaultPort() {
        let url = URL(string: "https://example.com:443/")!
        #expect(AdWebView.canonicalOrigin(of: url) == "https://example.com")
    }

    @Test func fileSchemeFallsBackToAbsoluteString() {
        // No host on file:// URLs — fallback path preserves the input
        // string so callers can detect/log the unusable origin instead
        // of getting a misleading partial normalisation.
        let url = URL(string: "file:///tmp/x")!
        let result = AdWebView.canonicalOrigin(of: url)
        #expect(result == url.absoluteString)
    }
}
