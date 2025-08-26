//
//  InlineAdView.swift
//  KontextSwiftSDK
//

import SwiftUI
import UIKit

struct InlineAdWebViewRepresentable: UIViewRepresentable {
    private let url: URL
    private let updateIFrameData: UpdateIFrameData
    private let onIFrameEvent: (InlineAdEvent) -> Void
    
    init(
        url: URL,
        updateIFrameData: UpdateIFrameData,
        onIFrameEvent: @escaping (InlineAdEvent) -> Void
    ) {
        self.url = url
        self.updateIFrameData = updateIFrameData
        self.onIFrameEvent = onIFrameEvent
    }
    
    func makeUIView(context: Context) -> InlineAdWebView {
        let view = InlineAdWebView(
            frame: .zero,
            updateFrameData: updateIFrameData,
            onIFrameEvent: onIFrameEvent
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
