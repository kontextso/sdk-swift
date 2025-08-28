//
//  ChatView.swift
//  ExampleSwiftUI
//

import Foundation
import KontextSwiftSDK
import SwiftUI

enum TestEvent: String {
    case text = "kontextso ad_format:INLINE"
    case image = "kontextso ad_format:IMAGE"
    case video = "kontextso ad_format:VIDEO"
    case character = "kontextso ad_format:INTERSTITIAL"
    case characterRewarded = "kontextso ad_format:INTERSTITIAL_REWARDED"
}

struct ChatMessage: Identifiable, MessageRepresentable {
    let id: String
    let role: Role
    let content: String
    let createdAt: Date = Date()
}

// Example
struct ChatView: View {
    @State private var adsProvider: AdsProvider
    @State private var messages: [ChatMessage] = []
    @State private var ads: [Advertisement] = []

    init() {
        // 1. Prepare Character information about the assistant (if any)
        let character = Character(
            id: "1",
            name: "Assistant",
            avatarUrl: URL(string: "https://example.com/avatar.png"),
            isNsfw: false,
            greeting: "Hello! How can I assist you today?",
            persona: "Helpful smart polite assistant",
            tags: ["friendly", "professional"]
        )

        // 2. Create configuration with publisher token and relevant conversation data
        let configuration = AdsProviderConfiguration(
            publisherToken: "nexus-dev",
            userId: "1",
            conversationId: "1",
            enabledPlacementCodes: ["inlineAd"],
            character: character,
            regulatory: Regulatory(gdpr: 1, coppa: nil),
            otherParams: ["theme": "dark"]
        )

        // 3. Create AdsProvider associated to this conversation
        // Multiple instances can be created, for each conversation one
        _adsProvider = State(initialValue: AdsProvider(
            configuration: configuration
        ))
    }
    
    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(messages, id: \.id) { message in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(message.content)
                                .padding()
                                .background(message.role == .user ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                                .cornerRadius(8)

                            if let ad = ads.first, ad.messageId == message.id {
                                InlineAdView(ad: ad)
                            }
                        }
                    }
                }
                .padding()
            }

            Button("Send Message") {
                sendMessage()
            }
            .padding()
        }
        .onReceive(adsProvider.eventPublisher) { event in
            switch event {
            case .didChangeAvailableAdsTo(let newAds):
                ads = newAds
            case .didUpdateHeightForAd(let newAd):
                guard let index = ads.firstIndex(where: { $0.id == newAd.id }) else {
                    return
                }

                ads[index] = newAd                
            }
        }
    }

    private func sendMessage() {
        // Simulate user message
        let userMessage = ChatMessage(
            id: UUID().uuidString,
            role: .user,
            content: TestEvent.character.rawValue
        )

        messages.append(userMessage)
        adsProvider.setMessages(messages)

        Task {
            // Simulate assistant response
            try await Task.sleep(nanoseconds: 1_000_000_0)
            handleAssistantResponse()
        }
    }

    private func handleAssistantResponse() {
        // Simulate assistant message
        let assistantMessage = ChatMessage(
            id: UUID().uuidString,
            role: .assistant,
            content: "I'm doing well, thank you for asking!"
        )

        messages.append(assistantMessage)
        adsProvider.setMessages(messages)
    }
}
