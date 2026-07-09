//
// mobjtypes.h
//

#ifndef __MOBJT
#define __MOBJT

// MODEL_GROUP_SKELETONBASE is used by bg3d.h's MAX_BG3D_GROUPS macro
// (`((int)MODEL_GROUP_SKELETONBASE+(int)MAX_SKELETON_TYPES)`), which sizes
// real extern-global arrays in Source/3D/bg3d.c - this enum block must stay
// C-visible. Every other enum that used to live in this file (GLOBAL/
// PLAYER PARTS/WEAPONS/LEVEL1-3/LEVEL INTRO ObjType indices, ~186
// constants) had zero C usage (verified 2026-07-07) and moved to native
// Swift constants in Source/System/MobjTypes.swift.

enum
{
	MODEL_GROUP_GLOBAL		=	0,
	MODEL_GROUP_LEVELSPECIFIC =	1,
	MODEL_GROUP_LEVELINTRO =	2,
	MODEL_GROUP_WEAPONS		 = 	3,
	MODEL_GROUP_PLAYER		 = 	4,

	MODEL_GROUP_SKELETONBASE				// skeleton files' models are attached here
};

#endif
