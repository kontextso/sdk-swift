import Foundation
import Testing
@testable import KontextSwiftSDK

/// Verifies EventIframeDataDTO → AdsEvent conversion for every TypeDTO case.
struct IframeEventMappingTests {
    private let sampleId = UUID()

    // MARK: - Leaf data mappers

    @Test
    func viewedDataToModelCopiesAllFields() {
        let dto = EventIframeDataDTO.ViewedDataDTO(id: sampleId, content: "c", messageId: "m", format: "inline")
        let model = dto.toModel()
        #expect(model.bidId == sampleId)
        #expect(model.content == "c")
        #expect(model.messageId == "m")
        #expect(model.format == "inline")
    }

    @Test
    func clickedDataToModelCopiesAllFields() {
        let url = URL(string: "https://example.com")!
        let dto = EventIframeDataDTO.ClickedDataDTO(id: sampleId, content: "c", messageId: "m", url: url, format: "inline", area: "cta")
        let model = dto.toModel()
        #expect(model.bidId == sampleId)
        #expect(model.url == url)
        #expect(model.format == "inline")
        #expect(model.area == "cta")
    }

    @Test
    func errorDataToModelCopiesAllFields() {
        let dto = EventIframeDataDTO.ErrorDataDTO(message: "boom", errCode: "E42")
        let model = dto.toModel()
        #expect(model.message == "boom")
        #expect(model.errCode == "E42")
    }

    @Test
    func generalDataToModelCopiesBidId() {
        let dto = EventIframeDataDTO.GeneralDataDTO(id: sampleId)
        let model = dto.toModel()
        #expect(model.bidId == sampleId)
    }

    // MARK: - TypeDTO → AdsEvent routing

    @Test
    func typeDTOViewedMapsToAdsEventViewed() {
        let dto = EventIframeDataDTO.TypeDTO.viewed(
            EventIframeDataDTO.ViewedDataDTO(id: sampleId, content: "c", messageId: "m", format: nil)
        )
        if case .viewed(let payload) = dto.toModel() {
            #expect(payload?.bidId == sampleId)
        } else {
            Issue.record("Expected .viewed")
        }
    }

    @Test
    func typeDTOWithNilPayloadMapsToAdsEventWithNil() {
        if case .viewed(let payload) = EventIframeDataDTO.TypeDTO.viewed(nil).toModel() {
            #expect(payload == nil)
        } else {
            Issue.record("Expected .viewed(nil)")
        }

        if case .clicked(let payload) = EventIframeDataDTO.TypeDTO.clicked(nil).toModel() {
            #expect(payload == nil)
        } else {
            Issue.record("Expected .clicked(nil)")
        }

        if case .error(let payload) = EventIframeDataDTO.TypeDTO.error(nil).toModel() {
            #expect(payload == nil)
        } else {
            Issue.record("Expected .error(nil)")
        }
    }

    @Test
    func typeDTOClickedMapsToAdsEventClicked() {
        let url = URL(string: "https://example.com")!
        let dto = EventIframeDataDTO.TypeDTO.clicked(
            EventIframeDataDTO.ClickedDataDTO(id: sampleId, content: "c", messageId: "m", url: url, format: nil, area: nil)
        )
        if case .clicked(let payload) = dto.toModel() {
            #expect(payload?.url == url)
        } else {
            Issue.record("Expected .clicked")
        }
    }

    @Test
    func typeDTOErrorMapsToAdsEventError() {
        let dto = EventIframeDataDTO.TypeDTO.error(
            EventIframeDataDTO.ErrorDataDTO(message: "m", errCode: "c")
        )
        if case .error(let payload) = dto.toModel() {
            #expect(payload?.message == "m")
            #expect(payload?.errCode == "c")
        } else {
            Issue.record("Expected .error")
        }
    }

