//
//  InterstitialAd.swift
//  KontextSwiftSDK
//

import SwiftUI

struct InterstitialAdView: View {
    @StateObject private var viewModel: InterstitialAdViewModel

    init(input: InterstitialAdViewModel.Input) {
        self._viewModel = StateObject(
            wrappedValue: InterstitialAdViewModel(input: input)
        )
    }

    var body: some View {
        ZStack {
            if let url = viewModel.url {
                AdWebViewRepresentable(
                    url: url,
                    onIframeEvent: { viewModel.send(.didReceiveAdEvent($0)) }
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
