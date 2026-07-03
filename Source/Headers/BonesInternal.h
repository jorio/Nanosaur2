#pragma once

#include "bg3d.h"

// gBG3DContainerList is defined in bg3d.c (real size MAX_BG3D_GROUPS) but
// only ever declared locally as an incomplete `extern T arr[];` inside
// Bones.c — not in any shared header. Swift's importer rejects incomplete
// array declarations outright ("invalid declaration"), so give it a
// proper extern here plus an accessor, matching the EnemyInternal.h
// gCollisionList/gWaterBBox precedent.
extern BG3DFileContainer *gBG3DContainerList[];

static inline MetaObjectPtr GetBG3DContainerRoot(int group) { return gBG3DContainerList[group]->root; }

static inline BG3DFileContainer* _Nullable GetBG3DContainer(int group) { return gBG3DContainerList[group]; }
static inline void SetBG3DContainer(int group, BG3DFileContainer* _Nullable value) { gBG3DContainerList[group] = value; }
