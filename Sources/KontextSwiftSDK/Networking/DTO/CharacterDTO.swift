//
//  CharacterDTO.swift
//  KontextSwiftSDK
//

import Foundation

struct CharacterDTO: Encodable {
    let id: String?
    let name: String?
    let avatarUrl: URL?
    let isNsfw: Bool?
    let greeting: String?
    let persona: String?
    let tags: [String]?
    
    init(
        id: String?,
        name: String?,
        avatarUrl: URL?,
        isNsfw: Bool?,
        greeting: String?,
        persona: String?,
        tags: [String]?
    ) {
        self.id = id
        self.name = name
        self.avatarUrl = avatarUrl
        self.isNsfw = isNsfw
        self.greeting = greeting
        self.persona = persona
        self.tags = tags
    }
    
    init?(from model: Character?) {
        guard let model else {
            return nil
        }
        
        self.init(
            id: model.id,
            name: model.name,
            avatarUrl: model.avatarUrl,
            isNsfw: model.isNsfw,
            greeting: model.greeting,
            persona: model.persona,
            tags: model.tags
        )
    }
}
