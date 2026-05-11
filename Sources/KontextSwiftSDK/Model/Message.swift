import Foundation

/// A single message in a conversation.
public struct Message: Sendable, Hashable, Identifiable {
    /// Unique identifier of the message.
    public let id: String
    /// The sender role (user or assistant).
    public let role: Role
    /// Text content of the message.
    public let content: String
    /// Timestamp when the message was created. Defaults to `Date()` if not provided.
    public let createdAt: Date

    /// The sender role in a conversation. Mirrors the server's
    /// `messages.role` enum — `'system'` is reserved for server-generated
    /// system prompts and is not exposed to publishers.
    public enum Role: String, Sendable, Hashable, Encodable {
        case user
        case assistant
    }

    public init(id: String, role: Role, content: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

// MARK: - Wire-format conversion

extension Message {
    /// Converts to the `/preload`-bound `MessageDTO`. The only non-trivial
    /// field is `createdAt`: serialised as an ISO 8601 string with
    /// millisecond precision (matches sdk-js's `Date.toJSON()`).
    func toDTO() -> MessageDTO {
        MessageDTO(
            id: id,
            role: role,
            content: content,
            createdAt: DateFormatting.iso8601String(from: createdAt)
        )
    }
}
