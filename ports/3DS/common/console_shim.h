// console_shim.h - see console_shim.c.
//
// Plain scalar-typed declarations (no <3ds.h>/SDL types), same reasoning
// as picaGL_shim.h/romfs_shim.h - safe to include from game_3ds.h.
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Hooks SDL's log output so every existing SDL_Log/SDL_LogError/etc. call
// already in the engine (and DoAlert's SDL_Log) lands in the SD-card log
// file - and, under DEBUGLOG, in the bottom-screen log view too (routed
// through DebugLog). Call once, early in main(), after SDL_Init().
void Console3DS_Init(void);

// Appends one line to the SD-card log file (sdmc:/nanosaur2_log.txt,
// flushed per line so a crash can't eat it). Always compiled: it's both
// DebugLog's file sink (DEBUGLOG builds) and the SDL_Log mirror's only
// sink (non-DEBUGLOG builds, where alerts/errors still get recorded).
void DebugLogFile3DS(const char *message);

// One DebugLog line - callable from C (Swift call sites use the same
// symbol via game_3ds.h). Implemented in Swift
// (Source/System/BottomLog3DS.swift): writes the SD-card log file and
// redraws the bottom-screen log view (game font, SDL software blits).
// Only exists under -DDEBUGLOG; every call site is gated the same way.
#ifdef DEBUGLOG
void DebugLog(const char *message);
#endif

#ifdef __cplusplus
}
#endif
