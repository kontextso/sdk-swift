import Foundation
@testable import KontextSwiftSDK
import Testing

/// Direct tests for the `Skan` typed struct + tolerant decoder + raw-dict
/// conversion. The wire-format contract (string scalars, camelCase keys,
/// four required fields) is shared with the ad server's `SkanPayload` type
/// in `ads/packages/ad-formats`.
struct SkanTests {

    // MARK: - Decoding the typed struct from wire-format JSON

    @Test func decodesAllFieldsFromWireFormat() throws {
        let json = Data("""
        {
            "version": "2.2",
            "network": "example.skadnetwork",
            "campaign": "42",
            "itunesItem": "123456789",
            "sourceApp": "987654321",
            "sourceIdentifier": "1234",
            "nonce": "abc-123",
            "timestamp": "1234567890",
            "signature": "sig-data"
        }
        """.utf8)

        let skan = try JSONDecoder().decode(Skan.self, from: json)
        #expect(skan.version == "2.2")
        #expect(skan.network == "example.skadnetwork")
        #expect(skan.campaign == "42")
        #expect(skan.itunesItem == "123456789")
        #expect(skan.sourceApp == "987654321")
        #expect(skan.sourceIdentifier == "1234")
        #expect(skan.nonce == "abc-123")
        #expect(skan.timestamp == "1234567890")
        #expect(skan.signature == "sig-data")
    }

    @Test func decodesMinimalPayloadWithOnlyRequiredFields() throws {
        // The four server-required fields alone decode fine; everything else
        // is optional on the wire.
        let json = Data("""
        {
            "version": "2.2",
            "network": "test.skadnetwork",
            "itunesItem": "123",
            "sourceApp": "456"
        }
        """.utf8)

        let skan = try JSONDecoder().decode(Skan.self, from: json)
        #expect(skan.version == "2.2")
        #expect(skan.network == "test.skadnetwork")
        #expect(skan.itunesItem == "123")
        #expect(skan.sourceApp == "456")
        #expect(skan.campaign == nil)
        #expect(skan.sourceIdentifier == nil)
        #expect(skan.fidelities == nil)
    }

    @Test func decodesFidelitiesArray() throws {
        let json = Data("""
        {
            "version": "4.0",
            "network": "example.skadnetwork",
            "itunesItem": "1",
            "sourceApp": "2",
            "fidelities": [
                { "fidelity": 0, "nonce": "n-0", "signature": "s-0", "timestamp": "100" },
                { "fidelity": 1, "nonce": "n-1", "signature": "s-1", "timestamp": "101" }
            ]
        }
        """.utf8)

        let skan = try JSONDecoder().decode(Skan.self, from: json)
        let fidelities = try #require(skan.fidelities)
        #expect(fidelities.count == 2)
        #expect(fidelities[0].fidelity == 0)
        #expect(fidelities[0].timestamp == "100")
        #expect(fidelities[1].fidelity == 1)
    }

    // MARK: - All-or-nothing: required fields throw on missing / unparseable

