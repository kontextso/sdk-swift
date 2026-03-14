/// Determines when impression attribution should be started
public enum ImpressionTrigger: String, Decodable, Sendable {
    /// Impression is tracked immediately when the ad is rendered
    case immediate
    /// Impression is tracked when the ad component becomes visible
    case component
}
