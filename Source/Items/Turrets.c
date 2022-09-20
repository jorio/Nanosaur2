/****************************/
/*   	TURRETS.C		    */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/


#include "game.h"

extern	float				gFramesPerSecondFrac,gFramesPerSecond,gTerrainPolygonSize;
extern	OGLPoint3D			gCoord;
extern	OGLVector3D			gDelta;
extern	NewObjectDefinitionType	gNewObjectDefinition;
extern	OGLBoundingBox 		gObjectGroupBBoxList[MAX_BG3D_GROUPS][MAX_OBJECTS_IN_GROUP];
extern	OGLSetupOutputType	*gGameViewInfoPtr;
extern	uint32_t				gAutoFadeStatusBits,gGlobalMaterialFlags;
extern	SparkleType	gSparkles[MAX_SPARKLES];
extern	short				gNumEnemies;
extern	SpriteType	*gSpriteGroupList[];
extern	AGLContext		gAGLContext;
extern	Byte				gCurrentSplitScreenPane;


/****************************/
/*    PROTOTYPES            */
/****************************/

static void MoveTowerTurret(ObjNode *tower);
static void ShootTurretGun(ObjNode *turret);
static void MoveTurretBullet(ObjNode *theNode);
static Boolean	DoTurretBlastCollisionDetection(ObjNode *theNode);
static void DoTurretBlastImpactTerrainEffect(const OGLPoint3D *impactPt, const OGLVector3D *surfaceNormal);
static void DoTurretBlastImpactObjectEffect(const OGLPoint3D *impactPt, const OGLVector3D *surfaceNormal);
static Boolean TurretHitByWeaponCallback(ObjNode *bullet, ObjNode *theNode, OGLPoint3D *hitCoord, OGLVector3D *hitTriangleNormal);
static void ExplodeTurret(ObjNode *base);



/****************************/
/*    CONSTANTS             */
/****************************/

#define	TURRET_SHOOT_DIST		3000.0f

#define	TOWER_TURRET_SCALE		2.5f

static const OGLPoint3D 	gTurretMuzzleTipOff =  {-61, 0, -115};
static const OGLVector3D	gTurretMuzzleTipAim = {0,0,-1};


/*********************/
/*    VARIABLES      */
/*********************/

#define	ShootTimer		SpecialF[0]


/************************* ADD TOWER TURRET *********************************/

