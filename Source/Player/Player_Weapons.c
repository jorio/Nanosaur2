/****************************/
/*   	PLAYER_WEAPONS.C    */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/

#include "game.h"

extern	float			gFramesPerSecondFrac,gFramesPerSecond,gGlobalTransparency;
extern	OGLPoint3D		gCoord;
extern	OGLVector3D		gDelta;
extern	NewObjectDefinitionType	gNewObjectDefinition;
extern	OGLSetupOutputType		*gGameViewInfoPtr;
extern	OGLVector3D		gRecentTerrainNormal;
extern	uint32_t			gAutoFadeStatusBits;
extern	NewParticleGroupDefType	gNewParticleGroupDef;
extern	SparkleType	gSparkles[];
extern	CollisionRec	gCollisionList[];
extern	short			gNumCollisions;
extern	ObjNode			*gFirstNodePtr;
extern	SpriteType		*gSpriteGroupList[];
extern	OGLBoundingBox			gObjectGroupBBoxList[MAX_BG3D_GROUPS][MAX_OBJECTS_IN_GROUP];


/****************************/
/*    PROTOTYPES            */
/****************************/

static void CalcPlayerGunMuzzleInfo(ObjNode *player, OGLPoint3D *muzzleCoord, OGLVector3D *muzzleVector);

static void ShootBlaster(ObjNode *player);
static void MoveBlasterBullet(ObjNode *theNode);
static Boolean	DoBlasterCollisionDetection(ObjNode *theNode);
static void DoBlasterImpactTerrainEffect(const OGLPoint3D *impactPt, const OGLVector3D *surfaceNormal);
static void DoBlasterImpactObjectEffect(const OGLPoint3D *impactPt, const OGLVector3D *surfaceNormal);

static void ShootClusterShot(ObjNode *player);
static void MoveClusterBullet(ObjNode *theNode);
static void FragmentClusterShot(ObjNode *parentShot);

static void ShootSonicScream(ObjNode *player);
static void MoveSonicScream(ObjNode *theNode);
static Boolean DoSonicScreamCollisionDetection(ObjNode *bullet);

static void ShootHeatSeeker(ObjNode *player);
static void MoveHeatSeekerBullet(ObjNode *theNode);
static Boolean	DoHeatSeekerCollisionDetection(ObjNode *theNode);
static void FindBulletTarget(ObjNode *bullet);
static void DoHeatSeekerImpactEffect(OGLPoint3D *where);

static void ShootBomb(ObjNode *player);
static void MovePlayerBomb(ObjNode *theNode);
static Boolean	DoBombCollisionDetection(ObjNode *theNode);
static void DoBombImpactEffect(OGLPoint3D *where);
static void LeaveBombTrail(ObjNode *theNode);
static ObjNode *MakeBombShockwave(OGLPoint3D *where);
static void MoveBombShockwave(ObjNode *theNode);


/****************************/
/*    CONSTANTS             */
/****************************/

#define	BLASTER_BULLET_SPEED	4000.0f

#define	BLASTER_AUTO_FIRE_DELAY	.16f

#define	NUM_SHOTS_IN_CLUSTER	4
#define	CLUSTER_BULLET_SPEED	2500.0f

#define	SONICSCREAM_SPEED		1800.0f

#define	HEATSEEKER_BULLET_MAX_SPEED	2300.0f

#define	HEATSEEKER_TURN_SPEED	3.8f				// smaller == more slide, larger = less slide

#define	HEATSEEKER_BUTT_OFF		50.0f

enum
{
	CLUSTER_SHOT_SINGLE,
	CLUSTER_SHOT_FRAGMENT
};



/*********************/
/*    VARIABLES      */
/*********************/

#define	SonicHeadScale		SpecialF[0]

#define	BulletTargetLocked	Flag[0]
#define	BulletTargetObj		SpecialPtr[0]
#define	BulletTargetCookie	Special[1]

const OGLVector3D	gPlayerMuzzleTipAim = {0,0,-1};				// aim vector of root body matrix (not the gun joint!)

float	gAutoFireDelay[MAX_PLAYERS] = {0,0};


/****************** UPDATE PLAYER CROSSHAIRS **********************/

void UpdatePlayerCrosshairs(ObjNode *player)
{
short				p = player->PlayerNum;
short				i;
float				f;
OGLPoint3D			coord;
OGLRay				ray;
ObjNode				*hitNode;
uint32_t				ctype;

		/*********************************************************************/
		/* DO RAY COLLISION AGAINST THE SCENE TO SEE WHAT THE CROSSHAIRS HIT */
		/*********************************************************************/

			/* CALC SIGHT VECTOR/RAY */

	OGLVector3D_Transform(&gPlayerMuzzleTipAim, &player->BaseTransformMatrix, &ray.direction);


			/* FIRST SEE IF RAY HITS ANY OBJNODES */

	ctype = CTYPE_AUTOTARGETWEAPON;							// look for things which auto target the weapon
	ctype |= CTYPE_PLAYER2 >> p;							// and also other players

	ray.origin = gCoord;
	hitNode = OGL_DoRayCollision_ObjNodes(&ray, STATUS_BIT_HIDDEN | (STATUS_BIT_ISCULLED1 << p), ctype, nil, nil);

	if (hitNode)
	{
		gPlayerInfo[p].crosshairTargetObj 		= hitNode;
		gPlayerInfo[p].crosshairTargetCookie 	= hitNode->Cookie;
	}
	else
		gPlayerInfo[p].crosshairTargetObj = nil;


			/************************/
			/* SET CROSSHAIR COORDS */
			/************************/

	if (gGamePrefs.stereoGlassesMode != STEREO_GLASSES_MODE_OFF)
		f = 800.0f;
	else
		f = 1000.0f;

	coord.x = player->Coord.x + (ray.direction.x * f);
	coord.y = player->Coord.y + (ray.direction.y * f);
	coord.z = player->Coord.z + (ray.direction.z * f);

	for (i = 0; i < NUM_CROSSHAIR_LEVELS; i++)
	{
		float	dist;

		gPlayerInfo[p].crosshairCoord[i] = coord;

		if (gGamePrefs.stereoGlassesMode != STEREO_GLASSES_MODE_OFF)
			dist = 500.0f;
		else
			dist = 5000.0f;

		coord.x += ray.direction.x * dist;
		coord.y += ray.direction.y * dist;
		coord.z += ray.direction.z * dist;
	}
}


#pragma mark -


/*********************** PLAYER FIRE BUTTON PRESSED ****************************/
//
// Called when player presses the Fire button
//

void PlayerFireButtonPressed(ObjNode *player, Boolean newFireButton)
{
short			playerNum = player->PlayerNum;
short			weaponType;
Boolean			didShoot = false;


	weaponType  = gPlayerInfo[playerNum].currentWeapon;

	if (weaponType == WEAPON_TYPE_NONE)							// bail if no weapon selected
		return;


			/************************************/
			/* SHOOT THE APPROPRIATE PROJECTILE */
			/************************************/


	gAutoFireDelay[playerNum] -= gFramesPerSecondFrac;

	switch(weaponType)
	{
					/* BLASTER */

		case	WEAPON_TYPE_BLASTER:
				if (gAutoFireDelay[playerNum] <= 0.0f)
				{
					ShootBlaster(player);
					gAutoFireDelay[playerNum] += BLASTER_AUTO_FIRE_DELAY;
					didShoot = true;
				}
				break;

					/*  CLUSTER SHOT */

		case	WEAPON_TYPE_CLUSTERSHOT:
				if (newFireButton)
				{
					ShootClusterShot(player);
					didShoot = true;
				}
				break;


					/*  SONIC SCREAM */

		case	WEAPON_TYPE_SONICSCREAM:
				if (newFireButton)
					gPlayerInfo[playerNum].weaponCharge = 0;							// start it charging
				else
				{
					gPlayerInfo[playerNum].weaponCharge += gFramesPerSecondFrac * .5f;	// continue charging
					if (gPlayerInfo[playerNum].weaponCharge > 1.0f)
						gPlayerInfo[playerNum].weaponCharge = 1.0f;

					if (gPlayerInfo[playerNum].weaponChargeChannel == -1)				// update charging sfx
						gPlayerInfo[playerNum].weaponChargeChannel = PlayEffect_Parms(EFFECT_WEAPONCHARGE, FULL_CHANNEL_VOLUME/3, FULL_CHANNEL_VOLUME/4, NORMAL_CHANNEL_RATE);
				}

				break;


					/*  HEAT SEEKER */

		case	WEAPON_TYPE_HEATSEEKER:
				if (newFireButton)
				{
					ShootHeatSeeker(player);
					didShoot = true;
				}
				break;


					/*  BOMB */

		case	WEAPON_TYPE_BOMB:
				if (newFireButton)
				{
					ShootBomb(player);
					didShoot = true;
				}
				break;


	}


			/********************/
			/* DEC THE QUANTITY */
			/********************/

	if (didShoot && (weaponType != WEAPON_TYPE_SONICSCREAM))
	{
		gPlayerInfo[playerNum].weaponQuantity[weaponType]--;		// dec bullet count
		if (gPlayerInfo[playerNum].weaponQuantity[weaponType] <= 0)	// if we're out, try to select next weapon in inventory
			SelectNextWeapon(playerNum, false);
	}
}


