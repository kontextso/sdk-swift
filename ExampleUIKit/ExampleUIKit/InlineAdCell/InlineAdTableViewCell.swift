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
        // IMPORTANT: Do NOT remove inlineAdView or nil out configuredAdId here.
        //
        // UITableView calls prepareForReuse() when a cell scrolls off screen. If we destroy
        // the InlineAdUIView here, the WKWebView inside it is torn down, which ends the OMID
        // ad session. When the same cell scrolls back on screen, configure() would create a
        // brand new InlineAdUIView, starting a duplicate OMID session for the same bid.
        //
        // Instead, configure() is responsible for teardown — it compares configuredAdId to
        // detect whether the ad has actually changed, and only tears down when it has.
        // This preserves the WKWebView and OMID session across scroll off/on for the same ad,
        // ensuring each bid produces exactly one sessionStart/sessionFinish pair.
    }

    func configure(with viewModel: InlineAdViewModel) {
        // Same ad already displayed in this cell — WKWebView and OMID session are intact,
        // nothing to do. This is the common case when scrolling back to an already-loaded ad.
        if configuredAdId == viewModel.ad.id, inlineAdView != nil {
            return
        }

        // Different ad — tear down the previous InlineAdUIView (and its WKWebView + OMID session)
        // before creating a new one for the incoming ad.
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
