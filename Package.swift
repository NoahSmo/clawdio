// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Clawdio",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Clawdio",
            path: "Sources/Clawdio"
        )
    ],
    swiftLanguageModes: [.v5]
)
