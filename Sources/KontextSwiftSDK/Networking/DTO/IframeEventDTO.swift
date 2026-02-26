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

    /// The ad finished rendering and is ready for impression attribution
    case adDoneIframe

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
        let messageId: String?
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
    struct UpdateIFrameDataDTO: Codable, Hashable {
        let sdk: String
        let code: String
        let messageId: String
        let messages: [MessageDTO]
        let otherParams: [String: String]?
    }

    /// Data for open component iframe events
    struct OpenComponentIframeDataDTO: Decodable, Hashable {
        enum Component: String, Decodable {
            case modal
        }

        static let defaultTimeoutMilliseconds: TimeInterval = 5000

        let code: String
        let component: Component
        let timeout: TimeInterval // ms
        let appStoreId: String?
        let position: String?
        let dismissible: Bool?

        init(
            code: String,
            component: String,
            timeout: TimeInterval = OpenComponentIframeDataDTO.defaultTimeoutMilliseconds,
            appStoreId: String? = nil,
            position: String? = nil,
            dismissible: Bool? = nil
        ) {
            self.code = code
            self.component = component
            self.timeout = timeout > 0 ? timeout : Self.defaultTimeoutMilliseconds
            self.appStoreId = appStoreId
            self.position = position
            self.dismissible = dismissible
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            code = try container.decode(String.self, forKey: .code)
            component = try container.decode(String.self, forKey: .component)
            timeout = Self.decodeTimeout(from: container)
            appStoreId = try container.decodeIfPresent(String.self, forKey: .appStoreId)
            position = try container.decodeIfPresent(String.self, forKey: .position)
            dismissible = try container.decodeIfPresent(Bool.self, forKey: .dismissible)
        }

        private enum CodingKeys: String, CodingKey {
            case code
            case component
            case timeout
            case appStoreId
            case position
            case dismissible
        }

        private static func decodeTimeout(
            from container: KeyedDecodingContainer<CodingKeys>
        ) -> TimeInterval {
            if let timeout = try? container.decode(TimeInterval.self, forKey: .timeout),
               timeout > 0 {
                return timeout
            }

            if let timeout = try? container.decode(Int.self, forKey: .timeout),
               timeout > 0 {
                return TimeInterval(timeout)
            }

            return defaultTimeoutMilliseconds
        }
    }

    /// Data for general component iframe events
    // TODO: Fix component - is not String anymore
    struct ComponentIframeDataDTO: Decodable, Hashable {
        let code: String
        let component: OpenComponentIframeDataDTO.Component

        init(code: String, component: String) {
            self.code = code
            self.component = component
        }
    }

    /// Data for unknown events
    struct UnknownDataDTO: Decodable, Hashable {
        let type: String
    }

    private struct OpenSKOverlayIframeDataAliasDTO: Decodable {
        let appStoreId: String?
        let position: String?
        let dismissible: Bool?
    }

    private struct CloseSKOverlayIframeDataAliasDTO: Decodable {}
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
        case "ad-done-iframe":
            self = .adDoneIframe
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
            guard let data = try? container.decode(OpenComponentIframeDataDTO.self, forKey: .data) else {
                self = .unknown(type)
                return
            }
            self = .openComponentIframe(data)
        case "open-skoverlay-iframe":
            let aliasData = try container.decode(
                OpenSKOverlayIframeDataAliasDTO.self,
                forKey: .data
            )
            self = .openComponentIframe(.init(
                code: "",
                component: "skoverlay",
                appStoreId: aliasData.appStoreId,
                position: aliasData.position,
                dismissible: aliasData.dismissible
            ))
        case "close-component-iframe":
            guard let data = try? container.decode(ComponentIframeDataDTO.self, forKey: .data) else {
                self = .unknown(type)
                return
            }
            self = .closeComponentIframe(data)
        case "close-skoverlay-iframe":
            let aliasData = try? container.decode(
                CloseSKOverlayIframeDataAliasDTO.self,
                forKey: .data
            )
            _ = aliasData
            self = .closeComponentIframe(.init(
                code: "",
                component: "skoverlay"
            ))
        case "init-component-iframe":
            guard let data = try? container.decode(ComponentIframeDataDTO.self, forKey: .data) else {
                self = .unknown(type)
                return
            }
            self = .initComponentIframe(data)
        case "error-component-iframe":
            guard let data = try? container.decode(ComponentIframeDataDTO.self, forKey: .data) else {
                self = .unknown(type)
                return
            }
            self = .errorComponentIframe(data)
        case "event-iframe":
            self = .eventIframe(
                try container.decode(EventIframeDataDTO.self, forKey: .data)
            )
        default:
            self = .unknown(type)
        }
    }
}
