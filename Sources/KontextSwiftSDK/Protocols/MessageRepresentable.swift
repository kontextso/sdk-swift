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
