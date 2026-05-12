import Combine
import UIKit
import WebKit

@MainActor
final class InterstitialAdViewController: UIViewController {
    private let ad: Ad
    private let url: URL
    private var adWebView: AdWebView?
    private var modalUrlCancellable: AnyCancellable?
    private let spinner = UIActivityIndicatorView(style: .large)
    private weak var webViewContainer: UIView?

    init(ad: Ad, url: URL) {
        self.ad = ad
        self.url = url
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        setupSpinner()
        setupWebView()
        observeModalDismiss()
    }

    private func setupSpinner() {
        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func setupWebView() {
        let webView = AdWebView(ad: ad, isInterstitial: true)
        adWebView = webView

        let wk = webView.webView
        // Hidden until the component iframe signals init — keeps the
        // partially-rendered modal from flashing on screen, and avoids
        // OMID's geometry observer reading <100% opacity (would fail the
        // IAB `percentageInView: 100` compliance test).
        wk.alpha = 0
        wk.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(wk)
        webViewContainer = wk
        NSLayoutConstraint.activate([
            wk.topAnchor.constraint(equalTo: view.topAnchor),
            wk.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            wk.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            wk.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        webView.onComponentInitialized = { [weak self] in
            guard let self else { return }
            self.spinner.stopAnimating()
            self.webViewContainer?.alpha = 1
        }

        webView.loadURL(url)
    }

    private func observeModalDismiss() {
        modalUrlCancellable = ad.$modalUrl
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newUrl in
                guard let self, newUrl == nil else { return }
                self.webViewContainer?.alpha = 0
            }
    }
}
