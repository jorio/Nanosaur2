#pragma once

#include "globals.h"

// Only pulls in the declarations (no STB_IMAGE_IMPLEMENTATION defined here),
// so this doesn't duplicate the implementation compiled into stb_image.c.
#include "stb_image.h"

// General-purpose C shims for Swift interop, shared across ported files.
// Clang's macro-constant importer can only fold simple numeric literals;
// compound macros that reference other macros/enum constants aren't
// imported, so we re-expose them here as plain typed constants.

static const float SwPI2 = PI2;
static const unsigned short SwALL_SOLID_SIDES = ALL_SOLID_SIDES;
static const int SwMAX_BG3D_GROUPS = MAX_BG3D_GROUPS;


// SDL_Log is variadic, which Swift can't call directly.
static inline void SwLog(const char* msg) { SDL_Log("%s", msg); }

// DoAlert is variadic, which Swift can't call directly.
static inline void SwAlert(const char* msg) { DoAlert("%s", msg); }

// DoFatalAlert is variadic, which Swift can't call directly. This is the
// single C sink behind every Swift-side fatal/assert helper (SwFatal,
// SwFatalAlert, SwGameAssert, SwGameAssertMessage - SwiftSupport.swift),
// which append #fileID:#line #function before funneling the finished
// string here.
static inline void SwFatalRaw(const char* msg) { DoFatalAlert("%s", msg); }

