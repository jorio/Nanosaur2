#pragma once

#include "objects.h"

// Swift can't dynamically index fixed-size (or 2D fixed-size) C arrays
// (they import as tuples); hand out accessors instead.
static inline int GetNumObjectsInBG3DGroup(int group) { return gNumObjectsInBG3DGroupList[group]; }
static inline MetaObjectPtr _Nullable GetBG3DGroupObject(int group, int type) { return gBG3DGroupList[group][type]; }
static inline OGLBoundingBox GetObjectGroupBBox(int group, int type) { return gObjectGroupBBoxList[group][type]; }
static inline float GetObjectGroupBSphere(int group, int type) { return gObjectGroupBSphereList[group][type]; }
