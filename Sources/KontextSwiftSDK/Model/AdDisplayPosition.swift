/// Position in the conversation where the ad should be rendered
enum AdDisplayPosition: String, Sendable {
    /// Ad will be rendered after the assistant's message
    case afterAssistantMessage
    /// The ad will be rendered after the user's message
    case afterUserMessage
}
