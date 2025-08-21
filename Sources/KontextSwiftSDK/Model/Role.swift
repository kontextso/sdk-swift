import Foundation

/// Role of the author of the message (user or assistant)
public enum Role: String, Sendable {
    /// Author of the message is the user of the app
    case user
    /// Author of the message is the assistant (AI), generated message
    case assistant
    /// Author of the message is unknown
    case unknown
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        self = Role(rawValue: rawValue) ?? .unknown
    }
}
