/// Per-call options for `Session.addMessage()`.
public struct AddMessageOptions: Sendable, Equatable {
    /// When `true`, the preload request is still sent (for analytics) but bids
    /// are not processed — no ad will be shown for this message.
    ///
    /// Use this when you want Kontext to retain conversation context for pacing
    /// and frequency-cap purposes but you don't want to display an ad
    /// (e.g. the user just dismissed an ad slot).
    ///
    /// Mirrors `addMessage(msg, { trackOnly: true })` in the JS family.
    public let trackOnly: Bool

    public init(trackOnly: Bool = false) {
        self.trackOnly = trackOnly
    }
}
