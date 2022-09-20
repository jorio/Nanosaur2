/****************************/
/*   ENEMY: RAMPHOR.C		*/
/* (c)2004 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/

#include "game.h"

extern	NewObjectDefinitionType	gNewObjectDefinition;
extern	OGLPoint3D				gCoord;
extern	int						gNumEnemies;
extern	float					gFramesPerSecondFrac,gGlobalTransparency;
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

static ObjNode *MakeRamphor(float x, float z, short animNum, long height);

static void MoveRamphorOnSpline(ObjNode *theNode);
static void UpdateRamphor(ObjNode *theNode);
static Boolean RamphorHitByWeaponCallback(ObjNode *bullet, ObjNode *enemy, OGLPoint3D *hitCoord, OGLVector3D *hitTriangleNormal);

static void KillRamphor(ObjNode *enemy);
static void DisorientRamphor(ObjNode *enemy);
static Boolean DoTrig_Ramphor(ObjNode *trigger, ObjNode *player);
static void ExplodeRamphor(ObjNode *theNode);
static Boolean HurtRamphor(ObjNode *enemy, float damage);
static Boolean CheckIfRamphorHitPlayer(ObjNode *enemy);


/****************************/
/*    CONSTANTS             */
/****************************/


#define	RAMPHOR_SCALE			2.2f


#define RAMPHOR_WOBBLE_DIFF		270.0f

#define BLOCK_DIST				1000.0f


#define	RAMPHOR_HEALTH			.8f
#define	RAMPHOR_DAMAGE			.4f


		/* ANIMS */

enum
{
	RAMPHOR_ANIM_FLAP,
	RAMPHOR_ANIM_COAST,
	RAMPHOR_ANIM_DISORIENTED,
	RAMPHOR_ANIM_DEATH,
	RAMPHOR_ANIM_BLOCK
};


enum
{
	RAMPHOR_JOINTNUM_BUTT = 3 ,
	RAMPHOR_JOINTNUM_TAILTIP = 31

};


/*********************/
/*    VARIABLES      */
/*********************/

#define		Wobble			SpecialF[0]
#define		FlightHeight	SpecialF[1]
#define		SplineSpeed		SpecialF[2]


/************************ PRIME RAMPHOR ENEMY *************************/

Boolean PrimeEnemy_Ramphor(long splineNum, SplineItemType *itemPtr)
{
ObjNode			*newObj;
float			x,z,placement;
long			height = itemPtr->parm[0];
long			speed = itemPtr->parm[1];

			/* GET SPLINE INFO */

	placement = itemPtr->placement;
	GetCoordOnSpline(&gSplineList[splineNum], placement, &x, &z);


				/* MAKE RAMPHOR */

	newObj = MakeRamphor(x,z, RAMPHOR_ANIM_FLAP, height);


				/* SET SPLINE INFO */

	newObj->SplineSpeed		= 180 + speed * 30;

	newObj->StatusBits		|= STATUS_BIT_ONSPLINE;
	newObj->SplineItemPtr 	= itemPtr;
	newObj->SplineNum 		= splineNum;
	newObj->SplinePlacement = placement;
	newObj->SplineMoveCall 	= MoveRamphorOnSpline;					// set move call

	newObj->Coord.y 		-= newObj->BottomOff;


			/* ADD SPLINE OBJECT TO SPLINE OBJECT LIST */

	DetachObject(newObj, true);										// detach this object from the linked list
	AddToSplineObjectList(newObj, true);

	return(true);
}


/************************* MAKE RAMPHOR ****************************/

static ObjNode *MakeRamphor(float x, float z, short animNum, long height)
{
ObjNode	*newObj;

				/***********************/
				/* MAKE SKELETON ENEMY */
				/***********************/

	newObj = MakeEnemySkeleton(SKELETON_TYPE_RAMPHOR, animNum, x,z, RAMPHOR_SCALE, 0, nil);

	newObj->Wobble = RandomFloat() * PI2;
	newObj->FlightHeight	= GetTerrainY(x,z) + (RAMPHOR_WOBBLE_DIFF + 150.0f) + (height * 190.0f);


				/* SET BETTER INFO */

	newObj->Skeleton->CurrentAnimTime = newObj->Skeleton->MaxAnimTime * RandomFloat();		// set random time index so all of these are not in sync

	newObj->Health 		= RAMPHOR_HEALTH;
	if (gGamePrefs.kiddieMode)									// no damage in kiddie mode
		newObj->Damage 		= 0;
	else
		newObj->Damage 		= RAMPHOR_DAMAGE;
	newObj->Kind 		= ENEMY_KIND_RAMPHOR;


			/* SET HOT-SPOT FOR AUTO TARGETING WEAPONS */

	newObj->HeatSeekHotSpotOff.x = 0;
	newObj->HeatSeekHotSpotOff.y = 0;
	newObj->HeatSeekHotSpotOff.z = 0;


				/* MAKE SHADOW */

	AttachShadowToObject(newObj, SHADOW_TYPE_CIRCULAR, 6, 10,false);


			/* SET COLLISION STUFF */

	CreateCollisionBoxFromBoundingBox(newObj, .8,.9);
	newObj->LeftOff = newObj->BackOff;
	newObj->RightOff = -newObj->LeftOff;

	newObj->HitByWeaponHandler = RamphorHitByWeaponCallback;
	newObj->TriggerCallback = DoTrig_Ramphor;

	return(newObj);

}



