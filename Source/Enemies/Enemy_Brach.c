/****************************/
/*   ENEMY: BRACH.C		*/
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/

#include "3DMath.h"

extern	NewObjectDefinitionType	gNewObjectDefinition;
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
extern	PrefsType			gGamePrefs;


/****************************/
/*    PROTOTYPES            */
/****************************/

static ObjNode *MakeBrach(float x, float z, short animNum);
static void MoveBrach(ObjNode *theNode);
static void  MoveBrach_Stand(ObjNode *theNode);
static void  MoveBrach_Walk(ObjNode *theNode);
static void  MoveBrach_Death(ObjNode *theNode);
static void  MoveBrach_Scratch(ObjNode *theNode);
static void  MoveBrach_Eat(ObjNode *theNode);

static void MoveBrachOnSpline(ObjNode *theNode);
static void UpdateBrach(ObjNode *theNode);

static void KillBrach(ObjNode *enemy);
static Boolean BrachHitByWeaponCallback(ObjNode *bullet, ObjNode *enemy, OGLPoint3D *hitCoord, OGLVector3D *hitTriangleNormal);


/****************************/
/*    CONSTBRACHS             */
/****************************/

#define	MAX_BRACHS				7

#define	BRACH_SCALE				6.0f

#define	BRACH_DETACH_DIST		500.0f

#define	BRACH_CHASE_DIST_MAX	3000.0f

#define	BRACH_TARGET_OFFSET		20.0f

#define BRACH_TURN_SPEED			2.0f
#define BRACH_WALK_SPEED			300.0f

#define	BRACH_HEALTH				1.1f
#define	BRACH_DAMAGE				.7f


		/* ANIMS */

enum
{
	BRACH_ANIM_STAND,
	BRACH_ANIM_WALK,
	BRACH_ANIM_DEATH,
	BRACH_ANIM_SCRATCH,
	BRACH_ANIM_EAT
};


/*********************/
/*    VARIABLES      */
/*********************/

#define	ButtTimer			SpecialF[2]



/************************ ADD BRACH ENEMY *************************/

Boolean AddEnemy_Brach(TerrainItemEntryType *itemPtr, float x, float z)
{
ObjNode	*newObj;


	if (gNumEnemies >= gMaxEnemies)								// keep from getting absurd
		return(false);

	if (!(itemPtr->parm[3] & 1))								// see if always add
	{
		if (gNumEnemyOfKind[ENEMY_KIND_BRACH] >= MAX_BRACHS)
			return(false);
	}

	newObj = MakeBrach(x, z, BRACH_ANIM_STAND);

	newObj->TerrainItemPtr = itemPtr;

	newObj->Timer = RandomFloat() * 10.0f;

			/* SET ROT */

	newObj->Rot.y = ((float)itemPtr->parm[0]) * (PI2/8.0f);
	UpdateObjectTransforms(newObj);

	gNumEnemies++;
	gNumEnemyOfKind[ENEMY_KIND_BRACH]++;


	return(true);
}


/************************* MAKE BRACH ****************************/

static ObjNode *MakeBrach(float x, float z, short animNum)
{
ObjNode	*newObj;

				/***********************/
				/* MAKE SKELETON ENEMY */
				/***********************/

	newObj = MakeEnemySkeleton(SKELETON_TYPE_BRACH,animNum, x,z, BRACH_SCALE, 0, MoveBrach);



				/* SET BETTER INFO */

	newObj->Skeleton->CurrentAnimTime = newObj->Skeleton->MaxAnimTime * RandomFloat();		// set random time index so all of these are not in sync

	newObj->Health 		= BRACH_HEALTH;
	newObj->Damage 		= BRACH_DAMAGE;
	newObj->Kind 		= ENEMY_KIND_BRACH;


				/* MAKE SHADOW */

	AttachShadowToObject(newObj, SHADOW_TYPE_CIRCULAR, 12, 20,false);


			/* SET COLLISION STUFF */

	CalcNewTargetOffsets(newObj,BRACH_TARGET_OFFSET);

	CreateCollisionBoxFromBoundingBox(newObj, .5,.9);
	newObj->LeftOff = newObj->BackOff;
	newObj->RightOff = -newObj->LeftOff;

	newObj->HitByWeaponHandler = BrachHitByWeaponCallback;


	return(newObj);

}

