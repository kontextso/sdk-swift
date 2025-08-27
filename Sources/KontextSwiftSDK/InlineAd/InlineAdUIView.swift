//
//  InlineAdUIView.swift
//  KontextSwiftSDK
//

import Combine
import UIKit
import SwiftUI

public enum InlineAdUIViewEvent {
    /// Reports new view height after iframe gets rendered
    case didChangeHeight(CGFloat)
}

public final class InlineAdUIView: UIView {
    private var viewModel: InlineAdViewModel
    private var cancellables: Set<AnyCancellable> = []
    private var heightConstraint: NSLayoutConstraint?
    private var onEvent: ((InlineAdUIViewEvent) -> Void)?

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
        otherParams: [String: String],
        onEvent: ((InlineAdUIViewEvent) -> Void)? = nil
    ) {
        self.onEvent = onEvent
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
    func setupUI(_ url: URL?) {
        guard let url else {
            return
        }

        let adView = InlineAdWebView(
            frame: .zero,
            updateFrameData: viewModel.updateIFrameData,
            onIFrameEvent: { [weak self] event in
                self?.viewModel.send(.didReceiveAdEvent(event))
            }
        )
        adView.loadAd(from: url)
        addSubview(adView)

        translatesAutoresizingMaskIntoConstraints = false
        adView.translatesAutoresizingMaskIntoConstraints = false

        let heightConstraint = adView.heightAnchor.constraint(equalTo: heightAnchor)
        self.heightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            adView.topAnchor.constraint(equalTo: topAnchor),
            adView.leadingAnchor.constraint(equalTo: leadingAnchor),
            adView.trailingAnchor.constraint(equalTo: trailingAnchor),
            heightConstraint
        ])
    }

    func observeChanges() {
        viewModel.$url
            .first(where: { $0 != nil })
            .sink { [weak self] url in
                self?.subviews.forEach { $0.removeFromSuperview() }
                self?.setupUI(url)
            }
            .store(in: &cancellables)

        viewModel.$preferredHeight
            .sink { [weak self] height in
                guard let self else { return }
                self.onEvent?(.didChangeHeight(height))

                Task { @MainActor in
                    self.heightConstraint?.constant = height
                    self.setNeedsUpdateConstraints()
                    self.updateConstraintsIfNeeded()
                    self.setNeedsLayout()
                    self.layoutIfNeeded()
                }
            }
            .store(in: &cancellables)
    }
}
