import Foundation

public enum OmCreativeType: String, Sendable {
    case display
    case video
}

public struct OmInfo: Sendable, Hashable {
    public let creativeType: OmCreativeType
}
