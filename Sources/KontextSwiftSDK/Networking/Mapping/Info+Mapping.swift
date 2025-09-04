import Foundation

extension AppInfo: ModelConvertible {
    func toModel() -> AppDTO {
        AppDTO(
            bundleId: bundleId,
            version: version,
            storeUrl: storeUrl,
            firstInstallTime: installTime,
            lastUpdateTime: updateTime,
            startTime: startTime
        )
    }
}

extension AudioInfo: ModelConvertible {
    func toModel() -> AudioDTO {
        AudioDTO(
            volume: volume,
            muted: muted,
            outputPluggedIn: outputPluggedIn,
            outputType: outputType
        )
    }
}

extension OSInfo: ModelConvertible {
    func toModel() -> OSDTO {
        OSDTO(
            name: name,
            version: version,
            locale: locale,
            timezone: timezone
        )
    }
}

extension HardwareInfo: ModelConvertible {
    func toModel() -> HardwareDTO {
        HardwareDTO(
            brand: brand,
            model: model,
            type: type,
            sdCardAvailable: false
        )
    }
}

extension ScreenInfo: ModelConvertible {
    func toModel() -> ScreenDTO {
        ScreenDTO(
            width: screenWidth,
            height: screenHeight,
            dpr: scale,
            orientation: orientation,
            darkMode: isDarkMode
        )
    }
}

extension PowerInfo: ModelConvertible {
    func toModel() -> PowerDTO {
        PowerDTO(
            batteryLevel: batteryLevel,
            batteryState: batteryState,
            lowPowerMode: lowPowerMode
        )
    }
}

extension NetworkInfo: ModelConvertible {
    func toModel() -> NetworkDTO {
        NetworkDTO(
            userAgent: userAgent,
            type: networkType,
            detail: networkDetail,
            carrier: carrierName
        )
    }
}

extension DeviceInfo: ModelConvertible {
    func toModel() -> DeviceDTO {
        DeviceDTO(
            os: os.toModel(),
            hardware: hardware.toModel(),
            screen: screen.toModel(),
            power: power.toModel(),
            audio: audio.toModel(),
            network: network.toModel()
        )
    }
}

extension SDKInfo: ModelConvertible {
    func toModel() -> SDKDTO {
        SDKDTO(
            name: name,
            version: version,
            platform: lowercasedPlatform
        )
    }
}
