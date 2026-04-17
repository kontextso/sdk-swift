//
//  MyMessagesTableViewController.swift
//  ExampleUIKit
//

import KontextSwiftSDK
import UIKit

final class MyMessagesTableViewController: UITableViewController {
    private let adsProvider: AdsProvider
    private var messages: [MyMessage]
    private var ads: [Advertisement] = []
    private var viewModels: [CellViewModel]
    private var messageCount: Int = 0

    private let sendButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Send Static Message", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init() {
        messages = []
        viewModels = []
        adsProvider = AdsProvider(configuration: AdsProviderConfiguration(
            // Replace publisher token with your own to try out
            publisherToken: "{publisher-token}",
            userId: "1",
            conversationId: "1",
            enabledPlacementCodes: ["inlineAd"],
            otherParams: ["theme": "dark"]
        ))
        super.init(style: .plain)
        adsProvider.delegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(
            MyMessageTableViewCell.self,
            forCellReuseIdentifier: MyMessageTableViewCell.reuseIdentifier
        )
        tableView.register(
            InlineAdTableViewCell.self,
            forCellReuseIdentifier: InlineAdTableViewCell.reuseIdentifier
        )

        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .interactive
        tableView.contentInset.bottom = 66
        tableView.rowHeight = UITableView.automaticDimension

        view.addSubview(sendButton)
        NSLayoutConstraint.activate(
            [
                sendButton.leadingAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                    constant: 16
                ),
                sendButton.trailingAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                    constant: -16
                ),
                sendButton.bottomAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                    constant: -16
                ),
                sendButton.heightAnchor.constraint(equalToConstant: 50)
            ]
        )
        sendButton.addTarget(self, action: #selector(addMessage), for: .touchUpInside)
    }

}

// MARK: - Polybuzz simulation (KON-1580)
// Simulates Polybuzz's flow: multiple message exchanges, no .cleared handling.

private extension MyMessagesTableViewController {
    static let userMessages = [
        "Hello my smart helpful assistant, how are you?",
        "Can you recommend a good restaurant nearby?",
        "What about Italian food?",
        "Do they have outdoor seating?",
        "Great, can you book a table for two?",
        "What time works best for dinner?",
    ]

    static let assistantMessages = [
        "I'm doing well, thank you for asking!",
        "Sure! There are several great options in your area.",
        "There's a wonderful Italian place called Trattoria Roma.",
        "Yes, they have a beautiful patio with garden views!",
        "I'd be happy to help with that reservation.",
        "Most people prefer between 7-8 PM for dinner.",
    ]

    @objc func addMessage() {
        guard messageCount < Self.userMessages.count else { return }

        let message = MyMessage(
            id: UUID().uuidString,
            role: .user,
            content: Self.userMessages[messageCount],
            createdAt: Date()
        )
        messages.append(message)
        adsProvider.setMessages(messages)
        self.prepareViewModels()
        tableView.reloadData()

        let responseIndex = messageCount
        messageCount += 1
        sendButton.setTitle("Send Message (\(messageCount + 1)/\(Self.userMessages.count))", for: .normal)
        sendButton.isEnabled = messageCount < Self.userMessages.count

        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
            self.handleAssistantResponse(index: responseIndex)
        }
    }

    func handleAssistantResponse(index: Int) {
        guard index < Self.assistantMessages.count else { return }

        let assistantMessage = MyMessage(
            id: UUID().uuidString,
            role: .assistant,
            content: Self.assistantMessages[index],
            createdAt: Date()
        )
        messages.append(assistantMessage)
        adsProvider.setMessages(messages)
        self.prepareViewModels()
        tableView.reloadData()
    }

    func prepareViewModels() {
        var viewModels: [CellViewModel] = []
        for message in messages {
            viewModels.append(.message(MyMessageViewModel(message: message)))
            if let ad = ads.first(where: { $0.messageId == message.id }) {
                viewModels.append(.ad(InlineAdViewModel(ad: ad)))
            }
        }
        self.viewModels = viewModels
    }
}

// MARK: - AdsProviderDelegate

extension MyMessagesTableViewController: AdsProviderDelegate {
    func adsProvider(_ adsProvider: AdsProvider, didReceiveEvent event: AdsEvent) {
        print("[Polybuzz sim] Event: \(event.name)")
        switch event {
        case .filled(let ads):
            self.ads = ads
            self.prepareViewModels()
            self.tableView.reloadData()
        // NOTE: Polybuzz does NOT handle .cleared — they don't cache ads locally
        // case .cleared:
        //     self.ads = []
        //     self.prepareViewModels()
        //     self.tableView.reloadData()
        case .adHeight:
            self.tableView.beginUpdates()
            self.tableView.endUpdates()
        default:
            break
        }
    }
}

// MARK: - Table view data source

extension MyMessagesTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        viewModels.count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let viewModel = viewModels[indexPath.row]
        switch viewModel {
        case .message(let messageViewModel):
            return createMessageCell(indexPath: indexPath, viewModel: messageViewModel)
        case .ad(let adViewModel):
            return createAdCell(indexPath: indexPath, viewModel: adViewModel)
        }
    }
}

// MARK: - Cell Creation

private extension MyMessagesTableViewController {
    func createMessageCell(
        indexPath: IndexPath,
        viewModel: MyMessageViewModel
    ) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: MyMessageTableViewCell.reuseIdentifier,
            for: indexPath
        ) as? MyMessageTableViewCell else {
            fatalError("Could not dequeue MyMessageTableViewCell")
        }
        cell.configure(with: viewModel)
        return cell
    }

    func createAdCell(
        indexPath: IndexPath,
        viewModel: InlineAdViewModel
    ) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: InlineAdTableViewCell.reuseIdentifier,
            for: indexPath
        ) as? InlineAdTableViewCell else {
            fatalError("Could not dequeue InlineAdTableViewCell")
        }
        cell.configure(with: viewModel)
        return cell
    }
}
