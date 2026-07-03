#pragma once

#include "game.h"
#include "pick.h"

// Swift can't dynamically index fixed-size C arrays (they import as
// tuples); hand out accessors instead.

static inline SuperTileMemoryType* GetSuperTileMemoryEntry(int i) { return &gSuperTileMemoryList[i]; }

static inline MOVertexArrayData* GetFenceTriMeshDataEntry(int fenceIndex, int side) { return &gFenceTriMeshData[fenceIndex][side]; }
