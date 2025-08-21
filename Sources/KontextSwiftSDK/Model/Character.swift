import Foundation

public struct Character: Codable, Sendable {
    public let id: String?
    public let name: String?
    public let avatarUrl: URL?
    public let isNsfw: Bool?
    public let greeting: String?
    public let persona: String?
    public let tags: [String]?
}
