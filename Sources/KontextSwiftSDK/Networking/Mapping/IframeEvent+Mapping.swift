import Foundation

extension IframeEvent.EventIframeDataDTO: ModelConvertible {
    func toModel() -> AdsEvent {
        AdsEvent(
            name: data.name,
            type: data.type.toModel()
        )
    }
}

extension EventIframeContentDTO.TypeDTO: ModelConvertible {
    func toModel() -> AdsEventType {
        switch self {
        case .viewed(let viewedDataDTO):
            .viewed(viewedDataDTO?.toModel())
        case .clicked(let clickedDataDTO):
            .clicked(clickedDataDTO?.toModel())
        case .videoPlayed(let videoPlayedDataDTO):
            .videoPlayed(videoPlayedDataDTO?.toModel())
        case .videoClosed(let videoClosedDataDTO):
            .videoClosed(videoClosedDataDTO?.toModel())
        case .rewardReceived(let rewardReceivedDataDTO):
            .rewardReceived(rewardReceivedDataDTO?.toModel())
        case .event(let dictionary):
            .event(dictionary)
        }
    }
}

extension EventIframeContentDTO.ViewedDataDTO: ModelConvertible {
    func toModel() -> AdsEventType.ViewedData {
        AdsEventType.ViewedData()
    }
}

extension EventIframeContentDTO.ClickedDataDTO: ModelConvertible {
    func toModel() -> AdsEventType.ClickedData {
        AdsEventType.ClickedData()
    }
}

extension EventIframeContentDTO.VideoClosedDataDTO: ModelConvertible {
    func toModel() -> AdsEventType.VideoClosedData {
        AdsEventType.VideoClosedData()
    }
}

extension EventIframeContentDTO.VideoPlayedDataDTO: ModelConvertible {
    func toModel() -> AdsEventType.VideoPlayedData {
        AdsEventType.VideoPlayedData()
    }
}

extension EventIframeContentDTO.RewardReceivedDataDTO: ModelConvertible {
    func toModel() -> AdsEventType.RewardReceivedData {
        AdsEventType.RewardReceivedData()
    }
}

extension IframeEvent.ClickIframeDataDTO: ModelConvertible {
    func toModel() -> ClickAdEventData {
        ClickAdEventData(
            id: id,
            content: content,
            messageId: messageId,
            url: url
        )
    }
}

extension IframeEvent.ViewIframeDataDTO: ModelConvertible {
    func toModel() -> ViewAdEventData {
        ViewAdEventData(
            id: id,
            content: content,
            messageId: messageId,
            code: code
        )
    }
}
