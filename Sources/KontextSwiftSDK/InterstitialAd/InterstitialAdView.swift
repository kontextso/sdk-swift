import Combine
import SwiftUI

enum InterstitialAdEvent {
    case didChangeDisplay(Bool)
}

struct InterstitialAdView: View {
    struct Params: Identifiable {
        let id: UUID = UUID()
        let url: URL
        let events: AnyPublisher<InterstitialAdEvent, Never>
        let webViewEvents: AnyPublisher<AdWebViewUpdateEvent, Never>
        let onIFrameEvent: (IframeEvent) -> Void
        let onOMEvent: (OMEvent) -> Void
    }

    @StateObject private var viewModel: InterstitialAdViewModel
    private let events: AnyPublisher<InterstitialAdEvent, Never>
    private let webViewEvents: AnyPublisher<AdWebViewUpdateEvent, Never>
    private var onIFrameEvent: (IframeEvent) -> Void
    private var onOMEvent: (OMEvent) -> Void

    init(params: Params) {
        _viewModel = StateObject(
            wrappedValue: InterstitialAdViewModel(
                url: params.url,
                events: params.events
            )
        )
        self.events = params.events
        self.webViewEvents = params.webViewEvents
        self.onIFrameEvent = params.onIFrameEvent
        self.onOMEvent = params.onOMEvent
    }

    var body: some View {
        ZStack {
            AdWebViewRepresentable(
                url: viewModel.url,
                updateIFrameData: nil,
                eventPublisher: webViewEvents,
                onIFrameEvent: { onIFrameEvent($0) },
                onOMEvent: onOMEvent
            )
            .opacity(viewModel.showIframe ? 1 : 0)
            .animation(.none, value: viewModel.showIframe)

            if !viewModel.showIframe {
                ProgressView()
            }
        }
        .onReceive(events) { event in
            switch event {
            case .didChangeDisplay:
                break
            }
        }
    }
}
