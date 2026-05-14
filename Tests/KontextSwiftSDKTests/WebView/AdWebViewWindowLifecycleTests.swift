import Foundation
@testable import KontextSwiftSDK
import Testing
import UIKit

/// Tests for `AdWebView.hasEverHadWindow`, the latch that distinguishes
/// "initial load (never attached)" from "crash-recovery reload (attached
/// then detached)" in the navigation-policy callback.
///
/// Background: v3 sdk-swift cancelled navigations only when the WebView
/// had been in a window and was then removed — see
/// `origin/main:AdWebView.swift:194`. The v4 port initially shipped a
/// stricter check (`window == nil → cancel`) which broke the initial
/// load whenever publishers constructed the view before attaching it
/// (e.g. inside a `UITableViewCell`'s `configure(with:)` before the
/// cell is inserted, or in `viewDidLoad` before `addSubview`). The
/// asynchronous nature of `decidePolicyFor` masked this in the
/// common fast-path, but the fix restores the v3 semantic.
///
/// These tests pin the flag's behavior; the policy-callback logic
/// itself is one branch on this flag and is easier to verify by code
/// inspection than by mocking a `WKNavigationAction`.
@MainActor
struct AdWebViewWindowLifecycleTests {

    private func makeAdWebView() -> AdWebView {
        let config = ResolvedConfig(
            publisherToken: "tok",
            userId: "u",
            conversationId: "c",
            enabledPlacementCodes: ["inlineAd"],
            adServerUrl: URL(string: "http://0.0.0.0:1")!,
            character: nil,
            variantId: nil,
            regulatory: nil,
            userEmail: nil,
            advertisingId: nil,
            vendorId: nil,
            requestTrackingAuthorization: false,
            onEvent: nil,
            onDebugEvent: nil
        )
        let session = Session(config: config)
        let ad = Ad(session: session, messageId: "m1")
        return AdWebView(ad: ad)
    }

    @Test func hasEverHadWindowIsFalseInitially() {
        let adWebView = makeAdWebView()
        #expect(
            adWebView.hasEverHadWindow == false,
            "A fresh AdWebView must allow the initial `load()` even though `webView.window` is still nil at that moment"
        )
    }

    @Test func hasEverHadWindowLatchesOnAttach() {
        let adWebView = makeAdWebView()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(adWebView.webView)

        #expect(
            adWebView.hasEverHadWindow == true,
            "Attaching the WebView to a UIWindow must latch the flag — UIView's didMoveToWindow fires synchronously"
        )
    }

    @Test func hasEverHadWindowStaysTrueAfterDetach() {
        // One-way latch: once the WebView has been in a window, it stays
        // marked. Subsequent detaches must NOT clear the flag; that's
        // exactly the state in which crash-recovery reloads must be
        // cancelled.
        let adWebView = makeAdWebView()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(adWebView.webView)
        #expect(adWebView.hasEverHadWindow == true)

        adWebView.webView.removeFromSuperview()
        #expect(
            adWebView.hasEverHadWindow == true,
            "Flag must not toggle back on detach — it's a one-way latch matching v3's `hasEverHadWindow` semantic"
        )
    }
}
