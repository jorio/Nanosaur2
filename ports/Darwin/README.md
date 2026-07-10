# Nanosaur 2 — macOS Screen Saver (ports/Darwin)

A native macOS screen saver (`Nanosaur2.saver`) that renders the game's
attract-mode scene: the level-intro wormhole with the nano + jetpack,
star dome, logo, and pulsing "PRESS ANY KEY" — i.e.
`DoLevelIntroScreen(INTRO_MODE_SCREENSAVER)`.

Built from a **curated subset** of the engine (~40 Swift files + a few C
leftovers), with **no SDL** (a small `Saver/shim.c` supplies the handful of
runtime calls the subset reaches — clock, logging, malloc, UTF-8 — plus
link-only stubs for compiled-but-unreachable code) and **only the assets
the scene loads** (~2.7 MB out of the 113 MB Data folder — same list as
`ports/3DS/romfs-poc`). Bundle ends up around 5 MB.

## Building

Xcode project (recommended):

```sh
cmake -G Xcode -B ports/Darwin/build-xcode ports/Darwin
open ports/Darwin/build-xcode/Nanosaur2ScreenSaver.xcodeproj
# build the Nanosaur2Saver target; output: Debug/Nanosaur2.saver
```

Command line (Ninja/Make):

```sh
cmake -B ports/Darwin/build ports/Darwin
cmake --build ports/Darwin/build
```

## Installing

```sh
cp -R ports/Darwin/build/Nanosaur2.saver ~/Library/Screen\ Savers/
```

Then pick "Nanosaur 2" in System Settings → Screen Saver. (If it was
already installed, System Settings/legacyScreenSaver may cache the old
bundle — toggling to another saver and back, or logging out, refreshes it.)

## Headless smoke test

`SaverSmoke` drives the exact same C entry points as the saver view
against an offscreen CGL context and dumps a frame:

```sh
./ports/Darwin/build/SaverSmoke \
    ports/Darwin/build/Nanosaur2.saver/Contents/Resources/Data \
    /tmp/frame.ppm 120
```

It runs boot → scene → 120 frames → teardown → second scene cycle, so it
catches most engine regressions without installing anything.

## Architecture

- **Two Swift modules.** The engine subset compiles with the game's
  bridging header, which cannot coexist with an `import AppKit`
  (SwMacTypes vs Darwin.MacTypes — same reason MetalRenderer is a separate
  module). So `Nanosaur2SaverView.swift` (ScreenSaverView + NSOpenGLContext)
  lives in its own module and talks to the engine through 4 C entry points:
  `Nanosaur2Saver_Boot/StartScene/Frame/StopScene` (`Saver/saver_api.h`,
  implemented in `Saver/SaverGlue.swift`).
- **`NANOSAUR_SCREENSAVER`** compile condition (like `NANOSAUR_3DS`) seams
  the engine: host-owned GL context (`RenderBackend.swift`), host-provided
  window size (`OGL_DrawScene`), gameplay code fenced off in
  `Camera.swift`/`Infobar.swift`/`File.swift`/`ObjNodeExtensions.swift`.
- **`Saver/SaverStubs.swift`** provides state-only shells for the gEngine
  subsystems whose real files aren't compiled (player, terrain, sound,
  menus, ...), plus no-op sound/terrain/collision queries reachable from
  generic object paths.
- The scene itself is shared with the desktop game:
  `Source/Screens/LevelIntroScene.swift` (split out of `LevelIntro.swift`,
  which remains the desktop screen driver for save/credits/screensaver
  modes).
