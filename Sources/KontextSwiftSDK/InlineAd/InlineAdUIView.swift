import Combine
import OSLog
import StoreKit
import SwiftUI
import UIKit

/// A UIView that displays an inline advertisement using a web view.
public final class InlineAdUIView: UIView {
    private var cancellables: Set<AnyCancellable> = []
    /// The height constraint for the web view, allowing dynamic resizing.
    private var heightConstraint: NSLayoutConstraint?
    /// The web view that loads and displays the ad content.
    private var adWebView: AdWebView?
    /// Timer that periodically reports ad viewport.
    private var samplingTimer: Timer?
    /// Height of the currently visible keyboard, otherwise 0.
    private var keyboardHeight: CGFloat = 0
    /// Presented interstitial view controller.
    private weak var interstitialViewController: UIViewController?
    /// Sampling viewport interval in seconds
    private let samplingInterval = 0.2
    /// Events targeted for AdWebView
    private let adWebViewEventsSubject = PassthroughSubject<AdWebViewUpdateEvent, Never>()
    /// Ad to be displayed
    private let ad: Advertisement

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// - Parameters:
    ///   - ad: Advertisement to be displayed.
    public init(ad: Advertisement) {
        self.ad = ad
        super.init(frame: .zero)
        observeEvents()
        setupUI()
    }

    public override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)

        guard newWindow != nil else {
            stopSampling()
            return
        }

        startSampling()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        sampleViewport()
    }
}

private extension InlineAdUIView {
    func setupUI() {
        let adWebView = AdWebView(
            updateIframeData: ad.webViewData.updateData,
            eventPublisher: adWebViewEventsSubject.eraseToAnyPublisher(),
            onIFrameEvent: { [weak self] event in
                guard let self else {
                    return
                }

                if case .resizeIframe(let resizeIframeData) = event {
                    self.heightConstraint?.constant = resizeIframeData.height
                    self.layoutIfNeeded()
                }

                self.ad.webViewData.onIFrameEvent(event)
            }
        )
        addSubview(adWebView)
        self.adWebView = adWebView

        adWebView.translatesAutoresizingMaskIntoConstraints = false

        let heightConstraint = adWebView.heightAnchor.constraint(
            equalToConstant: ad.preferredHeight
        )
        heightConstraint.priority = .defaultHigh

        self.heightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            adWebView.topAnchor.constraint(equalTo: topAnchor),
            adWebView.leadingAnchor.constraint(equalTo: leadingAnchor),
            adWebView.trailingAnchor.constraint(equalTo: trailingAnchor),
            adWebView.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightConstraint
        ])

        if let url = ad.webViewData.url {
            adWebView.load(URLRequest(url: url))
        }
    }

    func observeEvents() {
        ad.webViewData.events
            .sink { [weak self] event in
                guard let self else {
                    return
                }

                switch event {
                case .didRequestInterstitialAd(let params, let mode):
                    presentInterstitialAd(params: params, presentationMode: mode)

                case .didRequestSKOverlay(let params):
                    presentSKOverlay(params: params)

                case .didRequestStoreProductDisplay(let params):
                    presentAppStoreProduct(params.appStoreId)

                case .didFinishInterstitialAd:
                    dismissInterstitialAd()

                case .didFinishSKOverlay:
                    dismissSKOverlay()
                }
            }
            .store(in: &cancellables)

        Publishers.keyboardHeight
            .sink { [weak self] height in
                self?.keyboardHeight = height
            }
            .store(in: &cancellables)
    }
}

// MARK: Interstitial
private extension InlineAdUIView {
    func presentInterstitialAd(
        params: InterstitialAdView.Params,
        presentationMode: UIModalPresentationStyle
    ) {
        let presentationController = topMostViewController
        let viewController = UIHostingController(
            rootView: InterstitialAdView(params: params)
        )
        interstitialViewController = viewController
        viewController.modalPresentationStyle = presentationMode
        presentationController?.present(viewController, animated: true)
    }

    func dismissInterstitialAd() {
        interstitialViewController?.dismiss(animated: true)
        interstitialViewController = nil
    }
}

// MARK: SKOverlay
private extension InlineAdUIView {
    func presentSKOverlay(params: SKOverlayParams) {
        guard let scene = window?.windowScene else {
            return
        }

        let configuration = SKOverlay.AppConfiguration(
            appIdentifier: params.appStoreId,
            position: params.position
        )
        configuration.userDismissible = params.dismissible

        let overlay = SKOverlay(configuration: configuration)
        overlay.present(in: scene)
    }

    func dismissSKOverlay() {
        guard let scene = window?.windowScene else {
            return
        }

        SKOverlay.dismiss(in: scene)
    }
}

private extension InlineAdUIView {
    func presentAppStoreProduct(_ appStoreId: Int?) {
        let presentationController = topMostViewController
        let viewController = SKStoreProductViewController()
        viewController.delegate = self
        let params = [SKStoreProductParameterITunesItemIdentifier: appStoreId]

        Task {
            do {
                try await viewController.loadProduct(withParameters: params)
                presentationController?.present(viewController, animated: true)
            } catch {
                os_log(.error, "Failed to open SKStoreProductViewController \(appStoreId ?? 0)")
            }
        }
    }
}

// MARK: Viewport sampling
private extension InlineAdUIView {
    func startSampling() {
        guard samplingTimer == nil, superview != nil else {
            return
        }

        stopSampling()

        let samplingTimer = Timer.scheduledTimer(
            withTimeInterval: samplingInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.sampleViewport()
            }
        }
        self.samplingTimer = samplingTimer

        RunLoop.main.add(samplingTimer, forMode: .common)

        sampleViewport()
    }

    func stopSampling() {
        guard samplingTimer != nil else {
            return
        }

        samplingTimer?.invalidate()
        samplingTimer = nil
    }

    @MainActor
    func sampleViewport() {
        guard let window else {
            return
        }

        let screenBounds = window.screen.bounds
        let screenWidth = screenBounds.width
        let screenHeight = screenBounds.height
        let containerWidth = bounds.width
        let containerHeight = bounds.height

        // Convert container origin to window coordinates
        // Using bounds.origin (0,0 in self space) converted from self -> window
        let originInWindow = convert(bounds.origin, to: window)

        let data = UpdateDimensionsIFrameDataDTO.Data(
            screenWidth: screenWidth,
            screenHeight: screenHeight,
            containerWidth: containerWidth,
            containerHeight: containerHeight,
            containerX: originInWindow.x,
            containerY: originInWindow.y,
            keyboardHeight: keyboardHeight
        )

        adWebViewEventsSubject.send(.didPrepareUpdateDimensions(
            UpdateDimensionsIFrameDataDTO(data: data)
        ))
    }
}

// MARK: - SKStoreProductViewControllerDelegate
extension InlineAdUIView: SKStoreProductViewControllerDelegate {
    public func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
        viewController.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
