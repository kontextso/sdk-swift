//
//  InlineAdView.swift
//  KontextSwiftSDK
//

import SwiftUI
import UIKit

struct AdWebViewRepresentable: UIViewRepresentable {
    private let url: URL
    private let updateIframeData: UpdateIFrameData?
    private let onIframeEvent: (AdEvent) -> Void

    init(
        url: URL,
        updateIframeData: UpdateIFrameData? = nil,
        onIframeEvent: @escaping (AdEvent) -> Void
    ) {
        self.url = url
        self.updateIframeData = updateIframeData
        self.onIframeEvent = onIframeEvent
    }

    func makeUIView(context: Context) -> AdWebView {
        let view = AdWebView(
            frame: .zero,
            updateIframeData: updateIframeData,
            onIframeEvent: onIframeEvent
        )
        view.loadAd(from: url)
        return view
    }

    func updateUIView(_ uiView: AdWebView, context: Context) {
        if uiView.url != url {
            uiView.loadAd(from: url)
        }
    }
}
