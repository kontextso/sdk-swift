//
//  InlineAdUIView.swift
//  KontextSwiftSDK
//

import Combine
import UIKit
import SwiftUI

public final class InlineAdUIView: UIView {
    private var viewModel: InlineAdViewModel
    private var cancellables: Set<AnyCancellable> = []
    private var heightConstraint: NSLayoutConstraint?
    private var onAdHeightChange: ((CGFloat) -> Void)?

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
        self.setupUI()
        observeChanges()
    }
}

private extension InlineAdUIView {
    func setupUI() {
        let adWebView = InlineAdWebView(
            frame: .zero,
            updateFrameData: viewModel.updateIFrameData,
            onIFrameEvent: { [weak self] event in
                self?.viewModel.send(.didReceiveAdEvent(event))
            }
        )
        addSubview(adWebView)
        self.adWebView = adWebView

        adWebView.translatesAutoresizingMaskIntoConstraints = false

        let heightConstraint = adWebView.heightAnchor.constraint(equalToConstant: viewModel.preferredHeight)
        heightConstraint.priority = .defaultHigh
        self.heightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            adWebView.topAnchor.constraint(equalTo: topAnchor),
            adWebView.leadingAnchor.constraint(equalTo: leadingAnchor),
            adWebView.trailingAnchor.constraint(equalTo: trailingAnchor),
            adWebView.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightConstraint
        ])
    }

    func observeChanges() {
        viewModel.$url
            .first(where: { $0 != nil })
            .sink { [weak self] url in
                guard let url else { return }
                self?.adWebView?.loadAd(from: url)
            }
            .store(in: &cancellables)

        viewModel.$preferredHeight
            .receive(on: RunLoop.main)
            .sink { [weak self] height in
                guard let self else { return }
                self.heightConstraint?.constant = height
                self.viewModel.viewDidFinishSizeUpdate()
            }
            .store(in: &cancellables)
    }
}
