import Foundation
@testable import KontextSwiftSDK
import Testing

struct UserEventNameTests {

    // MARK: - Raw values pin the wire format

    @Test func userTypingStartedRawValue() {
        // The rawValue is the literal string the iframe / server expects.
        // Pin it explicitly — changing it is a wire-format break.
        #expect(UserEventName.userTypingStarted.rawValue == "user.typing.started")
    }

    // MARK: - init(rawValue:)

    @Test func initFromKnownRawValueReturnsCase() {
        let result = UserEventName(rawValue: "user.typing.started")
        #expect(result == .userTypingStarted)
    }

    @Test func initFromUnknownRawValueReturnsNil() {
        // Unknown names are rejected — typos and SDK-version mismatches don't
        // silently broadcast to the iframe.
        #expect(UserEventName(rawValue: "user.typing.startd") == nil)
        #expect(UserEventName(rawValue: "user.unknown.event") == nil)
        #expect(UserEventName(rawValue: "") == nil)
    }

    @Test func initFromKnownRawValueRoundTrips() {
        // rawValue → init → rawValue should give back the same string.
        let name = UserEventName.userTypingStarted
        let roundtripped = UserEventName(rawValue: name.rawValue)
        #expect(roundtripped == name)
        #expect(roundtripped?.rawValue == name.rawValue)
    }

    // MARK: - Equatable / Hashable

    @Test func equality() {
        #expect(UserEventName.userTypingStarted == .userTypingStarted)
        // Two values constructed from the same raw value compare equal.
        let a = UserEventName(rawValue: "user.typing.started")
        let b = UserEventName(rawValue: "user.typing.started")
        #expect(a == b)
    }

    @Test func hashableDeduplicatesInSet() {
        let set: Set<UserEventName> = [.userTypingStarted, .userTypingStarted]
        #expect(set.count == 1)
        #expect(set.contains(.userTypingStarted))
    }
}
