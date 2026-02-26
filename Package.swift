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
            resources: [
                .copy("PrivacyInfo.xcprivacy")
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "KontextSwiftSDKTests",
            dependencies: ["KontextSwiftSDK"]
        )
    ]
)
