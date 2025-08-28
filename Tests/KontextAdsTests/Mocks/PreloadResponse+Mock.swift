@testable import KontextSwiftSDK

extension PreloadedData {
    static let data1 = PreloadedData(
        sessionId: "sessionId1",
        bids: [
            Bid.bid1,
            Bid.bid2,
            Bid.bid3,
            Bid.bid4,
            Bid.bid5,
        ],
        remoteLogLevel: nil,
        permanentError: nil
    )
}
