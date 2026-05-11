import Foundation
@testable import KontextSwiftSDK
import Testing

struct ImpressionTriggerTests {

    // MARK: - Raw values pin the wire format

    @Test func rawValuesMatchWireFormat() {
        // The rawValues are the literal strings the server sends and the
        // SDK uses to decide WHEN to start SKAdNetwork tracking.
        // Pin them — changing either is a wire-format break.
        #expect(ImpressionTrigger.immediate.rawValue == "immediate")
        #expect(ImpressionTrigger.component.rawValue == "component")
    }

    // MARK: - init(rawValue:)

    @Test func initFromKnownRawValueReturnsCase() {
        #expect(ImpressionTrigger(rawValue: "immediate") == .immediate)
        #expect(ImpressionTrigger(rawValue: "component") == .component)
    }

    @Test func initFromUnknownRawValueReturnsNil() {
        // Unknown wire values are rejected — server-side typos and
        // SDK-version mismatches don't get silently mapped to a default.
        #expect(ImpressionTrigger(rawValue: "immedate") == nil)
        #expect(ImpressionTrigger(rawValue: "page-loaded") == nil)
        #expect(ImpressionTrigger(rawValue: "") == nil)
    }

    // MARK: - Equatable / Hashable

    @Test func hashableDeduplicatesInSet() {
        let set: Set<ImpressionTrigger> = [.immediate, .component, .immediate]
        #expect(set.count == 2)
    }
}
