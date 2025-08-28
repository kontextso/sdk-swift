import UIKit

struct AdLoadingState {
    let id: UUID
    let bid: Bid
    let messageId: String
    var show: Bool
    var preferredHeight: CGFloat?
    let webViewData: AdLoadingState.WebViewData
}

extension AdLoadingState {
    struct WebViewData: Sendable, Hashable {
        let url: URL?
        let updateData: UpdateIFrameData
        let onIFrameEvent: @Sendable (InlineAdEvent) -> Void

        func hash(into hasher: inout Hasher) {
            hasher.combine(url)
            hasher.combine(updateData)
        }

        static func ==(lhs: WebViewData, rhs: WebViewData) -> Bool {
            lhs.url == rhs.url && lhs.updateData == rhs.updateData
        }
    }
}

extension AdLoadingState {
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
