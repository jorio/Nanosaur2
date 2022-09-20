/****************************/
/*   	FOREST DOOR.C	    */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/


#include "3DMath.h"

extern	float				gFramesPerSecondFrac,gFramesPerSecond,gTerrainPolygonSize;
extern	OGLPoint3D			gCoord;
extern	OGLVector3D			gDelta;
extern	NewObjectDefinitionType	gNewObjectDefinition;
extern	OGLBoundingBox 		gObjectGroupBBoxList[MAX_BG3D_GROUPS][MAX_OBJECTS_IN_GROUP];
extern	OGLSetupOutputType	*gGameViewInfoPtr;
extern	u_long				gAutoFadeStatusBits,gGlobalMaterialFlags;
extern	SparkleType	gSparkles[MAX_SPARKLES];
extern	short				gNumEnemies;
extern	SpriteType	*gSpriteGroupList[];
extern	AGLContext		gAGLContext;
extern	Byte				gCurrentSplitScreenPane;


/****************************/
/*    PROTOTYPES            */
/****************************/

static void MoveForestDoor(ObjNode *wall);

static Boolean ForestDoorKeyHitByWeaponCallback(ObjNode *bullet, ObjNode *mine, OGLPoint3D *hitCoord, OGLVector3D *hitTriangleNormal);
static Boolean DoTrig_ForestDoorKey(ObjNode *theNode, ObjNode *player);
static void	DestroyForestDoorKey(ObjNode *keyHolder);
static void MoveForestDoorKey(ObjNode *keyHolder);


/****************************/
/*    CONSTANTS             */
/****************************/

#define	DAMDOOR_SCALE	1.85f

#define	MAX_DAM_DOORS	64

/*********************/
/*    VARIABLES      */
/*********************/

static Boolean	gForestDoorOpen[MAX_DAM_DOORS];


/********************* INIT FOREST DOORS *************************/

void InitForestDoors(void)
{
short	i;

	for (i = 0; i < MAX_DAM_DOORS; i++)
		gForestDoorOpen[i] = false;

}


/************************* ADD FOREST DOOR *********************************/

Boolean AddForestDoor(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode				*wall, *door, *ring;
Byte				keyID = itemPtr->parm[0];
float				rot = (float)itemPtr->parm[1] * (PI/2);
short			type;

	switch(gLevelNum)
	{
		case	LEVEL_NUM_ADVENTURE1:
				type = LEVEL1_ObjType_ForestDoor_Wall;
				break;

		case	LEVEL_NUM_ADVENTURE2:
				type = LEVEL2_ObjType_ForestDoor_Wall;
				break;

		case	LEVEL_NUM_ADVENTURE3:
		case	LEVEL_NUM_RACE1:
		case	LEVEL_NUM_FLAG1:
				type = LEVEL3_ObjType_ForestDoor_Wall;
				break;

		default:
				DoFatalAlert("\pAddForestDoor: no door here yet, call Brian!");
				return(false);
	}

				/*****************/
				/* MAKE DAM WALL */
				/*****************/

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= type;
	gNewObjectDefinition.scale 		= DAMDOOR_SCALE;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= itemPtr->terrainY;
	gNewObjectDefinition.flags 		= 0;
	gNewObjectDefinition.slot 		= 176;
	gNewObjectDefinition.moveCall 	= MoveForestDoor;
	gNewObjectDefinition.rot 		= rot;
	wall = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	wall->TerrainItemPtr = itemPtr;								// keep ptr to item list

			/* SET COLLISION STUFF */

	wall->CType 			= CTYPE_SOLIDTOENEMY | CTYPE_WEAPONTEST | CTYPE_PLAYERTEST;
	wall->CBits				= CBITS_ALLSOLID;
	CreateCollisionBoxFromBoundingBox_Rotated(wall, 1, 1);


	wall->TriggerCallback 	= DoTrig_MiscSmackableObject;

	wall->Kind = keyID;


				/*************/
				/* MAKE DOOR */
				/*************/

	gNewObjectDefinition.group 		= MODEL_GROUP_GLOBAL;
	gNewObjectDefinition.type 		= GLOBAL_ObjType_ForestDoor_Door;
	gNewObjectDefinition.flags 		|= STATUS_BIT_ROTZXY;
	gNewObjectDefinition.coord.y 	= wall->Coord.y + DAMDOOR_SCALE * 70.0f;
	gNewObjectDefinition.slot++;
	gNewObjectDefinition.moveCall 	= nil;
	door = MakeNewDisplayGroupObject(&gNewObjectDefinition);

			/* SET COLLISION STUFF */

	door->CType 			= CTYPE_WEAPONTEST | CTYPE_PLAYERTEST;


	if (gForestDoorOpen[keyID])			// see if door is open
	{
		door->Rot.z = -PI;
		UpdateObjectTransforms(door);
	}

	wall->ChainNode = door;
	door->ChainHead = wall;

				/*************/
				/* MAKE RING */
				/*************/

	gNewObjectDefinition.type 		= GLOBAL_ObjType_ForestDoor_Ring;
	gNewObjectDefinition.flags 		|= STATUS_BIT_GLOW  | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOFOG | STATUS_BIT_UVTRANSFORM;
	gNewObjectDefinition.slot		= SLOT_OF_DUMB-1;
	ring = MakeNewDisplayGroupObject(&gNewObjectDefinition);

			/* SET COLLISION STUFF */

	ring->CType 			= CTYPE_WEAPONTEST | CTYPE_PLAYERTEST;

	door->ChainNode = ring;
	ring->ChainHead = door;


	return(true);													// item was added
}


