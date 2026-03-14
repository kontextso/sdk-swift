enum AdDisplayPosition: String, Sendable {
    /// Ad will be rendered after the assistant's message
    case afterAssistantMessage
    /// The ad will be rendered after the user's message
    case afterUserMessage

    init(from decoder: Decoder) throws {
        let rawValue = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = AdDisplayPosition(rawValue: rawValue) ?? .afterAssistantMessage
    }
}
