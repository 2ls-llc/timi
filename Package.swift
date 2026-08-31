// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PixelPal",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "PixelPal", targets: ["PixelPal"]),
        .library(name: "PixelPalKit", targets: ["PixelPalKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "PixelPalKit",
            path: "Sources/PixelPalKit"
        ),
        .executableTarget(
            name: "PixelPal",
            dependencies: [
                "PixelPalKit",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
            path: "Sources/PixelPal"
        ),
        .testTarget(
            name: "PixelPalKitTests",
            dependencies: ["PixelPalKit"],
            path: "Tests/PixelPalKitTests"
        ),
    ]
)