/********************** MOVE FOREST DOOR ***********************/

static void MoveForestDoor(ObjNode *wall)
{
float	fps = gFramesPerSecondFrac;
ObjNode	*door = wall->ChainNode;
ObjNode	*ring = door->ChainNode;

		/* SEE IF GONE */

	if (TrackTerrainItem(wall))
	{
		DeleteObject(wall);
		return;
	}

		/* SEE IF OPEN DOOR */

	if (gForestDoorOpen[wall->Kind])
	{

		door->Rot.z -= fps;

		if (gLevelNum != LEVEL_NUM_ADVENTURE3)			// on level 3 we'll keep the door spinning
		{
			if (door->Rot.z < -PI)
				door->Rot.z = -PI;
		}

		UpdateObjectTransforms(door);
	}

			/* UPDATE RING */

	ring->BaseTransformMatrix = door->BaseTransformMatrix;
	SetObjectTransformMatrix(ring);
	ring->ColorFilter.a = .7f + RandomFloat() * .3f;
	ring->TextureTransformU -= fps * 3.0f;
}


#pragma mark -



/************************* ADD FOREST DOOR KEY *********************************/

Boolean AddForestDoorKey(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode				*keyHolder, *key;
short				keyID = itemPtr->parm[0];
short				i, j;
float				rot = (float)itemPtr->parm[1] * (PI2/8);
Boolean				keyDestroyed = itemPtr->flags & ITEM_FLAGS_USER1;

					/*******************/
					/* MAKE KEY HOLDER */
					/*******************/

	gNewObjectDefinition.group 		= MODEL_GROUP_GLOBAL;
	gNewObjectDefinition.type 		= GLOBAL_ObjType_ForestDoor_KeyHolder;
	gNewObjectDefinition.scale 		= DAMDOOR_SCALE;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= itemPtr->terrainY;
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits;
	gNewObjectDefinition.slot 		= 209;
	gNewObjectDefinition.moveCall 	= MoveForestDoorKey;
	gNewObjectDefinition.rot 		= rot;
	keyHolder = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	keyHolder->TerrainItemPtr = itemPtr;								// keep ptr to item list

	keyHolder->Kind = keyID;


			/* SET COLLISION STUFF */

	keyHolder->CType 			= CTYPE_MISC | CTYPE_WEAPONTEST | CTYPE_PLAYERTEST;
	keyHolder->CBits			= CBITS_ALLSOLID;
	CreateCollisionBoxFromBoundingBox(keyHolder, 1, 1);

	keyHolder->TriggerCallback 		= DoTrig_ForestDoorKey;
	keyHolder->HitByWeaponHandler 	= ForestDoorKeyHitByWeaponCallback;

	keyHolder->HeatSeekHotSpotOff.y 	= 220.0f;

	keyHolder->Health = .3f;


					/************/
					/* MAKE KEY */
					/************/

	if (!keyDestroyed)								// was the key already destroyed?
	{
		keyHolder->CType |= CTYPE_AUTOTARGETWEAPON;					// make keyholder auto-target

		gNewObjectDefinition.type 		= GLOBAL_ObjType_ForestDoor_Key;
		gNewObjectDefinition.slot++;
		gNewObjectDefinition.moveCall 	= nil;
		key = MakeNewDisplayGroupObject(&gNewObjectDefinition);


				/* SET COLLISION STUFF */

		key->CType 			= CTYPE_WEAPONTEST | CTYPE_AUTOTARGETWEAPON;

		key->HitByWeaponHandler 	= ForestDoorKeyHitByWeaponCallback;

		key->HeatSeekHotSpotOff.y 	= 220.0f;

		keyHolder->ChainNode = key;
		key->ChainHead = keyHolder;


					/* MAKE SPARKLES */

		rot = 0;
		for (j = 0; j < 3; j++)
		{
			key->Sparkles[j] = i = GetFreeSparkle(key);
			if (i != -1)
			{
				gSparkles[i].flags = SPARKLE_FLAG_OMNIDIRECTIONAL | SPARKLE_FLAG_FLICKER | SPARKLE_FLAG_TRANSFORMWITHOWNER;
				gSparkles[i].where.x = sin(rot) * 20.0f;
				gSparkles[i].where.y = 190.0f;
				gSparkles[i].where.z = cos(rot) * 20.0f;

				gSparkles[i].color.r = 1;
				gSparkles[i].color.g = 1;
				gSparkles[i].color.b = 1;
				gSparkles[i].color.a = 1;

				gSparkles[i].scale 	= 60.0f;
				gSparkles[i].separation = 50;

				gSparkles[i].textureNum = PARTICLE_SObjType_RedGlint;

				rot += PI2 * .333f;
			}
		}
	}


	return(true);													// item was added
}


