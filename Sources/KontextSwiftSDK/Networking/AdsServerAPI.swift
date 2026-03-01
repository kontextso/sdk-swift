import Foundation

// MARK: - AdsServerAPI

protocol AdsServerAPI: Sendable {
    func preload(
        sessionId: String?,
        configuration: AdsProviderConfiguration,
        isDisabled: Bool,
        advertisingId: String?,
        vendorId: String?,
        messages: [AdsMessage]
    ) async throws -> PreloadedData

    @MainActor
    func frameURL(
        messageId: String,
        bidId: String,
        bidCode: String,
        otherParams: [String: String]
    ) -> URL?

    @MainActor
    func componentURL(
        messageId: String,
        bidId: String,
        bidCode: String,
        component: String,
        otherParams: [String: String]
    ) -> URL?

    func redirectURL(relativeURL: URL) -> URL
}

// MARK: - BaseURLConvertible

struct BaseURLConvertible: URLConvertible {
    let baseURL: URL
    let pathComponents: [String]
    let queryItems: [URLQueryItem]?
    
    func asURL() -> URL? {
        let urlWithPath: URL = pathComponents.reduce(baseURL) { $0.appendingPathComponent($1) }
        var urlComponents = URLComponents(url: urlWithPath, resolvingAgainstBaseURL: false)
        urlComponents?.queryItems = queryItems
        return urlComponents?.url
    }
}

// MARK: - BaseURLAdsServerAPI

final class BaseURLAdsServerAPI: AdsServerAPI, @unchecked Sendable {
    private let trackingURL: URL      // server.megabrain.co
    private let nonTrackingURL: URL    // ctx.megabrain.co
    private let networking: Networking
    
    init(trackingURL: URL, nonTrackingURL: URL, networking: Networking) {
        self.trackingURL = trackingURL
        self.nonTrackingURL = nonTrackingURL
        self.networking = networking
    }

    private var activeBaseURL: URL {
        IFACollector.isTrackingAuthorized ? trackingURL : nonTrackingURL
    }
    
    func preload(
        sessionId: String?,
        configuration: AdsProviderConfiguration,
        isDisabled: Bool,
        advertisingId: String?,
        vendorId: String?,
        messages: [AdsMessage]
    ) async throws -> PreloadedData {
        let preloadUrlConvertible = BaseURLConvertible(
            baseURL: activeBaseURL,
            pathComponents: ["preload"],
            queryItems: nil
        )
        let app = await AppInfo.current()
        let sdk = await SDKInfo.current()
        let device = await DeviceInfo.current(appInfo: app)
        let mergedRegulatory = TCFInfo.current().mergedRegulatory(from: configuration.regulatory)
        let requestDTO = PreloadRequestDTO(
            sessionId: sessionId,
            configuration: configuration,
            advertisingId: advertisingId,
            vendorId: vendorId,
            sdkInfo: sdk,
            appinfo: app,
            device: device,
            messages: messages,
            regulatoryOverride: mergedRegulatory
        )
        var headers: [HTTPHeaderField] = [
            .acceptType(.json),
            .contentType(.json),
            .publisherToken(configuration.publisherToken),
            .isDisabled(isDisabled)
        ]
        let responseDTO: PreloadResponseDTO = try await networking.request(
            method: .post,
            urlConvertible: preloadUrlConvertible,
            headers: headers,
            body: requestDTO
        )
        return responseDTO.toModel()
    }

    @MainActor
    func frameURL(
        messageId: String,
        bidId: String,
        bidCode: String,
        otherParams: [String: String]
    ) -> URL? {
        BaseURLConvertible(
            baseURL: activeBaseURL,
            pathComponents: ["api", "frame", bidId],
            queryItems: [
                URLQueryItem(name: "messageId", value: messageId),
                URLQueryItem(name: "code", value: bidCode),
                URLQueryItem(name: "sdk", value: SDKInfo.current().name)
            ] + otherParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        ).asURL()
    }

    @MainActor
    func componentURL(
        messageId: String,
        bidId: String,
        bidCode: String,
        component: String,
        otherParams: [String: String]
    ) -> URL? {
        BaseURLConvertible(
            baseURL: activeBaseURL,
            pathComponents: ["api", component, bidId],
            queryItems: [
                URLQueryItem(name: "messageId", value: messageId),
                URLQueryItem(name: "code", value: bidCode),
                URLQueryItem(name: "sdk", value: SDKInfo.current().name),
            ] + otherParams.map { URLQueryItem(name: $0.key, value: $0.value)}
        ).asURL()
    }

    func redirectURL(relativeURL: URL) -> URL {
        URL(string: relativeURL.relativeString, relativeTo: activeBaseURL) ?? relativeURL
    }
}
