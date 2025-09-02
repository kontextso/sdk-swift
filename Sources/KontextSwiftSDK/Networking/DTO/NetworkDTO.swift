//
//  NetworkDTO.swift
//  KontextSwiftSDK
//

struct NetworkDTO: Encodable {
    /// User agent string for the network request
    let userAgent: String?
    /// Network connection type (wifi/cellular/ethernet/other)
    let type: NetworkType?
    /// Network technology detail (5g/lte/hspa/...)
    let detail: NetworkDetail?
    /// Carrier name (e.g., "T-Mobile CZ")
    let carrier: String?

    init(from model: NetworkInfo) {
        userAgent = model.userAgent
        type = model.networkType
        detail = model.networkDetail
        carrier = model.carrierName
    }
}
