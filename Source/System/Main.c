/****************************/
/*    NANOSAUR 2 - MAIN 	*/
/* By Brian Greenstone      */
/* (c)2003 Pangea Software  */
/* (c)2022 Iliyas Jorio     */
/****************************/

// All function implementations are now in Main.swift. Nearly every global
// below stays here because many other already-ported and still-unported
// files read/write them directly via `extern` (gBestCheckpointNum/Aim
// additionally have shim accessors in PlayerInternal.h that reference them
// directly).

#include "game.h"
#include "uieffects.h"

short	gPrefsFolderVRefNum;
long	gPrefsFolderDirID;

Byte				gDebugMode = 0;				// 0 == none, 1 = fps, 2 = all

uint32_t				gAutoFadeStatusBits;

OGLSetupOutputType		*gGameViewInfoPtr = nil;

PrefsType			gGamePrefs;

Boolean				gTimeDemo = false;

OGLVector3D			gWorldSunDirection;		// also serves as lense flare vector

uint32_t				gGameFrameNum = 0;

Boolean				gPlayingFromSavedGame 	= false;
Boolean				gGameOver 				= false;
Boolean				gLevelCompleted 		= false;
Boolean				gSkipLevelIntro			= false;

short				gLevelNum;
VSMode				gVSMode = VS_MODE_NONE;						// nano vs. nano mode

float				gRaceReadySetGoTimer;

			/* CHECKPOINTS */

short				gBestCheckpointNum[MAX_PLAYERS];
OGLPoint3D			gBestCheckpointCoord[MAX_PLAYERS];
float				gBestCheckpointAim[MAX_PLAYERS];
