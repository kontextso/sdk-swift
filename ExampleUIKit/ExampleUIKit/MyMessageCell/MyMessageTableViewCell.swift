//
//  MyMessageTableViewCell.swift
//  ExampleUIKit
//

import UIKit

final class MyMessageTableViewCell: UITableViewCell {
    private let bubbleView = UIView()
    private let label = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with viewModel: MyMessageViewModel) {
        label.text = viewModel.message.content
        switch viewModel.message.role {
        case .user:
            bubbleView.backgroundColor = UIColor.systemBlue
        case .assistant:
            bubbleView.backgroundColor = UIColor.systemGray
        default:
            bubbleView.backgroundColor = UIColor.systemGray4
        }
    }

    private func setupViews() {
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.layer.cornerRadius = 8
        bubbleView.layer.masksToBounds = true

        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .white

        contentView.addSubview(bubbleView)
        bubbleView.addSubview(label)

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),

            label.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -8)
        ])
    }
}