Boolean AddTowerTurret(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*base, *turret, *wheel, *gun, *lens;
short	typeB, typeT, typeW, typeG;

	switch(gLevelNum)
	{
		case	LEVEL_NUM_ADVENTURE1:
		case	LEVEL_NUM_FLAG2:
		case	LEVEL_NUM_BATTLE1:
				typeB = LEVEL1_ObjType_TowerTurret_Base;
				typeT = LEVEL1_ObjType_TowerTurret_Turret;
				typeW = LEVEL1_ObjType_TowerTurret_Wheel;
				typeG = LEVEL1_ObjType_TowerTurret_Gun;
				break;

		case	LEVEL_NUM_ADVENTURE2:
		case	LEVEL_NUM_BATTLE2:
		case	LEVEL_NUM_RACE2:
				typeB = LEVEL2_ObjType_TowerTurret_Base;
				typeT = LEVEL2_ObjType_TowerTurret_Turret;
				typeW = LEVEL2_ObjType_TowerTurret_Wheel;
				typeG = LEVEL2_ObjType_TowerTurret_Gun;
				break;

		case	LEVEL_NUM_ADVENTURE3:
		case	LEVEL_NUM_RACE1:
		case	LEVEL_NUM_FLAG1:
				typeB = LEVEL3_ObjType_TowerTurret_Base;
				typeT = LEVEL3_ObjType_TowerTurret_Turret;
				typeW = LEVEL3_ObjType_TowerTurret_Wheel;
				typeG = LEVEL3_ObjType_TowerTurret_Gun;
				break;

		default:
				DoFatalAlert("AddTowerTurret: not here yet, call Brian!");
				return(false);
	}


				/**************/
				/* MAKE BASE */
				/**************/

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= typeB;
	gNewObjectDefinition.scale 		= TOWER_TURRET_SCALE;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= GetMinTerrainY(x,z, gNewObjectDefinition.group, gNewObjectDefinition.type, gNewObjectDefinition.scale);
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits;
	gNewObjectDefinition.slot 		= 331;
	gNewObjectDefinition.moveCall 	= MoveTowerTurret;
	gNewObjectDefinition.rot 		= RandomFloat() * PI2;
	base = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	base->TerrainItemPtr = itemPtr;								// keep ptr to item list

			/* SET COLLISION STUFF */

	base->CType 			= CTYPE_MISC;
	base->CBits				= CBITS_ALLSOLID;
	CreateCollisionBoxFromBoundingBox(base, 1, 1);

	base->Health = .8f;


				/***************/
				/* MAKE TURRET */
				/***************/

	gNewObjectDefinition.type 		= typeT;
	gNewObjectDefinition.slot++;
	gNewObjectDefinition.moveCall 	= nil;
	turret = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	turret->CType 			= CTYPE_WEAPONTEST | CTYPE_PLAYERTEST | CTYPE_AUTOTARGETWEAPON;
	turret->CBits			= CBITS_ALLSOLID;
	CreateCollisionBoxFromBoundingBox(turret, 1, 1);
	turret->HitByWeaponHandler 	= TurretHitByWeaponCallback;

	turret->HeatSeekHotSpotOff.x = 0;
	turret->HeatSeekHotSpotOff.y = 300.0f;
	turret->HeatSeekHotSpotOff.z = 0;


	base->ChainNode = turret;
	turret->ChainHead = base;




				/***************/
				/* MAKE WHEEL  */
				/***************/

	gNewObjectDefinition.type 		= typeW;
	gNewObjectDefinition.slot++;
	gNewObjectDefinition.flags 		|= STATUS_BIT_ROTZXY;
	wheel = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	wheel->CType 			= CTYPE_WEAPONTEST | CTYPE_PLAYERTEST | CTYPE_AUTOTARGETWEAPON;

	turret->ChainNode = wheel;
	wheel->ChainHead = turret;


				/************/
				/* MAKE GUN */
				/************/

	gNewObjectDefinition.type 		= typeG;
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits;
	gNewObjectDefinition.slot++;
	gun = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	gun->CType 			= CTYPE_WEAPONTEST | CTYPE_PLAYERTEST | CTYPE_AUTOTARGETWEAPON;

	wheel->ChainNode = gun;
	gun->ChainHead = wheel;


				/*************/
				/* MAKE LENS */
				/*************/

	gNewObjectDefinition.group 		= MODEL_GROUP_GLOBAL;
	gNewObjectDefinition.type 		= GLOBAL_ObjType_TowerTurret_Lens;
	gNewObjectDefinition.slot 		= SLOT_OF_DUMB;
	gNewObjectDefinition.flags 		|= STATUS_BIT_GLOW;
	lens = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	gun->ChainNode = lens;
	lens->ChainHead = gun;




	return(true);													// item was added
}


/********************** MOVE TOWER TURRET ***********************/

