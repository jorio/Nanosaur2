/*******************************/
/*   	PLAYER .C			   */
/* (c)2003 Pangea Software     */
/* By Brian Greenstone         */
/*******************************/


/****************************/
/*    EXTERNALS             */
/****************************/


#include "game.h"

/****************************/
/*    PROTOTYPES            */
/****************************/

static Boolean DoPlayerCollisionDetect(ObjNode *theNode, Boolean useBBoxForTerrain);
static Boolean DoPlayerMovementAndCollision(ObjNode *theNode, Boolean useBBoxForTerrain);
static void MovePlayer_Flying(ObjNode *theNode);
static void MovePlayer_DeathDive(ObjNode *theNode);
static void MovePlayer_AppearWormhole(ObjNode *player);
static void MovePlayer_EnterWormhole(ObjNode *player);
static void MovePlayer_FlyingDisoriented(ObjNode *theNode);
static void MovePlayer_DustDevil(ObjNode *player);
static void MovePlayer_ReadyToGrab(ObjNode *theNode);
static void MovePlayer_Banking(ObjNode *theNode);


static void DrawPlayer(ObjNode *theNode);
static void UpdatePlayer(ObjNode *theNode);
static void PlayerJetpackButtonPressed(ObjNode *player, short playerNum);
static void MakeJetpackExhaust(ObjNode *jetpack);


static void MovePlayer(ObjNode *theNode);
static void DoPlayerFlightControls(ObjNode *player);
static void CheckPlayerActionControls(ObjNode *theNode);

static void DoPlayerLineSegmentCollision(ObjNode *player);
static void SetPlayerFlyingAnim_WithEgg(ObjNode *player);

static void MakePlayerSmoke(ObjNode *theNode);


/****************************/
/*    CONSTANTS             */
/****************************/

#define	FLIGHT_SLIDE_FACTOR		15.0f				// smaller == more slide, larger = less slide
#define	FLIGHT_TURN_SENSITIVITY	1.9f				// smaller == slower turns, larger == faster turns

#define	MAX_FLIGHT_Z_ROT		(PI/2.0f * .6f)


#define	DEFAULT_PLAYER_SHADOW_SCALE	8.0f


#define	PLAYER_MIN_SPEED		650.0f

/*********************/
/*    VARIABLES      */
/*********************/

float			gPlayerBottomOff = 0;
short			gPlayerMultiPassCount = 0;


//
// In order to let the player move faster than the max speed, we use a current and target value.
// the target is what we want the max to normally be, and the current is what it currently is.
// So, when the player needs to go faster, we modify Current and then slowly decay it back to Target.
//

float	gTargetMaxSpeed[MAX_PLAYERS] = {PLAYER_NORMAL_MAX_SPEED, PLAYER_NORMAL_MAX_SPEED};
float	gCurrentMaxSpeed[MAX_PLAYERS] = {PLAYER_NORMAL_MAX_SPEED, PLAYER_NORMAL_MAX_SPEED};


static OGLPoint3D	gJetpackButtOff = {0, 11.3, 33};

#define	FlapCoastTimer	SpecialF[3]


/*************************** CREATE PLAYER MODEL: TERRAIN ****************************/
//
// Creates an ObjNode for the player
//
// INPUT:
//			where = floor coord where to init the player.
//			rotY = rotation to assign to player if oldObj is nil.
//

void CreatePlayerObject(short playerNum, OGLPoint3D *where, float rotY)
{
ObjNode	*newObj, *jetpack, *blue;
short	j,i;

		/*****************/
		/* MAKE SKELETON */
		/*****************/

	NewObjectDefinitionType def =
	{
		.type 		= SKELETON_TYPE_PLAYER,
		.animNum	= PLAYER_ANIM_FLAP,
		.coord.x	= where->x,
		.coord.z	= where->z,
		.coord.y	= FindHighestCollisionAtXZ(where->x,where->z, CTYPE_MISC|CTYPE_TERRAIN) + 500,
		.flags		= gAutoFadeStatusBits |STATUS_BIT_NOTEXTUREWRAP|STATUS_BIT_ROTXZY,
		.slot		= PLAYER_SLOT,
		.moveCall	= MovePlayer,
		.drawCall	= DrawPlayer,
		.rot		= rotY,
		.scale		= PLAYER_DEFAULT_SCALE,
	};

	newObj = MakeNewSkeletonObject(&def);
	newObj->PlayerNum = playerNum;

	def.drawCall = NULL;		// clear draw call for jetpack et al.



				/* SET COLLISION INFO */

	gPlayerBottomOff = newObj->LocalBBox.min.y;								// calc offset to bottom for collision function later

	newObj->CType = CTYPE_PLAYER1 << playerNum;
	newObj->CBits = CBITS_ALLSOLID;
	SetObjectCollisionBounds(newObj, 40, newObj->LocalBBox.min.y, -40, 40, 40, -40);

	newObj->HitByWeaponHandler = PlayerHitByWeaponCallback;

			/* SET HOT-SPOT FOR AUTO TARGETING WEAPONS */

	newObj->HeatSeekHotSpotOff.x = 0;
	newObj->HeatSeekHotSpotOff.y = 0;
	newObj->HeatSeekHotSpotOff.z = -80;

	newObj->SmokeParticleGroup = -1;


			/* SET OVERRIDE TEXTURE FOR PLAYER 2 */

	if (playerNum > 0)
	{
		if (0 == gNumSpritesInGroupList[SPRITE_GROUP_P2SKIN])
		{
			LoadSpriteGroupFromFile(SPRITE_GROUP_P2SKIN, ":Sprites:textures:player2", 0);
		}

		newObj->Skeleton->overrideTexture[0] = gSpriteGroupList[SPRITE_GROUP_P2SKIN][0].materialObject;
	}




		/*****************/
		/* MAKE JETPACK  */
		/*****************/

	def.group 		= MODEL_GROUP_PLAYER;
	def.type 		= PLAYER_ObjType_JetPack;
	def.flags 		= gAutoFadeStatusBits;
	def.slot++;
	def.moveCall 	= MovePlayerJetpack;
	def.drawCall 	= nil;
	jetpack = MakeNewDisplayGroupObject(&def);

	newObj->ChainNode = jetpack;
	jetpack->ChainHead = newObj;

		/* BLUE THING */

	def.type 		= PLAYER_ObjType_JetPackBlue;
	def.flags 		= gAutoFadeStatusBits | STATUS_BIT_UVTRANSFORM | STATUS_BIT_GLOW | STATUS_BIT_NOLIGHTING;
	def.slot++;
	def.moveCall 	= nil;
	blue = MakeNewDisplayGroupObject(&def);

	blue->ColorFilter.a = .99;
	jetpack->ChainNode = blue;
	blue->ChainHead = jetpack;


		/* MAKE SPARKLES FOR GUN TURRETS */

	for (j = 0; j < 2; j++)
	{
		i = jetpack->Sparkles[j] = GetFreeSparkle(jetpack);
		if (i != -1)
		{
			static OGLPoint3D	sparkleOff[2] =
			{
				{21.21, 19.068, 21.183},
				{-21.21, 19.068, 21.183},
			};

			gSparkles[i].flags = SPARKLE_FLAG_OMNIDIRECTIONAL  | SPARKLE_FLAG_TRANSFORMWITHOWNER;
			gSparkles[i].where = sparkleOff[j];

			gSparkles[i].color.r = 1;
			gSparkles[i].color.g = 1;
			gSparkles[i].color.b = 1;
			gSparkles[i].color.a = 1;

			gSparkles[i].scale 	= 15.0f;
			gSparkles[i].separation = 15.0f;

			gSparkles[i].textureNum = PARTICLE_SObjType_GreenGlint;
		}
	}

		/*******************/
		/* SET OTHER STUFF */
		/*******************/

	gTargetMaxSpeed[playerNum] = PLAYER_NORMAL_MAX_SPEED;
	gCurrentMaxSpeed[playerNum] = PLAYER_NORMAL_MAX_SPEED;


	gPlayerInfo[playerNum].objNode 	= newObj;
	gPlayerInfo[playerNum].coord		= newObj->Coord;


	AttachShadowToObject(newObj, GLOBAL_SObjType_Shadow_Nano, DEFAULT_PLAYER_SHADOW_SCALE, DEFAULT_PLAYER_SHADOW_SCALE * 1.1, true);



		/******************************/
		/* SET COLLISION FOR VS MODES */
		/******************************/
		//
		// In VS. modes the players can collide with each other, so
		// set triggers on the players.
		//

	if (gVSMode != VS_MODE_NONE)
	{
		newObj->CType 			|= CTYPE_TRIGGER;
		newObj->CBits			|= CBITS_ALWAYSTRIGGER;
		newObj->TriggerCallback = DoTrig_Player;
	}

	if (gTimeDemo)
		HidePlayer(newObj);

}


