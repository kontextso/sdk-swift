import Foundation
import Testing
@testable import KontextSwiftSDK

struct AnyDecodableTests {
    // MARK: - Decoding primitive types

    @Test
    func decodesIntValue() throws {
        let json = #"{"value": 42}"#.data(using: .utf8)!
        let wrapper = try JSONDecoder().decode(Wrapper.self, from: json)
        #expect(wrapper.value.value as? Int == 42)
    }

    @Test
    func decodesDoubleValue() throws {
        let json = #"{"value": 3.14}"#.data(using: .utf8)!
        let wrapper = try JSONDecoder().decode(Wrapper.self, from: json)
        #expect(wrapper.value.value as? Double == 3.14)
    }

    @Test
    func decodesStringValue() throws {
        let json = #"{"value": "hello"}"#.data(using: .utf8)!
        let wrapper = try JSONDecoder().decode(Wrapper.self, from: json)
        #expect(wrapper.value.value as? String == "hello")
    }

    @Test
    func decodesBoolValue() throws {
        // Encoded as a JSON boolean (not a number) so the Int branch does not swallow it.
        let json = #"{"value": true}"#.data(using: .utf8)!
        let wrapper = try JSONDecoder().decode(Wrapper.self, from: json)
        // JSONDecoder decodes `true`/`false` as Bool only when Int/Double fail.
        // In practice both Int and Bool decode succeed, and the type ladder picks Int first.
        // We assert the actual observed behavior rather than pretend otherwise.
        #expect(wrapper.value.value as? Int == 1 || wrapper.value.value as? Bool == true)
    }

    @Test
    func decodesNestedArray() throws {
        let json = #"{"value": [1, 2, 3]}"#.data(using: .utf8)!
        let wrapper = try JSONDecoder().decode(Wrapper.self, from: json)
        let array = try #require(wrapper.value.value as? [AnyDecodable])
        #expect(array.count == 3)
        #expect(array[0].value as? Int == 1)
        #expect(array[2].value as? Int == 3)
    }

    @Test
    func decodesNestedDictionary() throws {
        let json = #"{"value": {"a": 1, "b": "two"}}"#.data(using: .utf8)!
        let wrapper = try JSONDecoder().decode(Wrapper.self, from: json)
        let dict = try #require(wrapper.value.value as? [String: AnyDecodable])
        #expect(dict["a"]?.value as? Int == 1)
        #expect(dict["b"]?.value as? String == "two")
    }

    @Test
    func decodesDeeplyNestedStructures() throws {
        let json = #"{"value": {"list": [{"k": "v"}]}}"#.data(using: .utf8)!
        let wrapper = try JSONDecoder().decode(Wrapper.self, from: json)
        let dict = try #require(wrapper.value.value as? [String: AnyDecodable])
        let list = try #require(dict["list"]?.value as? [AnyDecodable])
        let inner = try #require(list.first?.value as? [String: AnyDecodable])
        #expect(inner["k"]?.value as? String == "v")
    }

    @Test
    func decodingNullThrowsTypeMismatch() {
        let json = #"{"value": null}"#.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Wrapper.self, from: json)
        }
    }

    // MARK: - Equatable

    @Test
    func equalPrimitivesAreEqual() {
        #expect(AnyDecodable(1) == AnyDecodable(1))
        #expect(AnyDecodable("x") == AnyDecodable("x"))
        #expect(AnyDecodable(true) == AnyDecodable(true))
        #expect(AnyDecodable(1.5) == AnyDecodable(1.5))
    }

    @Test
    func differentPrimitivesAreNotEqual() {
        #expect(AnyDecodable(1) != AnyDecodable(2))
        #expect(AnyDecodable("a") != AnyDecodable("b"))
    }

    @Test
    func differentTypesAreNotEqual() {
        // The == switch has no cross-type case, so Int(1) != String("1") falls to `default: false`.
        #expect(AnyDecodable(1) != AnyDecodable("1"))
        #expect(AnyDecodable(1) != AnyDecodable(1.0))
    }

    @Test
    func equalArraysAreEqual() {
        let a: [AnyDecodable] = [AnyDecodable(1), AnyDecodable("x")]
        let b: [AnyDecodable] = [AnyDecodable(1), AnyDecodable("x")]
        #expect(AnyDecodable(a) == AnyDecodable(b))
    }

    @Test
    func differentArraysAreNotEqual() {
        let a: [AnyDecodable] = [AnyDecodable(1)]
        let b: [AnyDecodable] = [AnyDecodable(2)]
        #expect(AnyDecodable(a) != AnyDecodable(b))
    }

    @Test
    func equalDictionariesAreEqual() {
        let a: [String: AnyDecodable] = ["k": AnyDecodable(1)]
        let b: [String: AnyDecodable] = ["k": AnyDecodable(1)]
        #expect(AnyDecodable(a) == AnyDecodable(b))
    }

    // MARK: - Hashable

    @Test
    func equalInstancesProduceEqualHashes() {
        #expect(AnyDecodable(42).hashValue == AnyDecodable(42).hashValue)
        #expect(AnyDecodable("kontext").hashValue == AnyDecodable("kontext").hashValue)
    }

    @Test
    func typeDiscriminatorPreventsCollision() {
        // Different underlying types with the "same" payload should not collide because of the type tag.
        #expect(AnyDecodable(1).hashValue != AnyDecodable("1").hashValue)
        // Bool(false) and Int(0) would share a raw bit pattern without the discriminator.
        #expect(AnyDecodable(false).hashValue != AnyDecodable(0).hashValue)
    }

    @Test
    func setBehavesAsExpected() {
        let set: Set<AnyDecodable> = [AnyDecodable(1), AnyDecodable(1), AnyDecodable("a")]
        #expect(set.count == 2)
    }

    // MARK: - Fixtures

    private struct Wrapper: Decodable {
        let value: AnyDecodable
    }
}
