import UIKit
import KontextSwiftSDK

final class ChatViewController: UITableViewController {
    private let session: Session
    private var messages: [ChatItem] = []
    private var loading = false

    /// Cache ad views by message ID to avoid recreating on cell reuse
    private var adViews: [String: InlineAdUIView] = [:]

    private let sendButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Send", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let inputField: UITextField = {
        let field = UITextField()
        field.placeholder = "Type a message..."
        field.borderStyle = .roundedRect
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    init() {
        session = KontextAds.createSession(SessionOptions(
            publisherToken: ExampleSecrets.publisherToken,
            userId: UUID().uuidString,
            conversationId: UUID().uuidString,
            enabledPlacementCodes: ["inlineAd"],
            onEvent: { event in
                print("[kontext] \(event)")
            }
        ))
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Kontext v4 — UIKit"
        navigationItem.largeTitleDisplayMode = .never
        navigationController?.navigationBar.prefersLargeTitles = false

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "MessageCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "AdCell")
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.contentInsetAdjustmentBehavior = .automatic
        tableView.contentInset.bottom = 70

        let footer = UIView()
        footer.translatesAutoresizingMaskIntoConstraints = false
        footer.backgroundColor = .systemBackground
        view.addSubview(footer)
        footer.addSubview(inputField)
        footer.addSubview(sendButton)

        NSLayoutConstraint.activate([
            footer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            footer.heightAnchor.constraint(equalToConstant: 60),

            inputField.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 16),
            inputField.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
            inputField.heightAnchor.constraint(equalToConstant: 40),

            sendButton.leadingAnchor.constraint(equalTo: inputField.trailingAnchor, constant: 8),
            sendButton.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -16),
            sendButton.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 70),
            sendButton.heightAnchor.constraint(equalToConstant: 40),
        ])

        sendButton.addTarget(self, action: #selector(sendMessage), for: .touchUpInside)
    }

    @objc private func sendMessage() {
        let content = inputField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !content.isEmpty, !loading else { return }
        inputField.text = ""

        // Remove previous ad row
        if let adIndex = messages.lastIndex(where: { $0.isAd }) {
            let adItem = messages[adIndex]
            adViews[adItem.id]?.removeFromSuperview()
            adViews.removeValue(forKey: adItem.id)
            messages.remove(at: adIndex)
        }

        let userMsg = ChatItem(id: UUID().uuidString, role: .user, content: content, isAd: false)
        messages.append(userMsg)
        tableView.reloadData()

        Task { await session.addMessage(Message(id: userMsg.id, role: .user, content: content)) }

        loading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }

            let assistantMsg = ChatItem(
                id: UUID().uuidString,
                role: .assistant,
                content: "This is a response from the assistant.",
                isAd: false
            )
            messages.append(assistantMsg)
            messages.append(ChatItem(id: assistantMsg.id, role: .assistant, content: "", isAd: true))

            loading = false
            tableView.reloadData()

            Task { await self.session.addMessage(Message(id: assistantMsg.id, role: .assistant, content: assistantMsg.content)) }
        }
    }

    // MARK: - Ad View Cache

    private func adView(for messageId: String) -> InlineAdUIView {
        if let cached = adViews[messageId] {
            return cached
        }
        let view = InlineAdUIView(messageId: messageId, session: session)
        view.onHeightChange = { [weak self] _ in
            self?.tableView.beginUpdates()
            self?.tableView.endUpdates()
        }
        adViews[messageId] = view
        return view
    }

    // MARK: - Table View

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        messages.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let msg = messages[indexPath.row]

        if msg.isAd {
            let cell = tableView.dequeueReusableCell(withIdentifier: "AdCell", for: indexPath)
            cell.selectionStyle = .none
            cell.clipsToBounds = true
            cell.contentView.clipsToBounds = true

            // Remove any previous ad subview
            cell.contentView.subviews.forEach { $0.removeFromSuperview() }

            let adView = adView(for: msg.id)
            // Remove from previous cell if reused
            adView.removeFromSuperview()
            cell.contentView.addSubview(adView)
            NSLayoutConstraint.activate([
                adView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
                adView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
                adView.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
                adView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
            ])
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.text = "\(msg.role == .user ? "You" : "Assistant"): \(msg.content)"
        config.textProperties.font = .preferredFont(forTextStyle: .subheadline)
        config.textProperties.numberOfLines = 0
        cell.contentConfiguration = config
        cell.backgroundColor = msg.role == .user ? .systemBlue.withAlphaComponent(0.1) : .systemGray6
        return cell
    }
}

private struct ChatItem {
    let id: String
    let role: Message.Role
    let content: String
    let isAd: Bool
}
