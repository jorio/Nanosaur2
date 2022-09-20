/****************************/
/*   ENEMY: RAPTOR.C		*/
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/

#include "game.h"

extern	NewObjectDefinitionType	gNewObjectDefinition;
extern	OGLPoint3D				gCoord;
extern	int						gNumEnemies;
extern	float					gFramesPerSecondFrac,gGlobalTransparency, gFramesPerSecond;
extern	OGLVector3D			gDelta;
extern	signed char			gNumEnemyOfKind[];
extern	uint32_t		gAutoFadeStatusBits;
extern	SpriteType	*gSpriteGroupList[MAX_SPRITE_GROUPS];
extern	int						gMaxEnemies;
extern	OGLSetupOutputType		*gGameViewInfoPtr;
extern	MetaObjectPtr			gBG3DGroupList[MAX_BG3D_GROUPS][MAX_OBJECTS_IN_GROUP];
extern	PrefsType			gGamePrefs;


/****************************/
/*    PROTOTYPES            */
/****************************/

static ObjNode *MakeRaptor(float x, float z, short animNum);
static void MoveRaptor(ObjNode *theNode);
static void  MoveRaptor_Stand(ObjNode *theNode);
static void  MoveRaptor_Walk(ObjNode *theNode);
static void  MoveRaptor_Death(ObjNode *theNode);
static void  MoveRaptor_Jump(ObjNode *theNode);

static void MoveRaptorOnSpline(ObjNode *theNode);
static void UpdateRaptor(ObjNode *theNode);
static void  MoveRaptor_KnockedDown(ObjNode *theNode);
static Boolean RaptorHitByWeaponCallback(ObjNode *bullet, ObjNode *enemy, OGLPoint3D *hitCoord, OGLVector3D *hitTriangleNormal);
static Boolean HurtRaptor(ObjNode *enemy, float damage);

static void KillRaptor(ObjNode *enemy);
static void KnockDownRaptor(ObjNode *enemy);
static Boolean DoTrig_Raptor(ObjNode *trigger, ObjNode *player);
static Boolean CheckIfRaptorHitPlayer(ObjNode *enemy);


/****************************/
/*    CONSTANTS             */
/****************************/

#define	MAX_RAPTORS				7

#define	RAPTOR_SCALE			2.5f

#define	RAPTOR_CHASE_DIST_MAX	5000.0f


#define	RAPTOR_TARGET_OFFSET	100.0f

#define RAPTOR_TURN_SPEED		4.2f
#define RAPTOR_WALK_SPEED		2300.0f

#define	RAPTOR_HEALTH			.7f
#define	RAPTOR_DAMAGE			.4f

#define RAPTOR_WALK_ANIM_SPEED_FACTOR   .0009

#define	RAPTOR_ATTACK_DIST		1100.0f
#define RAPTOR_JUMP_DELTAY		2800.0f


		/* ANIMS */

enum
{
	RAPTOR_ANIM_WALK,
	RAPTOR_ANIM_STAND,
	RAPTOR_ANIM_DEATH,
	RAPTOR_ANIM_KNOCKEDDOWN,
	RAPTOR_ANIM_JUMP,
	RAPTOR_ANIM_TURNLEFT,
	RAPTOR_ANIM_TURNRIGHT,
	RAPTOR_ANIM_WALKLEFT,
	RAPTOR_ANIM_WALKRIGHT
};


enum
{
	RAPTOR_MODE_WALKINFRONT,
	RAPTOR_MODE_WALKTOPLAYER,
	RAPTOR_MODE_WALKHOME
};

enum
{
	RAPTOR_JOINTNUM_HEAD	=   3,
	RAPTOR_JOINTNUM_TAILTIP =   22

};


/*********************/
/*    VARIABLES      */
/*********************/

#define	ButtTimer			Timer

#define WalkSpeed			SpecialF[0]
#define HomeTimer			SpecialF[1]


/************************ ADD RAPTOR ENEMY *************************/

