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
    @Environment(\.openURL) private var openURL
    @State var fullscreenCoverIsPresented = false
    @State private var adPresented = false
    @State private var previousUrl: URL?

    @StateObject private var viewModel: InlineAdViewModel
    var didChangeSize: () -> Void

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
        otherParams: [String: String],
        didChangeSize: @escaping () -> Void
    ) {
        let viewModel = adsProvider.inlineAdViewModel(
            code: code,
            messageId: messageId,
            otherParams: otherParams
        )
        _viewModel = StateObject(wrappedValue: viewModel)
        self.didChangeSize = didChangeSize
    }

    public var body: some View {
        if let url = viewModel.url {
            InlineAdWebViewRepresentable(
                url: url,
                updateIFrameData: viewModel.updateIFrameData,
                onIFrameEvent: { viewModel.send(.didReceiveAdEvent($0)) }
            )
            .frame(height: viewModel.showIFrame ? viewModel.preferredHeight : 0)
            .onReceive(viewModel.$iframeClickedURL) { newURL in
                guard let newURL else { return }
                openURL(newURL)
            }
        } else {
            Button(action: {
                self.fullscreenCoverIsPresented = true
            }) {
                Text("Display fullscreenCover modal")
            }
            .fullScreenCover(isPresented: self.$fullscreenCoverIsPresented) {
                VStack {
                    Text("This is a fullscreen modal")
                    Button("Dismiss") {
                        self.fullscreenCoverIsPresented = false
                    }
                }
            }
        }
    }
}
