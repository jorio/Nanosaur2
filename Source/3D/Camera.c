/****************************/
/*   	CAMERA.C    	    */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/


#include "game.h"


/****************************/
/*    PROTOTYPES            */
/****************************/

static void ResetCameraSettings(void);
static void MoveCamera_DustDevil(ObjNode *player);
static void UpdateCamera_FirstPerson(short i);


/****************************/
/*    CONSTANTS             */
/****************************/


#define	CAM_MINY			60.0f

#define	CAMERA_CLOSEST		75.0f
#define	CAMERA_FARTHEST		400.0f

#define	NUM_FLARE_TYPES		4
#define	NUM_FLARES			6

#define	CAMERA_DEFAULT_DIST_FROM_ME		280.0f
#define	CAMERA_WORMHOLE_DIST_FROM_ME	(CAMERA_DEFAULT_DIST_FROM_ME * 6.0f)

#define	CAMERA_LOOKAT_YOFF			100.0f


#define	MAX_CAMERA_ACCEL	2.0f

#define	CAMERA_TERRAIN_MIN_DIST	80.0f



/*********************/
/*    VARIABLES      */
/*********************/

static OGLCameraPlacement	gAnaglyphCameraBackup[MAX_PLAYERS];		// backup of original camera info before offsets applied

Boolean				gCameraInExitMode = false;
Boolean				gDrawLensFlare = true;

float				gCameraStartupTimer;

static float		gCameraLookAtAccel,gCameraFromAccel;
float				gMinHeightOffGround, gTopCamDist, gMaxCameraHeightOff;

Boolean				gCameraInDeathDiveMode[MAX_PLAYERS] = {false, false};

static OGLPoint3D	gSunCoord;

Byte				gCameraMode[MAX_PLAYERS] = {CAMERA_MODE_NORMAL, CAMERA_MODE_NORMAL};

static const float	gFlareOffsetTable[]=
{
	1.0,
	.6,
	.3,
	1.0/8.0,
	-.25,
	-.5
};


static const float	gFlareScaleTable[]=
{
	.3,
	.06,
	.1,
	.2,
	.03,
	.1
};

static const Byte	gFlareImageTable[]=
{
	PARTICLE_SObjType_LensFlare0,
	PARTICLE_SObjType_LensFlare1,
	PARTICLE_SObjType_LensFlare2,
	PARTICLE_SObjType_LensFlare3,
	PARTICLE_SObjType_LensFlare2,
	PARTICLE_SObjType_LensFlare1
};


/*********************** DRAW LENS FLARE ***************************/

