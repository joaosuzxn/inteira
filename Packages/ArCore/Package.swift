// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ArCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "ArCore", targets: ["ArCore"])
    ],
    targets: [
        .target(name: "ArCore"),
        .testTarget(name: "ArCoreTests", dependencies: ["ArCore"])
    ]
)