Boolean AddEnemy_Raptor(TerrainItemEntryType *itemPtr, float x, float z)
{
ObjNode	*newObj;

	if (gGamePrefs.kiddieMode)							// don't add any non-spline enemies in kiddie mode
		return(false);

	if (gNumEnemies >= gMaxEnemies)								// keep from getting absurd
		return(false);

	if (!(itemPtr->parm[3] & 1))								// see if always add
	{
		if (gNumEnemyOfKind[ENEMY_KIND_RAPTOR] >= MAX_RAPTORS)
			return(false);
	}

	newObj = MakeRaptor(x, z, RAPTOR_ANIM_WALK);

	newObj->TerrainItemPtr = itemPtr;

	gNumEnemies++;
	gNumEnemyOfKind[ENEMY_KIND_RAPTOR]++;


	return(true);
}


/************************* MAKE RAPTOR ****************************/

static ObjNode *MakeRaptor(float x, float z, short animNum)
{
ObjNode	*newObj;

				/***********************/
				/* MAKE SKELETON ENEMY */
				/***********************/

	newObj = MakeEnemySkeleton(SKELETON_TYPE_RAPTOR,animNum, x,z, RAPTOR_SCALE, 0, MoveRaptor);

	newObj->Mode = RAPTOR_MODE_WALKINFRONT;


				/* SET BETTER INFO */

	newObj->Skeleton->CurrentAnimTime = newObj->Skeleton->MaxAnimTime * RandomFloat();		// set random time index so all of these are not in sync

	newObj->Health 		= RAPTOR_HEALTH;
	if (gGamePrefs.kiddieMode)									// no damage in kiddie mode
		newObj->Damage 		= 0;
	else
		newObj->Damage 		= RAPTOR_DAMAGE;
	newObj->Kind 		= ENEMY_KIND_RAPTOR;


			/* SET HOT-SPOT FOR AUTO TARGETING WEAPONS */

	newObj->HeatSeekHotSpotOff.x = 0;
	newObj->HeatSeekHotSpotOff.y = 0;
	newObj->HeatSeekHotSpotOff.z = -20;


				/* MAKE SHADOW */

	AttachShadowToObject(newObj, SHADOW_TYPE_CIRCULAR, 6, 10,false);


			/* SET COLLISION STUFF */

	CalcNewTargetOffsets(newObj,RAPTOR_TARGET_OFFSET);

	CreateCollisionBoxFromBoundingBox(newObj, .5,.9);
	newObj->LeftOff = newObj->BackOff;
	newObj->RightOff = -newObj->LeftOff;

	newObj->HitByWeaponHandler = RaptorHitByWeaponCallback;
	newObj->TriggerCallback = DoTrig_Raptor;

	return(newObj);

}

#pragma mark -

/********************* MOVE RAPTOR **************************/

static void MoveRaptor(ObjNode *theNode)
{
static	void(*myMoveTable[])(ObjNode *) =
				{
					MoveRaptor_Walk,
					MoveRaptor_Stand,
					MoveRaptor_Death,
					MoveRaptor_KnockedDown,
					MoveRaptor_Jump,
					MoveRaptor_Walk,
					MoveRaptor_Walk,
					MoveRaptor_Walk,
					MoveRaptor_Walk,
				};

	if (TrackTerrainItem(theNode))						// just check to see if it's gone
	{
		DeleteEnemy(theNode);
		return;
	}

	GetObjectInfo(theNode);

	myMoveTable[theNode->Skeleton->AnimNum](theNode);
}




/********************** MOVE RAPTOR: STANDING ******************************/

