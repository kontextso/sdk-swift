//
//  Task+Sleep.swift
//  KontextSwiftSDK
//

import Foundation

extension Task where Success == Never, Failure == Never {
    static func sleep(milliseconds: TimeInterval) async throws {
        let duration = UInt64(milliseconds * 1_000_000)
        try await Task.sleep(nanoseconds: duration)
    }
}
