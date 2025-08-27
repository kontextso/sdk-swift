//
//  InlineAdCollectionViewCell.swift
//  ExampleUIKit
//

import KontextSwiftSDK
import UIKit
import SwiftUI

final class InlineAdCollectionViewCell: UICollectionViewCell {
    private var inlineAdView: InlineAdUIView?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        inlineAdView?.removeFromSuperview()
        inlineAdView = nil
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with viewModel: InlineAdViewModel) {
        inlineAdView?.removeFromSuperview()

        let inlineAdView = InlineAdUIView(
            adsProvider: viewModel.adsProvider,
            code: viewModel.code,
            messageId: viewModel.messageId,
            otherParams: viewModel.otherParams
        )

        self.inlineAdView = inlineAdView

        contentView.addSubview(inlineAdView)
        inlineAdView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            inlineAdView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            inlineAdView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            inlineAdView.topAnchor.constraint(equalTo: contentView.topAnchor),
            inlineAdView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }
}
