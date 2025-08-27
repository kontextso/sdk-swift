//
//  ChatView.swift
//  ExampleSwiftUI
//

import Foundation
import KontextSwiftSDK
import SwiftUI

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

    init() {
        // 1. Create configuration with publisher token and relevant conversation data
        let configuration = AdsProviderConfiguration(
            publisherToken: "nexus-dev",
            userId: "1",
            conversationId: "1",
            enabledPlacementCodes: ["inlineAd"]
        )
        // 2. Create AdsProvider associated to this conversation
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
                            // 3. Insert InlineAdView which will expand when ad is available
                            // If there is no respective ad for the message it will stay empty
                            InlineAdView(
                                adsProvider: adsProvider,
                                code: "inlineAd",
                                messageId: message.id,
                                otherParams: [:]
                            )
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
    }

    private func sendMessage() {
        // Simulate user message
        let userMessage = ChatMessage(
            id: UUID().uuidString,
            role: .user,
            content: "kontextso ad_format:INTERSTITIAL_REWARDED"
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
