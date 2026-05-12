// CGFloat in AdHeightData.height — analyze can't see it.
// swiftlint:disable:next unused_import
import CoreGraphics
import Foundation

/// Ad lifecycle events emitted by the SDK.
///
/// Mirrors the sdk-js `AdEvent` contract in `sdk-common/src/ad-events.ts`:
/// every case carries a single typed payload struct (the analogue of
/// sdk-js's `event.payload`). Each case's primary identifier is the bid
/// ID; payload structs match sdk-js's type definitions field-by-field —
/// only `ViewedData.revenue` is optional, everything else is required.
public enum AdEvent: Sendable, Equatable {
    /// A bid was successfully filled.
    case filled(FilledData)
    /// No ad was returned for the placement (server skipped).
    case noFill(NoFillData)
    /// The ad iframe reported a new height. Swift-only event (sdk-js
    /// handles iframe resize internally); publishers consume it for
    /// UIKit auto-layout.
    case adHeight(AdHeightData)
    /// The ad was viewed by the user.
    case viewed(ViewedData)
    /// The ad was clicked by the user.
    case clicked(ClickedData)
    /// Render started for the bid.
    case renderStarted(RenderStartedData)
    /// Render completed for the bid.
    case renderCompleted(RenderCompletedData)
    /// The SDK encountered an error while serving an ad.
    case error(ErrorData)
    /// A video ad started playing.
    case videoStarted(VideoStartedData)
    /// A video ad finished playing.
    case videoCompleted(VideoCompletedData)
    /// A reward was granted (rewarded ad flow).
    case rewardGranted(RewardGrantedData)

    public struct FilledData: Sendable, Equatable {
        /// Unique identifier of the bid that filled.
        public let bidId: UUID
        /// Placement code this bid was matched to (e.g. `"inlineAd"`).
        /// Required because publishers with multiple `enabledPlacementCodes`
        /// receive one `.filled` per matched code and need to disambiguate.
        public let code: String
        public let revenue: Double?
        public init(bidId: UUID, code: String, revenue: Double? = nil) {
            self.bidId = bidId
            self.code = code
            self.revenue = revenue
        }
    }

    public struct NoFillData: Sendable, Equatable {
        public let skipCode: String
        public init(skipCode: String) {
            self.skipCode = skipCode
        }
    }

    public struct AdHeightData: Sendable, Equatable {
        public let bidId: UUID
        public let messageId: String
        public let height: CGFloat
        public init(bidId: UUID, messageId: String, height: CGFloat) {
            self.bidId = bidId
            self.messageId = messageId
            self.height = height
        }
    }

    public struct ViewedData: Sendable, Equatable {
        public let bidId: UUID
        public let content: String
        public let messageId: String
        public let format: String
        public let revenue: Double?
        public init(
            bidId: UUID,
            content: String,
            messageId: String,
            format: String,
            revenue: Double? = nil
        ) {
            self.bidId = bidId
            self.content = content
            self.messageId = messageId
            self.format = format
            self.revenue = revenue
        }
    }

    public struct ClickedData: Sendable, Equatable {
        public let bidId: UUID
        public let content: String
        public let messageId: String
        public let url: String
        public let format: String
        public let area: String
        public init(
            bidId: UUID,
            content: String,
            messageId: String,
            url: String,
            format: String,
            area: String
        ) {
            self.bidId = bidId
            self.content = content
            self.messageId = messageId
            self.url = url
            self.format = format
            self.area = area
        }
    }

    public struct RenderStartedData: Sendable, Equatable {
        public let bidId: UUID
        public init(bidId: UUID) {
            self.bidId = bidId
        }
    }

    public struct RenderCompletedData: Sendable, Equatable {
        public let bidId: UUID
        public init(bidId: UUID) {
            self.bidId = bidId
        }
    }

    public struct ErrorData: Sendable, Equatable {
        public let message: String
        public let errCode: String
        public init(message: String, errCode: String) {
            self.message = message
            self.errCode = errCode
        }
    }

    public struct VideoStartedData: Sendable, Equatable {
        public let bidId: UUID
        public init(bidId: UUID) {
            self.bidId = bidId
        }
    }

    public struct VideoCompletedData: Sendable, Equatable {
        public let bidId: UUID
        public init(bidId: UUID) {
            self.bidId = bidId
        }
    }

    public struct RewardGrantedData: Sendable, Equatable {
        public let bidId: UUID
        public init(bidId: UUID) {
            self.bidId = bidId
        }
    }
}

public extension AdEvent {
    /// Stable string identifier of the event, suitable for diagnostics, logs and telemetry.
    var name: String {
        switch self {
        case .filled: return "ad.filled"
        case .noFill: return "ad.no-fill"
        case .adHeight: return "ad.height"
        case .viewed: return "ad.viewed"
        case .clicked: return "ad.clicked"
        case .renderStarted: return "ad.render-started"
        case .renderCompleted: return "ad.render-completed"
        case .error: return "ad.error"
        case .videoStarted: return "video.started"
        case .videoCompleted: return "video.completed"
        case .rewardGranted: return "reward.granted"
        }
    }
}

/// Callback for ad lifecycle events.
public typealias AdEventHandler = @Sendable (AdEvent) -> Void
