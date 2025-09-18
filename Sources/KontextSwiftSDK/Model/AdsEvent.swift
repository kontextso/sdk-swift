import Foundation

/// Event received from an ad.
public enum AdsEvent: Sendable {
    /// Event received when ad is available or ads have changed.
    case filled([Advertisement])
    /// Event received when ad is not available.
    case noFill(NoFillData)
    /// Event received when the height of a specific ad has been updated.
    case adHeight(Advertisement)
    /// Event received when user has viewed the ad.
    case viewed(ViewedData?)
    /// Event received when user has clicked the ad.
    case clicked(ClickedData?)
    /// Event received when ad starts rendering.
    case renderStarted(GeneralData?)
    /// Event received when ad completes rendering.
    case renderCompleted(GeneralData?)
    /// Event received when ad encounters an error.
    case error(ErrorData?)
    /// Event received when video started playing.
    case videoStarted(GeneralData?)
    /// Event received when video finished playing.
    case videoCompleted(GeneralData?)
    /// Event received when reward was granted.
    case rewardGranted(GeneralData?)
    /// Any other event.
    case event([String: any Sendable])
}

/// Types that come as payloads in ad events.
public extension AdsEvent {
    struct ViewedData: Sendable {
        public let bidId: String
        public let content: String
        public let messageId: String
        public let format: String
    }
    
    struct ClickedData: Sendable {
        public let bidId: String
        public let content: String
        public let messageId: String
        public let url: URL
        public let format: String
        public let area: String
    }
    
    struct ErrorData: Sendable {
        public let message: String
        public let errCode: String
    }

    struct GeneralData: Sendable {
        public let bidId: String
    }

    struct NoFillData: Sendable {
        public let messageId: String
    }
}

public extension AdsEvent {
    /// Name of the event for diagnostics.
    var name: String {
        switch self {
        case .filled: "ad.filled"
        case .noFill: "ad.no-fill"
        case .adHeight: "ad.height"
        case .viewed: "ad.viewed"
        case .clicked: "ad.clicked"
        case .renderStarted: "ad.render-started"
        case .renderCompleted: "ad.render-completed"
        case .error: "ad.error"
        case .videoStarted: "video.started"
        case .videoCompleted: "video.completed"
        case .rewardGranted: "reward.granted"
        case .event: "ad.event"
        }
    }
}
