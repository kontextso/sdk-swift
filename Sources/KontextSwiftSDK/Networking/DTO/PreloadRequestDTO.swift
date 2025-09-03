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
    let character: CharacterDTO?
    let enabledPlacementCodes: [String]?
    let advertisingId: String?
    let vendorId: String?
    let sessionId: String?
    let sdk: SDKDTO
    let app: AppDTO
    let device: DeviceDTO?
    let regulatory: RegulatoryDTO?
    

    init(
        sessionId: String?,
        configuration: AdsProviderConfiguration,
        sdkInfo: SDKInfo,
        appinfo: AppInfo,
        device: DeviceInfo,
        messages: [AdsMessage]
    ) {
        publisherToken = configuration.publisherToken
        conversationId = configuration.conversationId
        userId = configuration.userId
        self.messages = messages.map(MessageDTO.init)
        self.enabledPlacementCodes = configuration.enabledPlacementCodes
        variantId = configuration.variantId
        character = CharacterDTO(from: configuration.character)
        advertisingId = configuration.advertisingId
        vendorId = configuration.vendorId
        self.sessionId = sessionId
        self.sdk = SDKDTO(from: sdkInfo)
        self.app = AppDTO(from: appinfo)
        self.device = DeviceDTO(from: device)
        self.regulatory = RegulatoryDTO(from: configuration.regulatory)
    }
}
