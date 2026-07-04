#pragma once

#include "game.h" // already pulls in camera.h; camera.h has no #pragma once, so don't include it again here
#include "infobar.h"

// Swift can't dynamically index fixed-size (or incomplete) C arrays (they
// import as tuples, or are rejected outright); hand out accessors instead.

static inline Byte GetCameraMode(int i) { return gCameraMode[i]; }
static inline void SetCameraMode(int i, Byte v) { gCameraMode[i] = v; }

static inline OGLMatrix4x4* _Nonnull GetWorldToWindowMatrixEntry(int i) { return &gWorldToWindowMatrix[i]; }
