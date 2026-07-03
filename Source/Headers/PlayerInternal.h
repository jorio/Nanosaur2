#pragma once

#include "game.h" // already pulls in camera.h; camera.h has no #pragma once, so don't include it again here
#include "player.h"

// Swift can't dynamically index fixed-size C arrays (they import as
// tuples); hand out accessors instead.

static inline float GetDeathTimer(int i) { return gDeathTimer[i]; }
static inline void SetDeathTimer(int i, float v) { gDeathTimer[i] = v; }

// GetPlayerIsDead already declared in SwiftInternal.h.
static inline void SetPlayerIsDead(int i, Boolean v) { gPlayerIsDead[i] = v; }

static inline OGLPoint3D GetBestCheckpointCoord(int i) { return gBestCheckpointCoord[i]; }
static inline void SetBestCheckpointCoord(int i, OGLPoint3D v) { gBestCheckpointCoord[i] = v; }

static inline float GetBestCheckpointAim(int i) { return gBestCheckpointAim[i]; }
static inline void SetBestCheckpointAim(int i, float v) { gBestCheckpointAim[i] = v; }

static inline float GetCurrentMaxSpeed(int i) { return gCurrentMaxSpeed[i]; }
static inline void SetCurrentMaxSpeed(int i, float v) { gCurrentMaxSpeed[i] = v; }

static inline float GetTargetMaxSpeed(int i) { return gTargetMaxSpeed[i]; }
static inline void SetTargetMaxSpeed(int i, float v) { gTargetMaxSpeed[i] = v; }

static inline Boolean GetCameraInDeathDiveMode(int i) { return gCameraInDeathDiveMode[i]; }
static inline void SetCameraInDeathDiveMode(int i, Boolean v) { gCameraInDeathDiveMode[i] = v; }

static inline float GetAutoFireDelay(int i) { return gAutoFireDelay[i]; }
static inline void SetAutoFireDelay(int i, float v) { gAutoFireDelay[i] = v; }

static inline short GetBestCheckpointNum(int i) { return gBestCheckpointNum[i]; }
static inline void SetBestCheckpointNum(int i, short v) { gBestCheckpointNum[i] = v; }
