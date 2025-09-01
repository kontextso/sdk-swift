import Foundation

struct AnyDecodable: Decodable, Hashable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyDecodable].self) {
            value = arrayValue
        } else if let dictValue = try? container.decode([String: AnyDecodable].self) {
            value = dictValue
        } else {
            throw DecodingError.typeMismatch(
                AnyDecodable.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type")
            )
        }
    }

    // MARK: Equatable
    static func == (lhs: AnyDecodable, rhs: AnyDecodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case (let lhs as Int, let rhs as Int):
            lhs == rhs
        case (let lhs as Double, let rhs as Double):
            lhs == rhs
        case (let lhs as String, let rhs as String):
            lhs == rhs
        case (let lhs as Bool, let rhs as Bool):
            lhs == rhs
        case (let lhs as [AnyDecodable], let rhs as [AnyDecodable]):
            lhs == rhs
        case (let lhs as [String: AnyDecodable], let rhs as [String: AnyDecodable]):
            lhs == rhs
        default:
            false
        }
    }

    // MARK: Hashable
    func hash(into hasher: inout Hasher) {
        switch value {
        case let intValue as Int:
            hasher.combine(0) // Type discriminator
            hasher.combine(intValue)
        case let doubleValue as Double:
            hasher.combine(1)
            hasher.combine(doubleValue)
        case let stringValue as String:
            hasher.combine(2)
            hasher.combine(stringValue)
        case let boolValue as Bool:
            hasher.combine(3)
            hasher.combine(boolValue)
        case let arrayValue as [AnyDecodable]:
            hasher.combine(4)
            hasher.combine(arrayValue)
        case let dictValue as [String: AnyDecodable]:
            hasher.combine(5)
            hasher.combine(dictValue)
        default:
            hasher.combine(6) // For unknown types
        }
    }
}
