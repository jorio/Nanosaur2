# SDL3 (real, official 3DS backend)

Built from https://github.com/libsdl-org/SDL (main branch) on 2026-07-06,
using devkitPro's official `$DEVKITPRO/cmake/3DS.cmake` toolchain file:

```
cmake -S. -Bbuild-3ds -DCMAKE_TOOLCHAIN_FILE="$DEVKITPRO/cmake/3DS.cmake" -DCMAKE_BUILD_TYPE=Release
cmake --build build-3ds
```

Unlike `../picaGL` (see its own `VENDORED.md`), this is zlib-licensed
(SDL's standard license) with no vendoring concerns.

Vendored here: `include/SDL3/*.h` (public API headers, unmodified) plus two
build-generated headers real consumers need (`SDL_build_config.h`,
`SDL_revision.h`), and the built static library (`lib/libSDL3.a`).

Per `docs/README-n3ds.md` upstream: **software rendering only** - no GPU/
OpenGL acceleration (there's an open, unmerged upstream PR for that). This
is why picaGL is still used for all actual drawing - real SDL3 replaces
this project's own hand-rolled `common/SDL3/SDL.h` stub + `sdlcompat.c` for
events/audio/joystick/timers/locale instead, which it implements for real
(`src/video/n3ds`, `src/audio/n3ds`, `src/joystick/n3ds`) rather than as
guessed always-empty/always-false stubs.

`common/SDL3/SDL_opengl.h`/`SDL_opengl_glext.h` are NOT replaced by real
SDL3's own copies of those headers - they still forward to picaGL's
`<GL/gl.h>` (see those files' own comments) - GL declarations need to
resolve to picaGL's real implementation, not just any declaration.