static void  MoveRaptor_Stand(ObjNode *theNode)
{
float	angleToTarget;
float	dist;
short	playerNum;

				/* TURN TOWARDS ME */

	dist = CalcDistanceToClosestPlayer(&gCoord, &playerNum);

	angleToTarget = TurnObjectTowardTarget(theNode, &gCoord, gPlayerInfo[playerNum].coord.x,
										gPlayerInfo[playerNum].coord.z, RAPTOR_TURN_SPEED, false, nil);


	if (dist < RAPTOR_CHASE_DIST_MAX)
	{
		theNode->WalkSpeed = 0;
		theNode->Mode = RAPTOR_MODE_WALKINFRONT;
		MorphToSkeletonAnim(theNode->Skeleton, RAPTOR_ANIM_WALK, 3);
	}



				/**********************/
				/* DO ENEMY COLLISION */
				/**********************/

	if (DoEnemyCollisionDetect(theNode,DEFAULT_ENEMY_COLLISION_CTYPES, true))
		return;

	UpdateRaptor(theNode);
}


/********************** MOVE RAPTOR: WALKING ******************************/

static void  MoveRaptor_Walk(ObjNode *theNode)
{
float		r,fps,aim,dist, walkSpeed;
short		playerNum;
float		px,pz, maxSpeed, cross, oldRotY;
ObjNode		*player;

	fps = gFramesPerSecondFrac;

	oldRotY = theNode->Rot.y;

			/********************************/
			/* SEE IF WALK TO HOME POSITION */
			/********************************/

	if (theNode->Mode == RAPTOR_MODE_WALKHOME)
	{
		px = theNode->InitCoord.x;
		pz = theNode->InitCoord.z;
		dist = CalcDistanceToClosestPlayer(&gCoord, &playerNum);
		aim = TurnObjectTowardTarget(theNode, &gCoord, px, pz, RAPTOR_TURN_SPEED, false, &cross);

		if (dist < 500.0f)													// are we basically home?
			theNode->Mode = RAPTOR_MODE_WALKINFRONT;
		else
		{
			theNode->HomeTimer -= fps;										// only try to go home for so long, then give up
			if (theNode->HomeTimer <= 0.0f)
				theNode->Mode = RAPTOR_MODE_WALKINFRONT;
		}
	}
	else
	{
				/**********************/
				/* MOVE TOWARD PLAYER */
				/**********************/

		dist = CalcDistanceToClosestPlayer(&gCoord, &playerNum);
		player = gPlayerInfo[playerNum].objNode;


				/* SEE IF MOVING TOWARD POINT IN FRONT */

		if (theNode->Mode == RAPTOR_MODE_WALKINFRONT)
		{
			r = player->Rot.y;
			px = player->Coord.x - sin(r) * 2600.0f;										// calc pt in front of player
			pz = player->Coord.z - cos(r) * 2600.0f;

			dist = CalcQuickDistance(px, pz, gCoord.x, gCoord.z);							// calc dist to the target pt
			aim = TurnObjectTowardTarget(theNode, &gCoord, px, pz, RAPTOR_TURN_SPEED, true,  &cross);

			if (dist < 400.0f)										// once we've reached this point then switch to enemy target mode
			{
				theNode->Mode = RAPTOR_MODE_WALKTOPLAYER;
				goto pdist;
			}
		}

				/* MOVE DIRECTLY TO PLAYER */

		else
		if (theNode->Mode == RAPTOR_MODE_WALKTOPLAYER)
		{
	pdist:
			px = player->Coord.x;
			pz = player->Coord.z;

			dist = CalcQuickDistance(px, pz, gCoord.x, gCoord.z);							// calc dist to player
			aim = TurnObjectTowardTarget(theNode, &gCoord, px, pz, RAPTOR_TURN_SPEED, true,  &cross);
		}
	}


			/**************/
			/* ACCELERATE */
			/**************/
			//
			// Max speed is a factor of how fast the enemy is turning.
			// The more it's turning, the slower it goes.
			//

	maxSpeed = RAPTOR_WALK_SPEED - (fabs(aim) * 200.0f);
	if (maxSpeed < (RAPTOR_WALK_SPEED/4))						// make sure doesn't get too slow
		maxSpeed = RAPTOR_WALK_SPEED/4;

	theNode->WalkSpeed += fps * (maxSpeed * .3f);
	if (theNode->WalkSpeed > maxSpeed)
		theNode->WalkSpeed = maxSpeed;

	walkSpeed = theNode->WalkSpeed;

	theNode->Skeleton->AnimSpeed = walkSpeed * RAPTOR_WALK_ANIM_SPEED_FACTOR;



			/********/
			/* MOVE */
			/********/

	r = theNode->Rot.y;
	gDelta.x = -sin(r) * walkSpeed;
	gDelta.z = -cos(r) * walkSpeed;
	gDelta.y -= ENEMY_GRAVITY*fps;									// add gravity

	gCoord.x += gDelta.x * fps;
	gCoord.y += gDelta.y * fps;
	gCoord.z += gDelta.z * fps;



		/* SET APPROPRIATE WALK ANIM */

	theNode->DeltaRot.y = (r - oldRotY) * gFramesPerSecond;

	if (fabs(theNode->DeltaRot.y) > 1.5f)
	{
		if (cross < 0.0f)
		{
			if (theNode->Skeleton->AnimNum != RAPTOR_ANIM_WALKLEFT)
				MorphToSkeletonAnim(theNode->Skeleton, RAPTOR_ANIM_WALKLEFT, 5);
		}
		else
		{
			if (theNode->Skeleton->AnimNum != RAPTOR_ANIM_WALKRIGHT)
				MorphToSkeletonAnim(theNode->Skeleton, RAPTOR_ANIM_WALKRIGHT, 5);
		}
	}
	else
	if (theNode->Skeleton->AnimNum != RAPTOR_ANIM_WALK)
		MorphToSkeletonAnim(theNode->Skeleton, RAPTOR_ANIM_WALK, 5);




			/* SEE IF STAND */

	if (theNode->Mode != RAPTOR_MODE_WALKHOME)						// only if not walking home
	{
		if (dist > RAPTOR_CHASE_DIST_MAX)
		{
			MorphToSkeletonAnim(theNode->Skeleton, RAPTOR_ANIM_STAND, 2);
		}
	}

			/**********************/
			/* DO ENEMY COLLISION */
			/**********************/

	if (DoEnemyCollisionDetect(theNode,DEFAULT_ENEMY_COLLISION_CTYPES | CTYPE_WATER, false))
		return;

	if (gTotalSides)									// if touched something then slow us down
	{
		if (gNumCollisions == 0)						// if it wasn't an objNode (probably fence), then switch mode
		{
			theNode->Mode = RAPTOR_MODE_WALKHOME;
			theNode->HomeTimer = 3.0f;
		}

		theNode->WalkSpeed = RAPTOR_WALK_SPEED * .2f;
	}


			/*****************/
			/* SEE IF JUMP   */
			/*****************/

	if (!gGamePrefs.kiddieMode)
	{
		if (theNode->Mode == RAPTOR_MODE_WALKTOPLAYER)					// only when walking directly to player
		{
			if ((dist < RAPTOR_ATTACK_DIST) && (aim < (PI/8)))
			{
				gDelta.y = RAPTOR_JUMP_DELTAY;
				gDelta.x *= .7f;
				gDelta.z *= .7f;
				MorphToSkeletonAnim(theNode->Skeleton, RAPTOR_ANIM_JUMP, 5);
				PlayEffect3D(EFFECT_RAPTORATTACK, &gCoord);
			}
		}
	}

	UpdateRaptor(theNode);
}


