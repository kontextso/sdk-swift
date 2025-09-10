import Foundation

func withTimeout<T: Sendable>(
    _ duration: TimeInterval,
    _ work: @Sendable @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await work()
        }

        group.addTask {
            try await Task.sleep(seconds: duration)
            throw CancellationError()
        }

        guard let data = try await group.next() else {
            throw CancellationError()
        }

        group.cancelAll()
        return data
    }
}