/*********************** PLAYER FIRE BUTTON RELEASED ****************************/
//
// Called when player releases a previously pressed Fire button
//
// This is used by weapons which require a charge before firing.
//

void PlayerFireButtonReleased(ObjNode *player)
{
short			playerNum = player->PlayerNum;
short			weaponType;
Boolean			didShoot = false;


	weaponType  = gPlayerInfo[playerNum].currentWeapon;

	if (weaponType == WEAPON_TYPE_NONE)							// bail if no weapon selected
		return;


			/************************************/
			/* SHOOT THE APPROPRIATE PROJECTILE */
			/************************************/


	switch(weaponType)
	{

					/*  SONIC SCREAM */

		case	WEAPON_TYPE_SONICSCREAM:
				StopAChannel(&gPlayerInfo[playerNum].weaponChargeChannel);

				if (gPlayerInfo[playerNum].weaponCharge > .3f)			// see if sufficient charge to fire the weapon
				{
					ShootSonicScream(player);
					didShoot = true;
				}
				break;
	}


	gPlayerInfo[playerNum].weaponCharge = 0;


			/********************/
			/* DEC THE QUANTITY */
			/********************/

	if (didShoot)
	{
		gPlayerInfo[playerNum].weaponQuantity[weaponType]--;		// dec bullet count
		if (gPlayerInfo[playerNum].weaponQuantity[weaponType] <= 0)	// if we're out, try to select next weapon in inventory
			SelectNextWeapon(playerNum, false);
	}

}


/********************** SELECT NEXT WEAPON *************************/
//
// Scans thru our weapon inventory starting at the current weapon, looking for another weapon
// which we have inventory for.
//

void SelectNextWeapon(short playerNum, Boolean allowSonicScream)
{
short	weaponType, i;

	gPlayerInfo[playerNum].weaponCharge = 0;					// make sure not charging

	weaponType  = gPlayerInfo[playerNum].currentWeapon;			// get currently selected weapon
	if (weaponType == WEAPON_TYPE_NONE)							// if nothing was selected then just start as though we had the first weapon type
		weaponType = 0;


			/* SCAN FOR ANOTHER WEAPON */

	i = weaponType;

	while(true)													// scan until we've looped back to where we started
	{
		i++;													// try next weapon slot
		if (i >= NUM_WEAPON_TYPES)								// loop back to front of list?
			i = 0;

		if (i == weaponType)									// did we loop to where we started?
		{
			if (i == WEAPON_TYPE_SONICSCREAM)					// if already SS, then bail
				return;

			i = WEAPON_TYPE_SONICSCREAM;						// must be out of everything, so default to sonic scream
			goto setthis;
		}

		if (!allowSonicScream)									// see if skip sonic scream
			if (i == WEAPON_TYPE_SONICSCREAM)
				continue;

		if (gPlayerInfo[playerNum].weaponQuantity[i] > 0)		// do we have any of this weapon type?
		{
setthis:
			StopAChannel(&gPlayerInfo[playerNum].weaponChargeChannel);		// make sure to stop this
			PlayEffect_Parms(EFFECT_CHANGEWEAPON, FULL_CHANNEL_VOLUME/2, FULL_CHANNEL_VOLUME/2, NORMAL_CHANNEL_RATE);
			gPlayerInfo[playerNum].currentWeapon = i;
			return;
		}

	}


			/* SHOULD NEVER GET HERE, BUT JUST IN CASE... */

	gPlayerInfo[playerNum].currentWeapon = WEAPON_TYPE_NONE;
}



#pragma mark -


/************************ SHOOT BLASTER ************************/

static void ShootBlaster(ObjNode *player)
{
ObjNode	*newObj;
OGLPoint3D	where;
OGLVector3D	aim;
short		i;

	CalcPlayerGunMuzzleInfo(player, &where, &aim);

				/************************/
				/* CREATE WEAPON OBJECT */
				/************************/

	gNewObjectDefinition.group 		= MODEL_GROUP_WEAPONS;
	gNewObjectDefinition.type 		= WEAPONS_ObjType_BlasterBullet;
	gNewObjectDefinition.coord		= where;
	gNewObjectDefinition.flags 		= STATUS_BIT_USEALIGNMENTMATRIX|STATUS_BIT_GLOW|STATUS_BIT_NOZWRITES|
										STATUS_BIT_NOFOG|STATUS_BIT_DOUBLESIDED|STATUS_BIT_NOTEXTUREWRAP|STATUS_BIT_NOLIGHTING;
	gNewObjectDefinition.slot 		= WATER_SLOT + 1;
	gNewObjectDefinition.moveCall 	= MoveBlasterBullet;
	gNewObjectDefinition.rot 		= 0;
	gNewObjectDefinition.scale 		= 4.0;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	newObj->Kind = WEAPON_TYPE_BLASTER;
	newObj->PlayerNum = player->PlayerNum;					// remember which player shot this

	newObj->ColorFilter.a = .99;							// do this just to turn on transparency so it'll glow

	newObj->Delta.x = aim.x * BLASTER_BULLET_SPEED;
	newObj->Delta.y = aim.y * BLASTER_BULLET_SPEED;
	newObj->Delta.z = aim.z * BLASTER_BULLET_SPEED;

	newObj->Health = 2.0f;

	if (gVSMode == VS_MODE_NONE)
		newObj->Damage = .2f;
	else
		newObj->Damage = .35f;							// more damage in 2P modes


				/* SET COLLISION */

	newObj->CType 			= CTYPE_HURTME;
	newObj->CBits			= 0;
	CreateCollisionBoxFromBoundingBox_Maximized(newObj, 1.0);


			/* SET THE ALIGNMENT MATRIX */

	SetAlignmentMatrix(&newObj->AlignmentMatrix, &aim);


			/* PLAYE SFX */

	PlayEffect_Parms3D(EFFECT_STUNGUN, &where, NORMAL_CHANNEL_RATE, .7);





		/*************************/
		/* MAKE SPARKLE FOR HEAD */
		/*************************/

	i = newObj->Sparkles[0] = GetFreeSparkle(newObj);			// make new sparkle
	if (i != -1)
	{
		static OGLPoint3D	sparkleOff = {0,0,-12};

		gSparkles[i].flags = SPARKLE_FLAG_OMNIDIRECTIONAL | SPARKLE_FLAG_TRANSFORMWITHOWNER;
		gSparkles[i].where = sparkleOff;

		gSparkles[i].color.r = 1;
		gSparkles[i].color.g = 1;
		gSparkles[i].color.b = 1;
		gSparkles[i].color.a = 1;

		gSparkles[i].scale 	= 100.0f;
		gSparkles[i].separation = 10.0f;

		gSparkles[i].textureNum = PARTICLE_SObjType_RedGlint;
	}

}




/******************* MOVE BLASTER BULLET ***********************/

static void MoveBlasterBullet(ObjNode *theNode)
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

	if (DoBlasterCollisionDetection(theNode))
		return;

	UpdateObject(theNode);
}



/***************** DO BLASTER COLLISION DETECTION ***********************/
//
// Returns TRUE if blaster bullet was deleted.
//

