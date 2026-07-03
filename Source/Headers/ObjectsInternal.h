#pragma once

#include "objects.h"

// Swift can't dynamically index fixed-size (or 2D fixed-size) C arrays
// (they import as tuples); hand out accessors instead.
static inline int GetNumObjectsInBG3DGroup(int group) { return gNumObjectsInBG3DGroupList[group]; }
static inline void SetNumObjectsInBG3DGroup(int group, int value) { gNumObjectsInBG3DGroupList[group] = value; }
static inline MetaObjectPtr _Nullable GetBG3DGroupObject(int group, int type) { return gBG3DGroupList[group][type]; }
static inline void SetBG3DGroupObject(int group, int type, MetaObjectPtr _Nullable value) { gBG3DGroupList[group][type] = value; }
static inline OGLBoundingBox GetObjectGroupBBox(int group, int type) { return gObjectGroupBBoxList[group][type]; }
static inline void SetObjectGroupBBox(int group, int type, OGLBoundingBox value) { gObjectGroupBBoxList[group][type] = value; }
static inline float GetObjectGroupBSphere(int group, int type) { return gObjectGroupBSphereList[group][type]; }
static inline void SetObjectGroupBSphere(int group, int type, float value) { gObjectGroupBSphereList[group][type] = value; }
