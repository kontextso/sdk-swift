import Foundation
import Testing
@testable import KontextSwiftSDK

/// Tests for BaseURLAdsServerAPI — the concrete impl of AdsServerAPI.
/// Covers preload request plumbing + URL building. Hits a stub Networking
/// rather than URLSession because preload() depends on main-actor APIs
/// (DeviceInfo.current, SDKInfo.current, TCFCollector.current) that we
/// cannot freely call across actor boundaries.
struct AdsServerAPITests {
    // MARK: - Stub Networking

    final class StubNetworking: Networking, @unchecked Sendable {
        struct Capture: Sendable {
            let method: HTTPMethod
            let url: URL?
            let headers: [HTTPHeaderField]
            let body: Data
        }

        private let lock = NSLock()
        private var _lastCapture: Capture?
        private var _responseDTO: PreloadResponseDTO?
        private var _errorToThrow: Error?

        var lastCapture: Capture? { lock.lock(); defer { lock.unlock() }; return _lastCapture }

        func setResponse(_ dto: PreloadResponseDTO) {
            lock.lock(); defer { lock.unlock() }
            _responseDTO = dto
        }
        func setError(_ error: Error) {
            lock.lock(); defer { lock.unlock() }
            _errorToThrow = error
        }

        func request<E>(
            method: HTTPMethod,
            urlConvertible: any URLConvertible,
            headers: [HTTPHeaderField],
            body: E
        ) async throws where E: Encodable {
            try captureAndMaybeThrow(method: method, urlConvertible: urlConvertible, headers: headers, body: body)
        }

        func request<E, D>(
            method: HTTPMethod,
            urlConvertible: any URLConvertible,
            headers: [HTTPHeaderField],
            body: E
        ) async throws -> D where E: Encodable, D: Decodable {
            try captureAndMaybeThrow(method: method, urlConvertible: urlConvertible, headers: headers, body: body)

            lock.lock(); let dto = _responseDTO; lock.unlock()
            guard let dto else {
                throw APIError.decodingError(NSError(domain: "test", code: -1))
            }
            // We know the concrete D is always PreloadResponseDTO in these tests.
            return dto as! D
        }

        private func captureAndMaybeThrow<E: Encodable>(
            method: HTTPMethod,
            urlConvertible: any URLConvertible,
            headers: [HTTPHeaderField],
            body: E
        ) throws {
            let data = (try? JSONEncoder().encode(body)) ?? Data()
            lock.lock()
            _lastCapture = Capture(
                method: method,
                url: urlConvertible.asURL(),
                headers: headers,
                body: data
            )
            let err = _errorToThrow
            lock.unlock()
            if let err {
                throw err
            }
        }
    }

    // MARK: - preload

    @Test
    func preloadHitsPreloadPathWithPostAndExpectedHeaders() async throws {
        let base = URL(string: "https://ads.example.com")!
        let stub = StubNetworking()
        stub.setResponse(
            try JSONDecoder().decode(PreloadResponseDTO.self, from: #"{"sessionId": "s-1"}"#.data(using: .utf8)!)
        )
        let sut = BaseURLAdsServerAPI(baseURL: base, networking: stub)

        let config = AdsProviderConfiguration(
            publisherToken: "pub-tok",
            userId: "u",
            conversationId: "c",
            enabledPlacementCodes: ["inlineAd"]
        )

        _ = try await sut.preload(
            sessionId: "sess-0",
            configuration: config,
            isDisabled: true,
            advertisingId: "idfa",
            vendorId: "idfv",
            messages: [AdsMessage(id: "m", role: .user, content: "Hi", createdAt: Date(timeIntervalSince1970: 0))]
        )

        let capture = try #require(stub.lastCapture)
        #expect(capture.method == .post)
        #expect(capture.url?.absoluteString == "https://ads.example.com/preload")

        // Every expected header is present.
        let headerKeys = capture.headers.map(\.headerKey)
        #expect(headerKeys.contains("Content-Type"))
        #expect(headerKeys.contains("Accept"))
        #expect(headerKeys.contains("Kontextso-Publisher-Token"))
        #expect(headerKeys.contains("Kontextso-Is-Disabled"))

        let tokenHeader = capture.headers.first { $0.headerKey == "Kontextso-Publisher-Token" }
        #expect(tokenHeader?.headerValue == "pub-tok")
        let disabledHeader = capture.headers.first { $0.headerKey == "Kontextso-Is-Disabled" }
        #expect(disabledHeader?.headerValue == "1")
    }

    @Test
    func preloadBodyCarriesRequestFields() async throws {
        let base = URL(string: "https://ads.example.com")!
        let stub = StubNetworking()
        stub.setResponse(try JSONDecoder().decode(PreloadResponseDTO.self, from: "{}".data(using: .utf8)!))
        let sut = BaseURLAdsServerAPI(baseURL: base, networking: stub)

        let config = AdsProviderConfiguration(
            publisherToken: "tok",
            userId: "user-99",
            conversationId: "conv-99",
            enabledPlacementCodes: ["x"],
            variantId: "v-1",
            userEmail: "e@x.com"
        )

        _ = try? await sut.preload(
            sessionId: "sess",
            configuration: config,
            isDisabled: false,
            advertisingId: "ad-id",
            vendorId: "v-id",
            messages: []
        )

        let capture = try #require(stub.lastCapture)
        let json = try #require(try JSONSerialization.jsonObject(with: capture.body) as? [String: Any])
        #expect(json["publisherToken"] as? String == "tok")
        #expect(json["userId"] as? String == "user-99")
        #expect(json["conversationId"] as? String == "conv-99")
        #expect(json["variantId"] as? String == "v-1")
        #expect(json["userEmail"] as? String == "e@x.com")
        #expect(json["enabledPlacementCodes"] as? [String] == ["x"])
        #expect(json["sessionId"] as? String == "sess")
        #expect(json["advertisingId"] as? String == "ad-id")
        #expect(json["vendorId"] as? String == "v-id")
    }

    @Test
    func preloadPropagatesNetworkingErrors() async {
        let base = URL(string: "https://ads.example.com")!
        let stub = StubNetworking()
        stub.setError(APIError.invalidResponse(statusCode: 500))
        let sut = BaseURLAdsServerAPI(baseURL: base, networking: stub)

        let config = AdsProviderConfiguration(publisherToken: "t", userId: "u", conversationId: "c", enabledPlacementCodes: [])
        await #expect(throws: APIError.self) {
            try await sut.preload(
                sessionId: nil, configuration: config, isDisabled: false,
                advertisingId: nil, vendorId: nil, messages: []
            )
        }
    }

