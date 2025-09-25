@preconcurrency import Combine
import UIKit

struct AdLoadingState {
    let id: UUID
    let bid: Bid
    let messageId: String
    let webViewData: AdLoadingState.WebViewData
    var show: Bool
    var preferredHeight: CGFloat?    
}

extension AdLoadingState {
    struct WebViewData: Sendable, Hashable {
        let url: URL?
        let updateData: UpdateIFrameDTO?
        let onIFrameEvent: @Sendable (IframeEvent) -> Void
        let onOMEvent: @Sendable (OMEvent) -> Void
        let events: AnyPublisher<InlineAdEvent, Never>

        func hash(into hasher: inout Hasher) {
            hasher.combine(url)
            hasher.combine(updateData)
        }

        static func ==(lhs: WebViewData, rhs: WebViewData) -> Bool {
            lhs.url == rhs.url && lhs.updateData == rhs.updateData
        }
    }
}

extension AdLoadingState: ModelConvertible {
    func toModel() -> Advertisement {
        Advertisement(
            id: id,
            messageId: messageId,
            placementCode: bid.code,
            preferredHeight: preferredHeight ?? 0,
            bid: bid,
            webViewData: webViewData
        )
    }
}
