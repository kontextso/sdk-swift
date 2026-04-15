import Foundation

/// Supported app-originated user events that can be broadcast into mounted ads.
public enum UserEventName: String, Codable, Sendable {
    /// Notify ads that the publisher app's input field entered a typing state.
    case userTypingStarted = "user.typing.started"
}
