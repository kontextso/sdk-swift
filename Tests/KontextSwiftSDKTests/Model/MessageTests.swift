import Foundation
@testable import KontextSwiftSDK
import Testing

@MainActor
struct MessageTests {

    // MARK: - Equality

    @Test func messageEqualityWithSameFields() {
        let date = Date(timeIntervalSince1970: 1000)
        let m1 = Message(id: "m1", role: .user, content: "Hello", createdAt: date)
        let m2 = Message(id: "m1", role: .user, content: "Hello", createdAt: date)

        #expect(m1 == m2)
    }

    @Test func messageInequalityWithDifferentId() {
        let date = Date(timeIntervalSince1970: 1000)
        let m1 = Message(id: "m1", role: .user, content: "Hello", createdAt: date)
        let m2 = Message(id: "m2", role: .user, content: "Hello", createdAt: date)

        #expect(m1 != m2)
    }

    // MARK: - Defaults

    @Test func messageWithDefaultCreatedAt() {
        let before = Date()
        let msg = Message(id: "m1", role: .user, content: "Hello")
        let after = Date()

        #expect(msg.createdAt >= before)
        #expect(msg.createdAt <= after)
    }

    // MARK: - Role

    @Test func messageRoleRawValue() {
        #expect(Message.Role.user.rawValue == "user")
        #expect(Message.Role.assistant.rawValue == "assistant")
    }

    // MARK: - Hashable

    @Test func messageHashableConformance() {
        let date = Date(timeIntervalSince1970: 1000)
        let m1 = Message(id: "m1", role: .user, content: "Hello", createdAt: date)
        let m2 = Message(id: "m1", role: .user, content: "Hello", createdAt: date)
        let m3 = Message(id: "m2", role: .user, content: "Hello", createdAt: date)

        var set = Set<Message>()
        set.insert(m1)
        set.insert(m2) // Same as m1, should not increase count
        set.insert(m3) // Different id

        #expect(set.count == 2)
    }

    // MARK: - toDTO()

    @Test func toDTOConvertsAllFieldsCorrectly() {
        let date = Date(timeIntervalSince1970: 1705312200) // 2024-01-15T10:30:00Z
        let message = Message(id: "msg-42", role: .user, content: "What is the weather?", createdAt: date)

        let dto = message.toDTO()

        #expect(dto.id == "msg-42")
        #expect(dto.role == .user)
        #expect(dto.content == "What is the weather?")

        // Verify ISO 8601 with millisecond precision (matches sdk-js).
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let parsedDate = formatter.date(from: dto.createdAt)
        #expect(parsedDate != nil)
        #expect(parsedDate == date)
    }

    @Test func toDTOConvertsAssistantRole() {
        let message = Message(id: "msg-99", role: .assistant, content: "Here is the forecast")

        let dto = message.toDTO()

        #expect(dto.role == .assistant)
    }

    @Test func toDTOProducesISO8601DateString() {
        let date = Date(timeIntervalSince1970: 0) // 1970-01-01T00:00:00Z
        let message = Message(id: "m1", role: .user, content: "hi", createdAt: date)

        let dto = message.toDTO()

        #expect(dto.createdAt.contains("1970"))
        #expect(dto.createdAt.contains("T"))
        #expect(dto.createdAt.hasSuffix("Z"))
    }

    @Test func toDTOPreservesMillisecondPrecision() {
        // Pin the contract: createdAt strings always carry sub-second
        // precision, so two messages within the same second are
        // distinguishable on the wire.
        let date = Date(timeIntervalSince1970: 1705312200.456)
        let message = Message(id: "m1", role: .user, content: "hi", createdAt: date)

        let dto = message.toDTO()

        #expect(dto.createdAt.contains("."))
        #expect(dto.createdAt.contains("456"))
    }

    @Test func toDTOPreservesEmptyContent() {
        let message = Message(id: "m1", role: .user, content: "")

        let dto = message.toDTO()

        #expect(dto.content.isEmpty)
    }
}
