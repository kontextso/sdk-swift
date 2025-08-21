//
//  DependencyContainer.swift
//  KontextSwiftSDK
//

struct DependencyContainer: Sendable {
    let networking: Networking
    let adsServerAPI: AdsServerAPI
    let sharedStorage: SharedStorage
    let adsProviderActing: AdsProviderActing
    
    init(
        networking: Networking,
        adsServerAPI: AdsServerAPI,
        sharedStorage: SharedStorage,
        adsProviderActing: AdsProviderActing
    ) {
        self.networking = networking
        self.adsServerAPI = adsServerAPI
        self.sharedStorage = sharedStorage
        self.adsProviderActing = adsProviderActing
    }
    
    @MainActor
    static func defaultContainer(
        configuration: AdsProviderConfiguration,
        sessionId: String?,
        isDisabled: Bool
    ) -> DependencyContainer {
        let networking = Network()
        let adsServerAPI = BaseURLAdsServerAPI(
            baseURL: configuration.adServerUrl,
            networking: networking
        )
        let sharedStorage = SharedStorage()
        let providerActor = AdsProviderActor(
            configuration: configuration,
            sessionId: sessionId,
            isDisabled: isDisabled,
            adsServerAPI: adsServerAPI,
            sharedStorage: sharedStorage
        )
        
        return DependencyContainer(
            networking: networking,
            adsServerAPI: adsServerAPI,
            sharedStorage: sharedStorage,
            adsProviderActing: providerActor
        )
    }
}
