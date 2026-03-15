struct AudioDTO: Encodable {
    let volume: Int
    let muted: Bool
    let outputPluggedIn: Bool
    let outputType: [AudioOutputType]
}
