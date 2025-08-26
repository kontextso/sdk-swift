//
//  MyMessagesTableViewController.swift
//  ExampleUIKit
//

import KontextSwiftSDK
import UIKit

final class MyMessagesTableViewController: UITableViewController {
    private let adsProvider: AdsProvider
    private var messages: [MyMessage]
    private var viewModels: [MyMessagesCollectionViewModel]
    private var adHeight: CGFloat? = 60

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
        let configuration = AdsProviderConfiguration(
            publisherToken: "nexus-dev",
            userId: "1",
            conversationId: "1",
            enabledPlacementCodes: ["inlineAd"]
        )
        adsProvider = AdsProvider(configuration: configuration)
        super.init(style: .plain)
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

    @objc private func addMessage() {
        let message = MyMessage(
            id: UUID().uuidString,
            role: .user,
            content: "kontextso ad_format:INTERSTITIAL",
            createdAt: Date()
        )
        messages.append(message)
        adsProvider.setMessages(messages)
        addViewModels(for: message, includeAd: false)
        tableView.reloadData()

        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
            self.handleAssistantResponse()
        }
    }

    private func handleAssistantResponse() {
        let assistantMessage = MyMessage(
            id: UUID().uuidString,
            role: .assistant,
            content: "I'm doing well, thank you for asking!",
            createdAt: Date()
        )
        messages.append(assistantMessage)
        adsProvider.setMessages(messages)
        addViewModels(for: assistantMessage, includeAd: true)
        tableView.reloadData()
    }

    private func addViewModels(for message: MyMessage, includeAd: Bool) {
        viewModels.removeAll {
            if case .ad = $0 {
                return true
            }
            return false
        }
        viewModels.append(.message(MyMessageViewModel(message: message)))

        if includeAd {
            viewModels.append(.ad(
                InlineAdViewModel(
                    adsProvider: adsProvider,
                    code: "inlineAd",
                    messageId: message.id,
                    otherParams: [:]
                )
            ))
        }
    }
}

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
    override func tableView(
        _ tableView: UITableView,
        estimatedHeightForRowAt indexPath: IndexPath
    ) -> CGFloat {
        60
    }

    override func tableView(
        _ tableView: UITableView,
        heightForRowAt indexPath: IndexPath
    ) -> CGFloat {
        let viewModel = viewModels[indexPath.row]

        if case .ad = viewModel {
            return adHeight ?? 60
        } else {
            return UITableView.automaticDimension
        }
    }
}

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
        cell.onAdHeightChange = { [weak self] height in
            self?.adHeight = height

            Task { @MainActor in
                self?.tableView.beginUpdates()
                self?.tableView.endUpdates()
            }
        }
        return cell
    }
}
