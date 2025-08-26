//
//  InterstitialAdViewModel.swift
//  KontextSwiftSDK
//

import Foundation

@MainActor
final class InterstitialAdViewModel: ObservableObject {
    private let onFinished: () -> Void

    @Published private(set) var showIframe: Bool = false
    @Published private(set) var url: URL

    init(url: URL, onFinished: @escaping () -> Void) {
        self.url = url
        self.onFinished = onFinished
    }

    func send(_ action: InlineAdViewModel.Action) {
        switch action {
        case .didReceiveAdEvent(let inlineAdEvent):
            onAdEventAction(adEvent: inlineAdEvent)
        }
    }
}

extension InterstitialAdViewModel {
    enum Action {
        case didReceiveAdEvent(AdEvent)
    }
}

private extension InterstitialAdViewModel {
    func onAdEventAction(adEvent: AdEvent) {
        switch adEvent {
        case .closeComponentIframe, .errorIframe:
            onFinished()

        // TODO: Click event

        case .initComponentIframe:
            showIframe = true

        default:
            break
        }
    }
}
