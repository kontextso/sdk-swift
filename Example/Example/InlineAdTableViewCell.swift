import KontextSwiftSDK
import UIKit

final class InlineAdTableViewCell: UITableViewCell {
    private var inlineAdView: InlineAdUIView?
    private var configuredAdId: UUID?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var enclosingTableView: UITableView? {
        var view: UIView? = superview
        while let current = view {
            if let table = current as? UITableView { return table }
            view = current.superview
        }
        return nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // Do NOT destroy `inlineAdView` here. UITableView calls
        // prepareForReuse when the cell scrolls off screen — tearing
        // down the InlineAdUIView would end its OMID session and the
        // same bid would start a new session on scroll back in.
        // `configure(with:)` handles teardown via `configuredAdId`.
    }

    func configure(with ad: Ad) {
        if configuredAdId == ad.id, inlineAdView != nil {
            return
        }
        inlineAdView?.removeFromSuperview()
        inlineAdView = nil
        configuredAdId = ad.id

        let inlineAdView = InlineAdUIView(ad: ad)
        inlineAdView.onHeightChange = { [weak self] _ in
            guard let tableView = self?.enclosingTableView else { return }
            // Capture "was scrolled to bottom" before the height change so
            // we know whether to follow the growing ad. ~24pt slack to
            // tolerate the rubber-banding overshoot at the bottom edge.
            let wasAtBottom = tableView.contentOffset.y + tableView.bounds.height
                >= tableView.contentSize.height - 24
            tableView.beginUpdates()
            tableView.endUpdates()
            guard wasAtBottom else { return }
            let rows = tableView.numberOfRows(inSection: 0)
            guard rows > 0 else { return }
            tableView.scrollToRow(at: IndexPath(row: rows - 1, section: 0), at: .bottom, animated: true)
        }
        self.inlineAdView = inlineAdView
        inlineAdView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(inlineAdView)

        let trailing = inlineAdView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)
        trailing.priority = .defaultHigh

        NSLayoutConstraint.activate([
            inlineAdView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            trailing,
            inlineAdView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            inlineAdView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
        ])
    }
}
