struct BidDTO: Decodable {
    let bidId: String
    let code: String
    let adDisplayPosition: AdDisplayPosition
    
    var model: Bid {
        Bid(
            bidId: bidId,
            code: code,
            adDisplayPosition: adDisplayPosition
        )
    }
}
