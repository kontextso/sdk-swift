import Foundation
import Testing
@testable import KontextSwiftSDK

// MARK: - Tests

struct AdsEventTests {
    @Test
    func testKnownEventWithData() async throws {
        let json = """
            {
                "name": "ad.clicked",
                "code": "200",
                "payload": { 
                   "id": "uuid",
                   "content": "black",
                   "messageId": "1234",
                   "url": "https://example.com"
                }              
            }
        """

        let data = try #require(json.data(using: .utf8))
        let result = try JSONDecoder().decode(EventIframeDataDTO.self, from: data)

        #expect(result.name == "ad.clicked")

        switch result.type {
        case .clicked(let data):
            #expect(
                data == EventIframeDataDTO.ClickedDataDTO(
                    id: "uuid",
                    content: "black",
                    messageId: "1234",
                    url: URL(string: "https://example.com")!,
                    format: nil,
                    area: nil
                )
            )
        default:
            Issue.record("Expected clicked event type, got: \(result.type)")
        }
    }

    @Test
    func testKnownEventWithMissingData() async throws {
        let json = """
            {
                "name": "ad.clicked",
                "code": "200"              
            }
        """

        let data = try #require(json.data(using: .utf8))
        let result = try JSONDecoder().decode(EventIframeDataDTO.self, from: data)

        #expect(result.name == "ad.clicked")

        switch result.type {
        case .clicked(let data):
            #expect(data == nil)
        default:
            Issue.record("Expected clicked event type, got: \(result.type)")
        }
    }

    @Test
    func testKnownEventWithUnknownEvent() async throws {
        let json = """
            {
                "name": "new-event",
                "code": "200",
                "payload": {
                   "videoId": 1000
                }              
            }
        """

        let data = try #require(json.data(using: .utf8))
        let result = try JSONDecoder().decode(EventIframeDataDTO.self, from: data)

        #expect(result.name == "new-event")

        switch result.type {
        case .event(let data):
            let value = data["videoId"]?.value as? Int
            #expect(value == 1000)
        default:
            Issue.record("Expected clicked event type, got: \(result.type)")
        }
    }
}
