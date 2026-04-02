// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "cleanlock",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "cleanlock", targets: ["CleanLock"])
    ],
    targets: [
        .executableTarget(
            name: "CleanLock",
            path: "Sources/CleanLock",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
