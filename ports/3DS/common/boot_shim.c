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

SDL_Window *gSDLWindow = NULL;
SDL_Window *gSDLWindow2 = NULL;
Boolean gDualScreenMode = 0;
int gCurrentAntialiasingLevel = 0;
