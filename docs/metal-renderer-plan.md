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

## What exists now on this branch

- Branch `feature/metal` created.
- This plan.
- (Nothing else yet — Phase 0 spike is the next step, pending the SDL_GPU
  vs. raw-Metal decision confirmation.)
