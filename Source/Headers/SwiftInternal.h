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

static inline void SwGameAssertMessage(bool cond, const char* msg) { if (!cond) DoFatalAlert("%s", msg); }

// SDL_Log is variadic, which Swift can't call directly.
static inline void SwLog(const char* msg) { SDL_Log("%s", msg); }

// DoAlert is variadic, which Swift can't call directly.
static inline void SwAlert(const char* msg) { DoAlert("%s", msg); }

// DoFatalAlert is variadic, which Swift can't call directly. Callers that
// need dynamic content should build the string with Swift interpolation
// first, then pass the finished string here.
static inline void SwFatalAlert(const char* msg) { DoFatalAlert("%s", msg); }

// gPlayerInfo is a fixed-size C array (`PlayerInfoType gPlayerInfo[MAX_PLAYERS]`),
// which Swift imports as a non-subscriptable tuple. Hand out an element
// pointer instead so it can be dynamically indexed by playerNum.
static inline PlayerInfoType* GetPlayerInfoEntry(int i) { return &gPlayerInfo[i]; }

// Same tuple-import issue as gPlayerInfo above.
static inline Boolean GetPlayerIsDead(int i) { return gPlayerIsDead[i]; }

// gSuperTileTextureObjects is a fixed-size C array, which Swift imports as a
// non-subscriptable tuple. Hand out an element pointer instead.
static inline MOMaterialObject** GetSuperTileTextureObjectSlot(int i) { return &gSuperTileTextureObjects[i]; }
