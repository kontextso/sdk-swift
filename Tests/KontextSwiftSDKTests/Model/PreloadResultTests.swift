import Foundation
@testable import KontextSwiftSDK
import Testing

struct PreloadResultTests {

    // MARK: - .success

    @Test func successWithSingleBid() {
        let id = UUID()
        let session = UUID()
        let bid = Bid(bidId: id, code: "inlineAd")
        let result: PreloadResult = .success(bids: [bid], sessionId: session)

        guard case .success(let bids, let sessionId) = result else {
            Issue.record("Expected success")
            return
        }
        #expect(bids.count == 1)
        #expect(bids.first?.bidId == id)
        #expect(bids.first?.code == "inlineAd")
        #expect(sessionId == session)
    }

    @Test func successWithMultipleBids() {
        // Multi-placement publisher — one bid per matching placement code.
        let id1 = UUID()
        let id2 = UUID()
        let bids = [
            Bid(bidId: id1, code: "inlineAd"),
            Bid(bidId: id2, code: "interstitial"),
        ]
        let result: PreloadResult = .success(bids: bids, sessionId: UUID())

        guard case .success(let extracted, _) = result else {
            Issue.record("Expected success")
            return
        }
        #expect(extracted.count == 2)
        #expect(extracted.map { $0.bidId } == [id1, id2])
    }

    @Test func successWithEmptyBids() {
        // Server responded OK but no bid won the auction.
        let session = UUID()
        let result: PreloadResult = .success(bids: [], sessionId: session)

        guard case .success(let bids, let sessionId) = result else {
            Issue.record("Expected success")
            return
        }
        #expect(bids.isEmpty)
        #expect(sessionId == session)
    }

    // MARK: - .failure

    @Test func failureWithReasonOnly() {
        let result: PreloadResult = .failure(reason: "No fill", event: nil, disableSession: false, sessionId: nil)

        guard case .failure(let reason, let event, let disable, _) = result else {
            Issue.record("Expected failure")
            return
        }
        #expect(reason == "No fill")
        #expect(event == nil)
        #expect(!disable)
    }

    @Test func failureWithEvent() {
        // Server returned a skip with an event payload — the SDK forwards
        // the event to the publisher's onEvent handler.
        let event: AdEvent = .noFill(.init(skipCode: "frequency_cap"))
        let result: PreloadResult = .failure(reason: "Skipped", event: event, disableSession: false, sessionId: nil)

        guard case .failure(_, let extractedEvent, _, _) = result else {
            Issue.record("Expected failure")
            return
        }
        #expect(extractedEvent == .noFill(.init(skipCode: "frequency_cap")))
    }

    @Test func failureWithDisableSession() {
        // Server permanently disabled the session — the SDK should stop
        // sending preload requests.
        let result: PreloadResult = .failure(reason: "Publisher disabled", event: nil, disableSession: true, sessionId: nil)

        guard case .failure(let reason, _, let disable, _) = result else {
            Issue.record("Expected failure")
            return
        }
        #expect(reason == "Publisher disabled")
        #expect(disable)
    }
}
