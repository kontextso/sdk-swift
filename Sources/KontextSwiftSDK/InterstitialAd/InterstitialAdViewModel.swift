//
//  InterstitialAdViewModel.swift
//  KontextSwiftSDK
//

import Combine
import UIKit

@MainActor
final class InterstitialAdViewModel: ObservableObject {
    struct Input: Identifiable {
        let id: String
        let code: String
        let messageId: String
        let component: String
        let timeoutInMilliseconds: TimeInterval
        let otherParams: [String: String]
        let adsServerAPI: AdsServerAPI
        let onEvent: (Event) -> Void
    }

    private let adsServerAPI: AdsServerAPI
    private let timeoutInMilliseconds: TimeInterval
    private let onEvent: (Event) -> Void

    private var cancellables: Set<AnyCancellable> = []

    @Published private(set) var showIframe: Bool = false
    @Published private(set) var url: URL?

    init(input: Input) {
        adsServerAPI = input.adsServerAPI
        onEvent = input.onEvent
        timeoutInMilliseconds = input.timeoutInMilliseconds

        url = adsServerAPI.componentURL(
            messageId: input.messageId,
            bidId: input.id,
            bidCode: input.code,
            component: input.component,
            otherParams: input.otherParams
        )

        handleTimeout()
    }

    func send(_ action: InlineAdViewModel.Action) {
        switch action {
        case .didReceiveAdEvent(let inlineAdEvent):
            onAdEventAction(adEvent: inlineAdEvent)
        }
    }
}

// MARK: Timeout
private extension InterstitialAdViewModel {
    func handleTimeout() {
        Task {
            try await Task.sleep(milliseconds: timeoutInMilliseconds)
            if !showIframe {
                // Close ad if it initComponentIframe event doesn't come in timeout interval
                onEvent(.didFinishAd)
            }
        }
    }
}

extension InterstitialAdViewModel {
    enum Event {
        case didFinishAd
    }
}

// MARK: Action
extension InterstitialAdViewModel {
    enum Action {
        case didReceiveAdEvent(AdEvent)
    }
}

// MARK: Action handler
private extension InterstitialAdViewModel {
    func onAdEventAction(adEvent: AdEvent) {
        switch adEvent {
        case .closeComponentIframe, .errorIframe:
            onEvent(.didFinishAd)

        case .clickIframe(let data):
            if let iframeClickedURL = if let clickDataURL = data.url {
                adsServerAPI.redirectURL(relativeURL: clickDataURL)
            } else {
                url
            } {
                UIApplication.shared.open(iframeClickedURL)
            }

        case .initComponentIframe:
            showIframe = true

        default:
            break
        }
    }
}
