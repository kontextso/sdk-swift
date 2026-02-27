import CoreTelephony
import Foundation
import Network
import WebKit

enum NetworkType: String, Encodable {
    case wifi
    case cellular
    case ethernet
    case other
}

enum NetworkDetail: String, Encodable {
    case twoG = "2g"
    case threeG = "3g"
    case fourG = "4g"
    case lte
    case fiveG = "5g"
    case nr
    case hspa
    case edge
    case gprs
}

struct NetworkInfo {
    let userAgent: String?
    let carrierName: String?
    let networkType: NetworkType?
    let networkDetail: NetworkDetail?

    init(
        userAgent: String?,
        carrierName: String?,
        networkType: NetworkType?,
        networkDetail: NetworkDetail?
    ) {
        self.userAgent = userAgent
        self.carrierName = carrierName
        self.networkType = networkType
        self.networkDetail = networkDetail
    }
}

extension NetworkInfo {
    /// Creates a NetworkInfo instance with current network information
    static func current(
        appInfo: AppInfo,
        osInfo: OSInfo,
        hardwareInfo: HardwareInfo
    ) async -> NetworkInfo {
        let userAgent = await currentUserAgent()
        let carrierName = carrierName
        let networkType = await networkType()
        let networkDetail = await networkDetail()

        return NetworkInfo(
            userAgent: userAgent,
            carrierName: carrierName,
            networkType: networkType,
            networkDetail: networkDetail
        )
    }
}

private extension NetworkInfo {
    static var cachedUserAgent: String?

    static func currentUserAgent() async -> String? {
        if let cached = cachedUserAgent {
            return cached
        }
        let ua = await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let webView = WKWebView(frame: .zero)
                webView.evaluateJavaScript("navigator.userAgent") { value, _ in
                    continuation.resume(returning: value as? String)
                }
            }
        }
        cachedUserAgent = ua
        return ua
    }

    /// Returns the carrier name of the device, or nil if unavailable
    static var carrierName: String? {
        let networkInfo = CTTelephonyNetworkInfo()
        let carrier: CTCarrier? = networkInfo.serviceSubscriberCellularProviders?.values.first
        return carrier?.carrierName
    }

    /// Returns general network type: wifi, cellular, ethernet, or other
    static func networkType() async -> NetworkType {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()

            monitor.pathUpdateHandler = { path in
                if path.usesInterfaceType(.wifi) {
                    continuation.resume(returning: .wifi)
                } else if path.usesInterfaceType(.cellular) {
                    continuation.resume(returning: .cellular)
                } else if path.usesInterfaceType(.wiredEthernet) {
                    continuation.resume(returning: .ethernet)
                } else {
                    continuation.resume(returning: .other)
                }

                monitor.cancel()
            }

            monitor.start(queue: DispatchQueue.global(qos: .background))
        }
    }

    /// Returns detailed network type for cellular connections (5g/lte/hspa/3g/2g/edge/gprs/unknown)
    static func networkDetail() async -> NetworkDetail? {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()

            monitor.pathUpdateHandler = { path in
                if path.usesInterfaceType(.wifi) {
                    continuation.resume(returning: nil)
                } else if path.usesInterfaceType(.cellular) {
                    continuation.resume(returning: mapRadioTechnologyToDetail())
                } else {
                    continuation.resume(returning: .none)
                }
                monitor.cancel()
            }
            
            monitor.start(queue: DispatchQueue.global(qos: .background))
        }
    }
    
    static func mapRadioTechnologyToDetail() -> NetworkDetail? {
        let info = CTTelephonyNetworkInfo()
        let radioTech: String?

        radioTech = info.serviceCurrentRadioAccessTechnology?.values.first


        if #available(iOS 14.1, *) {
            switch radioTech {
            case CTRadioAccessTechnologyNRNSA, CTRadioAccessTechnologyNR:
                return .fiveG
            default:
                break
            }
        }
        switch radioTech {
        case CTRadioAccessTechnologyGPRS:
            return .gprs
        case CTRadioAccessTechnologyEdge:
            return .edge
        case CTRadioAccessTechnologyWCDMA:
            return .threeG
        case CTRadioAccessTechnologyHSDPA,
        CTRadioAccessTechnologyHSUPA:
            return .hspa
        case CTRadioAccessTechnologyCDMA1x:
            return .twoG
        case CTRadioAccessTechnologyCDMAEVDORev0,
            CTRadioAccessTechnologyCDMAEVDORevA,
            CTRadioAccessTechnologyCDMAEVDORevB,
        CTRadioAccessTechnologyeHRPD:
            return .threeG
        case CTRadioAccessTechnologyLTE:
        return .lte
        default:
            return nil
        }
    }
}
