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
    
    init(
        sdk: String,
        code: String,
        messageId: String,
        messages: [MessageDTO],
        otherParams: [String : String]?
    ) {
        self.sdk = sdk
        self.code = code
        self.messageId = messageId
        self.messages = messages
        self.otherParams = otherParams
    }
    
    init(from model: UpdateIFrameData) {
        self.init(
            sdk: model.sdk,
            code: model.code,
            messageId: model.messageId,
            messages: model.messages,
            otherParams: model.otherParams
        )
    }
}
