import Foundation
@testable import KontextSwiftSDK
import Testing

@MainActor
struct PreloadBodyTests {

    // MARK: - Helpers

    private func makeConfig(
        publisherToken: String = "test-token",
        userId: String = "test-user",
        conversationId: String = "test-conv",
        enabledPlacementCodes: [String] = ["inlineAd"],
        character: Character? = nil,
        regulatory: Regulatory? = nil,
        userEmail: String? = nil
    ) -> ResolvedConfig {
        return ResolvedConfig(
            publisherToken: publisherToken,
            userId: userId,
            conversationId: conversationId,
            enabledPlacementCodes: enabledPlacementCodes,
            adServerUrl: "http://0.0.0.0:1",
            character: character,
            variantId: nil,
            regulatory: regulatory,
            userEmail: userEmail,
            advertisingId: nil,
            vendorId: nil,
            requestTrackingAuthorization: false,
            onEvent: nil,
            onDebugEvent: nil
        )
    }

    /// Builds a preload request body the same way Preload does internally,
    /// and returns the serialized dictionary for assertion.
    private func buildBody(
        config: ResolvedConfig? = nil,
        sessionId: String? = nil,
        isDisabled: Bool = false,
        messages: [Message]
    ) -> (body: [String: Any]?, request: URLRequest?) {
        let cfg = config ?? makeConfig()

        guard let url = URL(string: "\(cfg.adServerUrl)/preload") else {
            return (nil, nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(cfg.publisherToken, forHTTPHeaderField: "Kontextso-Publisher-Token")
        request.setValue(isDisabled ? "1" : "0", forHTTPHeaderField: "Kontextso-Is-Disabled")

        let messagesPayload: [[String: Any]] = messages.map { msg in
            [
                "id": msg.id,
                "role": msg.role.rawValue,
                "content": msg.content,
                "createdAt": ISO8601DateFormatter().string(from: msg.createdAt),
            ]
        }

        var body: [String: Any] = [
            "messages": messagesPayload,
            "publisherToken": cfg.publisherToken,
            "userId": cfg.userId,
            "conversationId": cfg.conversationId,
            "enabledPlacementCodes": cfg.enabledPlacementCodes,
            "sdk": [
                "name": SDKInfo.current.name,
                "platform": SDKInfo.current.platform,
                "version": SDKInfo.current.version,
            ],
        ]

        if let sid = sessionId {
            body["sessionId"] = sid
        }
        if let character = cfg.character {
            var charDict: [String: Any] = ["id": character.id, "name": character.name]
            if let v = character.avatarUrl { charDict["avatarUrl"] = v.absoluteString }
            if let v = character.greeting { charDict["greeting"] = v }
            if let v = character.persona { charDict["persona"] = v }
            if let v = character.tags { charDict["tags"] = v }
            if let v = character.isNsfw { charDict["isNsfw"] = v }
            body["character"] = charDict
        }
        if let userEmail = cfg.userEmail {
            body["userEmail"] = userEmail
        }
        if let regulatory = cfg.regulatory {
            var regDict: [String: Any] = [:]
            if let v = regulatory.gdpr { regDict["gdpr"] = v }
            if let v = regulatory.gdprConsent { regDict["gdprConsent"] = v }
            if let v = regulatory.coppa { regDict["coppa"] = v }
            if let v = regulatory.gpp { regDict["gpp"] = v }
            if let v = regulatory.gppSid { regDict["gppSid"] = v }
            if let v = regulatory.usPrivacy { regDict["usPrivacy"] = v }
            body["regulatory"] = regDict
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        // Parse the body back for assertions
        let parsed = request.httpBody.flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
        }

        return (parsed, request)
    }

    // MARK: - Body field tests

    @Test func bodyIncludesPublisherTokenUserIdConversationId() {
        let messages = [Message(id: "u1", role: .user, content: "Hello")]
        let (body, _) = buildBody(messages: messages)

        #expect(body?["publisherToken"] as? String == "test-token")
        #expect(body?["userId"] as? String == "test-user")
        #expect(body?["conversationId"] as? String == "test-conv")
    }

    @Test func bodyIncludesMessagesArray() {
        let messages = [
            Message(id: "u1", role: .user, content: "Hello"),
            Message(id: "a1", role: .assistant, content: "Hi there"),
        ]
        let (body, _) = buildBody(messages: messages)

        let msgs = body?["messages"] as? [[String: Any]]
        #expect(msgs?.count == 2)
        #expect(msgs?[0]["id"] as? String == "u1")
        #expect(msgs?[0]["role"] as? String == "user")
        #expect(msgs?[0]["content"] as? String == "Hello")
        #expect(msgs?[1]["id"] as? String == "a1")
        #expect(msgs?[1]["role"] as? String == "assistant")
    }

    @Test func bodyIncludesEnabledPlacementCodesAsArray() {
        let config = makeConfig(enabledPlacementCodes: ["inlineAd", "banner"])
        let messages = [Message(id: "u1", role: .user, content: "Hello")]
        let (body, _) = buildBody(config: config, messages: messages)

        let codes = body?["enabledPlacementCodes"] as? [String]
        #expect(codes == ["inlineAd", "banner"])
    }

    @Test func bodyIncludesSessionIdWhenSet() {
        // sessionId is now a UUID throughout the SDK; the wire format is
        // still a string, so the body builder mirrors that.
        let sessionUuid = "11111111-1111-1111-1111-111111111111"
        let messages = [Message(id: "u1", role: .user, content: "Hello")]
        let (body, _) = buildBody(sessionId: sessionUuid, messages: messages)

        #expect(body?["sessionId"] as? String == sessionUuid)
    }

    @Test func bodyExcludesSessionIdWhenNil() {
        let messages = [Message(id: "u1", role: .user, content: "Hello")]
        let (body, _) = buildBody(sessionId: nil, messages: messages)

        #expect(body?["sessionId"] == nil)
    }

    @Test func bodyIncludesRegulatoryWhenProvided() {
        let reg = Regulatory(gdpr: 1, gdprConsent: "consent-string", coppa: 0)
        let config = makeConfig(regulatory: reg)
        let messages = [Message(id: "u1", role: .user, content: "Hello")]
        let (body, _) = buildBody(config: config, messages: messages)

        let regDict = body?["regulatory"] as? [String: Any]
        #expect(regDict != nil)
        #expect(regDict?["gdpr"] as? Int == 1)
        #expect(regDict?["gdprConsent"] as? String == "consent-string")
        #expect(regDict?["coppa"] as? Int == 0)
    }

    @Test func bodyIncludesCharacterWhenProvided() {
        let char = Character(id: "char-1", name: "TestBot", avatarUrl: URL(string: "https://example.com/avatar.png")!)
        let config = makeConfig(character: char)
        let messages = [Message(id: "u1", role: .user, content: "Hello")]
        let (body, _) = buildBody(config: config, messages: messages)

        let charDict = body?["character"] as? [String: Any]
        #expect(charDict != nil)
        #expect(charDict?["id"] as? String == "char-1")
        #expect(charDict?["name"] as? String == "TestBot")
        #expect(charDict?["avatarUrl"] as? String == "https://example.com/avatar.png")
    }

    // MARK: - Headers

    @Test func requestIncludesIsDisabledHeaderWhenDisabled() {
        let messages = [Message(id: "u1", role: .user, content: "Hello")]
        let (_, request) = buildBody(isDisabled: true, messages: messages)

        #expect(request?.value(forHTTPHeaderField: "Kontextso-Is-Disabled") == "1")
    }

    @Test func requestIncludesContentTypeJsonHeader() {
        let messages = [Message(id: "u1", role: .user, content: "Hello")]
        let (_, request) = buildBody(messages: messages)

        #expect(request?.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }
}