#pragma mark -

/********************* MOVE BRACH **************************/

static void MoveBrach(ObjNode *theNode)
{
static	void(*myMoveTable[])(ObjNode *) =
				{
					MoveBrach_Stand,
					MoveBrach_Walk,
					MoveBrach_Death,
					MoveBrach_Scratch,
					MoveBrach_Eat,
				};

	if (TrackTerrainItem(theNode))						// just check to see if it's gone
	{
		DeleteEnemy(theNode);
		return;
	}

	GetObjectInfo(theNode);

	myMoveTable[theNode->Skeleton->AnimNum](theNode);
}




/********************** MOVE BRACH: STANDING ******************************/

static void  MoveBrach_Stand(ObjNode *theNode)
{

	theNode->Skeleton->AnimSpeed = .3f;						// slow this down

			/* SEE IF DO SCRATCH / EAT */

	theNode->Timer -= gFramesPerSecondFrac;
	if (theNode->Timer <= 0.0f)
	{
		if (MyRandomLong() & 1)
			MorphToSkeletonAnim(theNode->Skeleton, BRACH_ANIM_SCRATCH, 3);
		else
			MorphToSkeletonAnim(theNode->Skeleton, BRACH_ANIM_EAT, 1);

		theNode->Timer = 3.0f + RandomFloat() * 5.0f;
	}

				/**********************/
				/* DO ENEMY COLLISION */
				/**********************/

	if (DoEnemyCollisionDetect(theNode,DEFAULT_ENEMY_COLLISION_CTYPES, true))
		return;

	UpdateBrach(theNode);
}

/********************** MOVE BRACH: SCRATCH ******************************/

static void  MoveBrach_Scratch(ObjNode *theNode)
{
	theNode->Skeleton->AnimSpeed = .7f;						// slow this down

	if (theNode->Skeleton->AnimHasStopped)
	{
		SetSkeletonAnim(theNode->Skeleton, BRACH_ANIM_STAND);
	}

				/**********************/
				/* DO ENEMY COLLISION */
				/**********************/

	if (DoEnemyCollisionDetect(theNode,DEFAULT_ENEMY_COLLISION_CTYPES, true))
		return;

	UpdateBrach(theNode);
}

/********************** MOVE BRACH: EAT ******************************/

static void  MoveBrach_Eat(ObjNode *theNode)
{
	theNode->Skeleton->AnimSpeed = .4f;						// slow this down

	if (theNode->Skeleton->AnimHasStopped)
	{
		SetSkeletonAnim(theNode->Skeleton, BRACH_ANIM_STAND);
	}

				/**********************/
				/* DO ENEMY COLLISION */
				/**********************/

	if (DoEnemyCollisionDetect(theNode,DEFAULT_ENEMY_COLLISION_CTYPES, true))
		return;

	UpdateBrach(theNode);
}



/********************** MOVE BRACH: WALK ******************************/

static void  MoveBrach_Walk(ObjNode *theNode)
{
float		r,fps,dist;
short		playerNum;

	fps = gFramesPerSecondFrac;


			/* MOVE TOWARD PLAYER */

	dist = CalcDistanceToClosestPlayer(&gCoord, &playerNum);

	if (!gPlayerIsDead[playerNum])							// don't aim at dead players
	{
		TurnObjectTowardTarget(theNode, &gCoord, gPlayerInfo[playerNum].coord.x, gPlayerInfo[playerNum].coord.z,
									BRACH_TURN_SPEED, false, nil);
	}

	r = theNode->Rot.y;
	gDelta.x = -sin(r) * BRACH_WALK_SPEED;
	gDelta.z = -cos(r) * BRACH_WALK_SPEED;
	gDelta.y -= ENEMY_GRAVITY*fps;				// add gravity

	gCoord.x += gDelta.x * fps;
	gCoord.y += gDelta.y * fps;
	gCoord.z += gDelta.z * fps;

	if (IsWaterInFrontOfEnemy(r))				// if about to enter water then stop
	{
		MorphToSkeletonAnim(theNode->Skeleton, BRACH_ANIM_STAND, 8);
	}

			/* DO ENEMY COLLISION */

	if (DoEnemyCollisionDetect(theNode,DEFAULT_ENEMY_COLLISION_CTYPES, false))
		return;



	UpdateBrach(theNode);

}





