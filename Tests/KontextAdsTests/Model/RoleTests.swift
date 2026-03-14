import Foundation
import Testing
@testable import KontextSwiftSDK

struct RoleTests {
    @Test
    func knownRolesDecodeCorrectly() throws {
        #expect(try decode("user") == .user)
        #expect(try decode("assistant") == .assistant)
        #expect(try decode("unknown") == .unknown)
    }

    @Test
    func unknownRawValueFallsBackToUnknown() throws {
        #expect(try decode("moderator") == .unknown)
        #expect(try decode("") == .unknown)
        #expect(try decode("USER") == .unknown)  // case-sensitive
    }

    @Test
    func rawValuesMatchCaseNames() {
        #expect(Role.user.rawValue == "user")
        #expect(Role.assistant.rawValue == "assistant")
        #expect(Role.unknown.rawValue == "unknown")
    }
}

private func decode(_ string: String) throws -> Role {
    let data = try JSONEncoder().encode(string)
    return try JSONDecoder().decode(Role.self, from: data)
}
