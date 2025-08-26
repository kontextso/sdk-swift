//
//  InterstitialAd.swift
//  KontextSwiftSDK
//

import SwiftUI

struct InterstitialAdView: View {
    @StateObject private var viewModel: InterstitialAdViewModel

    init(url: URL, onFinished: @escaping () -> Void) {
        _viewModel = StateObject(
            wrappedValue: InterstitialAdViewModel(
                url: url,
                onFinished: onFinished
            )
        )
    }

    var body: some View {
        ZStack {
            AdWebViewRepresentable(
                url: viewModel.url,
                onIframeEvent: { viewModel.send(.didReceiveAdEvent($0)) }
            )
            .frame(maxHeight: viewModel.showIframe ? .infinity : 0)
            .ignoresSafeArea()

            if !viewModel.showIframe {
                ProgressView()
            }
        }
    }
}
