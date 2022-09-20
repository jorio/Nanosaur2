//
// Terrain.h
//

#ifndef TERRAIN_H
#define TERRAIN_H

#include "main.h"


enum
{
	MAP_ITEM_MYSTARTCOORD		= 0,			// map item # for my start coords
	MAP_ITEM_EGG				= 3
};

#define	ILLEGAL_TERRAIN_Y	-10000.0f			// returned from GetTerrainY if no terrain is loaded

		/* SUPER TILE MODES */

enum
{
	SUPERTILE_MODE_FREE,
	SUPERTILE_MODE_USED
};

#define	DEFAULT_TERRAIN_SCALE		210.0f											// size of a polygon
#define	SUPERTILE_TEXMAP_SIZE		256												// the width & height of a supertile's texture

#define	SUPERTILE_SIZE				8  												// size of a super-tile / terrain object zone

#define	OREOMAP_TILE_SIZE			(SUPERTILE_TEXMAP_SIZE/SUPERTILE_SIZE)			// pixel w/h of texture tile

#define	NUM_TRIS_IN_SUPERTILE		(SUPERTILE_SIZE * SUPERTILE_SIZE * 2)			// 2 triangles per tile
#define	NUM_VERTICES_IN_SUPERTILE	((SUPERTILE_SIZE+1)*(SUPERTILE_SIZE+1))			// # vertices in a supertile

#define	MAX_SUPERTILE_ACTIVE_RANGE	9

#define	SUPERTILE_DIST_WIDE			(gSuperTileActiveRange*2)
#define	SUPERTILE_DIST_DEEP			(gSuperTileActiveRange*2)

								// # visible supertiles * 2 players * 2 buffers
								// We need the x2 buffer because we dont free unused supertiles
								// until after we've allocated new supertiles, so we'll always
								// need more supertiles than are actually ever used.

#define	MAX_SUPERTILES			((MAX_SUPERTILE_ACTIVE_RANGE*2 * MAX_SUPERTILE_ACTIVE_RANGE*2)*MAX_SPLITSCREENS * 2)	// the final *2 is because the old supertiles are not deleted until
																											// after new ones are created, thus we need some extas - worst case
																											// scenario is twice as many.


#define	MAX_TERRAIN_WIDTH		400
#define	MAX_TERRAIN_DEPTH		400

#define	MAX_SUPERTILES_WIDE		(MAX_TERRAIN_WIDTH/SUPERTILE_SIZE)
#define	MAX_SUPERTILES_DEEP		(MAX_TERRAIN_DEPTH/SUPERTILE_SIZE)


#define	MAX_SUPERTILE_TEXTURES	(MAX_SUPERTILES_WIDE*MAX_SUPERTILES_DEEP)


//=====================================================================


struct SuperTileMemoryType
{
	Byte				hiccupTimer;							// # frames to skip for use
	Byte				mode;									// free, used, etc.
	float				x,z,y;									// world coords
	long				left,back;								// integer coords of back/left corner
	long				tileRow,tileCol;						// tile row/col of the start of this supertile
	MOMaterialObject	*texture;								// refs to materials
	MOVertexArrayData	*meshData;								// mesh's data for the supertile
	OGLBoundingBox		bBox;									// bounding box
};
typedef struct SuperTileMemoryType SuperTileMemoryType;


typedef struct
{
	u_short		numItems;
	u_short		itemIndex;
}SuperTileItemIndexType;


#define	BOTTOMLESS_PIT_Y	-100000.0f				// to identify a blank area on Cloud Level


		/* TERRAIN ITEM FLAGS */

enum
{
	ITEM_FLAGS_INUSE	=	(1),
	ITEM_FLAGS_USER1	=	(1<<1),
	ITEM_FLAGS_USER2	=	(1<<2),
	ITEM_FLAGS_USER3	=	(1<<3)
};


enum
{
	SPLIT_BACKWARD = 0,
	SPLIT_FORWARD,
	SPLIT_ARBITRARY
};


typedef	struct
{
	u_short		supertileIndex;
	u_char		statusFlags;
	u_char		playerHereFlags;
}SuperTileStatus;

enum									// statusFlags
{
	SUPERTILE_IS_DEFINED			=	1,
	SUPERTILE_IS_USED_THIS_FRAME	=	(1<<1)
};



#define	MAX_LINEMARKERS	100

typedef struct
{
	short	unused;
	short	infoBits;

	float	x[2],z[2];			// the two endpoints
}LineMarkerDefType;



		/* EXTERNS */

extern	float gTerrainSuperTileUnitSize;
extern	int						gNumLineMarkers;
extern	LineMarkerDefType		gLineMarkerList[MAX_LINEMARKERS];
extern	TerrainItemEntryType 	*gMasterItemList;
extern	int						gNumTerrainItems;
extern  uint32_t			gTerrainPolygonSizeInt;
extern  long			gTerrainTileWidth,gTerrainTileDepth;
extern  long			gTerrainUnitWidth,gTerrainUnitDepth;
extern  long			gNumSuperTilesDeep,gNumSuperTilesWide, gNumUniqueSuperTiles;

//=====================================================================


void SetTerrainScale(int polygonSize);

void CreateSuperTileMemoryList(OGLSetupOutputType *setupInfo);
void DisposeSuperTileMemoryList(void);
extern 	void DisposeTerrain(void);
extern	void GetSuperTileInfo(long x, long z, long *superCol, long *superRow, long *tileCol, long *tileRow);
extern	void InitTerrainManager(void);
float	GetTerrainY(float x, float z);
float	GetMinTerrainY(float x, float z, short group, short type, float scale);
void InitCurrentScrollSettings(void);

extern 	void BuildTerrainItemList(void);
void AddTerrainItemsOnSuperTile(long row, long col);
extern 	Boolean TrackTerrainItem(ObjNode *theNode);
void DrawTerrain(ObjNode *theNode, const OGLSetupOutputType *setupInfo);
Boolean SeeIfCoordsOutOfRange(float x, float z);
void InitSuperTileGrid(void);
void RotateOnTerrain(ObjNode *theNode, float yOffset, OGLVector3D *surfaceNormal);
void RotateOnTerrain_WideArea(ObjNode *theNode, float yOffset, float radius);
void DoPlayerTerrainUpdate(void);
void CalcTileNormals(long row, long col, OGLVector3D *n1, OGLVector3D *n2);
void CalcTileNormals_NotNormalized(long row, long col, OGLVector3D *n1, OGLVector3D *n2);
void CalculateSplitModeMatrix(void);
void CalculateSupertileVertexNormals(MOVertexArrayData	*meshData, long	startRow, long startCol);

void DoItemShadowCasting(OGLSetupOutputType *setupInfo);
Boolean SeeIfCrossedLineMarker(ObjNode *theNode, long *whichLine);


#endif






