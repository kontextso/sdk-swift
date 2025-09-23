extension EventIframeDataDTO: ModelConvertible {
    func toModel() -> AdsEvent {
        type.toModel()
    }
}

extension EventIframeDataDTO.TypeDTO: ModelConvertible {
    func toModel() -> AdsEvent {
        switch self {
        case .viewed(let viewedDataDTO):
            .viewed(viewedDataDTO?.toModel())
        case .clicked(let clickedDataDTO):
            .clicked(clickedDataDTO?.toModel())
        case .renderStarted(let generalDataDTO):
            .renderStarted(generalDataDTO?.toModel())
        case .renderCompleted(let generalDataDTO):
            .renderCompleted(generalDataDTO?.toModel())
        case .error(let errorDataDTO):
            .error(errorDataDTO?.toModel())
        case .videoStarted(let generalDataDTO):
            .videoStarted(generalDataDTO?.toModel())
        case .videoCompleted(let generalDataDTO):
            .videoCompleted(generalDataDTO?.toModel())
        case .rewardGranted(let generalDataDTO):
            .rewardGranted(generalDataDTO?.toModel())
        case .event(let dictionary):
            .event(dictionary)
        }
    }
}

extension EventIframeDataDTO.ViewedDataDTO: ModelConvertible {
    func toModel() -> AdsEvent.ViewedData {
        AdsEvent.ViewedData(
            bidId: id,
            content: content,
            messageId: messageId,
            format: format
        )
    }
}

extension EventIframeDataDTO.ClickedDataDTO: ModelConvertible {
    func toModel() -> AdsEvent.ClickedData {
        AdsEvent.ClickedData(
            bidId: id,
            content: content,
            messageId: messageId,
            url: url,
            format: format,
            area: area
        )
    }
}

extension EventIframeDataDTO.ErrorDataDTO: ModelConvertible {
    func toModel() -> AdsEvent.ErrorData {
        AdsEvent.ErrorData(
            message: message,
            errCode: errCode
        )
    }
}

extension EventIframeDataDTO.GeneralDataDTO: ModelConvertible {
    func toModel() -> AdsEvent.GeneralData {
        AdsEvent.GeneralData(bidId: id)
    }
}
