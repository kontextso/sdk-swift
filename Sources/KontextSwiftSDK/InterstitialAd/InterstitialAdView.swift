import Combine
import SwiftUI

enum InterstitialAdEvent {
    case didChangeDisplay(Bool)
}

struct InterstitialAdView: View {
    struct Params: Identifiable {
        var id: String { url?.absoluteString ?? UUID().uuidString }
        let url: URL?
        let events: AnyPublisher<InterstitialAdEvent, Never>
        let onIFrameEvent: (IframeEvent) -> Void
    }

    @StateObject private var viewModel: InterstitialAdViewModel
    private var onIFrameEvent: (IframeEvent) -> Void

    init(params: Params) {
        _viewModel = StateObject(
            wrappedValue: InterstitialAdViewModel(
                url: params.url,
                events: params.events
            )
        )
        self.onIFrameEvent = params.onIFrameEvent
    }

    var body: some View {
        ZStack {
            if let url = viewModel.url {
                AdWebViewRepresentable(
                    url: url,
                    updateIFrameData: nil,
                    onIFrameEvent: { onIFrameEvent($0) }
                )
                .opacity(viewModel.showIframe ? 1 : 0)
            }

            if !viewModel.showIframe {
                ProgressView()
            }
        }
    }
}
