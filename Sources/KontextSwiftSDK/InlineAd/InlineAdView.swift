import Combine
import SwiftUI
import WebKit

/// A SwiftUI view that renders an inline ad.
///
/// Can be initialized with either an `Ad` instance directly, or with convenience
/// parameters that create one from a session.
///
/// Reports container viewport dimensions to the iframe every 200ms for
/// ad visibility tracking and layout optimization.
///
/// Usage:
/// ```swift
/// // From an Ad instance
/// let ad = session.createAd("a1", options: AdOptions(theme: "dark"))
/// InlineAdView(ad: ad)
///
/// // Convenience: creates the ad automatically
/// InlineAdView(messageId: "a1", session: session)
/// ```
public struct InlineAdView: View {
    @ObservedObject private var ad: Ad
    @State private var adWebView: AdWebView?
    @State private var containerRect: CGRect = .zero
    @State private var keyboardHeight: CGFloat = 0
    @State private var interstitialURL: IdentifiableURL?

    /// Creates an `InlineAdView` with an existing `Ad` instance.
    public init(ad: Ad) {
        // Equivalent of `self._ad = ObservedObject(wrappedValue: ad)`.
        self.ad = ad
    }

    /// Convenience initializer that creates an `Ad` from a session.
    public init(messageId: String, session: Session, code: String? = nil, theme: String? = nil) {
        let ad = session.createAd(messageId, options: AdOptions(code: code ?? Constants.defaultPlacementCode, theme: theme))
        self.ad = ad
    }

    public var body: some View {
        Group {
            if ad.iframeUrl != nil, !ad.destroyed, let adWebView {
                AdWebViewRepresentable(webView: adWebView.webView)
                    .frame(height: ad.isVisible ? max(ad.height, 0) : 0)
                    .clipped()
                    .background(
                        // The preference-based capture path used to flake on
                        // some iOS versions — `onPreferenceChange` stayed
                        // wedged at the `.zero` default even after layout
                        // settled, leaving the iframe with `containerRect ==
                        // .zero` forever (the iframe's viewability calc
                        // then concluded the ad was off-screen and never
                        // fired `ad.viewed`). Capture explicitly inside the
                        // GeometryReader closure on every layout-affecting
                        // lifecycle event (isVisible flip, height change,
                        // appear) — those are the only moments the rect can
                        // actually change.
                        GeometryReader { geo in
                            let frame = geo.frame(in: .global)
                            let size = geo.size
                            Color.clear
                                .onAppear {
                                    containerRect = frame
                                    ad.session.config.onDebugEvent?(
                                        "InlineAdView: geometry-onAppear",
                                        [
                                            "messageId": ad.messageId,
                                            "size": "\(size.width)x\(size.height)",
                                            "frame": "\(frame.minX),\(frame.minY) \(frame.width)x\(frame.height)",
                                        ]
                                    )
                                }
                                .onChange(of: size) { newSize in
                                    let newFrame = geo.frame(in: .global)
                                    containerRect = newFrame
                                    ad.session.config.onDebugEvent?(
                                        "InlineAdView: geometry-onChange-size",
                                        [
                                            "messageId": ad.messageId,
                                            "size": "\(newSize.width)x\(newSize.height)",
                                            "frame": "\(newFrame.minX),\(newFrame.minY) \(newFrame.width)x\(newFrame.height)",
                                        ]
                                    )
                                }
                        }
                    )
            }
        }
        .onChange(of: ad.iframeUrl) { newUrl in
            if newUrl != nil {
                setupWebViewIfNeeded()
            }
        }
        .onAppear {
            if ad.iframeUrl != nil {
                setupWebViewIfNeeded()
            }
            setupModalCallbacks()
        }
        .onReceive(Timer.publish(every: Constants.dimensionReportIntervalMs / 1000, on: .main, in: .common).autoconnect()) { _ in
            reportDimensions()
        }
        .onReceive(keyboardHeightPublisher) { height in
            keyboardHeight = height
        }
        .fullScreenCover(item: $interstitialURL) { item in
            InterstitialAdView(ad: ad, url: item.url)
        }
        // Note: do NOT destroy the ad in onDisappear — in LazyVStack or
        // when the keyboard appears, SwiftUI fires onDisappear for views
        // that scroll off-screen. The ad is destroyed when Ad.destroy()
        // is called explicitly or when the Ad object is deallocated.
    }

    private func setupModalCallbacks() {
        ad.onRequestModal = { [weak ad] urlString, _ in
            guard ad != nil, let url = URL(string: urlString) else { return }
            interstitialURL = IdentifiableURL(url: url)
        }
        ad.onDismissModal = {
            interstitialURL = nil
        }
    }

    private func setupWebViewIfNeeded() {
        guard adWebView == nil else { return }
        let webView = AdWebView(ad: ad)
        adWebView = webView
        webView.load()
    }

    private func reportDimensions() {
        // Diagnostic: log every tick of the 200ms heartbeat with the
        // current guard state so a non-firing dimensions pipeline (the
        // upstream cause of a missing `ad.viewed` event) is observable
        // via `onDebugEvent` without attaching the Safari Web Inspector.
        guard let adWebView else {
            ad.session.config.onDebugEvent?("InlineAdView: dimensions-skip-no-webview", [
                "messageId": ad.messageId,
            ])
            return
        }
        guard ad.isVisible else {
            ad.session.config.onDebugEvent?("InlineAdView: dimensions-skip-not-visible", [
                "messageId": ad.messageId,
            ])
            return
        }
        guard !ad.destroyed else {
            ad.session.config.onDebugEvent?("InlineAdView: dimensions-skip-destroyed", [
                "messageId": ad.messageId,
            ])
            return
        }

        let screenSize = UIScreen.main.bounds.size
        // `windowSize` reflects the app's UIWindow bounds — different
        // from the physical screen on iPad split-view / Slide Over.
        // SwiftUI doesn't expose the window directly, so we look up
        // the key window via UIApplication and fall back to the screen
        // if there isn't one (unlikely after view appearance).
        let windowSize = Self.activeWindowSize() ?? screenSize
        ad.session.config.onDebugEvent?("InlineAdView: send-dimensions", [
            "messageId": ad.messageId,
            "windowW": windowSize.width,
            "windowH": windowSize.height,
            "containerX": containerRect.minX,
            "containerY": containerRect.minY,
            "containerW": containerRect.width,
            "containerH": containerRect.height,
            "keyboardH": keyboardHeight,
        ])
        adWebView.sendDimensionUpdate(DimensionUpdate(
            windowWidth: windowSize.width,
            windowHeight: windowSize.height,
            screenWidth: screenSize.width,
            screenHeight: screenSize.height,
            containerWidth: containerRect.width,
            containerHeight: containerRect.height,
            containerX: containerRect.minX,
            containerY: containerRect.minY,
            keyboardHeight: keyboardHeight
        ))
    }

    private static func activeWindowSize() -> CGSize? {
        UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })?
            .bounds
            .size
    }

    /// Publisher that emits keyboard height changes.
    private var keyboardHeightPublisher: AnyPublisher<CGFloat, Never> {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { notification -> CGFloat? in
                (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height
            }
        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }
        return willShow.merge(with: willHide)
            .eraseToAnyPublisher()
    }
}

// MARK: - Identifiable URL (for fullScreenCover)

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - UIViewRepresentable

struct AdWebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No-op -- webView is managed by AdWebView
    }
}
