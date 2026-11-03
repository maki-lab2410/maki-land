// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "makiland",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "makiland",
            targets: ["makiland"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "makiland",
            dependencies: [],
            path: "Sources/DynamicIsland"
        )
    ]
)
