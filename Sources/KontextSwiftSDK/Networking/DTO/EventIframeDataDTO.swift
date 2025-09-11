import Foundation

struct EventIframeDataDTO: Decodable, Hashable {
    private enum CodingKeys: String, CodingKey {
        case name
        case code
        case type = "payload"
    }

    let name: String
    let code: String
    let type: TypeDTO

    enum TypeName: String {
        case viewed = "ad.viewed"
        case clicked = "ad.clicked"
        case renderStarted = "ad.renderStarted"
        case renderCompleted = "ad.render"
        case error = "ad.error"
        case rewardGranted = "reward.granted"
        case videoStarted = "video.started"
        case videoCompleted = "video.completed"
    }

    enum TypeDTO: Decodable, Hashable {
        case viewed(ViewedDataDTO?)
        case clicked(ClickedDataDTO?)
        case renderStarted(GeneralDataDTO?)
        case renderCompleted(GeneralDataDTO?)
        case error(ErrorDataDTO?)
        case videoStarted(GeneralDataDTO?)
        case videoCompleted(GeneralDataDTO?)
        case rewardGranted(GeneralDataDTO?)
        case event([String: AnyDecodable])
    }

    struct ViewedDataDTO: Decodable, Hashable {
        let id: String
        let content: String
        let messageId: String
    }

    struct ClickedDataDTO: Decodable, Hashable {
        let id: String
        let content: String
        let messageId: String
        let url: URL?
    }

    struct GeneralDataDTO: Decodable, Hashable {
        let id: String
    }

    struct ErrorDataDTO: Decodable, Hashable {
        let message: String
        let errCode: String
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decode(String.self, forKey: .name)
        code = try container.decode(String.self, forKey: .code)

        switch TypeName(rawValue: name) {
        case .viewed:
            type = .viewed(try? container.decodeIfPresent(ViewedDataDTO.self, forKey: .type))
        case .clicked:
            type = .clicked(try? container.decodeIfPresent(ClickedDataDTO.self, forKey: .type))
        case .renderStarted:
            type = .renderStarted(try? container.decodeIfPresent(GeneralDataDTO.self, forKey: .type))
        case .renderCompleted:
            type = .renderCompleted(try? container.decodeIfPresent(GeneralDataDTO.self, forKey: .type))
        case .error:
            type = .error(try? container.decodeIfPresent(ErrorDataDTO.self, forKey: .type))
        case .rewardGranted:
            type = .rewardGranted(try? container.decodeIfPresent(GeneralDataDTO.self, forKey: .type))
        case .videoStarted:
            type = .videoStarted(try? container.decodeIfPresent(GeneralDataDTO.self, forKey: .type))
        case .videoCompleted:
            type = .videoCompleted(try? container.decodeIfPresent(GeneralDataDTO.self, forKey: .type))
        case .none:
            type = .event(try container.decode([String: AnyDecodable].self, forKey: .type))
        }
    }
}
