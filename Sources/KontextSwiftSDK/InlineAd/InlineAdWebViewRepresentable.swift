//
//  InlineAdView.swift
//  KontextSwiftSDK
//

import SwiftUI
import UIKit

struct InlineAdWebViewRepresentable: UIViewRepresentable {
    private let url: URL
    private let updateIFrameData: UpdateIFrameData
    @Binding private var iframeEvent: InlineAdEvent?
    
    init(
        url: URL,
        updateIFrameData: UpdateIFrameData,
        iframeEvent: Binding<InlineAdEvent?>
    ) {
        self.url = url
        self.updateIFrameData = updateIFrameData
        self._iframeEvent = iframeEvent
    }
    
    func makeUIView(context: Context) -> InlineAdWebView {
        let view = InlineAdWebView(
            frame: .zero,
            updateFrameData: updateIFrameData,
            iframeEvent: $iframeEvent
        )
        view.loadAd(from: url)
        return view
    }
    
    func updateUIView(_ uiView: InlineAdWebView, context: Context) {
        if uiView.url != url {
            uiView.loadAd(from: url)
        }
    }
}
