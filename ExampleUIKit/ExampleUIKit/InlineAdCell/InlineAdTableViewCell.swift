//
//  InlineAdTableViewCell.swift
//  ExampleUIKit
//

import UIKit
import KontextSwiftSDK

final class InlineAdTableViewCell: UITableViewCell {
    private var inlineAdView: InlineAdUIView?
    private var configuredAdId: UUID?

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
        // Don't destroy the view here — configure() will clean up if the ad changes.
        // This preserves the OMID session across scroll off/on for the same ad.
    }

    func configure(with viewModel: InlineAdViewModel) {
        // Same ad already displayed — nothing to do.
        if configuredAdId == viewModel.ad.id, inlineAdView != nil {
            return
        }

        // Different ad — tear down previous view.
        inlineAdView?.removeFromSuperview()
        inlineAdView = nil
        configuredAdId = viewModel.ad.id

        let inlineAdView = InlineAdUIView(ad: viewModel.ad)
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