void DrawLensFlare(const OGLSetupOutputType *setupInfo)
{
short			i;
float			x,y,dot;
OGLPoint3D		sunScreenCoord,from;
float			cx,cy;
float			dx,dy,length;
OGLVector3D		axis,lookAtVector,sunVector;
static OGLColorRGBA	transColor = {1,1,1,1};
int				px,py,pw,ph;
AGLContext 		agl_ctx = gGameViewInfoPtr->drawContext;
float			oneOverAspect;

	if (!gDrawLensFlare)
		return;


			/************/
			/* SET TAGS */
			/************/

	OGL_PushState();

	OGL_DisableLighting();												// Turn OFF lighting
	OGL_DisableCullFace();
	glDisable(GL_DEPTH_TEST);
	OGL_BlendFunc(GL_SRC_ALPHA, GL_ONE);
	OGL_SetColor4f(1,1,1,1);										// full white & alpha to start with


			/* CALC SUN COORD */

	from = setupInfo->cameraPlacement[gCurrentSplitScreenPane].cameraLocation;
	gSunCoord.x = from.x - (gWorldSunDirection.x * setupInfo->yon);
	gSunCoord.y = from.y - (gWorldSunDirection.y * setupInfo->yon);
	gSunCoord.z = from.z - (gWorldSunDirection.z * setupInfo->yon);



	/* CALC DOT PRODUCT BETWEEN VIEW AND LIGHT VECTORS TO SEE IF OUT OF RANGE */

	FastNormalizeVector(from.x - gSunCoord.x,
						from.y - gSunCoord.y,
						from.z - gSunCoord.z,
						&sunVector);

	FastNormalizeVector(setupInfo->cameraPlacement[gCurrentSplitScreenPane].pointOfInterest.x - from.x,
						setupInfo->cameraPlacement[gCurrentSplitScreenPane].pointOfInterest.y - from.y,
						setupInfo->cameraPlacement[gCurrentSplitScreenPane].pointOfInterest.z - from.z,
						&lookAtVector);

	dot = OGLVector3D_Dot(&lookAtVector, &sunVector);
	if (dot >= 0.0f)
		goto bye;

	dot = acos(dot) * -2.0f;				// get angle & modify it
	transColor.a = cos(dot);				// get cos of modified angle


			/* CALC SCREEN COORDINATE OF LIGHT */

	OGLPoint3D_Transform(&gSunCoord, &gWorldToWindowMatrix[gCurrentSplitScreenPane], &sunScreenCoord);



			/* CALC CENTER OF VIEWPORT */

	OGL_GetCurrentViewport(setupInfo, &px, &py, &pw, &ph, gCurrentSplitScreenPane);
	cx = pw/2 + px;
	cy = ph/2 + py;


			/* CALC VECTOR FROM CENTER TO LIGHT */

	dx = sunScreenCoord.x - cx;
	dy = sunScreenCoord.y - cy;
	length = sqrt(dx*dx + dy*dy);
	FastNormalizeVector(dx, dy, 0, &axis);


			/***************/
			/* DRAW FLARES */
			/***************/

			/* INIT MATRICES */

	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();

	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();

	oneOverAspect = 1.0f / gCurrentPaneAspectRatio;

	for (i = 0; i < NUM_FLARES; i++)
	{
		float	sx,sy,o,fx,fy;

		if (i == 0)
			gGlobalTransparency = .99;		// sun is always full brightness (leave @ < 1 to ensure GL_BLEND)
		else
			gGlobalTransparency = transColor.a;

		MO_DrawMaterial(gSpriteGroupList[SPRITE_GROUP_PARTICLES][gFlareImageTable[i]].materialObject, setupInfo);		// activate material



		if (i == 1)												// always draw sun, but fade flares based on dot
		{
			if (transColor.a <= 0.0f)							// see if faded all out
				break;
			OGL_SetColor4fv(&transColor);
		}


		o = gFlareOffsetTable[i];
		sx = gFlareScaleTable[i];
		sy = sx * oneOverAspect;

		x = cx + axis.x * length * o;
		y = cy + axis.y * length * o;

		fx = x / (pw/2) - 1.0f;
		fy = (ph-y) / (ph/2) - 1.0f;

		glBegin(GL_QUADS);
		glTexCoord2f(0,0);	glVertex2f(fx - sx, fy - sy);
		glTexCoord2f(1,0);	glVertex2f(fx + sx, fy - sy);
		glTexCoord2f(1,1);	glVertex2f(fx + sx, fy + sy);
		glTexCoord2f(0,1);	glVertex2f(fx - sx, fy + sy);
		glEnd();
	}

			/* RESTORE MODES */

bye:
	gGlobalTransparency = 1.0f;
	OGL_PopState();

}


//===============================================================================================================================================================

#pragma mark -

/*************** INIT CAMERA: TERRAIN ***********************/
//
// This MUST be called after the players have been created so that we know
// where to put the camera.
//

