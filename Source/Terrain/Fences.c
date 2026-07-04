/**********************/
/*   	FENCES.C      */
/**********************/

// All function implementations are now in Fences.swift. gNumFences and
// gFenceList stay here because Pick.swift and File.swift (already ported)
// read/write them directly via `extern`. gFenceTriMeshData stays because
// PickInternal.h's GetFenceTriMeshDataEntry shim references it directly.
// gNumFencesDrawn stays too since it's `extern`'d in game.h.

#include "game.h"

long			gNumFences = 0;
short			gNumFencesDrawn;
FenceDefType	*gFenceList = nil;

MOVertexArrayData				gFenceTriMeshData[MAX_FENCES][2];
