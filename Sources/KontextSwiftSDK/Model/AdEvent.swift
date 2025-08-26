//
//  AdEvent.swift
//  KontextSwiftSDK
//

import Foundation
/// Represents different types of events that can be received from the InlineAd iframe
enum AdEvent: Decodable {
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
    case viewIframe(ViewIframeData)

    /// The ad has been clicked by the user
    case clickIframe(ClickIframeData)

    /// The height of the iframe has changed
    case resizeIframe(ResizeIframeData)

    /// Error event from the iframe
    case errorIframe(ErrorData)

    /// Open component request event to display component iframe
    case openComponentIframe(OpenComponentIframeData)

    /// Init component event from iframe
    case initComponentIframe(ComponentIframeData)

    /// Error component event from iframe
    case errorComponentIframe(ComponentIframeData)

    /// Close component request event to close component iframe
    case closeComponentIframe(ComponentIframeData)

    /// Unknown event type
    case unknown(UnknownData)
}

// MARK: - Event Data Objects

/// Data for view-iframe events
struct ViewIframeData: Decodable {
    let id: String
    let content: String
    let messageId: String
    let code: String
}

/// Data for click-iframe events
struct ClickIframeData: Decodable {
    let id: String
    let content: String
    let messageId: String
    let url: URL?
}

/// Data for resize-iframe events
struct ResizeIframeData: Decodable {
    let height: CGFloat
}

/// Data for error events
struct ErrorData: Decodable {
    let message: String
}

/// Data for update-iframe events
struct UpdateIFrameData: Decodable {
    let sdk: String
    let code: String
    let messageId: String
    let messages: [MessageDTO]
    let otherParams: [String: String]?
}

/// Data for open component iframe events
struct OpenComponentIframeData: Decodable {
    let code: String
    let component: String
    let timeout: CGFloat
}

/// Data for general component iframe events
struct ComponentIframeData: Decodable {
    let code: String
    let component: String
}

/// Data for unknown events
struct UnknownData: Decodable {
    let type: String
}

// MARK: - Event Parsing

extension AdEvent {
    /// Creates an InlineAdEvent from a dictionary received from the iframe
    /// - Parameter dict: The dictionary containing event data
    /// - Returns: Parsed InlineAdEvent or nil if parsing fails
    ///
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        print(type)
        switch type {
        case "init-iframe":
            self = .initIframe
        case "show-iframe":
            self = .showIframe
        case "hide-iframe":
            self = .hideIframe
        case "view-iframe":
            self = .viewIframe(try container.decode(ViewIframeData.self, forKey: .data))
        case "click-iframe":
            self = .clickIframe(try container.decode(ClickIframeData.self, forKey: .data))
        case "resize-iframe":
            self = .resizeIframe(try container.decode(ResizeIframeData.self, forKey: .data))
        case "error-iframe":
            self = .errorIframe(try container.decode(ErrorData.self, forKey: .data))
        case "open-component-iframe":
            self = .openComponentIframe(try container.decode(OpenComponentIframeData.self, forKey: .data))
        case "close-component-iframe":
            self = .closeComponentIframe(try container.decode(ComponentIframeData.self, forKey: .data))
        case "init-component-iframe":
            self = .initComponentIframe(try container.decode(ComponentIframeData.self, forKey: .data))
        case "error-component-iframe":
            self = .errorComponentIframe(try container.decode(ComponentIframeData.self, forKey: .data))
        default:
            self = .unknown(try container.decode(UnknownData.self, forKey: .data))
        }
    }
}
