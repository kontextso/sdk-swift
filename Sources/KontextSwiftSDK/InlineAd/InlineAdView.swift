import Combine
import SwiftUI
import StoreKit

enum InlineAdEvent {
    case didRequestInterstitialAd(
        InterstitialAdView.Params,
        UIModalPresentationStyle = .fullScreen
    )
    case didRequestSKOverlay(SKOverlayParams)
    case didFinishSKOverlay
    case didFinishInterstitialAd
}

/// SwiftUI view that represents an inline ad in the chat UI.
public struct InlineAdView: View {
    @StateObject private var viewModel: InlineAdViewModel
    /// Screen data
    @State private var keyboardHeight: CGFloat = 0
    @State private var rect: CGRect = .zero
    @State private var timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    /// Presentation
    @State private var interstitialParams: InterstitialAdView.Params?
    @State private var skOverlayParams: SKOverlayParams?

    /// Events targeted for AdWebView
    @State private var adWebViewEventsSubject = PassthroughSubject<AdWebViewUpdateEvent, Never>()

    private let ad: Advertisement

    /// - Parameters:
    ///   - ad: Advertisement to be displayed.
    public init(ad: Advertisement) {
        self.ad = ad
        _viewModel = StateObject(wrappedValue: InlineAdViewModel(ad: ad))
    }

    public var body: some View {
        Group {
            if let url = viewModel.ad.webViewData.url {
                AdWebViewRepresentable(
                    url: url,
                    updateIFrameData: viewModel.ad.webViewData.updateData,
                    eventPublisher: adWebViewEventsSubject.eraseToAnyPublisher(),
                    onIFrameEvent: { event in
                        viewModel.ad.webViewData.onIFrameEvent(event)
                    }
                )
                .readRect(coordinateSpace: .global) {
                    rect = $0
                }
                .frame(height: viewModel.ad.preferredHeight)
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
        .fullScreenCover(item: $interstitialParams) { params in
            InterstitialAdView(params: params)
        }
        .onChange(of: ad) { newAd in
            viewModel.ad = newAd
        }
        .onReceive(Publishers.keyboardHeight) { height in
            keyboardHeight = height
        }
        .onReceive(timer) { _ in
            reportUpdateDimensions()
        }
        .onReceive(viewModel.ad.webViewData.events) { event in
            switch event {
            case .didRequestInterstitialAd(let params, _):
                interstitialParams = params
            case .didRequestSKOverlay(let params):
                skOverlayParams = params
            case .didFinishInterstitialAd:
                interstitialParams = nil
            case .didFinishSKOverlay:
                skOverlayParams = nil
            }
        }
    }
}

// MARK: Private
private extension InlineAdView {
    func reportUpdateDimensions() {
        let screenSize = UIScreen.main.bounds.size
        let data = UpdateDimensionsIFrameDataDTO.Data(
            screenWidth: screenSize.width,
            screenHeight: screenSize.height,
            containerWidth: rect.width,
            containerHeight: rect.height,
            containerX: rect.minX,
            containerY: rect.minY,
            keyboardHeight: keyboardHeight
        )

        adWebViewEventsSubject.send(.didPrepareUpdateDimensions(
            UpdateDimensionsIFrameDataDTO(data: data)
        ))
    }
}
