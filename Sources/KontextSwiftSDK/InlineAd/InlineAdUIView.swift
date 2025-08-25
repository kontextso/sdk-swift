//
//  InlineAdUIView.swift
//  KontextSwiftSDK
//

import Combine
import UIKit
import SwiftUI

public final class InlineAdUIView: UIView {
    public var onContentSizeChange: (() -> Void)?

    private var viewModel: InlineAdViewModel
    private var cancellables: Set<AnyCancellable> = []

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
        code: String,
        messageId: String,
        otherParams: [String: String]
    ) {
        viewModel = adsProvider.inlineAdViewModel(
            code: code,
            messageId: messageId,
            otherParams: otherParams
        )

        super.init(frame: .zero)
        observeChanges()
    }
}

private extension InlineAdUIView {
    // Call this when the web content/frame size changes
    func updateContentSize(to newSize: CGSize) {
        invalidateIntrinsicContentSize()
        onContentSizeChange?()
    }

    func setupUI(_ url: URL?) {
        guard let url else {
            return
        }

        let adView = InlineAdWebView(
            frame: .zero,
            updateFrameData: viewModel.updateIFrameData,
            iframeEvent: Binding<InlineAdEvent?>(
                get: { self.viewModel.iframeEvent },
                set: { self.viewModel.iframeEvent = $0 }
            )
        )
        adView.loadAd(from: url)
        addSubview(adView)

        adView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            adView.topAnchor.constraint(equalTo: topAnchor),
            adView.leadingAnchor.constraint(equalTo: leadingAnchor),
            adView.trailingAnchor.constraint(equalTo: trailingAnchor),
            adView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func observeChanges() {
        viewModel.$url
            .sink { [weak self] url in
                self?.subviews.forEach { $0.removeFromSuperview() }
                self?.setupUI(url)
            }
            .store(in: &cancellables)
    }
}
