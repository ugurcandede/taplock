// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "cleanlock",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "CleanLockCore", targets: ["CleanLockCore"]),
        .executable(name: "cleanlock", targets: ["CleanLock"]),
    ],
    targets: [
        .target(
            name: "CleanLockCore",
            path: "Sources/CleanLockCore",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "CleanLock",
            dependencies: ["CleanLockCore"],
            path: "Sources/CleanLock",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)
