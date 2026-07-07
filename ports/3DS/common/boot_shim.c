// boot_shim.c - real storage for the handful of globals Source/Boot.cpp
// (desktop-only: argv parsing, SDL_CreateWindow, --dual-screen handling -
// none of which applies on 3DS) normally defines, that a few still-C
// engine files read directly via `extern` (AnaglyphCalibration.c's
// gSDLWindow, Settings.c's gCurrentAntialiasingLevel). Not read/written by
// anything on 3DS beyond satisfying the link - there's no SDL window to
// point gSDLWindow at (real SDL3's 3DS backend is software-rendering-only,
// see docs/3DS_PORT_PLAN.md), no dual-screen mode, no antialiasing level
// setting exposed yet.
//
// gSDLWindow is now a REAL SDL_Window (created in source/main.cpp via
// SDL_CreateWindow, same as desktop's Boot.cpp) even though picaGL - not
// SDL's own GL/renderer backend - does the actual drawing: too many engine
// call sites (OGL_Support.swift's window-size query, MainMenu.swift's mouse
// cursor tracking, Input.swift's mouse warp/grab) dereference gSDLWindow as
// a real SDL_Window every frame, so a fake non-NULL placeholder crashes the
// moment any of them run. This is just extern storage; main.cpp assigns it.
#include "PommeTypes.h"
#include <SDL3/SDL.h>
#include <stdint.h>

SDL_Window *gSDLWindow = NULL;
SDL_Window *gSDLWindow2 = NULL;
Boolean gDualScreenMode = 0;
int gCurrentAntialiasingLevel = 0;

// NOTE: __ctru_heap_size/__ctru_linear_heap_size (libctru's weak-symbol
// heap size overrides, see 3ds/env.h) were tried here as a workaround for
// LoadPlayfield's supertile texture-assembly loop (Source/System/File.swift)
// running out of linear memory after ~250 supertile textures. Measured
// defaults: heap=89MiB, linearHeap=32MiB. But heap+linearHeap draw from one
// fixed total pool - growing linearHeap by 16MiB shrank the regular heap by
// exactly 16MiB, which regressed a DIFFERENT, previously-reliable code path
// (LoadSoundBank crashed loading story7's effect instead). Reverted: this
// needs a real fix (why isn't the sliding-window loop's disposal actually
// freeing linear memory as it's designed to?), not a memory-budget shuffle.
