// boot_shim.c - real storage for the handful of globals Source/Boot.cpp
// (desktop-only: argv parsing, SDL_CreateWindow, --dual-screen handling -
// none of which applies on 3DS) normally defines, that a few still-C
// engine files read directly via `extern` (AnaglyphCalibration.c's
// gSDLWindow, Settings.c's gCurrentAntialiasingLevel). Not read/written by
// anything on 3DS beyond satisfying the link - there's no SDL window to
// point gSDLWindow at (real SDL3's 3DS backend is software-rendering-only,
// see docs/3DS_PORT_PLAN.md), no dual-screen mode, no antialiasing level
// setting exposed yet.
#include "PommeTypes.h"
#include <SDL3/SDL.h>

SDL_Window *gSDLWindow = NULL;
SDL_Window *gSDLWindow2 = NULL;
Boolean gDualScreenMode = 0;
int gCurrentAntialiasingLevel = 0;