#pragma mark -


/******************** MOVE PLAYER ***********************/

static void MovePlayer(ObjNode *theNode)
{
static void(*myMoveTable[])(ObjNode *) =
{
	MovePlayer_Flying,							// flap
	MovePlayer_Banking,							// bank left
	MovePlayer_Banking,							// bank right
	MovePlayer_DeathDive,						// death dive
	MovePlayer_AppearWormhole,					// appear via wormhole
	MovePlayer_ReadyToGrab,						// ready 2 grab
	MovePlayer_Flying,							// flap w/ egg
	MovePlayer_Banking,							// bank left / egg
	MovePlayer_Banking,							// bank right /egg
	MovePlayer_EnterWormhole,					// exit level via wormhole
	MovePlayer_FlyingDisoriented,				// disoriented
	MovePlayer_DustDevil,						// caught in dust devil
	MovePlayer_Flying,							// coasting
	MovePlayer_Flying,							// xxxx
};

	if (gTimeDemo)
	{

		return;
	}


	GetObjectInfo(theNode);


			/* JUMP TO HANDLER */

	if (myMoveTable[theNode->Skeleton->AnimNum] != nil)
		myMoveTable[theNode->Skeleton->AnimNum](theNode);


//	gScratch = theNode->Skeleton->activeBuffer;

}





/******************** MOVE PLAYER: FLYING ***********************/

static void MovePlayer_Flying(ObjNode *theNode)
{
			/***************/
			/* MOVE PLAYER */
			/***************/

			/* DO MOTION CONTROLS */

	DoPlayerFlightControls(theNode);


			/* DO ACTION CONTROL */

	CheckPlayerActionControls(theNode);


			/* SET APPROPRIATE ANIM */

	if (gPlayerInfo[theNode->PlayerNum].carriedObj)
		SetPlayerFlyingAnim_WithEgg(theNode);
	else
		SetPlayerFlyingAnim(theNode);


			/* MOVE & COLLIDE */

	if (DoPlayerMovementAndCollision(theNode, false))
		goto update;






			/* UPDATE IT */

update:
	UpdatePlayer(theNode);
}


/******************** MOVE PLAYER: BANKING ***********************/

static void MovePlayer_Banking(ObjNode *theNode)
{
	theNode->Skeleton->AnimSpeed = 1.5f;
	MovePlayer_Flying(theNode);
}


/******************** MOVE PLAYER: READY TO GRAB ***********************/

static void MovePlayer_ReadyToGrab(ObjNode *theNode)
{
	theNode->Skeleton->AnimSpeed = 1.7f;

	MovePlayer_Flying(theNode);
}


/******************** MOVE PLAYER: FLYING DISORIENTED ***********************/

static void MovePlayer_FlyingDisoriented(ObjNode *theNode)
{
			/* SEE IF STOP DISORIENTATION */

	if (theNode->Skeleton->AnimHasStopped)
		SetPlayerFlyingAnim(theNode);


			/***************/
			/* MOVE PLAYER */
			/***************/

			/* DO MOTION CONTROLS */

	DoPlayerFlightControls(theNode);


			/* DO ACTION CONTROL */

	CheckPlayerActionControls(theNode);



			/* MOVE & COLLIDE */

	if (DoPlayerMovementAndCollision(theNode, false))
		goto update;


			/* UPDATE IT */

update:
	UpdatePlayer(theNode);
}




/******************** MOVE PLAYER: DEATH DIVE ***********************/

static void MovePlayer_DeathDive(ObjNode *player)
{
float				fps = gFramesPerSecondFrac;

	gDelta.y -=  800.0f * fps;
	ApplyFrictionToDeltasXZ(300, &gDelta);				// air friction


				/* MOVE IT */

	gCoord.x += gDelta.x * fps;
	gCoord.y += gDelta.y * fps;
	gCoord.z += gDelta.z * fps;


			/* TILT TO NOSE DIVE */


	player->Rot.z = DecayToZero(player->Rot.z, fps * .5f);


			/*********************/
			/* SEE IF HIT GROUND */
			/*********************/

	if (gCoord.y < GetTerrainY(gCoord.x, gCoord.z))
	{
		ExplodePlayer(player, player->PlayerNum, &gCoord);
	}


	UpdatePlayer(player);
}



/******************** MOVE PLAYER: APPEAR WORMHOLE ***********************/

static void MovePlayer_AppearWormhole(ObjNode *player)
{
float				fps = gFramesPerSecondFrac;
short				playerNum = player->PlayerNum;


			/* SLOW DOWN */

	player->Speed -= 500.0f * fps;
	if (player->Speed < PLAYER_MIN_SPEED)
		player->Speed = PLAYER_MIN_SPEED;


			/* CALC NEW DELTA */

	OGLVector3D_Normalize(&gDelta, &gDelta);
	gDelta.x *= player->Speed;
	gDelta.y *= player->Speed;
	gDelta.z *= player->Speed;

			/* MOVE */

	gCoord.x += gDelta.x * fps;
	gCoord.y += gDelta.y * fps;
	gCoord.z += gDelta.z * fps;


	/* ARE WE OUT OF THE WORMHOLE? */

	if (gCoord.y < (GetTerrainY(gCoord.x, gCoord.z) + MAX_ALTITUDE_DIFF))
	{
		gCurrentMaxSpeed[playerNum] = -gDelta.y;								// match speeds when exiting wormhole
		MorphToSkeletonAnim(player->Skeleton, PLAYER_ANIM_FLAP, 2);
		FadePlayer(player, 1.0);						// make sure totally faded in

	}


		/* FADE IN */

	FadePlayer(player, .4f * fps);



	UpdatePlayer(player);
}


/******************** MOVE PLAYER: ENTER WORMHOLE ***********************/
//
// Make player fly into the wormhole
//

static void MovePlayer_EnterWormhole(ObjNode *player)
{
float		fps = gFramesPerSecondFrac;
float		dist, s;


			/* SEE IF GO STRAIGHT UP */

	dist = OGLPoint3D_Distance(&gCoord, &gExitWormhole->Coord);		// get current dist to joint
	if (dist < 50.0f)
	{
		static OGLVector3D	up = {0,1,0};

		OGLVector3D_Transform(&up, &gExitWormhole->BaseTransformMatrix, &player->MotionVector);	// make aim up wormhole
	}


			/* MOVE IT */

	gDelta.x = player->MotionVector.x * player->Speed;							// move toward the joint
	gDelta.y = player->MotionVector.y * player->Speed;
	gDelta.z = player->MotionVector.z * player->Speed;

	gCoord.x += gDelta.x * fps;
	gCoord.y += gDelta.y * fps;
	gCoord.z += gDelta.z * fps;


			/* ROTATE UP */

	player->Rot.x += fps * 2.0f;
	if (player->Rot.x > PI/2.2)
		player->Rot.x = PI/2.2;

	player->Rot.z = DecayToZero(player->Rot.z, PI * fps);


	player->Speed += 200.0f * fps;


			/* FADE OUT */

	if (FadePlayer(player, -.3 * fps))
		StartLevelCompletion(2.0);


				/* SHRINK */

	s = player->Scale.x -= fps * .5f;
	if (s < 0.0f)
	{
		s = 0.0f;
		StartLevelCompletion(2.0);
	}

	player->Scale.x =
	player->Scale.y =
	player->Scale.z = s;

	UpdatePlayer(player);
}


