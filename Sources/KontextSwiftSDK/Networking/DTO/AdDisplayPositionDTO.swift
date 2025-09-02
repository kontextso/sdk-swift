import Foundation

enum AdDisplayPositionDTO: String, Decodable, Sendable {
    case afterAssistantMessage
    case afterUserMessage
    case unknown
    
    // Conversion from model to DTO
    init(from model: AdDisplayPosition) {
        switch model {
        case .afterAssistantMessage:
            self = .afterAssistantMessage
        case .afterUserMessage:
            self = .afterUserMessage
        case .unknown:
            self = .unknown
        }
    }
}
