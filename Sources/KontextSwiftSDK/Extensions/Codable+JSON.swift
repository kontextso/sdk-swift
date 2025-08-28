import Foundation

extension Encodable {
    func encodeToJSON() throws -> Any {
        let data = try JSONEncoder().encode(self)
        let jsonData = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = jsonData as? [String: Any] else {
            throw EncodingError.invalidValue(jsonData, EncodingError.Context(
                codingPath: [],
                debugDescription: "Failed to convert JSON data to dictionary."
            ))
        }
        return dictionary
    }
}

extension Decodable {
    init(fromJSON json: Any) throws {
        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        self = try JSONDecoder().decode(Self.self, from: data)
    }
}
