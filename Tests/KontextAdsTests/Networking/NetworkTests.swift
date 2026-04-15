import Foundation
import Testing
@testable import KontextSwiftSDK

/// Tests for the low-level `Network` class (Networking protocol impl).
/// Uses MockURLProtocol to intercept URLSession traffic.
///
/// Serialized because it mutates MockURLProtocol's shared state.
@Suite(.serialized)
struct NetworkTests {
    private func makeSUT() -> (Network, URLSession) {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return (Network(session: session), session)
    }

    private struct Body: Encodable { let foo: String }
    private struct Response: Decodable { let ok: Bool }

    private struct RawURL: URLConvertible {
        let url: URL
        func asURL() -> URL? { url }
    }

    private var testURL: RawURL {
        RawURL(url: URL(string: "https://example.com/endpoint")!)
    }

    // MARK: - Happy path

    @Test
    func successfulPOSTReturnsDecodedResponse() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.register(forHost: "example.com") { _ in
            let data = #"{"ok": true}"#.data(using: .utf8)!
            let response = HTTPURLResponse(url: URL(string: "https://example.com/endpoint")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data, response, nil)
        }

        let (sut, _) = makeSUT()
        let result: Response = try await sut.request(
            method: .post,
            urlConvertible: testURL,
            headers: [.contentType(.json)],
            body: Body(foo: "bar")
        )
        #expect(result.ok == true)
    }

    @Test
    func voidRequestSucceedsAndIgnoresBody() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.register(forHost: "example.com") { _ in
            let data = Data()
            let response = HTTPURLResponse(url: URL(string: "https://example.com/endpoint")!, statusCode: 204, httpVersion: nil, headerFields: nil)
            return (data, response, nil)
        }

        let (sut, _) = makeSUT()
        try await sut.request(
            method: .post,
            urlConvertible: testURL,
            headers: [],
            body: EmptyBody()
        )
    }

    // MARK: - Request shape

    @Test
    func usesCorrectHTTPMethod() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.register(forHost: "example.com") { _ in
            (nil, HTTPURLResponse(url: URL(string: "https://example.com/endpoint")!, statusCode: 200, httpVersion: nil, headerFields: nil), nil)
        }
        let (sut, _) = makeSUT()
        try await sut.request(method: .put, urlConvertible: testURL, headers: [], body: EmptyBody())
        #expect(MockURLProtocol.lastRequest?.httpMethod == "PUT")
    }

    @Test
    func setsHeadersFromHTTPHeaderFieldEnum() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.register(forHost: "example.com") { _ in
            (nil, HTTPURLResponse(url: URL(string: "https://example.com/endpoint")!, statusCode: 200, httpVersion: nil, headerFields: nil), nil)
        }
        let (sut, _) = makeSUT()
        try await sut.request(
            method: .post,
            urlConvertible: testURL,
            headers: [
                .contentType(.json),
                .acceptType(.json),
                .publisherToken("pub-tok"),
                .isDisabled(true),
                .userAgent("custom-ua"),
            ],
            body: EmptyBody()
        )

        let headers = MockURLProtocol.lastRequest?.allHTTPHeaderFields ?? [:]
        #expect(headers["Content-Type"] == "application/json")
        #expect(headers["Accept"] == "application/json")
        #expect(headers["Kontextso-Publisher-Token"] == "pub-tok")
        #expect(headers["Kontextso-Is-Disabled"] == "1")
        #expect(headers["User-Agent"] == "custom-ua")
    }

    @Test
    func isDisabledHeaderEmitsZeroForFalse() async throws {
        MockURLProtocol.reset()
        MockURLProtocol.register(forHost: "example.com") { _ in
            (nil, HTTPURLResponse(url: URL(string: "https://example.com/endpoint")!, statusCode: 200, httpVersion: nil, headerFields: nil), nil)
        }
        let (sut, _) = makeSUT()
        try await sut.request(
            method: .post,
            urlConvertible: testURL,
            headers: [.isDisabled(false)],
            body: EmptyBody()
        )
        #expect(MockURLProtocol.lastRequest?.allHTTPHeaderFields?["Kontextso-Is-Disabled"] == "0")
    }

    @Test
    func encodesBodyWithMillisecondsDateStrategy() async throws {
        struct DatedBody: Encodable { let ts: Date }
        MockURLProtocol.reset()
        MockURLProtocol.register(forHost: "example.com") { _ in
            (nil, HTTPURLResponse(url: URL(string: "https://example.com/endpoint")!, statusCode: 200, httpVersion: nil, headerFields: nil), nil)
        }
        let (sut, _) = makeSUT()
        let ts = Date(timeIntervalSince1970: 1.5) // 1500ms

        try await sut.request(
            method: .post,
            urlConvertible: testURL,
            headers: [],
            body: DatedBody(ts: ts)
        )
        let body = try #require(MockURLProtocol.lastRequest?.bodyData())
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["ts"] as? Double == 1500)
    }

    // MARK: - Errors

    @Test
    func returnsInvalidURLWhenURLConvertibleYieldsNil() async {
        struct NilURL: URLConvertible { func asURL() -> URL? { nil } }
        let (sut, _) = makeSUT()

        await #expect(throws: APIError.self) {
            try await sut.request(
                method: .post,
                urlConvertible: NilURL(),
                headers: [],
                body: EmptyBody()
            )
        }
    }

    @Test
    func mapsTransportFailureToRequestFailed() async {
        MockURLProtocol.reset()
        MockURLProtocol.register(forHost: "example.com") { _ in
            (nil, nil, URLError(.notConnectedToInternet))
        }
        let (sut, _) = makeSUT()

        do {
            try await sut.request(
                method: .post,
                urlConvertible: testURL,
                headers: [],
                body: EmptyBody()
            )
            Issue.record("Expected throw")
        } catch let APIError.requestFailed(inner) {
            #expect((inner as? URLError)?.code == .notConnectedToInternet)
        } catch {
            Issue.record("Expected .requestFailed, got \(error)")
        }
    }

    @Test
    func mapsNon2xxStatusToInvalidResponseWithCode() async {
        MockURLProtocol.reset()
        MockURLProtocol.register(forHost: "example.com") { _ in
            let data = Data()
            let response = HTTPURLResponse(url: URL(string: "https://example.com/endpoint")!, statusCode: 418, httpVersion: nil, headerFields: nil)
            return (data, response, nil)
        }
        let (sut, _) = makeSUT()

        do {
            try await sut.request(
                method: .post,
                urlConvertible: testURL,
                headers: [],
                body: EmptyBody()
            )
            Issue.record("Expected throw")
        } catch let APIError.invalidResponse(code) {
            #expect(code == 418)
        } catch {
            Issue.record("Expected .invalidResponse, got \(error)")
        }
    }

    @Test
    func mapsDecodingFailureToDecodingError() async {
        MockURLProtocol.reset()
        MockURLProtocol.register(forHost: "example.com") { _ in
            let data = "this is not json".data(using: .utf8)!
            let response = HTTPURLResponse(url: URL(string: "https://example.com/endpoint")!, statusCode: 200, httpVersion: nil, headerFields: nil)
            return (data, response, nil)
        }
        let (sut, _) = makeSUT()

        do {
            let _: Response = try await sut.request(
                method: .post,
                urlConvertible: testURL,
                headers: [],
                body: EmptyBody()
            )
            Issue.record("Expected throw")
        } catch let APIError.decodingError(inner) {
            #expect(inner is DecodingError)
        } catch {
            Issue.record("Expected .decodingError, got \(error)")
        }
    }

    // MARK: - BaseURLConvertible

    @Test
    func baseURLConvertibleBuildsURLWithPathAndQueryItems() {
        let convertible = BaseURLConvertible(
            baseURL: URL(string: "https://server.example.com/")!,
            pathComponents: ["api", "frame", "abc-123"],
            queryItems: [URLQueryItem(name: "k", value: "v"), URLQueryItem(name: "code", value: "inline")]
        )
        let url = convertible.asURL()!
        #expect(url.path.hasSuffix("/api/frame/abc-123"))
        #expect(url.absoluteString.contains("k=v"))
        #expect(url.absoluteString.contains("code=inline"))
    }

    @Test
    func baseURLConvertibleHandlesEmptyQueryItems() {
        let convertible = BaseURLConvertible(
            baseURL: URL(string: "https://server.example.com")!,
            pathComponents: ["preload"],
            queryItems: nil
        )
        let url = convertible.asURL()!
        #expect(url.absoluteString.hasSuffix("/preload"))
    }
}