/********************** MOVE RAPTOR: JUMP ******************************/

static void  MoveRaptor_Jump(ObjNode *theNode)
{
float		fps;

	fps = gFramesPerSecondFrac;

	ApplyFrictionToDeltas(400.0,&gDelta);

	gDelta.y -= ENEMY_GRAVITY*fps;				// add gravity

	gCoord.x += gDelta.x * fps;
	gCoord.y += gDelta.y * fps;
	gCoord.z += gDelta.z * fps;


			/* DO ENEMY COLLISION */

	if (DoEnemyCollisionDetect(theNode,DEFAULT_ENEMY_COLLISION_CTYPES | CTYPE_WATER, false))
		return;

			/* DO SPECIAL CHECK TO SEE IF HIT PLAYER */

	if (CheckIfRaptorHitPlayer(theNode))
		return;


		/* SEE IF LANDED */

	if (theNode->StatusBits & STATUS_BIT_ONGROUND)
	{
		theNode->WalkSpeed = theNode->Speed;
		theNode->Mode = RAPTOR_MODE_WALKINFRONT;
		MorphToSkeletonAnim(theNode->Skeleton, RAPTOR_ANIM_WALK, 7.0f);
	}

	UpdateRaptor(theNode);
}




/********************** MOVE RAPTOR: KNOCKED DOWN ******************************/

