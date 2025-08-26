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

extension UITableViewCell {
    static var reuseIdentifier: String {
        String(describing: self)
    }
}