static void MoveTowerTurret(ObjNode *base)
{
ObjNode	*turret = base->ChainNode;
ObjNode	*wheel 	= turret->ChainNode;
ObjNode	*gun 	= wheel->ChainNode;
ObjNode	*lens 	= gun->ChainNode;
short		i, playerNum;
float	angle2, angle, dist;
OGLPoint3D	aimPt, muzzleCoord;
float	fps = gFramesPerSecondFrac;
float   turretShootDist;
Boolean	shootNow = false;
static const OGLPoint3D aimOff = {0,0,-150};
static const OGLPoint3D wheelOff = {31.837, 282.548, 0};
static const OGLPoint3D gunOff = {0, 283.141, 0};

		/* SEE IF GONE */

	if (TrackTerrainItem(base))
	{
		DeleteObject(base);
		return;
	}

			/*****************/
			/* UPDATE TURRET */
			/*****************/

	if (gGamePrefs.kiddieMode)
		goto dont_fire;

	gun->ShootTimer -= fps;

	dist = CalcDistanceToClosestPlayer(&turret->Coord, &playerNum);									// calc dist to player

	if (gLevelNum == LEVEL_NUM_ADVENTURE1)					// make this easier on level 1
		turretShootDist = TURRET_SHOOT_DIST * 2/3;
	else
		turretShootDist = TURRET_SHOOT_DIST;


	if (dist < (turretShootDist * 1.2))															// see if player is close enough for turret to aim
	{
		OGLPoint3D_Transform(&aimOff, &gPlayerInfo[playerNum].objNode->BaseTransformMatrix, &aimPt);// calc pt in front of player to aim ag
		OGLPoint3D_Transform(&gTurretMuzzleTipOff, &gun->BaseTransformMatrix, &muzzleCoord);		// calc coord of muzzle for more accurate rotation next
		angle =  TurnObjectTowardTarget(turret, &muzzleCoord, aimPt.x, aimPt.z, PI/2, false, nil);		// turn turret on y-axis

		UpdateObjectTransforms(turret);


					/* IF AIMED CLOSE, THEN ALSO AIM GUN */

		if (angle < (PI/4))
		{
			angle2 = TurnObjectTowardTargetOnX(gun, &gun->Coord, &aimPt, PI/2);
			if (angle2 < (PI/3))
			{
				if (dist < turretShootDist)								// see if player close enough to shoot at
				{
					if (gun->ShootTimer <= 0.0f)
						shootNow = true;									// shoot after updating gun below
				}
			}
		}
	}
			/* OUT OF RANGE OF PLAYER, SO JUST SPIN */
	else
	{
dont_fire:
		turret->Rot.y += fps;
		UpdateObjectTransforms(turret);
	}


				/***************/
				/* UPDATE LENS */
				/***************/

	lens->BaseTransformMatrix = turret->BaseTransformMatrix;			// match with turret
	SetObjectTransformMatrix(lens);


				/****************/
				/* UPDATE WHEEL */
				/****************/

	OGLPoint3D_Transform(&wheelOff, &turret->BaseTransformMatrix, &wheel->Coord);
	wheel->Rot.z += fps * PI2;
	wheel->Rot.y = turret->Rot.y;
	UpdateObjectTransforms(wheel);



				/**************/
				/* UPDATE GUN */
				/**************/

	OGLPoint3D_Transform(&gunOff, &turret->BaseTransformMatrix, &gun->Coord);
	gun->Rot.y = turret->Rot.y;

	UpdateObjectTransforms(gun);

	if (shootNow)
	{
		ShootTurretGun(gun);
	}



		/* UPDATE MUZZLE SPARKLE */

	i = gun->Sparkles[0];								// get sparkle index
	if (i != -1)
	{
		gSparkles[i].color.a -= fps * 4.0f;				// fade out
		if (gSparkles[i].color.a <= 0.0f)
		{
			DeleteSparkle(i);
			gun->Sparkles[0] = -1;
		}
	}
}


#pragma mark -

/*************************** TURRET HIT BY WEAPON CALLBACK *****************************/
//
// Returns true if object should stop bullet.
//

static Boolean TurretHitByWeaponCallback(ObjNode *bullet, ObjNode *theNode, OGLPoint3D *hitCoord, OGLVector3D *hitTriangleNormal)
{
#pragma unused (hitCoord, hitTriangleNormal)

		/* FIND BASE OBJECT */

	while(theNode->ChainHead)
		theNode = theNode->ChainHead;


		/* CAUSE DAMAGE */

	theNode->Health -= bullet->Damage;
	if (theNode->Health <= 0.0f)
	{
		ExplodeTurret(theNode);
	}

	return(true);
}


/********************* EXPLODE TURRET ***********************/