static Boolean	DoBlasterCollisionDetection(ObjNode *theNode)
{
OGLPoint3D		hitPt;
OGLVector3D		hitNormal;
ObjNode			*hitObj;
OGLLineSegment	lineSegment;
uint32_t			cType;

			/*****************************************/
			/* SEE IF LINE SEGMENT HITS ANY GEOMETRY */
			/*****************************************/


			/* CREATE LINE SEGMENT TO DO COLLISION WITH */

	lineSegment.p1 = theNode->OldCoord;								// from old coord

	lineSegment.p2.x = gCoord.x + theNode->MotionVector.x * 40.0f;	// to new coord (in front of center)
	lineSegment.p2.y = gCoord.y + theNode->MotionVector.y * 40.0f;
	lineSegment.p2.z = gCoord.z + theNode->MotionVector.z * 40.0f;


	cType = CTYPE_WEAPONTEST | CTYPE_FENCE | CTYPE_TERRAIN | CTYPE_WATER;	// set CTYPE mask to find what we're looking for
	cType |= CTYPE_PLAYER2 >> theNode->PlayerNum;							// also set to check hits on other player

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

		if (cType == CTYPE_WATER)
			CreateMultipleNewRipples(hitPt.x, hitPt.z, 10.0, 40.0, .5, 3);

		if (cType == CTYPE_TERRAIN)
			DoBlasterImpactTerrainEffect(&hitPt, &hitNormal);			// do special terrain impact
		else
			DoBlasterImpactObjectEffect(&hitPt, &hitNormal);			// do special object impact

		DeleteObject(theNode);
		return(true);
	}



	return(false);
}



/*************************** DO BLASTER IMPACT TERRAIN EFFECT ********************************/

static void DoBlasterImpactTerrainEffect(const OGLPoint3D *impactPt, const OGLVector3D *surfaceNormal)
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

			speed = 70.0f + RandomFloat() * 900.0f;
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


	PlayEffect_Parms3D(EFFECT_IMPACTSIZZLE, &gCoord, NORMAL_CHANNEL_RATE, .8);
}



/*************************** DO BLASTER IMPACT OBJECT EFFECT ********************************/

static void DoBlasterImpactObjectEffect(const OGLPoint3D *impactPt, const OGLVector3D *surfaceNormal)
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


	PlayEffect_Parms3D(EFFECT_IMPACTSIZZLE, &gCoord, NORMAL_CHANNEL_RATE, .8);
}


#pragma mark -


/************************ SHOOT CLUSTER SHOT ************************/

static void ShootClusterShot(ObjNode *player)
{
ObjNode	*newObj;
OGLPoint3D	where;
OGLVector3D	aim;

	CalcPlayerGunMuzzleInfo(player, &where, &aim);

				/************************/
				/* CREATE BULLET OBJECT */
				/************************/

	gNewObjectDefinition.group 		= MODEL_GROUP_WEAPONS;
	gNewObjectDefinition.type 		= WEAPONS_ObjType_ClusterBullet;
	gNewObjectDefinition.coord		= where;
	gNewObjectDefinition.flags 		= 0;
	gNewObjectDefinition.slot 		= 628;
	gNewObjectDefinition.moveCall 	= MoveClusterBullet;
	gNewObjectDefinition.rot 		= RandomFloat() * PI2;
	gNewObjectDefinition.scale 		= .9;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	newObj->Kind = WEAPON_TYPE_CLUSTERSHOT;
	newObj->PlayerNum = player->PlayerNum;					// remember which player shot this

	newObj->Mode = CLUSTER_SHOT_SINGLE;
	newObj->Timer = .6f;

	newObj->Delta.x = aim.x * CLUSTER_BULLET_SPEED;
	newObj->Delta.y = aim.y * CLUSTER_BULLET_SPEED;
	newObj->Delta.z = aim.z * CLUSTER_BULLET_SPEED;

	newObj->Health = 1.3f + RandomFloat() * .2f;
	newObj->Damage = .1f * NUM_SHOTS_IN_CLUSTER;			// the single one has as much power as all of the clusters combined

	newObj->Rot.x = RandomFloat2() * PI2;
	newObj->Rot.z = RandomFloat2() * PI2;
	newObj->DeltaRot.x = RandomFloat2() * 10.0f;
	newObj->DeltaRot.y = RandomFloat2() * 20.0f;


				/* SET COLLISION */

	newObj->CType 			= CTYPE_HURTME;
	newObj->CBits			= 0;
	CreateCollisionBoxFromBoundingBox_Maximized(newObj, 1.0);

	AttachShadowToObject(newObj, SHADOW_TYPE_CIRCULAR, 1, 1, false);



	PlayEffect_Parms3D(EFFECT_FLARESHOOT, &where, NORMAL_CHANNEL_RATE, .7);
}


/************************ FRAGMENT CLUSTER SHOT ************************/
//
// Breaks the single cluster shot into several fragments.
//

static void FragmentClusterShot(ObjNode *parentShot)
{
ObjNode	*newObj;
short	i;
float		zrot,yrot;
OGLMatrix4x4	m;
OGLVector3D		v;
OGLVector3D	aim;

	for (i = 0; i < NUM_SHOTS_IN_CLUSTER; i++)
	{

					/************************/
					/* CREATE BULLET OBJECT */
					/************************/

		gNewObjectDefinition.group 		= MODEL_GROUP_WEAPONS;
		gNewObjectDefinition.type 		= WEAPONS_ObjType_ClusterBullet;
		gNewObjectDefinition.coord		= parentShot->Coord;
		gNewObjectDefinition.flags 		= 0;
		gNewObjectDefinition.slot 		= 628;
		gNewObjectDefinition.moveCall 	= MoveClusterBullet;
		gNewObjectDefinition.rot 		= RandomFloat() * PI2;
		gNewObjectDefinition.scale 		= .9;
		newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

		newObj->Kind = WEAPON_TYPE_CLUSTERSHOT;
		newObj->PlayerNum = parentShot->PlayerNum;			// remember which player shot this

		newObj->Mode = CLUSTER_SHOT_FRAGMENT;

			/* CALC NEW VECTOR IN CONE OF AIM */

		FastNormalizeVector(gDelta.x, gDelta.y, gDelta.z, &aim);

		zrot = RandomFloat2() * .4f;
		yrot = RandomFloat2() * .4f;
		OGLMatrix4x4_SetRotate_XYZ(&m, 0, yrot, zrot);
		OGLVector3D_Transform(&aim, &m, &v);

		newObj->Delta.x = v.x * CLUSTER_BULLET_SPEED;
		newObj->Delta.y = v.y * CLUSTER_BULLET_SPEED;
		newObj->Delta.z = v.z * CLUSTER_BULLET_SPEED;

		newObj->Health = 1.9f + RandomFloat() * .2f;
		newObj->Damage = .34f;

		newObj->Rot.x = RandomFloat2() * PI2;
		newObj->Rot.z = RandomFloat2() * PI2;
		newObj->DeltaRot.x = RandomFloat2() * 10.0f;
		newObj->DeltaRot.y = RandomFloat2() * 20.0f;


					/* SET COLLISION */

		newObj->CType 			= CTYPE_HURTME;
		newObj->CBits			= 0;
		CreateCollisionBoxFromBoundingBox_Maximized(newObj, 1.0);

		AttachShadowToObject(newObj, SHADOW_TYPE_CIRCULAR, 1, 1, false);

	}


	PlayEffect_Parms3D(EFFECT_FLARESHOOT, &parentShot->Coord, NORMAL_CHANNEL_RATE * 3/2, .7);
}




/******************* MOVE CLUSTER BULLET ***********************/

