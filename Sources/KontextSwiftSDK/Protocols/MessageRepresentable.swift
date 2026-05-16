/// A type that can be passed to `Session.addMessage()` as a message.
///
/// Conform your own message model to this protocol to skip the manual
/// adapter step:
///
/// ```swift
/// struct MyChatMessage {
///     let id: UUID
///     let role: String
///     let body: String
///     let sentAt: Date
/// }
///
/// extension MyChatMessage: MessageRepresentable {
///     var asKontextMessage: Message {
///         Message(
///             id: id.uuidString,
///             role: role == "user" ? .user : .assistant,
///             content: body,
///             createdAt: sentAt
///         )
///     }
/// }
///
/// for msg in chat.messages {
///     session.addMessage(msg.asKontextMessage)
/// }
/// ```
///
/// `Message` itself conforms to `MessageRepresentable`, so callers can
/// pass `Message` instances directly.
public protocol MessageRepresentable {
    /// Returns the Kontext-shaped message for the ad server.
    var asKontextMessage: Message { get }
}

extension Message: MessageRepresentable {
    public var asKontextMessage: Message { self }
}

public extension Session {
    /// Convenience overload that accepts any `MessageRepresentable`.
    ///
    /// - SeeAlso: ``addMessage(_:options:)``
    func addMessage(
        _ message: MessageRepresentable,
        options: AddMessageOptions? = nil
    ) {
        addMessage(message.asKontextMessage, options: options)
    }
}
