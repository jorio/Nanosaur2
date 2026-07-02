#pragma once

#include "globals.h"

// General-purpose C shims for Swift interop, shared across ported files.
// Clang's macro-constant importer can only fold simple numeric literals;
// compound macros that reference other macros/enum constants aren't
// imported, so we re-expose them here as plain typed constants.

static const float SwPI2 = PI2;
static const unsigned short SwALL_SOLID_SIDES = ALL_SOLID_SIDES;

static inline void SwGameAssertMessage(bool cond, const char* msg) { if (!cond) DoFatalAlert("%s", msg); }

// SDL_Log is variadic, which Swift can't call directly.
static inline void SwLog(const char* msg) { SDL_Log("%s", msg); }

// DoAlert is variadic, which Swift can't call directly.
static inline void SwAlert(const char* msg) { DoAlert("%s", msg); }

// gPlayerInfo is a fixed-size C array (`PlayerInfoType gPlayerInfo[MAX_PLAYERS]`),
// which Swift imports as a non-subscriptable tuple. Hand out an element
// pointer instead so it can be dynamically indexed by playerNum.
static inline PlayerInfoType* GetPlayerInfoEntry(int i) { return &gPlayerInfo[i]; }

// Same tuple-import issue as gPlayerInfo above.
static inline Boolean GetPlayerIsDead(int i) { return gPlayerIsDead[i]; }

// gChannelInfo is declared `extern ChannelInfoType gChannelInfo[];` (an
// incomplete array type), which Swift's importer rejects outright. Route
// through a shim instead, matching GetCollisionListEntry in EnemyInternal.h.
static inline ChannelInfoType* GetChannelInfoEntry(int i) { return &gChannelInfo[i]; }