void InitCamera_Terrain(short playerNum)
{
ObjNode	*playerObj = gPlayerInfo[playerNum].objNode;

	ResetCameraSettings();

	gCameraInDeathDiveMode[playerNum] = false;

			/******************************/
			/* SET CAMERA STARTING COORDS */
			/******************************/

	if (playerObj)
	{
		float	dx,dz,x,z,r;

		r = playerObj->Rot.y;

					/* SPECIAL INIT FOR WORMHOLE START */

		if (playerObj->Skeleton->AnimNum == PLAYER_ANIM_APPEARWORMHOLE)		// if coming out of a wormhole, move camera farther out to init
		{
			ObjNode *wormhole = gPlayerInfo[playerNum].wormhole;

			r += PI * .8f;

			dx = sin(r) * CAMERA_WORMHOLE_DIST_FROM_ME;
			dz = cos(r) * CAMERA_WORMHOLE_DIST_FROM_ME;

			x = gGameViewInfoPtr->cameraPlacement[playerNum].cameraLocation.x = wormhole->Coord.x + dx;
			z = gGameViewInfoPtr->cameraPlacement[playerNum].cameraLocation.z = wormhole->Coord.z + dz;
			gGameViewInfoPtr->cameraPlacement[playerNum].cameraLocation.y = GetTerrainY(x, z) + 600.0f;

			gCameraFromAccel 	= 0;
		}


				/* START IN REGULAR TRACKING POSITION */

		else
		{
			dx = sin(r) * CAMERA_DEFAULT_DIST_FROM_ME;
			dz = cos(r) * CAMERA_DEFAULT_DIST_FROM_ME;

			x = gGameViewInfoPtr->cameraPlacement[playerNum].cameraLocation.x = playerObj->Coord.x + dx;
			z = gGameViewInfoPtr->cameraPlacement[playerNum].cameraLocation.z = playerObj->Coord.z + dz;
			gGameViewInfoPtr->cameraPlacement[playerNum].cameraLocation.y = GetTerrainY(x, z) + 200.0f;

			gCameraFromAccel 	= MAX_CAMERA_ACCEL;
		}


				/* SET LOOK-AT PT */

		gGameViewInfoPtr->cameraPlacement[playerNum].pointOfInterest.x = playerObj->Coord.x;
		gGameViewInfoPtr->cameraPlacement[playerNum].pointOfInterest.y = playerObj->Coord.y + CAMERA_LOOKAT_YOFF;
		gGameViewInfoPtr->cameraPlacement[playerNum].pointOfInterest.z = playerObj->Coord.z;
	}
}



/******************** RESET CAMERA SETTINGS **************************/

static void ResetCameraSettings(void)
{
	gTopCamDist = 300.0f;

	gCameraFromAccel 	= MAX_CAMERA_ACCEL;

	gMinHeightOffGround = 60;

	gCameraInExitMode = false;

	gCameraLookAtAccel 	= 8.0;

	gMaxCameraHeightOff = MAX_ALTITUDE_DIFF * 1.2f;

}



/*********************** UPDATE CAMERA ************************/

