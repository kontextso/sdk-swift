import Foundation
import OSLog

/// Represents different types of events that can be received from the InlineAd iframe
enum IframeEvent: Decodable, Hashable, Sendable {
    enum CodingKeys: CodingKey {
        case type
        case data
    }

    /// Init event from the iframe
    case initIframe

    /// WebView is ready to start streaming
    case showIframe

    /// WebView should be hidden
    case hideIframe

    /// The ad has been viewed by the user
    case viewIframe(ViewIframeDataDTO)

    /// The ad has been clicked by the user
    case clickIframe(ClickIframeDataDTO)

    /// The height of the iframe has changed
    case resizeIframe(ResizeIframeDataDTO)

    /// Error event from the iframe
    case errorIframe(ErrorDataDTO?)

    /// Open component request event to display component iframe
    case openComponentIframe(OpenComponentIframeDataDTO)

    /// Init component event from iframe
    case initComponentIframe(ComponentIframeDataDTO)

    /// Error component event from iframe
    case errorComponentIframe(ComponentIframeDataDTO)

    /// Close component request event to close component iframe
    case closeComponentIframe(ComponentIframeDataDTO)

    /// Events coming from iframe
    case eventIframe(EventIframeDataDTO)

    /// Unknown event type
    case unknown(String)
}

// MARK: - Event Data Objects
extension IframeEvent {
    /// Data for view-iframe events
    struct ViewIframeDataDTO: Decodable, Hashable {
        let id: String
        let content: String
        let messageId: String
        let code: String
    }

    /// Data for click-iframe events
    struct ClickIframeDataDTO: Decodable, Hashable {
        let id: String
        let content: String
        let messageId: String
        let url: URL?
    }

    /// Data for resize-iframe events
    struct ResizeIframeDataDTO: Decodable, Hashable {
        let height: CGFloat
    }

    /// Data for error events
    struct ErrorDataDTO: Decodable, Hashable {
        let message: String
    }

    /// Data for update-iframe events
    struct UpdateIFrameDataDTO: Decodable, Hashable {
        let sdk: String
        let code: String
        let messageId: String
        let messages: [MessageDTO]
        let otherParams: [String: String]?
    }

    /// Data for open component iframe events
    struct OpenComponentIframeDataDTO: Decodable, Hashable {
        let code: String
        let component: String
        let timeout: TimeInterval // ms
    }

    /// Data for general component iframe events
    struct ComponentIframeDataDTO: Decodable, Hashable {
        let code: String
        let component: String
    }

    /// Data for unknown events
    struct UnknownDataDTO: Decodable, Hashable {
        let type: String
    }

    /// Data for iframe event
    struct EventIframeDataDTO: Decodable, Hashable {
        let type: String
        let data: EventIframeContentDTO
    }
}

// MARK: - Event Parsing

extension IframeEvent {
    /// Creates an InlineAdEvent from a dictionary received from the iframe
    /// - Parameter dict: The dictionary containing event data
    /// - Returns: Parsed InlineAdEvent or nil if parsing fails
    ///
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "init-iframe":
            self = .initIframe
        case "show-iframe":
            self = .showIframe
        case "hide-iframe":
            self = .hideIframe
        case "view-iframe":
            self = .viewIframe(
                try container.decode(ViewIframeDataDTO.self, forKey: .data)
            )
        case "click-iframe":
            self = .clickIframe(
                try container.decode(ClickIframeDataDTO.self, forKey: .data)
            )
        case "resize-iframe":
            self = .resizeIframe(
                try container.decode(ResizeIframeDataDTO.self, forKey: .data)
            )
        case "error-iframe":
            self = .errorIframe(
                try? container.decode(ErrorDataDTO.self, forKey: .data)
            )
        case "open-component-iframe":
            self = .openComponentIframe(
                try container.decode(
                    OpenComponentIframeDataDTO.self,
                    forKey: .data
                )
            )
        case "close-component-iframe":
            self = .closeComponentIframe(
                try container.decode(ComponentIframeDataDTO.self, forKey: .data)
            )
        case "init-component-iframe":
            self = .initComponentIframe(
                try container.decode(ComponentIframeDataDTO.self, forKey: .data)
            )
        case "error-component-iframe":
            self = .errorComponentIframe(
                try container.decode(ComponentIframeDataDTO.self, forKey: .data)
            )
        case "event-iframe":
            self = .eventIframe(
                try container.decode(EventIframeDataDTO.self, forKey: .data)
            )
        default:
            self = .unknown(type)
        }
    }
}
