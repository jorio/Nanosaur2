/****************************/
/*   		ITEMS.C		    */
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

static void MoveEgg_NotCarried(ObjNode *egg);
static void MoveEgg_Carried(ObjNode *egg);
static void MoveEgg_IntoWormhole(ObjNode *egg);
static void EggWasRetrieved(ObjNode *egg);
static void MoveNest(ObjNode *nest);
static void PlayerPickedUpEgg(ObjNode *egg, short playerNum);
static void ResetEggToNest(ObjNode *egg);



/****************************/
/*    CONSTANTS             */
/****************************/

#define	EGG_SCALE	6.0f


/*********************/
/*    VARIABLES      */
/*********************/

#define NestHasEgg		Flag[1]						// true when the nest still has an egg sitting in it
#define	CanResetEgg		Flag[0]						// set after a player has moved the egg
#define	ResetEggDelay	SpecialF[0]

#define	Wormhole		SpecialPtr[0]
#define	TargetJoint		Special[1]					// which joint in wormhole to move to
#define	DelayUntilCanPickup	Timer					// delay after dropping egg before it can be picked back up

Byte	gNumEggsToSave[NUM_EGG_TYPES];
Byte	gNumEggsSaved[NUM_EGG_TYPES];


/******************** FIND ALL EGG ITEMS *******************/
//
// Called when terrain is loaded - it counts the total egg inventory for this level.
//

void FindAllEggItems(void)
{
long					i;
TerrainItemEntryType	*itemPtr;
short					eggColor;

			/* INIT EGG COUNTS */

	for (i = 0; i < NUM_EGG_TYPES; i++)
	{
		gNumEggsToSave[i] = 0;
		gNumEggsSaved[i] = 0;
	}


				/* SCAN FOR EGG ITEM */

	itemPtr = gMasterItemList; 									// get pointer to data inside the LOCKED handle

	for (i= 0; i < gNumTerrainItems; i++)
	{
		if (itemPtr[i].type == MAP_ITEM_EGG)						// see if it's an Egg item
		{
			eggColor = itemPtr[i].parm[0];							// egg color # is in parm 0
			if (eggColor >= NUM_EGG_TYPES)
				DoFatalAlert("FindAllEggItems: bad egg color!");

			gNumEggsToSave[eggColor]++;								// inc counter
		}
	}
}




/************************* ADD EGG *********************************/

