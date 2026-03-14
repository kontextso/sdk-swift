import Foundation
import Testing
@testable import KontextSwiftSDK

struct ImpressionTriggerTests {
    @Test
    func knownValuesDecodeCorrectly() throws {
        #expect(try decode("immediate") == .immediate)
        #expect(try decode("component") == .component)
    }

    @Test
    func unknownRawValueFallsBackToImmediate() throws {
        #expect(try decode("unknown") == .immediate)
        #expect(try decode("") == .immediate)
        #expect(try decode("Immediate") == .immediate)  // case-sensitive
    }

    @Test
    func rawValuesMatchCaseNames() {
        #expect(ImpressionTrigger.immediate.rawValue == "immediate")
        #expect(ImpressionTrigger.component.rawValue == "component")
    }
}

private func decode(_ string: String) throws -> ImpressionTrigger {
    let data = try JSONEncoder().encode(string)
    return try JSONDecoder().decode(ImpressionTrigger.self, from: data)
}
