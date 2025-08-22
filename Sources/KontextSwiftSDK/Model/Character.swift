import Foundation

/// Character that is being talked to in associated conversation
public struct Character: Codable, Sendable {
    /// Unique ID of the character
    public let id: String?
    /// Name of the character
    public let name: String?
    /// URL of the character’s avatar
    public let avatarUrl: URL?
    /// Whether the character is NSFW
    public let isNsfw: Bool?
    /// Greeting of the character
    public let greeting: String?
    /// Description of the character’s personality
    public let persona: String?
    /// Tags of the character (list of strings)
    public let tags: [String]?

    /// Initializes a Character instance.
    /// - Parameters:
    ///   - id: Unique ID of the character.
    ///   - name: Name of the character.
    ///   - avatarUrl: URL of the character’s avatar.
    ///   - isNsfw: Whether the character is NSFW.
    ///   - greeting: Greeting of the character.
    ///   - persona: Description of the character’s personality.
    ///   - tags: Tags of the character (list of strings).
    public init(
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
}