/******************** MOVE PLAYER: DUST DEVIL ***********************/

static void MovePlayer_DustDevil(ObjNode *player)
{
float		fps = gFramesPerSecondFrac;
short		p = player->PlayerNum;
float		r, radius = gPlayerInfo[p].radiusFromDustDevil;
ObjNode		*devil = gPlayerInfo[p].dustDevilObj;							// get dust devil objNode

	player->Timer -= fps;

				/***************/
				/* SPIN PLAYER */
				/***************/

	if (player->Timer > 0.0f)
	{

		if (PlayerLoseHealth(p, .04f * fps, PLAYER_DEATH_TYPE_EXPLODE, &gCoord, false))		// lose some health while spinning
			return;


				/* ACCELERATE SPIN */

		gPlayerInfo[p].dustDevilRotSpeed += fps * PI2;
		if (gPlayerInfo[p].dustDevilRotSpeed > (4000.0f / radius))
			gPlayerInfo[p].dustDevilRotSpeed = (4000.0f / radius);


					/* SPIN */

		r = gPlayerInfo[p].dustDevilRot += gPlayerInfo[p].dustDevilRotSpeed * fps;

		gCoord.x = devil->Coord.x - sin(r) * radius;
		gCoord.z = devil->Coord.z - cos(r) * radius;


				/* ROTATE TO AIM */

#if 0
		r += PI/2;											// calc desired aim
		if (player->Rot.y < r)
		{
			player->Rot.y += fps * 10.0f;
			if (player->Rot.y > r)
				player->Rot.y = r;
		}
		else
		if (player->Rot.y > r)
		{
			player->Rot.y -= fps * 10.0f;
			if (player->Rot.y < r)
				player->Rot.y = r;
		}
#else
		player->Rot.y += fps * 9.0f;


#endif

	}

				/****************/
				/* EJECT PLAYER */
				/****************/

	else
	{
				/* CALC EJECTION TRAJECTORY */

		if (!gPlayerInfo[p].ejectedFromDustDevil)
		{
			const float	speed = 3000.0f;
			OGLVector3D	v;
			const OGLVector3D up = {0,1,0};

			v.x = gCoord.x - devil->Coord.x;							// calc vector from devil to player
			v.z = gCoord.z - devil->Coord.z;
			FastNormalizeVector(v.x, 0, v.z, &v);

			OGLVector3D_Cross(&up, &v, &v);								// calc cross product to get ejection vector

			gDelta.x = v.x * speed;										// calc delta
			gDelta.y = 0;
			gDelta.z = v.z * speed;

			player->Speed = speed;										// set player speeds
			gCurrentMaxSpeed[p] = speed;

			gPlayerInfo[p].ejectedFromDustDevil = true;

			player->Rot.y = CalcYAngleFromPointToPoint(0, gCoord.x, gCoord.z, gCoord.x + v.x, gCoord.z + v.z);

		}

				/* MOVE */

		gCoord.x += gDelta.x * fps;
		gCoord.y += gDelta.y * fps;
		gCoord.z += gDelta.z * fps;
	}



	UpdatePlayer(player);


			/***************/
			/* SEE IF DONE */
			/***************/

	if (player->Timer <= -.3f)
	{
		DisorientPlayer(player);
	}



}



#pragma mark -

/************************ UPDATE PLAYER ***************************/

static void UpdatePlayer(ObjNode *theNode)
{
const float fps = gFramesPerSecondFrac;
short	playerNum = theNode->PlayerNum;


			/****************************/
			/* UPDATE CURRENT MAX SPEED */
			/****************************/


	if (gVSMode == VS_MODE_RACE)
	{
		float   dist = OGLPoint3D_Distance(&gPlayerInfo[0].coord, &gPlayerInfo[1].coord);

		if (!gPlayerInfo[playerNum].jetpackActive)
		{
			gTargetMaxSpeed[playerNum] = PLAYER_NORMAL_MAX_SPEED;

			if (dist > 2000.0f)
			{
				if (gPlayerInfo[playerNum].place == 1)
					gTargetMaxSpeed[playerNum] = PLAYER_NORMAL_MAX_SPEED * 1.25;
			}
		}

		if (theNode->Speed < gCurrentMaxSpeed[playerNum])
			theNode->Speed = gCurrentMaxSpeed[playerNum];
	}


//	if (playerNum == 0)
//		gScratchF = gTargetMaxSpeed[playerNum]; //-------


			/* NEED TO SLOW TO TARGET SPEED */

	if (gCurrentMaxSpeed[playerNum] > gTargetMaxSpeed[playerNum])
	{
		gCurrentMaxSpeed[playerNum] -= fps * 600.0f;
		if (gCurrentMaxSpeed[playerNum] < gTargetMaxSpeed[playerNum])
			gCurrentMaxSpeed[playerNum] = gTargetMaxSpeed[playerNum];
	}

			/* NEED TO SPEEDUP TO TARGET SPEED */

	else
	if (gCurrentMaxSpeed[playerNum] < gTargetMaxSpeed[playerNum])
	{
		gCurrentMaxSpeed[playerNum] += fps * 800.0f;
		if (gCurrentMaxSpeed[playerNum] > gTargetMaxSpeed[playerNum])
			gCurrentMaxSpeed[playerNum] = gTargetMaxSpeed[playerNum];
	}



		/********************************************************/
		/* UPDATE OBJECT AS LONG AS NOT BEING MATRIX CONTROLLED */
		/********************************************************/

	switch(theNode->Skeleton->AnimNum)
	{
//		case	PLAYER_ANIM_GRABBED:
//				break;

		default:
				UpdateObject(theNode);
	}

	gPlayerInfo[playerNum].coord = gCoord;				// update player coord




		/* CHECK INV TIMER */

	gPlayerInfo[playerNum].invincibilityTimer -= fps;


			/***********************************/
			/* SEE IF CROSSED ANY LINE MARKERS */
			/***********************************/

	switch(gLevelNum)
	{
		case	LEVEL_NUM_RACE1:								// call special line marker function for race modes
		case	LEVEL_NUM_RACE2:
				UpdatePlayerRaceMarkers(theNode);
				break;

		default:
				HandlePlayerLineMarkerCrossing(theNode);
	}



			/* UPDATE CONTRAILS */

	UpdatePlayerContrails(theNode);


			/* UPDATE CROSSHAIRS */

	UpdatePlayerCrosshairs(theNode);


		/* UPDATE SHIELD */

	UpdatePlayerShield(playerNum);


			/****************************/
			/* MAKE SMOKE TRAIL IF HURT */
			/****************************/

	if (!gGamePrefs.lowRenderQuality && gPlayerInfo[playerNum].health < .33f)
	{
		MakePlayerSmoke(theNode);
	}


			/* HIDE SMOKE TRAIL IF FIRST-PERSON */

	{
		short particleGroup		= (short) theNode->SmokeParticleGroup;
		uint32_t magicNum 		= (uint32_t) theNode->SmokeParticleMagic;

		if (particleGroup != -1 && VerifyParticleGroupMagicNum(particleGroup, magicNum))
		{
			if (gCameraMode[playerNum] == CAMERA_MODE_FIRSTPERSON)
			{
				SetParticleGroupVisiblePanes(particleGroup, playerNum != 0, playerNum != 1);
			}
			else
			{
				SetParticleGroupVisiblePanes(particleGroup, true, true);
			}
		}
	}
}


/****************** MAKE PLAYER SMOKE ************************/

