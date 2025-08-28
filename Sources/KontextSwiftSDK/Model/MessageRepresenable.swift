import Foundation

/// Provides necessary information for the AdsProvider about the message's content.
/// - Either conform to this protocol
public protocol MessageRepresentable: Sendable {
    /// Unique ID of the message
    var id: String { get }
    /// Role of the author of the message (user or assistant)
    var role: Role { get }
    /// Text content of the message
    var content: String { get }
    /// Date of message creation
    var createdAt: Date { get }
}

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

/// Protocol that provides a type that conforms to `MessageRepresentable`.
/// - This can be useful if conforming to `MessageRepresentable` directly is not desired.
/// - Ideally use with AdsMessage as the default type.
public protocol MessageRepresentableProviding {
    /// The message that provides necessary information for the AdsProvider and conforms to `MessageRepresentable`
    var message: MessageRepresentable { get }
}

// MARK: Mapping
extension MessageRepresentable {
    func toModel() -> AdsMessage {
        AdsMessage(
            id: id,
            role: role,
            content: content,
            createdAt: createdAt
        )
    }
}
