// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodexUsagePeek",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "CodexUsageCore", targets: ["CodexUsageCore"]),
        .executable(name: "CodexUsagePeek", targets: ["CodexUsagePeek"]),
    ],
    targets: [
        .target(name: "CodexUsageCore"),
        .executableTarget(
            name: "CodexUsagePeek",
            dependencies: ["CodexUsageCore"]
        ),
        .testTarget(
            name: "CodexUsageCoreTests",
            dependencies: ["CodexUsageCore"]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
