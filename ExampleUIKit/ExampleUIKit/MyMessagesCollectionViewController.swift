//
//  MyMessagesCollectionViewController.swift
//  ExampleUIKit
//

import KontextSwiftSDK
import UIKit

enum MyMessagesCollectionViewModel {
    case message(MyMessageViewModel)
    case ad(InlineAdViewModel)
}

final class MyMessagesCollectionViewController: UICollectionViewController {
    private let adsProvider: AdsProvider
    private var messages: [MyMessage]
    private var viewModels: [MyMessagesCollectionViewModel]

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
        let layout = UICollectionViewCompositionalLayout { (_, _) -> NSCollectionLayoutSection? in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .estimated(60)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .estimated(60)
            )
            let group = NSCollectionLayoutGroup.vertical(
                layoutSize: groupSize, subitem: item, count: 1
            )

            return NSCollectionLayoutSection(group: group)
        }

        // 1. Create configuration with publisher token and relevant conversation data
        let configuration = AdsProviderConfiguration(
            publisherToken: "nexus-dev",
            userId: "1",
            conversationId: "1",
            enabledPlacementCodes: ["inlineAd"]
        )
        // 2. Create AdsProvider associated to this conversation
        // Multiple instances can be created, for each conversation one
        adsProvider = AdsProvider(
            configuration: configuration
        )
        super.init(collectionViewLayout: layout)
        adsProvider.delegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.register(
            MyMessageCollectionViewCell.self,
            forCellWithReuseIdentifier: MyMessageCollectionViewCell.reuseIdentifier
        )
        collectionView.register(
            InlineAdCollectionViewCell.self,
            forCellWithReuseIdentifier: InlineAdCollectionViewCell.self.reuseIdentifier
        )

        collectionView.dataSource = self

        view.addSubview(sendButton)
        NSLayoutConstraint.activate([
            sendButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            sendButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            sendButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            sendButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        sendButton.addTarget(self, action: #selector(addMessage), for: .touchUpInside)
        collectionView.contentInset.bottom = 66
    }

    @objc private func addMessage() {        
        let message = MyMessage(
            id: UUID().uuidString,
            role: .user,
            content: "Hello, this is a static message!",
            createdAt: Date()
        )

        messages.append(message)
        adsProvider.setMessages(messages)
        addViewModels(for: message, includeAd: false)
        collectionView.reloadData()

        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
            self.handleAssistantResponse()
        }
    }

    private func handleAssistantResponse() {
        // Simulate assistant message
        let assistantMessage = MyMessage(
            id: UUID().uuidString,
            role: .assistant,
            content: "I'm doing well, thank you for asking!",
            createdAt: Date()
        )

        messages.append(assistantMessage)
        adsProvider.setMessages(messages)
        addViewModels(for: assistantMessage, includeAd: true)
        collectionView.reloadData()
    }

    private func addViewModels(for message: MyMessage, includeAd: Bool) {
        viewModels.removeAll(where: {
            if case .ad = $0 {
                return true
            }
            return false
        })
        viewModels.append(
            .message(MyMessageViewModel(message: message))
        )
        if includeAd {
            viewModels.append(
                .ad(
                    InlineAdViewModel(
                        adsProvider: adsProvider,
                        code: "inlineAd",
                        messageId: message.id,
                        otherParams: [:]
                    )
                )
            )
        }
    }
}

// MARK: - UICollectionViewDataSource

extension MyMessagesCollectionViewController {
    override func numberOfSections(
        in collectionView: UICollectionView
    ) -> Int {
        1
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        viewModels.count
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let viewModel = viewModels[indexPath.item]

        return switch viewModel {
        case .message(let messageViewModel):
            createMessageCell(indexPath: indexPath, viewModel: messageViewModel)
        case .ad(let adViewModel):
            createAdCell(indexPath: indexPath, viewModel: adViewModel)
        }
    }
}

// MARK: Factories
private extension MyMessagesCollectionViewController {
    func createMessageCell(
        indexPath: IndexPath,
        viewModel: MyMessageViewModel
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: MyMessageCollectionViewCell.reuseIdentifier, for: indexPath
        ) as? MyMessageCollectionViewCell else {
            fatalError("Could not dequeue MyMessageCollectionViewCell")
        }
        cell.configure(with: viewModel)
        return cell
    }

    func createAdCell(
        indexPath: IndexPath,
        viewModel: InlineAdViewModel
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: InlineAdCollectionViewCell.reuseIdentifier, for: indexPath
        ) as? InlineAdCollectionViewCell else {
            fatalError("Could not dequeue MyMessageCollectionViewCell")
        }
        cell.configure(with: viewModel)
        return cell
    }
}
