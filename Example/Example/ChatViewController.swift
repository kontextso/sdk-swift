import KontextSwiftSDK
import UIKit

final class ChatViewController: UIViewController {
    private let session: Session
    private var messages: [Message] = []
    private var items: [Item] = []
    private var ads: [String: Ad] = [:]

    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .interactive
        tableView.rowHeight = UITableView.automaticDimension
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.allowsSelection = false
        return tableView
    }()

    private let inputField: UITextField = {
        let field = UITextField()
        field.placeholder = "Type a message…"
        field.borderStyle = .roundedRect
        field.font = .systemFont(ofSize: 15)
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()

    private let sendButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Send", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    init() {
        session = KontextAds.createSession(SessionOptions(
            publisherToken: ExampleSecrets.publisherToken,
            userId: UUID().uuidString,
            conversationId: UUID().uuidString,
            enabledPlacementCodes: ["inlineAd"],
            onEvent: { event in
                print("[kontext] \(event)")
            },
            onDebugEvent: { name, data in
                // Filter out the 200ms dimension-tick chatter — uncomment
                // if you need to debug viewport reporting.
                if let dict = data as? [String: Any],
                   dict["type"] as? String == "update-dimensions-iframe" {
                    return
                }
                if let data {
                    print("[kontext-debug] \(name) \(data)")
                } else {
                    print("[kontext-debug] \(name)")
                }
            }
        ))
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Kontext v4"
        setupTableView()
        setupInputBar()
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
    }

    private func setupTableView() {
        tableView.register(MyMessageTableViewCell.self, forCellReuseIdentifier: MyMessageTableViewCell.reuseIdentifier)
        tableView.register(InlineAdTableViewCell.self, forCellReuseIdentifier: InlineAdTableViewCell.reuseIdentifier)
        tableView.dataSource = self
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupInputBar() {
        let bar = UIView()
        bar.backgroundColor = .secondarySystemBackground
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(inputField)
        bar.addSubview(sendButton)
        view.addSubview(bar)

        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bar.topAnchor.constraint(equalTo: tableView.bottomAnchor),
            bar.heightAnchor.constraint(equalToConstant: 56),

            inputField.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 12),
            inputField.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            inputField.heightAnchor.constraint(equalToConstant: 36),

            sendButton.leadingAnchor.constraint(equalTo: inputField.trailingAnchor, constant: 8),
            sendButton.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -12),
            sendButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 64),
            sendButton.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    @objc private func sendTapped() {
        let text = inputField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !text.isEmpty else { return }
        inputField.text = ""

        // A new user message triggers a new preload; tear down any ads
        // bound to earlier assistant messages so the chat only shows
        // the ad for the latest reply. v4 leaves Ad lifecycle to the
        // publisher (no auto-clear event like v3's `.cleared`).
        for ad in ads.values { ad.destroy() }
        ads.removeAll()

        let user = Message(id: UUID().uuidString, role: .user, content: text)
        appendMessage(user)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            let assistant = Message(
                id: UUID().uuidString,
                role: .assistant,
                content: "This is a static reply. Replace with your own LLM."
            )
            self.appendMessage(assistant)
            self.ads[assistant.id] = self.session.createAd(assistant.id)
            self.rebuildItems()
        }
    }

    private func appendMessage(_ message: Message) {
        messages.append(message)
        session.addMessage(message)
        rebuildItems()
        scrollToBottom()
    }

    private func rebuildItems() {
        var built: [Item] = []
        for message in messages {
            built.append(.message(message))
            if let ad = ads[message.id] {
                built.append(.ad(ad))
            }
        }
        items = built
        tableView.reloadData()
    }

    private func scrollToBottom(animated: Bool = true) {
        guard !items.isEmpty else { return }
        let last = IndexPath(row: items.count - 1, section: 0)
        tableView.scrollToRow(at: last, at: .bottom, animated: animated)
    }
}

extension ChatViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch items[indexPath.row] {
        case .message(let message):
            let cell = tableView.dequeueReusableCell(
                withIdentifier: MyMessageTableViewCell.reuseIdentifier,
                for: indexPath
            ) as! MyMessageTableViewCell
            cell.configure(with: message)
            return cell
        case .ad(let ad):
            let cell = tableView.dequeueReusableCell(
                withIdentifier: InlineAdTableViewCell.reuseIdentifier,
                for: indexPath
            ) as! InlineAdTableViewCell
            cell.configure(with: ad)
            return cell
        }
    }
}

private enum Item {
    case message(Message)
    case ad(Ad)
}