static void MoveClusterBullet(ObjNode *theNode)
{
float	fps = gFramesPerSecondFrac;
short	i;

			/* SEE IF GONE */

	theNode->Health -= fps;
	if (theNode->Health <= 0.0f)
	{
		DeleteObject(theNode);
		return;
	}

	GetObjectInfo(theNode);


			/*******************/
			/* SEE IF FRAGMENT */
			/*******************/

	if (theNode->Mode == CLUSTER_SHOT_SINGLE)
	{
		theNode->Timer -= fps;
		if (theNode->Timer <= 0.0f)
		{
			FragmentClusterShot(theNode);
			DeleteObject(theNode);
			return;
		}
	}

	theNode->Rot.x += theNode->DeltaRot.x * fps;
	theNode->Rot.y += theNode->DeltaRot.y * fps;


			/* MOVE IT */

	gDelta.y -= 500.0f * fps;				// gravity

	gCoord.x += gDelta.x * fps;
	gCoord.y += gDelta.y * fps;
	gCoord.z += gDelta.z * fps;


		/***********************/
		/* SEE IF HIT ANYTHING */
		/***********************/

	if (DoBlasterCollisionDetection(theNode))
		return;

	UpdateObject(theNode);


		/************************/
		/* UPDATE SPARKLE TRAIL */
		/************************/


	theNode->ParticleTimer -= fps;
	if (theNode->ParticleTimer <= 0.0f)
	{
		int						particleGroup,magicNum;
		NewParticleGroupDefType	groupDef;
		NewParticleDefType		newParticleDef;
		OGLVector3D				d;

		theNode->ParticleTimer += .02f;										// reset timer

		particleGroup 	= theNode->ParticleGroup;
		magicNum 		= theNode->ParticleMagicNum;

		if ((particleGroup == -1) || (!VerifyParticleGroupMagicNum(particleGroup, magicNum)))
		{
			theNode->ParticleMagicNum = magicNum = MyRandomLong();			// generate a random magic num

			groupDef.magicNum				= magicNum;
			groupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
			groupDef.flags					= PARTICLE_FLAGS_DONTCHECKGROUND | PARTICLE_FLAGS_ALLAIM;
			groupDef.gravity				= 50;
			groupDef.magnetism				= 0;
			groupDef.baseScale				= 8;
			groupDef.decayRate				=  0;
			groupDef.fadeRate				= .5;
			groupDef.particleTextureNum		= PARTICLE_SObjType_GreenFumes;
			groupDef.srcBlend				= GL_SRC_ALPHA;
			groupDef.dstBlend				= GL_ONE;
			theNode->ParticleGroup = particleGroup = NewParticleGroup(&groupDef);
		}

		if (particleGroup != -1)
		{
			for (i = 0; i < 2; i++)
			{
				d.x = (gDelta.x * .1f) + RandomFloat2() * 20.0f;
				d.y = (gDelta.y * .1f) + RandomFloat2() * 20.0f;
				d.z = (gDelta.z * .1f) + RandomFloat2() * 20.0f;

				newParticleDef.groupNum		= particleGroup;
				newParticleDef.where		= &gCoord;
				newParticleDef.delta		= &d;
				newParticleDef.scale		= RandomFloat() + 1.0f;
				newParticleDef.rotZ			= RandomFloat() * PI2;
				newParticleDef.rotDZ		= RandomFloat2() * 5.0f;
				newParticleDef.alpha		= .5f + RandomFloat() * .2f;
				if (AddParticleToGroup(&newParticleDef))
				{
					theNode->ParticleGroup = -1;
					break;
				}
			}
		}
	}

}


#pragma mark -

/************************ SHOOT HEAT SEEKER ************************/

static void ShootHeatSeeker(ObjNode *player)
{
ObjNode	*newObj, *targetObj;
OGLPoint3D	where;
OGLVector3D	aim;
short		i, playerNum = player->PlayerNum;
float		speed;

	CalcPlayerGunMuzzleInfo(player, &where, &aim);

				/************************/
				/* CREATE BULLET OBJECT */
				/************************/

	gNewObjectDefinition.group 		= MODEL_GROUP_WEAPONS;
	gNewObjectDefinition.type 		= WEAPONS_ObjType_HeatSeekerBullet;
	gNewObjectDefinition.coord		= where;
	gNewObjectDefinition.flags 		= STATUS_BIT_USEALIGNMENTMATRIX;
	gNewObjectDefinition.slot 		= PLAYER_SLOT + 100;
	gNewObjectDefinition.moveCall 	= MoveHeatSeekerBullet;
	gNewObjectDefinition.rot 		= 0;
	gNewObjectDefinition.scale 		= .7;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	newObj->Kind = WEAPON_TYPE_HEATSEEKER;
	newObj->PlayerNum = playerNum;								// remember which player shot this

	speed = newObj->Speed = player->Speed + 300.0f;

	newObj->Delta.x = aim.x * speed;
	newObj->Delta.y = aim.y * speed;
	newObj->Delta.z = aim.z * speed;

	newObj->MotionVector = aim;


	newObj->Health = 4.0f;
	if (gVSMode == VS_MODE_NONE)
		newObj->Damage = .8f;
	else
		newObj->Damage = .4f;					// less damage in 2P mode


				/* SET COLLISION */

	newObj->CType 			= CTYPE_HURTME;
	newObj->CBits			= 0;
	CreateCollisionBoxFromBoundingBox_Maximized(newObj, 1.0);


			/* SET AUTO-TARGETING */

	targetObj = gPlayerInfo[playerNum].crosshairTargetObj;						// get object which crosshairs are targeting now
	if (targetObj != nil)
	{
		if (gPlayerInfo[playerNum].crosshairTargetCookie != targetObj->Cookie)	// make sure cookie still matches
			newObj->BulletTargetLocked = false;
		else
		{
			newObj->BulletTargetLocked = true;
			newObj->BulletTargetObj 	= targetObj;
			newObj->BulletTargetCookie 	= targetObj->Cookie;
		}
	}
			/* NOTHING HAS BEEN AUTO-TARGETED */
	else
		newObj->BulletTargetLocked = false;




			/* SET THE ALIGNMENT MATRIX */

	SetAlignmentMatrix(&newObj->AlignmentMatrix, &aim);


	AttachShadowToObject(newObj, SHADOW_TYPE_CIRCULAR, 2, 2, false);



		/**************************/
		/* MAKE SPARKLE FOR FLAME */
		/**************************/

	i = newObj->Sparkles[0] = GetFreeSparkle(newObj);			// make new sparkle
	if (i != -1)
	{
		static OGLPoint3D	sparkleOff = {0,0,HEATSEEKER_BUTT_OFF};

		gSparkles[i].flags = SPARKLE_FLAG_OMNIDIRECTIONAL | SPARKLE_FLAG_FLICKER | SPARKLE_FLAG_TRANSFORMWITHOWNER;
		gSparkles[i].where = sparkleOff;

		gSparkles[i].color.r = 1;
		gSparkles[i].color.g = 1;
		gSparkles[i].color.b = 1;
		gSparkles[i].color.a = 1;

		gSparkles[i].scale 	= 100.0f;
		gSparkles[i].separation = 20.0f;

		gSparkles[i].textureNum = PARTICLE_SObjType_WhiteSpark4;
	}


	PlayEffect_Parms3D(EFFECT_LAUNCHMISSILE, &where, NORMAL_CHANNEL_RATE, .8);
}


/******************* MOVE HEAT SEEKER BULLET ***********************/

