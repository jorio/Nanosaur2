# Metal (SDL_GPU) Renderer — Plan

Branch: `feature/metal` (off `feature/swift`).

Goal: replace Nanosaur 2's fixed-function OpenGL 2.0 rendering with a modern
GPU renderer, using **SDL's GPU API (`SDL_gpu.h`)**, which is backed by Metal
on macOS (and Vulkan/D3D12 elsewhere). This is the "Metal SDL renderer": we
drive Metal through SDL_GPU rather than raw `MTLDevice`.

## Why SDL_GPU and not raw Metal / MetalKit

This is the single most important architectural decision, and it's driven by a
constraint specific to this codebase:

- **This project has ~zero Swift module imports.** A full-tree grep finds only
  one `import` (`import BG3DFile`, a local flat-compiled package). There is no
  `import Foundation`, `import Darwin`, `import Metal`, or `import MetalKit`
  anywhere. This is deliberate — see the memory note
  `feedback_no_system_headers_from_bridging_header`: pulling any part of the
  SDK's Darwin/Foundation Clang module into a file reachable by the
  `-import-objc-header` bridging header forces validation of the whole module,
  including its `MacTypes.h`, whose `Point`/`Rect`/`Boolean`/`FSSpec`
  definitions collide with this project's own `SwMacTypes.h`. This exact
  collision blocked the SwiftPM migration and broke IOKit compilation earlier.
- `import Metal` / `import MetalKit` would almost certainly re-trigger that
  collision (Metal transitively pulls in Foundation). **High risk, must be
  validated before committing to it.**
- **`SDL_gpu.h` is a pure C API already visible through the bridging header**
  (SDL is already included via `game.h`). Using it needs *zero new Swift
  imports* — same as every other SDL call in the codebase. No collision risk.

So: **SDL_GPU is the low-risk path that fits this codebase's established
constraints.** It also keeps the Win32/Linux cross-platform story intact
(the codebase still has `#if WIN32`/`APPLE` branches), since SDL_GPU targets
D3D12/Vulkan there.

Trade-off: SDL_GPU needs **precompiled shaders per backend**. On macOS that's
Metal Shading Language compiled to a `.metallib` (or MSL source strings). We
control the one platform we're shipping first (macOS), so we ship MSL; other
backends can be added later via SDL_shadercross or hand-written variants.

**Decision to confirm with the user before Phase 1:** SDL_GPU (recommended) vs.
raw Metal via `SDL_Metal_CreateView` + `import Metal` (cleaner Metal API, but
must first prove the MacTypes collision can be avoided — likely can't without
isolating Metal code into a separate non-bridged module/target).

## Current rendering architecture (surveyed 2026-07-08)

Everything is **fixed-function OpenGL 2.0 compatibility profile**. ~700 `gl*`
call sites across ~30 files. Breakdown of what has to be reimplemented:

### Context & frame loop (OGL_Support.swift)
- `OGL_CreateDrawContext()` — `SDL_GL_CreateContext` on `gSDLWindow`, sets
  swap interval, loads `glActiveTexture` proc, optional 2nd context for
  `--dual-screen`.
- `OGL_DrawScene(drawRoutine)` — the frame. Sets viewport/projection/camera/
  lights, clears buffers, runs the game's `@convention(c)` draw callback,
  then `SDL_GL_SwapWindow`. Also runs the scene **twice** for stereo
  (anaglyph colour-mask passes / shutter buffer swaps).
- Dual-screen mode = a second window + GL context + swap.

### 3D geometry — the ONE core path (MetaObjects.swift)
- `MO_DrawGeometry_VertexArray(MOVertexArrayData*)` — indexed triangle lists
  via client-side vertex arrays: `glVertexPointer`/`glNormalPointer`/
  `glTexCoordPointer`/`glColorPointer` + `glEnableClientState` +
  `glDrawElements(GL_TRIANGLES, …, GL_UNSIGNED_INT, triangles)`.
- Multi-texture (up to 2 UV sets), texgen (reflection mapping), per-vertex
  colour, optional normals. Material state via `MO_DrawMaterial`.
- This is the good news: **almost all in-world geometry funnels through this
  one function.** A single vertex/fragment shader pair + buffer path covers
  the terrain, skeletons, models, items, enemies.

### 2D / UI / effects — immediate mode (the hard, scattered part)
- `glBegin/glEnd/glVertex*/glTexCoord*/glColor*` in ~25 files:
  Infobar.swift (152 gl calls — the HUD), sprites (`MO_DrawSprite`),
  Particles, Water, Shards, LaserOrbs, Sparkle, menus, screen transitions.
