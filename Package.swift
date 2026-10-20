// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacCleaner",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "CleanerCore", path: "Sources/CleanerCore"),
        .executableTarget(
            name: "MacCleaner",
            dependencies: ["CleanerCore"],
            path: "Sources/MacCleaner"
        ),
        .testTarget(
            name: "CleanerCoreTests",
            dependencies: ["CleanerCore"],
            path: "Tests/CleanerCoreTests"
        ),
    ]
)
