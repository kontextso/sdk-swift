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
            dependencies: ["OMSDK_Megabrainco"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .binaryTarget(
            name: "OMSDK_Megabrainco",
            path: "Frameworks/OMSDK_Megabrainco.xcframework"
        ),
        .testTarget(
            name: "KontextSwiftSDKTests",
            dependencies: ["KontextSwiftSDK"]
        )
    ]
)
