// console_shim.h - see console_shim.c.
//
// Plain scalar-typed declaration (no <3ds.h>/SDL types), same reasoning as
// picaGL_shim.h/romfs_shim.h: this needs libctru's console API, which
// can't coexist with Pomme's Handle typedef in the same translation unit
// (see game_3ds.h's comment on hidScanInput for the full explanation).
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Sets up libctru's console on the bottom screen (independent of picaGL,
// which owns the top screen) and hooks it up as an SDL log output function,
// so every existing SDL_Log/SDL_LogError/etc. call already in the engine
// (and DoAlert's SDL_Log) is mirrored live to the bottom screen as a
// scrolling console - not just fatal errors. Call once, early in main(),
// after SDL_Init(). Safe to call before or after Fatal3DS_Print's own
// consoleInit() call - consoleInit() is idempotent, just re-takes the same
// framebuffer.
void Console3DS_Init(void);

// Prints one line to the bottom-screen console immediately (bypassing
// SDL_Log) - callable from Swift, which can't call variadic C functions.
// Safe to call before Console3DS_Init() too (lazily initializes the
// console on first use), so Swift boot-sequence checkpoints can start
// before main.cpp's own Console3DS_Init() call if ever needed.
void Debug3DS_Log(const char *message);

#ifdef __cplusplus
}
#endif
