//
//  URLSession+async.swift
//  KontextSwiftSDK
//

import Foundation

extension URLSession {
    func requestAsync(
        request: URLRequest
    ) async throws -> (Data, URLResponse) {
        if #available(iOS 15, *) {
            try await data(for: request)
        } else {
            try await withCheckedThrowingContinuation { continuation in
                let task = dataTask(with: request) { data, response, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let data = data, let response = response {
                        continuation.resume(returning: (data, response))
                    } else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                    }
                }
                task.resume()
            }
        }
    }
}
