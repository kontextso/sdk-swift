import Foundation

enum IframeComponentKind {
    case modal
    case skoverlay
    case skstoreproduct
    case unknown(String)

    init(componentName: String) {
        switch componentName.lowercased() {
        case "modal":
            self = .modal
        case "skoverlay":
            self = .skoverlay
        case "skstoreproduct":
            self = .skstoreproduct
        default:
            self = .unknown(componentName)
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
            IframeComponentKind(componentName: data.component)
        case .close(let data):
            IframeComponentKind(componentName: data.component)
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
