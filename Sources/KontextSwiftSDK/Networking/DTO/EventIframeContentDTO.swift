import Foundation

struct EventIframeContentDTO: Decodable, Hashable {
    private enum CodingKeys: String, CodingKey {
        case name
        case code
        case type = "payload"
    }

    let name: String
    let code: String
    var type: TypeDTO

    enum TypeName: String {
        case viewed = "viewed"
        case clicked = "clicked"
        case videoPlayed = "video-played"
        case videoClosed = "video-closed"
        case rewardReceived = "reward-received"
    }

    enum TypeDTO: Decodable, Hashable {
        case viewed(ViewedDataDTO?)
        case clicked(ClickedDataDTO?)
        case videoPlayed(VideoPlayedDataDTO?)
        case videoClosed(VideoClosedDataDTO?)
        case rewardReceived(RewardReceivedDataDTO?)
        case event([String: AnyDecodable])
    }

    struct ViewedDataDTO: Decodable, Hashable {}
    struct ClickedDataDTO: Decodable, Hashable {}
    struct VideoPlayedDataDTO: Decodable, Hashable {}
    struct VideoClosedDataDTO: Decodable, Hashable {}
    struct RewardReceivedDataDTO: Decodable, Hashable {}

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decode(String.self, forKey: .name)
        code = try container.decode(String.self, forKey: .code)

        switch TypeName(rawValue: name) {
        case .viewed:
            type = .viewed(try? container.decodeIfPresent(ViewedDataDTO.self, forKey: .type))
        case .clicked:
            type = .clicked(try? container.decodeIfPresent(ClickedDataDTO.self, forKey: .type))
        case .videoClosed:
            type = .videoClosed(try? container.decodeIfPresent(VideoClosedDataDTO.self, forKey: .type))
        case .videoPlayed:
            type = .videoPlayed(try? container.decodeIfPresent(VideoPlayedDataDTO.self, forKey: .type))
        case .rewardReceived:
            type = .rewardReceived(try? container.decodeIfPresent(RewardReceivedDataDTO.self, forKey: .type))
        case .none:
            type = .event(try container.decode([String: AnyDecodable].self, forKey: .type))
        }
    }
}
