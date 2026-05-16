import KontextSwiftSDK
import UIKit

final class MyMessageTableViewCell: UITableViewCell {
    private let bubbleView = UIView()
    private let label = UILabel()
    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with message: Message) {
        label.text = message.content
        switch message.role {
        case .user:
            bubbleView.backgroundColor = .systemBlue
            label.textColor = .white
            leadingConstraint?.isActive = false
            trailingConstraint?.isActive = true
        case .assistant:
            bubbleView.backgroundColor = .systemGray5
            label.textColor = .label
            trailingConstraint?.isActive = false
            leadingConstraint?.isActive = true
        }
    }

    private func setupViews() {
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.layer.cornerRadius = 14
        bubbleView.layer.masksToBounds = true

        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 15)

        contentView.addSubview(bubbleView)
        bubbleView.addSubview(label)

        let leading = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12)
        let trailing = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)
        leadingConstraint = leading
        trailingConstraint = trailing

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.78),

            label.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
        ])
    }
}
