import Foundation

/// Reference-type sink for values produced by `@Sendable` callbacks in
/// tests (e.g. `AdEventHandler`, `DebugEventHandler`).
///
/// Why not just `var events: [T] = []`? Capturing a mutable local var in a
/// `@Sendable` closure is rejected under Swift 6 strict concurrency. Class
/// references survive the capture cleanly, and the lock makes the
/// `@unchecked Sendable` honest — even though tests run on MainActor in
/// practice, the closure types make no such promise.
final class TestCollector<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [T] = []

    /// Appends an item — safe to call from any thread.
    func append(_ item: T) {
        lock.lock()
        defer { lock.unlock() }
        items.append(item)
    }

    /// Snapshot of recorded items. Each access takes the lock once.
    var values: [T] {
        lock.lock()
        defer { lock.unlock() }
        return items
    }

    var count: Int { values.count }
    var first: T? { values.first }
    var isEmpty: Bool { values.isEmpty }

    /// Convenience indexed access on the snapshot.
    subscript(index: Int) -> T { values[index] }
}
