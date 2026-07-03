/**********************/
/*   	WATER.C      */
/**********************/

// All function implementations are now in Water.swift. gNumWaterPatches,
// gNumWaterDrawn, gWaterListHandle, gWaterList, gWaterTriMeshData, and
// gWaterBBox stay here because Pick.c, OGL_Support.c, Terrain.c,
// Player_Terrain.c, and EnemyInternal.h (still unported) read/write them
// directly by name via `extern`.

#include "game.h"

#define MAX_WATER 60

long			gNumWaterPatches = 0;
short			gNumWaterDrawn;
WaterDefType	**gWaterListHandle = nil;
WaterDefType	*gWaterList;

MOVertexArrayData				gWaterTriMeshData[MAX_WATER];
OGLBoundingBox					gWaterBBox[MAX_WATER];
