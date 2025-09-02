import Foundation

/// Event received from a displayed ad.
public struct AdsEvent: Sendable {
    public let name: String
    public let type: AdsEventType
}

public enum AdsEventType: Sendable {
    /// Event received when user has viewed the ad.
    case viewed(ViewedData?)
    /// Event received when user has clicked the ad.
    case clicked(ClickedData?)
    /// Event received when video was played.
    case videoPlayed(VideoPlayedData?)
    /// Event received when video was closed.
    case videoClosed(VideoClosedData?)
    /// Event received when reward was received.
    case rewardReceived(RewardReceivedData?)
    /// Any other event.
    case event([String: any Sendable])
}

/// Types that come as payloads in ad events..
public extension AdsEventType {
    struct ViewedData: Sendable {}
    struct ClickedData: Sendable {}
    struct VideoPlayedData: Sendable {}
    struct VideoClosedData: Sendable {}
    struct RewardReceivedData: Sendable {}
}
