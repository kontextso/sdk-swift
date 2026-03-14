/// SKAdNetwork fidelity type and its associated attribution signature
struct AttributionFidelity: Sendable, Hashable {
    let fidelity: Int
    let signature: String
    let nonce: String
    let timestamp: String
}

/// SKAdNetwork attribution payload for iOS impression reporting
struct Skan: Sendable, Hashable {
    let version: String
    let network: String
    let itunesItem: String
    let sourceApp: String
    let sourceIdentifier: String?
    let campaign: String?
    let fidelities: [AttributionFidelity]?
    let nonce: String?
    let timestamp: String?
    let signature: String?
}