static void MakePlayerSmoke(ObjNode *theNode)
{
float	fps = gFramesPerSecondFrac;
NewParticleGroupDefType	groupDef;
NewParticleDefType	newParticleDef;
OGLVector3D			d;
OGLPoint3D			p;

	theNode->SmokeTimer -= fps;													// see if add smoke
	if (theNode->SmokeTimer <= 0.0f)
	{
		theNode->SmokeTimer += .02f;										// reset timer

		short particleGroup		= (short) theNode->SmokeParticleGroup;
		uint32_t magicNum 		= (uint32_t) theNode->SmokeParticleMagic;

		if ((particleGroup == -1) || (!VerifyParticleGroupMagicNum(particleGroup, magicNum)))
		{
			theNode->SmokeParticleMagic = magicNum = MyRandomLong();			// generate a random magic num

			groupDef.magicNum				= magicNum;
			groupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
			groupDef.flags					= PARTICLE_FLAGS_DONTCHECKGROUND | PARTICLE_FLAGS_ALLAIM;
			groupDef.gravity				= 0;
			groupDef.magnetism				= 0;
			groupDef.baseScale				= 9.0f;
			groupDef.decayRate				=  -.4f;
			groupDef.fadeRate				= .6;
			groupDef.particleTextureNum		= PARTICLE_SObjType_BlackSmoke;
			groupDef.srcBlend				= GL_SRC_ALPHA;
			groupDef.dstBlend				= GL_ONE_MINUS_SRC_ALPHA;
			theNode->SmokeParticleGroup = particleGroup = NewParticleGroup(&groupDef);
		}

		if (particleGroup != -1)
		{
			float   x = gCoord.x;
			float   y = gCoord.y;
			float   z = gCoord.z;

			for (int i = 0; i < 2; i++)
			{
				p.x = x + RandomFloat2() * 20.0f;
				p.y = y + RandomFloat2() * 20.0f;
				p.z = z + RandomFloat2() * 20.0f;

				d.x = RandomFloat2() * 20.0f;
				d.y = RandomFloat2() * 20.0f;
				d.z = RandomFloat2() * 20.0f;

				newParticleDef.groupNum		= particleGroup;
				newParticleDef.where		= &p;
				newParticleDef.delta		= &d;
				newParticleDef.scale		= RandomFloat() + 1.0f;
				newParticleDef.rotZ			= RandomFloat() * PI2;
				newParticleDef.rotDZ		= RandomFloat2();
				newParticleDef.alpha		= .9;
				if (AddParticleToGroup(&newParticleDef))
				{
					theNode->SmokeParticleGroup = -1;
					break;
				}
			}
		}
	}
}






/********************** DRAW PLAYER *************************/

static void DrawPlayer(ObjNode *theNode)
{
	if ((gCameraMode[theNode->PlayerNum] != CAMERA_MODE_FIRSTPERSON) || (gCurrentSplitScreenPane != theNode->PlayerNum))
	{
		DrawSkeleton(theNode);
	}


		/* DRAW TARGETING FOR 2P MODES */
		//
		// This draws the orange ring around the other player so that
		// we can see him more easily.
		//

	if (gVSMode != VS_MODE_NONE)
	{

		if (gCurrentSplitScreenPane != theNode->PlayerNum)					// if we're drawing the "other" player...
		{
			float size = OGLPoint3D_Distance(&theNode->Coord, &gPlayerInfo[gCurrentSplitScreenPane].coord) * .12f;
			if (size > 600.0f)
				size = 600.0f;

			if (size > 110.0f)
			{
				OGLMatrix4x4	m;

				SetLookAtMatrixAndTranslate(&m, &gUp, &theNode->Coord, &gPlayerInfo[gCurrentSplitScreenPane].camera.cameraLocation);

				OGL_PushState();
				glMultMatrixf(m.value);

				MO_DrawMaterial(gSpriteGroupList[SPRITE_GROUP_INFOBAR][INFOBAR_SObjType_GunSight_OuterRing].materialObject);		// activate material

				OGL_DisableCullFace();
				OGL_DisableLighting();
				OGL_DisableFog();
				gGlobalTransparency = 1.0f;

				glBegin(GL_QUADS);
				glTexCoord2f(0,0);	glVertex2f(-size, -size);
				glTexCoord2f(0,1);	glVertex2f(-size, size);
				glTexCoord2f(1,1);	glVertex2f(size, size);
				glTexCoord2f(1,0);	glVertex2f(size, -size);
				glEnd();

				OGL_PopState();
			}
		}
	}
}

#pragma mark -


/********************** DO PLAYER FLIGHT CONTROLS ************************/
//
// Handles the flight controls for the player based on the analogControl values.
//

static void DoPlayerFlightControls(ObjNode *player)
{
float	sideBank, rotZ, pull, rotX, pitch;
float	fps = gFramesPerSecondFrac;
short	playerNum = player->PlayerNum;


			/* SEE IF CONTROL IS ALLOWED RIGHT NOW */

	if (gVSMode == VS_MODE_RACE)							// don't allow control while doing read-set-go for race start
		if (gRaceReadySetGoTimer > 0.0f)
			return;


			/*******************/
			/* DO SIDE-BANKING */
			/*******************/

	sideBank = gPlayerInfo[playerNum].analogControlX;
	rotZ = player->Rot.z;


			/* PULL BACK TO ZERO */


	if (fabs(sideBank) < .1f)								// only pull back if user isn't controlling
	{
		pull = fabs(rotZ) * 1.5f;							// calc amount of roll-back based on z-rotaton:  more snap-back the steeper the rotation
		if (pull < .1f)
			pull = .1f;
		pull *= fps;

		if (rotZ > 0.0f)
		{
			rotZ -= pull;
			if (rotZ < 0.0f)
				rotZ = 0.0f;
		}
		else
		{
			rotZ += pull;
			if (rotZ > 0.0f)
				rotZ = 0.0f;
		}
	}

			/* ROTATE BASED ON USER DELTA */

	rotZ += sideBank * fps * -1.8f;


			/* CHECK FOR MAX PINNING */

	if (rotZ > MAX_FLIGHT_Z_ROT)
		rotZ = MAX_FLIGHT_Z_ROT;
	else
	if (rotZ < -MAX_FLIGHT_Z_ROT)
		rotZ = -MAX_FLIGHT_Z_ROT;

	player->Rot.z = rotZ;


		/****************/
		/* DO PITCH-YAW */
		/****************/

	pitch = gPlayerInfo[playerNum].analogControlZ;
	if (pitch > 0)
		if (gCoord.y > (CalcPlayerMaxAltitude(gCoord.x, gCoord.z) - 150.0f)) // see if we're near the max altitude
			pitch = 0;

	rotX = player->Rot.x;


			/* PULL BACK TO ZERO */

	if (fabs(pitch) < .1f)
	{
		pull = fabs(rotX) * .8f;							// calc amount of roll-back based on x-rotaton:  more snap-back the steeper the rotation
		pull *= fps;

		if (rotX > 0.0f)
		{
			rotX -= pull;
			if (rotX < 0.0f)
				rotX = 0.0f;
		}
		else
		{
			rotX += pull;
			if (rotX > 0.0f)
				rotX = 0.0f;
		}
	}

			/* ROTATE BASED ON USER DELTA */

	rotX += pitch * fps * 1.4f;


			/* CHECK FOR MAX PINNING */

	if (rotX > (PI/3))
		rotX = PI/3;
	else
	if (rotX < (-PI/1.9))
		rotX = -PI/1.9;

	player->Rot.x = rotX;


		/**********************/
		/* DO Y-AXIS ROTATION */
		/**********************/

	player->Rot.y += rotZ * fps * FLIGHT_TURN_SENSITIVITY;



	UpdateObjectTransforms(player);							// update the matrix so that it's accurate when we do our move

}

