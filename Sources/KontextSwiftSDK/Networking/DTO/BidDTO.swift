import Foundation

struct BidDTO: Decodable {
    let bidId: String
    let code: String
    let adDisplayPosition: AdDisplayPositionDTO
    let skan: SkanDTO?
    let impressionTrigger: ImpressionTrigger
    let om: OmInfoDTO?

    private enum CodingKeys: String, CodingKey {
        case bidId
        case code
        case adDisplayPosition
        case skan
        case impressionTrigger
        case om
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bidId = try container.decode(String.self, forKey: .bidId)
        code = try container.decode(String.self, forKey: .code)
        adDisplayPosition = (try? container.decode(
            AdDisplayPositionDTO.self,
            forKey: .adDisplayPosition
        )) ?? .afterAssistantMessage
        do {
            skan = try container.decodeIfPresent(SkanDTO.self, forKey: .skan)
        } catch {
            skan = nil
        }
        let decodedImpressionTrigger = try? container.decodeIfPresent(
            String.self,
            forKey: .impressionTrigger
        )
        impressionTrigger = ImpressionTrigger(
            rawValue: decodedImpressionTrigger ?? ""
        ) ?? .immediate
        do {
            om = try container.decodeIfPresent(OmInfoDTO.self, forKey: .om)
        } catch {
            om = nil
        }
    }

    var model: Bid? {
        guard let uuid = UUID(uuidString: bidId) else {
            return nil
        }
        return Bid(
            bidId: uuid,
            code: code,
            adDisplayPosition: adDisplayPosition.model,
            skan: skan?.model,
            impressionTrigger: impressionTrigger,
            creativeType: om?.model
        )
    }
}

struct OmInfoDTO: Decodable {
    let creativeType: String?

    var model: OmCreativeType? {
        guard let creativeType else { return nil }
        return OmCreativeType(rawValue: creativeType)
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
