//
//  InlinedAdViewModel.swift
//  KontextSwiftSDK
//

import Combine
import Foundation
import OSLog
import UIKit

@MainActor
final class InlineAdViewModel: ObservableObject {
    let ad: Advertisment

    init(ad: Advertisment) {
        self.ad = ad
    }
}

