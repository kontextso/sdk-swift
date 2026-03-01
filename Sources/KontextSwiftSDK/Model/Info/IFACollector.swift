import AdSupport
import AppTrackingTransparency
import UIKit
import os

struct IFAResult {
    let advertisingId: String?
    let vendorId: String?
}

enum IFACollector {
    private static let zeroUUID = "00000000-0000-0000-0000-000000000000"

    static func collect(
        manualAdvertisingId: String?,
        manualVendorId: String?
    ) async -> IFAResult {
        os_log(.debug, "[Kontext] collect")
        await requestTrackingAuthorizationIfNeeded()
        let advertisingId = resolveAdvertisingId(manual: manualAdvertisingId)
        os_log(.debug, "[Kontext] advertisingId: %{public}@", advertisingId ?? "nil")
        let vendorId = await resolveVendorId(manual: manualVendorId)
        os_log(.debug, "[Kontext] vendorId: %{public}@", vendorId ?? "nil")

        return IFAResult(advertisingId: advertisingId, vendorId: vendorId)
    }

    private static func requestTrackingAuthorizationIfNeeded() async {
        os_log(.debug, "[Kontext] requestTrackingAuthorizationIfNeeded")
        // Only request on iOS 14.5+ — on 14.0–14.4, requesting ATT when user
        // hasn't decided yet can cause them to deny and lose IDFA access entirely.
        guard #available(iOS 14.5, *) else { return }

        let status = ATTrackingManager.trackingAuthorizationStatus
        guard status == .notDetermined else {
            let statusString: String
            switch status {
            case .authorized: statusString = "authorized"
            case .denied: statusString = "denied"
            case .restricted: statusString = "restricted"
            default: statusString = "unknown"
            }
            os_log(.debug, "[Kontext] trackingAuthorizationStatus: %{public}@", statusString)
            return
        }

    os_log(.debug, "[Kontext] requesting tracking authorization")
    await ATTrackingManager.requestTrackingAuthorization()

    let finalStatus = ATTrackingManager.trackingAuthorizationStatus
    let finalStatusString: String
    switch finalStatus {
    case .authorized: finalStatusString = "authorized"
    case .denied: finalStatusString = "denied"
    case .restricted: finalStatusString = "restricted"
    default: finalStatusString = "unknown"
    }
    os_log(.debug, "[Kontext] trackingAuthorizationStatus after request: %{public}@", finalStatusString)

    
    
    }

    private static func resolveAdvertisingId(manual: String?) -> String? {
        os_log(.debug, "[Kontext] resolveAdvertisingId")
        // Automatic has precedence over manual (manual is deprecated)
        let automatic: String? = ATTrackingManager.trackingAuthorizationStatus == .authorized
            ? ASIdentifierManager.shared().advertisingIdentifier.uuidString
            : nil
        return normalize(automatic) ?? normalize(manual)
    }

    @MainActor
    private static func resolveVendorId(manual: String?) async -> String? {
        os_log(.debug, "[Kontext] resolveVendorId")
        let automatic = UIDevice.current.identifierForVendor?.uuidString
        return normalize(automatic) ?? normalize(manual)
    }

    private static func normalize(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        if value.lowercased() == zeroUUID { return nil }
        return value
    }
}