/**************** CHECK PLAYER ACTION CONTROLS ***************/
//
// Checks for special action controls
//
// INPUT:	theNode = the node of the player
//

static void CheckPlayerActionControls(ObjNode *player)
{
short	playerNum = player->PlayerNum;

			/* SEE IF CONTROL IS ALLOWED RIGHT NOW */

	if (gVSMode == VS_MODE_RACE)							// don't allow control while doing read-set-go for race start
		if (gRaceReadySetGoTimer > 0.0f)
			return;


			/**********************************/
			/* SEE IF CHANGE WEAPON SELECTION */
			/**********************************/

				/* SEE IF SELECT NEXT WEAPON */

	if (IsNeedDown(kNeed_NextWeapon, playerNum))			// is Next button pressed?
	{
		SelectNextWeapon(playerNum, true, 1);
		gAutoFireDelay[playerNum] = 0;
	}
	else if (IsNeedDown(kNeed_PrevWeapon, playerNum))
	{
		SelectNextWeapon(playerNum, true, -1);
		gAutoFireDelay[playerNum] = 0;
	}


			/**************************/
			/* SEE IF NEW FIRE BUTTON */
			/**************************/

	switch (GetNeedState(kNeed_Fire, playerNum))
	{
		case KEYSTATE_DOWN:
			PlayerFireButtonPressed(player, true);			// pass the newButtonPressed flag for handlers that don't auto-fire
			break;
		case KEYSTATE_HELD:
			PlayerFireButtonPressed(player, false);
			break;
		case KEYSTATE_UP:
			PlayerFireButtonReleased(player);
			break;
		default:
			gAutoFireDelay[playerNum] = 0;					// not pressing Fire button, so clear auto-fire delay timer
	}

			/*************************/
			/* SEE IF JETPACK BUTTON */
			/*************************/

	if (IsNeedActive(kNeed_Jetpack, playerNum))				// is jetpack button pressed?
		PlayerJetpackButtonPressed(player, playerNum);
	else
		JetpackOff(playerNum);

}

#pragma mark -


/***************** PLAYER JETPACK BUTTON PRESSED ************************/

static void PlayerJetpackButtonPressed(ObjNode *player, short playerNum)
{
float	fps = gFramesPerSecondFrac;

			/* DO WE HAVE FUEL? */

	if (gPlayerInfo[playerNum].jetpackFuel <= 0.0f)
	{
		JetpackOff(playerNum);
		return;
	}


			/* IF NEW THEN MAKE POOF */
	if (!gPlayerInfo[playerNum].jetpackActive)
	{
		PlayEffect_Parms3D(EFFECT_JETPACKIGNITE, &gCoord, NORMAL_CHANNEL_RATE, .7);
#if 0
		{
			OGLPoint3D	buttPt;
			ObjNode		*jetpack = player->ChainNode;

			OGLPoint3D_Transform(&gJetpackButtOff, &jetpack->BaseTransformMatrix, &buttPt);		// calc butt coord where smoke comes from

			MakePuff(3, &buttPt, 7.0, PARTICLE_SObjType_BlackSmoke, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, 1.0);
		}
#endif

		gPlayerInfo[playerNum].jetpackRumbleCooldown = 0;
	}

			/* BURN FUEL */

	gPlayerInfo[playerNum].jetpackFuel -= fps * .05f;
	if (gPlayerInfo[playerNum].jetpackFuel < 0.0f)
		gPlayerInfo[playerNum].jetpackFuel = 0.0f;


	gTargetMaxSpeed[playerNum] = PLAYER_JETPACK_MAX_SPEED;

	player->Speed += 1000.0f * fps;

	gPlayerInfo[playerNum].jetpackActive = true;


				/* UPDATE EFFECT */

	if (player->EffectChannel == -1)
		player->EffectChannel = PlayEffect_Parms3D(EFFECT_JETPACKHUM, &gCoord, NORMAL_CHANNEL_RATE, 1.0);
	else
		Update3DSoundChannel(EFFECT_JETPACKHUM, &player->EffectChannel, &gCoord);


			/* FORCE FEEDBACK */

	gPlayerInfo[playerNum].jetpackRumbleCooldown -= gFramesPerSecondFrac;
	if (gPlayerInfo[playerNum].jetpackRumbleCooldown <= 0)
	{
		PlayRumbleEffect(EFFECT_JETPACKHUM, playerNum);
		gPlayerInfo[playerNum].jetpackRumbleCooldown = 0.100f;	// should match duration of rumble effect in sound.c
	}


}


/********************* JETPACK OFF ***************************/
//
// Called once per frame when jetpack is off.
//

void JetpackOff(short playerNum)
{
ObjNode	*player = gPlayerInfo[playerNum].objNode;

	gPlayerInfo[playerNum].jetpackActive = false;

	StopAChannelIfEffectNum(&player->EffectChannel, EFFECT_JETPACKHUM);		// stop jetpack sfx


			/* DECELERATE TO NORMAL MAX SPEED */

	gTargetMaxSpeed[playerNum] = PLAYER_NORMAL_MAX_SPEED;
}


/******************* MOVE PLAYER JETPACK **************************/
//
// Called to align jetpack on the player's body.
//

void MovePlayerJetpack(ObjNode *jetpack)
{
ObjNode	*player = jetpack->ChainHead;
ObjNode	*blue = jetpack->ChainNode;
short	i,j;
float	fps = gFramesPerSecondFrac;
short	playerNum = player->PlayerNum;
OGLMatrix4x4	m;

			/* SET MATRIX */

	FindJointFullMatrix(player, 0, &m);
	m.value[M13] += 3.0f;							// offset y a tad to help alignment
	jetpack->BaseTransformMatrix = m; //player->BaseTransformMatrix;
	SetObjectTransformMatrix(jetpack);


			/* UPDATE COORD */

	jetpack->Coord.x = jetpack->BaseTransformMatrix.value[M03];
	jetpack->Coord.y = jetpack->BaseTransformMatrix.value[M13];
	jetpack->Coord.z = jetpack->BaseTransformMatrix.value[M23];


			/* UPDATE GUN TURRET SPARKLES */

	for (j = 0; j < 2; j++)
	{
		i = jetpack->Sparkles[j];
		if (i != -1)
		{
			gSparkles[i].scale 	-= fps * 90.0f;
			if (gSparkles[i].scale < 15.0f)
				gSparkles[i].scale = 15.0f;
		}
	}


		/***************/
		/* UPDATE BLUE */
		/***************/

	blue->TextureTransformV -= fps * 1.5f;
	blue->TextureTransformU -= fps * .2f;

			/* SET MATRIX */

	blue->BaseTransformMatrix = m; //player->BaseTransformMatrix;
	SetObjectTransformMatrix(blue);


			/* UPDATE COORD */

	blue->Coord = jetpack->Coord;


		/********************/
		/* MAKE JET EXHAUST */
		/********************/

	if (gPlayerInfo[playerNum].jetpackActive)
	{
		MakeJetpackExhaust(jetpack);
	}
	else
	if (jetpack->Sparkles[2] != -1)
	{
		DeleteSparkle(jetpack->Sparkles[2]);
		jetpack->Sparkles[2] = -1;
	}
}


/*********************** MAKE JETPACK EXHAUST **************************/

