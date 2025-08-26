//
//  ReuseIdentifier.swift
//  ExampleUIKit
//

import UIKit

extension UICollectionReusableView {
    static var reuseIdentifier: String {
        String(describing: Self.self)
    }
}