Boolean AddEgg(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*egg , *nest, *beam;
short	eggColor = itemPtr->parm[0];


		/*************/
		/* MAKE NEST */
		/*************/

	gNewObjectDefinition.group 		= MODEL_GROUP_GLOBAL;
	gNewObjectDefinition.type 		= GLOBAL_ObjType_Nest;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= itemPtr->terrainY;
	gNewObjectDefinition.slot 		= SLOT_OF_DUMB;
	gNewObjectDefinition.moveCall 	= MoveNest;
	gNewObjectDefinition.scale 		= EGG_SCALE;
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits;
	gNewObjectDefinition.rot 		= RandomFloat()*PI2;

	nest = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	nest->TerrainItemPtr = itemPtr;								// keep ptr to item list

	if (!(itemPtr->flags & ITEM_FLAGS_USER1))						// if user flag is set then egg has already been saved, so don't make it
	{
				/************/
				/* MAKE EGG */
				/************/

		gNewObjectDefinition.type 		= GLOBAL_ObjType_RedEgg + eggColor;
		gNewObjectDefinition.slot++;
		gNewObjectDefinition.moveCall 	= MoveEgg_NotCarried;
		egg = MakeNewDisplayGroupObject(&gNewObjectDefinition);

		egg->What = WHAT_EGG;

		egg->Kind = eggColor;										// remember what color of egg this is
		egg->CanResetEgg	 = false;

		egg->InitCoord.y = egg->Coord.y -= egg->LocalBBox.min.y;
		egg->Rot.x = 0; //PI/2;											// rot onto side

		UpdateObjectTransforms(egg);


				/* SET COLLISION STUFF */

		egg->CType 			= CTYPE_EGG;
		egg->CBits			= CBITS_ALLSOLID;
		CreateCollisionBoxFromBoundingBox(egg, 1, 1);

				/* SET HOLD OFFSETS */

		egg->HoldOffset.x = 0;
		egg->HoldOffset.y = 0;
		egg->HoldOffset.z = 0;

		egg->HoldRot.x = 0;
		egg->HoldRot.y = 0;
		egg->HoldRot.z = 0;

		egg->TargetJoint = 0;

		egg->DelayUntilCanPickup = 0;


		nest->ChainNode = egg;
		egg->ChainHead = nest;

		nest->NestHasEgg = true;									// the egg is in the nest


				/*************/
				/* MAKE BEAM */
				/*************/

		gNewObjectDefinition.type 		= GLOBAL_ObjType_EggBeam;
		gNewObjectDefinition.flags 		|= STATUS_BIT_GLOW | STATUS_BIT_NOZWRITES | STATUS_BIT_NOLIGHTING |
										STATUS_BIT_NOFOG;
		gNewObjectDefinition.slot 		= SLOT_OF_DUMB+50;
		gNewObjectDefinition.moveCall 	= nil;
		beam = MakeNewDisplayGroupObject(&gNewObjectDefinition);

//		beam->ColorFilter.a = .2f;

		switch(eggColor)
		{
			case	0:											// red
					beam->ColorFilter.g = beam->ColorFilter.b = .5f;
					break;
			case	1:											// green
					beam->ColorFilter.r = beam->ColorFilter.b = .5f;
					break;
			case	2:											// blue
					beam->ColorFilter.r = beam->ColorFilter.g = .5f;
					break;
			case	3:											// yellow
					beam->ColorFilter.b = .5f;
					break;
			case	4:											// purple
					beam->ColorFilter.g = .5f;
					break;


		}

		egg->ChainNode = beam;

		AttachShadowToObject(egg, SHADOW_TYPE_CIRCULAR, 3, 3, true);
	}



	return(true);													// item was added
}


/********************* MOVE NEST **********************/

static void MoveNest(ObjNode *nest)
{
ObjNode *beam, *egg;


			/* GET BEAM OBJ */

	egg = nest->ChainNode;
	if (egg)
		beam = egg->ChainNode;
	else
		beam = nil;



			/* SEE IF GONE, ONLY IF EGG IS STILL IN THE NEST OR IF EGG WENT THRU WORMHOLE */

	if (nest->NestHasEgg || (beam == nil))
	{
		if (TrackTerrainItem(nest))
		{
			DeleteObject(nest);
			return;
		}
	}

			/***************/
			/* UPDATE BEAM */
			/***************/

	if (beam)
	{
				/* DECAY BEAM IF EGG IS OUT OF NEST */

		if (!nest->NestHasEgg)
		{
			beam->ColorFilter.a -= gFramesPerSecondFrac * .3f;
			if (beam->ColorFilter.a <= 0.0f)
				beam->ColorFilter.a = 0.0f;
		}
				/* UNDULATE THE BEAM */
		else
		{
			beam->SpecialF[0] += gFramesPerSecondFrac * PI;
			beam->ColorFilter.a = .4f + sin(beam->SpecialF[0]) * .1f;
		}
	}

}


#pragma mark -


/********************* MOVE EGG: NOT CARRIED **********************/

