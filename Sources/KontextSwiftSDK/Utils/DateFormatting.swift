import Foundation

/// Centralised date → wire-format conversion.
///
/// Every `Date` we ship to the server is encoded as an ISO 8601 string
/// **with millisecond precision** (e.g. `"2024-01-01T00:00:00.000Z"`)
/// to match sdk-js's `JSON.stringify(date)` (which calls
/// `Date.toISOString()`). The default `ISO8601DateFormatter` settings
/// drop sub-second precision, which would silently coarsen timestamps
/// vs. sdk-js — so always go through this helper.
///
/// Single shared formatter instance: `ISO8601DateFormatter` is
/// thread-safe for `string(from:)` (per Apple docs) and constructing
/// it per-call is expensive.
enum DateFormatting {
    // `nonisolated(unsafe)` because `ISO8601DateFormatter` predates
    // Swift Concurrency and isn't declared `Sendable`, but Apple docs
    // confirm `string(from:)` is thread-safe — so this static let is
    // safe to share across actors despite the compiler's caution.
    nonisolated(unsafe) private static let iso8601MillisecondFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Returns an ISO 8601 string with millisecond precision in UTC.
    static func iso8601String(from date: Date) -> String {
        iso8601MillisecondFormatter.string(from: date)
    }
}
