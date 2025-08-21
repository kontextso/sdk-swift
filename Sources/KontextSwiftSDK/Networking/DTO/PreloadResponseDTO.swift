//
//  PreloadResponseDTO.swift
//  KontextSwiftSDK
//

struct PreloadResponseDTO: Decodable {
    let sessionId: String?
    let bids: [BidDTO]
    let remoteLogLevel: String?
    let permanentError: Bool?
    
    var preloadedData: PreloadedData {
        PreloadedData(
            sessionId: sessionId,
            bids: bids.map { $0.model },
            remoteLogLevel: remoteLogLevel,
            permanentError: permanentError
        )
    }
}
