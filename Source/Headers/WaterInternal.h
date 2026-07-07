#pragma once

#include "game.h"
#include "water.h"

// Casting WaterDefType** to Handle (= Ptr* = char**) is a trivial reinterpret
// in C, but fighting Swift's raw-pointer rebinding APIs for a one-off cast
// isn't worth it - do the cast here instead.
static inline void DisposeWaterListHandle(WaterDefType * _Nullable * _Nonnull h) { DisposeHandle((Handle) h); }
