import Foundation
import Testing
@testable import KontextSwiftSDK

/// Decoding tests for IframeEvent, which routes by `type` string and
/// has fallbacks for malformed/unknown data.
struct IframeEventDTOTests {
    private func decode(_ json: String) throws -> IframeEvent {
        try JSONDecoder().decode(IframeEvent.self, from: json.data(using: .utf8)!)
    }

    // MARK: - Simple type strings

    @Test
    func decodesInitIframe() throws {
        let event = try decode(#"{"type": "init-iframe"}"#)
        #expect(event == .initIframe)
    }

    @Test
    func decodesShowIframe() throws {
        let event = try decode(#"{"type": "show-iframe"}"#)
        #expect(event == .showIframe)
    }

    @Test
    func decodesHideIframe() throws {
        let event = try decode(#"{"type": "hide-iframe"}"#)
        #expect(event == .hideIframe)
    }

    @Test
    func decodesAdDoneIframe() throws {
        let event = try decode(#"{"type": "ad-done-iframe"}"#)
        #expect(event == .adDoneIframe)
    }

    @Test
    func unknownTypeFallsBackToUnknown() throws {
        let event = try decode(#"{"type": "not-a-real-type"}"#)
        if case .unknown(let type) = event {
            #expect(type == "not-a-real-type")
        } else {
            Issue.record("Expected .unknown, got \(event)")
        }
    }

    // MARK: - View, click, resize

    @Test
    func decodesViewIframeWithFullData() throws {
        let event = try decode(#"""
        {
          "type": "view-iframe",
          "data": { "id": "bid-1", "content": "ad", "messageId": "m-1", "code": "inlineAd" }
        }
        """#)
        if case .viewIframe(let data) = event {
            #expect(data.id == "bid-1")
            #expect(data.content == "ad")
            #expect(data.messageId == "m-1")
            #expect(data.code == "inlineAd")
        } else {
            Issue.record("Expected .viewIframe")
        }
    }

    @Test
    func decodesClickIframeWithFullData() throws {
        let event = try decode(#"""
        {
          "type": "click-iframe",
          "data": { "id": "bid-1", "content": "ad", "messageId": "m-1", "url": "https://example.com/x" }
        }
        """#)
        if case .clickIframe(let data) = event {
            #expect(data.url?.absoluteString == "https://example.com/x")
            #expect(data.messageId == "m-1")
        } else {
            Issue.record("Expected .clickIframe")
        }
    }

    @Test
    func decodesClickIframeWithoutURL() throws {
        let event = try decode(#"""
        {
          "type": "click-iframe",
          "data": { "id": "bid-1", "content": "ad", "messageId": "m-1" }
        }
        """#)
        if case .clickIframe(let data) = event {
            #expect(data.url == nil)
        } else {
            Issue.record("Expected .clickIframe")
        }
    }

    @Test
    func decodesResizeIframe() throws {
        let event = try decode(#"""
        { "type": "resize-iframe", "data": { "height": 320.5 } }
        """#)
        if case .resizeIframe(let data) = event {
            #expect(data.height == 320.5)
        } else {
            Issue.record("Expected .resizeIframe")
        }
    }

    // MARK: - Error iframe

    @Test
    func decodesErrorIframeWithData() throws {
        let event = try decode(#"""
        { "type": "error-iframe", "data": { "message": "boom", "errorType": "timeout" } }
        """#)
        if case .errorIframe(let data) = event {
            #expect(data?.message == "boom")
            #expect(data?.errorType == "timeout")
        } else {
            Issue.record("Expected .errorIframe")
        }
    }

    @Test
    func decodesErrorIframeWithoutData() throws {
        let event = try decode(#"{"type": "error-iframe"}"#)
        if case .errorIframe(let data) = event {
            #expect(data == nil)
        } else {
            Issue.record("Expected .errorIframe")
        }
    }

    // MARK: - Component iframe family

    @Test
    func decodesOpenComponentIframe() throws {
        let event = try decode(#"""
        {
          "type": "open-component-iframe",
          "data": { "code": "inline", "component": "modal", "timeout": 3000 }
        }
        """#)
        if case .openComponentIframe(let data) = event {
            #expect(data.code == "inline")
            #expect(data.component == .modal)
            #expect(data.timeout == 3000)
        } else {
            Issue.record("Expected .openComponentIframe")
        }
    }

    @Test
    func openComponentIframeDefaultsTimeoutWhenZero() throws {
        let event = try decode(#"""
        {
          "type": "open-component-iframe",
          "data": { "code": "inline", "component": "modal", "timeout": 0 }
        }
        """#)
        if case .openComponentIframe(let data) = event {
            #expect(data.timeout == IframeEvent.OpenComponentIframeDataDTO.defaultTimeoutMilliseconds)
        } else {
            Issue.record("Expected .openComponentIframe")
        }
    }

    @Test
    func openComponentIframeDefaultsTimeoutWhenMissing() throws {
        let event = try decode(#"""
        {
          "type": "open-component-iframe",
          "data": { "code": "inline", "component": "modal" }
        }
        """#)
        if case .openComponentIframe(let data) = event {
            #expect(data.timeout == IframeEvent.OpenComponentIframeDataDTO.defaultTimeoutMilliseconds)
        } else {
            Issue.record("Expected .openComponentIframe")
        }
    }

    @Test
    func openComponentIframeAcceptsIntegerTimeout() throws {
        // Some iframe senders serialize timeout as Int rather than Double.
        let event = try decode(#"""
        {
          "type": "open-component-iframe",
          "data": { "code": "inline", "component": "modal", "timeout": 1500 }
        }
        """#)
        if case .openComponentIframe(let data) = event {
            #expect(data.timeout == 1500)
        } else {
            Issue.record("Expected .openComponentIframe")
        }
    }

    @Test
    func decodesOpenSKOverlayIframeAlias() throws {
        let event = try decode(#"""
        {
          "type": "open-skoverlay-iframe",
          "data": { "position": "bottom", "dismissible": true }
        }
        """#)
        if case .openComponentIframe(let data) = event {
            #expect(data.component == .skoverlay)
            #expect(data.position == "bottom")
            #expect(data.dismissible == true)
        } else {
            Issue.record("Expected .openComponentIframe(.skoverlay)")
        }
    }

    @Test
    func decodesCloseSKOverlayAlias() throws {
        let event = try decode(#"{"type": "close-skoverlay-iframe"}"#)
        if case .closeComponentIframe(let data) = event {
            #expect(data.component == .skoverlay)
        } else {
            Issue.record("Expected .closeComponentIframe(.skoverlay)")
        }
    }

    @Test
    func openComponentIframeWithMalformedDataFallsBackToUnknown() throws {
        let event = try decode(#"""
        { "type": "open-component-iframe", "data": { "wrong": "shape" } }
        """#)
        if case .unknown(let type) = event {
            #expect(type == "open-component-iframe")
        } else {
            Issue.record("Expected .unknown")
        }
    }

    @Test
    func decodesInitAndCloseAndAdDoneComponentIframes() throws {
        let init_ = try decode(#"""
        { "type": "init-component-iframe", "data": { "code": "c", "component": "modal" } }
        """#)
        let close = try decode(#"""
        { "type": "close-component-iframe", "data": { "code": "c", "component": "modal" } }
        """#)
        let done = try decode(#"""
        { "type": "ad-done-component-iframe", "data": { "code": "c", "component": "modal" } }
        """#)

        guard case .initComponentIframe = init_ else { Issue.record("init"); return }
        guard case .closeComponentIframe = close else { Issue.record("close"); return }
        guard case .adDoneComponentIframe = done else { Issue.record("done"); return }
    }

    @Test
    func decodesErrorComponentIframe() throws {
        let event = try decode(#"""
        {
          "type": "error-component-iframe",
          "data": { "code": "c", "component": "modal", "message": "m", "errorType": "t" }
        }
        """#)
        if case .errorComponentIframe(let data) = event {
            #expect(data.code == "c")
            #expect(data.component == .modal)
            #expect(data.message == "m")
            #expect(data.errorType == "t")
        } else {
            Issue.record("Expected .errorComponentIframe")
        }
    }

    // MARK: - event-iframe routes through EventIframeDataDTO

    @Test
    func decodesEventIframeAdViewed() throws {
        let event = try decode(#"""
        {
          "type": "event-iframe",
          "data": {
            "name": "ad.viewed",
            "code": "inlineAd",
            "payload": { "id": "550e8400-e29b-41d4-a716-446655440000", "content": "c", "messageId": "m" }
          }
        }
        """#)
        guard case .eventIframe(let data) = event else { Issue.record("Expected .eventIframe"); return }
        #expect(data.name == "ad.viewed")
        #expect(data.code == "inlineAd")
        if case .viewed(let payload) = data.type {
            #expect(payload?.messageId == "m")
            #expect(payload?.content == "c")
        } else {
            Issue.record("Expected .viewed payload")
        }
    }

    @Test
    func decodesEventIframeUnknownNameFallsToEvent() throws {
        // Unknown event name → .event([String: AnyDecodable])
        let event = try decode(#"""
        {
          "type": "event-iframe",
          "data": {
            "name": "my.custom.event",
            "code": "x",
            "payload": { "k": "v", "n": 42 }
          }
        }
        """#)
        guard case .eventIframe(let data) = event else { Issue.record("Expected .eventIframe"); return }
        #expect(data.name == "my.custom.event")
        if case .event(let dict) = data.type {
            #expect(dict["k"]?.value as? String == "v")
            #expect(dict["n"]?.value as? Int == 42)
        } else {
            Issue.record("Expected .event(dict)")
        }
    }

    @Test
    func decodesEventIframeKnownNameWithoutPayload() throws {
        // Payload is optional in the decoder — known names should degrade to nil.
        let event = try decode(#"""
        { "type": "event-iframe", "data": { "name": "video.started", "code": "x" } }
        """#)
        guard case .eventIframe(let data) = event else { Issue.record("Expected .eventIframe"); return }
        if case .videoStarted(let payload) = data.type {
            #expect(payload == nil)
        } else {
            Issue.record("Expected .videoStarted")
        }
    }

    @Test
    func decodesEventIframeErrorPayload() throws {
        let event = try decode(#"""
        {
          "type": "event-iframe",
          "data": {
            "name": "ad.error",
            "code": "x",
            "payload": { "message": "oops", "errCode": "E42" }
          }
        }
        """#)
        guard case .eventIframe(let data) = event else { Issue.record(""); return }
        if case .error(let payload) = data.type {
            #expect(payload?.message == "oops")
            #expect(payload?.errCode == "E42")
        } else {
            Issue.record("Expected .error payload")
        }
    }

    @Test
    func decodesEventIframeClickedPayload() throws {
        let event = try decode(#"""
        {
          "type": "event-iframe",
          "data": {
            "name": "ad.clicked",
            "code": "x",
            "payload": {
              "id": "550e8400-e29b-41d4-a716-446655440000",
              "content": "c",
              "messageId": "m",
              "url": "https://example.com",
              "format": "inline",
              "area": "button"
            }
          }
        }
        """#)
        guard case .eventIframe(let data) = event else { Issue.record(""); return }
        if case .clicked(let payload) = data.type {
            #expect(payload?.url.absoluteString == "https://example.com")
            #expect(payload?.format == "inline")
            #expect(payload?.area == "button")
        } else {
            Issue.record("Expected .clicked payload")
        }
    }

    @Test
    func decodesEventIframeRewardGranted() throws {
        let event = try decode(#"""
        {
          "type": "event-iframe",
          "data": {
            "name": "reward.granted",
            "code": "rewardedAd",
            "payload": { "id": "550e8400-e29b-41d4-a716-446655440000" }
          }
        }
        """#)
        guard case .eventIframe(let data) = event else { Issue.record(""); return }
        if case .rewardGranted(let payload) = data.type {
            #expect(payload?.id.uuidString == "550E8400-E29B-41D4-A716-446655440000")
        } else {
            Issue.record("Expected .rewardGranted")
        }
    }
}
