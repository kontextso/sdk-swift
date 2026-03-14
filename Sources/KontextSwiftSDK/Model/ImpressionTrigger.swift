import Foundation

public enum ImpressionTrigger: String, Decodable, Sendable {
    case immediate
    case component

    public init(from decoder: Decoder) throws {
        let rawValue = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = ImpressionTrigger(rawValue: rawValue) ?? .immediate
    }
}
