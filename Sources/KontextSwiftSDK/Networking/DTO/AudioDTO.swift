/// Audio output state.
///
/// `volume` is 0–100.
///
/// `outputPluggedIn` reports **external-output presence only** — the
/// built-in speaker is excluded. The server's `audioSchema` description
/// (`"Whether ANY audio output is connected"`) reflects v3's wire
/// meaning, when both SDKs counted built-in speakers and the field was
/// therefore always `true`. v4 (this SDK + sdk-kotlin) report the more
/// useful "external output present" signal so an empty `outputType`
/// always pairs with `outputPluggedIn = false`. Server-schema doc is
/// stale — the actual signal mobile SDKs send is "external only".
///
/// `outputType` is the list of currently-connected external outputs —
/// empty when only the built-in speaker is active.
struct AudioDTO: Encodable, Sendable {
    let volume: Int
    let muted: Bool
    let outputPluggedIn: Bool
    let outputType: [AudioOutputType]
}