- Metal has no immediate mode. Each `glBegin…glEnd` span becomes: build a
  small vertex buffer, bind a pipeline, draw. This needs a thin **immediate-
  mode emulation layer** (an `ImmediateBatch` that accumulates verts and
  flushes on state change / `end()`), or a per-call-site rewrite. The
  emulation layer is far less churn and is the recommended route.

### Fixed-function state → shader uniforms
Metal has none of these; each becomes a uniform + shader logic:
- **Matrix stack** (`glMatrixMode`/`glPushMatrix`/`glLoadMatrixf`/
  `glMultMatrixf`/`glTranslatef`/etc.). The codebase already has
  `OGLMatrix4x4` math in Swift — reimplement the modelview/projection stacks
  in Swift and feed a combined MVP uniform.
- **Lighting** (`glLightfv`/`glMaterialfv`/`glLightModeli`) — up to a few
  directional/point lights + ambient. Move into the vertex/fragment shader
  as a small lighting UBO.
- **Texturing / texenv** (`glTexEnvi` combine modes, multitexture, `glTexGeni`
  reflection texgen) — fragment shader with 0–2 samplers + a texenv mode
  uniform.
- **Fog** (`glFogf`/`glFogfv`/`glFogi`) — fragment shader, linear/exp fog UBO.
- **Alpha test** (`glAlphaFunc`) — fragment `discard`.
- **Blend / depth / cull / colour-mask / polygon-mode** — direct SDL_GPU
  pipeline state (these map cleanly, no shader work).

### Textures
- `glGenTextures`/`glTexImage2D` (BGRA source) / `glTexSubImage2D` (dynamic
  update, e.g. anaglyph). Map to `SDL_CreateGPUTexture` + upload via a copy
  pass. Formats: BGRA8. Straightforward.

## The abstraction strategy

Do **not** rewrite 700 call sites to SDL_GPU directly. Instead:

1. Introduce a small **renderer facade** (Swift) that exposes the operations
   the game actually performs — the same verbs the `gl*` calls express:
   `setMatrix`, `pushMatrix`, `bindTexture`, `setBlend`, `beginImmediate`/
   `vertex`/`end`, `drawIndexed(MOVertexArrayData)`, `setLight`, `setFog`, etc.
2. Keep the **existing GL implementation** behind that facade as backend #1
   (so nothing breaks and we can A/B).
3. Add the **SDL_GPU/Metal implementation** as backend #2, selectable at
   runtime (env var / `--metal` flag) during development.
4. Migrate the codebase's `gl*` call sites to the facade **incrementally**,
   file by file, verifying the GL backend still renders identically after each
   — this is the same "small batch + verify" discipline used throughout the
   Swift port. Only once the facade covers everything do we flip the default
   to Metal.

This makes the effort *incremental and always-shippable* instead of a
big-bang rewrite that leaves the game unrunnable for weeks.

## Phased plan

**Phase 0 — Spike (de-risk the toolchain).** Prove the two unknowns before
committing: (a) SDL_GPU device creation + a clear-screen render pass on
`gSDLWindow` compiles and runs in this CMake/bridging-header build with no new
Swift imports; (b) an MSL shader can be compiled to a `.metallib` (or loaded
as MSL source) and bound. Deliverable: a `--metal` mode that opens the window
and clears it to a colour via SDL_GPU, alongside the untouched GL path.

**Phase 1 — Renderer facade + GL backend.** Define the facade protocol; wrap
the current GL calls behind it in `OGL_Support`/`MetaObjects` without behaviour
change. Ship. (No Metal yet — pure refactor, fully verifiable against current
output.)

**Phase 2 — Core 3D via SDL_GPU.** Implement the facade's `drawIndexed`
(the `MO_DrawGeometry_VertexArray` path) + the main lit/textured shader +
matrix/light/fog/texenv uniforms + texture upload. Get the in-world 3D scene
rendering under `--metal`. This alone makes most of a level look right.

**Phase 3 — Immediate-mode emulation.** Build the `ImmediateBatch` layer so
Infobar/sprites/particles/menus render under Metal. This is the largest single
chunk of surface.

**Phase 4 — Stereo, dual-screen, edge cases.** Anaglyph colour-mask passes
(render-to-texture + channel combine shader), shutter, `--dual-screen` second
swapchain, `glReadPixels`/screenshot paths, polygon-mode wireframe (F8 debug).

