import Foundation
@testable import KontextSwiftSDK
import Testing

struct DateFormattingTests {

    @Test func iso8601StringHasMillisecondPrecision() {
        // 2024-01-15 10:30:00.123 UTC
        let date = Date(timeIntervalSince1970: 1705314600.123)
        let formatted = DateFormatting.iso8601String(from: date)

        #expect(formatted == "2024-01-15T10:30:00.123Z")
    }

    @Test func iso8601StringIncludesMillisEvenWhenZero() {
        // Whole-second timestamps still emit `.000` so the precision
        // contract matches sdk-js's `Date.toISOString()` exactly.
        let date = Date(timeIntervalSince1970: 1705314600)
        let formatted = DateFormatting.iso8601String(from: date)

        #expect(formatted == "2024-01-15T10:30:00.000Z")
    }

    @Test func iso8601StringEmitsUtcZSuffix() {
        let date = Date(timeIntervalSince1970: 0)
        let formatted = DateFormatting.iso8601String(from: date)

        #expect(formatted.hasSuffix("Z"))
        #expect(formatted == "1970-01-01T00:00:00.000Z")
    }
}
