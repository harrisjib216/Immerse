// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Immerse",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "ImmerseKit", targets: ["ImmerseKit"]),
    ],
    targets: [
        .target(name: "ImmerseKit"),
        .testTarget(name: "ImmerseKitTests", dependencies: ["ImmerseKit"]),
    ]
)
