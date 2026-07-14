// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AppDelta",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AppDelta", targets: ["AppDelta"])
    ],
    targets: [
        .executableTarget(
            name: "AppDelta",
            path: "Sources/AppDelta"
        ),
        .testTarget(
            name: "AppDeltaTests",
            dependencies: ["AppDelta"],
            path: "Tests/AppDeltaTests"
        )
    ]
)
