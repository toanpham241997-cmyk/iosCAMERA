// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIMatCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "AIMatCore", targets: ["AIMatCore"])],
    targets: [
        .target(name: "AIMatCore", path: "AIMat/Core"),
        .testTarget(name: "AIMatCoreTests", dependencies: ["AIMatCore"], path: "Tests")
    ]
)
