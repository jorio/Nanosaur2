#if 0 // TODO: check whether we need this -IJ
/****************************/
/*   ENEMY: STEGO.C		*/
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/

#include "game.h"

extern	NewObjectDefinitionType	gNewObjectDefinition;
extern	SplineDefType			**gSplineList;
extern	OGLPoint3D				gCoord;
extern	int						gNumEnemies;
extern	float					gFramesPerSecondFrac,gGlobalTransparency;
extern	OGLVector3D			gDelta;
extern	signed char			gNumEnemyOfKind[];
extern	u_long		gAutoFadeStatusBits;
extern	SpriteType	*gSpriteGroupList[MAX_SPRITE_GROUPS];
extern	int						gMaxEnemies;
extern	OGLSetupOutputType		*gGameViewInfoPtr;
extern	MetaObjectPtr			gBG3DGroupList[MAX_BG3D_GROUPS][MAX_OBJECTS_IN_GROUP];
extern	TerrainItemEntryType 	**gMasterItemList;
extern	short					gNumTerrainItems;
extern	PrefsType			gGamePrefs;


/****************************/
/*    PROTOTYPES            */
/****************************/

static ObjNode *MakeStego(float x, float z, short animNum);
static void MoveStego(ObjNode *theNode);
static void  MoveStego_Stand_Food(ObjNode *theNode);
static void  MoveStego_Stand(ObjNode *theNode);
static void  MoveStego_Walk(ObjNode *theNode);
static void  MoveStego_Death(ObjNode *theNode);

static void MoveStegoOnSpline(ObjNode *theNode);
static void UpdateStego(ObjNode *theNode);
static void  MoveStego_GotHit(ObjNode *theNode);
static Boolean HurtStego(ObjNode *enemy, float damage);

static void KillStego(ObjNode *enemy);
static void StegoGotKickedCallback(ObjNode *player, ObjNode *kickedObj);


/****************************/
/*    CONSTSTEGOS             */
/****************************/

#define	MAX_STEGOS				7

#define	STEGO_SCALE			8.0f

#define	STEGO_DETACH_DIST		500.0f

#define	STEGO_CHASE_DIST_MAX	900.0f

#define	STEGO_ATTACK_DIST		100.0f

#define	STEGO_TARGET_OFFSET		20.0f

#define STEGO_TURN_SPEED			4.0f
#define STEGO_WALK_SPEED			300.0f

#define	STEGO_HEALTH				3.0f
#define	STEGO_DAMAGE				.2f


		/* ANIMS */

enum
{
	STEGO_ANIM_WALK,
	STEGO_ANIM_STAND
};




/*********************/
/*    VARIABLES      */
/*********************/

#define	ButtTimer			SpecialF[2]



/************************ ADD STEGO ENEMY *************************/

Boolean AddEnemy_Stego(TerrainItemEntryType *itemPtr, float x, float z)
{
ObjNode	*newObj;


	if (gNumEnemies >= gMaxEnemies)								// keep from getting absurd
		return(false);

	if (!(itemPtr->parm[3] & 1))								// see if always add
	{
		if (gNumEnemyOfKind[ENEMY_KIND_STEGO] >= MAX_STEGOS)
			return(false);
	}

	newObj = MakeStego(x, z, STEGO_ANIM_WALK);

	newObj->TerrainItemPtr = itemPtr;

	gNumEnemies++;
	gNumEnemyOfKind[ENEMY_KIND_STEGO]++;


	return(true);
}


/************************* MAKE STEGO ****************************/

static ObjNode *MakeStego(float x, float z, short animNum)
{
ObjNode	*newObj;

				/***********************/
				/* MAKE SKELETON ENEMY */
				/***********************/

	newObj = MakeEnemySkeleton(SKELETON_TYPE_STEGO,animNum, x,z, STEGO_SCALE, 0, MoveStego);



				/* SET BETTER INFO */

	newObj->Skeleton->CurrentAnimTime = newObj->Skeleton->MaxAnimTime * RandomFloat();		// set random time index so all of these are not in sync

	newObj->StatusBits |= STATUS_BIT_CLIPALPHA6;

	newObj->Health 		= STEGO_HEALTH;
	newObj->Damage 		= STEGO_DAMAGE;
	newObj->Kind 		= ENEMY_KIND_STEGO;



	newObj->HurtCallback 		= HurtStego;							// set hurt callback function

	newObj->Damage = STEGO_DAMAGE;


				/* MAKE SHADOW */

	AttachShadowToObject(newObj, SHADOW_TYPE_CIRCULAR, 6, 10,false);


			/* SET COLLISION STUFF */

	CalcNewTargetOffsets(newObj,STEGO_TARGET_OFFSET);

	CreateCollisionBoxFromBoundingBox(newObj, .5,.9);
	newObj->LeftOff = newObj->BackOff;
	newObj->RightOff = -newObj->LeftOff;

	return(newObj);

}