static void MakeJetpackExhaust(ObjNode *jetpack)
{
OGLPoint3D			buttPt;

			/************************/
			/* MAKE EXHAUST SPARKLE */
			/************************/

	if (jetpack->Sparkles[2] == -1)
	{
		int i = jetpack->Sparkles[2] = GetFreeSparkle(jetpack);			// make new sparkle
		if (i != -1)
		{
			gSparkles[i].flags = SPARKLE_FLAG_TRANSFORMWITHOWNER | SPARKLE_FLAG_FLICKER | SPARKLE_FLAG_RANDOMSPIN;
			gSparkles[i].where = gJetpackButtOff;

			gSparkles[i].color.r = 1;
			gSparkles[i].color.g = 1;
			gSparkles[i].color.b = 1;
			gSparkles[i].color.a = 1;

			gSparkles[i].aim.x = 0;
			gSparkles[i].aim.y = 0;
			gSparkles[i].aim.z = 1;

			gSparkles[i].scale 	= 100.0f;
			gSparkles[i].separation = 50.0f;

			gSparkles[i].textureNum = PARTICLE_SObjType_RedGlint;
		}
	}

			/*********************/
			/* LEAVE FLAME TRAIL */
			/*********************/

	jetpack->ParticleTimer -= gFramesPerSecondFrac;
	if (jetpack->ParticleTimer <= 0.0f)
	{
		int						particleGroup,magicNum;
		NewParticleGroupDefType	groupDef;
		NewParticleDefType		newParticleDef;
		OGLVector3D				d;
		OGLPoint3D				p;

		jetpack->ParticleTimer += .02f;												// reset timer

		OGLPoint3D_Transform(&gJetpackButtOff, &jetpack->BaseTransformMatrix, &buttPt);		// calc butt coord where smoke comes from


		particleGroup 	= jetpack->ParticleGroup;
		magicNum 		= jetpack->ParticleMagicNum;

		if ((particleGroup == -1) || (!VerifyParticleGroupMagicNum(particleGroup, magicNum)))
		{
			jetpack->ParticleMagicNum = magicNum = MyRandomLong();			// generate a random magic num

			groupDef.magicNum				= magicNum;
			groupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
			groupDef.flags					= PARTICLE_FLAGS_DONTCHECKGROUND | PARTICLE_FLAGS_ALLAIM;
			groupDef.gravity				= 0;
			groupDef.magnetism				= 0;
			groupDef.baseScale				= 15;
			groupDef.decayRate				=  .6;
			groupDef.fadeRate				= 1.3;
			groupDef.particleTextureNum		= PARTICLE_SObjType_RedFumes;
			groupDef.srcBlend				= GL_SRC_ALPHA;
			groupDef.dstBlend				= GL_ONE;
			jetpack->ParticleGroup = particleGroup = NewParticleGroup(&groupDef);
		}

		if (particleGroup != -1)
		{
			for (int i = 0; i < 2; i++)
			{
				d.x = RandomFloat2() * 10.0f;
				d.y = RandomFloat2() * 10.0f;
				d.z = RandomFloat2() * 10.0f;

				p.x = buttPt.x + d.x * .6f;
				p.y = buttPt.y + d.y * .6f;
				p.z = buttPt.z + d.z * .6f;

				newParticleDef.groupNum		= particleGroup;
				newParticleDef.where		= &p;
				newParticleDef.delta		= &d;
				newParticleDef.scale		= 1.0f + RandomFloat() * 1.0f;
				newParticleDef.rotZ			= RandomFloat() * PI2;
				newParticleDef.rotDZ		= RandomFloat2() * 3.0f;
				newParticleDef.alpha		= .4f + RandomFloat() * .1f;
				if (AddParticleToGroup(&newParticleDef))
				{
					jetpack->ParticleGroup = -1;
					break;
				}
			}
		}
	}




}



#pragma mark -


/******************* DO PLAYER MOVEMENT AND COLLISION DETECT *********************/
//
// OUTPUT: true if disabled or killed
//

static Boolean DoPlayerMovementAndCollision(ObjNode *theNode, Boolean useBBoxForTerrain)
{
float				fps = gFramesPerSecondFrac,terrainY;
static const OGLVector3D forward = {0,0,-1};
OGLVector3D			aim, deltaVec;
Boolean				killed = false;
float				f, oneMinusF;
short				playerNum = theNode->PlayerNum;
float				speed;

			/*****************************/
			/* ACCEL IN DIRECTION OF AIM */
			/*****************************/

			/* GET AIM & MOTION VECTORS */

	OGLVector3D_Transform(&forward, &theNode->BaseTransformMatrix, &aim);	// calc aim vector - the direction we want to be moving
	FastNormalizeVector(gDelta.x, gDelta.y, gDelta.z, &deltaVec);			// calc current motion vector


		/* CALC INTERPOLATION BETWEEN AIM & MOTION */

	f = FLIGHT_SLIDE_FACTOR * fps;										// calc interpolation % from 0 to 1
	if (f > 1.0f)
		f = 1.0f;
	oneMinusF = 1.0f - f;

	deltaVec.x = (deltaVec.x * oneMinusF) + (aim.x * f);				// interpolate it
	deltaVec.y = (deltaVec.y * oneMinusF) + (aim.y * f);
	deltaVec.z = (deltaVec.z * oneMinusF) + (aim.z * f);


			/* ACCELERATE / DECELERATE */

	theNode->Speed = DecayToZero(theNode->Speed, fps * fabs(theNode->Rot.z) * 100.0f);	// friction based on z-rot banking

	theNode->Speed -= deltaVec.y * 300.0f * fps;						// up/down friction
	if (theNode->Speed > gCurrentMaxSpeed[playerNum])
		theNode->Speed = gCurrentMaxSpeed[playerNum];
	else
	if (theNode->Speed < PLAYER_MIN_SPEED)
		theNode->Speed = PLAYER_MIN_SPEED;


			/* SET DELTA */

	speed = theNode->Speed;
	gDelta.x = deltaVec.x * speed;							// apply new motion vector to our deltas with speed
	gDelta.y = deltaVec.y * speed;
	gDelta.z = deltaVec.z * speed;



			/* CHECK MAX ALTITUDE */
			//
			// As the player approaches the max ceiling, we decay the Delta.y value
			// based on the distance to the max y.  This should give us a nice smooth
			// ceiling instead of a sudden stop at max_y.
			//


	if (gDelta.y > 0.0f)
	{
		float	maxAlt, diff;

		maxAlt = CalcPlayerMaxAltitude(gCoord.x, gCoord.z);

		diff = maxAlt - gCoord.y;							// calc dist to MAX Y

		if (diff < 0.0f)											// if over max, then just pin y value to max
			gCoord.y = maxAlt;
		else
		if (diff < 300.0f)											// are we within our decay calculation range?
		{
			diff = 30.0f / diff;									// this does the decay calc

			gDelta.y -= gDelta.y * diff;							// decay delta.y
			if (gDelta.y < 0.0f)
				gDelta.y = 0;

		}
	}


				/* MOVE IT */

	gCoord.x += gDelta.x * fps;
	gCoord.y += gDelta.y * fps;
	gCoord.z += gDelta.z * fps;


			/* DO OBJECT COLLISION DETECT */

	if (DoPlayerCollisionDetect(theNode, useBBoxForTerrain))
	{
		killed = true;
	}



				/*************************/
				/* CHECK FENCE COLLISION */
				/*************************/

	if (DoFenceCollision(theNode))
	{
		killed = true;
		KillPlayer(playerNum, PLAYER_DEATH_TYPE_EXPLODE, &gCoord);
	}


				/********************************/
				/* CHECK LINE-SEGMENT COLLISION */
				/********************************/

	DoPlayerLineSegmentCollision(theNode);


				/* CHECK FLOOR */

	terrainY = GetTerrainY(gCoord.x, gCoord.z);
	gPlayerInfo[playerNum].distToFloor = gCoord.y + theNode->LocalBBox.min.y - terrainY;				// calc dist to floor




	return(killed);
}


/********************* DO PLAYER LINE SEGMENT COLLISION ************************/

