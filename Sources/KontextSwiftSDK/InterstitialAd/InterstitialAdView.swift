import Combine
import StoreKit
import SwiftUI

enum InterstitialAdEvent {
    case didChangeDisplay(Bool)
    case didRequestSKOverlay(SKOverlayParams)
    case didFinishSKOverlay
    case didRequestStoreProductDisplay(StoreProductView.Params)
}

struct InterstitialAdView: View {
    struct Params: Identifiable {
        var id: String { url?.absoluteString ?? UUID().uuidString }
        let url: URL?
        let events: AnyPublisher<InterstitialAdEvent, Never>
        let onIFrameEvent: (IframeEvent) -> Void
    }

    @State private var showIframe: Bool = false
    @State private var skOverlayParams: SKOverlayParams?
    @State private var skStoreProductParams: StoreProductView.Params?

    private let params: Params

    init(params: Params) {
        self.params = params
    }

    var body: some View {
        ZStack {
            if let url = params.url {
                AdWebViewRepresentable(
                    url: url,
                    updateIFrameData: nil,
                    onIFrameEvent: { params.onIFrameEvent($0) }
                )
                .opacity(showIframe ? 1 : 0)
            }

            if let params = skStoreProductParams {
                StoreProductView(
                    params: params,
                    isPresented: Binding(
                        get: { skStoreProductParams != nil },
                        set: { newValue in
                            if !newValue {
                                skStoreProductParams = nil
                            }
                        }
                    )
                )
                .frame(width: .zero, height: .zero)
            }

            if !showIframe {
                ProgressView()
            }
        }
        .appStoreOverlay(
            isPresented: Binding(
                get: { skOverlayParams != nil },
                set: { newValue in
                    if !newValue {
                        skOverlayParams = nil
                    }
                }
            )
        ) {
            SKOverlay.AppConfiguration(
                appIdentifier: skOverlayParams?.appStoreId ?? "",
                position: skOverlayParams?.position ?? .bottom
            )
        }
        .onReceive(params.events) { event in
            switch event {
            case .didChangeDisplay(let value):
                showIframe = value
            case .didRequestSKOverlay(let params):
                skOverlayParams = params
            case .didRequestStoreProductDisplay(let params):
                skStoreProductParams = params
            case .didFinishSKOverlay:
                skOverlayParams = nil
            }
        }
    }
}
