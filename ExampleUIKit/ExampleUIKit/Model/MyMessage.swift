//
//  MyMessage.swift
//  ExampleUIKit
//

import Foundation
import KontextSwiftSDK

struct MyMessage: MessageRepresentable {
    let id: String
    let role: Role
    let content: String
    let createdAt: Date
}
