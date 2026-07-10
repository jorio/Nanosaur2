// swift-tools-version: 6.2
import PackageDescription

// NOTE: this package currently only defines the standalone, independently
// tested parser libraries (BG3DFile, ResourceFile). The full CNanosaur2Core/
// Nanosaur2Swift/Nanosaur2Exe targets from the CMake->SwiftPM migration are
// commented out below - that migration is paused (see
// project_nanosaur2_spm_migration in memory) and its file moves were
// reverted, so those targets' `path:`s no longer exist. Re-enable them (and
// restore the moves) when that migration resumes. The project no longer
// depends on Pomme at all (removed entirely, including from the 3DS port),
// so that target is gone too - CNanosaur2Core/Nanosaur2Exe below no longer
// reference it.

let package = Package(
    name: "Nanosaur2",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "BG3DFile", type: .static, targets: ["BG3DFile"]),
        .library(name: "ResourceFile", type: .static, targets: ["ResourceFile"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-binary-parsing", from: "0.0.2")
    ],
    targets: [
        // MARK: - BG3DFile (standalone, tested BG3D model-file parser)

        .target(
            name: "BG3DFile",
            dependencies: [
                .product(name: "BinaryParsing", package: "swift-binary-parsing")
            ]
        ),
        .testTarget(
            name: "BG3DFileTests",
            dependencies: ["BG3DFile"]
        ),

        // MARK: - ResourceFile (standalone, tested classic-Mac resource-fork parser)

        .target(
            name: "ResourceFile",
            dependencies: [
                .product(name: "BinaryParsing", package: "swift-binary-parsing")
            ]
        ),
        .testTarget(
            name: "ResourceFileTests",
            dependencies: ["ResourceFile"]
        ),

        /* Paused pending SPM migration resuming - see note above.

        // MARK: - CNanosaur2Core (remaining C surface: real data tables, C-variadic
        // functions, platform code, and the game's ~50 shared C headers)

        .target(
            name: "CNanosaur2Core",
            path: "Sources/CNanosaur2Core",
            publicHeadersPath: "SPMPublicHeaders",
            cSettings: [
                .headerSearchPath("include"),
                .unsafeFlags(sdlFrameworkSearchPath),
            ],
            linkerSettings: [
                .unsafeFlags(sdlLinkFlags),
                .linkedFramework("Foundation", .when(platforms: [.macOS])),
                .linkedFramework("IOKit", .when(platforms: [.macOS])),
            ]
        ),

        // MARK: - Nanosaur2Swift (the Swift port itself)

        .target(
            name: "Nanosaur2Swift",
            dependencies: ["CNanosaur2Core", "BG3DFile"],
            path: "Source",
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .unsafeFlags(["-parse-as-library"]),
                // Required by BG3DFile's dependency on swift-binary-parsing.
                .enableExperimentalFeature("Lifetimes"),
                // The ~50 headers under CNanosaur2Core/include were written
                // for CMake's -import-objc-header (textual, order-dependent
                // inclusion via game.h) and aren't individually
                // self-contained, which SPM's real Clang-module validation
                // for `import CNanosaur2Core` rejects outright (confirmed:
                // even force-including a shared prelude ahead of every
                // header via -Xcc -include didn't satisfy the per-header
                // module-map validator). Using the same -import-objc-header
                // mechanism CMake already used successfully sidesteps that
                // validation entirely - the C symbols become ambiently
                // visible to every file in this target, exactly as under
                // CMake, with no `import CNanosaur2Core` statement needed
                // anywhere.
                .unsafeFlags([
                    "-import-objc-header", "Sources/CNanosaur2Core/include/Nanosaur2-Bridging-Header.h",
                    "-Xcc", "-I", "-Xcc", "Sources/CNanosaur2Core/include",
                    "-Xcc", "-F", "-Xcc", "extern",
                ]),
            ]
        ),

        // MARK: - Nanosaur2Exe (entry point: Boot.cpp's main(), which calls into
        // Nanosaur2Swift's GameMain())

        .executableTarget(
            name: "Nanosaur2Exe",
            dependencies: ["CNanosaur2Core", "Nanosaur2Swift"],
            path: "Sources/Nanosaur2Exe",
            cxxSettings: [
                .headerSearchPath("../CNanosaur2Core/include"),
                .unsafeFlags(sdlFrameworkSearchPath),
            ],
            linkerSettings: [
                .unsafeFlags(sdlLinkFlags),
            ]
        ),
        */
    ],
    cxxLanguageStandard: .cxx20
)
