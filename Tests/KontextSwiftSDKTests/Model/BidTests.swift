import Foundation
@testable import KontextSwiftSDK
import Testing

struct BidTests {

    @Test func bidEquality() {
        let id = UUID()
        let b1 = Bid(bidId: id, code: "inlineAd", revenue: 0.5)
        let b2 = Bid(bidId: id, code: "inlineAd", revenue: 0.5)

        #expect(b1 == b2)
    }

    @Test func bidInequality() {
        let b1 = Bid(bidId: UUID(), code: "inlineAd")
        let b2 = Bid(bidId: UUID(), code: "inlineAd")

        #expect(b1 != b2)
    }

    @Test func bidImpressionTrigger() {
        let b1 = Bid(bidId: UUID(), code: "inlineAd", impressionTrigger: .immediate)
        let b2 = Bid(bidId: UUID(), code: "inlineAd", impressionTrigger: .component)

        #expect(b1.impressionTrigger == .immediate)
        #expect(b2.impressionTrigger == .component)
    }
}