    // MARK: - frameURL / componentURL

    @MainActor
    @Test
    func frameURLBuildsExpectedStructure() {
        let base = URL(string: "https://ads.example.com")!
        let sut = BaseURLAdsServerAPI(baseURL: base, networking: StubNetworking())

        let url = sut.frameURL(
            messageId: "m-1",
            bidId: "bid-1",
            bidCode: "inlineAd",
            otherParams: ["theme": "dark"]
        )!

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        #expect(components.path == "/api/frame/bid-1")
        let qi = components.queryItems ?? []
        #expect(qi.contains(URLQueryItem(name: "messageId", value: "m-1")))
        #expect(qi.contains(URLQueryItem(name: "code", value: "inlineAd")))
        #expect(qi.contains(URLQueryItem(name: "sdk", value: "sdk-swift")))
        #expect(qi.contains(URLQueryItem(name: "theme", value: "dark")))
    }

    @MainActor
    @Test
    func frameURLHandlesEmptyOtherParams() {
        let sut = BaseURLAdsServerAPI(
            baseURL: URL(string: "https://ads.example.com")!,
            networking: StubNetworking()
        )
        let url = sut.frameURL(messageId: "m", bidId: "b", bidCode: "c", otherParams: [:])!
        #expect(url.absoluteString.contains("/api/frame/b"))
        #expect(!url.absoluteString.contains("theme="))
    }

    @MainActor
    @Test
    func componentURLIncludesComponentPathSegment() {
        let sut = BaseURLAdsServerAPI(
            baseURL: URL(string: "https://ads.example.com")!,
            networking: StubNetworking()
        )
        let url = sut.componentURL(
            messageId: "m-1",
            bidId: "bid-1",
            bidCode: "inlineAd",
            component: "modal",
            otherParams: [:]
        )!
        #expect(url.path == "/api/modal/bid-1")
    }

    // MARK: - redirectURL

    @Test
    func redirectURLResolvesRelativeAgainstBase() {
        let base = URL(string: "https://ads.example.com/")!
        let sut = BaseURLAdsServerAPI(baseURL: base, networking: StubNetworking())

        // A relative URL — the SDK uses relativeString on the input.
        let relative = URL(string: "/click/abc", relativeTo: base)!
        let resolved = sut.redirectURL(relativeURL: relative)
        #expect(resolved.absoluteString.hasPrefix("https://ads.example.com/"))
        #expect(resolved.absoluteString.hasSuffix("/click/abc"))
    }

    @Test
    func redirectURLReturnsOriginalForAbsoluteHTTPSURL() {
        let base = URL(string: "https://ads.example.com/")!
        let sut = BaseURLAdsServerAPI(baseURL: base, networking: StubNetworking())

        let absolute = URL(string: "https://other.example.com/x")!
        let resolved = sut.redirectURL(relativeURL: absolute)
        // `URL(string:relativeTo:)` with an already-absolute string returns that string.
        #expect(resolved.absoluteString == absolute.absoluteString)
    }
}
