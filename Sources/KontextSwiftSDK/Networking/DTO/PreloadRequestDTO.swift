import Foundation

/// JSON body sent to `POST /preload` — the SDK's main ad-fetching call.
///
/// Mirrors the server's `preloadRequestBodySchema`
/// (`apps/ad-server/app/preload/utils.ts`). Required fields go first;
/// every optional has an explicit `nil` default at construction time
/// so the entire DTO can be built in one pass at the call site
/// (`Preload.buildPreloadDTO`).
///
/// `app` is sent on every request — sdk-js conditionally omits it
/// when `getApp` returns nothing, but iOS always has bundle metadata.
/// `regulatory` is sent only when at least one privacy field has a
/// real value (avoids shipping empty objects).
struct PreloadRequestDTO: Encodable, Sendable {
    let publisherToken: String
    let userId: String
    let conversationId: String
    let enabledPlacementCodes: [String]
    let messages: [MessageDTO]
    let sdk: SDKDTO
    let device: DeviceDTO
    let app: AppDTO

    /// Wire-form sessionId. Stored as `String?` (not `UUID?`) so the
    /// JSONEncoder default — Swift's `UUID.uuidString` is uppercase per
    /// Apple's docs — can't leak uppercase to the wire. The constructor
    /// accepts `UUID?` for type-safety and lowercases at the boundary,
    /// matching sdk-js / sdk-kotlin's RFC-4122 lowercase wire form.
    /// Decode side (`PreloadResponseDTO.sessionId: UUID?`) stays a UUID
    /// because Swift's `UUID(uuidString:)` is case-tolerant on parse.
    let sessionId: String?
    let character: CharacterDTO?
    let regulatory: RegulatoryDTO?
    let userEmail: String?
    let variantId: String?
    let advertisingId: String?
    let vendorId: String?

    init(
        publisherToken: String,
        userId: String,
        conversationId: String,
        enabledPlacementCodes: [String],
        messages: [MessageDTO],
        sdk: SDKDTO,
        device: DeviceDTO,
        app: AppDTO,
        sessionId: UUID? = nil,
        character: CharacterDTO? = nil,
        regulatory: RegulatoryDTO? = nil,
        userEmail: String? = nil,
        variantId: String? = nil,
        advertisingId: String? = nil,
        vendorId: String? = nil
    ) {
        self.publisherToken = publisherToken
        self.userId = userId
        self.conversationId = conversationId
        self.enabledPlacementCodes = enabledPlacementCodes
        self.messages = messages
        self.sdk = sdk
        self.device = device
        self.app = app
        self.sessionId = sessionId?.uuidString.lowercased()
        self.character = character
        self.regulatory = regulatory
        self.userEmail = userEmail
        self.variantId = variantId
        self.advertisingId = advertisingId
        self.vendorId = vendorId
    }
}