static void MoveHeatSeekerBullet(ObjNode *theNode)
{
float			fps = gFramesPerSecondFrac;
OGLVector3D		v;
OGLPoint3D		targetPt;


			/* SEE IF GONE */

	theNode->Health -= fps;
	if (theNode->Health <= 0.0f)
	{
		DeleteObject(theNode);
		return;
	}

	GetObjectInfo(theNode);

			/*************************/
			/* UPDATE AUTO-TARGETING */
			/*************************/

		/* SEE IF NEED TO LOOK FOR TARGET */

	if (!theNode->BulletTargetLocked)
	{
		FindBulletTarget(theNode);

	}

			/* VERIFY EXISTING TARGET */
	else
	{
		ObjNode	*target = (ObjNode *)theNode->BulletTargetObj;				// get target objNode

		if ((uint32_t)theNode->BulletTargetCookie != (uint32_t)target->Cookie)					// verify that it's the same object
		{
			theNode->BulletTargetLocked = false;
		}

			/* UPDATE AIM TO TARGET */

		else
		{
			OGLPoint3D_Transform(&target->HeatSeekHotSpotOff, &target->BaseTransformMatrix, &targetPt);		// calc coord of hotspot we're shooting for

			OGLPoint3D_Subtract(&targetPt, &gCoord, &v);					// calc vector from bullet to target
			FastNormalizeVector(v.x, v.y, v.z, &v);

			OGLVector3D_MoveToVector(&theNode->MotionVector, &v, &theNode->MotionVector, HEATSEEKER_TURN_SPEED * fps);

		}
	}


			/* UPDATE DELTAS */

	theNode->Speed += fps * 1000.0f;								// accelerate bullet
	if (theNode->Speed > HEATSEEKER_BULLET_MAX_SPEED)
		theNode->Speed = HEATSEEKER_BULLET_MAX_SPEED;

	gDelta.x = theNode->MotionVector.x * theNode->Speed;
	gDelta.y = theNode->MotionVector.y * theNode->Speed;
	gDelta.z = theNode->MotionVector.z * theNode->Speed;


			/* MOVE IT */

	gCoord.x += gDelta.x * fps;
	gCoord.y += gDelta.y * fps;
	gCoord.z += gDelta.z * fps;


		/***********************/
		/* SEE IF HIT ANYTHING */
		/***********************/

	if (DoHeatSeekerCollisionDetection(theNode))
	{
		return;
	}



			/* UPDATE */

	SetAlignmentMatrix(&theNode->AlignmentMatrix, &theNode->MotionVector);

	UpdateObject(theNode);



		/**********************/
		/* UPDATE SMOKE TRAIL */
		/**********************/

	theNode->ParticleTimer -= fps;
	if (theNode->ParticleTimer <= 0.0f)
	{
		int						particleGroup,magicNum;
		NewParticleGroupDefType	groupDef;
		NewParticleDefType		newParticleDef;
		OGLVector3D				d;
		OGLPoint3D				p, buttPt;
		static OGLPoint3D		buttOff = {0,0,HEATSEEKER_BUTT_OFF};

		theNode->ParticleTimer += .015f;									// reset timer


		OGLPoint3D_Transform(&buttOff, &theNode->BaseTransformMatrix, &buttPt);		// calc butt coord where smoke comes from


		particleGroup 	= theNode->ParticleGroup;
		magicNum 		= theNode->ParticleMagicNum;

		if ((particleGroup == -1) || (!VerifyParticleGroupMagicNum(particleGroup, magicNum)))
		{
			theNode->ParticleMagicNum = magicNum = MyRandomLong();			// generate a random magic num

			groupDef.magicNum				= magicNum;
			groupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
			groupDef.flags					= PARTICLE_FLAGS_DONTCHECKGROUND | PARTICLE_FLAGS_ALLAIM;
			groupDef.gravity				= 0;
			groupDef.magnetism				= 0;
			groupDef.baseScale				= 9;
			groupDef.decayRate				=  -.5;
			groupDef.fadeRate				= .3;
			groupDef.particleTextureNum		= PARTICLE_SObjType_GreySmoke;
			groupDef.srcBlend				= GL_SRC_ALPHA;
			groupDef.dstBlend				= GL_ONE_MINUS_SRC_ALPHA;
			theNode->ParticleGroup = particleGroup = NewParticleGroup(&groupDef);
		}

		if (particleGroup != -1)
		{
			short	i;
			for (i = 0; i < 2; i++)
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
				newParticleDef.scale		= 1.0f + RandomFloat() * .5f;
				newParticleDef.rotZ			= RandomFloat() * PI2;
				newParticleDef.rotDZ		= RandomFloat2() * 3.0f;
				newParticleDef.alpha		= .4f + RandomFloat() * .1f;
				if (AddParticleToGroup(&newParticleDef))
				{
					theNode->ParticleGroup = -1;
					break;
				}
			}
		}
	}


				/* UPDATE EFFECT */

	if (theNode->EffectChannel == -1)
		theNode->EffectChannel = PlayEffect_Parms3D(EFFECT_MISSILEENGINE, &gCoord, NORMAL_CHANNEL_RATE, 1.0);
	else
		Update3DSoundChannel(EFFECT_MISSILEENGINE, &theNode->EffectChannel, &gCoord);



}


/****************** FIND BULLET TARGET *************************/

static void FindBulletTarget(ObjNode *bullet)
{
ObjNode		*thisNodePtr,*best = nil;
float	d,minDist = 10000000;
float	angle;
OGLVector3D	v;
uint32_t	ctype;
short	playerNum = bullet->PlayerNum;				// who shot this?


	ctype = CTYPE_AUTOTARGETWEAPON;					// look for things that auto-target
	ctype |= CTYPE_PLAYER2 >> playerNum;			// also target the other player

	thisNodePtr = gFirstNodePtr;

	do
	{
		if (thisNodePtr->Slot >= SLOT_OF_DUMB)					// see if reach end of usable list
			break;

		if (thisNodePtr->CType & ctype)
		{
					/* IS THIS BEST DIST */

			d = OGLPoint3D_Distance(&gCoord, &thisNodePtr->Coord);
			if (d < minDist)
			{
					/* IS GOOD ANGLE */

				OGLPoint3D_Subtract(&thisNodePtr->Coord, &gCoord, &v);		// calc vector to target
				FastNormalizeVector(v.x, v.y, v.z, &v);

				angle = acos(OGLVector3D_Dot(&v, &bullet->MotionVector));	// calc angle to target

				if (angle < (PI/6))
				{
					minDist = d;
					best = thisNodePtr;
				}
			}
		}
		thisNodePtr = (ObjNode *)thisNodePtr->NextNode;		// next node
	}
	while (thisNodePtr != nil);


	if (best)
	{
		bullet->BulletTargetLocked 	= true;
		bullet->BulletTargetObj 	= best;
		bullet->BulletTargetCookie 	= best->Cookie;
	}
	else
		bullet->BulletTargetLocked = false;

}


/***************** DO HEAT SEEKER COLLISION DETECTION ***********************/
//
// Returns TRUE if bullet was deleted.
//

static Boolean	DoHeatSeekerCollisionDetection(ObjNode *theNode)
{
OGLPoint3D		hitPt;
OGLVector3D		hitNormal, d;
ObjNode			*hitObj;
OGLLineSegment	lineSegment;
uint32_t			cType;

			/*****************************************/
			/* SEE IF LINE SEGMENT HITS ANY GEOMETRY */
			/*****************************************/

	FastNormalizeVector(gDelta.x, gDelta.y, gDelta.z, &d);						// get normalized delta

			/* CREATE LINE SEGMENT TO DO COLLISION WITH */

	lineSegment.p1 = theNode->OldCoord;											// from old coord

	lineSegment.p2.x = gCoord.x + d.x * 50.0f;									// to new coord (slightly in front)
	lineSegment.p2.y = gCoord.y + d.y * 50.0f;
	lineSegment.p2.z = gCoord.z + d.z * 50.0f;


	cType = CTYPE_WEAPONTEST | CTYPE_FENCE | CTYPE_TERRAIN | CTYPE_WATER;		// set CTYPE mask to find what we're looking for
	cType |= CTYPE_PLAYER2 >> theNode->PlayerNum;								// also set to check hits on other player

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

		if (cType == CTYPE_WATER)
			CreateMultipleNewRipples(hitPt.x, hitPt.z, 10.0, 40.0, .5, 3);


//		if (cType == CTYPE_TERRAIN)
//			DoBlasterImpactTerrainEffect(&hitPt, &hitNormal);			// do special terrain impact
//		else
//			DoBlasterImpactObjectEffect(&hitPt, &hitNormal);			// do special object impact

		DoHeatSeekerImpactEffect(&hitPt);


		DeleteObject(theNode);

		return(true);
	}



	return(false);
}



/************************ DO HEAT SEEKER IMPACT EFFECT *******************************/

