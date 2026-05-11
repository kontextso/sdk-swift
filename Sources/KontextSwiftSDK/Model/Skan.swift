/// SKAdNetwork attribution payload, decoded from the `/preload` response and
/// passed through to Apple's SKAdNetwork APIs (via KontextKit).
///
/// Internal to the SDK. Field types and names mirror the server's
/// `SkanPayload` interface (in `ads/packages/ad-formats`); KontextKit's
/// `num()` helper handles the String → NSNumber conversion for any
/// numeric-looking IDs at the SKAdNetwork API boundary.
///
/// Decoder is type-coercing: if the server sends a numeric ID as `42`
/// instead of the contract-specified `"42"` (or vice versa), the decoder
/// silently coerces between Int/Double and String rather than failing.
/// All-or-nothing for the four server-required fields (`version`,
/// `network`, `itunesItem`, `sourceApp`): if any is missing or genuinely
/// unparseable (e.g. an object), decoding throws — `BidDTO`'s outer
/// `try?` then nils the whole `skan` so the bid still decodes.
struct Skan: Sendable, Decodable, Equatable {
    let version: String
    let network: String
    let itunesItem: String
    let sourceApp: String
    let campaign: String?
    let sourceIdentifier: String?
    let nonce: String?
    let timestamp: String?
    let signature: String?
    let fidelities: [Fidelity]?

    private enum CodingKeys: String, CodingKey {
        case version, network, itunesItem, sourceApp, campaign, sourceIdentifier, nonce, timestamp, signature, fidelities
    }

    struct Fidelity: Sendable, Decodable, Equatable {
        let fidelity: Int
        let signature: String
        let nonce: String
        let timestamp: String

        private enum CodingKeys: String, CodingKey {
            case fidelity, signature, nonce, timestamp
        }

        init(fidelity: Int, signature: String, nonce: String, timestamp: String) {
            self.fidelity = fidelity
            self.signature = signature
            self.nonce = nonce
            self.timestamp = timestamp
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.fidelity  = try c.requireIntCoercing(forKey: .fidelity)
            self.signature = try c.requireStringCoercing(forKey: .signature)
            self.nonce     = try c.requireStringCoercing(forKey: .nonce)
            self.timestamp = try c.requireStringCoercing(forKey: .timestamp)
        }
    }

    init(
        version: String,
        network: String,
        itunesItem: String,
        sourceApp: String,
        campaign: String? = nil,
        sourceIdentifier: String? = nil,
        nonce: String? = nil,
        timestamp: String? = nil,
        signature: String? = nil,
        fidelities: [Fidelity]? = nil
    ) {
        self.version = version
        self.network = network
        self.itunesItem = itunesItem
        self.sourceApp = sourceApp
        self.campaign = campaign
        self.sourceIdentifier = sourceIdentifier
        self.nonce = nonce
        self.timestamp = timestamp
        self.signature = signature
        self.fidelities = fidelities
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.version          = try c.requireStringCoercing(forKey: .version)
        self.network          = try c.requireStringCoercing(forKey: .network)
        self.itunesItem       = try c.requireStringCoercing(forKey: .itunesItem)
        self.sourceApp        = try c.requireStringCoercing(forKey: .sourceApp)
        self.campaign         = c.decodeStringCoercing(forKey: .campaign)
        self.sourceIdentifier = c.decodeStringCoercing(forKey: .sourceIdentifier)
        self.nonce            = c.decodeStringCoercing(forKey: .nonce)
        self.timestamp        = c.decodeStringCoercing(forKey: .timestamp)
        self.signature        = c.decodeStringCoercing(forKey: .signature)
        self.fidelities       = try? c.decode([Fidelity].self, forKey: .fidelities)
    }
}

extension Skan {
    /// Whether the bid carries a fidelity-1 signature (StoreKit-rendered
    /// surfaces / SKStoreProduct attribution path).
    var hasFidelity1: Bool {
        fidelities?.contains(where: { $0.fidelity == 1 }) ?? false
    }

    /// Builds the `[String: Any]` shape that KontextKit's SKAdNetwork
    /// helpers consume. KontextKit's `num()` helper accepts String values
    /// and converts to NSNumber for the SKAdImpression API, so the values
    /// pass through as-is.
    func toRawDict() -> [String: Any] {
        var dict: [String: Any] = [
            "version": version,
            "network": network,
            "itunesItem": itunesItem,
            "sourceApp": sourceApp,
        ]
        if let v = campaign { dict["campaign"] = v }
        if let v = sourceIdentifier { dict["sourceIdentifier"] = v }
        if let v = nonce { dict["nonce"] = v }
        if let v = timestamp { dict["timestamp"] = v }
        if let v = signature { dict["signature"] = v }
        if let fidelities = fidelities {
            dict["fidelities"] = fidelities.map { f -> [String: Any] in
                [
                    "fidelity": f.fidelity,
                    "signature": f.signature,
                    "nonce": f.nonce,
                    "timestamp": f.timestamp,
                ]
            }
        }
        return dict
    }
}

// MARK: - Type-coercing decode helpers

/// Tolerant per-field decoding for SKAN scalars: tries the expected JSON
/// type first, then coerces between Int/Double and String. Lets the
/// server send `42` or `"42"` interchangeably without breaking the decode.
private extension KeyedDecodingContainer {
    /// Returns the field as a String, coercing Int/Double if necessary.
    /// Returns nil if the value is absent, null, or non-scalar.
    func decodeStringCoercing(forKey key: Key) -> String? {
        if let s = try? decode(String.self, forKey: key) { return s }
        if let i = try? decode(Int.self, forKey: key) { return String(i) }
        if let d = try? decode(Double.self, forKey: key) { return String(d) }
        return nil
    }

    /// Returns the field as an Int, coercing String/Double if necessary.
    /// Returns nil if the value is absent, null, or unparseable.
    func decodeIntCoercing(forKey key: Key) -> Int? {
        if let i = try? decode(Int.self, forKey: key) { return i }
        if let s = try? decode(String.self, forKey: key), let i = Int(s) { return i }
        if let d = try? decode(Double.self, forKey: key) { return Int(d) }
        return nil
    }

    func requireStringCoercing(forKey key: Key) throws -> String {
        guard let v = decodeStringCoercing(forKey: key) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: self,
                debugDescription: "Missing or unparseable required string field '\(key.stringValue)'"
            )
        }
        return v
    }

    func requireIntCoercing(forKey key: Key) throws -> Int {
        guard let v = decodeIntCoercing(forKey: key) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: self,
                debugDescription: "Missing or unparseable required int field '\(key.stringValue)'"
            )
        }
        return v
    }
}
