//
//  ScreenInfo.swift
//  KontextSwiftSDK
//

import UIKit

struct ScreenInfo {
    /// Device screen width size
    let screenWidth: CGFloat
    /// Device screen height size
    let screenHeight: CGFloat
    /// Device screen scale (e.g., 2.0 for Retina displays)
    let scale: CGFloat
    /// Device orientation: "portrait" or "landscape"
    let orientation: ScreenOrientation?
    /// Device dark mode status (true if dark mode is on, false if light mode is on)
    let isDarkMode: Bool

    init(
        screenWidth: CGFloat,
        screenHeight: CGFloat,
        scale: CGFloat,
        orientation: ScreenOrientation?,
        isDarkMode: Bool
    ) {
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        self.scale = scale
        self.orientation = orientation
        self.isDarkMode = isDarkMode
    }
}

extension ScreenInfo {
    @MainActor
    /// Creates a ScreenInfo instance with current screen information
    static func current() -> ScreenInfo {
        let orientation: ScreenOrientation? = switch UIDevice.current.orientation {
        case .portrait, .portraitUpsideDown: .portrait
        case .landscapeLeft, .landscapeRight: .landscape
        default: nil
        }

        let isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark

        return ScreenInfo(
            screenWidth: UIScreen.main.bounds.width,
            screenHeight: UIScreen.main.bounds.height,
            scale: UIScreen.main.scale,
            orientation: orientation,
            isDarkMode: isDarkMode
        )
    }
}
