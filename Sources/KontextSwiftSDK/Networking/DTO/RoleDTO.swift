enum RoleDTO: String, Codable {
    /// Author of the message is the user of the app
    case user
    /// Author of the message is the assistant (AI), generated message
    case assistant

    init(from model: Role) {
        switch model {
        case .user: self = .user
        case .assistant: self = .assistant
        }
    }
}
