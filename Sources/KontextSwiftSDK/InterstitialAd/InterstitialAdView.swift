import Combine
import SwiftUI

enum InterstitialAdEvent {
    case didChangeDisplay(Bool)
    case didUpdateSKOverlay(UpdateSKOverlayIFrameDataDTO)
}

struct InterstitialAdView: View {
    struct Params: Identifiable {
        var id: String { url?.absoluteString ?? UUID().uuidString }
        let url: URL?
        let placementCode: String
        let events: AnyPublisher<InterstitialAdEvent, Never>
        let onIFrameEvent: (IframeEvent) -> Void
    }

    @StateObject private var viewModel: InterstitialAdViewModel
    @State private var adWebViewEventsSubject = PassthroughSubject<AdWebViewUpdateEvent, Never>()
    private let placementCode: String
    private let events: AnyPublisher<InterstitialAdEvent, Never>
    private var onIFrameEvent: (IframeEvent) -> Void

    init(params: Params) {
        _viewModel = StateObject(
            wrappedValue: InterstitialAdViewModel(
                url: params.url,
                events: params.events
            )
        )
        self.placementCode = params.placementCode
        self.events = params.events
        self.onIFrameEvent = params.onIFrameEvent
    }

    var body: some View {
        ZStack {
            if let url = viewModel.url {
                AdWebViewRepresentable(
                    url: url,
                    updateIFrameData: nil,
                    eventPublisher: adWebViewEventsSubject.eraseToAnyPublisher(),
                    onIFrameEvent: { onIFrameEvent($0) }
                )
                .opacity(viewModel.showIframe ? 1 : 0)
            }

            if !viewModel.showIframe {
                ProgressView()
            }
        }
        .onReceive(events) { event in
            switch event {
            case .didChangeDisplay:
                break
            case .didUpdateSKOverlay(let data):
                guard data.data.code == placementCode else {
                    return
                }
                adWebViewEventsSubject.send(.didUpdateSKOverlay(data))
            }
        }
    }
}
