#pragma once

#include "sprites.h"

#pragma clang assume_nonnull begin

// Swift can't dynamically index fixed-size C arrays (they import as
// tuples); hand out accessors instead.
static inline SpriteType* _Nullable GetSpriteGroupList(int groupNum) { return gSpriteGroupList[groupNum]; }
static inline void SetSpriteGroupList(int groupNum, SpriteType* _Nullable v) { gSpriteGroupList[groupNum] = v; }
static inline int GetNumSpritesInGroup(int groupNum) { return gNumSpritesInGroupList[groupNum]; }
static inline void SetNumSpritesInGroup(int groupNum, int v) { gNumSpritesInGroupList[groupNum] = v; }

#pragma clang assume_nonnull end