static void MoveEgg_NotCarried(ObjNode *egg)
{
short					i;
OGLPoint3D				footCoord;
float					fps = gFramesPerSecondFrac;
uint32_t					onGround = egg->StatusBits & STATUS_BIT_ONGROUND;
ObjNode *nest;

	nest = egg->ChainHead;

	GetObjectInfo(egg);

			/***********/
			/* MOVE IT */
			/***********/

	gDelta.y += -3000.0f * fps;								// gravity

	if (onGround)
	{
		ApplyFrictionToDeltasXZ(300, &gDelta);				// ground friction

		if (nest->NestHasEgg)
			egg->Rot.x = 0;								// keep up
		else
			egg->Rot.x = PI/2;								// keep on side
	}
	else
	{
		ApplyFrictionToDeltasXZ(100, &gDelta);				// air friction
		egg->Rot.x += fps * 1.5f;							// spin in air
	}

			/* MOVE */

	gCoord.x += gDelta.x * fps;
	gCoord.y += gDelta.y * fps;
	gCoord.z += gDelta.z * fps;


			/* COLLISION DETECT */

	HandleCollisions(egg, CTYPE_FENCE | CTYPE_TERRAIN | CTYPE_MISC, .1);


			/********************************************/
			/* SEE IF NEED TO RESET IT BACK TO ITS NEST */
			/********************************************/

	if (egg->CanResetEgg)									// has the egg been picked up before?
	{
		egg->ResetEggDelay -= fps;
		if (egg->ResetEggDelay <= 0.0f)						// is it ok to try resetting now?
		{
			if (egg->ResetEggDelay < -25.0f)				// if we've tried for 25 seconds with no results, then just force it to get reset
				goto force_reset;

			if ((CalcDistanceToClosestPlayer(&gCoord, nil) > 1500.0f) &&		// only reset if players are far enough away & nobody can see it
				IsObjectTotallyCulled(egg))
			{
					/* SEE IF THE HOME POSITION IS ALSO CULLED */

				OGLMatrix4x4	m;
				OGLBoundingBox	*bbox = &egg->LocalBBox;		// get ptr to egg's local-space bbox

				egg->Coord = egg->InitCoord;				// move back to init coord (this gets zapped at update below if bboxvisible() fails)
				UpdateObjectTransforms(egg);
				OGLMatrix4x4_Multiply(&egg->BaseTransformMatrix, &gWorldToFrustumMatrix, &m);

				if (!OGL_IsBBoxVisible(bbox, nil))			// see if it would be culled there
				{
force_reset:
					ResetEggToNest(egg);
				}
			}
		}
	}


		/********************************/
		/* SEE IF PICKED UP BY A PLAYER */
		/********************************/

	egg->DelayUntilCanPickup -= fps;
	if (egg->DelayUntilCanPickup <= 0.0f)									// only allow pickup if timer is ready
	{
		for (i = 0; i < gNumPlayers; i++)
		{
			if (gPlayerIsDead[i])											// dead players can't pick up eggs
				continue;

			if (gPlayerInfo[i].carriedObj == nil)							// is player already carrying anything?
			{
				ObjNode	*player = gPlayerInfo[i].objNode;

					/* SEE IF "HOLD" POINT HITS EGG */

				FindCoordOfJoint(player, PLAYER_JOINT_EGGHOLD, &footCoord);	// get coord of joint
				if (OGLPoint3D_Distance(&footCoord, &gCoord) < 150.0f)		// is coord close enough to egg?
				{
					PlayerPickedUpEgg(egg, i);
					break;
				}
			}
		}
	}


		/* UPDATE */

	UpdateObject(egg);
}


/****************** RESET EGG TO NEST **********************/

static void ResetEggToNest(ObjNode *egg)
{
ObjNode *nest;

	nest = egg->ChainHead;

			/* MOVE BACK TO NEST */

	gCoord = egg->InitCoord;
	gDelta.x = gDelta.y = gDelta.z = 0;


			/* LET NEST KNOW */

	nest->NestHasEgg = true;
}


/********************* PLAYER PICKED UP EGG *************************/