void UpdateCameras(void)
{
float				fps = gFramesPerSecondFrac;
OGLPoint3D			from,to,target;
float				distX,distZ,distY,fromAcc, terrainY;
OGLVector3D			v;
float				myX,myY,myZ,delta;
ObjNode				*playerObj;
SkeletonObjDataType	*skeleton;
float				oldCamX,oldCamZ,oldCamY,oldPointOfInterestX,oldPointOfInterestZ,oldPointOfInterestY;
const OGLVector3D 	up = {0,1,0};
OGLMatrix4x4		m;
const OGLPoint3D	tailOff = {0, 60, CAMERA_DEFAULT_DIST_FROM_ME};
const OGLPoint3D	noseOff = {0, 0, -600};
short				i, n;
const Byte cameraToggle[MAX_PLAYERS] = {kNeed_P1_CameraMode, kNeed_P2_CameraMode};

	if (gTimeDemo)			// don't do anything in time demo mode
		return;

			/****************************/
			/* ACCELERATE CAMERA TO MAX */
			/****************************/
			//
			// When starting @ a wormhole, gCameraFromAccel is 0.0 to prevent
			// the camera from moving.  Once we're out of the wormhole, we
			// accelerate gCameraFromAccel to it's regular value.
			//

	if (gPlayerInfo[0].objNode->Skeleton->AnimNum != PLAYER_ANIM_APPEARWORMHOLE)
	{
		gCameraFromAccel += fps * .6f;
		if (gCameraFromAccel > MAX_CAMERA_ACCEL)
			gCameraFromAccel=MAX_CAMERA_ACCEL;
	}



	for (i = 0; i < gNumPlayers; i++)
	{
		playerObj =  gPlayerInfo[i].objNode;

		if (!playerObj)
			continue;

				/* SEE IF TOGGLE CAMERA MODE */

		n = cameraToggle[i];											// which need should we test?
		if (gControlNeeds[n].newButtonPress)							// is button pressed?
		{
			gCameraMode[i]++;
			if (0)  //gGamePrefs.stereoGlassesMode != STEREO_GLASSES_MODE_OFF)
			{
				if (gCameraMode[i] > CAMERA_MODE_ANAGLYPHCLOSE)
					gCameraMode[i] = 0;
			}
			else
			{
				if (gCameraMode[i] > CAMERA_MODE_FIRSTPERSON)
					gCameraMode[i] = 0;
			}
		}

		if (gCameraMode[i] == CAMERA_MODE_FIRSTPERSON)
		{
			UpdateCamera_FirstPerson(i);
			continue;
		}




		skeleton = playerObj->Skeleton;
		if (!skeleton)
			DoFatalAlert("MoveCameras: player has no skeleton!");


					/* SPECIAL FOR DUST DEVIL */

		if (skeleton->AnimNum == PLAYER_ANIM_DUSTDEVIL)
		{
			MoveCamera_DustDevil(playerObj);

			continue;
		}


					/******************/
					/* GET COORD DATA */
					/******************/

		oldCamX = gGameViewInfoPtr->cameraPlacement[i].cameraLocation.x;				// get current/old cam coords
		oldCamY = gGameViewInfoPtr->cameraPlacement[i].cameraLocation.y;
		oldCamZ = gGameViewInfoPtr->cameraPlacement[i].cameraLocation.z;

		oldPointOfInterestX = gGameViewInfoPtr->cameraPlacement[i].pointOfInterest.x;
		oldPointOfInterestY = gGameViewInfoPtr->cameraPlacement[i].pointOfInterest.y;
		oldPointOfInterestZ = gGameViewInfoPtr->cameraPlacement[i].pointOfInterest.z;

		myX = gPlayerInfo[i].coord.x;
		myY = gPlayerInfo[i].coord.y + playerObj->BottomOff;
		myZ = gPlayerInfo[i].coord.z;


				/**********************/
				/* CALC LOOK AT POINT */
				/**********************/

		OGLPoint3D_Transform(&noseOff, &playerObj->BaseTransformMatrix, &target);

		distX = target.x - oldPointOfInterestX;
		distY = target.y - oldPointOfInterestY;
		distZ = target.z - oldPointOfInterestZ;


					/* MOVE "TO" */

		delta = distX * (fps * gCameraLookAtAccel);										// calc delta to move
		if (fabs(delta) > fabs(distX))													// see if will overshoot
			delta = distX;
		to.x = oldPointOfInterestX + delta;												// move x

		delta = distY * (fps * gCameraLookAtAccel);										// calc delta to move
		if (fabs(delta) > fabs(distY))													// see if will overshoot
			delta = distY;
		to.y = oldPointOfInterestY + delta;												// move y

		delta = distZ * (fps * gCameraLookAtAccel);										// calc delta to move
		if (fabs(delta) > fabs(distZ))													// see if will overshoot
			delta = distZ;
		to.z = oldPointOfInterestZ + delta;												// move z


				/*******************/
				/* CALC FROM POINT */
				/*******************/

		if (!gCameraInDeathDiveMode[i])
		{
			fromAcc = gCameraFromAccel;

			if (gCameraInExitMode)
			{
				target.x = gExitWormhole->Coord.x;
				target.z = gExitWormhole->Coord.z;

				target.y = GetTerrainY(target.x, target.z) + 600.0f;

				fromAcc *= .4f;				// don't go so fast
			}
			else
			{
				OGLPoint3D_Transform(&tailOff, &playerObj->BaseTransformMatrix, &target);
			}


					/* MOVE CAMERA TOWARDS POINT */

			distX = target.x - oldCamX;
			distY = target.y - oldCamY;
			distZ = target.z - oldCamZ;

			delta = distX * (fps * fromAcc);							// calc delta to move
			if (fabs(delta) > fabs(distX))								// see if will overshoot
				delta = distX;
			from.x = oldCamX + delta;									// move x

			delta = distZ * (fps * fromAcc);							// calc delta to move
			if (fabs(delta) > fabs(distZ))								// see if will overshoot
				delta = distX;
			from.z = oldCamZ + delta;									// move z

			delta = distY * (fps * fromAcc);							// calc delta to move
			if (fabs(delta) > fabs(distY))								// see if will overshoot
				delta = distY;
			from.y = oldCamY + delta;									// move y
		}
		else
		{
			OGLMatrix4x4	mm;

			OGLMatrix4x4_SetRotateAboutPoint(&mm, &playerObj->Coord, 0, fps * .4, 0);
			OGLPoint3D_Transform(&gGameViewInfoPtr->cameraPlacement[i].cameraLocation, &mm, &from);
			from.y += fps * 100.0f;

		}

				/* KEEP BELOW CEILING */

		terrainY = CalcPlayerMaxAltitude(from.x, from.z) - 300.0f;
		if (from.y > terrainY)
			from.y = terrainY;


				/* MAKE SURE ABOVE TERRAIN */

		terrainY = GetTerrainY(from.x, from.z) + CAMERA_TERRAIN_MIN_DIST;
		if (from.y < terrainY)
			from.y = terrainY;


					/**********************/
					/* UPDATE CAMERA INFO */
					/**********************/

			/* CALC CAMERA TILT */

		v.x = to.x - from.x;												// calc sight vector
		v.y = to.y - from.y;
		v.z = to.z - from.z;
		FastNormalizeVector(v.x, v.y, v.z, &v);

		gPlayerInfo[i].camera.cameraAim = v;

		if (gGamePrefs.stereoGlassesMode != STEREO_GLASSES_MODE_OFF)		// exaggerate z-rot in anaglyph mode
			OGLMatrix4x4_SetRotateAboutAxis(&m, &v, playerObj->Rot.z * .3f);
		else
			OGLMatrix4x4_SetRotateAboutAxis(&m, &v, playerObj->Rot.z * .2f);


		OGLVector3D_Transform(&up, &m, &v);									// transform the "up" vector to give us tilt
		OGL_UpdateCameraFromToUp(gGameViewInfoPtr, &from, &to, &v, i);		// update camera settings



					/* UPDATE PLAYER'S CAMERA INFO */

		gPlayerInfo[i].camera.cameraLocation = from;
		gPlayerInfo[i].camera.pointOfInterest = to;
	}
}


