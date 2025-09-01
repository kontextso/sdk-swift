public struct AdsEvent: Sendable {
    public let name: String
    public let type: AdsEventType
}

public enum AdsEventType: Sendable {
    case viewed(ViewedData?)
    case clicked(ClickedData?)
    case videoPlayed(VideoPlayedData?)
    case videoClosed(VideoClosedData?)
    case rewardReceived(RewardReceivedData?)
    case event([String: Any])
}

public extension AdsEventType {
    struct ViewedData {}
    struct ClickedData {}
    struct VideoPlayedData {}
    struct VideoClosedData {}
    struct RewardReceivedData {}
}