static void PlayerPickedUpEgg(ObjNode *egg, short playerNum)
{
ObjNode *nest;

			/* LET NEST KNOW THE EGG IS GONE */

	nest = egg->ChainHead;
	nest->NestHasEgg = false;


				/* GET THE EGG */

	gPlayerInfo[playerNum].carriedObj = egg;							// give egg to player
	egg->PlayerNum 					= playerNum;						// remember which player has it
	egg->MoveCall 					= MoveEgg_Carried;					// change move call
	egg->CanResetEgg 				= true;								// we can now reset it when needed
	egg->ResetEggDelay 				= 15.0f;
	PlayEffect_Parms3D(EFFECT_GRABEGG, &gCoord, NORMAL_CHANNEL_RATE, .6);
}


/****************** MOVE EGG: CARRIED ********************/


static void MoveEgg_Carried(ObjNode *egg)
{
short			playerNum = egg->PlayerNum;								// which player # is carrying this egg?
ObjNode			*player = gPlayerInfo[playerNum].objNode;				// get holding player obj
short			n;
ObjNode			*wormhole;
static short 	dropNeed[MAX_PLAYERS] = {kNeed_P1_Drop, kNeed_P2_Drop};



			/* ALIGN EGG IN PLAYER'S GRASP */

	UpdateCarriedObject(player, egg);


			/********************************************/
			/* SEE IF AUTOMATICALLY THROW INTO WORMHOLE */
			/********************************************/
			//
			// In addition to having manual control over dropping eggs (see below),
			// the eggs will automatically release themselves from the player's grasp
			// if a wormhole is detected to be within range.
			//


	wormhole = FindClosestEggWormholeInRange(egg->Kind, &egg->Coord);	// find closest in-range wormhole
	if (wormhole)
	{
		ObjNode *nest = egg->ChainHead;

		nest->ChainNode = nil;										// detach egg from the nest
		egg->ChainHead = nil;
		nest->TerrainItemPtr->flags |= ITEM_FLAGS_USER1;			// set flag so nest knows the egg is gone forever

		egg->Wormhole = wormhole;
		egg->MoveCall = MoveEgg_IntoWormhole;
		egg->Delta.x =
		egg->Delta.y =
		egg->Delta.z = 0;
		egg->Speed = player->Speed;
		gPlayerInfo[playerNum].carriedObj = nil;					// player not holding anything
		return;
	}


			/**************************/
			/* SEE IF PLAYER DROP EGG */
			/**************************/

	n = dropNeed[playerNum];											// which need should we test?
	if (gControlNeeds[n].newButtonPress)								// is drop button pressed?
	{
		DropEgg_NoWormhole(playerNum);
	}
}


/******************* DROP EGG : NO WORMHOLE ************************/
//
// Does a generic drop of the egg - when it doesn't need to
// go into a wormhole.
//

void DropEgg_NoWormhole(short playerNum)
{
ObjNode *egg;

	egg = gPlayerInfo[playerNum].carriedObj;							// get egg
	if (egg)
	{
		egg->DelayUntilCanPickup = 1.0f;								// delay until can be picked back up
		egg->MoveCall = MoveEgg_NotCarried;
		egg->Delta.x = gPlayerInfo[playerNum].objNode->Delta.x * .8f;	// match player's delta minus some friction
		egg->Delta.y = gPlayerInfo[playerNum].objNode->Delta.y * .8f;
		egg->Delta.z = gPlayerInfo[playerNum].objNode->Delta.z * .8f;
		gPlayerInfo[playerNum].carriedObj = nil;						// player not holding anything
	}
}



/********************* MOVE EGG: INTO WORMHOLE **********************/