/********************** MOVE CAMERA:  DUST DEVIL ****************************/

static void MoveCamera_DustDevil(ObjNode *player)
{
short	p = player->PlayerNum;
ObjNode	*devil;
OGLVector3D v;
OGLPoint3D	camCoord;
float	terrainY;
float	fps = gFramesPerSecondFrac;

	devil = gPlayerInfo[p].dustDevilObj;

	camCoord = gGameViewInfoPtr->cameraPlacement[p].cameraLocation;				// get old cam coords

				/* CALC VECTOR FROM DEVIL TO CAMERA */

	v.x = camCoord.x - devil->Coord.x;
	v.z = camCoord.z - devil->Coord.z;
	FastNormalizeVector(v.x, 0, v.z, &v);

				/* MOVE CAMERA */

	camCoord.x += v.x * 600.0f * fps;
	camCoord.z += v.z * 600.0f * fps;
	camCoord.y -= 400.0f * fps;


	terrainY = GetTerrainY(camCoord.x, camCoord.z) + CAMERA_TERRAIN_MIN_DIST;					// keep above terrain
	if (camCoord.y  < terrainY)
		camCoord.y = terrainY;

	OGL_UpdateCameraFromTo(gGameViewInfoPtr, &camCoord, nil, p);		// update camera settings

}