static void  MoveRaptor_KnockedDown(ObjNode *theNode)
{
float	fps = gFramesPerSecondFrac;

	ApplyFrictionToDeltas(700.0,&gDelta);

	gDelta.y -= ENEMY_GRAVITY*fps;			// add gravity

	gCoord.x += gDelta.x * fps;
	gCoord.y += gDelta.y * fps;
	gCoord.z += gDelta.z * fps;


				/* SEE IF DONE */

	theNode->ButtTimer -= fps;
	if (theNode->ButtTimer <= 0.0)
	{
		MorphToSkeletonAnim(theNode->Skeleton, RAPTOR_ANIM_STAND, 2.0);
	}


				/* DO ENEMY COLLISION */

	if (DoEnemyCollisionDetect(theNode,DEFAULT_ENEMY_COLLISION_CTYPES, true))
		return;


	UpdateRaptor(theNode);
}




/********************** MOVE RAPTOR: DEATH ******************************/

static void  MoveRaptor_Death(ObjNode *theNode)
{
float	fps = gFramesPerSecondFrac;

			/* SEE IF GONE */
			//
			// if was culled on last frame and is far enough away, then delete it
			//

	if (IsObjectTotallyCulled(theNode))
	{
		short	playerNum;
		float	dist = CalcDistanceToClosestPlayer(&gCoord, &playerNum);

		if (dist > 1000.0f)
		{
			DeleteEnemy(theNode);
			return;
		}
	}


	if (theNode->StatusBits & STATUS_BIT_ONGROUND)		// if on ground, add friction
		ApplyFrictionToDeltas(2000.0,&gDelta);
	gDelta.y -= ENEMY_GRAVITY*fps;		// add gravity
	gCoord.x += gDelta.x * fps;
	gCoord.y += gDelta.y * fps;
	gCoord.z += gDelta.z * fps;


				/* DO ENEMY COLLISION */

	if (DoEnemyCollisionDetect(theNode,DEATH_ENEMY_COLLISION_CTYPES, true))
		return;


				/* UPDATE */

	UpdateRaptor(theNode);
}




/***************** UPDATE RAPTOR ************************/

static void UpdateRaptor(ObjNode *theNode)
{

	UpdateEnemy(theNode);

}



//===============================================================================================================
//===============================================================================================================
//===============================================================================================================



#pragma mark -

/************************ PRIME RAPTOR ENEMY *************************/

Boolean PrimeEnemy_Raptor(long splineNum, SplineItemType *itemPtr)
{
ObjNode			*newObj;
float			x,z,placement;

			/* GET SPLINE INFO */

	placement = itemPtr->placement;
	GetCoordOnSpline(&gSplineList[splineNum], placement, &x, &z);


				/* MAKE RAPTOR */

	newObj = MakeRaptor(x,z, RAPTOR_ANIM_WALK);


				/* SET BETTER INFO */

	newObj->StatusBits		|= STATUS_BIT_ONSPLINE;
	newObj->SplineItemPtr 	= itemPtr;
	newObj->SplineNum 		= splineNum;
	newObj->SplinePlacement = placement;
	newObj->SplineMoveCall 	= MoveRaptorOnSpline;					// set move call

	newObj->Coord.y 		-= newObj->BottomOff;


			/* ADD SPLINE OBJECT TO SPLINE OBJECT LIST */

	DetachObject(newObj, true);										// detach this object from the linked list
	AddToSplineObjectList(newObj, true);

	return(true);
}


