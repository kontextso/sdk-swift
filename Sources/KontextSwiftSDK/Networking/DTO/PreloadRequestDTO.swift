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
        self.sdk = sdkInfo.toModel()
        self.app = appinfo.toModel()
        self.device = device.toModel()
        self.regulatory = RegulatoryDTO(from: configuration.regulatory)
    }
}