/*********************** UPDATE CAMERA: FIRST PERSON ************************/

static void UpdateCamera_FirstPerson(short i)
{
OGLPoint3D			to;
OGLVector3D			v,up;
ObjNode				*player;
const OGLVector3D	forward = {0,0,-1};

	player =  gPlayerInfo[i].objNode;
	if (!player)
		return;

		/* CALC FORWARD VECTOR */

	OGLVector3D_Transform(&forward, &player->BaseTransformMatrix, &v);


		/* CALC UP VECTOR */

	OGLVector3D_Transform(&gUp, &player->BaseTransformMatrix, &up);


	to.x = player->Coord.x + v.x;
	to.y = player->Coord.y + v.y;
	to.z = player->Coord.z + v.z;

	OGL_UpdateCameraFromToUp(gGameViewInfoPtr, &player->Coord, &to, &up, i);		// update camera settings



				/* UPDATE PLAYER'S CAMERA INFO */

	gPlayerInfo[i].camera.cameraLocation = player->Coord;
	gPlayerInfo[i].camera.pointOfInterest = to;
}


#pragma mark -

/********************** PREP ANAGLYPH CAMERAS ***************************/
//
// Make a copy of the camera's real coord info before we do anaglyph offsetting.
//

void PrepAnaglyphCameras(void)
{
short	i;

	for (i = 0; i < gNumPlayers; i++)
	{
		gAnaglyphCameraBackup[i] = gGameViewInfoPtr->cameraPlacement[i];
	}


}

/********************** RESTORE CAMERAS FROM ANAGLYPH ***************************/

void RestoreCamerasFromAnaglyph(void)
{
short	i;

	for (i = 0; i < gNumPlayers; i++)
	{
		gGameViewInfoPtr->cameraPlacement[i] = gAnaglyphCameraBackup[i];
	}
}


/******************** CALC ANAGLYPH CAMERA OFFSET ***********************/

void CalcAnaglyphCameraOffset(Byte pane, Byte pass)
{
OGLVector3D	aim;
OGLVector3D	xaxis;
float		sep = gAnaglyphEyeSeparation;

	if (pass > 0)
		sep = -sep;

			/* CALC CAMERA'S X-AXIS */

	aim.x = gAnaglyphCameraBackup[pane].pointOfInterest.x - gAnaglyphCameraBackup[pane].cameraLocation.x;
	aim.y = gAnaglyphCameraBackup[pane].pointOfInterest.y - gAnaglyphCameraBackup[pane].cameraLocation.y;
	aim.z = gAnaglyphCameraBackup[pane].pointOfInterest.z - gAnaglyphCameraBackup[pane].cameraLocation.z;
	OGLVector3D_Normalize(&aim, &aim);

	OGLVector3D_Cross(&gAnaglyphCameraBackup[pane].upVector, &aim, &xaxis);


				/* OFFSET CAMERA FROM */

	gGameViewInfoPtr->cameraPlacement[pane].cameraLocation.x = gAnaglyphCameraBackup[pane].cameraLocation.x + (xaxis.x * sep);
	gGameViewInfoPtr->cameraPlacement[pane].cameraLocation.z = gAnaglyphCameraBackup[pane].cameraLocation.z + (xaxis.z * sep);
	gGameViewInfoPtr->cameraPlacement[pane].cameraLocation.y = gAnaglyphCameraBackup[pane].cameraLocation.y + (xaxis.y * sep);



				/* OFFSET CAMERA TO */

	gGameViewInfoPtr->cameraPlacement[pane].pointOfInterest.x = gAnaglyphCameraBackup[pane].pointOfInterest.x + (xaxis.x * sep);
	gGameViewInfoPtr->cameraPlacement[pane].pointOfInterest.z = gAnaglyphCameraBackup[pane].pointOfInterest.z + (xaxis.z * sep);
	gGameViewInfoPtr->cameraPlacement[pane].pointOfInterest.y = gAnaglyphCameraBackup[pane].pointOfInterest.y + (xaxis.y * sep);



}




