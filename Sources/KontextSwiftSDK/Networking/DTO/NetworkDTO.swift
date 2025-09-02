//
//  NetworkDTO.swift
//  KontextSwiftSDK
//

enum NetworkType: String, Encodable {
    case wifi
    case cellular
    case ethernet
    case other
}

enum NetworkDetail: String, Encodable {
    case twoG = "2g"
    case threeG = "3g"
    case fourG = "4g"
    case lte
    case fiveG = "5g"
    case nr
    case hspa
    case edge
    case gprs
}

struct NetworkDTO: Encodable {
    /// User agent string for the network request
    let userAgent: String?
    /// Network connection type (wifi/cellular/ethernet/other)
    let type: NetworkType?
    /// Network technology detail (5g/lte/hspa/...)
    let detail: NetworkDetail?
    /// Carrier name (e.g., "T-Mobile CZ")
    let carrier: String?

    init(
        from model: NetworkInfo = NetworkInfo.
    ) {
        userAgent = NetworkInfo.userAgent
        type = NetworkInfo.networkType()
        detail = NetworkInfo.networkDetail()
        carrier = NetworkInfo.carrierName
    }
}
