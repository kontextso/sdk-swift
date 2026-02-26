struct UpdateSKOverlayIFrameDataDTO: Encodable, Sendable {
    let type: String = "update-skoverlay-iframe"
    let data: Data
}

extension UpdateSKOverlayIFrameDataDTO {
    struct Data: Encodable, Sendable {
        let code: String
        let open: Bool
    }
}
