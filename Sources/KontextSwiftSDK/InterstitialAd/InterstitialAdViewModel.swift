import Combine
import UIKit

@MainActor
final class InterstitialAdViewModel: ObservableObject {
    private var cancellables: Set<AnyCancellable> = []

    @Published private(set) var showIframe: Bool = false
    @Published private(set) var url: URL?

    init(
        url: URL?,
        events: AnyPublisher<InterstitialAdEvent, Never>
    ) {
        self.url = url

        events
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                switch event {
                case .didChangeDisplay(let showIframe):
                    self?.showIframe = showIframe
                }
            }
            .store(in: &cancellables)
    }
}
