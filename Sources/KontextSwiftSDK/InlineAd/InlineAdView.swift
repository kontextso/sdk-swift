import SwiftUI

enum InlineAdEvent {
    case didRequestInterstitialAd(
        InterstitialAdView.Params,
        UIModalPresentationStyle = .fullScreen
    )
    case didFinishInterstitialAd
}

/// SwiftUI view that represents an inline ad in the chat UI.
public struct InlineAdView: View {
    @StateObject private var viewModel: InlineAdViewModel
    @State private var interstitialParams: InterstitialAdView.Params?
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
                    onIFrameEvent: { event in
                        viewModel.ad.webViewData.onIFrameEvent(event)
                    }
                )
                .frame(height: viewModel.ad.preferredHeight)
            }
        }
        .fullScreenCover(item: $interstitialParams) { params in
            InterstitialAdView(params: params)
        }
        .onChange(of: ad) { newAd in
            viewModel.ad = newAd
        }
        .onReceive(viewModel.ad.webViewData.events) { event in
            switch event {
            case .didRequestInterstitialAd(let params, _):
                interstitialParams = params
            case .didFinishInterstitialAd:
                interstitialParams = nil
            }
        }
    }
}
