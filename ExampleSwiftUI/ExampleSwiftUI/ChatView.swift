import SwiftUI
import KontextSwiftSDK

struct ChatMessage: Identifiable {
    let id: String
    let role: Message.Role
    let content: String
}

struct ChatView: View {
    @State private var session: Session
    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var loading = false

    /// Cached ads by message ID — prevents recreating on every body evaluation.
    @State private var ads: [String: Ad] = [:]

    init() {
        let session = KontextAds.createSession(SessionOptions(
            publisherToken: "nexus-dev",
            userId: UUID().uuidString,
            conversationId: UUID().uuidString,
            enabledPlacementCodes: ["inlineAd"],
            onEvent: { event in
                print("[kontext] \(event)")
            },
            onDebugEvent: { name, payload in
                if let payload {
                    print("[kontext-debug] \(name) \(payload)")
                } else {
                    print("[kontext-debug] \(name)")
                }
            }
        ))
        _session = State(initialValue: session)
    }

    private var lastAssistantId: String? {
        guard !loading else { return nil }
        return messages.last(where: { $0.role == .assistant })?.id
    }

    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(messages) { msg in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(msg.role == .user ? "You" : "Assistant"): \(msg.content)")
                                .padding()
                                .background(msg.role == .user ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                .cornerRadius(8)

                            if msg.id == lastAssistantId, let ad = ads[msg.id] {
                                InlineAdView(ad: ad)
                            }
                        }
                    }

                    if loading {
                        Text("Loading...")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding()
            }

            HStack {
                TextField("Type a message...", text: $input, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .disabled(loading)

                Button("Send") {
                    sendMessage()
                }
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || loading)
            }
            .padding()
        }
        .navigationTitle("Kontext v4 — SwiftUI")
    }

    private func sendMessage() {
        let content = input.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }
        input = ""

        let userMsg = ChatMessage(id: UUID().uuidString, role: .user, content: content)
        messages.append(userMsg)

        Task {
            await session.addMessage(Message(id: userMsg.id, role: .user, content: content))
        }

        loading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let assistantMsg = ChatMessage(
                id: UUID().uuidString,
                role: .assistant,
                content: "This is a response from the assistant."
            )
            messages.append(assistantMsg)

            // Create and cache the ad for this assistant message
            let ad = session.createAd(assistantMsg.id)
            ads[assistantMsg.id] = ad

            loading = false

            Task {
                await session.addMessage(Message(id: assistantMsg.id, role: .assistant, content: assistantMsg.content))
            }
        }
    }
}