static void DoPlayerLineSegmentCollision(ObjNode *player)
{
OGLLineSegment	lineSeg;
ObjNode	*hitObj;
OGLPoint3D	hitPt;
short		i;
static short	joints[2][2] =
{
	{PLAYER_JOINT_LEFT_WING3, PLAYER_JOINT_RIGHT_WING3},
	{PLAYER_JOINT_JAW, PLAYER_JOINT_EGGHOLD},
};


				/* TEST VARIOUS LINE SEGMENTS FOR COLLISION */

	for (i = 0; i < 2; i++)
	{

				/* CALC LINE SEGMENT BETWEEN JOINTS */

		FindCoordOfJoint(player, joints[i][0], &lineSeg.p1);
		FindCoordOfJoint(player, joints[i][1], &lineSeg.p2);

		gPickAllTrianglesAsDoubleSided = true;
		hitObj = OGL_DoLineSegmentCollision_ObjNodes(&lineSeg, STATUS_BIT_HIDDEN, CTYPE_PLAYERTEST, &hitPt, nil, nil, true);
		gPickAllTrianglesAsDoubleSided = false;

		if (hitObj)
		{
			if (hitObj->TriggerCallback)								// call hit obj's trigger func if any
			{
				hitObj->TriggerCallback(hitObj, player);
			}
			else
			if (gPlayerInfo[player->PlayerNum].invincibilityTimer <= 0.0f)	// otherwise, just kill player
				KillPlayer(player->PlayerNum, PLAYER_DEATH_TYPE_EXPLODE, &gCoord);

			return;
		}
	}
}



/******************** DO PLAYER COLLISION DETECT **************************/
//
// Standard collision handler for player
//
// OUTPUT: true = disabled/killed
//

static Boolean DoPlayerCollisionDetect(ObjNode *theNode, Boolean useBBoxForTerrain)
{
short		i;
ObjNode		*hitObj;
float		distToFloor, terrainY, fps = gFramesPerSecondFrac;
float		bottomOff;
Boolean		killed = false;
short		playerNum = theNode->PlayerNum;
uint32_t		ctype;

			/***************************************/
			/* AUTOMATICALLY HANDLE THE GOOD STUFF */
			/***************************************/
			//
			// this also sets the ONGROUND status bit if on a solid object.
			//

	if (useBBoxForTerrain)
		theNode->BottomOff = theNode->LocalBBox.min.y;
	else
		theNode->BottomOff = gPlayerBottomOff;

	ctype = PLAYER_COLLISION_CTYPE;								// get default ctypes
	ctype |= CTYPE_PLAYER2 >> playerNum;						// and also check for other player

				/* CALL DEFAULT HANDLER */

	HandleCollisions(theNode, ctype, -.2);

	killed = gPlayerIsDead[playerNum];							// see if player was killed during that


			/* SCAN FOR INTERESTING STUFF */

	for (i=0; i < gNumCollisions; i++)
	{
		if (gCollisionList[i].type == COLLISION_TYPE_OBJ)
		{
			hitObj = gCollisionList[i].objectPtr;				// get ObjNode of this collision

			if (hitObj->CType == INVALID_NODE_FLAG)				// see if has since become invalid
				continue;



			/* CHECK FOR TOTALLY IMPENETRABLE */

			if (hitObj->CBits & CBITS_IMPENETRABLE2)
			{
				if (!(gCollisionList[i].sides & SIDE_BITS_BOTTOM))	// dont do this if we landed on top of it
				{
					gCoord.x = theNode->OldCoord.x;					// dont take any chances, just move back to original safe place
					gCoord.z = theNode->OldCoord.z;
				}
			}
		}
	}

		/*************************************/
		/* CHECK & HANDLE TERRAIN  COLLISION */
		/*************************************/

	if (useBBoxForTerrain)
		bottomOff = theNode->LocalBBox.min.y;							// use bbox for bottom
	else
		bottomOff = theNode->BottomOff;								// use collision box for bottom

	terrainY =  GetTerrainY(gCoord.x, gCoord.z);					// get terrain Y

	distToFloor = (gCoord.y + bottomOff) - terrainY;				// calc amount I'm above or under

	if (distToFloor <= 0.0f)										// see if on or under floor
	{
		float   dot;
		gCoord.y = terrainY - bottomOff;
		theNode->StatusBits |= STATUS_BIT_ONGROUND;

				/* SEE IF HIT GROUND HEAD-ON OR SQUEEZED TO MAX ALTITUDE */

		if (gCoord.y > MAX_ALTITUDE)									// kaboom is squeezed
			goto kaboom;

		dot = OGLVector3D_Dot(&theNode->MotionVector, &gRecentTerrainNormal);   // see if smacked into terrain

		if ((dot < -.6f) && (!gGamePrefs.kiddieMode))			// if hit head-on & not in kiddie mode
		{
kaboom:
			killed |= PlayerLoseHealth(playerNum, 1.1, PLAYER_DEATH_TYPE_EXPLODE, &gCoord, true);
		}

				/* NOT SO HARD */
		else
		{
			if (gDelta.y < -200.0f)
				killed |= PlayerLoseHealth(playerNum, fps * .1f, PLAYER_DEATH_TYPE_EXPLODE, &gCoord, true);

			DoPlayerGroundScrape(theNode, playerNum);

				/* GROUND SCRAPE FORCE FEEDBACK */

			if (!killed)
			{
				gPlayerInfo[playerNum].groundScrapeRumbleCooldown -= fps;
				if (gPlayerInfo[playerNum].groundScrapeRumbleCooldown <= 0)
				{
					gPlayerInfo[playerNum].groundScrapeRumbleCooldown = 0.1;
					Rumble(0.8f, 0.5f, 100, playerNum);
				}
			}
		}

		gDelta.y *= -.1f;
	}

			/****************************/
			/* SEE IF HIT WATER SURFACE */
			/****************************/

	if (!killed && (gDelta.y <= 0.0f))							// only check water if moving down and not killed yet
	{
		int		patchNum;
		Boolean	wasInWater;

		if (theNode->StatusBits & STATUS_BIT_UNDERWATER)		// remember if was in water to begin with
			wasInWater = true;
		else
			wasInWater = false;


					/* CHECK IF IN WATER NOW */

		if (DoWaterCollisionDetect(theNode, gCoord.x, gCoord.y+theNode->BottomOff, gCoord.z, &patchNum))
		{
			short		waterType;
			Boolean		isLava;
			float		waterY = gWaterBBox[patchNum].max.y;
			OGLPoint3D	splashPt;

			gCoord.y = waterY - theNode->BottomOff;				// keep player on surface

			waterType = gWaterList[patchNum].type;
			isLava = (waterType >= WATER_TYPE_LAVA) && (waterType <= WATER_TYPE_LAVA_DIR7);		// see if this is lava


					/* SEE IF HIT WATER HARD */

			if (gDelta.y < -400.0f)
			{
				killed |= PlayerLoseHealth(playerNum, 1.1, PLAYER_DEATH_TYPE_EXPLODE, &gCoord, true);

				splashPt.x = gCoord.x;
				splashPt.y = waterY;
				splashPt.z = gCoord.z;
				MakeSplash(&splashPt, 1.2);
			}


				/* KEEP LEVEL ON WATER */
				//
				// When skimming the water we don't want the wings and things dipping into it, so force
				// the player to level out flat.
				//

			else
			{
						/* SEE IF HIT LAVA */

				if (isLava)
					killed |= PlayerLoseHealth(playerNum, fps * 1.0f, PLAYER_DEATH_TYPE_EXPLODE, &gCoord, true);


				theNode->Rot.z = DecayToZero(theNode->Rot.z, PI2 * fps);

				if (theNode->Rot.x < 0.0f)
					theNode->Rot.x = DecayToZero(theNode->Rot.x, PI2 * fps);
			}


				/* MAKE SPLASH IF THIS IS A FIRST TOUCH OF THE WATER */

			if (!isLava)							// no splashing for lava
			{
				if (!wasInWater)
				{
					splashPt.x = gCoord.x;
					splashPt.y = waterY;
					splashPt.z = gCoord.z;
					MakeSplash(&splashPt, 1.0);
				}

						/* OTHERWISE JUST UPDATE RIPPLES BEHIND US */
				else
				{
					gPlayerInfo[playerNum].waterRippleTimer -= fps;
					if (gPlayerInfo[playerNum].waterRippleTimer <= 0.0f)
					{
						gPlayerInfo[playerNum].waterRippleTimer += .05f;
						splashPt.x = gCoord.x;
						splashPt.y = waterY;
						splashPt.z = gCoord.z;
						CreateNewRipple(&splashPt, 12.0f, 40.0f, 1.0f);
					}
					SprayWater(theNode, gCoord.x, waterY, gCoord.z);
				}
			}

			gDelta.y = 0;
		}
	}

	return(killed);
}