/******************** MOVE RAMPHOR ON SPLINE ***************************/

static void MoveRamphorOnSpline(ObjNode *theNode)
{
Boolean			isInRange;
OGLMatrix4x4	m,sm;

	isInRange = IsSplineItemOnActiveTerrain(theNode);					// update its visibility

		/* MOVE ALONG THE SPLINE */

	IncreaseSplineIndex(theNode, 250);
	GetObjectCoordOnSpline(theNode);

			/****************************/
			/* UPDATE STUFF IF IN RANGE */
			/****************************/

	if (isInRange)
	{
		float   fps = gFramesPerSecondFrac;
		short   playerNum;

				/* DO Y CALC */

		theNode->Wobble += fps * 1.3;													// wobble height
		if (theNode->Wobble > PI2)
			theNode->Wobble -= PI2;
		theNode->Coord.y = theNode->FlightHeight + cos(theNode->Wobble) * RAMPHOR_WOBBLE_DIFF;		// calc y coord



				/***********************/
				/* SEE IF CHANGE ANIMS */
				/***********************/

		if (theNode->Skeleton->AnimNum == RAMPHOR_ANIM_DISORIENTED)					// see if done with disorientation
		{
			if (theNode->Skeleton->AnimHasStopped)
				MorphToSkeletonAnim(theNode->Skeleton, RAMPHOR_ANIM_COAST, 3);
		}

				/* SEE IF BLOCK */

		else
		if (CalcDistanceToClosestPlayer(&theNode->Coord, &playerNum) < BLOCK_DIST)
		{
			if (theNode->Skeleton->AnimNum != RAMPHOR_ANIM_BLOCK)
				MorphToSkeletonAnim(theNode->Skeleton, RAMPHOR_ANIM_BLOCK, 2.0);
		}

				/* FLIGHT ANIM */
		else
		{
			if (theNode->Wobble < PI)					// coast when going down the curve
			{
				if (theNode->Skeleton->AnimNum != RAMPHOR_ANIM_COAST)
					MorphToSkeletonAnim(theNode->Skeleton, RAMPHOR_ANIM_COAST, 4.0f);
			}
			else										// flap when going up
			{
				if (theNode->Skeleton->AnimNum != RAMPHOR_ANIM_FLAP)
					MorphToSkeletonAnim(theNode->Skeleton, RAMPHOR_ANIM_FLAP, 4.0f);
			}
		}


				/* DO SPECIAL CHECK TO SEE IF HIT PLAYER */

		if (CheckIfRamphorHitPlayer(theNode))
			return;




				/* AIM ALONG SPLINE */

		SetLookAtMatrixAndTranslate(&m, &gUp, &theNode->OldCoord, &theNode->Coord);
		OGLMatrix4x4_SetScale(&sm, RAMPHOR_SCALE, RAMPHOR_SCALE, RAMPHOR_SCALE);
		OGLMatrix4x4_Multiply(&sm, &m, &theNode->BaseTransformMatrix);

		SetObjectTransformMatrix(theNode);															// update transforms
		UpdateShadow(theNode);
		CalcObjectBoxFromNode(theNode);

	}
}






/********************** MOVE RAMPHOR: DEATH ******************************/

static void  MoveRamphor_Death(ObjNode *theNode)
{
float	fps = gFramesPerSecondFrac;

	GetObjectInfo(theNode);

			/* MOVE */

	gDelta.y -= 4000.0f * fps;		// add gravity
	gCoord.x += gDelta.x * fps;
	gCoord.y += gDelta.y * fps;
	gCoord.z += gDelta.z * fps;

	theNode->Rot.z -= fps * PI2;


			/* SEE IF HIT GROUND */

	if (gCoord.y <= GetTerrainY(gCoord.x, gCoord.z))
	{
		ExplodeRamphor(theNode);
		return;
	}




				/* UPDATE */

	UpdateRamphor(theNode);
}




/***************** UPDATE RAMPHOR ************************/

static void UpdateRamphor(ObjNode *theNode)
{

	UpdateEnemy(theNode);

}


#pragma mark -


/*************************** RAMPHOR HIT BY WEAPON CALLBACK *****************************/
//
// Returns true if object should stop bullet.
//

static Boolean RamphorHitByWeaponCallback(ObjNode *bullet, ObjNode *enemy, OGLPoint3D *hitCoord, OGLVector3D *hitTriangleNormal)
{
#pragma unused (hitTriangleNormal, hitCoord)

	enemy->Health -= bullet->Damage;

			/* SEE IF KILLED */

	if (enemy->Health <= 0.0f)
		KillRamphor(enemy);


			/* JUST HURT */

	else
	{
		DisorientRamphor(enemy);
	}

	return(true);
}


