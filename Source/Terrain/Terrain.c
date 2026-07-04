/****************************/
/*     TERRAIN.C           	*/
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/

// All function implementations are now in Terrain.swift (and Terrain2.c's
// in Terrain2.swift). Most of the globals below stay here because many
// other already-ported and still-unported files read/write them directly
// via `extern` (including PickInternal.h's GetSuperTileMemoryEntry shim
// for gSuperTileMemoryList).

#include "game.h"

float			gTerrainPolygonSize;
uint32_t			gTerrainPolygonSizeInt;
float			gTerrainSuperTileUnitSize, gTerrainSuperTileUnitSizeFrac;
float			gMapToUnitValue, gMapToUnitValueFrac;
int				gSuperTileActiveRange = 4;

Boolean			gDisableHiccupTimer = false;

SuperTileStatus	**gSuperTileStatusGrid = nil;				// supertile status grid

long			gTerrainTileWidth,gTerrainTileDepth;			// width & depth of terrain in tiles
long			gTerrainUnitWidth,gTerrainUnitDepth;			// width & depth of terrain in world units (see gTerrainPolygonSize)

long			gNumUniqueSuperTiles;
short		 	**gSuperTileTextureGrid = nil;			// 2d array
Ptr				*gSuperTilePixelBuffers = nil;			// temporary pixel buffers used to assemble seamless textures - freed after terrain is loaded

float			**gVertexShading = nil;					// vertex shading grid

MOMaterialObject	*gSuperTileTextureObjects[MAX_SUPERTILE_TEXTURES];

long			gNumSuperTilesDeep,gNumSuperTilesWide;	  		// dimensions of terrain in terms of supertiles

SuperTileMemoryType	gSuperTileMemoryList[MAX_SUPERTILES];

OGLVector3D		gRecentTerrainNormal;							// from _Planar

// Terrain2.c's globals - also shared here since many other files reference
// them directly via `extern` (game.h).

int						gNumTerrainItems;
TerrainItemEntryType 	*gMasterItemList = nil;

float					**gMapYCoords = nil;			// 2D array of map vertex y coords
float					**gMapYCoordsOriginal = nil;	// copy of gMapYCoords data as it was when file was loaded
Byte					**gMapSplitMode = nil;

SuperTileItemIndexType	**gSuperTileItemIndexGrid = nil;

int						gNumLineMarkers;
LineMarkerDefType		gLineMarkerList[MAX_LINEMARKERS];
