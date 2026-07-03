/****************************/
/*   	BG3D.C 				*/
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/

// All function implementations are now in Bg3d.swift. The globals below
// stay here because Items.c, Terrain.c, Player.c (still unported) and
// Bones.swift read/write them directly via `extern`.

#include "game.h"

BG3DFileContainer		*gBG3DContainerList[MAX_BG3D_GROUPS];
MetaObjectPtr			gBG3DGroupList[MAX_BG3D_GROUPS][MAX_OBJECTS_IN_GROUP];		// ILLEGAL references!!!
int						gNumObjectsInBG3DGroupList[MAX_BG3D_GROUPS];
OGLBoundingBox			gObjectGroupBBoxList[MAX_BG3D_GROUPS][MAX_OBJECTS_IN_GROUP];
float					gObjectGroupBSphereList[MAX_BG3D_GROUPS][MAX_OBJECTS_IN_GROUP];
