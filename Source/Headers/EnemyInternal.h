#pragma once

#include "enemy.h"

// gCollisionList is declared `extern CollisionRec gCollisionList[];` (an
// incomplete array type), which Swift's importer rejects outright
// ("invalid declaration") rather than decaying to a pointer. Route
// through a shim instead.
static inline CollisionRec* GetCollisionListEntry(int i) { return &gCollisionList[i]; }

// Same incomplete-array-type issue as gCollisionList above.
static inline OGLBoundingBox* GetWaterBBoxEntry(int i) { return &gWaterBBox[i]; }

// Compound macros referencing other macros/enum constants aren't imported by
// Clang's macro-constant importer; re-expose them as plain typed constants.
static const uint32_t SwDEFAULT_ENEMY_COLLISION_CTYPES = DEFAULT_ENEMY_COLLISION_CTYPES;
static const uint32_t SwDEATH_ENEMY_COLLISION_CTYPES = DEATH_ENEMY_COLLISION_CTYPES;