static void MoveEgg_IntoWormhole(ObjNode *egg)
{
float		fps = gFramesPerSecondFrac;
ObjNode		*wormhole = (ObjNode *)egg->Wormhole;
OGLVector3D	v2;
OGLPoint3D	jointCoord;
float		dist, dist2;


	GetObjectInfo(egg);


			/* CALC VECTOR TO JOINT */

	FindCoordOfJoint(wormhole, egg->TargetJoint, &jointCoord);
	v2.x = jointCoord.x - gCoord.x;
	v2.y = jointCoord.y - gCoord.y;
	v2.z = jointCoord.z - gCoord.z;
	OGLVector3D_Normalize(&v2, &v2);

	dist = OGLPoint3D_Distance(&gCoord, &jointCoord);		// get current dist to joint



			/* MOVE IT */

	gDelta.x = v2.x * egg->Speed;							// move toward the joint
	gDelta.y = v2.y * egg->Speed;
	gDelta.z = v2.z * egg->Speed;

	gCoord.x += gDelta.x * fps;
	gCoord.y += gDelta.y * fps;
	gCoord.z += gDelta.z * fps;


			/* SEE IF TIME TO DO NEXT JOINT */

	dist2 = OGLPoint3D_Distance(&gCoord, &jointCoord);
	if ((dist2 > dist) || (dist2 < 40.0f))				// if dist suddenly got larger, then we must have overshot the coord, or see if in range of joint
	{
		egg->TargetJoint++;

		if (egg->TargetJoint == 1)
			PlayEffect3D(EFFECT_EGGINTOWORMHOLE, &gCoord);

		if (egg->TargetJoint >= wormhole->Skeleton->skeletonDefinition->NumBones)
			goto got_it;
	}


	egg->Speed += 500.0f * fps;							// accelerate
	if (egg->Speed > 1500.0f)
		egg->Speed = 1500.0f;

	egg->Rot.x += fps * 4.5f;
	egg->Rot.z += fps * 2.4f;



		/* SHRINK AWAY */

	if (egg->TargetJoint > 0)					// only shrink once reached wormhole mouth
	{
		egg->Scale.x =
		egg->Scale.y =
		egg->Scale.z -= fps * .5f;
		if (egg->Scale.x <= 0.0f)
		{
got_it:
			EggWasRetrieved(egg);
			return;
		}
	}
		/* UPDATE */

	UpdateObject(egg);
}



/****************** EGG WAS RETREIVED ***************************/
//
// Called after an egg has completed its travel thru the wormhole,
// and now we're ready to count it as saved.
//

static void EggWasRetrieved(ObjNode *egg)
{
short	i;
Boolean	gotAllEggs = true;

			/* INC COUNTER */

	gNumEggsSaved[egg->Kind]++;


		/**************************************/
		/* SEE IF WE GOT ALL THE EGGS WE NEED */
		/**************************************/

	switch(gVSMode)
	{
				/* HANDLE REGULAR ADVENTURE MODE */

		case	VS_MODE_NONE:
				for (i = 0; i < NUM_EGG_TYPES; i++)
				{
					if (gNumEggsToSave[i] > 0)								// do we need to get this color?
					{
						if (gNumEggsSaved[i] < gNumEggsToSave[i])			// did we get them all?
						{
							gotAllEggs = false;
							break;
						}
					}
				}

				if (gotAllEggs)
					gOpenPlayerWormhole = true;

				break;


				/* CAPTURE THE FLAG MODE */

		case	VS_MODE_CAPTURETHEFLAG:
				if (gLevelCompleted)						// ignore any more eggs if someone already won
					break;

						/* SEE IF PLAYER 1 WON */

				if (gNumEggsSaved[1] >= gNumEggsToSave[1])			// did we get all of P2's eggs?
				{
					ShowWinLose(0, 0);					// won!
					ShowWinLose(1, 1);					// lost
					StartLevelCompletion(5.0f);
				}
						/* SEE IF PLYAER 2 WON */

				else
				if (gNumEggsSaved[0] >= gNumEggsToSave[0])			// did we get all of P1's eggs?
				{
					ShowWinLose(1, 0);					// won!
					ShowWinLose(0, 1);					// lost
					StartLevelCompletion(5.0f);
				}
				break;
	}


	DeleteObject(egg);			// note: also deletes the light beam that's chained onto this
}







