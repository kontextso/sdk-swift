import Foundation
@testable import KontextSwiftSDK
import Testing

@MainActor
struct InitResponseDTODecodingTests {

    // MARK: - Helpers

    private func decode(_ json: String) throws -> InitResponseDTO {
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(InitResponseDTO.self, from: data)
    }

    // MARK: - preloadTimeout

    @Test func decodeResponseWithPreloadTimeout() throws {
        let json = """
        {
            "preloadTimeout": 8000,
            "enabled": true
        }
        """
        let response = try decode(json)

        #expect(response.preloadTimeout == 8000)
        #expect(response.enabled == true)
    }

    // MARK: - enabled

    @Test func decodeResponseWithEnabledFalse() throws {
        let json = """
        {
            "enabled": false
        }
        """
        let response = try decode(json)

        #expect(response.enabled == false)
        #expect(response.preloadTimeout == nil)
    }

    @Test func decodeResponseWithEnabledTrue() throws {
        let json = """
        {
            "enabled": true
        }
        """
        let response = try decode(json)

        #expect(response.enabled == true)
    }

    // MARK: - Empty / optional

    @Test func decodeEmptyResponseDefaultsEnabledToTrue() throws {
        // Empty body — only an explicit `enabled: false` should disable
        // the session, so the missing key collapses to the safe default.
        let json = """
        {}
        """
        let response = try decode(json)

        #expect(response.preloadTimeout == nil)
        #expect(response.enabled == true)
    }

    @Test func nullEnabledFallsBackToTrue() throws {
        let json = """
        {
            "preloadTimeout": null,
            "enabled": null
        }
        """
        let response = try decode(json)

        #expect(response.preloadTimeout == nil)
        #expect(response.enabled == true)
    }

    @Test func wrongTypeEnabledFallsBackToTrue() throws {
        // Server emitting a non-Bool for `enabled` is a server bug;
        // the tolerant decode keeps the session enabled rather than
        // accidentally disabling everyone.
        let json = """
        {
            "enabled": "yes"
        }
        """
        let response = try decode(json)

        #expect(response.enabled == true)
    }

    // MARK: - reportErrors / reportDebug

    @Test func decodeReportErrorsExplicitFalse() throws {
        // The kill-switch path: server flips `reportErrors: false` to
        // suppress `/error` POSTs from this user's SDK.
        let json = """
        {
            "reportErrors": false
        }
        """
        let response = try decode(json)

        #expect(response.reportErrors == false)
        #expect(response.reportDebug == false)
    }

    @Test func decodeReportDebugExplicitTrue() throws {
        // The opt-in path: server flips `reportDebug: true` to
        // forward debug events for this user.
        let json = """
        {
            "reportDebug": true
        }
        """
        let response = try decode(json)

        #expect(response.reportDebug == true)
        #expect(response.reportErrors == true)
    }

    @Test func missingReportFlagsUseDefaults() throws {
        // Empty body — `reportErrors` defaults to true (preserves
        // existing fire-and-forget behaviour); `reportDebug` defaults
        // to false (privacy: don't forward unless explicitly opted in).
        let json = "{}"
        let response = try decode(json)

        #expect(response.reportErrors == true)
        #expect(response.reportDebug == false)
    }

    @Test func nullReportFlagsFallBackToDefaults() throws {
        let json = """
        {
            "reportErrors": null,
            "reportDebug": null
        }
        """
        let response = try decode(json)

        #expect(response.reportErrors == true)
        #expect(response.reportDebug == false)
    }

    @Test func wrongTypeReportFlagsFallBackToDefaults() throws {
        // Tolerate server-side bugs that emit non-Bool values: keep
        // the safe default (don't accidentally enable forwarding).
        let json = """
        {
            "reportErrors": "no",
            "reportDebug": 1
        }
        """
        let response = try decode(json)

        #expect(response.reportErrors == true)
        #expect(response.reportDebug == false)
    }
}