/***************** PLAYER SMACKED INTO OBJECT ************************/
//
// Returns true if player was killed by impact
//

Boolean PlayerSmackedIntoObject(ObjNode *player, ObjNode *hitObj, short deathType)
{
OGLVector2D	pv, ov;
float		r;


		/********************************************/
		/* HANDLE SPECIAL STUFF BASED ON DEATH TYPE */
		/********************************************/

	switch(deathType)
	{
		case	PLAYER_DEATH_TYPE_DEATHDIVE:

					/* DETERMINE WHAT ANGLE TO BOUNCE */

				r = player->Rot.y;
				pv.x = sin(r);
				pv.y = cos(r);

				ov.x = hitObj->Coord.x - gCoord.x;
				ov.y = hitObj->Coord.z - gCoord.z;
				FastNormalizeVector2D(ov.x, ov.y, &ov, true);

				if (OGLVector2D_Cross(&ov, &pv) > 0.0f)
					player->Rot.y += PI/9;
				else
					player->Rot.y -= PI/9;

				player->Rot.x *= 1.0f + RandomFloat2() * .2f;


			//	player->Speed *= .8f;							// slow speed

				MakeSparkExplosion(&gCoord, 200, 1.0, PARTICLE_SObjType_RedSpark, 100, 1.0);
				break;

		case	PLAYER_DEATH_TYPE_EXPLODE:
				break;

	}

			/***************/
			/* KILL PLAYER */
			/***************/

	if (gPlayerInfo[player->PlayerNum].invincibilityTimer <= 0.0f)
		KillPlayer(player->PlayerNum, deathType, &gCoord);
	return(true);
}


#pragma mark -


/****************** SET PLAYER FLYING ANIM *********************/

void SetPlayerFlyingAnim(ObjNode *player)
{
short	currentAnim = player->Skeleton->AnimNum;
short	desiredAnim = -1;
float	dist, bestDist = 100000000;
float	dot;
ObjNode	*thisNodePtr;

			/***********************************/
			/* SEE IF SHOULD GO INTO GRAB ANIM */
			/***********************************/

	if (gFirstNodePtr == nil)								// see if there are any objects
		return;

			/* SCAN THRU ALL OBJECTS LOOKING FOR SOMETHING TO PICKUP */

	thisNodePtr = gFirstNodePtr;

	do
	{
		if (thisNodePtr->CType & (CTYPE_POWERUP | CTYPE_EGG))
		{
				/* IS IT IN RANGE? */

			dist = OGLPoint3D_Distance(&gCoord, &thisNodePtr->Coord);
			if ((dist < bestDist) && (dist < 900.0f))					// see if this is in range & is closest so far
			{
				OGLVector3D	v;

					/* ARE WE AIMED AT IT? */

				v.x = thisNodePtr->Coord.x - gCoord.x;					// calc vector to node
				v.y = thisNodePtr->Coord.y - gCoord.y;
				v.z = thisNodePtr->Coord.z - gCoord.z;
				FastNormalizeVector(v.x, v.y, v.z, &v);

				dot = OGLVector3D_Dot(&v, &player->MotionVector);
				if (dot > -.1f)
				{
					desiredAnim = PLAYER_ANIM_READY2GRAB;
					bestDist = dist;
				}
			}
		}

		thisNodePtr = thisNodePtr->NextNode;							// next node
	}
	while (thisNodePtr != nil);



		/****************************************/
		/* SEE WHICH GENERAL FLIGHT ANIM TO USE */
		/****************************************/

	if (desiredAnim != PLAYER_ANIM_READY2GRAB)						// do we want to be grabbing?
	{

				/* SEE IF BANKING RIGHT */

		if (player->Rot.z < (-PI/7))
			desiredAnim = PLAYER_ANIM_BANKRIGHT;


				/* SEE IF BANKING LEFT */

		else
		if (player->Rot.z > (PI/7))
			desiredAnim = PLAYER_ANIM_BANKLEFT;


				/* FLAP / COAST */
		else
		{
			switch(currentAnim)
			{
				case	PLAYER_ANIM_FLAP:						// if currently flapping, then see if time to coast
						player->FlapCoastTimer -= gFramesPerSecondFrac;
						if (player->FlapCoastTimer <= 0.0f)
						{
							desiredAnim = PLAYER_ANIM_COASTING;
							player->FlapCoastTimer = 2.0f + RandomFloat() * 3.0f;
						}
						else
							desiredAnim = PLAYER_ANIM_FLAP;
						break;

				case	PLAYER_ANIM_COASTING:						// if currently coasting, then see if time to flap
						player->FlapCoastTimer -= gFramesPerSecondFrac;
						if (player->FlapCoastTimer <= 0.0f)
						{
do_flap:
							desiredAnim = PLAYER_ANIM_FLAP;
							player->FlapCoastTimer = 1.0f + RandomFloat() * 3.0f;
						}
						else
							desiredAnim = PLAYER_ANIM_COASTING;
						break;

				default:											// coming out of another anim, so always flap
						goto do_flap;


			}
		}
	}

	if (desiredAnim != currentAnim)
		MorphToSkeletonAnim(player->Skeleton, desiredAnim, 4.0f);

}


/****************** SET PLAYER FLYING ANIM WITH EGG *********************/

static void SetPlayerFlyingAnim_WithEgg(ObjNode *player)
{
short	currentAnim = player->Skeleton->AnimNum;
short	desiredAnim = -1;

			/* SEE IF BANKING RIGHT */

	if (player->Rot.z < (-PI/7))
		desiredAnim = PLAYER_ANIM_BANKRIGHTEGG;


			/* SEE IF BANKING LEFT */

	else
	if (player->Rot.z > (PI/7))
		desiredAnim = PLAYER_ANIM_BANKLEFTEGG;


			/* FLAP */
	else
		desiredAnim = PLAYER_ANIM_FLAPWITHEGG;


	if (desiredAnim != currentAnim)
		MorphToSkeletonAnim(player->Skeleton, desiredAnim, 3.0f);

}


#pragma mark -


/************************ HANDLE PLAYER LINE MARKER CROSSING ************************/

void	HandlePlayerLineMarkerCrossing(ObjNode *player)
{
long	markerNum;

			/* SEE IF CROSSED ANY LINE MARKERS */

	if (!SeeIfCrossedLineMarker(player, &markerNum))
		return;



			/* SET CHECKPOINT */

	SetReincarnationCheckpointAtMarker(player, markerNum);
}


/******************** SET REINCARNATION CHECKPOINT AT MARKER *******************/

void SetReincarnationCheckpointAtMarker(ObjNode *player, short markerNum)
{
short	playerNum = player->PlayerNum;
float	x,z;

			/* CALC CENTER OF THE LINE MARKER */

	x = (gLineMarkerList[markerNum].x[0] + gLineMarkerList[markerNum].x[1]) * .5f;
	z = (gLineMarkerList[markerNum].z[0] + gLineMarkerList[markerNum].z[1]) * .5f;


				/* SET CHECKPOINT INFO */

	gBestCheckpointNum[playerNum] = markerNum;

	gBestCheckpointCoord[playerNum].x = x;
	gBestCheckpointCoord[playerNum].z = z;
	gBestCheckpointCoord[playerNum].y = GetTerrainY(x,z) + MAX_ALTITUDE_DIFF * .95f;		// start as high as we can go

	gBestCheckpointAim[playerNum] = player->Rot.y;
}












