struct UpdateIFrameDTO: Encodable, Hashable {
    let type: String = "update-iframe"
    let data: IframeEvent.UpdateIFrameDataDTO
}
