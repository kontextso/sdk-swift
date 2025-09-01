import Foundation
import Testing
@testable import KontextSwiftSDK

// MARK: - Tests

struct AdsEventTests {
    @Test
    func testKnownEventWithData() async throws {
        let json = """
            {
              "type": "event-iframe",
              "data": {
                "name": "clicked",
                "code": "200",
                "payload": { 
                   "videoId": 1000
                }
              }
            }
        """

        let data = try #require(json.data(using: .utf8))
        let result = try JSONDecoder().decode(EventIframeData.self, from: data)

        #expect(result.data.name == "clicked")

        switch result.data.type {
        case .clicked(let data):
            #expect(data == EventIframeContentDTO.ClickedDataDTO())
        default:
            Issue.record("Expected clicked event type, got: \(result.data.type)")
        }
    }

    @Test
    func testKnownEventWithMissingData() async throws {
        let json = """
            {
              "type": "event-iframe",
              "data": {
                "name": "clicked",
                "code": "200"
              }
            }
        """

        let data = try #require(json.data(using: .utf8))
        let result = try JSONDecoder().decode(EventIframeData.self, from: data)

        #expect(result.data.name == "clicked")

        switch result.data.type {
        case .clicked(let data):
            #expect(data == nil)
        default:
            Issue.record("Expected clicked event type, got: \(result.data.type)")
        }
    }

    @Test
    func testKnownEventWithUnknownEvent() async throws {
        let json = """
            {
              "type": "event-iframe",
              "data": {
                "name": "new-event",
                "code": "200",
                "payload": {
                   "videoId": 1000
                }
              }
            }
        """

        let data = try #require(json.data(using: .utf8))
        let result = try JSONDecoder().decode(EventIframeData.self, from: data)

        #expect(result.data.name == "new-event")

        switch result.data.type {
        case .event(let data):
            let value = data["videoId"]?.value as? Int
            #expect(value == 1000)
        default:
            Issue.record("Expected clicked event type, got: \(result.data.type)")
        }
    }
}
