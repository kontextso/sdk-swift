import Combine
import UIKit

/// A UIKit view that renders an inline ad for a given message.
///
/// Directly hosts the ad's WKWebView and dynamically adjusts its height
/// based on the ad's reported content size. Works correctly in UITableView,
/// UICollectionView, and UIStackView.
///
/// Usage:
/// ```swift
/// let ad = session.createAd("a1")
/// let adView = InlineAdUIView(ad: ad)
/// stackView.addArrangedSubview(adView)
/// ```
@MainActor
public final class InlineAdUIView: UIView {
    private var adWebView: AdWebView?
    private var heightConstraint: NSLayoutConstraint!
    private var cancellables = Set<AnyCancellable>()
    private let ad: Ad
    private nonisolated(unsafe) var dimensionTimer: Timer?
    private var keyboardHeight: CGFloat = 0
    private weak var interstitialViewController: UIViewController?

    /// Called when the ad height changes. Use this to trigger table/collection
    /// view layout updates (e.g., `tableView.beginUpdates(); tableView.endUpdates()`).
    public var onHeightChange: ((CGFloat) -> Void)?

    /// Creates an `InlineAdUIView` with an existing `Ad` instance.
    public init(ad: Ad) {
        self.ad = ad
        super.init(frame: .zero)
        setup()
    }

    /// Convenience initializer that creates an `Ad` from a session.
    public init(messageId: String, session: Session, code: String? = nil, theme: String? = nil) {
        self.ad = session.createAd(messageId, options: AdOptions(code: code ?? Constants.defaultPlacementCode, theme: theme))
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        clipsToBounds = true
        translatesAutoresizingMaskIntoConstraints = false

        heightConstraint = heightAnchor.constraint(equalToConstant: 0)
        heightConstraint.priority = .defaultHigh // Allow UITableView to override during layout
        heightConstraint.isActive = true

        // Observe iframeUrl to create the web view when a bid is available
        ad.$iframeUrl
            .compactMap { $0 }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.createWebView()
            }
            .store(in: &cancellables)

        // Handle interstitial presentation
        ad.onRequestModal = { [weak self] urlString, _ in
            guard let self, let url = URL(string: urlString) else { return }
            self.presentInterstitialAd(url: url)
        }
        ad.onDismissModal = { [weak self] in
            self?.dismissInterstitialAd()
        }

        // Observe height changes
        ad.$height
            .combineLatest(ad.$isVisible)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] height, isVisible in
                guard let self else { return }
                let newHeight = isVisible ? max(height, 0) : 0
                guard self.heightConstraint.constant != newHeight else { return }
                self.heightConstraint.constant = newHeight
                self.invalidateIntrinsicContentSize()
                self.onHeightChange?(newHeight)
            }
            .store(in: &cancellables)
    }

    private func createWebView() {
        guard adWebView == nil, !ad.destroyed else { return }

        let webView = AdWebView(ad: ad)
        self.adWebView = webView

        let wkWebView = webView.webView
        wkWebView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(wkWebView)
        NSLayoutConstraint.activate([
            wkWebView.topAnchor.constraint(equalTo: topAnchor),
            wkWebView.leadingAnchor.constraint(equalTo: leadingAnchor),
            wkWebView.trailingAnchor.constraint(equalTo: trailingAnchor),
            wkWebView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        webView.load()
    }

    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: heightConstraint.constant)
    }

    public override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow != nil {
            startDimensionTimer()
            registerKeyboardObservers()
        } else {
            stopDimensionTimer()
            unregisterKeyboardObservers()
            // OMID retire+finish must run while the WebView is still
            // attached to a window — otherwise the in-iframe JS
            // verification script polls geometry one more time, sees the
            // detached element, and emits a spurious
            // `geometryChange { reasons: ["notFound"] }` before
            // sessionFinish dispatches. willMove fires BEFORE removal,
            // which gives us that pre-removal hook. Matches the
            // OMID-certified v3 sdk-swift behaviour.
            ad.finishOMSession()
        }
    }

    // MARK: - Dimension Reporting

    private func startDimensionTimer() {
        guard dimensionTimer == nil else { return }
        let timer = Timer(timeInterval: Constants.dimensionReportIntervalMs / 1000, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.reportDimensions()
            }
        }
        // `.common` so the timer keeps firing while UIKit is in `.tracking`
        // (during scroll/pan). `Timer.scheduledTimer` defaults to `.default`
        // only — and `.default` is suspended whenever the run loop enters
        // tracking, which is exactly when the ad is moving on screen and
        // the iframe needs fresh viewport geometry for visibility tracking.
        RunLoop.main.add(timer, forMode: .common)
        dimensionTimer = timer
    }

    private func stopDimensionTimer() {
        dimensionTimer?.invalidate()
        dimensionTimer = nil
    }

    private func reportDimensions() {
        guard let adWebView else { return }
        let screenBounds = UIScreen.main.bounds
        // `windowBounds` differs from `screenBounds` on iPad split-view /
        // Slide Over. Fall back to the screen if the view isn't yet in a
        // window (rare timing window during setup).
        let windowBounds = self.window?.bounds ?? screenBounds
        let containerBounds = self.bounds
        let globalFrame = self.convert(bounds, to: nil)
        adWebView.sendDimensionUpdate(DimensionUpdate(
            windowWidth: windowBounds.width,
            windowHeight: windowBounds.height,
            screenWidth: screenBounds.width,
            screenHeight: screenBounds.height,
            containerWidth: containerBounds.width,
            containerHeight: containerBounds.height,
            containerX: globalFrame.origin.x,
            containerY: globalFrame.origin.y,
            keyboardHeight: keyboardHeight
        ))
    }

    // MARK: - Keyboard Tracking

    private func registerKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    private func unregisterKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            keyboardHeight = frame.height
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        keyboardHeight = 0
    }

    // MARK: - Interstitial Presentation

    private func presentInterstitialAd(url: URL) {
        guard let topVC = topMostViewController else { return }

        let viewController = InterstitialAdViewController(ad: ad, url: url)
        interstitialViewController = viewController
        topVC.present(viewController, animated: true)
    }

    private func dismissInterstitialAd() {
        interstitialViewController?.dismiss(animated: true)
        interstitialViewController = nil
    }

    /// Returns the top-most presented view controller for modal presentation.
    private var topMostViewController: UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }),
              let keyWindow = scene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }

        var topController = keyWindow.rootViewController
        while let presented = topController?.presentedViewController {
            topController = presented
        }
        return topController
    }

    deinit {
        let timer = dimensionTimer
        MainActor.assumeIsolated {
            timer?.invalidate()
            ad.destroy()
        }
    }
}
