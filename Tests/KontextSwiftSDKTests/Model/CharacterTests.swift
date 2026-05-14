import Foundation
@testable import KontextSwiftSDK
import Testing

struct CharacterTests {

    @Test func characterInit() {
        let url = URL(string: "https://example.com/avatar.png")!
        let c = Character(
            id: "c1",
            name: "Bot",
            avatarUrl: url,
            greeting: "Hello!",
            persona: "Friendly",
            tags: ["fun", "casual"],
            isNsfw: false
        )

        #expect(c.id == "c1")
        #expect(c.name == "Bot")
        #expect(c.avatarUrl == url)
        #expect(c.greeting == "Hello!")
        #expect(c.persona == "Friendly")
        #expect(c.tags == ["fun", "casual"])
        #expect(c.isNsfw == false)
    }

    @Test func characterMinimalInit() {
        let url = URL(string: "https://example.com/avatar.png")!
        let c = Character(id: "c1", name: "Bot", avatarUrl: url)

        #expect(c.id == "c1")
        #expect(c.name == "Bot")
        #expect(c.avatarUrl == url)
        #expect(c.greeting == nil)
        #expect(c.persona == nil)
        #expect(c.tags == nil)
        #expect(c.isNsfw == nil)
    }

    // MARK: - toDTO()

    @Test func toDTOConvertsRequiredFields() {
        let url = URL(string: "https://example.com/luna.png")!
        let character = Character(id: "char-1", name: "Luna", avatarUrl: url)

        let dto = character.toDTO()

        #expect(dto.id == "char-1")
        #expect(dto.name == "Luna")
        #expect(dto.avatarUrl == "https://example.com/luna.png")
    }

    @Test func toDTOPreservesNilOptionalFields() {
        let url = URL(string: "https://example.com/luna.png")!
        let character = Character(id: "char-1", name: "Luna", avatarUrl: url)

        let dto = character.toDTO()

        #expect(dto.greeting == nil)
        #expect(dto.persona == nil)
        #expect(dto.tags == nil)
        #expect(dto.isNsfw == nil)
    }

    @Test func toDTOPreservesNonNilOptionalFields() {
        let character = Character(
            id: "char-2",
            name: "Nova",
            avatarUrl: URL(string: "https://example.com/nova.png")!,
            greeting: "Hey there!",
            persona: "A witty AI companion",
            tags: ["funny", "smart", "creative"],
            isNsfw: true
        )

        let dto = character.toDTO()

        #expect(dto.id == "char-2")
        #expect(dto.name == "Nova")
        #expect(dto.avatarUrl == "https://example.com/nova.png")
        #expect(dto.greeting == "Hey there!")
        #expect(dto.persona == "A witty AI companion")
        #expect(dto.tags == ["funny", "smart", "creative"])
        #expect(dto.isNsfw == true)
    }

    @Test func toDTOSerialisesAvatarUrlWithQueryParams() {
        // URL.absoluteString must preserve query strings — pin it so a
        // refactor (e.g. switching to URL.path) doesn't drop them.
        let url = URL(string: "https://example.com/avatar.png?v=42&size=large")!
        let character = Character(id: "c1", name: "Bot", avatarUrl: url)

        let dto = character.toDTO()

        #expect(dto.avatarUrl == "https://example.com/avatar.png?v=42&size=large")
    }

    @Test func toDTOPreservesEmptyTagsArray() {
        // Empty tags array should round-trip as `[]`, distinct from nil.
        let url = URL(string: "https://example.com/avatar.png")!
        let character = Character(id: "c1", name: "Bot", avatarUrl: url, tags: [])

        let dto = character.toDTO()

        #expect(dto.tags == [])
    }
}
