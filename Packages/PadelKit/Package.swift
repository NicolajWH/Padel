// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PadelKit",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "PadelKit", targets: ["PadelKit"])
    ],
    targets: [
        .target(name: "PadelKit"),
        .testTarget(name: "PadelKitTests", dependencies: ["PadelKit"])
    ]
)