    @Test
    func typeDTORenderStartedAndRenderCompletedMap() {
        let rs = EventIframeDataDTO.TypeDTO.renderStarted(.init(id: sampleId)).toModel()
        let rc = EventIframeDataDTO.TypeDTO.renderCompleted(.init(id: sampleId)).toModel()
        if case .renderStarted(let p) = rs { #expect(p?.bidId == sampleId) } else { Issue.record("rs") }
        if case .renderCompleted(let p) = rc { #expect(p?.bidId == sampleId) } else { Issue.record("rc") }
    }

    @Test
    func typeDTOVideoStartedAndCompletedMap() {
        let vs = EventIframeDataDTO.TypeDTO.videoStarted(.init(id: sampleId)).toModel()
        let vc = EventIframeDataDTO.TypeDTO.videoCompleted(.init(id: sampleId)).toModel()
        if case .videoStarted(let p) = vs { #expect(p?.bidId == sampleId) } else { Issue.record("vs") }
        if case .videoCompleted(let p) = vc { #expect(p?.bidId == sampleId) } else { Issue.record("vc") }
    }

    @Test
    func typeDTORewardGrantedMaps() {
        let event = EventIframeDataDTO.TypeDTO.rewardGranted(.init(id: sampleId)).toModel()
        if case .rewardGranted(let p) = event {
            #expect(p?.bidId == sampleId)
        } else {
            Issue.record("Expected .rewardGranted")
        }
    }

    @Test
    func typeDTOEventMapsToAdsEventEvent() {
        let payload: [String: AnyDecodable] = ["k": AnyDecodable("v"), "n": AnyDecodable(42)]
        let event = EventIframeDataDTO.TypeDTO.event(payload).toModel()
        if case .event(let dict) = event {
            // dict is [String: any Sendable] — the underlying values may be the AnyDecodable wrappers.
            #expect(dict["k"] != nil)
            #expect(dict["n"] != nil)
        } else {
            Issue.record("Expected .event")
        }
    }

    // MARK: - EventIframeDataDTO wrapper

    // MARK: - JSON decoding (webview → DTO)

    /// The webview emits event names that must match `TypeName` raw values exactly.
    /// If they drift, `init(from:)` silently falls through to `.event(dictionary)`.
    @Test
    func decodesKnownEventNamesToTypedCases() throws {
        func decode(_ json: String) throws -> EventIframeDataDTO {
            try JSONDecoder().decode(EventIframeDataDTO.self, from: Data(json.utf8))
        }

        let bidId = UUID().uuidString
        let generalPayload = #"{"id":"\#(bidId)"}"#

        let renderStarted = try decode(#"{"name":"ad.render-started","code":"inlineAd","payload":\#(generalPayload)}"#)
        if case .renderStarted(let p) = renderStarted.type { #expect(p?.id == UUID(uuidString: bidId)) }
        else { Issue.record("render-started decoded as \(renderStarted.type)") }

        let renderCompleted = try decode(#"{"name":"ad.render-completed","code":"inlineAd","payload":\#(generalPayload)}"#)
        if case .renderCompleted(let p) = renderCompleted.type { #expect(p?.id == UUID(uuidString: bidId)) }
        else { Issue.record("render-completed decoded as \(renderCompleted.type)") }

        let viewed = try decode(#"{"name":"ad.viewed","code":"inlineAd","payload":{"id":"\#(bidId)","content":"c","messageId":"m"}}"#)
        if case .viewed = viewed.type {} else { Issue.record("viewed decoded as \(viewed.type)") }

        let unknown = try decode(#"{"name":"ad.something-new","code":"inlineAd","payload":{"foo":"bar"}}"#)
        if case .event = unknown.type {} else { Issue.record("unknown decoded as \(unknown.type)") }
    }

    @Test
    func eventIframeDataDTOToModelDelegatesToTypeDTO() {
        let dto = EventIframeDataDTO(
            name: "ad.viewed",
            code: "inlineAd",
            type: .viewed(EventIframeDataDTO.ViewedDataDTO(id: sampleId, content: "c", messageId: "m", format: nil))
        )
        if case .viewed(let payload) = dto.toModel() {
            #expect(payload?.bidId == sampleId)
        } else {
            Issue.record("Expected .viewed")
        }
    }
}
