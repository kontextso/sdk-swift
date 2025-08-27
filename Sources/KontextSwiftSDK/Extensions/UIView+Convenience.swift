//
//  UIView+TopMostViewController.swift
//  KontextSwiftSDK
//
//  Created by Dominika Gajdová on 27.08.2025.
//

import UIKit

extension UIView {
    var topMostViewController: UIViewController? {
        guard let keyWindow = UIApplication.shared.currentKeyWindow else {
            return nil
        }

        var topController = keyWindow.rootViewController

        while let presentedViewController = topController?.presentedViewController {
            topController = presentedViewController
        }

        return topController
    }
}
