// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Timi",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Timi", targets: ["Timi"]),
        .library(name: "TimiKit", targets: ["TimiKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "TimiKit",
            path: "Sources/TimiKit"
        ),
        .executableTarget(
            name: "Timi",
            dependencies: [
                "TimiKit",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
            path: "Sources/Timi"
        ),
        .testTarget(
            name: "TimiKitTests",
            dependencies: ["TimiKit"],
            path: "Tests/TimiKitTests"
        ),
    ]
)
