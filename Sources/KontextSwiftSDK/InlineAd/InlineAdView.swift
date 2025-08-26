//
//  InlineAdView.swift
//  KontextSwiftSDK
//

import SwiftUI

/// SwiftUI view that represents an inline ad in the chat UI.
///
/// - Use InlineAdView below every assistant and user message to allocate the slot.
/// - It will not display ad below every message, only when the ad is available.
/// - Until the ad is available, it will be an empty space.
public struct InlineAdView: View {
    @StateObject private var viewModel: InlineAdViewModel

    @State private var componentURL: URL? = nil

    /// SwiftUI view that represents an inline ad in the chat UI.
    /// It starts as EmptyView and when ad content is retrieved it will expand.
    ///
    /// - Parameters:
    ///   - adsProvider: The AdsProvider instance that manages the ad content.
    ///   - code: Placement code of the ad to be displayed.
    ///   - messageId: The identifier of the message after which the ad should be displayed.
    ///   - otherParams: Additional parameters to be sent to the ad server, for example theme.
    public init(
        adsProvider: AdsProvider,
        code: String,
        messageId: String,
        otherParams: [String: String]
    ) {
        let viewModel = adsProvider.inlineAdViewModel(
            code: code,
            messageId: messageId,
            otherParams: otherParams
        )
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        if let url = viewModel.url {
            AdWebViewRepresentable(
                url: url,
                updateIframeData: viewModel.updateIFrameData,
                onIframeEvent: { viewModel.send(.didReceiveAdEvent($0)) }
            )
            .frame(height: viewModel.preferredHeight)
            .onReceive(viewModel.$componentURL) { url in
                componentURL = url
            }
            .fullScreenCover(item: $componentURL) { url in
                InterstitialAdView(
                    url: url,
                    onFinished: { componentURL = nil }
                )
            }
        }
    }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}
