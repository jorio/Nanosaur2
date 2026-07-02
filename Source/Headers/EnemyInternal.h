#pragma once

#include "enemy.h"

// Swift can't dynamically index a fixed-size C array (it imports as a
// tuple); hand out an element pointer instead.
static inline signed char* GetNumEnemyOfKindSlot(int kind) { return &gNumEnemyOfKind[kind]; }

// gCollisionList is declared `extern CollisionRec gCollisionList[];` (an
// incomplete array type), which Swift's importer rejects outright
// ("invalid declaration") rather than decaying to a pointer. Route
// through a shim instead.
static inline CollisionRec* GetCollisionListEntry(int i) { return &gCollisionList[i]; }

// Same incomplete-array-type issue as gCollisionList above.
static inline OGLBoundingBox* GetWaterBBoxEntry(int i) { return &gWaterBBox[i]; }
