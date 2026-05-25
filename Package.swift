// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ios-cloudfare-tunnel",
    platforms: [
        .iOS(.v16)
    ],
    targets: [
        .executableTarget(
            name: "ios-cloudfare-tunnel",
            path: ".",
            sources: ["App", "Core"],
            resources: [
                .process("App/Info.plist")
            ],
            swiftSettings: [
                .unsafeFlags(["-enable-bare-slash-regex"])
            ]
        )
    ]
)
