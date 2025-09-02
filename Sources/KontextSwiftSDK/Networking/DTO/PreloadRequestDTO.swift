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
    let device: DeviceDTO?
    let sdk: String
    let sdkVersion: String
    let regulatory: RegulatoryDTO?
    

    init(
        sessionId: String?,
        configuration: AdsProviderConfiguration,
        device: Device,
        messages: [AdsMessage],
        sdk: String,
        sdkVersion: String
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
        self.device = DeviceDTO(from: device)
        self.sdk = sdk
        self.sdkVersion = sdkVersion
        self.regulatory = RegulatoryDTO(from: configuration.regulatory)
    }
}