/****************** KILL RAMPHOR ***********************/

static void KillRamphor(ObjNode *enemy)
{
//	PlayEffect3D(EFFECT_RAMPHORDEATH, &enemy->Coord);

			/* SEE IF REMOVE FROM SPLINE */

	if (enemy->StatusBits & STATUS_BIT_ONSPLINE)
		DetachEnemyFromSpline(enemy, MoveRamphor_Death);

	enemy->HitByWeaponHandler	= nil;

	MorphToSkeletonAnim(enemy->Skeleton, RAMPHOR_ANIM_DEATH, 2.0);

	enemy->TerrainItemPtr = nil;			// dont ever come back
	enemy->CType &= ~CTYPE_AUTOTARGETWEAPON;
}


/******************** TRIGGER CALLBACK:  RAMPHOR ************************/
//
// Returns TRUE if want to handle hit as a solid
//

static Boolean DoTrig_Ramphor(ObjNode *enemy, ObjNode *player)
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
			/* HURT THE RAMPHOR */
			/*******************/

	HurtRamphor(enemy, .5);


	return(false);
}

/******************* HURT RAMPHOR ************************/
//
// Returns true if raptor killed
//

static Boolean HurtRamphor(ObjNode *enemy, float damage)
{
	enemy->Health -= damage;
	if (enemy->Health <= 0.0f)
	{
		KillRamphor(enemy);
		return(true);
	}
	else
		DisorientRamphor(enemy);

	return(false);
}



/***************** DISORIENT RAMPHOR ***********************/

static void DisorientRamphor(ObjNode *enemy)
{
			/* SET ANIM & TIMER */

	MorphToSkeletonAnim(enemy->Skeleton, RAMPHOR_ANIM_DISORIENTED, 2.0f);
}

/********************** EXPLODE RAMPHOR ***********************/

static void ExplodeRamphor(ObjNode *theNode)
{
long					pg,i;
OGLVector3D				d;
OGLPoint3D				pt;
NewParticleDefType		newParticleDef;
float					x,y,z;

	x = theNode->Coord.x;
	y = theNode->Coord.y;
	z = theNode->Coord.z;


	gNewParticleGroupDef.magicNum				= 0;
	gNewParticleGroupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
	gNewParticleGroupDef.flags					= 0;
	gNewParticleGroupDef.gravity				= 300;
	gNewParticleGroupDef.magnetism				= 0;
	gNewParticleGroupDef.baseScale				= 25;
	gNewParticleGroupDef.decayRate				=  -1.0;
	gNewParticleGroupDef.fadeRate				= .8;
	gNewParticleGroupDef.particleTextureNum		= PARTICLE_SObjType_CokeSpray;
	gNewParticleGroupDef.srcBlend				= GL_SRC_ALPHA;
	gNewParticleGroupDef.dstBlend				= GL_ONE_MINUS_SRC_ALPHA;
	pg = NewParticleGroup(&gNewParticleGroupDef);
	if (pg != -1)
	{
		for (i = 0; i < 100; i++)
		{
			d.y = RandomFloat() * 400.0f;
			d.x = RandomFloat2() * 200.0f;
			d.z = RandomFloat2() * 200.0f;

			pt.x = x + d.x * .27f;
			pt.y = y;
			pt.z = z + d.z * .27f;

			newParticleDef.groupNum		= pg;
			newParticleDef.where		= &pt;
			newParticleDef.delta		= &d;
			newParticleDef.scale		= RandomFloat() + 1.0f;
			newParticleDef.rotZ			= RandomFloat() * PI2;
			newParticleDef.rotDZ		= RandomFloat2() * 10.0f;
			newParticleDef.alpha		= 1.0f - (RandomFloat() * .4f);
			AddParticleToGroup(&newParticleDef);
		}
	}


	PlayEffect3D(EFFECT_PLANECRASH, &gCoord);

	DeleteEnemy(theNode);
}




/******************** CHECK IF RAMPHOR HIT PLAYER **********************/
//
// Returns true if enemy killed
//

static Boolean CheckIfRamphorHitPlayer(ObjNode *enemy)
{
short			p;
OGLLineSegment	lineSeg;
ObjNode			*hitObj;
OGLPoint3D		hitPt;
Boolean			killed;

	if (gGamePrefs.kiddieMode)							// don't hurt in kiddie mode
		return false;									// TODO: original function returned nothing, I assume we should return 0 here -IJ

	for (p = 0; p < gNumPlayers; p++)
	{
		if (gPlayerInfo[p].shieldPower > 0.0f)						// if player has shield then skip since other collision code handles this
			continue;

				/* GET COORD OF HEAD AND TAIL */

		FindCoordOfJoint(enemy, RAMPHOR_JOINTNUM_BUTT, &lineSeg.p1);
		FindCoordOfJoint(enemy, RAMPHOR_JOINTNUM_TAILTIP, &lineSeg.p2);


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

			killed = HurtRamphor(enemy, .2);

			return(killed);
		}

	}

	return(false);						//  not killed
}

