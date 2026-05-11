import CoreGraphics
@testable import KontextSwiftSDK
import Testing

/// Pins the parser-side helpers on `IframeEvent` data types — closing
/// the test gap where parsing logic was previously only covered
/// indirectly through `Ad.handleIframeEvent` consumer behaviour.
@MainActor
struct IframeEventParsingTests {

    // MARK: - Target

    @Test func targetFromValidStrings() {
        #expect(IframeEvent.Target.from("browser") == .browser)
        #expect(IframeEvent.Target.from("in-app") == .inApp)
    }

    @Test func targetFromMissingValueDefaultsToBrowser() {
        #expect(IframeEvent.Target.from(nil) == .browser)
    }

    @Test func targetFromUnknownStringDefaultsToBrowser() {
        // sdk-js's documented behaviour: unknown target falls back to
        // the system browser. Defaulting (rather than dropping) means
        // the click handler always has a concrete value.
        #expect(IframeEvent.Target.from("popup") == .browser)
        #expect(IframeEvent.Target.from("") == .browser)
    }

    @Test func targetFromNonStringDefaultsToBrowser() {
        // A buggy iframe sending the wrong JS type must not crash.
        #expect(IframeEvent.Target.from(42) == .browser)
        #expect(IframeEvent.Target.from(true) == .browser)
        #expect(IframeEvent.Target.from(["nested": "dict"]) == .browser)
    }

    // MARK: - AdDoneData

    @Test func adDoneDataParsesAllFields() {
        let dict: [String: Any] = [
            "id": "bid-123",
            "content": "rendered-html",
            "messageId": "msg-7",
            "cachedContent": "<html>cached</html>",
        ]
        let data = IframeEvent.AdDoneData.from(dict: dict)
        #expect(data.id == "bid-123")
        #expect(data.content == "rendered-html")
        #expect(data.messageId == "msg-7")
        #expect(data.cachedContent == "<html>cached</html>")
    }

    @Test func adDoneDataParsesEmptyDict() {
        // Wire format treats every field as optional — empty dict is
        // valid and produces an all-nil struct.
        let data = IframeEvent.AdDoneData.from(dict: [:])
        #expect(data.id == nil)
        #expect(data.content == nil)
        #expect(data.messageId == nil)
        #expect(data.cachedContent == nil)
    }

    @Test func adDoneDataDropsWrongTypes() {
        // Non-string values for string fields decay to nil instead of
        // crashing — defensive parsing per the file-level policy.
        let dict: [String: Any] = [
            "id": 12345, // number, not string
            "content": true,
            "messageId": ["nested": "dict"],
            "cachedContent": "<html>valid</html>",
        ]
        let data = IframeEvent.AdDoneData.from(dict: dict)
        #expect(data.id == nil)
        #expect(data.content == nil)
        #expect(data.messageId == nil)
        #expect(data.cachedContent == "<html>valid</html>")
    }

    // MARK: - SKOverlayData

    @Test func skOverlayDataParsesAllFields() {
        let dict: [String: Any] = [
            "position": "bottom",
            "dismissible": true,
            "appStoreId": "1234567890",
        ]
        let data = IframeEvent.SKOverlayData.from(dict: dict)
        #expect(data.position == "bottom")
        #expect(data.dismissible == true)
        #expect(data.appStoreId == "1234567890")
    }

    @Test func skOverlayDataParsesEmptyDict() {
        let data = IframeEvent.SKOverlayData.from(dict: [:])
        #expect(data.position == nil)
        #expect(data.dismissible == nil)
        #expect(data.appStoreId == nil)
    }

    @Test func skOverlayDataDropsWrongTypes() {
        let dict: [String: Any] = [
            "position": 0, // number, not string
            "dismissible": "yes", // string, not bool
            "appStoreId": ["nested": "dict"],
        ]
        let data = IframeEvent.SKOverlayData.from(dict: dict)
        #expect(data.position == nil)
        #expect(data.dismissible == nil)
        #expect(data.appStoreId == nil)
    }

    // MARK: - ResizeData

    @Test func resizeDataParsesCGFloat() {
        let data = IframeEvent.ResizeData.from(dict: ["height": CGFloat(120.5)])
        #expect(data?.height == 120.5)
    }

    @Test func resizeDataParsesDouble() {
        let data = IframeEvent.ResizeData.from(dict: ["height": Double(200.25)])
        #expect(data?.height == 200.25)
    }

