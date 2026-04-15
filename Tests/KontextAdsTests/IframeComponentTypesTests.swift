import Foundation
import Testing
@testable import KontextSwiftSDK

struct IframeComponentTypesTests {
    // MARK: - IframeComponentKind

    @Test
    func kindInitMapsModal() {
        let kind = IframeComponentKind(component: .modal)
        if case .modal = kind {} else { Issue.record("Expected .modal") }
    }

    @Test
    func kindInitMapsSkoverlay() {
        let kind = IframeComponentKind(component: .skoverlay)
        if case .skoverlay = kind {} else { Issue.record("Expected .skoverlay") }
    }

    // MARK: - IframeComponentRequest

    @Test
    func openRequestReportsOpenAction() {
        let open = IframeComponentRequest.open(.init(code: "c", component: .modal))
        if case .open = open.action {} else { Issue.record("Expected .open action") }
    }

    @Test
    func closeRequestReportsCloseAction() {
        let close = IframeComponentRequest.close(.init(code: "c", component: .modal))
        if case .close = close.action {} else { Issue.record("Expected .close action") }
    }

    @Test
    func requestSurfacesKind() {
        let modalOpen = IframeComponentRequest.open(.init(code: "c", component: .modal))
        let overlayClose = IframeComponentRequest.close(.init(code: "c", component: .skoverlay))

        if case .modal = modalOpen.kind {} else { Issue.record("Expected .modal kind") }
        if case .skoverlay = overlayClose.kind {} else { Issue.record("Expected .skoverlay kind") }
    }

    @Test
    func requestSurfacesCode() {
        let open = IframeComponentRequest.open(.init(code: "placement-a", component: .modal))
        let close = IframeComponentRequest.close(.init(code: "placement-b", component: .modal))

        #expect(open.code == "placement-a")
        #expect(close.code == "placement-b")
    }
}
