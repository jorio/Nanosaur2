# picaGL

Vendored from https://github.com/masterfeizz/picaGL (master branch, last
commit 2020-07-14) on 2026-07-06.

A real OpenGL 1.x-style implementation for the 3DS's PICA200 GPU - talks
directly to the GPU command queue via libctru's low-level `GPUCMD_*`/`3ds.h`
API (not citro3d), providing `glBegin`/`glVertex*`/matrix stack/vertex
arrays/texturing/blending/depth-test/stencil, plus a small GLU subset
(`gluPerspective`). See `docs/3DS_PORT_PLAN.md`'s "GL-compat" milestone
section for why this replaced the project's own hand-rolled
`ports/3DS/common/glcompat.c` shim.

**No license file exists in the upstream repo, and none is declared on
GitHub.** Vendored anyway per an explicit decision for this proof-of-concept
port (2026-07-06) - re-evaluate before treating this port as anything other
than a proof of concept (e.g. before any public release), since upstream's
licensing terms are genuinely unknown.

Known gaps in picaGL itself (not something this vendoring fixes): no
lighting support (`state.c` has no `GL_LIGHT*` handling at all), no
`gluLookAt`, and `glBegin` silently maps any primitive it doesn't recognize
(including `GL_QUADS`) to `GPU_TRIANGLE_FAN` with no per-quad restart - a
multi-quad batch in one `glBegin`/`glEnd` will incorrectly fan across all
of them instead of drawing independent quads. `Source/**/*.swift` mostly
draws one quad per `glBegin`/`glEnd` pair, so this may not matter in
practice, but it hasn't been audited call-site by call-site.