    @Test func resizeDataParsesInt() {
        let data = IframeEvent.ResizeData.from(dict: ["height": 300])
        #expect(data?.height == 300)
    }

    @Test func resizeDataReturnsNilOnMissingHeight() {
        // Missing field → nil → caller drops the event entirely.
        #expect(IframeEvent.ResizeData.from(dict: [:]) == nil)
    }

    @Test func resizeDataReturnsNilOnWrongType() {
        // Non-numeric height → nil. No crash.
        #expect(IframeEvent.ResizeData.from(dict: ["height": "tall"]) == nil)
        #expect(IframeEvent.ResizeData.from(dict: ["height": ["nested": 1]]) == nil)
    }

    // MARK: - EventData

    @Test func eventDataParsesNameAndPayload() {
        let dict: [String: Any] = [
            "name": "ad.viewed",
            "payload": ["id": "bid-1", "revenue": 0.05],
        ]
        let data = IframeEvent.EventData.from(dict: dict)
        #expect(data.name == "ad.viewed")
        #expect(data.payload?["id"] as? String == "bid-1")
        #expect(data.payload?["revenue"] as? Double == 0.05)
    }

    @Test func eventDataMissingNameDecaysToEmpty() {
        // Missing/non-string name → "" — Ad.handleAdEvent's default
        // case drops unknown names, so "" is harmless downstream.
        let data = IframeEvent.EventData.from(dict: [:])
        #expect(data.name == "")
        #expect(data.payload == nil)
    }

    @Test func eventDataMissingPayloadStaysNil() {
        let data = IframeEvent.EventData.from(dict: ["name": "ad.clicked"])
        #expect(data.name == "ad.clicked")
        #expect(data.payload == nil)
    }

    // MARK: - ClickData

    @Test func clickDataParsesAllFields() {
        let dict: [String: Any] = [
            "id": "bid-clicked",
            "content": "banner-cta",
            "messageId": "msg-7",
            "url": "https://example.com/click",
            "target": "in-app",
            "fallbackUrl": "https://example.com/fallback",
            "appStoreId": "1234567890",
        ]
        let data = IframeEvent.ClickData.from(dict: dict)
        #expect(data.id == "bid-clicked")
        #expect(data.content == "banner-cta")
        #expect(data.messageId == "msg-7")
        #expect(data.url == "https://example.com/click")
        #expect(data.target == .inApp)
        #expect(data.fallbackUrl == "https://example.com/fallback")
        #expect(data.appStoreId == "1234567890")
    }

    @Test func clickDataDefaultsTargetWhenMissing() {
        let data = IframeEvent.ClickData.from(dict: ["url": "https://example.com"])
        #expect(data.url == "https://example.com")
        #expect(data.target == .browser)
        #expect(data.id == nil)
    }

    @Test func clickDataDropsWrongTypes() {
        // Each field independently handles wrong types via `as?`.
        let dict: [String: Any] = [
            "id": 12345, // number, not string
            "url": ["nested": "dict"],
            "target": 42,
        ]
        let data = IframeEvent.ClickData.from(dict: dict)
        #expect(data.id == nil)
        #expect(data.url == nil)
        #expect(data.target == .browser)
    }

    // MARK: - OpenComponentData

    @Test func openComponentDataParsesAllFields() {
        let dict: [String: Any] = [
            "code": "inlineAd",
            "timeout": 8000,
            "brightnessDelta": 0.3,
            "componentParams": ["theme": "dark"],
        ]
        let data = IframeEvent.OpenComponentData.from(dict: dict)
        #expect(data.code == "inlineAd")
        #expect(data.timeout == 8000)
        #expect(data.brightnessDelta == 0.3)
        #expect(data.componentParams?["theme"] as? String == "dark")
    }

    @Test func openComponentDataFallsBackToDefaultTimeoutWhenMissing() {
        let data = IframeEvent.OpenComponentData.from(dict: [:])
        #expect(data.timeout == Constants.defaultModalTimeoutMs)
        #expect(data.code == nil)
        #expect(data.brightnessDelta == nil)
        #expect(data.componentParams == nil)
    }

    @Test func openComponentDataClampsNonPositiveTimeout() {
        // Initializer clamps timeout <= 0 to the default.
        let zero = IframeEvent.OpenComponentData.from(dict: ["timeout": 0])
        #expect(zero.timeout == Constants.defaultModalTimeoutMs)
        let negative = IframeEvent.OpenComponentData.from(dict: ["timeout": -5])
        #expect(negative.timeout == Constants.defaultModalTimeoutMs)
    }
}
