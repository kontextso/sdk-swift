//
//  InlineAdTableViewCell.swift
//  ExampleUIKit
//

import UIKit
import KontextSwiftSDK

final class InlineAdTableViewCell: UITableViewCell {
    private var inlineAdView: InlineAdUIView?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        inlineAdView?.removeFromSuperview()
        inlineAdView = nil
    }

    func configure(with viewModel: InlineAdViewModel) {
        inlineAdView?.removeFromSuperview()

        let inlineAdView = InlineAdUIView(
            adsProvider: viewModel.adsProvider,
            ad: viewModel.ad
        )

        self.inlineAdView = inlineAdView

        contentView.addSubview(inlineAdView)
        inlineAdView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            inlineAdView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            inlineAdView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            inlineAdView.topAnchor.constraint(equalTo: contentView.topAnchor),
            inlineAdView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
}
