// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KontextSwiftSDK",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "KontextSwiftSDK",
            targets: ["KontextSwiftSDK"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/kontextso/kontextkit-ios.git", from: "0.0.1")
    ],
    targets: [
        .target(
            name: "KontextSwiftSDK",
            dependencies: [
                .product(name: "KontextKit", package: "kontextkit-ios"),
            ],
            path: "Sources/KontextSwiftSDK",
            resources: [
                .copy("PrivacyInfo.xcprivacy"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "KontextSwiftSDKTests",
            dependencies: ["KontextSwiftSDK"],
            path: "Tests/KontextSwiftSDKTests"
        )
    ]
)
