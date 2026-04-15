import Foundation

/// Intercepts URLSession traffic so we can assert on outgoing requests
/// and stub responses without hitting the network.
///
/// Usage:
/// ```
/// let config = URLSessionConfiguration.ephemeral
/// config.protocolClasses = [MockURLProtocol.self]
/// let session = URLSession(configuration: config)
/// MockURLProtocol.register(for: url) { _ in (data, response, nil) }
/// ```
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) -> (Data?, HTTPURLResponse?, Error?)

    // Shared mutable state is protected by a serial queue.
    private static let lock = DispatchQueue(label: "MockURLProtocol.lock")
    private static var _handlers: [String: Handler] = [:]
    private static var _capturedRequests: [URLRequest] = []

    static func register(forHost host: String, handler: @escaping Handler) {
        lock.sync { _handlers[host] = handler }
    }

    static func reset() {
        lock.sync {
            _handlers.removeAll()
            _capturedRequests.removeAll()
        }
    }

    /// Clears only the captured-requests log, leaving the host handler map
    /// intact. Prefer this in tests that run in parallel with other MockURLProtocol
    /// consumers — calling `reset()` would wipe their handlers out from under them.
    static func resetCapturedRequests() {
        lock.sync { _capturedRequests.removeAll() }
    }

    static var capturedRequests: [URLRequest] {
        lock.sync { _capturedRequests }
    }

    static var lastRequest: URLRequest? {
        lock.sync { _capturedRequests.last }
    }

    // MARK: URLProtocol overrides

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let request = self.request

        MockURLProtocol.lock.sync {
            MockURLProtocol._capturedRequests.append(request)
        }

        let handler: Handler? = MockURLProtocol.lock.sync {
            let host = request.url?.host ?? ""
            return MockURLProtocol._handlers[host] ?? MockURLProtocol._handlers[""]
        }

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let (data, response, error) = handler(request)

        if let error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        if let response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        if let data {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension URLRequest {
    /// Reads the request body. `URLProtocol` receives the body via `httpBodyStream`, so
    /// both paths need handling to work in tests and production code.
    func bodyData() -> Data? {
        if let httpBody { return httpBody }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
