#pragma once

#include "player.h"

// Swift can't dynamically index fixed-size C arrays (they import as
// tuples); hand out element pointers instead.
static inline PlayerInfoType* GetPlayerInfoPtr(int i) { return &gPlayerInfo[i]; }
static inline LineMarkerDefType* GetLineMarkerPtr(int i) { return &gLineMarkerList[i]; }