#pragma mark -

/********************* MOVE STEGO **************************/

static void MoveStego(ObjNode *theNode)
{
static	void(*myMoveTable[])(ObjNode *) =
				{
					MoveStego_Walk,
					MoveStego_Stand,
					MoveStego_GotHit,
					MoveStego_Death
				};

	if (TrackTerrainItem(theNode))						// just check to see if it's gone
	{
		DeleteEnemy(theNode);
		return;
	}

	GetObjectInfo(theNode);

	myMoveTable[theNode->Skeleton->AnimNum](theNode);
}




/********************** MOVE STEGO: STANDING ******************************/

static void  MoveStego_Stand(ObjNode *theNode)
{
float	angleToTarget;
float	dist;
short	playerNum;

				/* TURN TOWARDS ME */

	dist = CalcDistanceToClosestPlayer(&gCoord, &playerNum);

	angleToTarget = TurnObjectTowardTarget(theNode, &gCoord, gPlayerInfo[playerNum].coord.x,
										gPlayerInfo[playerNum].coord.z, STEGO_TURN_SPEED, false);


	if (!IsWaterInFrontOfEnemy(theNode->Rot.y))				// dont chase if we're in front of water
	{
		if (dist < STEGO_CHASE_DIST_MAX)
		{
			MorphToSkeletonAnim(theNode->Skeleton, STEGO_ANIM_WALK, 6);
		}
	}

				/**********************/
				/* DO ENEMY COLLISION */
				/**********************/

	if (DoEnemyCollisionDetect(theNode,DEFAULT_ENEMY_COLLISION_CTYPES, true))
		return;

	UpdateStego(theNode);
}




/********************** MOVE STEGO: WALKING ******************************/

static void  MoveStego_Walk(ObjNode *theNode)
{
float		r,fps,aim,dist;
short		playerNum;

	fps = gFramesPerSecondFrac;


			/* MOVE TOWARD PLAYER */

	dist = CalcDistanceToClosestPlayer(&gCoord, &playerNum);

	aim = TurnObjectTowardTarget(theNode, &gCoord, gPlayerInfo[playerNum].coord.x, gPlayerInfo[playerNum].coord.z,
								STEGO_TURN_SPEED, false);

	r = theNode->Rot.y;
	gDelta.x = -sin(r) * STEGO_WALK_SPEED;
	gDelta.z = -cos(r) * STEGO_WALK_SPEED;
	gDelta.y -= ENEMY_GRAVITY*fps;				// add gravity

	gCoord.x += gDelta.x * fps;
	gCoord.y += gDelta.y * fps;
	gCoord.z += gDelta.z * fps;

	if (IsWaterInFrontOfEnemy(r))				// if about to enter water then stop
	{
		MorphToSkeletonAnim(theNode->Skeleton, STEGO_ANIM_STAND, 8);
	}

			/* DO ENEMY COLLISION */

	if (DoEnemyCollisionDetect(theNode,DEFAULT_ENEMY_COLLISION_CTYPES, true))
		return;


			/* SEE IF ATTACK */

	if (dist < STEGO_ATTACK_DIST)
	{
//		MorphToSkeletonAnim(theNode->Skeleton, STEGO_ANIM_ATTACK, 2);
	}


	UpdateStego(theNode);
}




/********************** MOVE STEGO: GOT HIT ******************************/

