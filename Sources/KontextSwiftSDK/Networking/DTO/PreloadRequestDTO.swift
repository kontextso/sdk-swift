//
//  PreloadRequestDTO.swift
//  KontextSwiftSDK
//

struct PreloadRequestDTO: Encodable {
    let publisherToken: String
    let conversationId: String
    let userId: String
    let messages: [MessageDTO]
    let variantId: String?
    let character: Character?
    let advertisingId: String?
    let vendorId: String?
    let sessionId: String?
    let device: DeviceDTO?
    let sdk: String
    let sdkVersion: String
    
    init(
        publisherToken: String,
        conversationId: String,
        userId: String,
        messages: [MessageDTO],
        variantId: String?,
        character: Character?,
        advertisingId: String?,
        vendorId: String?,
        sessionId: String?,
        device: DeviceDTO?,
        sdk: String,
        sdkVersion: String
    ) {
        self.publisherToken = publisherToken
        self.conversationId = conversationId
        self.userId = userId
        self.messages = messages
        self.variantId = variantId
        self.character = character
        self.advertisingId = advertisingId
        self.vendorId = vendorId
        self.sessionId = sessionId
        self.device = device
        self.sdk = sdk
        self.sdkVersion = sdkVersion
    }
    
    init(
        sessionId: String?,
        configuration: AdsProviderConfiguration,
        device: Device,
        messages: [AdsMessage],
        sdk: String,
        sdkVersion: String
    ) {
        self.init(
            publisherToken: configuration.publisherToken,
            conversationId: configuration.conversationId,
            userId: configuration.userId,
            messages: messages.map(MessageDTO.init),
            variantId: configuration.variantId,
            character: configuration.character,
            advertisingId: configuration.advertisingId,
            vendorId: configuration.vendorId,
            sessionId: sessionId,
            device: DeviceDTO(from: device),
            sdk: sdk,
            sdkVersion: sdkVersion
        )
    }
}
