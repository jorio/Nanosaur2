// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Nanosaur2",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "BG3DFile", type: .static, targets: ["BG3DFile"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-binary-parsing", from: "0.0.2")
    ],
    targets: [
        .target(
            name: "BG3DFile",
            dependencies: [
                .product(name: "BinaryParsing", package: "swift-binary-parsing")
            ]
        ),
        .testTarget(
            name: "BG3DFileTests",
            dependencies: ["BG3DFile"]
        )
    ]
)
