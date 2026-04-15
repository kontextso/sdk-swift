import Foundation
import Testing
@testable import KontextSwiftSDK

struct AdsEventTests {
    /// `AdsEvent.name` is part of the public API — these strings are stable
    /// contract for publishers that log/route on the event name.
    @Test
    func eventNamesCoverAllCases() {
        let url = URL(string: "https://example.com")!
        let uuid = UUID()

        #expect(AdsEvent.cleared.name == "ad.cleared")
        #expect(AdsEvent.filled([]).name == "ad.filled")
        #expect(AdsEvent.noFill(.init(messageId: "m", skipCode: nil)).name == "ad.no-fill")
        // adHeight requires a full Advertisement — not worth constructing here.
        #expect(AdsEvent.viewed(nil).name == "ad.viewed")
        #expect(AdsEvent.clicked(.init(bidId: uuid, content: "c", messageId: "m", url: url, format: nil, area: nil)).name == "ad.clicked")
        #expect(AdsEvent.renderStarted(nil).name == "ad.render-started")
        #expect(AdsEvent.renderCompleted(nil).name == "ad.render-completed")
        #expect(AdsEvent.error(nil).name == "ad.error")
        #expect(AdsEvent.videoStarted(nil).name == "video.started")
        #expect(AdsEvent.videoCompleted(nil).name == "video.completed")
        #expect(AdsEvent.rewardGranted(nil).name == "reward.granted")
        #expect(AdsEvent.event([:]).name == "ad.event")
    }

    @Test
    func noFillDataPreservesMessageIdAndSkipCode() {
        let data = AdsEvent.NoFillData(messageId: "m-1", skipCode: "no_fill")
        #expect(data.messageId == "m-1")
        #expect(data.skipCode == "no_fill")
    }

    @Test
    func viewedDataCapturesAllFields() {
        let id = UUID()
        let data = AdsEvent.ViewedData(bidId: id, content: "c", messageId: "m", format: "inline")
        #expect(data.bidId == id)
        #expect(data.content == "c")
        #expect(data.format == "inline")
    }

    @Test
    func clickedDataCapturesAllFields() {
        let id = UUID()
        let url = URL(string: "https://x.com")!
        let data = AdsEvent.ClickedData(bidId: id, content: "c", messageId: "m", url: url, format: "inline", area: "cta")
        #expect(data.bidId == id)
        #expect(data.url == url)
        #expect(data.area == "cta")
    }
}
