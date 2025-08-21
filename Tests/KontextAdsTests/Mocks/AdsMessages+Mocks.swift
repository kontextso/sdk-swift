//
//  AdsMessages+Mocks.swift
//  KontextSwiftSDK
//

import Foundation
@testable import KontextSwiftSDK

extension AdsMessage {
    // 1. Alternating, ends with assistant
    static let variation1: [AdsMessage] = [
        AdsMessage(id: "1", role: .user, content: "Hi", createdAt: Date()),
        AdsMessage(id: "2", role: .assistant, content: "Hello!", createdAt: Date()),
        AdsMessage(id: "3", role: .user, content: "How's it going?", createdAt: Date()),
        AdsMessage(id: "4", role: .assistant, content: "All good!", createdAt: Date()),
        AdsMessage(id: "5", role: .assistant, content: "And you?", createdAt: Date())
    ]

    // 2. Alternating, ends with user
    static let variation2: [AdsMessage] = [
        AdsMessage(id: "1", role: .user, content: "Hey", createdAt: Date()),
        AdsMessage(id: "2", role: .assistant, content: "Hi!", createdAt: Date()),
        AdsMessage(id: "3", role: .user, content: "What's up?", createdAt: Date()),
        AdsMessage(id: "4", role: .user, content: "Any news?", createdAt: Date()),
        AdsMessage(id: "5", role: .assistant, content: "Nothing much", createdAt: Date())
    ]

    // 3. Starts assistant, ends with multiple assistant
    static let variation3: [AdsMessage] = [
        AdsMessage(id: "1", role: .assistant, content: "Hello!", createdAt: Date()),
        AdsMessage(id: "2", role: .user, content: "Hi", createdAt: Date()),
        AdsMessage(id: "3", role: .assistant, content: "How can I help?", createdAt: Date()),
        AdsMessage(id: "4", role: .assistant, content: "Do you need anything?", createdAt: Date()),
        AdsMessage(id: "5", role: .assistant, content: "I'm here to help", createdAt: Date())
    ]

    // 4. Alternating, ends with two users
    static let variation4: [AdsMessage] = [
        AdsMessage(id: "1", role: .user, content: "Hello", createdAt: Date()),
        AdsMessage(id: "2", role: .assistant, content: "Hi!", createdAt: Date()),
        AdsMessage(id: "3", role: .user, content: "Question 1", createdAt: Date()),
        AdsMessage(id: "4", role: .user, content: "Question 2", createdAt: Date()),
        AdsMessage(id: "5", role: .assistant, content: "Answer", createdAt: Date())
    ]

    // 5. Alternating, ends with single assistant
    static let variation5: [AdsMessage] = [
        AdsMessage(id: "1", role: .user, content: "Start", createdAt: Date()),
        AdsMessage(id: "2", role: .assistant, content: "Reply", createdAt: Date()),
        AdsMessage(id: "3", role: .user, content: "Follow-up", createdAt: Date()),
        AdsMessage(id: "4", role: .assistant, content: "Reply again", createdAt: Date()),
        AdsMessage(id: "5", role: .user, content: "Final user message", createdAt: Date())
    ]

    // One extra message for user
    static let extraUserMessage = AdsMessage(
        id: "user_extra_1",
        role: .user,
        content: "This is an extra user message",
        createdAt: Date()
    )

    // One extra message for assistant
    static let extraAssistantMessage = AdsMessage(
        id: "assistant_extra_1",
        role: .assistant,
        content: "This is an extra assistant message",
        createdAt: Date()
    )
}