static void ExplodeTurret(ObjNode *base)
{
ObjNode	*node = base;
long					pg,i;
OGLVector3D				d;
OGLPoint3D				pt;
NewParticleDefType		newParticleDef;
float					x,y,z, q;

	PlayEffect_Parms3D(EFFECT_TURRETEXPLOSION, &base->Coord, NORMAL_CHANNEL_RATE, 2.0);

			/***************************************/
			/* DO SHARD EXPLOSION FOR ALL GEOMETRY */
			/***************************************/

	do
	{
		ExplodeGeometry(node, 240.0f + RandomFloat() * 50.0f, SHARD_MODE_FROMORIGIN, 1, .6);

		node = node->ChainNode;					// next obj in chain
	}while(node != nil);


		/*****************/
		/* MAKE FIREBALL */
		/*****************/

	x = base->Coord.x;
	y = base->Coord.y;
	z = base->Coord.z;

	gNewParticleGroupDef.magicNum				= 0;
	gNewParticleGroupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
	gNewParticleGroupDef.flags					= PARTICLE_FLAGS_DONTCHECKGROUND;
	gNewParticleGroupDef.gravity				= -50;
	gNewParticleGroupDef.magnetism				= 0;
	gNewParticleGroupDef.baseScale				= 18;
	gNewParticleGroupDef.decayRate				=  -4.0;
	gNewParticleGroupDef.fadeRate				= .7;
	gNewParticleGroupDef.particleTextureNum		= PARTICLE_SObjType_Fire;
	gNewParticleGroupDef.srcBlend				= GL_SRC_ALPHA;
	gNewParticleGroupDef.dstBlend				= GL_ONE;
	pg = NewParticleGroup(&gNewParticleGroupDef);
	if (pg != -1)
	{
		for (i = 0; i < 150; i++)
		{
			d.y = RandomFloat2() * 100.0f;
			d.x = RandomFloat2() * 100.0f;
			d.z = RandomFloat2() * 100.0f;

			pt.x = x + d.x * .2f;
			pt.y = y + RandomFloat() * (TOWER_TURRET_SCALE * 400.0f);
			pt.z = z + d.z * .2f;

			newParticleDef.groupNum		= pg;
			newParticleDef.where		= &pt;
			newParticleDef.delta		= &d;
			newParticleDef.scale		= RandomFloat() + 1.0f;
			newParticleDef.rotZ			= RandomFloat() * PI2;
			newParticleDef.rotDZ		= RandomFloat2() * 8.0f;
			newParticleDef.alpha		= 1.0f - (RandomFloat() * .3f);
			AddParticleToGroup(&newParticleDef);
		}
	}


		/***************/
		/* MAKE SPARKS */
		/***************/

	gNewParticleGroupDef.magicNum				= 0;
	gNewParticleGroupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
	gNewParticleGroupDef.flags					= PARTICLE_FLAGS_DONTCHECKGROUND;
	gNewParticleGroupDef.gravity				= 100;
	gNewParticleGroupDef.magnetism				= 0;
	gNewParticleGroupDef.baseScale				= 15;
	gNewParticleGroupDef.decayRate				=  .2;
	gNewParticleGroupDef.fadeRate				= .5;
	gNewParticleGroupDef.particleTextureNum		= PARTICLE_SObjType_WhiteSpark4;
	gNewParticleGroupDef.srcBlend				= GL_SRC_ALPHA;
	gNewParticleGroupDef.dstBlend				= GL_ONE;
	pg = NewParticleGroup(&gNewParticleGroupDef);
	if (pg != -1)
	{
		for (i = 0; i < 200; i++)
		{
			q = RandomFloat() * PI2;
			d.x = sin(q) * 600.0f;
			d.y = RandomFloat() * 80.0f;
			d.z = cos(q) * 600.0f;

			pt.x = x + d.x * .05f;
			pt.y = y + (TOWER_TURRET_SCALE * 220.0f);
			pt.z = z + d.z * .05f;

			newParticleDef.groupNum		= pg;
			newParticleDef.where		= &pt;
			newParticleDef.delta		= &d;
			newParticleDef.scale		= RandomFloat() + 1.0f;
			newParticleDef.rotZ			= 0;
			newParticleDef.rotDZ		= 0;
			newParticleDef.alpha		= 1.0f + (RandomFloat() * .3f);
			AddParticleToGroup(&newParticleDef);
		}
	}





			/* DELETE THE ENTIRE TURRET HIERARCHY */

	base->TerrainItemPtr = nil;				// dont ever come back
	DeleteObject(base);

}


