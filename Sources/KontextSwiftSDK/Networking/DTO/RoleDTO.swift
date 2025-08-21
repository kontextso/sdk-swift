//
//  RoleDTO.swift
//  KontextSwiftSDK
//

enum RoleDTO: String, Codable {
    /// Author of the message is the user of the app
    case user
    /// Author of the message is the assistant (AI), generated message
    case assistant
    /// Author of the message is unknown
    case unknown
    
    init(from model: Role) {
        switch model {
        case .user: self = .user
        case .assistant: self = .assistant
        case .unknown: self = .unknown
        }
    }
}
