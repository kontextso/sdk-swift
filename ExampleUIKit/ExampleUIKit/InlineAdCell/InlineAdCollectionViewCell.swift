//
//  InlineAdCollectionViewCell.swift
//  ExampleUIKit
//

import KontextSwiftSDK
import UIKit
import SwiftUI

class InlineAdCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = String(describing: InlineAdCollectionViewCell.self)

    var hostingController: UIHostingController<InlineAdView>?

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    func configureHosting(with viewModel: InlineAdViewModel, inside parent: UIViewController) {
        let view = InlineAdView(
            adsProvider: viewModel.adsProvider,
            code: viewModel.code,
            messageId: viewModel.messageId,
            otherParams: viewModel.otherParams
        )
        let newHostingController = UIHostingController(rootView: view)

        // Add hostingController.view to superview and pin constraints
        newHostingController.willMove(toParent: parent)
        let hostedView = newHostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hostedView)
        NSLayoutConstraint.activate([
            hostedView.topAnchor.constraint(equalTo: contentView.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            hostedView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
        parent.addChild(newHostingController)
        newHostingController.didMove(toParent: parent)

        self.hostingController = newHostingController
    }

    func unconfigureHosting() {
        self.hostingController?.willMove(toParent: nil)
        self.hostingController?.view.removeFromSuperview()
        self.hostingController?.removeFromParent()
        self.hostingController = nil
    }
}
