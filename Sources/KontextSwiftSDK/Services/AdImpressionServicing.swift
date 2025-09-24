protocol AdImpressionServicing {
    func onClickImpression(bidId: String) async
    func onViewStartImpression(bidId: String) async
    func onViewStartEndImpression(bidId: String) async
}
