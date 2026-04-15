import Foundation

struct UserEventIFrameDTO: Encodable, Hashable, Sendable {
    let type: String = "user-event-iframe"
    let data: Data
}

extension UserEventIFrameDTO {
    struct Data: Encodable, Hashable, Sendable {
        let name: UserEventName
    }
}