/********************** MOVE BRACH: DEATH ******************************/

static void  MoveBrach_Death(ObjNode *theNode)
{
float	fps = gFramesPerSecondFrac;

	theNode->Skeleton->AnimSpeed = .4f;

			/* SEE IF GONE */
			//
			// if was culled on last frame and is far enough away, then delete it
			//

	if (IsObjectTotallyCulled(theNode))
	{
		short	playerNum;
		float	dist = CalcDistanceToClosestPlayer(&gCoord, &playerNum);

		if (dist > 3000.0f)
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

	UpdateBrach(theNode);
}




/***************** UPDATE BRACH ************************/

static void UpdateBrach(ObjNode *theNode)
{

	UpdateEnemy(theNode);


			/* SET WALK ANIM SPEED */

	if (theNode->Skeleton->AnimNum == BRACH_ANIM_WALK)
		theNode->Skeleton->AnimSpeed = theNode->Speed * .003f;

}



//===============================================================================================================
//===============================================================================================================
//===============================================================================================================



#pragma mark -

/************************ PRIME BRACH ENEMY *************************/

Boolean PrimeEnemy_Brach(long splineNum, SplineItemType *itemPtr)
{
ObjNode			*newObj;
float			x,z,placement;

			/* GET SPLINE INFO */

	placement = itemPtr->placement;
	GetCoordOnSpline(&gSplineList[splineNum], placement, &x, &z);


				/* MAKE BRACH */

	newObj = MakeBrach(x,z, BRACH_ANIM_WALK);


				/* SET BETTER INFO */

	newObj->StatusBits		|= STATUS_BIT_ONSPLINE;
	newObj->SplineItemPtr 	= itemPtr;
	newObj->SplineNum 		= splineNum;
	newObj->SplinePlacement = placement;
	newObj->SplineMoveCall 	= MoveBrachOnSpline;					// set move call

	newObj->Coord.y 		-= newObj->BottomOff;


	newObj->Skeleton->AnimSpeed = .5f;

			/* ADD SPLINE OBJECT TO SPLINE OBJECT LIST */

	DetachObject(newObj, true);										// detach this object from the linked list
	AddToSplineObjectList(newObj, true);

	return(true);
}


/******************** MOVE BRACH ON SPLINE ***************************/

static void MoveBrachOnSpline(ObjNode *theNode)
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


/*************************** BRACH HIT BY WEAPON CALLBACK *****************************/
//
// Returns true if object should stop bullet.
//

static Boolean BrachHitByWeaponCallback(ObjNode *bullet, ObjNode *enemy, OGLPoint3D *hitCoord, OGLVector3D *hitTriangleNormal)
{
#pragma unused (hitTriangleNormal, hitCoord)

	enemy->Health -= bullet->Damage;
	if (enemy->Health <= 0.0f)
		KillBrach(enemy);
	else
	if (bullet->Damage >= .1f)						// if hurt enough, make grunt
		PlayEffect_Parms3D(EFFECT_BRACHHURT, &enemy->Coord, NORMAL_CHANNEL_RATE, 1.2);

	return(true);
}


/****************** KILL BRACH ***********************/

static void KillBrach(ObjNode *enemy)
{
	PlayEffect_Parms3D(EFFECT_BRACHDEATH, &enemy->Coord, NORMAL_CHANNEL_RATE, 1.0);

			/* SEE IF REMOVE FROM SPLINE */

	if (enemy->StatusBits & STATUS_BIT_ONSPLINE)
		DetachEnemyFromSpline(enemy, MoveBrach);

	enemy->HitByWeaponHandler	= nil;

	MorphToSkeletonAnim(enemy->Skeleton, BRACH_ANIM_DEATH, 8.0);

	enemy->TerrainItemPtr = nil;			// dont ever come back
	enemy->CType &= ~CTYPE_AUTOTARGETWEAPON;

}



