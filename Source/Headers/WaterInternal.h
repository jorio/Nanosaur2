#pragma once

#include "game.h"
#include "water.h"

// gWaterListHandle is a permanent AllocPtrClear'd handle-shaped allocation
// (double indirection) built in File.swift's readDataFromPlayfieldFile, not
// a Pomme Handle - so both levels are freed with SafeDisposePtr instead of
// Pomme's DisposeHandle. (Fighting Swift's raw-pointer rebinding APIs for a
// one-off cast isn't worth it - do this in C instead.)
static inline void DisposeWaterListHandle(WaterDefType * _Nullable * _Nonnull h) {
	SafeDisposePtr((void *) *h); // free the water-data buffer
	SafeDisposePtr((void *) h);  // free the handle-indirection buffer
}
