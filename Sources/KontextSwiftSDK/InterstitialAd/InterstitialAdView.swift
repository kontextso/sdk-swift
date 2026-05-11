import SwiftUI

/// A full-screen interstitial ad view presented as a modal.
///
/// Renders the ad's modal URL in a WKWebView with a loading spinner.
/// The view fades in once the component iframe signals `initComponent`.
///
/// Usage:
/// ```swift
/// .fullScreenCover(item: $interstitialParams) { params in
///     InterstitialAdView(ad: ad, url: params.url)
/// }
/// ```
public struct InterstitialAdView: View {
    @ObservedObject private var ad: Ad
    @State private var adWebView: AdWebView?
    @State private var showContent = false

    private let url: URL

    /// Creates an interstitial ad view.
    ///
    /// - Parameters:
    ///   - ad: The parent ad instance (used for event handling and OM/SKAN lifecycle).
    ///   - url: The modal iframe URL to load.
    public init(ad: Ad, url: URL) {
        // Equivalent of `self._ad = ObservedObject(wrappedValue: ad)`.
        self.ad = ad
        self.url = url
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            if let adWebView {
                AdWebViewRepresentable(webView: adWebView.webView)
                    .opacity(showContent ? 1 : 0)
                    // Animation explicitly disabled — matches v3 sdk-swift's
                    // OMID-certified behavior. With an opacity animation
                    // enabled, the iframe sits at <100% opacity during the
                    // fade in/out, which OMID's geometry observer reads as
                    // "not fully visible" and can break the IAB
                    // `percentageInView: 100` compliance test. Also avoids
                    // doubling up with UIKit's `dismiss(animated: true)`
                    // when the host wraps this view in a UIHostingController.
                    .animation(.none, value: showContent)
            }

            if !showContent {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
        .onAppear {
            setupWebView()
        }
        .onChange(of: ad.modalUrl) { newUrl in
            // Modal was closed externally
            if newUrl == nil {
                showContent = false
            }
        }
    }

    private func setupWebView() {
        guard adWebView == nil else { return }
        let webView = AdWebView(ad: ad, isInterstitial: true)
        webView.onComponentInitialized = {
            showContent = true
        }
        webView.onComponentDone = {
            // OM session for interstitial starts on adDoneComponent
            // (handled by Ad.handleIframeEvent)
        }
        adWebView = webView
        webView.loadURL(url)
    }
}
