import Foundation
// CGFloat in dimension fields — analyze can't see it.
// swiftlint:disable:next unused_import
import CoreGraphics

/// Wire DTOs for SDK → iframe `postMessage` traffic. Counterpart to
/// `Iframe/Inbound.swift` (which models the iframe → SDK direction).
///
/// Mirrors the host→iframe variants of `IframeMessages` in
/// `sdk-common/src/iframe-messaging.ts`. Each top-level struct
/// corresponds to one wire `type`; the `type` field is fixed by the
/// initializer so call sites can't accidentally produce a malformed
/// envelope.

/// `update-iframe`: pushes the conversation snapshot, SDK identity,
/// and publisher-supplied `otherParams` (e.g., `theme`) into the iframe
/// after `init-iframe` is observed.
struct UpdateIframeMessageDTO: Encodable, Sendable {
    let type: String
    let data: PayloadData

    init(data: PayloadData) {
        self.type = "update-iframe"
        self.data = data
    }

    struct PayloadData: Encodable, Sendable {
        let messages: [MessageDTO]
        let sdk: String
        let messageId: String
        /// Free-form publisher-supplied params. Today only `theme` is
        /// populated; widening the value type to a more flexible `Any`-
        /// like wrapper would require a custom Encodable layer — defer
        /// until we actually need non-string values on the wire.
        let otherParams: [String: String]
        let code: String
    }
}

/// `update-dimensions-iframe`: periodic viewport / container geometry
/// snapshot used by the iframe for visibility tracking. The payload is
/// `DimensionUpdate` directly — the same struct `InlineAdUIView`
/// constructs, so there's no duplicate-shape boilerplate at the wire
/// boundary.
struct UpdateDimensionsIframeMessageDTO: Encodable, Sendable {
    let type: String
    let data: DimensionUpdate

    init(data: DimensionUpdate) {
        self.type = "update-dimensions-iframe"
        self.data = data
    }
}

/// Snapshot of viewport / container geometry. The window-level fields
/// (`windowWidth`, `windowHeight`) are the app's `UIWindow` bounds,
/// which on iPad split-view / Slide Over differ from the physical
/// screen — both pairs are sent so the iframe can tell the difference.
struct DimensionUpdate: Encodable, Sendable {
    let windowWidth: CGFloat
    let windowHeight: CGFloat
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    let containerWidth: CGFloat
    let containerHeight: CGFloat
    let containerX: CGFloat
    let containerY: CGFloat
    let keyboardHeight: CGFloat
}

/// `user-event-iframe`: publisher → ad. Carries the typed
/// `UserEventName` plus a free-form publisher-supplied payload.
/// `payload` is wrapped in `AnyJSONEncodable` so the rest of the
/// envelope stays compile-time typed while the leaf accepts any
/// JSON-shaped Foundation value (`String`, `Bool`, numbers, arrays,
/// dictionaries).
struct UserEventIframeMessageDTO: Encodable {
    let type: String
    let data: PayloadData
    let code: String

    init(name: UserEventName, payload: [String: Any]?, code: String) {
        self.type = "user-event-iframe"
        self.data = PayloadData(
            name: name.rawValue,
            payload: payload.map(AnyJSONEncodable.init)
        )
        self.code = code
    }

    struct PayloadData: Encodable {
        let name: String
        let payload: AnyJSONEncodable?
    }
}

/// Encodes an arbitrary JSON-shaped Foundation value into a
/// `JSONEncoder`-driven container. Lets typed wrapper DTOs accept a
/// publisher-supplied `[String: Any]?` payload at the leaf without
/// dropping back to `JSONSerialization` for the whole envelope.
///
/// Supported value types are the standard JSON ones: `nil` /
/// `NSNull`, `Bool`, integer types, `Double`, `String`, `[Any]`, and
/// `[String: Any]`. Anything else encodes as `null` rather than
/// throwing — the publisher's payload may contain odd types we
/// don't model, but the SDK shouldn't crash on them.
struct AnyJSONEncodable: Encodable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        // NSNumber-bool must be checked BEFORE the generic `as Bool` /
        // `as Int` casts: a `[String: Any]` round-tripped through
        // `JSONSerialization` (or a publisher payload bridged from
        // Objective-C) gives us `NSNumber`-wrapped values, and Swift's
        // bridging rules will happily satisfy `as Bool` for any non-zero
        // number — so `42` as an `NSNumber` would encode as `true`.
        // CFBooleanGetTypeID() is the only reliable way to distinguish
        // a true bool from a numeric NSNumber.
        case let v as NSNumber where CFGetTypeID(v) == CFBooleanGetTypeID():
            try container.encode(v.boolValue)
        case let v as Bool:
            try container.encode(v)
        case let v as Int:
            try container.encode(v)
        case let v as Int64:
            try container.encode(v)
        case let v as Double:
            try container.encode(v)
        case let v as NSNumber:
            try container.encode(v.doubleValue)
        case let v as String:
            try container.encode(v)
        case let v as [Any]:
            try container.encode(v.map(AnyJSONEncodable.init))
        case let v as [String: Any]:
            try container.encode(v.mapValues(AnyJSONEncodable.init))
        default:
            try container.encodeNil()
        }
    }
}
