//
//  Networking.swift
//  KontextSwiftSDK
//

import Foundation

// MARK: - HTTPMethod

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

// MARK: - HTTPHeaderField

enum HTTPHeaderField {
    enum AcceptType: String {
        case json = "application/json"
    }
    
    enum ContentType: String {
        case json = "application/json"
    }
    
    case acceptType(AcceptType)
    case contentType(ContentType)
    
    var headerKey: String {
        switch self {
        case .acceptType: "Accept"
        case .contentType: "Content-Type"
        }
    }
    
    var headerValue: String {
        switch self {
        case .acceptType(let type): type.rawValue
        case .contentType(let type): type.rawValue
        }
    }
}

// MARK: - APIError

enum APIError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse(statusCode: Int)
    case encodingError(Error)
    case decodingError(Error)
}

// MARK: - URLConvertible

protocol URLConvertible: Sendable {
    func asURL() -> URL?
}

// MARK: - EmptyBody

struct EmptyBody: Encodable {}

// MARK: - Networking

protocol Networking: Sendable {
    func request<E: Encodable>(
        method: HTTPMethod,
        urlConvertible: any URLConvertible,
        headers: [HTTPHeaderField],
        body: E
    ) async throws -> Void
    
    func request<E: Encodable, D: Decodable>(
        method: HTTPMethod,
        urlConvertible: URLConvertible,
        headers: [HTTPHeaderField],
        body: E
    ) async throws -> D
}

// MARK: - Network

final class Network: Networking {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func request<EncodableResponse: Encodable>(
        method: HTTPMethod,
        urlConvertible: any URLConvertible,
        headers: [HTTPHeaderField],
        body: EncodableResponse
    ) async throws {
        // Ignore returned data
        _ = try await requestData(
            method: method,
            urlConvertible: urlConvertible,
            headers: headers,
            body: body
        )
    }
    
    func request<EncodableResponse: Encodable, DecodableResponse: Decodable>(
        method: HTTPMethod,
        urlConvertible: any URLConvertible,
        headers: [HTTPHeaderField],
        body: EncodableResponse
    ) async throws -> DecodableResponse {
        let data = try await requestData(
            method: method,
            urlConvertible: urlConvertible,
            headers: headers,
            body: body
        )
        // Decode response body
        do {
            let jsonDecoder = JSONDecoder()
            return try jsonDecoder.decode(DecodableResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
    
    private func requestData<EncodableResponse: Encodable>(
        method: HTTPMethod,
        urlConvertible: any URLConvertible,
        headers: [HTTPHeaderField] = [.contentType(.json)],
        body: EncodableResponse
    ) async throws -> Data {
        // Prepare URL
        guard let url = urlConvertible.asURL() else {
            throw APIError.invalidURL
        }
        // Prepare request
        var request = URLRequest(url: url)
        
        do {
            request.httpMethod = method.rawValue
            headers.forEach { request.setValue($0.headerValue, forHTTPHeaderField: $0.headerKey) }
            let jsonEncoder = JSONEncoder()
            request.httpBody = try jsonEncoder.encode(body)
        } catch {
            throw APIError.encodingError(error)
        }
        
        // Request data
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.requestAsync(request: request)
        } catch {
            throw APIError.requestFailed(error)
        }
        
        // Check HTTP status code
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(statusCode: -1)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse(statusCode: httpResponse.statusCode)
        }
        
        return data
    }
}
