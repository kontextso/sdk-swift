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
    let ad: Advertisement

    init(ad: Advertisement) {
        self.ad = ad
    }
}

