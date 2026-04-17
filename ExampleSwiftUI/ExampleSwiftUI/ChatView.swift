//
//  ChatView.swift
//  ExampleSwiftUI
//

import Foundation
import OSLog
import KontextSwiftSDK
import SwiftUI

struct ChatMessage: Identifiable, MessageRepresentable {
    let id: String
    let role: Role
    let content: String
    let createdAt: Date = Date()
}

// Example — simulates Polybuzz's flow (KON-1580):
// - Ads shown after every 2nd/3rd message exchange
// - Does NOT handle .cleared events (Polybuzz doesn't cache ads locally)
// - Calls setMessages() on every user + assistant message
struct ChatView: View {
    @State private var adsProvider: AdsProvider
    @State private var messages: [ChatMessage] = []
    @State private var ads: [Advertisement] = []
    @State private var messageCount: Int = 0

    private let userMessages = [
        "Hello my smart helpful assistant, how are you?",
        "Can you recommend a good restaurant nearby?",
        "What about Italian food?",
        "Do they have outdoor seating?",
        "Great, can you book a table for two?",
        "What time works best for dinner?",
    ]

    private let assistantMessages = [
        "I'm doing well, thank you for asking!",
        "Sure! There are several great options in your area.",
        "There's a wonderful Italian place called Trattoria Roma.",
        "Yes, they have a beautiful patio with garden views!",
        "I'd be happy to help with that reservation.",
        "Most people prefer between 7-8 PM for dinner.",
    ]

    init() {
        let character = Character(
            id: "1",
            name: "Assistant",
            avatarUrl: URL(string: "https://example.com/avatar.png"),
            isNsfw: false,
            greeting: "Hello! How can I assist you today?",
            persona: "Helpful smart polite assistant",
            tags: ["friendly", "professional"]
        )

        let configuration = AdsProviderConfiguration(
            publisherToken: "<publisher-token>",
            userId: "1",
            conversationId: "1",
            enabledPlacementCodes: ["inlineAd"],
            character: character,
            regulatory: Regulatory(gdpr: 1, coppa: nil),
            otherParams: ["theme": "dark"]
        )

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
                            Text("\(message.role == .user ? "You" : "Assistant"): \(message.content)")
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

            Button("Send Message (\(messageCount + 1)/\(userMessages.count))") {
                sendMessage()
            }
            .disabled(messageCount >= userMessages.count)
            .padding()
        }
        .onReceive(adsProvider.eventPublisher) { event in
            print("[Polybuzz sim] Event: \(event.name)")
            switch event {
            case .filled(let newAds):
                ads = newAds
            // NOTE: Polybuzz does NOT handle .cleared — they don't cache ads locally
            // case .cleared:
            //     ads = []
            case .adHeight(let newAd):
                guard let index = ads.firstIndex(where: { $0.id == newAd.id }) else {
                    return
                }
                ads[index] = newAd
            default:
                break
            }
        }
    }

    private func sendMessage() {
        guard messageCount < userMessages.count else { return }

        let userMessage = ChatMessage(
            id: UUID().uuidString,
            role: .user,
            content: userMessages[messageCount]
        )

        messages.append(userMessage)
        adsProvider.setMessages(messages)

        let responseIndex = messageCount
        messageCount += 1

        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            handleAssistantResponse(index: responseIndex)
        }
    }

    private func handleAssistantResponse(index: Int) {
        guard index < assistantMessages.count else { return }

        let assistantMessage = ChatMessage(
            id: UUID().uuidString,
            role: .assistant,
            content: assistantMessages[index]
        )

        messages.append(assistantMessage)
        adsProvider.setMessages(messages)
    }
}