static void DoHeatSeekerImpactEffect(OGLPoint3D *where)
{
long					pg,i;
OGLVector3D				d;
OGLPoint3D				pt;
NewParticleDefType		newParticleDef;
float					x,y,z;
ObjNode					*sw;

	x = where->x;
	y = where->y;
	z = where->z;

		/*********************/
		/* FIRST MAKE SPARKS */
		/*********************/

	gNewParticleGroupDef.magicNum				= 0;
	gNewParticleGroupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
	gNewParticleGroupDef.flags					= PARTICLE_FLAGS_DONTCHECKGROUND;
	gNewParticleGroupDef.gravity				= 1000;
	gNewParticleGroupDef.magnetism				= 0;
	gNewParticleGroupDef.baseScale				= 15;
	gNewParticleGroupDef.decayRate				=  .8;
	gNewParticleGroupDef.fadeRate				= .8;
	gNewParticleGroupDef.particleTextureNum		= PARTICLE_SObjType_RedSpark;
	gNewParticleGroupDef.srcBlend				= GL_SRC_ALPHA;
	gNewParticleGroupDef.dstBlend				= GL_ONE;
	pg = NewParticleGroup(&gNewParticleGroupDef);
	if (pg != -1)
	{

		for (i = 0; i < 50; i++)
		{
			pt.x = x + RandomFloat2() * 20.0f;
			pt.y = y + RandomFloat2()  * 20.0f;
			pt.z = z + RandomFloat2() * 20.0f;

			d.x = RandomFloat2() * 700.0f;
			d.y = RandomFloat2() * 700.0f;
			d.z = RandomFloat2() * 700.0f;


			newParticleDef.groupNum		= pg;
			newParticleDef.where		= &pt;
			newParticleDef.delta		= &d;
			newParticleDef.scale		= RandomFloat() + 1.0f;
			newParticleDef.rotZ			= 0;
			newParticleDef.rotDZ		= 0;
			newParticleDef.alpha		= FULL_ALPHA + (RandomFloat() * .3f);
			AddParticleToGroup(&newParticleDef);
		}
	}


		/***************/
		/* MAKE FLAMES */
		/***************/

	gNewParticleGroupDef.magicNum				= 0;
	gNewParticleGroupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
	gNewParticleGroupDef.flags					= PARTICLE_FLAGS_DONTCHECKGROUND;
	gNewParticleGroupDef.gravity				= 0;
	gNewParticleGroupDef.magnetism				= 0;
	gNewParticleGroupDef.baseScale				= 20;
	gNewParticleGroupDef.decayRate				=  -7.0;
	gNewParticleGroupDef.fadeRate				= 1.0;
	gNewParticleGroupDef.particleTextureNum		= PARTICLE_SObjType_Fire;
	gNewParticleGroupDef.srcBlend				= GL_SRC_ALPHA;
	gNewParticleGroupDef.dstBlend				= GL_ONE;
	pg = NewParticleGroup(&gNewParticleGroupDef);
	if (pg != -1)
	{
		for (i = 0; i < 60; i++)
		{
			pt.x = x + RandomFloat2() * 20.0f;
			pt.y = y + RandomFloat2() * 20.0f;
			pt.z = z + RandomFloat2() * 20.0f;

			d.y = RandomFloat2() * 270.0f;
			d.x = RandomFloat2() * 270.0f;
			d.z = RandomFloat2() * 270.0f;


			newParticleDef.groupNum		= pg;
			newParticleDef.where		= &pt;
			newParticleDef.delta		= &d;
			newParticleDef.scale		= RandomFloat() + 1.0f;
			newParticleDef.rotZ			= RandomFloat() * PI2;
			newParticleDef.rotDZ		= RandomFloat2() * 6.0f;
			newParticleDef.alpha		= FULL_ALPHA + (RandomFloat() * .3f);
			AddParticleToGroup(&newParticleDef);
		}
	}



		/******************/
		/* MAKE SHOCKWAVE */
		/******************/

	sw = MakeBombShockwave(where);
	sw->ColorFilter.r = .3f;
	sw->ColorFilter.g = .3f;
	sw->ColorFilter.a = .6f;
	sw->StatusBits |= STATUS_BIT_GLOW;



	PlayEffect_Parms3D(EFFECT_TURRETEXPLOSION, where, NORMAL_CHANNEL_RATE*3/2, .7);

}

#pragma mark -


/************************ SHOOT SONIC SCREAM ************************/

static void ShootSonicScream(ObjNode *player)
{
ObjNode	*newObj;
OGLPoint3D	where;
OGLVector3D	*aim;
static OGLPoint3D	offPt = {0, 0, -10};
short   p = player->PlayerNum;

			/* CALC MOUTH INFO */

	FindCoordOnJoint(player, PLAYER_JOINT_HEAD, &offPt, &where);
	aim = &player->MotionVector;


				/************************/
				/* CREATE BULLET OBJECT */
				/************************/

	gNewObjectDefinition.genre		= CUSTOM_GENRE;
	gNewObjectDefinition.slot 		= SLOT_OF_DUMB+10;
	gNewObjectDefinition.coord		= where;
	gNewObjectDefinition.moveCall 	= MoveSonicScream;
	gNewObjectDefinition.flags 		= 0;

	newObj = MakeNewObject(&gNewObjectDefinition);


	newObj->Kind = WEAPON_TYPE_SONICSCREAM;
	newObj->PlayerNum = p;									// remember which player shot this

	newObj->BoundingSphereRadius	= 100;					// set the bounding sphere for fence collisions

	newObj->Delta.x = aim->x * SONICSCREAM_SPEED;
	newObj->Delta.y = aim->y * SONICSCREAM_SPEED;
	newObj->Delta.z = aim->z * SONICSCREAM_SPEED;

	newObj->Health = gPlayerInfo[p].weaponCharge + .5f;		// set life to charge
	newObj->Damage = gPlayerInfo[p].weaponCharge;			// set damage to weapon charge

	newObj->SonicHeadScale = 1.0f;


				/* SET COLLISION */
				//
				// Nothing collides against this, instead the bullet collides against stuff
				// during its move function.
				//


	AddCollisionBoxToObject(newObj, 100, -100, -100, 100, 100, -100);



	PlayEffect_Parms3D(EFFECT_SONICSCREAM, &where, NORMAL_CHANNEL_RATE, .9);
}




/******************* MOVE SONIC SCREAM ***********************/

static void MoveSonicScream(ObjNode *theNode)
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

	if (DoSonicScreamCollisionDetection(theNode))
		return;

	UpdateObject(theNode);


		/*********************/
		/* UPDATE ECHO TRAIL */
		/*********************/

	theNode->ParticleTimer -= fps;
	if (theNode->ParticleTimer <= 0.0f)
	{
		int						particleGroup,magicNum;
		NewParticleGroupDefType	groupDef;
		NewParticleDefType		newParticleDef;
		OGLVector3D				d;

		theNode->ParticleTimer += .09f;										// reset timer

		theNode->SonicHeadScale *= 1.1f;							// scale up the head


		particleGroup 	= theNode->ParticleGroup;
		magicNum 		= theNode->ParticleMagicNum;

		if ((particleGroup == -1) || (!VerifyParticleGroupMagicNum(particleGroup, magicNum)))
		{
			theNode->ParticleMagicNum = magicNum = MyRandomLong();			// generate a random magic num

			groupDef.magicNum				= magicNum;
			groupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
			groupDef.flags					= PARTICLE_FLAGS_DONTCHECKGROUND|PARTICLE_FLAGS_ALLAIM;
			groupDef.gravity				= 50;
			groupDef.magnetism				= 0;
			groupDef.baseScale				= 15;
			groupDef.decayRate				= -theNode->SonicHeadScale * 10.0f;
			groupDef.fadeRate				= .9;
			groupDef.particleTextureNum		= PARTICLE_SObjType_Bubble;
			groupDef.srcBlend				= GL_SRC_ALPHA;
			groupDef.dstBlend				= GL_ONE_MINUS_SRC_ALPHA; //GL_ONE;
			theNode->ParticleGroup = particleGroup = NewParticleGroup(&groupDef);
		}

		if (particleGroup != -1)
		{
			d.x = gDelta.x * .25f;
			d.y = gDelta.y * .25f;
			d.z = gDelta.z * .25f;

			newParticleDef.groupNum		= particleGroup;
			newParticleDef.where		= &gCoord;
			newParticleDef.delta		= &d;
			newParticleDef.scale		= theNode->SonicHeadScale;
			newParticleDef.rotZ			= 0; //RandomFloat() * PI2;
			newParticleDef.rotDZ		= .1; //theNode->SonicHeadScale * 6.0f;
			newParticleDef.alpha		= 1;
			if (AddParticleToGroup(&newParticleDef))
			{
				theNode->ParticleGroup = -1;
			}
		}
	}
}


/********************** DO SONIC SCREAM COLLISION DETECTION **************************/
//
// Returns true if impacted anything and was deleted.
//

static Boolean DoSonicScreamCollisionDetection(ObjNode *bullet)
{
short	numHits, i;
uint32_t	ctype;
ObjNode	*hitObj;

			/***************************/
			/* SEE IF HIT ANY OBJNODES */
			/***************************/

				/* WHAT DO WE WANT TO HIT? */

	ctype = CTYPE_MISC | CTYPE_ENEMY | CTYPE_WEAPONTEST;
	ctype |= CTYPE_PLAYER2 >> bullet->PlayerNum;


				/* DOES THIS TOUCH ANYTHING? */

	numHits = DoSimpleBoxCollision(bullet->CollisionBoxes[0].top, bullet->CollisionBoxes[0].bottom,
									bullet->CollisionBoxes[0].left, bullet->CollisionBoxes[0].right,
									bullet->CollisionBoxes[0].front, bullet->CollisionBoxes[0].back,
									ctype);


	if (numHits > 0)
	{
					/* WE HIT SOMETHING */

		for (i = 0; i < numHits; i++)
		{
			hitObj = gCollisionList[i].objectPtr;
			if (hitObj)
			{
				if (hitObj->HitByWeaponHandler)								// see if there is a handler for this object
					hitObj->HitByWeaponHandler(bullet, hitObj, nil, nil);	// call the handler
			}
		}

				/* DELETE THE BULLET */

kill_bullet:
		DeleteObject(bullet);
		return(true);
	}


		/**********************/
		/* SEE IF HIT TERRAIN */
		/**********************/

	if (gCoord.y < GetTerrainY(gCoord.x, gCoord.z))
		goto kill_bullet;


		/********************/
		/* SEE IF HIT FENCE */
		/********************/

	if (DoFenceCollision(bullet))
		goto kill_bullet;



	return(false);
}



