//
//  MessageDTO.swift
//  KontextSwiftSDK
//

import Foundation

struct MessageDTO: Codable {
    /// Unique ID of the message
    let id: String
    /// Role of the author of the message (user or assistant)
    let role: RoleDTO
    /// Content of the message
    let content: String
    /// Timestamp when the message was created
    let createdAt: Date

    init(from model: AdsMessage) {
        id = model.id
        role = RoleDTO(from: model.role)
        content = model.content
        createdAt = model.createdAt
    }
}
