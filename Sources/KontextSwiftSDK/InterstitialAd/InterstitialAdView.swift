import SwiftUI

struct InterstitialAdView: View {
    @State private var url: URL?
    private var onIFrameEvent: (AdEvent) -> Void

    init(
        url: URL?,
        onIFrameEvent: @escaping (AdEvent) -> Void
    ) {
        _url = State(initialValue: url)
        self.onIFrameEvent = onIFrameEvent
    }

    var body: some View {
        ZStack {
            if let url {
                AdWebViewRepresentable(
                    url: url,
                    updateIFrameData: nil,
                    onIFrameEvent: { _ in  }
                )
//                .opacity(viewModel.showIframe ? 1 : 0)
                .ignoresSafeArea()
            } else {
                ProgressView()
            }

//            if !viewModel.showIframe {
//                ProgressView()
//            }
        }
    }
}
