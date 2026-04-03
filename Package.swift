// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "taplock",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "TapLockCore", targets: ["TapLockCore"]),
        .executable(name: "taplock", targets: ["TapLock"]),
    ],
    targets: [
        .target(
            name: "TapLockCore",
            path: "Sources/TapLockCore",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "TapLock",
            dependencies: ["TapLockCore"],
            path: "Sources/TapLock",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "TapLockTests",
            dependencies: ["TapLockCore"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)
