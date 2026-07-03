#pragma once

#include "game.h"
#include "water.h"

// gWaterTriMeshData is declared `extern MOVertexArrayData gWaterTriMeshData[];`
// (an incomplete array type), which Swift's importer rejects outright -
// same issue as gCollisionList/gWaterBBox (see EnemyInternal.h). Route
// through a shim instead.
static inline MOVertexArrayData* _Nonnull GetWaterTriMeshDataEntry(int i) { return &gWaterTriMeshData[i]; }

// Casting WaterDefType** to Handle (= Ptr* = char**) is a trivial reinterpret
// in C, but fighting Swift's raw-pointer rebinding APIs for a one-off cast
// isn't worth it - do the cast here instead.
static inline void DisposeWaterListHandle(WaterDefType * _Nullable * _Nonnull h) { DisposeHandle((Handle) h); }
