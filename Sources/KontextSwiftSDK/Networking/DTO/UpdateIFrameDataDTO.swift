struct UpdateIFrameDTO: Encodable, Hashable {
    enum EventType: String, Encodable {
        case updateIFrame = "update-iframe"
    }

    let type: EventType = .updateIFrame
    let data: IframeEvent.UpdateIFrameDataDTO
}
