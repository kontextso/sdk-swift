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
        // Pre-1.0 KontextKit: pin exact. Once KontextKit hits 1.0, switch to from: "1.0.0".
        // Matches the strictness of KontextSwiftSDK.podspec's exact `'0.0.4'` pin so SPM
        // and CocoaPods consumers resolve to the same KontextKit version.
        .package(url: "https://github.com/kontextso/kontextkit-ios.git", exact: "0.0.4"),
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
