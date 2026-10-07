// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PullJoy",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "PullJoy", targets: ["PullJoy"]),
    ],
    targets: [
        // Pure classification logic: no I/O, no clock, no AppKit.
        .target(name: "PullJoyCore"),
        // GitHub, auth, persistence, the inbox engine and the MCP server.
        .target(name: "PullJoyKit", dependencies: ["PullJoyCore"]),
        // The menu-bar app: AppKit shell around SwiftUI views.
        .executableTarget(name: "PullJoy", dependencies: ["PullJoyCore", "PullJoyKit"]),
        .testTarget(name: "PullJoyCoreTests", dependencies: ["PullJoyCore"]),
        .testTarget(name: "PullJoyKitTests", dependencies: ["PullJoyKit", "PullJoyCore"]),
    ]
)
