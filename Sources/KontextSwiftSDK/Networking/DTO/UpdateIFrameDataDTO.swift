//
//  UpdateIFrameDataDTO.swift
//  KontextSwiftSDK
//

struct UpdateIFrameDTO: Encodable {
    enum EventType: String, Encodable {
        case updateIFrame = "update-iframe"
    }

    let type: EventType = .updateIFrame
    let data: UpdateIFrameDataDTO
}

struct UpdateIFrameDataDTO: Encodable {
    let sdk: String
    let code: String
    let messageId: String
    let messages: [MessageDTO]
    let otherParams: [String: String]?

    init(from model: UpdateIFrameData) {
        sdk = model.sdk
        code = model.code
        messageId = model.messageId
        messages = model.messages
        otherParams = model.otherParams
    }
}