    @Test func decodingThrowsWhenRequiredFieldMissing() {
        // `itunesItem` and `sourceApp` are required on the wire.
        let json = Data("""
        { "version": "2.2", "network": "test.skadnetwork" }
        """.utf8)

        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(Skan.self, from: json)
        }
    }

    @Test func decodingThrowsWhenRequiredFieldIsUnparseable() {
        // `itunesItem` as an object — not a coercible scalar.
        let json = Data("""
        {
            "version": "2.2",
            "network": "test.skadnetwork",
            "itunesItem": { "wrong": "shape" },
            "sourceApp": "456"
        }
        """.utf8)

        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(Skan.self, from: json)
        }
    }

    // MARK: - Type-coercing decoder: numeric scalars accepted for required fields

    @Test func coercesIntToStringForRequiredField() throws {
        // Server bug: `itunesItem` sent as a number. Decoder coerces to
        // String rather than failing — the wire contract says strings,
        // but JS encoders mix types in practice.
        let json = Data("""
        {
            "version": "2.2",
            "network": "test.skadnetwork",
            "itunesItem": 123456789,
            "sourceApp": 987654321
        }
        """.utf8)

        let skan = try JSONDecoder().decode(Skan.self, from: json)
        #expect(skan.itunesItem == "123456789")
        #expect(skan.sourceApp == "987654321")
    }

    @Test func coercesIntToStringForOptionalField() throws {
        // Same coercion for optional fields.
        let json = Data("""
        {
            "version": "2.2",
            "network": "test.skadnetwork",
            "itunesItem": "1",
            "sourceApp": "2",
            "campaign": 42
        }
        """.utf8)

        let skan = try JSONDecoder().decode(Skan.self, from: json)
        #expect(skan.campaign == "42")
    }

    @Test func coercesStringToIntForFidelityField() throws {
        // Fidelity.fidelity is `Int` on the wire. If the server sends "1"
        // as a string, parse it.
        let json = Data("""
        {
            "version": "4.0",
            "network": "test.skadnetwork",
            "itunesItem": "1",
            "sourceApp": "2",
            "fidelities": [
                { "fidelity": "1", "nonce": "n", "signature": "s", "timestamp": "100" }
            ]
        }
        """.utf8)

        let skan = try JSONDecoder().decode(Skan.self, from: json)
        let fidelities = try #require(skan.fidelities)
        #expect(fidelities.count == 1)
        #expect(fidelities[0].fidelity == 1)
    }

    @Test func coercesIntToStringForFidelityField() throws {
        // And the reverse: numeric `timestamp` coerces to string.
        let json = Data("""
        {
            "version": "4.0",
            "network": "test.skadnetwork",
            "itunesItem": "1",
            "sourceApp": "2",
            "fidelities": [
                { "fidelity": 1, "nonce": "n", "signature": "s", "timestamp": 100 }
            ]
        }
        """.utf8)

        let skan = try JSONDecoder().decode(Skan.self, from: json)
        let fidelities = try #require(skan.fidelities)
        #expect(fidelities[0].timestamp == "100")
    }

    // MARK: - Tolerant decoder: optional non-coercible scalar becomes nil

    @Test func nonCoercibleOptionalScalarBecomesNil() throws {
        // `campaign` (optional) sent as an object — not coercible to a
        // scalar. Decoder leaves it nil; rest of the SKAN survives.
        let json = Data("""
        {
            "version": "2.2",
            "network": "test.skadnetwork",
            "itunesItem": "1",
            "sourceApp": "2",
            "campaign": { "wrong": "shape" }
        }
        """.utf8)

        let skan = try JSONDecoder().decode(Skan.self, from: json)
        #expect(skan.version == "2.2")
        #expect(skan.campaign == nil)
    }

    @Test func malformedFidelityEntryDropsTheWholeFidelitiesArray() throws {
        // Required Fidelity fields throw if genuinely unparseable. The
        // outer `try?` on `fidelities` then nils the whole array — the
        // rest of the SKAN survives.
        let json = Data("""
        {
            "version": "4.0",
            "network": "test.skadnetwork",
            "itunesItem": "1",
            "sourceApp": "2",
            "fidelities": [
                { "fidelity": 1, "nonce": "n", "signature": "s", "timestamp": { "wrong": "shape" } }
            ]
        }
        """.utf8)

        let skan = try JSONDecoder().decode(Skan.self, from: json)
        #expect(skan.version == "4.0")
        #expect(skan.fidelities == nil)
    }

    // MARK: - hasFidelity1

    @Test func hasFidelity1True() {
        let skan = makeSkan(fidelities: [
            Skan.Fidelity(fidelity: 0, signature: "s", nonce: "n", timestamp: "t"),
            Skan.Fidelity(fidelity: 1, signature: "s", nonce: "n", timestamp: "t"),
        ])
        #expect(skan.hasFidelity1)
    }

    @Test func hasFidelity1FalseWhenAllZero() {
        let skan = makeSkan(fidelities: [
            Skan.Fidelity(fidelity: 0, signature: "s", nonce: "n", timestamp: "t"),
        ])
        #expect(!skan.hasFidelity1)
    }

    @Test func hasFidelity1FalseWhenFidelitiesNil() {
        let skan = makeSkan()
        #expect(!skan.hasFidelity1)
    }

    // MARK: - toRawDict (KontextKit boundary)

    @Test func toRawDictPassesThroughCamelCaseKeys() {
        let skan = Skan(
            version: "2.2",
            network: "example.skadnetwork",
            itunesItem: "123456",
            sourceApp: "987654",
            campaign: "42",
            sourceIdentifier: "abc",
            nonce: "n",
            timestamp: "100",
            signature: "s"
        )
        let dict = skan.toRawDict()

        #expect(dict["version"] as? String == "2.2")
        #expect(dict["network"] as? String == "example.skadnetwork")
        #expect(dict["campaign"] as? String == "42")
        #expect(dict["itunesItem"] as? String == "123456")
        #expect(dict["sourceApp"] as? String == "987654")
        #expect(dict["sourceIdentifier"] as? String == "abc")
        #expect(dict["nonce"] as? String == "n")
        #expect(dict["timestamp"] as? String == "100")
        #expect(dict["signature"] as? String == "s")
    }

    @Test func toRawDictOmitsNilOptionalFields() {
        let skan = makeSkan()
        let dict = skan.toRawDict()
        // Required fields always present (4); no optionals set.
        #expect(dict.count == 4)
        #expect(dict["version"] as? String == "2.2")
        #expect(dict["network"] as? String == "n")
        #expect(dict["itunesItem"] as? String == "1")
        #expect(dict["sourceApp"] as? String == "2")
        #expect(dict["campaign"] == nil)
        #expect(dict["sourceIdentifier"] == nil)
    }

    @Test func toRawDictPreservesFidelities() throws {
        let skan = makeSkan(fidelities: [
            Skan.Fidelity(fidelity: 1, signature: "sig", nonce: "non", timestamp: "100"),
        ])
        let dict = skan.toRawDict()
        let fidelities = try #require(dict["fidelities"] as? [[String: Any]])
        #expect(fidelities.count == 1)
        #expect(fidelities[0]["fidelity"] as? Int == 1)
        #expect(fidelities[0]["signature"] as? String == "sig")
        #expect(fidelities[0]["nonce"] as? String == "non")
        #expect(fidelities[0]["timestamp"] as? String == "100")
    }

    // MARK: - Helpers

    private func makeSkan(fidelities: [Skan.Fidelity]? = nil) -> Skan {
        Skan(
            version: "2.2",
            network: "n",
            itunesItem: "1",
            sourceApp: "2",
            fidelities: fidelities
        )
    }
}
