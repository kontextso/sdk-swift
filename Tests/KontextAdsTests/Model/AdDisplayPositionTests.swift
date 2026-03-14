import Foundation
import Testing
@testable import KontextSwiftSDK

struct AdDisplayPositionTests {
    @Test
    func knownPositionsDecodeCorrectly() throws {
        #expect(try decode("afterAssistantMessage") == .afterAssistantMessage)
        #expect(try decode("afterUserMessage") == .afterUserMessage)
    }

    @Test
    func unknownRawValueFallsBackToAfterAssistantMessage() throws {
        #expect(try decode("unknown") == .afterAssistantMessage)
        #expect(try decode("") == .afterAssistantMessage)
        #expect(try decode("AfterAssistantMessage") == .afterAssistantMessage)  // case-sensitive
    }

    @Test
    func rawValuesMatchCaseNames() {
        #expect(AdDisplayPosition.afterAssistantMessage.rawValue == "afterAssistantMessage")
        #expect(AdDisplayPosition.afterUserMessage.rawValue == "afterUserMessage")
    }
}

private func decode(_ string: String) throws -> AdDisplayPosition {
    let data = try JSONEncoder().encode(string)
    return try JSONDecoder().decode(AdDisplayPosition.self, from: data)
}