#pragma mark -


/************************ SHOOT BOMB ************************/

static void ShootBomb(ObjNode *player)
{
ObjNode		*newObj;
OGLPoint3D	where;
OGLVector3D	aim;
short		playerNum = player->PlayerNum;
float		speed;

	CalcPlayerGunMuzzleInfo(player, &where, &aim);

				/**********************/
				/* CREATE BOMB OBJECT */
				/**********************/

	gNewObjectDefinition.group 		= MODEL_GROUP_WEAPONS;
	gNewObjectDefinition.type 		= WEAPONS_ObjType_Bomb;
	gNewObjectDefinition.coord		= where;
	gNewObjectDefinition.flags 		= 0;
	gNewObjectDefinition.slot 		= PLAYER_SLOT + 100;
	gNewObjectDefinition.moveCall 	= MovePlayerBomb;
	gNewObjectDefinition.rot 		= player->Rot.y;
	gNewObjectDefinition.scale 		= .3;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	newObj->Kind 		= WEAPON_TYPE_BOMB;
	newObj->PlayerNum 	= playerNum;								// remember which player shot this

	newObj->Rot.x = player->Rot.x;
	UpdateObjectTransforms(newObj);


	speed = player->Speed + 200.0f;

	newObj->Delta.x = aim.x * speed;
	newObj->Delta.y = aim.y * speed;
	newObj->Delta.z = aim.z * speed;

	newObj->Damage = 1.0;


				/* SET COLLISION */

	newObj->CType 			= CTYPE_HURTME;
	newObj->CBits			= 0;
	CreateCollisionBoxFromBoundingBox_Maximized(newObj, 1.0);


	AttachShadowToObject(newObj, SHADOW_TYPE_CIRCULAR, 2, 2, false);



	PlayEffect_Parms3D(EFFECT_BOMBDROP, &where, NORMAL_CHANNEL_RATE, .8);

}



/******************* MOVE PLAYER BOMB ***********************/

static void MovePlayerBomb(ObjNode *theNode)
{
float			fps = gFramesPerSecondFrac;

	GetObjectInfo(theNode);


			/* MOVE IT */

	gDelta.y -= 800.0f * fps;							// gravity

	ApplyFrictionToDeltasXZ(500, &gDelta);				// air friction

	gCoord.x += gDelta.x * fps;
	gCoord.y += gDelta.y * fps;
	gCoord.z += gDelta.z * fps;


	theNode->Rot.x -= fps * 1.1f;						// tilt down
	if (theNode->Rot.x < (-PI/2))
		theNode->Rot.x = -PI/2;



		/***********************/
		/* SEE IF HIT ANYTHING */
		/***********************/

	if (DoBombCollisionDetection(theNode))
	{
		return;
	}



			/* UPDATE */

	UpdateObject(theNode);

	LeaveBombTrail(theNode);

}


/********************** LEAVE BOMB TRAIL *************************/

static void LeaveBombTrail(ObjNode *theNode)
{
int		i;
float	fps = gFramesPerSecondFrac;
int		particleGroup,magicNum;
NewParticleGroupDefType	groupDef;
NewParticleDefType	newParticleDef;
OGLVector3D			d;
OGLPoint3D			p;

	theNode->ParticleTimer -= fps;													// see if add smoke
	if (theNode->ParticleTimer <= 0.0f)
	{
		theNode->ParticleTimer += .03f;											// reset timer

		particleGroup 	= theNode->ParticleGroup;
		magicNum 		= theNode->ParticleMagicNum;

		if ((particleGroup == -1) || (!VerifyParticleGroupMagicNum(particleGroup, magicNum)))
		{

			theNode->ParticleMagicNum = magicNum = MyRandomLong();			// generate a random magic num

			groupDef.magicNum				= magicNum;
			groupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
			groupDef.flags					= PARTICLE_FLAGS_DONTCHECKGROUND|PARTICLE_FLAGS_ALLAIM;
			groupDef.gravity				= 0;
			groupDef.magnetism				= 0;
			groupDef.baseScale				= 10.0f;
			groupDef.decayRate				= 1.0f;
			groupDef.fadeRate				= 1.0;
			groupDef.particleTextureNum		= PARTICLE_SObjType_WhiteSpark;
			groupDef.srcBlend				= GL_SRC_ALPHA;
			groupDef.dstBlend				= GL_ONE;
			theNode->ParticleGroup = particleGroup = NewParticleGroup(&groupDef);
		}

		if (particleGroup != -1)
		{
			float	x,y,z;

			x = gCoord.x;
			y = gCoord.y;
			z = gCoord.z;

			for (i = 0; i < 2; i++)
			{
				p.x = x + RandomFloat2() * 5.0f;
				p.y = y + RandomFloat2() * 5.0f;
				p.z = z + RandomFloat2() * 5.0f;

				d.x = RandomFloat2() * 20.0f;
				d.y = RandomFloat2() * 20.0f;
				d.z = RandomFloat2() * 20.0f;

				newParticleDef.groupNum		= particleGroup;
				newParticleDef.where		= &p;
				newParticleDef.delta		= &d;
				newParticleDef.scale		= 1.0f;
				newParticleDef.rotZ			= 0;
				newParticleDef.rotDZ		= 0;
				newParticleDef.alpha		= .7;
				if (AddParticleToGroup(&newParticleDef))
				{
					theNode->ParticleGroup = -1;
					break;
				}
			}
		}
	}
}



/***************** DO BOMB COLLISION DETECTION ***********************/
//
// Returns TRUE if bomb bullet was deleted.
//

static Boolean	DoBombCollisionDetection(ObjNode *theNode)
{
OGLPoint3D		hitPt;
OGLVector3D		hitNormal, d;
ObjNode			*hitObj;
OGLLineSegment	lineSegment;
uint32_t			cType;

			/*****************************************/
			/* SEE IF LINE SEGMENT HITS ANY GEOMETRY */
			/*****************************************/

	FastNormalizeVector(gDelta.x, gDelta.y, gDelta.z, &d);						// get normalized delta

			/* CREATE LINE SEGMENT TO DO COLLISION WITH */

	lineSegment.p1 = theNode->OldCoord;											// from old coord

	lineSegment.p2.x = gCoord.x + d.x * 40.0f;									// to new coord (slightly in front)
	lineSegment.p2.y = gCoord.y + d.y * 40.0f;
	lineSegment.p2.z = gCoord.z + d.z * 40.0f;


	cType = CTYPE_WEAPONTEST | CTYPE_FENCE | CTYPE_TERRAIN | CTYPE_WATER;		// set CTYPE mask to find what we're looking for
	cType |= CTYPE_PLAYER2 >> theNode->PlayerNum;								// also set to check hits on other player

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

		if (cType == CTYPE_WATER)
			CreateMultipleNewRipples(hitPt.x, hitPt.z, 10.0, 40.0, .5, 3);

		DoBombImpactEffect(&hitPt);

		DeleteObject(theNode);

		return(true);
	}



	return(false);
}


/************************ DO BOMB IMPACT EFFECT *******************************/

