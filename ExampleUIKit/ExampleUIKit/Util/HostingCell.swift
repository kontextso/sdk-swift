//
//  HostingCell.swift
//  ExampleUIKit
//

import Foundation
import SwiftUI
import UIKit
import KontextSwiftSDK

final class HostingCell<Content: View>: UICollectionViewCell {
    private let hostingController = UIHostingController<Content?>(rootView: nil)

    // Keep track if constraints were activated
    private var didSetupConstraints = false

    func set(rootView: Content, parentController: UIViewController) {
        hostingController.rootView = rootView
        hostingController.view.invalidateIntrinsicContentSize()

        let requiresControllerMove = hostingController.parent != parentController
        if requiresControllerMove {
            parentController.addChild(hostingController)
            hostingController.didMove(toParent: parentController)
        }

        if !contentView.subviews.contains(hostingController.view) {
            contentView.addSubview(hostingController.view)
        }

        if !didSetupConstraints {
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: contentView.topAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
            didSetupConstraints = true
        }
    }

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        setNeedsLayout()
        layoutIfNeeded()

        let targetSize = CGSize(
            width: layoutAttributes.size.width,
            height: UIView.layoutFittingCompressedSize.height
        )
        let size = hostingController.sizeThatFits(in: targetSize)

        print(CGRect(
            origin: layoutAttributes.frame.origin,
            size: CGSize(width: layoutAttributes.size.width, height: ceil(size.height))
        ))

        let newAttributes = layoutAttributes.copy() as! UICollectionViewLayoutAttributes
        newAttributes.frame = CGRect(
            origin: layoutAttributes.frame.origin,
            size: CGSize(width: layoutAttributes.size.width, height: ceil(size.height))
        )
        return newAttributes
    }
}


//final class HostingCell<Content: View>: UICollectionViewCell {
//    private let hostingController = UIHostingController<Content?>(rootView: nil)
//
//    override func prepareForReuse() {
//        super.prepareForReuse()
//        hostingController.rootView = nil
//    }
//
//    override init(frame: CGRect) {
//        super.init(frame: frame)
//        hostingController.view.backgroundColor = .clear
//    }
//
//    @available(*, unavailable)
//    required init?(coder aDecoder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//
//    func set(rootView: Content, parentController: UIViewController) {
//        hostingController.rootView = rootView
//        hostingController.view.invalidateIntrinsicContentSize()
//
//        let requiresControllerMove = hostingController.parent != parentController
//        if requiresControllerMove {
//            parentController.addChild(hostingController)
//        }        
//
//        if !contentView.subviews.contains(hostingController.view) {
//            contentView.addSubview(hostingController.view)
//
//            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
//
//            NSLayoutConstraint.activate([
//                topAnchor.constraint(equalTo: hostingController.view.topAnchor),
//                leadingAnchor.constraint(equalTo: hostingController.view.leadingAnchor),
//                trailingAnchor.constraint(equalTo: hostingController.view.trailingAnchor),
//                bottomAnchor.constraint(equalTo: hostingController.view.bottomAnchor)
//            ])
//        }
//
//        if requiresControllerMove {
//            hostingController.didMove(toParent: parentController)
//        }
//    }
//}

extension UICollectionReusableView {
    static var reuseIdentifier: String {
        String(describing: Self.self)
    }
}