/********************* MOVE FOREST DOOR KEY **********************/

static void MoveForestDoorKey(ObjNode *keyHolder)
{
ObjNode	*key = keyHolder->ChainNode;

	if (TrackTerrainItem(keyHolder))							// just check to see if it's gone
	{
		DeleteObject(keyHolder);
		return;
	}


			/* SPIN THE KEY */

	if (key)
	{
		key->Rot.y += gFramesPerSecondFrac * 2.0f;
		UpdateObjectTransforms(key);
	}
}



/******************** TRIGGER CALLBACK:  FOREST DOOR GENERATOR ************************/
//
// Returns TRUE if want to handle hit as a solid
//

static Boolean DoTrig_ForestDoorKey(ObjNode *theNode, ObjNode *player)
{
	DestroyForestDoorKey(theNode);

	PlayerSmackedIntoObject(player, theNode, PLAYER_DEATH_TYPE_EXPLODE);

	return(true);
}


/*************************** FOREST DOOR GENERATOR HIT BY WEAPON CALLBACK *****************************/
//
// Returns true if object should stop bullet.
//

static Boolean ForestDoorKeyHitByWeaponCallback(ObjNode *bullet, ObjNode *theNode, OGLPoint3D *hitCoord, OGLVector3D *hitTriangleNormal)
{
#pragma unused (hitCoord, hitTriangleNormal)


	if (theNode->ChainHead)									// make sure we're pointing to the key holder, not the key
		theNode = theNode->ChainHead;

	theNode->Health -= bullet->Damage;
	if (theNode->Health <= 0.0f)
	{
		DestroyForestDoorKey(theNode);

	}

	return(true);
}



/****************** DESTROY FOREST DOOR KEY **********************/

static void	DestroyForestDoorKey(ObjNode *keyHolder)
{
ObjNode	 *key = keyHolder->ChainNode;
OGLPoint3D	pt;
long		pg, i;
float		x,y,z,f;
NewParticleDefType		newParticleDef;
OGLVector3D	v, delta;

	if (key == nil)								// make sure there's a key in there
		return;

	gForestDoorOpen[keyHolder->Kind] = true;

	PlayEffect3D(EFFECT_TURRETEXPLOSION, &keyHolder->Coord);

			/* MAKE SURE KEY DOESNT COME BACK */

	keyHolder->TerrainItemPtr->flags |= ITEM_FLAGS_USER1;
	keyHolder->CType &= ~CTYPE_AUTOTARGETWEAPON;				// don't auto-target anymore


			/************************/
			/* MAKE SPARK EXPLOSION */
			/************************/

	x = key->Coord.x;
	z = key->Coord.z;
	y = key->Coord.y + (250.0f * DAMDOOR_SCALE);

	gNewParticleGroupDef.magicNum				= 0;
	gNewParticleGroupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
	gNewParticleGroupDef.flags					= PARTICLE_FLAGS_BOUNCE;
	gNewParticleGroupDef.gravity				= 300;
	gNewParticleGroupDef.magnetism				= 0;
	gNewParticleGroupDef.baseScale				= 20.0f;
	gNewParticleGroupDef.decayRate				=  0;
	gNewParticleGroupDef.fadeRate				= .5;
	gNewParticleGroupDef.particleTextureNum		= PARTICLE_SObjType_RedSpark;
	gNewParticleGroupDef.srcBlend				= GL_SRC_ALPHA;
	gNewParticleGroupDef.dstBlend				= GL_ONE;

	pg = NewParticleGroup(&gNewParticleGroupDef);
	if (pg != -1)
	{
		for (i = 0; i < 200; i++)
		{
			pt.x = x + RandomFloat2() * 50.0f;
			pt.y = y + RandomFloat2() * 30.0f;
			pt.z = z + RandomFloat2() * 50.0f;

			v.x = pt.x - x;
			v.y = pt.y - y;
			v.z = pt.z - z;
			FastNormalizeVector(v.x, v.y, v.z, &v);

			f = 200.0f + RandomFloat() * 300.0f;

			delta.x = v.x * f;
			delta.y = v.y * f;
			delta.z = v.z * f;


			newParticleDef.groupNum		= pg;
			newParticleDef.where		= &pt;
			newParticleDef.delta		= &delta;
			newParticleDef.scale		= 1.0f + RandomFloat()  * .5f;
			newParticleDef.rotZ			= 0;
			newParticleDef.rotDZ		= 0;
			newParticleDef.alpha		= .8f + RandomFloat() * .2f;
			if (AddParticleToGroup(&newParticleDef))
				break;
		}
	}


	DeleteObject(key);

	keyHolder->ChainNode = nil;
}































