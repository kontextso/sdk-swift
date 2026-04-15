import Foundation
import Testing
@testable import KontextSwiftSDK

struct UserEventIFrameDTOTests {
    @Test
    func encodeToJSONIncludesExpectedTypeAndName() throws {
        let dto = UserEventIFrameDTO(data: .init(name: .userTypingStarted))

        let json = try dto.encodeToJSON()
        let dict = try #require(json as? [String: Any])
        let data = try #require(dict["data"] as? [String: Any])

        #expect(dict["type"] as? String == "user-event-iframe")
        #expect(data["name"] as? String == "user.typing.started")
    }
}