#pragma mark -

/*********************** SHOOT TURRET GUN **************************/

static void ShootTurretGun(ObjNode *gun)
{
int			i;
OGLPoint3D	muzzleCoord;
OGLVector3D	muzzleVector;
ObjNode	*newObj;

	gun->ShootTimer = .3f;											// reset delay

		/*********************/
		/* MAKE MUZZLE FLASH */
		/*********************/

	if (gun->Sparkles[0] != -1)								// see if delete existing sparkle
	{
		DeleteSparkle(gun->Sparkles[0]);
		gun->Sparkles[0] = -1;
	}

	i = gun->Sparkles[0] = GetFreeSparkle(gun);		// make new sparkle
	if (i != -1)
	{
		gSparkles[i].flags = SPARKLE_FLAG_TRANSFORMWITHOWNER|SPARKLE_FLAG_OMNIDIRECTIONAL;
		gSparkles[i].where = gTurretMuzzleTipOff;

		gSparkles[i].color.r = 1;
		gSparkles[i].color.g = 1;
		gSparkles[i].color.b = 1;
		gSparkles[i].color.a = 1;

		gSparkles[i].scale 	= 200.0f;
		gSparkles[i].separation = 10.0f;

		gSparkles[i].textureNum = PARTICLE_SObjType_YellowGlint;
	}

			/************************/
			/* CREATE WEAPON OBJECT */
			/************************/

		/* CALC COORD & VECTOR OF MUZZLE */

	OGLPoint3D_Transform(&gTurretMuzzleTipOff, &gun->BaseTransformMatrix, &muzzleCoord);
	OGLVector3D_Transform(&gTurretMuzzleTipAim, &gun->BaseTransformMatrix, &muzzleVector);

				/* MAKE OBJECT */

	gNewObjectDefinition.group 		= MODEL_GROUP_GLOBAL;
	gNewObjectDefinition.type 		= GLOBAL_ObjType_TowerTurret_TurretBullet;
	gNewObjectDefinition.coord		= muzzleCoord;
	gNewObjectDefinition.flags 		= STATUS_BIT_USEALIGNMENTMATRIX|STATUS_BIT_GLOW|STATUS_BIT_NOZWRITES|
									STATUS_BIT_NOFOG|STATUS_BIT_DOUBLESIDED|STATUS_BIT_NOTEXTUREWRAP;
	gNewObjectDefinition.slot 		= SLOT_OF_DUMB-1;
	gNewObjectDefinition.moveCall 	= MoveTurretBullet;
	gNewObjectDefinition.rot 		= 0;
	gNewObjectDefinition.scale 		= 3.0;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);


	newObj->Kind = WEAPON_TYPE_BLASTER;

	newObj->ColorFilter.a = .99;			// do this just to turn on transparency so it'll glow

	newObj->Delta.x = muzzleVector.x * 3000.0f;
	newObj->Delta.y = muzzleVector.y * 3000.0f;
	newObj->Delta.z = muzzleVector.z * 3000.0f;

	newObj->Health = 1.0f;

	newObj->Damage = .08f;

			/* SET THE ALIGNMENT MATRIX */

	SetAlignmentMatrix(&newObj->AlignmentMatrix, &muzzleVector);


	PlayEffect3D(EFFECT_TURRETFIRE, &newObj->Coord);



		/*************************/
		/* MAKE SPARKLE FOR HEAD */
		/*************************/

	i = newObj->Sparkles[0] = GetFreeSparkle(newObj);			// make new sparkle
	if (i != -1)
	{
		static OGLPoint3D	sparkleOff = {0,0,-15};

		gSparkles[i].flags = SPARKLE_FLAG_OMNIDIRECTIONAL | SPARKLE_FLAG_TRANSFORMWITHOWNER;
		gSparkles[i].where = sparkleOff;

		gSparkles[i].color.r = 1;
		gSparkles[i].color.g = 1;
		gSparkles[i].color.b = 1;
		gSparkles[i].color.a = 1;

		gSparkles[i].scale 	= 350.0f;
		gSparkles[i].separation = 10.0f;

		gSparkles[i].textureNum = PARTICLE_SObjType_GreenGlint;
	}

}



