import Testing
import UIKit
@testable import KontextSwiftSDK

private let testURL = URL(string: "https://server.megabrain.co/api/modal/0198e56b-4c21-7001-bf8a-9dc46419043a?messageId=443DE94E-1179-4C37-9F88-5FC1DEC5FEFA&code=inlineAd")!
private let timeout: TimeInterval = 1

// MARK: - Tests
struct AdsProviderTests {
    // MARK: Ad available
    @Test
    @available(iOS 15, *)
    func testAdAvailable() async throws {
        let sut = createSUT()
        sut.setMessages(AdsMessage.variation1)

        let stream = sut.eventPublisher
            .buffer(size: 1, prefetch: .keepFull, whenFull: .dropOldest)
            .values

        do {
            try await withTimeout(timeout) {
                for await event in stream {
                    if case let .filled(ads) = event, !ads.isEmpty {
                        #expect(!ads.isEmpty)
                        break
                    }
                }
            }
        } catch {
            Issue.record("Expected available ad.")
        }
    }

    // MARK: Ad not available
    @Test
    @available(iOS 15, *)
    func testAdNotAvailable() async throws {
        let sut = createSUT(behaviour: .adNotAvailable)
        let messages = AdsMessage.variation1
        sut.setMessages(messages)

        let stream = sut.eventPublisher
            .buffer(size: 1, prefetch: .keepFull, whenFull: .dropOldest)
            .values

        do {
            try await withTimeout(timeout) {
                for await event in stream {
                    if case let .noFill(data) = event {
                        #expect(
                            AdsMessage.variation1.contains(where: {
                                $0.id == data.messageId
                            })
                        )
                        break
                    }
                }
            }
        } catch {
            Issue.record("Expected ad not available.")
        }
    }

    // MARK: Hide ad
    @Test
    @available(iOS 15, *)
    func testHideIframeEvent() async throws {
        let sut = createSUT()
        sut.setMessages(AdsMessage.variation1)

        let stream = sut.eventPublisher
            .buffer(size: 1, prefetch: .keepFull, whenFull: .dropOldest)
            .values

        do {
            try await withTimeout(timeout) {
                var didHideIframe = false

                for await event in stream {
                    if case let .filled(ads) = event, let ad = ads.first {
                        didHideIframe = true
                        ad.webViewData.onIFrameEvent(.hideIframe)
                    }

                    if case let .filled(ads) = event, ads.isEmpty, didHideIframe {
                        #expect(didHideIframe)
                        break
                    }
                }
            }
        } catch {
            Issue.record("Expected hideIframe event to fire.")
        }
    }

    // MARK: Show ad
    @Test
    @available(iOS 15, *)
    func testShowIframeEvent() async throws {
        let sut = createSUT()
        sut.setMessages(AdsMessage.variation1)

        let stream = sut.eventPublisher
            .buffer(size: 1, prefetch: .keepFull, whenFull: .dropOldest)
            .values

        do {
            try await withTimeout(timeout) {
                var didHideIframe = false
                var advertisement: Advertisement?

                for await event in stream {
                    if case let .filled(ads) = event, let ad = ads.first {
                        advertisement = ad

                        if !didHideIframe {
                            ad.webViewData.onIFrameEvent(.hideIframe)
                        } else {
                            #expect(didHideIframe)
                            break
                        }
                    }

                    if case let .filled(ads) = event, ads.isEmpty {
                        didHideIframe = true
                        advertisement?.webViewData.onIFrameEvent(.showIframe)
                    }
                }
            }
        } catch {
            Issue.record("Expected showIframe event to fire.")
        }
    }

    // MARK: Click ad
    @Test
    @available(iOS 15, *)
    func testClickIframeEvent() async throws {
        let urlOpener = await MockURLOpener()
        let sut = createSUT(urlOpener: urlOpener)

        Task {
            try? await Task.sleep(milliseconds: 0.1)
            sut.setMessages(AdsMessage.variation1)
        }

        let stream = sut.eventPublisher
            .buffer(size: 1, prefetch: .keepFull, whenFull: .dropOldest)
            .values

        do {
            try await withTimeout(0.1) {
                for await event in stream {
                    if case let .filled(ads) = event, let ad = ads.first {
                        ad.webViewData.onIFrameEvent(
                            .clickIframe(
                                IframeEvent.ClickIframeDataDTO(
                                    id: ad.bid.bidId,
                                    content: "content",
                                    messageId: ad.messageId,
                                    url: testURL
                                )
                            )
                        )

                        try? await Task.sleep(milliseconds: 10)
                        #expect(await urlOpener.didOpenURL(testURL))
                        break
                    }
                }
            }
        } catch {
            Issue.record("Expected clickIframe event to fire.")
        }
    }

    // MARK: Ad error
    @Test
    @available(iOS 15, *)
    func testAdError() async throws {
        let sut = createSUT()
        sut.setMessages(AdsMessage.variation1)
        let errorMessage = "Error in iFrame ad rendering."

        let stream = sut.eventPublisher
            .buffer(size: 1, prefetch: .keepFull, whenFull: .dropOldest)
            .values

        do {
            try await withTimeout(timeout) {
                var didSendError = false

                for await event in stream {
                    if case let .filled(ads) = event {
                        if let ad = ads.first, !didSendError {
                            ad.webViewData.onIFrameEvent(
                                .errorIframe(
                                    IframeEvent.ErrorDataDTO(
                                        message: errorMessage
                                    )
                                )
                            )
                            didSendError = true
                        } else if didSendError {
                            #expect(ads.isEmpty)
                            break
                        }
                    }
                }
            }
        } catch {
            Issue.record("Expected ad error event to fire.")
        }
    }

    // MARK: Ad event
    @Test
    @available(iOS 15, *)
    func testAdEvent() async throws {
        let sut = createSUT()
        sut.setMessages(AdsMessage.variation1)

        let stream = sut.eventPublisher
            .buffer(size: 1, prefetch: .keepFull, whenFull: .dropOldest)
            .values

        let errorData = EventIframeDataDTO.ViewedDataDTO(
            id: UUID().uuidString,
            content: "content",
            messageId: UUID().uuidString
        )

        do {
            try await withTimeout(timeout) {
                for await event in stream {
                    if case let .filled(ads) = event, let ad = ads.first {
                        ad.webViewData.onIFrameEvent(
                            .eventIframe(
                                EventIframeDataDTO(
                                    name: "ad.viewed",
                                    code: "",
                                    type: .viewed(errorData)
                                )
                            )
                        )
                    }

                    if case let .viewed(data) = event {
                        #expect(data != nil)
                        #expect(data?.bidId == errorData.id)
                        #expect(data?.messageId == errorData.messageId)
                        break
                    }
                }
            }
        } catch {
            Issue.record("Expected ad event to fire.")
        }
    }
}

// MARK: Utils
private extension AdsProviderTests {
    func createSUT(
        behaviour: MockAdsServerAPISimulationBehaviour = .adAvailable,
        urlOpener: URLOpening = UIApplication.shared
    ) -> AdsProvider {
        AdsProvider(
            configuration: .minimal,
            dependencies: createDependencies(
                configuration: .minimal,
                sessionId: nil,
                isDisabled: false,
                behaviour: behaviour,
                urlOpener: urlOpener
            )
        )
    }

    func createDependencies(
        configuration: AdsProviderConfiguration,
        sessionId: String?,
        isDisabled: Bool,
        behaviour: MockAdsServerAPISimulationBehaviour,
        urlOpener: URLOpening
    ) -> DependencyContainer {
        let networking = Network()
        let adsServerAPI = MockAdsServerAPI(behaviour)
        let providerActor = AdsProviderActor(
            configuration: configuration,
            sessionId: sessionId,
            isDisabled: isDisabled,
            adsServerAPI: adsServerAPI,
            urlOpener: urlOpener
        )

        return DependencyContainer(
            networking: networking,
            adsServerAPI: adsServerAPI,
            adsProviderActing: providerActor
        )
    }
}