static void DoBombImpactEffect(OGLPoint3D *where)
{
long					pg,i;
OGLVector3D				d;
OGLPoint3D				pt;
NewParticleDefType		newParticleDef;
float					x,y,z;

	x = where->x;
	y = where->y;
	z = where->z;


		/*********************/
		/* FIRST MAKE SPARKS */
		/*********************/

	gNewParticleGroupDef.magicNum				= 0;
	gNewParticleGroupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
	gNewParticleGroupDef.flags					= PARTICLE_FLAGS_ALLAIM|PARTICLE_FLAGS_DONTCHECKGROUND;
	gNewParticleGroupDef.gravity				= 1200;
	gNewParticleGroupDef.magnetism				= 0;
	gNewParticleGroupDef.baseScale				= 10;
	gNewParticleGroupDef.decayRate				=  .8;
	gNewParticleGroupDef.fadeRate				= 1.2;
	gNewParticleGroupDef.particleTextureNum		= PARTICLE_SObjType_YellowGlint;
	gNewParticleGroupDef.srcBlend				= GL_SRC_ALPHA;
	gNewParticleGroupDef.dstBlend				= GL_ONE;
	pg = NewParticleGroup(&gNewParticleGroupDef);
	if (pg != -1)
	{
		for (i = 0; i < 30; i++)
		{
			pt.x = x + RandomFloat2() * 20.0f;
			pt.y = y + RandomFloat()  * 20.0f;
			pt.z = z + RandomFloat2() * 20.0f;

			d.x = RandomFloat2() * 700.0f;
			d.y = RandomFloat() *  900.0f;
			d.z = RandomFloat2() * 700.0f;


			newParticleDef.groupNum		= pg;
			newParticleDef.where		= &pt;
			newParticleDef.delta		= &d;
			newParticleDef.scale		= RandomFloat() + 1.0f;
			newParticleDef.rotZ			= 0;
			newParticleDef.rotDZ		= 0;
			newParticleDef.alpha		= FULL_ALPHA + (RandomFloat() * .3f);
			AddParticleToGroup(&newParticleDef);
		}
	}


		/***************/
		/* MAKE FLAMES */
		/***************/

	gNewParticleGroupDef.magicNum				= 0;
	gNewParticleGroupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
	gNewParticleGroupDef.flags					= PARTICLE_FLAGS_ALLAIM|PARTICLE_FLAGS_DONTCHECKGROUND;
	gNewParticleGroupDef.gravity				= 0;
	gNewParticleGroupDef.magnetism				= 0;
	gNewParticleGroupDef.baseScale				= 20;
	gNewParticleGroupDef.decayRate				=  -7.0;
	gNewParticleGroupDef.fadeRate				= 1.0;
	gNewParticleGroupDef.particleTextureNum		= PARTICLE_SObjType_Fire;
	gNewParticleGroupDef.srcBlend				= GL_SRC_ALPHA;
	gNewParticleGroupDef.dstBlend				= GL_ONE;
	pg = NewParticleGroup(&gNewParticleGroupDef);
	if (pg != -1)
	{
		for (i = 0; i < 70; i++)
		{
			pt.x = x + RandomFloat2() * 20.0f;
			pt.y = y + RandomFloat() * 20.0f;
			pt.z = z + RandomFloat2() * 20.0f;

			d.y = RandomFloat2() * 100.0f;
			d.x = RandomFloat2() * 270.0f;
			d.z = RandomFloat2() * 270.0f;


			newParticleDef.groupNum		= pg;
			newParticleDef.where		= &pt;
			newParticleDef.delta		= &d;
			newParticleDef.scale		= RandomFloat() + 1.0f;
			newParticleDef.rotZ			= RandomFloat() * PI2;
			newParticleDef.rotDZ		= RandomFloat2() * 7.0f;
			newParticleDef.alpha		= FULL_ALPHA + (RandomFloat() * .3f);
			AddParticleToGroup(&newParticleDef);
		}
	}



		/******************/
		/* MAKE SHOCKWAVE */
		/******************/

	MakeBombShockwave(where);


	PlayEffect_Parms3D(EFFECT_TURRETEXPLOSION, where, NORMAL_CHANNEL_RATE*3/2, .7);

}


/*********************** MAKE BOMB SHOCKWAVE ***********************/

static ObjNode *MakeBombShockwave(OGLPoint3D *where)
{
ObjNode					*newObj;

	gNewObjectDefinition.group 		= MODEL_GROUP_WEAPONS;
	gNewObjectDefinition.type 		= WEAPONS_ObjType_BombShockwave;
	gNewObjectDefinition.coord		= *where;
	gNewObjectDefinition.flags 		= STATUS_BIT_NOZWRITES|STATUS_BIT_NOFOG|STATUS_BIT_NOLIGHTING;
	gNewObjectDefinition.slot 		= SLOT_OF_DUMB + 40;
	gNewObjectDefinition.moveCall 	= MoveBombShockwave;
	gNewObjectDefinition.rot 		= 0;
	gNewObjectDefinition.scale 		= 1.0;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	newObj->ColorFilter.a = .8;

	newObj->Damage = 1.0f;

	return(newObj);

}


/*********************** MOVE BOMB SHOCKWAVE *******************/

static void MoveBombShockwave(ObjNode *theNode)
{
float fps = gFramesPerSecondFrac;

			/* FADE */

	theNode->ColorFilter.a -= fps * 2.0f;
	if (theNode->ColorFilter.a <= 0.0f)
	{
		DeleteObject(theNode);
		return;
	}

	theNode->Scale.x =
	theNode->Scale.y =
	theNode->Scale.z += fps * 140.0f;

	UpdateObjectTransforms(theNode);

	CauseBombShockwaveDamage(theNode, CTYPE_ENEMY | CTYPE_PLAYER1 | CTYPE_PLAYER2 | CTYPE_WEAPONTEST);

}


/********************* CAUSE BOMB SHOCKWAVE DAMAGE ******************/

void CauseBombShockwaveDamage(ObjNode *wave, uint32_t ctype)
{
ObjNode	*thisNodePtr 	= gFirstNodePtr;
float	radius 			= wave->Scale.x * 10.0f;		// calc radius of sphere
float	x,y,z,d;
float	oldDamage;

	oldDamage = wave->Damage;						// remember original damager factor
	wave->Damage *= gFramesPerSecondFrac;			// set temporary damage

	x = wave->Coord.x;
	y = wave->Coord.y;
	z = wave->Coord.z;


		/* SCAN THRU NODES FOR TARGETS */

	do
	{
		if (thisNodePtr->Slot >= SLOT_OF_DUMB)			// see if reach end of usable list
			break;

		if (thisNodePtr->CType & ctype)					// is this something we'd care about?
		{
					/* SEE IF OBJECT IS INSIDE SHOCKWAVE RADIUS */

			d = CalcDistance3D(x, y, z, thisNodePtr->Coord.x, thisNodePtr->Coord.y, thisNodePtr->Coord.z);
			if (d < radius)
			{
				if (thisNodePtr->HitByWeaponHandler)
					thisNodePtr->HitByWeaponHandler(wave, thisNodePtr, nil, nil);
			}
		}
		thisNodePtr = (ObjNode *)thisNodePtr->NextNode;		// next node
	}
	while (thisNodePtr != nil);


	wave->Damage = oldDamage;

}


#pragma mark -


/********************* CALC PLAYER GUN MUZZLE INFO ******************/

static void CalcPlayerGunMuzzleInfo(ObjNode *player, OGLPoint3D *muzzleCoord, OGLVector3D *muzzleVector)
{
short	p, i;
static const OGLPoint3D 	muzzleTipOff_Left = {-15,14,-17};		// offsets from armpit joints to the gun muzzles
static const OGLPoint3D 	muzzleTipOff_Right = {15,14,-17};

	p = player->PlayerNum;
	gPlayerInfo[p].turretSide ^= 1;									// toggle turret side

			/* LEFT */

	if (gPlayerInfo[p].turretSide)
	{
		OGLPoint3D_Transform(&muzzleTipOff_Left, &player->BaseTransformMatrix, muzzleCoord);
		OGLVector3D_Transform(&gPlayerMuzzleTipAim, &player->BaseTransformMatrix, muzzleVector);
	}

			/* RIGHT */

	else
	{
		OGLPoint3D_Transform(&muzzleTipOff_Right, &player->BaseTransformMatrix, muzzleCoord);
		OGLVector3D_Transform(&gPlayerMuzzleTipAim, &player->BaseTransformMatrix, muzzleVector);
	}



			/* MAKE THIS MUZZLE'S SPARKLE GLOW BRIGHTER */

	{
		ObjNode	*jetpack = player->ChainNode;

		i = jetpack->Sparkles[gPlayerInfo[p].turretSide];
		if (i != -1)
		{
			gSparkles[i].color.a = 1.0;
			gSparkles[i].scale = 50;
		}
	}
}


