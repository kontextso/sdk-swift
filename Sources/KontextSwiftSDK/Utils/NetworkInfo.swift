//
//  NetworkDetail.swift
//  KontextSwiftSDK
//

import Foundation
import Network
import CoreTelephony

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

final class NetworkInfo {
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

    static func current(
        appInfo: AppInfo,
        osInfo: OSInfo,
        hardwareInfo: HardwareInfo
    ) async -> NetworkInfo {
        let userAgent = currentUserAgent(appInfo: appInfo, osInfo: osInfo, hardwareInfo: hardwareInfo)
        let carrierName = Self.carrierName
        let networkType = await Self.networkType()
        let networkDetail = await Self.networkDetail()

        return NetworkInfo(
            userAgent: userAgent,
            carrierName: carrierName,
            networkType: networkType,
            networkDetail: networkDetail
        )
    }

    /// Returns a User-Agent string representing the device and app
    private static func currentUserAgent(
        appInfo: AppInfo,
        osInfo: OSInfo,
        hardwareInfo: HardwareInfo
    ) -> String? {
        let appName = appInfo.name
        let appVersion = appInfo.version
        guard
            let osName = osInfo.name
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let osVersion = osInfo.version
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else {
            return nil
        }
        let deviceModel = hardwareInfo.model
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "UnknownDevice"

        return "\(appName)/\(appVersion) (\(deviceModel); \(osName) \(osVersion))"
    }

    /// Returns the carrier name of the device, or nil if unavailable
    static var carrierName: String? {
        let networkInfo = CTTelephonyNetworkInfo()
        var carrier: CTCarrier? = networkInfo.serviceSubscriberCellularProviders?.values.first
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
    
    private static func mapRadioTechnologyToDetail() -> NetworkDetail? {
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
