import Foundation
@testable import KontextSwiftSDK
import Testing

/// Pins the wire shape of outbound iframe DTOs and the JSON-shape
/// dispatch in `AnyJSONEncodable`. The latter is load-bearing: it
/// receives publisher-supplied `[String: Any]` payloads (often
/// round-tripped through `JSONSerialization`), where bool/number
/// disambiguation has historically been a foot-gun.
@MainActor
struct OutboundEncodingTests {

    // MARK: - AnyJSONEncodable: scalars

    @Test func encodesNativeBoolAsBool() throws {
        #expect(try jsonString(AnyJSONEncodable(true)) == "true")
        #expect(try jsonString(AnyJSONEncodable(false)) == "false")
    }

    @Test func encodesNativeIntAsNumber() throws {
        #expect(try jsonString(AnyJSONEncodable(42)) == "42")
        #expect(try jsonString(AnyJSONEncodable(-1)) == "-1")
    }

    @Test func encodesNativeDoubleAsNumber() throws {
        #expect(try jsonString(AnyJSONEncodable(3.5)) == "3.5")
    }

    @Test func encodesStringAsString() throws {
        #expect(try jsonString(AnyJSONEncodable("hello")) == "\"hello\"")
    }

    @Test func encodesNSNullAsNull() throws {
        #expect(try jsonString(AnyJSONEncodable(NSNull())) == "null")
    }

    // MARK: - AnyJSONEncodable: NSNumber bridging foot-gun

    /// Regression: NSNumber wrapping a real bool must encode as a JSON
    /// boolean, NOT as the underlying numeric form. CFBoolean is bridged
    /// through NSNumber, so `as Bool` matches both — we have to dispatch
    /// on `CFGetTypeID` first.
    @Test func encodesNSNumberBoolAsBool() throws {
        let trueNum: NSNumber = true
        let falseNum: NSNumber = false
        #expect(try jsonString(AnyJSONEncodable(trueNum)) == "true")
        #expect(try jsonString(AnyJSONEncodable(falseNum)) == "false")
    }

    /// Regression: a numeric NSNumber must NOT match the `as Bool` cast.
    /// Before the dispatch fix, `42` round-tripped through
    /// `JSONSerialization` (which boxes everything as `NSNumber`) would
    /// encode as `true`.
    @Test func encodesNSNumberIntAsNumber() throws {
        let num: NSNumber = 42
        #expect(try jsonString(AnyJSONEncodable(num)) == "42")
    }

    @Test func encodesNSNumberDoubleAsNumber() throws {
        let num: NSNumber = 3.5
        #expect(try jsonString(AnyJSONEncodable(num)) == "3.5")
    }

    @Test func encodesJSONSerializationRoundTripPreservesBoolVsNumber() throws {
        // The realistic shape: a publisher payload that arrived as JSON
        // and was decoded via JSONSerialization, so every leaf is an
        // NSNumber. Both kinds must emerge with the right JSON type.
        let raw = "{\"flag\": true, \"count\": 7}".data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: raw) as! [String: Any]
        let encoded = try jsonObject(AnyJSONEncodable(parsed))

        #expect(encoded["flag"] as? Bool == true)
        #expect(encoded["count"] as? Int == 7)
    }

    // MARK: - AnyJSONEncodable: containers

    @Test func encodesNestedDictionary() throws {
        let payload: [String: Any] = [
            "user": ["id": 1, "active": true] as [String: Any],
            "tags": ["a", "b"],
        ]
        let encoded = try jsonObject(AnyJSONEncodable(payload))
        let user = encoded["user"] as? [String: Any]
        #expect(user?["id"] as? Int == 1)
        #expect(user?["active"] as? Bool == true)
        #expect(encoded["tags"] as? [String] == ["a", "b"])
    }

    @Test func encodesArrayOfMixedTypes() throws {
        var payload: [Any] = []
        payload.append(1)
        payload.append("two")
        payload.append(true)
        payload.append(NSNull())
        let data = try JSONEncoder().encode(AnyJSONEncodable(payload))
        let decoded = try JSONSerialization.jsonObject(with: data) as? [Any]
        #expect(decoded?.count == 4)
        #expect(decoded?[0] as? Int == 1)
        #expect(decoded?[1] as? String == "two")
        #expect(decoded?[2] as? Bool == true)
        #expect(decoded?[3] is NSNull)
    }

    // MARK: - AnyJSONEncodable: unsupported types

    /// Anything that doesn't match a JSON-shaped case encodes as `null`
    /// rather than throwing. The publisher payload may contain odd
    /// types we don't model — we'd rather drop the leaf than crash the
    /// whole envelope.
    @Test func encodesUnsupportedTypeAsNull() throws {
        let value: Any = UnsupportedJSONType()
        #expect(try jsonString(AnyJSONEncodable(value)) == "null")
    }

    // MARK: - DTO wire shape

    @Test func userEventIframeMessageDTOHasCorrectType() throws {
        let dto = UserEventIframeMessageDTO(name: .userTypingStarted, payload: nil, code: "inlineAd")
        let encoded = try jsonObject(dto)
        #expect(encoded["type"] as? String == "user-event-iframe")
        // `code` must be INSIDE `data` (not at the top level) so the
        // iframe's `handleIframeMessage` finds it at `event.data.data.code`.
        // sdk-common's `makeIframeMessage` builds the same shape — a
        // top-level `code` here would silently break per-placement
        // filtering. See `sdk-common/src/iframe-messaging.ts:193`.
        #expect(encoded["code"] == nil)
        let data = encoded["data"] as? [String: Any]
        #expect(data?["name"] as? String == "user.typing.started")
        #expect(data?["code"] as? String == "inlineAd")
    }

    @Test func userEventIframeMessageDTOEncodesPayload() throws {
        let dto = UserEventIframeMessageDTO(
            name: .userTypingStarted,
            payload: ["count": 3, "isFinal": true],
            code: "sidebar"
        )
        let encoded = try jsonObject(dto)
        #expect(encoded["code"] == nil)
        let data = encoded["data"] as? [String: Any]
        #expect(data?["code"] as? String == "sidebar")
        let payload = data?["payload"] as? [String: Any]
        #expect(payload?["count"] as? Int == 3)
        #expect(payload?["isFinal"] as? Bool == true)
    }

    @Test func updateDimensionsIframeMessageDTOHasCorrectType() throws {
        let dto = UpdateDimensionsIframeMessageDTO(data: DimensionUpdate(
            windowWidth: 320, windowHeight: 480,
            screenWidth: 320, screenHeight: 568,
            containerWidth: 100, containerHeight: 50,
            containerX: 0, containerY: 100,
            keyboardHeight: 0
        ))
        let encoded = try jsonObject(dto)
        #expect(encoded["type"] as? String == "update-dimensions-iframe")
        let data = encoded["data"] as? [String: Any]
        #expect(data?["windowWidth"] as? Int == 320)
        #expect(data?["screenHeight"] as? Int == 568)
    }

    // MARK: - Helpers

    private func jsonString<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONEncoder().encode(value)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func jsonObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}

private struct UnsupportedJSONType {}
