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

        let data = XCTUnwrap(json.data(using: .utf8))
        let result = try JSONDecoder().decode(EventIframeData.self, from: data)
        #expect(result.name == "clicked")
        
//        switch result.type {
//        case .
//        }
    }
}
