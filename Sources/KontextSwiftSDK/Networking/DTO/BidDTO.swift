struct BidDTO: Decodable {
    let bidId: String
    let code: String
    let adDisplayPosition: AdDisplayPosition
    let skan: SkanDTO?

    private enum CodingKeys: String, CodingKey {
        case bidId
        case code
        case adDisplayPosition
        case skan
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bidId = try container.decode(String.self, forKey: .bidId)
        code = try container.decode(String.self, forKey: .code)
        adDisplayPosition = try container.decode(
            AdDisplayPosition.self,
            forKey: .adDisplayPosition
        )
        do {
            skan = try container.decodeIfPresent(SkanDTO.self, forKey: .skan)
        } catch {
            skan = nil
        }
    }
    
    var model: Bid {
        Bid(
            bidId: bidId,
            code: code,
            adDisplayPosition: adDisplayPosition,
            skan: skan?.model
        )
    }
}

struct SkanDTO: Decodable {
    let version: String
    let network: String
    let itunesItem: String
    let sourceApp: String
    let sourceIdentifier: String?
    let campaign: String?
    let fidelities: [AttributionFidelityDTO]?
    let nonce: String?
    let timestamp: String?
    let signature: String?

    var model: Skan {
        Skan(
            version: version,
            network: network,
            itunesItem: itunesItem,
            sourceApp: sourceApp,
            sourceIdentifier: sourceIdentifier,
            campaign: campaign,
            fidelities: fidelities?.map(\.model),
            nonce: nonce,
            timestamp: timestamp,
            signature: signature
        )
    }
}

struct AttributionFidelityDTO: Decodable {
    let fidelity: Int
    let signature: String
    let nonce: String
    let timestamp: String

    var model: AttributionFidelity {
        AttributionFidelity(
            fidelity: fidelity,
            signature: signature,
            nonce: nonce,
            timestamp: timestamp
        )
    }
}
