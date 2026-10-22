// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BKCleanHelper",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "BKCleanHelper", targets: ["BKCleanHelper"])],
    targets: [
        .target(name: "CleanCore"),
        .executableTarget(name: "BKCleanHelper", dependencies: ["CleanCore"]),
        .testTarget(name: "CleanCoreTests", dependencies: ["CleanCore"]),
    ],
    swiftLanguageModes: [.v5]
)
