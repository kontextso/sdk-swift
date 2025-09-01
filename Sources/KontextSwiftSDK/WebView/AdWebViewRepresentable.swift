import SwiftUI
import UIKit

struct AdWebViewRepresentable: UIViewRepresentable {
    private let url: URL
    private let updateIFrameData: IframeEvent.UpdateIFrameDataDTO?
    private let onIFrameEvent: (IframeEvent) -> Void
    
    init(
        url: URL,
        updateIFrameData: IframeEvent.UpdateIFrameDataDTO?,
        onIFrameEvent: @escaping (IframeEvent) -> Void
    ) {
        self.url = url
        self.updateIFrameData = updateIFrameData
        self.onIFrameEvent = onIFrameEvent
    }
    
    func makeUIView(context: Context) -> AdWebView {
        let view = AdWebView(
            updateIframeData: updateIFrameData,
            onIFrameEvent: onIFrameEvent
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
