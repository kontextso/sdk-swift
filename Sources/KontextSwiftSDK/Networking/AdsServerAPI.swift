import Foundation

// MARK: - AdsServerAPI

protocol AdsServerAPI: Sendable {
    func preload(
        sessionId: String?,
        configuration: AdsProviderConfiguration,
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
    private let baseURL: URL
    private let networking: Networking
    
    init(baseURL: URL, networking: Networking) {
        self.baseURL = baseURL
        self.networking = networking
    }
    
    func preload(
        sessionId: String?,
        configuration: AdsProviderConfiguration,
        messages: [AdsMessage]
    ) async throws -> PreloadedData {
        let preloadUrlConvertible = BaseURLConvertible(
            baseURL: baseURL,
            pathComponents: ["preload"],
            queryItems: nil
        )
        let app = AppInfo.current()
        let sdk = await SDKInfo.current()
        let requestDTO = PreloadRequestDTO(
            sessionId: sessionId,
            configuration: configuration,
            sdkInfo: sdk,
            appinfo: app,
            device: await DeviceInfo.current(appInfo: app),
            messages: messages
        )
        let responseDTO: PreloadResponseDTO = try await networking.request(
            method: .post,
            urlConvertible: preloadUrlConvertible,
            headers: [.acceptType(.json), .contentType(.json)],
            body: requestDTO
        )
        return responseDTO.preloadedData
    }

    @MainActor
    func frameURL(
        messageId: String,
        bidId: String,
        bidCode: String,
        otherParams: [String: String]
    ) -> URL? {
        BaseURLConvertible(
            baseURL: baseURL,
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
            baseURL: baseURL,
            pathComponents: ["api", component, bidId],
            queryItems: [
                URLQueryItem(name: "messageId", value: messageId),
                URLQueryItem(name: "code", value: bidCode),
                URLQueryItem(name: "sdk", value: SDKInfo.current().name),
            ] + otherParams.map { URLQueryItem(name: $0.key, value: $0.value)}
        ).asURL()
    }

    func redirectURL(relativeURL: URL) -> URL {
        URL(string: relativeURL.relativeString, relativeTo: baseURL) ?? relativeURL
    }
}
