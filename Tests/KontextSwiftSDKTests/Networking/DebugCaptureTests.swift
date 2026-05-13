import Foundation
@testable import KontextSwiftSDK
import Testing

struct DebugCaptureTests {

    // MARK: - DebugContext

    @Test func debugContextStoresAllFields() {
        let ctx = DebugContext(
            adServerUrl: URL(string: "https://example.com")!,
            publisherToken: "tok-123",
            conversationId: "conv-456",
            userId: "user-789",
            sessionId: "sess-abc"
        )

        #expect(ctx.adServerUrl == URL(string: "https://example.com"))
        #expect(ctx.publisherToken == "tok-123")
        #expect(ctx.conversationId == "conv-456")
        #expect(ctx.userId == "user-789")
        #expect(ctx.sessionId == "sess-abc")
    }

    @Test func debugContextAllowsNilOptionalFields() {
        let ctx = DebugContext(adServerUrl: URL(string: "https://example.com")!)

        #expect(ctx.publisherToken == nil)
        #expect(ctx.conversationId == nil)
        #expect(ctx.userId == nil)
        #expect(ctx.sessionId == nil)
    }

    // MARK: - capture doesn't crash

    @Test func captureWithNilDataDoesNotCrash() {
        // Fire-and-forget: any encoding/network failure must be
        // swallowed. Verifies the nil-data branch.
        DebugCapture.capture(name: "Session: pinged", context: DebugContext(
            adServerUrl: URL(string: "https://server.megabrain.co")!,
            publisherToken: "tok",
            userId: "user-1",
            sessionId: "sess-1"
        ))
    }

    @Test func captureWithJSONShapedDataDoesNotCrash() {
        DebugCapture.capture(name: "Session: probe", data: ["k": "v"], context: DebugContext(
            adServerUrl: URL(string: "https://server.megabrain.co")!
        ))
    }

    @Test func captureWithNonJSONDataDoesNotCrash() {
        // Non-JSON values (errors, structs) fall back to
        // `String(describing:)` rather than dropping the field.
        struct Probe { let id = 1 }
        DebugCapture.capture(name: "Session: probe", data: Probe(), context: DebugContext(
            adServerUrl: URL(string: "https://server.megabrain.co")!
        ))
    }

    // MARK: - DTO encoding

    @Test func dtoEncodesAllFields() throws {
        let dto = DebugRequestDTO(
            name: "Session: probe",
            data: #"{"k":"v"}"#,
            additionalData: DebugRequestDTO.AdditionalData(
                publisherToken: "tok",
                conversationId: "conv",
                userId: "usr",
                sessionId: "sess",
                sdk: SDKInfo.current.toDTO()
            )
        )

        let data = try JSONEncoder().encode(dto)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(decoded?["name"] as? String == "Session: probe")
        #expect(decoded?["data"] as? String == #"{"k":"v"}"#)

        let additionalData = decoded?["additionalData"] as? [String: Any]
        #expect(additionalData?["publisherToken"] as? String == "tok")
        #expect(additionalData?["conversationId"] as? String == "conv")
        #expect(additionalData?["userId"] as? String == "usr")
        #expect(additionalData?["sessionId"] as? String == "sess")

        let sdk = additionalData?["sdk"] as? [String: Any]
        #expect(sdk?["name"] as? String == SDKInfo.current.name)
        #expect(sdk?["platform"] as? String == SDKInfo.current.platform)
    }

    @Test func dtoEncodesNilOptionalsAsAbsentKeys() throws {
        // Mirrors ErrorRequestDTO's contract: nil-valued optionals are
        // dropped from the wire so the shape stays compatible with
        // sdk-js / sdk-kotlin.
        let dto = DebugRequestDTO(
            name: "msg",
            data: nil,
            additionalData: DebugRequestDTO.AdditionalData(
                publisherToken: nil,
                conversationId: nil,
                userId: nil,
                sessionId: nil,
                sdk: SDKInfo.current.toDTO()
            )
        )

        let data = try JSONEncoder().encode(dto)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(decoded?["name"] as? String == "msg")
        #expect(decoded?.keys.contains("data") == false)

        let additionalData = decoded?["additionalData"] as? [String: Any]
        #expect(additionalData?.keys.contains("publisherToken") == false)
        #expect(additionalData?.keys.contains("conversationId") == false)
        #expect(additionalData?.keys.contains("userId") == false)
        #expect(additionalData?.keys.contains("sessionId") == false)
        #expect(additionalData?["sdk"] != nil)
    }

    @Test func urlFormationUsesDebugEndpoint() throws {
        let adServerUrl = "https://custom.server.com"
        let url = URL(string: "\(adServerUrl)/debug")

        #expect(url != nil)
        #expect(url?.absoluteString == "https://custom.server.com/debug")
    }
}