**Phase 5 — Flip default to Metal, retire GL backend (optional).** Once Metal
reaches parity and is verified across every screen, make it default. Keep the
GL backend behind a flag (or remove) per user preference.

## Hard problems / risks (ranked)

1. **`import Metal` collision** (mitigated by choosing SDL_GPU; still must
   validate in Phase 0 that SDL_GPU needs no Swift module imports).
2. **Immediate-mode surface** (~400+ `glBegin/glVertex/glEnd` calls) — biggest
   volume of work; the emulation-layer approach is what keeps it tractable.
3. **texenv combine modes / multitexture / texgen** — need faithful shader
   equivalents; get exact modes from the `glTexEnvi(GL_COMBINE*, …)` and
   `glTexGeni` call sites in MetaObjects/Water/etc.
4. **Stereo anaglyph** — currently done with `glColorMask` + `glTexSubImage2D`
   channel-balancing; becomes a post/combine pass.
5. **Shader toolchain in CMake** — compiling `.metal` → `.metallib` at build
   time and loading it; decide MSL-source-at-runtime vs. prebuilt metallib.
6. **Verification is visual and manual** — every screen/effect must be eyeballed
   for parity (colours, blending, fog, transparency ordering). No automated
   check; expect a long tail of "this one effect looks slightly off."

## DECISION (user, 2026-07-08): raw Metal via `SDL_Metal_CreateView`, not SDL_GPU.

## Phase 0 finding (2026-07-08): `import Metal` collision is CONFIRMED and forces an isolation decision.

Empirically tested with a one-file probe (`import Metal` + `MTLCreateSystemDefaultDevice()`):
the build fails exactly as predicted —

```
SwMacTypes.h:83: error: 'Point' has different definitions in different modules;
  found field 'v' with type 'SInt16'
  …but in 'Darwin.MacTypes' found field 'v' with type 'short'
```

Metal transitively imports the Darwin `MacTypes` Clang module, whose `Point`
(`short v,h`) collides with this project's `SwMacTypes.h` `Point` (`SInt16 v,h`)
that every Swift file gets via the bridging header. **No Swift file compiled
with the bridging header can `import Metal`.** So the Metal code must be
*isolated* from the bridging header. Two ways to do that — this is the next
decision to make:

**Option A — Objective-C++ (`.mm`), C API.** Write the Metal renderer in an
`.mm` translation unit that `#import <Metal/Metal.h>`/`<QuartzCore/…>` and SDL,
but does NOT include the game's `game.h`/`SwMacTypes.h` (so no collision in the
`.mm` either). It exposes plain `extern "C"` entry points using only primitive
types (`const float*`, `uint32_t`, opaque handles), declared in a small clean
C header that the bridging header includes. Swift calls those C functions —
exactly the C-interop pattern this codebase already uses everywhere.
- Pros: zero new build machinery, no module boundary, matches existing pattern,
  lowest friction to a working spike.
