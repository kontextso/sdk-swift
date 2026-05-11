/// Strongly-typed identifier for a publisher → ad-iframe user event.
///
/// Use a case directly:
///
/// ```swift
/// session.sendUserEvent(.userTypingStarted)
/// ```
///
/// The set of valid events is closed at compile time — typos or unknown
/// names are rejected at the call site rather than silently broadcast.
/// Mirrors sdk-js's `UserEventName = keyof UserEventMap` semantics.
///
/// To add a new event: add a case here and ship a release.
public enum UserEventName: String, Sendable {
    /// The user has started typing in the publisher's input field.
    case userTypingStarted = "user.typing.started"
}

/// Internal envelope for a publisher → ad-iframe user event. Constructed
/// by `Session.sendUserEvent`, broadcast through `userEventSenders`,
/// and serialised at the AdWebView boundary into the wire shape
/// `{ type: "user-event-iframe", data: { name, payload }, code }`.
///
/// `code` carries the targeted placement; iframes filter incoming
/// events on it so a `sidebar`-targeted event isn't acted on by an
/// `inlineAd` iframe. Mirrors sdk-js's `code` field on
/// `user-event-iframe` messages.
///
/// `payload` stays loose (`[String: Any]?`) because the publisher
/// supplies it — JSON-shaped at runtime, not at compile time.
struct UserEvent {
    let name: UserEventName
    let payload: [String: Any]?
    let code: String
}
