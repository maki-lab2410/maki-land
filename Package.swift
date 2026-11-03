// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DynamicIsland",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "DynamicIsland",
            targets: ["DynamicIsland"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "DynamicIsland",
            dependencies: [],
            path: "Sources/DynamicIsland"
        )
    ]
)
