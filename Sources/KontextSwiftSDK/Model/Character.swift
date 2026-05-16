import Foundation

/// AI character metadata provided by the publisher for contextual targeting.
///
/// Conformances are deliberately minimal:
/// - `Sendable` — required: `Session.addMessage` is `async`, so options cross
///   actor boundaries.
/// - `Equatable` — convenience for publishers doing change-detection
///   (e.g. `if newCharacter != oldCharacter { update() }`); auto-synthesized.
///
/// Not conformed to `Hashable` (no set/dict-key usage) or `Encodable`
/// (encoding goes through `CharacterDTO`, not this type directly).
public struct Character: Sendable, Equatable {
    /// Unique identifier of the character.
    public let id: String
    /// Display name of the character.
    public let name: String
    /// URL of the character's avatar image. Required — publishers
    /// without a real avatar should supply a stable placeholder URL
    /// rather than passing a sentinel value. The server uses the URL
    /// host as a frequency-cap signal alongside `id`, so omitting it
    /// loses a piece of attribution.
    public let avatarUrl: URL
    /// Greeting text shown by the character, if any.
    public let greeting: String?
    /// Free-form description of the character's persona.
    public let persona: String?
    /// Tags categorising the character (e.g. genre, traits).
    public let tags: [String]?
    /// Whether the character is flagged as NSFW.
    public let isNsfw: Bool?

    public init(
        id: String,
        name: String,
        avatarUrl: URL,
        greeting: String? = nil,
        persona: String? = nil,
        tags: [String]? = nil,
        isNsfw: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.avatarUrl = avatarUrl
        self.greeting = greeting
        self.persona = persona
        self.tags = tags
        self.isNsfw = isNsfw
    }
}

// MARK: - Wire-format conversion

extension Character {
    /// Converts to the `/preload`-bound `CharacterDTO`. The only non-trivial
    /// field is `avatarUrl`: serialised as a string via `URL.absoluteString`.
    func toDTO() -> CharacterDTO {
        CharacterDTO(
            id: id,
            name: name,
            avatarUrl: avatarUrl.absoluteString,
            greeting: greeting,
            persona: persona,
            tags: tags,
            isNsfw: isNsfw
        )
    }
}