/******************** MOVE RAPTOR ON SPLINE ***************************/

static void MoveRaptorOnSpline(ObjNode *theNode)
{
Boolean isInRange;

	isInRange = IsSplineItemOnActiveTerrain(theNode);					// update its visibility

		/* MOVE ALONG THE SPLINE */

	IncreaseSplineIndex(theNode, 350);
	GetObjectCoordOnSpline(theNode);

			/****************************/
			/* UPDATE STUFF IF IN RANGE */
			/****************************/

	if (isInRange)
	{
				/* CALC ANIM SPEED */

		theNode->Speed = CalcVectorLength(&theNode->Delta);
		theNode->Skeleton->AnimSpeed = theNode->Speed * RAPTOR_WALK_ANIM_SPEED_FACTOR;

				/* AIM ALONG SPLINE */

		theNode->Rot.y = CalcYAngleFromPointToPoint(theNode->Rot.y, theNode->OldCoord.x, theNode->OldCoord.z,			// calc y rot aim
												theNode->Coord.x, theNode->Coord.z);

		theNode->Coord.y = GetTerrainY(theNode->Coord.x, theNode->Coord.z) - theNode->BottomOff;	// calc y coord
		UpdateObjectTransforms(theNode);															// update transforms
		UpdateShadow(theNode);


				/* DO SOME COLLISION CHECKING */

		GetObjectInfo(theNode);
		if (DoEnemyCollisionDetect(theNode,CTYPE_HURTENEMY, true))
			return;
	}
}



#pragma mark -


/*************************** RAPTOR HIT BY WEAPON CALLBACK *****************************/
//
// Returns true if object should stop bullet.
//

static Boolean RaptorHitByWeaponCallback(ObjNode *bullet, ObjNode *enemy, OGLPoint3D *hitCoord, OGLVector3D *hitTriangleNormal)
{
#pragma unused (hitTriangleNormal, hitCoord)

	enemy->Health -= bullet->Damage;

			/* SEE IF KILLED */

	if (enemy->Health <= 0.0f)
		KillRaptor(enemy);


			/* JUST HURT */

	else
	{
		if (enemy->StatusBits & STATUS_BIT_ONSPLINE)
			DetachEnemyFromSpline(enemy, MoveRaptor);

		KnockDownRaptor(enemy);
	}

	return(true);
}


/****************** KILL RAPTOR ***********************/

static void KillRaptor(ObjNode *enemy)
{
	PlayEffect3D(EFFECT_RAPTORDEATH, &enemy->Coord);

			/* SEE IF REMOVE FROM SPLINE */

	if (enemy->StatusBits & STATUS_BIT_ONSPLINE)
		DetachEnemyFromSpline(enemy, MoveRaptor);

	enemy->HitByWeaponHandler	= nil;

	MorphToSkeletonAnim(enemy->Skeleton, RAPTOR_ANIM_DEATH, 2.0);

	enemy->TerrainItemPtr = nil;			// dont ever come back
	enemy->CType &= ~CTYPE_AUTOTARGETWEAPON;
}

/******************** TRIGGER CALLBACK:  RAPTOR ************************/
//
// Returns TRUE if want to handle hit as a solid
//

