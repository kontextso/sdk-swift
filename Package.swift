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
            dependencies: ["OMSDK_Kontextso"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .binaryTarget(
            name: "OMSDK_Kontextso",
            path: "Frameworks/OMSDK_Kontextso.xcframework"
        ),
        .testTarget(
            name: "KontextSwiftSDKTests",
            dependencies: ["KontextSwiftSDK"]
        )
    ]
)
