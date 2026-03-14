/// Creative type for Open Measurement session configuration
enum OmCreativeType: String, Sendable {
    /// Display ad (HTML banner)
    case display
    /// Video ad
    case video
}

/// Open Measurement configuration for the ad
struct OmInfo: Sendable, Hashable {
    /// Type of creative used to configure the OMID session
    let creativeType: OmCreativeType
}
