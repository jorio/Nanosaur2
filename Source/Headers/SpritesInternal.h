#pragma once

#include "sprites.h"

// Swift can't dynamically index fixed-size C arrays (they import as
// tuples); hand out accessors instead.
static inline SpriteType* GetSpriteGroupList(int groupNum) { return gSpriteGroupList[groupNum]; }
static inline void SetSpriteGroupList(int groupNum, SpriteType* v) { gSpriteGroupList[groupNum] = v; }
static inline int GetNumSpritesInGroup(int groupNum) { return gNumSpritesInGroupList[groupNum]; }
static inline void SetNumSpritesInGroup(int groupNum, int v) { gNumSpritesInGroupList[groupNum] = v; }
