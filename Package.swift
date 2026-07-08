// swift-tools-version: 6.2
import PackageDescription

// Framework search path for the vendored extern/SDL3.framework (not an
// xcframework, so it's linked via unsafe -F/-framework flags rather than a
// binaryTarget). Paths in unsafe flags are resolved relative to the
// package root.
let sdlFrameworkSearchPath = ["-F", "extern"]
let sdlLinkFlags = sdlFrameworkSearchPath + ["-framework", "SDL3"]

let package = Package(
    name: "Nanosaur2",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "BG3DFile", type: .static, targets: ["BG3DFile"]),
        .executable(name: "Nanosaur2", targets: ["Nanosaur2Exe"])
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

        // MARK: - Pomme (Mac-toolbox-on-SDL compatibility layer)
        //
        // Mirrors extern/Pomme/CMakeLists.txt's POMME_NO_GRAPHICS/INPUT/VIDEO/QD3D=true
        // configuration (Nanosaur2 does its own OpenGL rendering and SDL input
        // handling, and doesn't use Pomme's QuickDraw 3D or QuickTime video code).
        .target(
            name: "Pomme",
            path: "extern/Pomme/src",
            exclude: [
                "Graphics",
                "Input",
                "Video",
                "QD3D",
                "Platform/Windows",
            ],
            // Pomme's real public surface (Pomme.h, PommeInit.h, etc.) lives
            // flat alongside its .cpp files, mixed across several
            // subdirectories - not a layout SPM's public-headers validator
            // accepts directly (naming Pomme.h as the umbrella conflicts with
            // the sibling source directories). Nothing needs to `import
            // Pomme` as a Clang module; CNanosaur2Core/Nanosaur2Exe reach its
            // headers via their own explicit headerSearchPath instead. This
            // points at a placeholder directory (SPMPublicHeaders/) that
            // nothing else includes into - pointing it at a real subdirectory
            // like CompilerSupport/ causes a "module Pomme is needed but has
            // not been provided" error the moment another target's raw
            // #include reaches a header under that same subdirectory, since
            // Clang then considers it part of the Pomme module.
            publicHeadersPath: "SPMPublicHeaders",
            cxxSettings: [
                .define("POMME_NO_GRAPHICS"),
                .define("POMME_NO_INPUT"),
                .define("POMME_NO_VIDEO"),
                .define("POMME_NO_QD3D"),
                .headerSearchPath("."),
                .unsafeFlags(sdlFrameworkSearchPath),
            ],
            linkerSettings: [
                .unsafeFlags(sdlLinkFlags)
            ]
        ),

        // MARK: - CNanosaur2Core (remaining C surface: real data tables, C-variadic
        // functions, platform code, and the game's ~50 shared C headers)

        .target(
            name: "CNanosaur2Core",
            dependencies: ["Pomme"],
            path: "Sources/CNanosaur2Core",
            publicHeadersPath: "SPMPublicHeaders",
            cSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("../../extern/Pomme/src"),
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
                    "-Xcc", "-I", "-Xcc", "extern/Pomme/src",
                    "-Xcc", "-F", "-Xcc", "extern",
                ]),
            ]
        ),

        // MARK: - Nanosaur2Exe (entry point: Boot.cpp's main(), which calls into
        // Nanosaur2Swift's GameMain())

        .executableTarget(
            name: "Nanosaur2Exe",
            dependencies: ["CNanosaur2Core", "Nanosaur2Swift", "Pomme"],
            path: "Sources/Nanosaur2Exe",
            cxxSettings: [
                .headerSearchPath("../../extern/Pomme/src"),
                .headerSearchPath("../CNanosaur2Core/include"),
                .unsafeFlags(sdlFrameworkSearchPath),
            ],
            linkerSettings: [
                .unsafeFlags(sdlLinkFlags),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx20
)
