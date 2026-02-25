// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "KontextSwiftSDK",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "KontextSwiftSDK",
            targets: ["KontextSwiftSDK"]
        ),
    ],
    targets: [
        .target(
            name: "KontextSwiftSDK",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ],
            linkerSettings: [
                .linkedFramework("AdSupport"),
                .linkedFramework("AppTrackingTransparency"),
            ]
        ),
        .testTarget(
            name: "KontextSwiftSDKTests",
            dependencies: ["KontextSwiftSDK"]
        )
    ]
)
