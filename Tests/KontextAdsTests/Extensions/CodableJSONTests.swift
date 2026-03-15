import Foundation
import Testing
@testable import KontextSwiftSDK

struct CodableJSONTests {
    private struct Person: Codable, Equatable {
        let name: String
        let age: Int
    }

    @Test
    func encodeToJSON() throws {
        let person = Person(name: "Alice", age: 30)
        let json = try person.encodeToJSON()
        let dict = try #require(json as? [String: Any])
        #expect(dict["name"] as? String == "Alice")
        #expect(dict["age"] as? Int == 30)
    }

    @Test
    func decodeFromJSON() throws {
        let json: [String: Any] = ["name": "Bob", "age": 25]
        let person = try Person(fromJSON: json)
        #expect(person == Person(name: "Bob", age: 25))
    }

    @Test
    func encodeToJSONFailsForNonDictionary() throws {
        struct JustAnArray: Encodable {
            func encode(to encoder: Encoder) throws {
                var container = encoder.unkeyedContainer()
                try container.encode(1)
            }
        }
        #expect(throws: (any Error).self) {
            try JustAnArray().encodeToJSON()
        }
    }

    @Test
    func roundtrip() throws {
        let original = Person(name: "Charlie", age: 40)
        let json = try original.encodeToJSON()
        let decoded = try Person(fromJSON: json)
        #expect(decoded == original)
    }
}
