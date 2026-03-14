enum AdDisplayPositionDTO: String, Decodable, Sendable {
    case afterAssistantMessage
    case afterUserMessage

    init(from model: AdDisplayPosition) {
        switch model {
        case .afterAssistantMessage:
            self = .afterAssistantMessage
        case .afterUserMessage:
            self = .afterUserMessage
        }
    }
}
