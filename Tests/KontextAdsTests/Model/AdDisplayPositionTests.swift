import Foundation
import Testing
@testable import KontextSwiftSDK

struct AdDisplayPositionTests {
    @Test
    func knownPositionsDecodeCorrectly() throws {
        #expect(try decode("afterAssistantMessage") == .afterAssistantMessage)
        #expect(try decode("afterUserMessage") == .afterUserMessage)
        #expect(try decode("unknown") == .unknown)
    }

    @Test
    func unknownRawValueFallsBackToUnknown() throws {
        #expect(try decode("before") == .unknown)
        #expect(try decode("") == .unknown)
        #expect(try decode("AfterAssistantMessage") == .unknown)  // case-sensitive
    }

    @Test
    func rawValuesMatchCaseNames() {
        #expect(AdDisplayPosition.afterAssistantMessage.rawValue == "afterAssistantMessage")
        #expect(AdDisplayPosition.afterUserMessage.rawValue == "afterUserMessage")
        #expect(AdDisplayPosition.unknown.rawValue == "unknown")
    }
}

private func decode(_ string: String) throws -> AdDisplayPosition {
    let data = try JSONEncoder().encode(string)
    return try JSONDecoder().decode(AdDisplayPosition.self, from: data)
}
