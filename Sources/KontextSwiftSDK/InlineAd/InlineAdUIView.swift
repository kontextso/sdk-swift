import Combine
import UIKit
import SwiftUI

/// A UIView that displays an inline advertisement using a web view.
public final class InlineAdUIView: UIView {
    private var cancellables: Set<AnyCancellable> = []
    /// The view model that manages the ad data and interactions.
    private var viewModel: InlineAdViewModel
    /// The height constraint for the web view, allowing dynamic resizing.
    private var heightConstraint: NSLayoutConstraint?
    /// The web view that loads and displays the ad content.
    private var adWebView: AdWebView?
    /// Timer that periodically reports ad viewport.
    private var samplingTimer: Timer?
    /// Presented interstitial view controller.
    private weak var interstitialViewController: UIViewController?
    /// Sampling viewport interval in seconds
    private let samplingInterval = 0.2
    /// Events targeted for AdWebView
    private let adWebViewEventsSubject = PassthroughSubject<AdWebViewUpdateEvent, Never>()

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// - Parameters:
    ///   - ad: Advertisement to be displayed.
    public init(ad: Advertisement) {
        viewModel = InlineAdViewModel(ad: ad)
        super.init(frame: .zero)
        observeEvents()
        setupUI()
    }

    deinit {
        stopSampling()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()

        guard window != nil else {
            stopSampling()
            return
        }

        Task { @MainActor [weak self] in
            self?.startSampling()
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        sampleViewport()
    }
}

private extension InlineAdUIView {
    func setupUI() {
        let adWebView = AdWebView(
            updateIframeData: viewModel.ad.webViewData.updateData,
            eventPublisher: adWebViewEventsSubject.eraseToAnyPublisher(),
            onIFrameEvent: { [weak self] event in
                guard let self else {
                    return
                }

                self.viewModel.ad.webViewData.onIFrameEvent(event)

                if case .resizeIframe(let resizeIframeData) = event {
                    self.heightConstraint?.constant = resizeIframeData.height
                }
            }
        )
        addSubview(adWebView)
        self.adWebView = adWebView

        adWebView.translatesAutoresizingMaskIntoConstraints = false

        let heightConstraint = adWebView.heightAnchor.constraint(
            equalToConstant: viewModel.ad.preferredHeight
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

        if let url = viewModel.ad.webViewData.url {
            adWebView.load(URLRequest(url: url))
        }
    }

    func observeEvents() {
        viewModel.ad.webViewData.events
            .sink { [weak self] event in
                guard let self else {
                    return
                }

                switch event {
                case .didRequestInterstitialAd(let params, let mode):
                    self.presentInterstitialAd(params: params, presentationMode: mode)

                case .didFinishInterstitialAd:
                    self.dismissInterstitialAd()
                }
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

// MARK: Viewport sampling
private extension InlineAdUIView {
    func startSampling() {
        stopSampling()

        let samplingTimer = Timer.scheduledTimer(
            withTimeInterval: samplingInterval,
            repeats: true
        ) { [weak self] _ in
            self?.sampleViewport()
        }
        self.samplingTimer = samplingTimer

        RunLoop.main.add(samplingTimer, forMode: .common)

        sampleViewport()
    }

    func stopSampling() {
        samplingTimer?.invalidate()
        samplingTimer = nil
    }

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
            containerY: originInWindow.y
        )

        adWebViewEventsSubject.send(.didPrepareUpdateDimensions(
            UpdateDimensionsIFrameDataDTO(data: data)
        ))
    }
}
