/// SKAdNetwork fidelity type and its associated attribution signature
struct AttributionFidelity: Sendable, Hashable {
    /// Fidelity type (0 = view-through, 1 = click-through)
    let fidelity: Int
    /// Attribution signature
    let signature: String
    /// Unique nonce for this impression
    let nonce: String
    /// Timestamp of the impression
    let timestamp: String
}

/// SKAdNetwork attribution payload for iOS impression reporting
struct Skan: Sendable, Hashable {
    /// SKAdNetwork version
    let version: String
    /// Ad network identifier
    let network: String
    /// App Store item ID of the advertised app
    let itunesItem: String
    /// Bundle ID of the source app showing the ad
    let sourceApp: String
    /// Source identifier for fine-grained campaign reporting (SKAdNetwork 4.0+)
    let sourceIdentifier: String?
    /// Campaign identifier
    let campaign: String?
    /// Fidelity types supported by this impression
    let fidelities: [AttributionFidelity]?
    /// Nonce for view-through attribution
    let nonce: String?
    /// Timestamp for view-through attribution
    let timestamp: String?
    /// Signature for view-through attribution
    let signature: String?
}
