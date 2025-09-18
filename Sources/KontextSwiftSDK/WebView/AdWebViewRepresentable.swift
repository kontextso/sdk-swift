import Combine
import SwiftUI
import UIKit

struct AdWebViewRepresentable: UIViewRepresentable {
    private let url: URL
    private let updateIFrameData: UpdateIFrameDTO?
    private let eventPublisher: AnyPublisher<AdWebViewUpdateEvent, Never>?
    private let onIFrameEvent: (IframeEvent) -> Void
    
    init(
        url: URL,
        updateIFrameData: UpdateIFrameDTO?,
        eventPublisher: AnyPublisher<AdWebViewUpdateEvent, Never>? = nil,
        onIFrameEvent: @escaping (IframeEvent) -> Void
    ) {
        self.url = url
        self.updateIFrameData = updateIFrameData
        self.eventPublisher = eventPublisher
        self.onIFrameEvent = onIFrameEvent
    }
    
    func makeUIView(context: Context) -> AdWebView {
        let view = AdWebView(
            updateIframeData: updateIFrameData,
            eventPublisher: eventPublisher,
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
