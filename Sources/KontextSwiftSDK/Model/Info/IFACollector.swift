import AdSupport
import AppTrackingTransparency
import UIKit

struct IFAResult {
    let advertisingId: String?
    let vendorId: String?
}

enum IFACollector {
    private static let zeroUUID = "00000000-0000-0000-0000-000000000000"

    static func collect(
        manualAdvertisingId: String?,
        manualVendorId: String?,
        requestTrackingAuthorization: Bool
    ) async -> IFAResult {
        if requestTrackingAuthorization {
            await requestTrackingAuthorizationIfNeeded()
        }

        let advertisingId = resolveAdvertisingId(manual: manualAdvertisingId)
        let vendorId = await resolveVendorId(manual: manualVendorId)

        return IFAResult(advertisingId: advertisingId, vendorId: vendorId)
    }

    private static func requestTrackingAuthorizationIfNeeded() async {
        // Only request on iOS 14.5+ — on 14.0–14.4, requesting ATT when user
        // hasn't decided yet can cause them to deny and lose IDFA access entirely.
        guard #available(iOS 14.5, *) else { return }
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        await ATTrackingManager.requestTrackingAuthorization()
    }

    private static func resolveAdvertisingId(manual: String?) -> String? {
        if let manual = normalize(manual) { return manual }
        guard ATTrackingManager.trackingAuthorizationStatus == .authorized else { return nil }
        return normalize(ASIdentifierManager.shared().advertisingIdentifier.uuidString)
    }

    @MainActor
    private static func resolveVendorId(manual: String?) async -> String? {
        if let manual = normalize(manual) { return manual }
        return normalize(UIDevice.current.identifierForVendor?.uuidString)
    }

    private static func normalize(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        if value.lowercased() == zeroUUID { return nil }
        return value
    }
}