/// Character / avatar metadata for character-based publisher apps.
///
/// `id`, `name`, and `avatarUrl` are required; everything else is
/// publisher-supplied optional metadata. The deprecated server field
/// `title` is intentionally omitted — server treats it as superseded
/// by `name`.
struct CharacterDTO: Encodable, Sendable {
    let id: String
    let name: String
    let avatarUrl: String
    let greeting: String?
    let persona: String?
    let tags: [String]?
    let isNsfw: Bool?

    init(
        id: String,
        name: String,
        avatarUrl: String,
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
