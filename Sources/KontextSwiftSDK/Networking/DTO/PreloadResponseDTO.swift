struct PreloadResponseDTO: ModelConvertible, Decodable {
    let sessionId: String?
    let bids: [BidDTO]?
    let remoteLogLevel: String?
    let permanentError: Bool?
    let skipCode: String?
    
    func toModel() -> PreloadedData {
        PreloadedData(
            sessionId: sessionId,
            bids: bids?.map { $0.model },
            remoteLogLevel: remoteLogLevel,
            permanentError: permanentError,
            skipCode: skipCode
        )
    }
}
