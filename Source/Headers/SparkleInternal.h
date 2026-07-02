#pragma once

#include "sparkle.h"

// Swift can't dynamically index fixed-size C arrays (they import as
// tuples); hand out element pointers instead.
static inline SparkleType* GetSparkleSlot(int i) { return &gSparkles[i]; }
static inline SpriteType* _Nullable GetSpriteGroupPtr(int groupNum) { return gSpriteGroupList[groupNum]; }
