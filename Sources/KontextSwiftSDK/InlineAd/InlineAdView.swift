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
        Group {
            if adPresented {
                Rectangle()
                    .fill(.green)
                    .frame(height: 100)
            } else {
                Rectangle()
                    .fill(.green)
                    .frame(height: 60)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        didChangeSize()
                    }
                    .onChange(of: adPresented) { _ in
                        didChangeSize()
                    }
                    .onChange(of: geometry.size) { _ in
                        didChangeSize()
                    }
            }
        )
        .onChange(of: viewModel.url) { newValue in
            if previousUrl != newValue {
                adPresented = true
            }

            previousUrl = newValue
        }
//        if let url = viewModel.url {
//            InlineAdWebViewRepresentable(
//                url: url,
//                updateIFrameData: viewModel.updateIFrameData,
//                iframeEvent: $viewModel.iframeEvent
//            )
//            // .frame(height: viewModel.showIFrame ? viewModel.preferredHeight : 0)
//            .onReceive(viewModel.$iframeClickedURL) { newURL in
//                guard let newURL else { return }
//                openURL(newURL)
//            }
//        } else {
//            Button(action: {
//                self.fullscreenCoverIsPresented = true
//            }) {
//                Text("Display fullscreenCover modal")
//            }
//            .fullScreenCover(isPresented: self.$fullscreenCoverIsPresented) {
//                VStack {
//                    Text("This is a fullscreen modal")
//                    Button("Dismiss") {
//                        self.fullscreenCoverIsPresented = false
//                    }
//                }
//            }
//        }
    }
}
