// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OnTop",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "OnTop",
            path: "Sources/OnTop"
        )
    ]
)
