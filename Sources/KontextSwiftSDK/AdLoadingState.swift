@preconcurrency import Combine
import UIKit

/// Internal state for a single active ad slot, tracking a bid from arrival through display.
/// Lives in AdsProviderActor — one instance per active placement.
struct AdLoadingState {
    /// Unique identifier for this state instance
    let id: UUID
    /// The winning bid received from the server
    let bid: Bid
    /// ID of the chat message that triggered this ad
    let messageId: String
    /// Data required to render the ad web view
    let webViewData: AdLoadingState.WebViewData
    /// Whether the ad is currently visible
    var show: Bool
    /// Height reported by the ad — nil until the ad reports it
    var preferredHeight: CGFloat?
}

extension AdLoadingState {
    /// Everything needed to render and communicate with the ad web view
    struct WebViewData: Sendable, Hashable {
        /// URL of the ad iframe
        let url: URL?
        /// Data for updating the iframe after initial load
        let updateData: UpdateIFrameDTO?
        /// Called when the iframe posts a JS event
        let onIFrameEvent: @Sendable (IframeEvent) -> Void
        /// Called when an Open Measurement event is received
        let onOMEvent: @Sendable (OMEvent) -> Void
        /// Called when the ad web view is removed
        let onDispose: @Sendable () -> Void
        /// Stream of events from the inline ad
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