/******************* MOVE TURRET BULLET ***********************/

static void MoveTurretBullet(ObjNode *theNode)
{
float	fps = gFramesPerSecondFrac;

			/* SEE IF GONE */

	theNode->Health -= fps;
	if (theNode->Health <= 0.0f)
	{
		DeleteObject(theNode);
		return;
	}


	GetObjectInfo(theNode);

			/* MOVE IT */

	gCoord.x += gDelta.x * fps;
	gCoord.y += gDelta.y * fps;
	gCoord.z += gDelta.z * fps;


			/***********************/
			/* SEE IF HIT ANYTHING */
			/***********************/

	if (DoTurretBlastCollisionDetection(theNode))
		return;

	UpdateObject(theNode);
}




/***************** DO TURRET BLAST COLLISION DETECTION ***********************/
//
// Returns TRUE if blaster bullet was deleted.
//

static Boolean	DoTurretBlastCollisionDetection(ObjNode *theNode)
{
OGLPoint3D		hitPt;
OGLVector3D		hitNormal;
ObjNode			*hitObj;
OGLLineSegment	lineSegment;
uint32_t			cType;

			/* CREATE LINE SEGMENT TO DO COLLISION WITH */

	lineSegment.p1 = theNode->OldCoord;								// from old coord

	lineSegment.p2.x = gCoord.x + theNode->MotionVector.x * 50.0f;	// to new coord (in front of center)
	lineSegment.p2.y = gCoord.y + theNode->MotionVector.y * 50.0f;
	lineSegment.p2.z = gCoord.z + theNode->MotionVector.z * 50.0f;


			/*****************************************/
			/* SEE IF LINE SEGMENT HITS ANY GEOMETRY */
			/*****************************************/

	cType = CTYPE_MISC | CTYPE_FENCE | CTYPE_TERRAIN | CTYPE_PLAYER1 | CTYPE_PLAYER2;	// set CTYPE mask to find what we're looking for

	if (HandleLineSegmentCollision(&lineSegment, &hitObj, &hitPt, &hitNormal, &cType, true))
	{
			/* DID WE HIT AN OBJNODE? */

		if (hitObj)
		{
			if (hitObj->HitByWeaponHandler)											// see if there is a handler for this object
				hitObj->HitByWeaponHandler(theNode, hitObj, &hitPt, &hitNormal);	// call the handler
		}

				/**********************/
				/* EXPLODE THE BULLET */
				/**********************/

		if (cType == CTYPE_TERRAIN)
			DoTurretBlastImpactTerrainEffect(&hitPt, &hitNormal);			// do special terrain impact
		else
			DoTurretBlastImpactObjectEffect(&hitPt, &hitNormal);			// do special object impact

		DeleteObject(theNode);
		return(true);
	}

	return(false);
}



/*************************** DO TURRET BLAST IMPACT TERRAIN EFFECT ********************************/

