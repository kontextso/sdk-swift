//
//  AdDisplayPosition.swift
//  KontextSwiftSDK
//

enum AdDisplayPosition: String, Decodable, Sendable {
    /// Ad will be rendered after the assistant’s message
    case afterAssistantMessage
    /// The ad will be rendered after the user’s message
    case afterUserMessage
    case unknown
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        self = AdDisplayPosition(rawValue: rawValue) ?? .unknown
    }
}
