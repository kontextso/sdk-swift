import Foundation
@preconcurrency import OMSDK_Kontextso

protocol OMServicing: Sendable {
    @discardableResult
    func activate() -> Bool

    func createSession(_ webView: WKWebView) throws -> OMSession
}

final class OMService: OMServicing {
    enum OMError: Error {
        case sdkIsNotActive
        case partnerIsNotAvailable
        case sessionCreationFailed(String)
    }

    /// Used to identify integration
    private let partner = OMIDKontextsoPartner(
        name: "Kontextso",
        versionString: "1.1.2"
    )

    /// Activates OM SDK
    func activate() -> Bool {
        if isActive {
            return true
        }

        OMIDKontextsoSDK.shared.activate()

        return isActive
    }

    /// Creates OMID context, configuration and returns a session
    func createSession(_ webView: WKWebView) throws -> OMSession {
        guard isActive else {
            throw OMError.sdkIsNotActive
        }

        guard let partner else {
            throw OMError.partnerIsNotAvailable
        }

        do {
            let context = try OMIDKontextsoAdSessionContext(
                partner: partner,
                webView: webView,
                contentUrl: nil,
                customReferenceIdentifier: nil
            )

            let configuration = try OMIDKontextsoAdSessionConfiguration(
                creativeType: .htmlDisplay,
                impressionType: .beginToRender,
                impressionOwner: .javaScriptOwner,
                mediaEventsOwner: .noneOwner,
                isolateVerificationScripts: false
            )

            let session = try OMIDKontextsoAdSession(
                configuration: configuration,
                adSessionContext: context
            )

            session.mainAdView = webView
            return OMSession(session: session)
        } catch {
            throw OMError.sessionCreationFailed(error.localizedDescription)
        }
    }
}

// MARK: - Private

private extension OMService {
    var isActive: Bool {
        OMIDKontextsoSDK.shared.isActive
    }
}

// MARK: - OMSession

struct OMSession {
    private let session: OMIDKontextsoAdSession

    init(session: OMIDKontextsoAdSession) {
        self.session = session
    }

    func start() {
        session.start()
    }

    func finish() {
        session.finish()
    }
}
