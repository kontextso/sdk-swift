//
//  SharedStorage.swift
//  KontextSwiftSDK
//

import Combine

@MainActor
final class SharedStorage: ObservableObject {
    @Published var bids: [Bid] = []
    @Published var messages: [AdsMessage] = []
    @Published var lastUserMessageId: String?
    @Published var lastAssistantMessageId: String?
    @Published var relevantAssistantMessageId: String?
}
