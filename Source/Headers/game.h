#pragma once


		/* MY BUILD OPTIONS */

#define	VERTEXARRAYRANGES	0
#define	HQ_TERRAIN			1		// seamless terrain texturing. Requires NPOT texture support.

#if !defined(__LITTLE_ENDIAN__) && !(__BIG_ENDIAN__)
#define __LITTLE_ENDIAN__ 1
#endif

#if _DEBUG
#define SKIPFLUFF 1
#endif

		/* HEADERS */

#include <Pomme.h>
#include <SDL3/SDL.h>
#include <SDL3/SDL_opengl.h>
#include <SDL3/SDL_opengl_glext.h>
#include <math.h>
#include <stdlib.h>

#include "version.h"
#include "globals.h"
#include "structs.h"

#include "collision.h"
#include "ogl_support.h"
#include "metaobjects.h"
#include "localization.h"
#include "main.h"
#include "terrain.h"
#include "player.h"
#include "mobjtypes.h"
#include "objects.h"
#include "misc.h"
#include "sound2.h"
#include "sobjtypes.h"
#include "sprites.h"
#include "shards.h"
#include "sparkle.h"
#include "bg3d.h"
#include "effects.h"
#include "camera.h"
#include 	"input.h"
#include "skeleton.h"
#include "file.h"
#include "fences.h"
#include "splineitems.h"
#include "items.h"
#include "window.h"
#include "enemy.h"
#include "water.h"
#include "miscscreens.h"
#include	"infobar.h"
#include	"pick.h"
#include "splinemanager.h"
#include "3dmath.h"
#include "quadmesh.h"
#include "atlas.h"
#include "menu.h"

#define GAME_ASSERT(condition) do { if (!(condition)) DoFatalAlert("%s:%d: %s", __func__, __LINE__, #condition); } while(0)
#define GAME_ASSERT_MESSAGE(condition, message) do { if (!(condition)) DoFatalAlert("%s:%d: %s", __func__, __LINE__, message); } while(0)

