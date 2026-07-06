// SDL3/SDL.h - minimal 3DS stub. Only exists so real game.h's
// `#include <SDL3/SDL.h>` parses; provides just enough typedefs for
// the C headers (SDL_Window*/SDL_GLContext-typed externs, SDL_Gamepad
// forward decl in input.h) to import. Swift files that call real SDL_*
// functions still fail to resolve those symbols here (expected - those 14
// files need PlatformBackend-style routing before they'll compile for 3DS,
// tracked separately in docs/3DS_PORT_PLAN.md).
#pragma once

typedef struct SDL_Window SDL_Window;
typedef void *SDL_GLContext;
typedef struct SDL_Gamepad SDL_Gamepad;

void SDL_Log(const char *fmt, ...);
