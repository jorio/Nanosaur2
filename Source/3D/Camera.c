/****************************/
/*   	CAMERA.C    	    */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/

// All function implementations are now in Camera.swift. The globals below
// stay here because other already-ported files read/write them directly
// via `extern` (including PlayerInternal.h's/InfobarInternal.h's Get/Set
// shims).

#include "game.h"

Boolean				gCameraInExitMode = false;
Boolean				gDrawLensFlare = true;

Boolean				gCameraInDeathDiveMode[MAX_PLAYERS] = {false, false};

Byte				gCameraMode[MAX_PLAYERS] = {CAMERA_MODE_NORMAL, CAMERA_MODE_NORMAL};
