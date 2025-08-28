import Combine
import SwiftUI

enum InterstitialAdEvent {
    case didChangeDisplay(Bool)
}

struct InterstitialAdView: View {
    @StateObject private var viewModel: InterstitialAdViewModel
    private var onIFrameEvent: (AdEvent) -> Void

    init(
        url: URL?,
        events: AnyPublisher<InterstitialAdEvent, Never>,
        onIFrameEvent: @escaping (AdEvent) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: InterstitialAdViewModel(
                url: url,
                events: events
            )
        )
        self.onIFrameEvent = onIFrameEvent
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
                .ignoresSafeArea()
            }

            if !viewModel.showIframe {
                ProgressView()
            }
        }
    }
}