extern	Boolean					gDisableAnimSounds;
extern	Boolean					gDisableHiccupTimer;
extern	Boolean					gDrawLensFlare;
extern	Boolean					gGameOver;
extern	Boolean					gGamePaused;
extern	Boolean					gLevelCompleted;
extern	Boolean					gMyState_Lighting;
extern	Boolean					gPlayNow;
extern	Boolean					gPlayerIsDead[MAX_PLAYERS];
extern	Boolean					gPlayingFromSavedGame;
extern	Boolean					gSkipLevelIntro;
extern	Boolean					gSongPlayingFlag;
extern	Boolean					gTimeDemo;
extern	Boolean					gUserPrefersGamepad;
extern	Boolean					gUsingVertexArrayRange;
extern	Byte					**gMapSplitMode;
extern	Byte					gActiveSplitScreenMode;
extern	Byte					gAnaglyphPass;
extern	Byte					gCurrentSplitScreenPane;
extern	Byte					gDebugMode;
extern	Byte					gNumPlayers;
extern	Byte					gTotalSides;
extern	CollisionRec			gCollisionList[];
extern	FSSpec					gDataSpec;
extern	FenceDefType			*gFenceList;
extern	GLuint					gVertexArrayRangeObjects[NUM_VERTEX_ARRAY_RANGES];
extern	LineMarkerDefType		gLineMarkerList[MAX_LINEMARKERS];
extern	MOMaterialObject		*gMostRecentMaterial;
extern	MOMaterialObject		*gSuperTileTextureObjects[MAX_SUPERTILE_TEXTURES];
extern	MOVertexArrayData		gFenceTriMeshData[MAX_FENCES][2];
extern	MOVertexArrayData		gWaterTriMeshData[];
extern	MetaObjectPtr			gBG3DGroupList[MAX_BG3D_GROUPS][MAX_OBJECTS_IN_GROUP];
extern	OGLBoundingBox			gObjectGroupBBoxList[MAX_BG3D_GROUPS][MAX_OBJECTS_IN_GROUP];
extern	OGLBoundingBox			gWaterBBox[];
extern	OGLColorRGB				gGlobalColorFilter;
extern	OGLColorRGBA			gMyState_Color;
extern	OGLMatrix4x4			gLocalToFrustumMatrix;
extern	OGLMatrix4x4			gLocalToViewMatrix;
extern	OGLMatrix4x4			gViewToFrustumMatrix;
extern	OGLMatrix4x4			gWorldToFrustumMatrix;
extern	OGLMatrix4x4			gWorldToViewMatrix;
extern	OGLMatrix4x4			gWorldToWindowMatrix[MAX_VIEWPORTS];
extern	OGLPoint2D				gCursorCoord;
extern	OGLPoint3D				gBestCheckpointCoord[MAX_PLAYERS];
extern	OGLPoint3D				gCoord;
extern	OGLRect					gLogicalRect;
extern	OGLSetupOutputType		*gGameViewInfoPtr;
extern	OGLVector3D				gDelta;
extern	OGLVector3D				gRecentTerrainNormal;
extern	OGLVector3D				gWorldSunDirection;
extern	ObjNode					*gCurrentNode;
extern	ObjNode					*gFirstNodePtr;
extern	ParticleGroupType		*gParticleGroups[MAX_PARTICLE_GROUPS];
extern	PlayerInfoType			gPlayerInfo[MAX_PLAYERS];
extern	PrefsType				gGamePrefs;
extern	Ptr						*gSuperTilePixelBuffers;			// temporary pixel buffers used to assemble seamless textures - freed after terrain is loaded
extern	SDL_GLContext			gAGLContext;
extern	SDL_Window*				gSDLWindow;
extern	SparkleType				gSparkles[MAX_SPARKLES];
extern	SpriteType				*gSpriteGroupList[MAX_SPRITE_GROUPS];
extern	SuperTileItemIndexType	**gSuperTileItemIndexGrid;
extern	SuperTileMemoryType		gSuperTileMemoryList[MAX_SUPERTILES];
extern	SuperTileStatus			**gSuperTileStatusGrid;
extern	TerrainItemEntryType 	*gMasterItemList;
extern	WaterDefType			**gWaterListHandle;
extern	WaterDefType			*gWaterList;
extern	const InputBinding		kDefaultInputBindings[NUM_CONTROL_NEEDS];
extern	float					**gMapYCoords;
extern	float					**gMapYCoordsOriginal;
extern	float					**gVertexShading;
extern	float					gAnaglyphEyeSeparation;
extern	float					gAnaglyphFocallength;
extern	float					gAutoFadeEndDist;
extern	float					gAutoFadeRange_Frac;
extern	float					gAutoFadeStartDist;
extern	float					gAutoFireDelay[MAX_PLAYERS];
extern	float					gBestCheckpointAim[MAX_PLAYERS];
extern	float					gCurrentMaxSpeed[MAX_PLAYERS];
extern	float					gCurrentPaneAspectRatio;
extern	float					gDeathTimer[MAX_PLAYERS];
extern	float					gFramesPerSecond;
extern	float					gFramesPerSecondFrac;
extern	float					gGammaFadeFrac;
extern	float					gGlobalTransparency;
extern	float					gLoadingThermoPercent;
extern	float					gMapToUnitValue;
extern	float					gMapToUnitValueFrac;
extern	float					gObjectGroupBSphereList[MAX_BG3D_GROUPS][MAX_OBJECTS_IN_GROUP];
extern	float					gRaceReadySetGoTimer;
extern	float					gTargetMaxSpeed[MAX_PLAYERS];
extern	float					gTerrainPolygonSize;
extern	float					gTerrainSuperTileUnitSize;
extern	float					gTerrainSuperTileUnitSizeFrac;
extern	int						gCurrentAntialiasingLevel;
extern	int						gGameWindowHeight;
extern	int						gGameWindowWidth;
extern	int						gMaxEnemies;
extern	int						gMenuOutcome;
extern	int						gNumEnemies;
extern	int						gNumLineMarkers;
extern	int						gNumObjectNodes;
extern	int						gNumObjectNodesPeak;
extern	int						gNumObjectsInBG3DGroupList[MAX_BG3D_GROUPS];
extern	int						gNumPointers;
extern	int						gNumSparkles;
extern	int						gNumSpritesInGroupList[MAX_SPRITE_GROUPS];
extern	int						gNumTerrainItems;
extern	int						gNumWorldCalcsThisFrame;
extern	int						gPolysThisFrame;
extern	int 					gSuperTileActiveRange;
extern	long					gNumFences;
extern	long					gNumSplines;
extern	long					gNumSuperTilesDeep;
extern	long					gNumSuperTilesWide;
extern	long					gNumUniqueSuperTiles;
extern	long					gNumWaterPatches;
extern	long					gPrefsFolderDirID;
extern	long					gRAMAlloced;
extern	long					gTerrainTileDepth;
extern	long					gTerrainTileWidth;
extern	long					gTerrainUnitDepth;
extern	long					gTerrainUnitWidth;
extern	short					**gSuperTileTextureGrid;
extern	short					gBestCheckpointNum[MAX_PLAYERS];
extern	short					gCurrentSong;
extern	short					gLevelNum;
extern	short					gNumActiveParticleGroups;
extern	short					gNumCollisions;
extern	short					gNumFencesDrawn;
extern	short					gNumSuperTilesDrawn;
extern	short					gNumWaterDrawn;
extern	short					gPrefsFolderVRefNum;
extern	short					gVSMode;
extern	signed char				gNumEnemyOfKind[NUM_ENEMY_KINDS];
extern	uint32_t				gGameFrameNum;
extern	uint32_t				gGlobalMaterialFlags;
extern	uint32_t				gTerrainPolygonSizeInt;
extern	uint32_t 				gAutoFadeStatusBits;
