import Foundation

/// Convenience type that already represents a message.
/// - This can be useful if conforming to `MessageRepresentable` directly is not desired.
public struct AdsMessage: MessageRepresentable, Sendable {
    /// Unique ID of the message
    public let id: String
    /// Role of the author of the message (user or assistant)
    public let role: Role
    /// Text content of the message
    public let content: String
    /// Date of message creation (defaults to the current date).
    public let createdAt: Date

    /// Initializes a new AdsMessage instance.
    ///
    /// - Parameters:
    ///     - id: Unique identifier of the message.
    ///     - role: Role of the author (user or assistant).
    ///     - content: Txt content of the message.
    ///     - createdAt: Date of message creation (defaults to the current date).
    public init(
        id: String,
        role: Role,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}