static Boolean DoTrig_Raptor(ObjNode *enemy, ObjNode *player)
{
short	playerNum = player->PlayerNum;

	if (gPlayerInfo[playerNum].invincibilityTimer <= 0.0f)
	{
					/* DOES PLAYER HAVE SHIELD? */

		if (gPlayerInfo[playerNum].shieldPower > 0.0f)
			HitPlayerShield(playerNum, MAX_SHIELD_POWER * enemy->Damage, 2.0, true);


					/* NO SHIELD, SO HURT PLAYER */
		else
		if (!gGamePrefs.kiddieMode)							// don't hurt in kiddie mode
			PlayerLoseHealth(playerNum, enemy->Damage, PLAYER_DEATH_TYPE_DEATHDIVE, &gCoord, true);


		gPlayerInfo[playerNum].invincibilityTimer = 1.0f;


					/* PLAYER ALWAYS DROPS EGG ON IMPACT */

		DropEgg_NoWormhole(playerNum);




					/* PLAY BODYHIT EFFECT */

		PlayEffect_Parms3D(EFFECT_BODYHIT, &gCoord, NORMAL_CHANNEL_RATE, 1.1);
	}


			/*******************/
			/* HURT THE RAPTOR */
			/*******************/

	HurtRaptor(enemy, .5);



	return(false);
}


/******************* HURT RAPTOR ************************/
//
// Returns true if raptor killed
//

static Boolean HurtRaptor(ObjNode *enemy, float damage)
{
	if ((enemy->Skeleton->AnimNum != RAPTOR_ANIM_KNOCKEDDOWN) &&			// only hurt if not dead or knocked down already
		(enemy->Skeleton->AnimNum != RAPTOR_ANIM_DEATH))
	{
		enemy->Health -= damage;
		if (enemy->Health <= 0.0f)
		{
			KillRaptor(enemy);
			return(true);
		}
		else
			KnockDownRaptor(enemy);
	}

	return(false);
}


/***************** KNOCK DOWN RAPTOR ***********************/

static void KnockDownRaptor(ObjNode *enemy)
{
			/* SET ANIM & TIMER */

	MorphToSkeletonAnim(enemy->Skeleton, RAPTOR_ANIM_KNOCKEDDOWN, 2.0f);
	enemy->ButtTimer = 5.0f;


		/* SEE IF REMOVE FROM SPLINE */

	if (enemy->StatusBits & STATUS_BIT_ONSPLINE)
		DetachEnemyFromSpline(enemy, MoveRaptor);
}


/******************** CHECK IF RAPTOR HIT PLAYER **********************/
//
// Returns true if enemy killed
//

static Boolean CheckIfRaptorHitPlayer(ObjNode *enemy)
{
short			p;
OGLLineSegment	lineSeg;
ObjNode			*hitObj;
OGLPoint3D		hitPt;
Boolean			killed;

	if (gGamePrefs.kiddieMode)							// don't hurt in kiddie mode
		return false;									// TODO: I assume we should return false here -IJ

	for (p = 0; p < gNumPlayers; p++)
	{
		if (gPlayerInfo[p].shieldPower > 0.0f)						// if player has shield then skip since other collision code handles this
			continue;

				/* GET COORD OF HEAD AND TAIL */

		FindCoordOfJoint(enemy, RAPTOR_JOINTNUM_HEAD, &lineSeg.p1);
		FindCoordOfJoint(enemy, RAPTOR_JOINTNUM_TAILTIP, &lineSeg.p2);


			/* SEE IF LINE SEG HITS PLAYER GEOMETRY */

		gPickAllTrianglesAsDoubleSided = true;
		hitObj = OGL_DoLineSegmentCollision_ObjNodes(&lineSeg, 0, CTYPE_PLAYER1<<p, &hitPt, nil, nil, true);
		gPickAllTrianglesAsDoubleSided = false;

		if (hitObj)
		{
					/* HURT PLAYER */

			if (hitObj->TriggerCallback)								// call hit obj's trigger func if any
				hitObj->TriggerCallback(hitObj, enemy);


						/* HURT ENEMY */

			killed = HurtRaptor(enemy, .3);

			return(killed);
		}

	}

	return(false);						// raptor not killed
}