static void  MoveStego_GotHit(ObjNode *theNode)
{
float	fps = gFramesPerSecondFrac;

	ApplyFrictionToDeltas(1200.0,&gDelta);

	gDelta.y -= ENEMY_GRAVITY*fps;			// add gravity

	gCoord.x += gDelta.x * fps;
	gCoord.y += gDelta.y * fps;
	gCoord.z += gDelta.z * fps;


				/* SEE IF DONE */

	theNode->ButtTimer -= fps;
	if (theNode->ButtTimer <= 0.0)
	{
		SetSkeletonAnim(theNode->Skeleton, STEGO_ANIM_STAND);
	}


				/* DO ENEMY COLLISION */

	if (DoEnemyCollisionDetect(theNode,DEFAULT_ENEMY_COLLISION_CTYPES, true))
		return;


update:
	UpdateStego(theNode);
}




/********************** MOVE STEGO: DEATH ******************************/

static void  MoveStego_Death(ObjNode *theNode)
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

	UpdateStego(theNode);
}




/***************** UPDATE STEGO ************************/

static void UpdateStego(ObjNode *theNode)
{

	UpdateEnemy(theNode);

}



//===============================================================================================================
//===============================================================================================================
//===============================================================================================================



#pragma mark -

/************************ PRIME STEGO ENEMY *************************/

Boolean PrimeEnemy_Stego(long splineNum, SplineItemType *itemPtr)
{
ObjNode			*newObj;
float			x,z,placement;

			/* GET SPLINE INFO */

	placement = itemPtr->placement;
	GetCoordOnSpline(&(*gSplineList)[splineNum], placement, &x, &z);


				/* MAKE STEGO */

	newObj = MakeStego(x,z, STEGO_ANIM_WALK);


				/* SET BETTER INFO */

	newObj->StatusBits		|= STATUS_BIT_ONSPLINE;
	newObj->SplineItemPtr 	= itemPtr;
	newObj->SplineNum 		= splineNum;
	newObj->SplinePlacement = placement;
	newObj->SplineMoveCall 	= MoveStegoOnSpline;					// set move call

	newObj->Coord.y 		-= newObj->BottomOff;


			/* ADD SPLINE OBJECT TO SPLINE OBJECT LIST */

	DetachObject(newObj, true);										// detach this object from the linked list
	AddToSplineObjectList(newObj, true);

	return(true);
}


/******************** MOVE STEGO ON SPLINE ***************************/

static void MoveStegoOnSpline(ObjNode *theNode)
{
Boolean isInRange;

	isInRange = IsSplineItemOnActiveTerrain(theNode);					// update its visibility

		/* MOVE ALONG THE SPLINE */

	IncreaseSplineIndex(theNode, 70);
	GetObjectCoordOnSpline(theNode);


			/* UPDATE STUFF IF IN RANGE */

	if (isInRange)
	{
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


/************************* STEGO GOT KICKED CALLBACK *************************/
//
// The default callback for kickable objects
//

static void StegoGotKickedCallback(ObjNode *player, ObjNode *kickedObj)
{
float	r = player->Rot.y;

	kickedObj->Delta.x = -sin(r) * 800.0f;
	kickedObj->Delta.z = -cos(r) * 800.0f;
	kickedObj->Delta.y = 600.0f;

	kickedObj->Rot.y = player->Rot.y + PI;

	HurtStego(kickedObj, .3);
}




/*********************** HURT STEGO ***************************/

static Boolean HurtStego(ObjNode *enemy, float damage)
{

			/* SEE IF REMOVE FROM SPLINE */

	if (enemy->StatusBits & STATUS_BIT_ONSPLINE)
		DetachEnemyFromSpline(enemy, MoveStego);


				/* HURT ENEMY & SEE IF KILL */

	enemy->Health -= damage;
	if (enemy->Health <= 0.0f)
	{
		KillStego(enemy);
		return(true);
	}
	else
	{
//		MorphToSkeletonAnim(enemy->Skeleton, STEGO_ANIM_GOTHIT, 10);
		enemy->ButtTimer = 1.5;
	}

	return(false);
}


/****************** KILL STEGO ***********************/

static void KillStego(ObjNode *enemy)
{
	enemy->CType 				= CTYPE_MISC;				// no longer an enemy
	enemy->HurtCallback 		= nil;

//	SetSkeletonAnim(enemy->Skeleton, STEGO_ANIM_DEATH);

	enemy->TerrainItemPtr = nil;			// dont ever come back

}




#endif
