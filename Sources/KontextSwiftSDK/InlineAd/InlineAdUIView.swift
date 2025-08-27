//
//  InlineAdUIView.swift
//  KontextSwiftSDK
//

import Combine
import UIKit
import SwiftUI

public final class InlineAdUIView: UIView {
    private var viewModel: InlineAdViewModel
    private var heightConstraint: NSLayoutConstraint?

    private var adWebView: InlineAdWebView?

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// - Parameters:
    ///   - adsProvider: The AdsProvider instance that manages the ad content.
    ///   - code: Placement code of the ad to be displayed.
    ///   - messageId: The identifier of the message after which the ad should be displayed.
    ///   - otherParams: Additional parameters to be sent to the ad server, for example theme.
    public init(
        adsProvider: AdsProvider,
        ad: Ad
    ) {
        viewModel = InlineAdViewModel(ad: ad)
        super.init(frame: .zero)
        self.setupUI()
    }
}

private extension InlineAdUIView {
    func setupUI() {
        let shouldLoadAd = viewModel.ad.webView == nil
        let adWebView = InlineAdWebView(
            frame: .zero,
            updateFrameData: viewModel.ad.webViewData.updateData,
            onIFrameEvent: { [weak self] event in
                guard let self else { return }
                guard let webView = self.adWebView else { return }
                self.viewModel.ad.webViewData.onIFrameEvent(webView, event)
                if case .resizeIframe(let resizeIframeData) = event {
                    self.heightConstraint?.constant = resizeIframeData.height
                }
            }
        )
        addSubview(adWebView)
        self.adWebView = adWebView

        adWebView.translatesAutoresizingMaskIntoConstraints = false

        let heightConstraint = adWebView.heightAnchor.constraint(equalToConstant: viewModel.ad.preferredHeight ?? 0)
        heightConstraint.priority = .defaultHigh
        
        self.heightConstraint = heightConstraint

        NSLayoutConstraint.activate([
//            adWebView.heightAnchor.constraint(greaterThanOrEqualToConstant: 20),
            adWebView.topAnchor.constraint(equalTo: topAnchor),
            adWebView.leadingAnchor.constraint(equalTo: leadingAnchor),
            adWebView.trailingAnchor.constraint(equalTo: trailingAnchor),
            adWebView.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightConstraint
        ])

        if shouldLoadAd, let url = viewModel.ad.webViewData.url {
            adWebView.load(URLRequest(url: url))
        }
    }
}
