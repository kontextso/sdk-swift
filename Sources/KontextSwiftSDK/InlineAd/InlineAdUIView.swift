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
    /// Presented interstitial view controller.
    private weak var interstitialViewController: UIViewController?

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
}

private extension InlineAdUIView {
    func setupUI() {
        let adWebView = AdWebView(
            updateIframeData: viewModel.ad.webViewData.updateData,
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
