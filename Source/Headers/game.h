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

#include "SwiftAnnotations.h"
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
#include	"pick.h"
#include "splinemanager.h"
#include "3dmath.h"
#include "atlas.h"
#include "menu.h"

#define GAME_ASSERT(condition) do { if (!(condition)) DoFatalAlert("%s:%d: %s", __func__, __LINE__, #condition); } while(0)
#define GAME_ASSERT_MESSAGE(condition, message) do { if (!(condition)) DoFatalAlert("%s:%d: %s", __func__, __LINE__, message); } while(0)

extern	Boolean					gDisableAnimSounds;
extern	Boolean					gDualScreenMode;
extern	Boolean					gGameOver;
extern	Boolean					gGamePaused;
extern	Boolean					gLevelCompleted;
extern	Boolean					gPlayNow;
extern	Boolean					gPlayingFromSavedGame;
extern	Boolean					gSkipLevelIntro;
extern	Boolean					gTimeDemo;
extern	Boolean					gUserPrefersGamepad;
extern	Boolean					gUsingVertexArrayRange;
extern	Byte					gDebugMode;
extern	Byte					gTotalSides;
extern	CollisionRec			gCollisionList[];
extern	FSSpec					gDataSpec;
extern	FenceDefType			*gFenceList;
extern	GLuint					gVertexArrayRangeObjects[NUM_VERTEX_ARRAY_RANGES];
extern	MOMaterialObject		*gMostRecentMaterial;
extern	MOVertexArrayData		gFenceTriMeshData[MAX_FENCES][2];
extern	OGLColorRGB				gGlobalColorFilter;
extern	OGLPoint2D				gCursorCoord;
extern	OGLPoint3D				gBestCheckpointCoord[MAX_PLAYERS];
extern	OGLPoint3D				gCoord;
extern	OGLRect					gLogicalRect;
extern	OGLSetupOutputType		*gGameViewInfoPtr;
extern	OGLVector3D				gDelta;
extern	OGLVector3D				gWorldSunDirection;
extern	ObjNode					*gCurrentNode;
extern	ObjNode					*gFirstNodePtr;
extern	ParticleGroupType		*gParticleGroups[MAX_PARTICLE_GROUPS];
extern	PrefsType				gGamePrefs;
extern	SDL_Window*				gSDLWindow;
extern	SDL_Window*				gSDLWindow2;
extern	SparkleType				gSparkles[MAX_SPARKLES];
extern	SpriteType				*gSpriteGroupList[MAX_SPRITE_GROUPS];
extern	const InputBinding		kDefaultInputBindings[NUM_CONTROL_NEEDS];
extern	float					gAutoFadeEndDist;
extern	float					gAutoFadeRange_Frac;
extern	float					gAutoFadeStartDist;
extern	float					gAutoFireDelay[MAX_PLAYERS];
extern	float					gBestCheckpointAim[MAX_PLAYERS];
extern	float					gCurrentMaxSpeed[MAX_PLAYERS];
extern	float					gFramesPerSecond;
extern	float					gFramesPerSecondFrac;
extern	float					gGammaFadeFrac;
extern	float					gGlobalTransparency;
extern	float					gLoadingThermoPercent;
extern	float					gRaceReadySetGoTimer;
extern	float					gTargetMaxSpeed[MAX_PLAYERS];
extern	int						gCurrentAntialiasingLevel;
extern	int						gGameWindowHeight;
extern	int						gGameWindowWidth;
extern	int						gMenuOutcome;
extern	int						gNumObjectNodes;
extern	int						gNumObjectNodesPeak;
extern	int						gNumPointers;
extern	int						gNumSparkles;
extern	int						gNumSpritesInGroupList[MAX_SPRITE_GROUPS];
extern	int						gNumWorldCalcsThisFrame;
extern	long					gNumFences;
extern	long					gPrefsFolderDirID;
extern	long					gRAMAlloced;
extern	short					gBestCheckpointNum[MAX_PLAYERS];
extern	short					gLevelNum;
extern	short					gNumActiveParticleGroups;
extern	short					gNumCollisions;
extern	short					gNumFencesDrawn;
extern	short					gNumSuperTilesDrawn;
extern	short					gPrefsFolderVRefNum;
extern	uint32_t				gGameFrameNum;
extern	uint32_t				gGlobalMaterialFlags;
extern	uint32_t 				gAutoFadeStatusBits;