static void DoTurretBlastImpactTerrainEffect(const OGLPoint3D *impactPt, const OGLVector3D *surfaceNormal)
{
OGLPoint3D				coord = *impactPt;
NewParticleDefType		newParticleDef;
OGLMatrix4x4			m;
float					zrot,yrot, speed;
long					pg,i;
OGLVector3D				delta,v;


			/* CREATE NEW PARTICLE GROUP */

	gNewParticleGroupDef.magicNum				= 0;
	gNewParticleGroupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
	gNewParticleGroupDef.flags					= PARTICLE_FLAGS_BOUNCE;
	gNewParticleGroupDef.gravity				= 1000;
	gNewParticleGroupDef.magnetism				= 0;
	gNewParticleGroupDef.baseScale				= 15.0f;
	gNewParticleGroupDef.decayRate				= -1.7f;
	gNewParticleGroupDef.fadeRate				= .6;
	gNewParticleGroupDef.particleTextureNum		= PARTICLE_SObjType_RedSpark;
	gNewParticleGroupDef.srcBlend				= GL_SRC_ALPHA;
	gNewParticleGroupDef.dstBlend				= GL_ONE;

	pg = NewParticleGroup(&gNewParticleGroupDef);
	if (pg != -1)
	{
		for (i = 0; i < 130; i++)
		{
			/* CALC NEW VECTOR IN CONE OF AIM */

			zrot = RandomFloat2() * .15f;
			yrot = RandomFloat2() * .15f;
			OGLMatrix4x4_SetRotate_XYZ(&m, 0, yrot, zrot);
			OGLVector3D_Transform(surfaceNormal, &m, &v);

			speed = 30.0f + RandomFloat() * 900.0f;
			delta.x = v.x * speed;
			delta.y = v.y * speed;
			delta.z = v.z * speed;

			newParticleDef.groupNum		= pg;
			newParticleDef.where		= &coord;
			newParticleDef.delta		= &delta;
			newParticleDef.scale		= 1.0f + RandomFloat() * 1.5f;
			newParticleDef.rotZ			= RandomFloat() * PI2;
			newParticleDef.rotDZ		= RandomFloat() * 11.0f;
			newParticleDef.alpha		= FULL_ALPHA - RandomFloat() * .5f;
			if (AddParticleToGroup(&newParticleDef))
				break;
		}
	}


	PlayEffect3D(EFFECT_IMPACTSIZZLE, &gCoord);
}



/*************************** DO TURRET BLAST IMPACT OBJECT EFFECT ********************************/

static void DoTurretBlastImpactObjectEffect(const OGLPoint3D *impactPt, const OGLVector3D *surfaceNormal)
{
OGLPoint3D				coord = *impactPt;
NewParticleDefType		newParticleDef;
OGLMatrix4x4			m;
float					zrot,yrot, speed;
long					pg,i;
OGLVector3D				delta,v;


			/* CREATE NEW PARTICLE GROUP */

	gNewParticleGroupDef.magicNum				= 0;
	gNewParticleGroupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
	gNewParticleGroupDef.flags					= PARTICLE_FLAGS_BOUNCE | PARTICLE_FLAGS_ALLAIM;
	gNewParticleGroupDef.gravity				= 100;
	gNewParticleGroupDef.magnetism				= 0;
	gNewParticleGroupDef.baseScale				= 10.0f;
	gNewParticleGroupDef.decayRate				= -1.2f;
	gNewParticleGroupDef.fadeRate				= .9;
	gNewParticleGroupDef.particleTextureNum		= PARTICLE_SObjType_RedSpark;
	gNewParticleGroupDef.srcBlend				= GL_SRC_ALPHA;
	gNewParticleGroupDef.dstBlend				= GL_ONE;

	pg = NewParticleGroup(&gNewParticleGroupDef);
	if (pg != -1)
	{
		for (i = 0; i < 50; i++)
		{
			/* CALC NEW VECTOR IN CONE OF AIM */

			zrot = RandomFloat2() * .15f;
			yrot = RandomFloat2() * .15f;
			OGLMatrix4x4_SetRotate_XYZ(&m, 0, yrot, zrot);
			OGLVector3D_Transform(surfaceNormal, &m, &v);

			speed = 30.0f + RandomFloat() * 300.0f;
			delta.x = v.x * speed;
			delta.y = v.y * speed;
			delta.z = v.z * speed;

			newParticleDef.groupNum		= pg;
			newParticleDef.where		= &coord;
			newParticleDef.delta		= &delta;
			newParticleDef.scale		= 1.0f + RandomFloat() * 1.5f;
			newParticleDef.rotZ			= RandomFloat() * PI2;
			newParticleDef.rotDZ		= RandomFloat() * 11.0f;
			newParticleDef.alpha		= FULL_ALPHA - RandomFloat() * .5f;
			if (AddParticleToGroup(&newParticleDef))
				break;
		}
	}


	PlayEffect3D(EFFECT_IMPACTSIZZLE, &gCoord);
}






























