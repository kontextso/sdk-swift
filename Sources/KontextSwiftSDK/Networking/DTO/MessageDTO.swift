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
    
    init(id: String, role: Role, content: String, createdAt: Date) {
        self.id = id
        self.role = RoleDTO(from: role)
        self.content = content
        self.createdAt = createdAt
    }
    
    init(from model: AdsMessage) {
        self.init(
            id: model.id,
            role: model.role,
            content: model.content,
            createdAt: model.createdAt
        )
    }
}
