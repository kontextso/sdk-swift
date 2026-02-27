import Foundation

enum IframeComponentKind {
    case modal
    case skoverlay

    init(component: IframeEvent.OpenComponentIframeDataDTO.Component) {
        switch component {
        case .modal:
            self = .modal
        case .skoverlay:
            self = .skoverlay
        }
    }
}

enum IframeComponentAction {
    case open
    case close
}

enum IframeComponentSource {
    case inline(AdLoadingState)
    case interstitial(AdLoadingState)
}

enum IframeComponentRequest {
    case open(IframeEvent.OpenComponentIframeDataDTO)
    case close(IframeEvent.ComponentIframeDataDTO)

    var action: IframeComponentAction {
        switch self {
        case .open:
            .open
        case .close:
            .close
        }
    }

    var kind: IframeComponentKind {
        switch self {
        case .open(let data):
            IframeComponentKind(component: data.component)
        case .close(let data):
            IframeComponentKind(component: data.component)
        }
    }

    var code: String {
        switch self {
        case .open(let data):
            data.code
        case .close(let data):
            data.code
        }
    }
}
