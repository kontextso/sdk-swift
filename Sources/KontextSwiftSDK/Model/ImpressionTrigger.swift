/// Determines when impression attribution should be started
enum ImpressionTrigger: String, Sendable {
    /// Impression is tracked immediately when the ad is rendered
    case immediate
    /// Impression is tracked when the ad component becomes visible
    case component
}
