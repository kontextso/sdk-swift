struct PreloadRequestDTO: Encodable {
    let publisherToken: String
    let conversationId: String
    let userId: String
    let userEmail: String?
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
        advertisingId: String?,
        vendorId: String?,
        sdkInfo: SDKInfo,
        appinfo: AppInfo,
        device: DeviceInfo,
        messages: [AdsMessage],
        regulatoryOverride: Regulatory? = nil
    ) {
        publisherToken = configuration.publisherToken
        conversationId = configuration.conversationId
        userId = configuration.userId
        userEmail = configuration.userEmail
        self.messages = messages.map(MessageDTO.init)
        self.enabledPlacementCodes = configuration.enabledPlacementCodes
        variantId = configuration.variantId
        character = CharacterDTO(from: configuration.character)
        self.advertisingId = IFACollector.isTrackingAuthorized ? advertisingId : nil
        self.vendorId = IFACollector.isTrackingAuthorized ? vendorId : nil
        self.sessionId = sessionId
        self.sdk = sdkInfo.toModel()
        self.app = appinfo.toModel()
        self.device = device.toModel()
        self.regulatory = RegulatoryDTO(from: regulatoryOverride ?? configuration.regulatory)
    }
}