- Cons: new code is Objective-C++, which cuts against the project's C→Swift
  porting direction (we'd be *adding* non-Swift code).

**Option B — Separate Swift module (new CMake target, no bridging header).**
A second Swift target compiled *without* `-import-objc-header`, free to
`import Metal`, exposing a Swift API; the main game module links/imports it.
Game geometry crosses the boundary as primitives (raw pointers + counts).
- Pros: new renderer code stays in Swift, consistent with the port's goal.
- Cons: real build complexity (the game is currently one flat Swift module;
  this adds a second module + its `.swiftmodule` interface), and the
  data-marshalling boundary needs designing. Higher upfront cost.

Recommendation: **Option A** for the Phase 0 spike (fastest path to a verified
clear-screen), with the option to migrate the renderer's authoring to Swift
(Option B) later if keeping everything in Swift matters more than simplicity.

## DECISION (user, 2026-07-08): isolate via a separate Swift module (Option B).

## Phase 0 RESULT (2026-07-08): native Swift Metal works — via a separate module + `@_implementationOnly import`.

Built and verified (compiles + links cleanly, game still runs on GL):

- **`Source/Metal/MetalRenderer.swift`** — a separate CMake Swift static-library
  target (`MetalRenderer`), compiled *without* the game's bridging header, so
  it can import Metal. Sets up `MTLDevice`/`MTLCommandQueue` from a
  `CAMetalLayer` pointer passed in, and has a Phase-0 `clearFrame(...)` that
  clears+presents a drawable. Public API uses only primitives/opaque handles
  (no Metal types leak).
- **`Source/Metal` excluded from the flat game module** in CMakeLists; built as
  `add_library(MetalRenderer STATIC …)` linking `-framework Metal -framework
  QuartzCore`, then linked into `Nanosaur2`.
- **`Source/3D/MetalSpike.swift`** — glue in the *game* module (which has SDL):
  `import MetalRenderer`, creates the `CAMetalLayer` via
  `SDL_Metal_CreateView`/`SDL_Metal_GetLayer` on `gSDLWindow`, hands the raw
  pointer to `MetalRenderer`. Not yet wired into the frame loop.

**Critical gotcha found and solved:** a plain `import Metal` inside a *separate*
Swift module is NOT enough. When the game module (which has `SwMacTypes.h` via
its bridging header) does `import MetalRenderer`, Swift transitively surfaces
MetalRenderer's Metal/QuartzCore *Clang-module* dependencies into the game
module's ClangImporter, and the `Point`/`MacTypes` collision fires again.
The fix is **`@_implementationOnly import Metal` / `@_implementationOnly import
QuartzCore`** inside MetalRenderer — this keeps the Metal Clang modules an
implementation detail that does not propagate to clients. Legal precisely
because MetalRenderer's public API exposes zero Metal types. This is the load-
bearing trick that makes the whole "native Swift Metal in this codebase"
approach viable.

## Phase 0 COMPLETE (2026-07-08): Metal spike confirms a live Metal frame on screen.

`Boot.cpp`'s `main()` checks for `--metal-spike` before anything else and, if
present, calls `RunMetalSpike()` instead of the normal `Boot()`/`GameMain()`
path (originally this was `--metal`; renamed when `--metal` was repurposed
for the real integration below — see Phase 2). `RunMetalSpike()` deliberately
does **not** reuse the normal boot sequence: it does its own minimal
`SDL_Init(SDL_INIT_VIDEO)`, creates `gSDLWindow` with `SDL_WINDOW_METAL` (no
`SDL_WINDOW_OPENGL`, no `SDL_GL_SetAttribute` calls), calls
`SwMetalSpike_Init()`, then runs its own tiny event/present loop that calls
`SwMetalSpike_ClearFrame(r, g, b)` every iteration with a cycling
HSV-derived colour (so a static clear can't be mistaken for a live one),
until the window is closed or Escape is pressed. Kept around as a minimal
regression check for the SDL-layer → Metal present path in isolation.

The three `SwMetalSpike_*` functions (`Source/3D/MetalSpike.swift`) are
exposed to C++ via `@c @implementation` (the same pattern as `GameMain`),
declared in `Source/Headers/main.h`.

**Verified on screen (computer-use screenshots):** launching the spike opens
a window that logged `MetalSpike: renderer live on device 'Apple M1 Pro'
(1280x960)` and visibly cycles through colours, proving the full
`SDL_Metal_CreateView` → `CAMetalLayer` → `MetalRenderer` (separate module)
→ `MTLCommandQueue`/render-pass → `presentDrawable` path is live end to end,
not just compiling. Re-verified after an unrelated `build/` dir loss and
rebuild (2026-07-08).

## Phase 1 COMPLETE (2026-07-08): RenderBackend facade covers the main menu screen's whole draw path

`Source/3D/RenderBackend.swift` defines a `RenderBackend` protocol +
`GLRenderBackend` (reproduces today's exact gl* calls — pure refactor, zero
behaviour change, verified via clean builds + live gameplay after every
slice). Selected via `var gRenderBackend: RenderBackend`. Landed in six
incremental, individually-verified commits, covering:
state toggles (blend/texture2D/lighting/cullface/fog/depthTest/color),
the matrix stack (matrixMode/push/pop/loadIdentity/loadMatrix/multMatrix),
texture bind + creation/upload, translate/scale/rotate + texture wrap,
immediate mode (beginImmediate/vertex2f/vertex3f/texCoord2f/endImmediate —
GLRenderBackend forwards 1:1 to real glBegin/glVertex/glTexCoord/glEnd since
every call site here is a single self-contained primitive, no cross-frame
batching needed), and viewport/clear/present/wireframe.

Investigated what the main menu screen (`DoMainMenuScreen` in
`MainMenu.swift`) actually draws: **no 3D geometry** — just a full-screen
background picture (`MO_DrawPicture`), a mouse-cursor sprite
(`MO_DrawSprite`), and menu text (`Atlas_DrawString2` → immediate-mode
quads), all funneling through `MO_DrawMaterial` for texture/color state and
`OGL_DrawScene` for the per-frame viewport/clear/camera/present sequence.
The facade now covers all of it. The 3D vertex-array geometry path
(`MO_DrawGeometry_VertexArray`) and GL state *introspection*
(`glGetIntegerv`/`glIsEnabled`/`glGetBooleanv` in `OGL_PushState`/
`DrawBlueLine`) are explicitly NOT covered — separate, larger design work.

## Phase 2 IN PROGRESS (2026-07-08): real Metal draw plumbing + `--metal` wired to render the actual game

- **`Source/Metal/MetalRenderer.swift`** expanded from the Phase 0 clear-only
  spike into a real draw layer: an embedded MSL shader (MVP transform,
  texture × vertex-color), two `MTLRenderPipelineState`s (blend on/off — GL's
  per-draw `glEnable(GL_BLEND)` doesn't exist in Metal; blending is baked
  into pipeline state), two `MTLDepthStencilState`s (depth test on/off), a
  1×1 white default texture (so the shader never branches on "textured?" —
  "no texture" just samples white, matching `disableTexture2D`'s effect), a
  texture handle table (`createTexture`/`updateTexture`/`bindTexture`,
  synthesized `Int32` IDs), and a real `beginFrame`/`draw`/`endFrame` frame
  lifecycle. Still knows nothing about GL enums — stays a dumb, primitive-
  typed Metal layer by design (isolation boundary intact).
- **`Source/3D/MetalRenderBackend.swift`** (new, main module): implements
  `RenderBackend` by translating GL-shaped verbs into `MetalRenderer` calls —
  a CPU-side matrix stack per GL matrix mode (recomputes and pushes the MVP
  uniform on every mutation), GL_QUADS/TRIANGLES/LINE_LOOP/LINE_STRIP/LINES
  immediate-mode accumulation (GL_QUADS triangulated per-4-vertices, matching
  GL's independent-quads-per-batch semantics — `Atlas_ImmediateDraw` submits
  many quads, one per glyph, in a single begin/end block), texture handles
  passed through 1:1, and clear/viewport/present mapped onto
  `beginFrame`/`endFrame`. Documented, deliberate gaps for this milestone
  (see the file's header comment): fixed blend equation (no per-call
  `blendFunc`), no lighting/fog/cull-face/texture-wrap, GL's `[-1,1]` NDC
  z-range vs Metal's `[0,1]` not corrected, viewport Y-origin not flipped —
  all harmless for a 2D-only menu screen, all need real fixes before any 3D
  content is migrated.
- **`Source/3D/MetalActivation.swift`** (new) + `gMetalMode` global
  (`BootGlobals.c`/`game.h`, same pattern as `gDualScreenMode`): `--metal`
  now means *run the actual game through Metal*, not the old spike. `Boot()`
  still creates `gSDLWindow` with its normal GL context unconditionally —
  deliberately left alive and simply never `SDL_GL_SwapWindow`'d once Metal
  is active. This is the key design choice that avoids having to migrate
  *every* raw `gl*` call in the codebase before anything can render: any
  not-yet-faceted call (lighting setup, state introspection, the 3D geometry
  path, stereo/dual-screen) still executes fine against a valid context —
  its output just never reaches the screen, since only the Metal layer
  (a second, Metal-backed SDL view on the same window) gets presented.
  `main()` calls `SwMetalBackend_Activate()` right after `Boot()`, before
  `GameMain()`; on failure it logs and falls back to `GLRenderBackend`
  (game still runs, just via GL).

**Status: wired and builds clean, but UNVERIFIED ON SCREEN.** This is real,
not-yet-visually-tested code — the author (an AI agent) does not launch the
app in this project (see the project memory's launch-ownership note); the
user runs `Nanosaur2 --metal` themselves. What to check when testing:
does the main menu screen appear at all (vs. black/crash/nothing), does the
background picture/cursor/text look reasonable (position, color, blending),
and does closing/quitting behave normally. Known-likely rough edges per the
gaps list above: menu text using the "glow" pulse effect may look like flat
alpha blend instead of additive glow; any edge-clamped sprite may show
faint repeat-wrap bleeding at its border.

## What exists now on this branch

- Branch `feature/metal`.
- This plan.
- Phase 0: live-verified Metal spike (`--metal-spike`).
- Phase 1: RenderBackend facade, complete for the main menu's draw path,
  each slice individually verified against live GL gameplay.
- Phase 2: real Metal draw plumbing + `--metal` wired to render the actual
  game — builds clean, not yet visually verified. **Next: user tests
  `--metal` from Xcode and reports what's on screen; iterate from there.**
