import Foundation

public struct AttributionFidelity: Decodable, Sendable, Hashable {
    public let fidelity: Int
    public let signature: String
    public let nonce: String
    public let timestamp: String
}

public struct Skan: Decodable, Sendable, Hashable {
    public let version: String
    public let network: String
    public let itunesItem: String
    public let sourceApp: String
    public let sourceIdentifier: String?
    public let campaign: String?
    public let fidelities: [AttributionFidelity]?
    public let nonce: String?
    public let timestamp: String?
    public let signature: String?
}
