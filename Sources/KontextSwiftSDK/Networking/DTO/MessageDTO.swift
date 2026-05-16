/// A single conversation message in the `/preload` body.
///
/// `role` is the strict `Message.Role` enum (`user` / `assistant`) —
/// the server's enum also allows `'system'`, but that case is reserved
/// for server-generated system prompts and is not exposed in the
/// publisher API. `createdAt` is a pre-formatted ISO 8601 string with
/// millisecond precision (see `DateFormatting`).
struct MessageDTO: Encodable, Sendable {
    let id: String
    let role: Message.Role
    let content: String
    let createdAt: String
}
