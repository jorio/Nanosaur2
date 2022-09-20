/****************************/
/*   		TREES.C		    */
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

static Boolean DoTrig_Tree(ObjNode *trigger, ObjNode *theNode);
static Boolean DoTrig_SmallTree(ObjNode *tree, ObjNode *player);
static Boolean DoTrig_FallenSwampTree(ObjNode *tree, ObjNode *player);
static Boolean DoTrig_Canopy(ObjNode *grass, ObjNode *player);

static Boolean TreeHitByWeaponCallback(ObjNode *bullet, ObjNode *tree, OGLPoint3D *hitCoord, OGLVector3D *hitTriangleNormal);
static void MoveTree_Burning(ObjNode *theNode);
static void MakeLeafConfetti(float x, float y, float z, short texture, short quantity);


/****************************/
/*    CONSTANTS             */
/****************************/

#define	TREE_BURN_TIME	15.0f

/*********************/
/*    VARIABLES      */
/*********************/

#define	TreeBurnY		SpecialF[0]				// y-coord for flames to come from
#define	TreeIsBurnt		Flag[0]


/************************* ADD BIRCH TREE *********************************/

Boolean AddBirchTree(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*newObj;

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= LEVEL1_ObjType_Tree_Birch_HighRed + itemPtr->parm[0];
	gNewObjectDefinition.scale 		= 1.2 + RandomFloat() * .3f;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= itemPtr->terrainY; //GetTerrainY(x,z);
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6;
	gNewObjectDefinition.slot 		= 501;
	gNewObjectDefinition.moveCall 	= MoveStaticObject;
	gNewObjectDefinition.rot 		= RandomFloat()*PI2;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list

			/* SET COLLISION STUFF */

	newObj->CType 			= CTYPE_MISC | CTYPE_TRIGGER | CTYPE_WEAPONTEST;
	newObj->CBits			= CBITS_ALLSOLID;

	CreateCollisionBoxFromBoundingBox(newObj, .1, 1);								// tree trunk collision box

	AddCollisionBoxToObject(newObj, newObj->TopOff * .9f, newObj->TopOff * .45f,		// tree canopy collision box
							newObj->LeftOff * 3.3f, newObj->RightOff * 3.3f,
							newObj->FrontOff * 3.3f, newObj->BackOff * 3.3f);


	newObj->TriggerCallback = DoTrig_Tree;

	newObj->HitByWeaponHandler = TreeHitByWeaponCallback;


	return(true);													// item was added
}


/************************* ADD PINE TREE *********************************/

Boolean AddPineTree(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*newObj;

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= LEVEL1_ObjType_Tree_Pine_HighDead + itemPtr->parm[0];
	gNewObjectDefinition.scale 		= 1.2 + RandomFloat() * .3f;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= itemPtr->terrainY;	//GetTerrainY(x,z);
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6;
	gNewObjectDefinition.slot 		= 588;
	gNewObjectDefinition.moveCall 	= MoveStaticObject;
	gNewObjectDefinition.rot 		= RandomFloat()*PI2;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list

			/* SET COLLISION STUFF */

	newObj->CType 			= CTYPE_MISC | CTYPE_TRIGGER | CTYPE_WEAPONTEST;
	newObj->CBits			= CBITS_ALLSOLID;

	CreateCollisionBoxFromBoundingBox_Rotated(newObj, .12, .95);						// tree trunk collision box

	AddCollisionBoxToObject(newObj, newObj->TopOff * .4f, newObj->TopOff * .15f,		// tree canopy collision box
							newObj->LeftOff * 2.3f, newObj->RightOff * 2.3f,
							newObj->FrontOff * 2.3f, newObj->BackOff * 2.3f);

	newObj->TriggerCallback = DoTrig_Tree;

	newObj->HitByWeaponHandler = TreeHitByWeaponCallback;


	return(true);													// item was added
}



/************************* ADD FALLEN TREE *********************************/

Boolean AddFallenTree(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*newObj;

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= LEVEL1_ObjType_FallenTree;
	gNewObjectDefinition.scale 		= 1.7;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= GetMinTerrainY(x,z, gNewObjectDefinition.group, gNewObjectDefinition.type, 1.0);
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6;
	gNewObjectDefinition.slot 		= 511;
	gNewObjectDefinition.moveCall 	= MoveStaticObject;
	gNewObjectDefinition.rot 		= (float)itemPtr->parm[0] * (PI2/8);
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list

			/* SET COLLISION STUFF */

	newObj->CType 			= CTYPE_MISC | CTYPE_TRIGGER;
	newObj->CBits			= CBITS_ALLSOLID;
	CreateCollisionBoxFromBoundingBox_Rotated(newObj, .3, .4);

	newObj->TriggerCallback = DoTrig_Tree;


	return(true);													// item was added
}


/************************* ADD TREE STUMP *********************************/

Boolean AddTreeStump(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*newObj;

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= LEVEL1_ObjType_TreeStump;
	gNewObjectDefinition.scale 		= 1.3;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= itemPtr->terrainY;
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6;
	gNewObjectDefinition.slot 		= 491;
	gNewObjectDefinition.moveCall 	= MoveStaticObject;
	gNewObjectDefinition.rot 		= RandomFloat()*PI2;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list

			/* SET COLLISION STUFF */

	newObj->CType 			= CTYPE_MISC | CTYPE_TRIGGER;
	newObj->CBits			= CBITS_ALLSOLID;
	CreateCollisionBoxFromBoundingBox_Rotated(newObj, .3, 1);

	newObj->TriggerCallback = DoTrig_Tree;


	return(true);													// item was added
}


/******************** TRIGGER CALLBACK:  TREE ************************/
//
// Returns TRUE if want to handle hit as a solid
//

static Boolean DoTrig_Tree(ObjNode *trigger, ObjNode *theNode)
{
	if (PlayerSmackedIntoObject(theNode, trigger, PLAYER_DEATH_TYPE_EXPLODE))
		return(false);

	return(true);
}


/******************** TRIGGER CALLBACK:  CANOPY ************************/
//
// Canopies don't cause any damage, just disorentation
//
// Returns TRUE if want to handle hit as a solid
//

static Boolean DoTrig_Canopy(ObjNode *grass, ObjNode *player)
{
#pragma unused (grass)

	if (!gGamePrefs.kiddieMode)							// don't hurt in kiddie mode
	{
		short   p = player->PlayerNum;

		if (gPlayerInfo[p].carriedObj == nil)		// only if not carrying egg
		{
			if (gPlayerInfo[p].invincibilityTimer > 0.0f)
				return(false);

			PlayerLoseHealth(p, .2, PLAYER_DEATH_TYPE_DEATHDIVE, &player->Coord, true);
			PlayEffect3D(EFFECT_BODYHIT, &player->Coord);
			gPlayerInfo[p].invincibilityTimer = .6;
		}
	}
	return(false);
}


#pragma mark -

/************************* ADD SMALL TREE *********************************/
//
// Small trees can be hit w/o killing the player.
//

Boolean AddSmallTree(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*newObj;

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= LEVEL1_ObjType_SmallTree;
	gNewObjectDefinition.scale 		= 1.0 + RandomFloat() * .2f;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= itemPtr->terrainY;
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6;
	gNewObjectDefinition.slot 		= 620;
	gNewObjectDefinition.moveCall 	= MoveStaticObject;
	gNewObjectDefinition.rot 		= RandomFloat()*PI2;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list

			/* SET COLLISION STUFF */

	newObj->CType 			= CTYPE_MISC | CTYPE_TRIGGER | CTYPE_WEAPONTEST;
	newObj->CBits			= CBITS_ALLSOLID;
	CreateCollisionBoxFromBoundingBox_Rotated(newObj, .3, 1);

	newObj->TriggerCallback = DoTrig_SmallTree;


	return(true);													// item was added
}



/******************** TRIGGER CALLBACK:  SMALL TREE ************************/
//
// Returns TRUE if want to handle hit as a solid
//

static Boolean DoTrig_SmallTree(ObjNode *tree, ObjNode *player)
{
	DisorientPlayer(player);
	PlayEffect3D(EFFECT_BODYHIT, &player->Coord);

	ExplodeGeometry(tree, 200, SHARD_MODE_FROMORIGIN, 1, 1.0);
	DeleteObject(tree);


	return(false);
}


#pragma mark -

/*************************** TREE HIT BY WEAPON CALLBACK *****************************/
//
// Returns true if object should stop bullet.
//

static Boolean TreeHitByWeaponCallback(ObjNode *bullet, ObjNode *tree, OGLPoint3D *hitCoord, OGLVector3D *hitTriangleNormal)
{
#pragma unused (hitTriangleNormal)

	switch(bullet->Kind)
	{
			/* WEAPONS THAT WILL LIGHT TREE ON FIRE */

		case	WEAPON_TYPE_BLASTER:
		case	WEAPON_TYPE_CLUSTERSHOT:
		case	WEAPON_TYPE_BOMB:
		case	WEAPON_TYPE_HEATSEEKER:
				if ((!tree->TreeIsBurnt) && (hitCoord))					// note:  make sure hitCoord is not nil
				{
					if (MyRandomLong() & 0x1)							// randomly decide if this ignites the tree
					{
						tree->MoveCall 		= MoveTree_Burning;
						tree->ParticleTimer = 0;
						tree->TreeIsBurnt 	= true;
						tree->TreeBurnY		= hitCoord->y;
						tree->Timer			= TREE_BURN_TIME;						// burn for n seconds
					}
				}
				break;

				/* WEAPONS THAT FURR THE TREE */

		case	WEAPON_TYPE_SONICSCREAM:
				MakeLeafConfetti(tree->Coord.x, gCoord.y, tree->Coord.z, PARTICLE_SObjType_Confetti_Birch, 200);
				break;

	}

	return(true);
}


/*************************** MOVE TREE: BURNING ****************************/

static void MoveTree_Burning(ObjNode *theNode)
{
float	fps = gFramesPerSecondFrac;
float	c;
ObjNode *chain;

	if (TrackTerrainItem(theNode))							// just check to see if it's gone
	{
		DeleteObject(theNode);
		return;
	}


			/* SEE IF DONE BURNING */

	theNode->Timer -= fps;
	if (theNode->Timer <= 0.0f)
	{
		return;
	}



	GetObjectInfo(theNode);


		/* MOVE BURN LINE DOWN TO BOTTOM */

	theNode->TreeBurnY -= fps * 30.0f;
	if (theNode->TreeBurnY < (gCoord.y + 100.0f))
		theNode->TreeBurnY = gCoord.y + 100.0f;

		/*******************/
		/* BURN TREE COLOR */
		/*******************/

	c = theNode->ColorFilter.r;
	c -= .1f * fps;
	if (c < .3f)
		c = .3f;

	theNode->ColorFilter.r =
	theNode->ColorFilter.g =
	theNode->ColorFilter.b = c;

			/* APPLY BURN TO CHAINS */

	chain = theNode->ChainNode;
	while(chain)
	{
		chain->ColorFilter = theNode->ColorFilter;
		chain = chain->ChainNode;
	}



		/************************/
		/* UPDATE SPARKLE TRAIL */
		/************************/

	theNode->ParticleTimer -= fps;
	if (theNode->ParticleTimer <= 0.0f)
	{
		int						particleGroup,magicNum, i;
		NewParticleGroupDefType	groupDef;
		NewParticleDefType		newParticleDef;

		theNode->ParticleTimer += .04f;										// reset timer

		particleGroup 	= theNode->ParticleGroup;
		magicNum 		= theNode->ParticleMagicNum;

		if ((particleGroup == -1) || (!VerifyParticleGroupMagicNum(particleGroup, magicNum)))
		{
			theNode->ParticleMagicNum = magicNum = MyRandomLong();			// generate a random magic num

			groupDef.magicNum				= magicNum;
			groupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
			groupDef.flags					= PARTICLE_FLAGS_DONTCHECKGROUND;
			groupDef.gravity				= -200;
			groupDef.magnetism				= 0;
			groupDef.baseScale				= 40.0f;
			groupDef.decayRate				=  0;
			groupDef.fadeRate				= .6;
			groupDef.particleTextureNum		= PARTICLE_SObjType_Fire;
			groupDef.srcBlend				= GL_SRC_ALPHA;
			groupDef.dstBlend				= GL_ONE;
			theNode->ParticleGroup = particleGroup = NewParticleGroup(&groupDef);
		}

		if (particleGroup != -1)
		{
			OGLVector3D		d;
			OGLPoint3D		p;

			for (i = 0; i < 3; i++)
			{

				p.x = gCoord.x + RandomFloat2() * 25.0f;
				p.y = theNode->TreeBurnY + RandomFloat2() * 15.0f;
				p.z = gCoord.z + RandomFloat2() * 25.0f;

				d.x = 0;
				d.y = 400 + RandomFloat2() * 30.0f;
				d.z = 0;

				newParticleDef.groupNum		= particleGroup;
				newParticleDef.where		= &p;
				newParticleDef.delta		= &d;
				newParticleDef.scale		= RandomFloat() + 1.0f;
				newParticleDef.rotZ			= RandomFloat() * PI2;
				newParticleDef.rotDZ		= RandomFloat2();
				newParticleDef.alpha		= 1.0;
				if (AddParticleToGroup(&newParticleDef))
				{
					theNode->ParticleGroup = -1;
					break;
				}
			}
		}
	}

}




/********************* MAKE LEAF CONFETTI ***********************/

static void MakeLeafConfetti(float x, float y, float z, short texture, short quantity)
{
long					pg,i;
OGLVector3D				delta,v;
OGLPoint3D				pt;
NewConfettiDefType		newConfettiDef;

	gNewConfettiGroupDef.magicNum				= 0;
	gNewConfettiGroupDef.flags					= PARTICLE_FLAGS_BOUNCE;
	gNewConfettiGroupDef.gravity				= 250;
	gNewConfettiGroupDef.baseScale				= 20.0f;
	gNewConfettiGroupDef.decayRate				= 0;
	gNewConfettiGroupDef.fadeRate				= 1.0;
	gNewConfettiGroupDef.confettiTextureNum		= texture;

	pg = NewConfettiGroup(&gNewConfettiGroupDef);
	if (pg != -1)
	{
		for (i = 0; i < quantity; i++)
		{
			pt.x = x + RandomFloat2() * 60.0f;
			pt.y = y + RandomFloat2() * 300.0f;
			pt.z = z + RandomFloat2() * 60.0f;

			v.x = pt.x - x;
			v.y = pt.y - y;
			v.z = pt.z - z;
			FastNormalizeVector(v.x,v.y,v.z,&v);

			delta.x = v.x * 200.0f;
			delta.y = v.y * 200.0f;
			delta.z = v.z * 200.0f;

			newConfettiDef.groupNum		= pg;
			newConfettiDef.where		= &pt;
			newConfettiDef.delta		= &delta;
			newConfettiDef.scale		= 1.0f + RandomFloat()  * .5f;
			newConfettiDef.rot.x		= RandomFloat()*PI2;
			newConfettiDef.rot.y		= RandomFloat()*PI2;
			newConfettiDef.rot.z		= RandomFloat()*PI2;
			newConfettiDef.deltaRot.x	= RandomFloat2()*5.0f;
			newConfettiDef.deltaRot.y	= RandomFloat2()*5.0f;
			newConfettiDef.deltaRot.z	= RandomFloat2()*5.0f;
			newConfettiDef.alpha		= FULL_ALPHA;
			newConfettiDef.fadeDelay	= .5f + RandomFloat();
			if (AddConfettiToGroup(&newConfettiDef))
				break;
		}
	}
}


#pragma mark -

/************************* ADD BENT PINE TREE *********************************/

Boolean AddBentPineTree(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*trunk, *leaves;
float	rot = (float)itemPtr->parm[1] * (PI2/8.0);

					/**************/
					/* MAKE TRUNK */
					/**************/

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= LEVEL1_ObjType_BentPine1_Trunk + itemPtr->parm[0];
	gNewObjectDefinition.scale 		= 1.2 + RandomFloat2() * .2f;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= itemPtr->terrainY;
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits;
	gNewObjectDefinition.slot 		= 444;
	gNewObjectDefinition.moveCall 	= MoveStaticObject;
	gNewObjectDefinition.rot 		= rot;
	trunk = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	trunk->TerrainItemPtr = itemPtr;								// keep ptr to item list

			/* SET COLLISION STUFF */

	trunk->CType 			= CTYPE_SOLIDTOENEMY | CTYPE_PLAYERTEST | CTYPE_WEAPONTEST;
	trunk->CBits			= CBITS_ALLSOLID;
	CreateCollisionBoxFromBoundingBox_Rotated(trunk, 1, 1);



					/**************/
					/* MAKE LEAVES */
					/**************/

	gNewObjectDefinition.type 		= LEVEL1_ObjType_BentPine1_Leaves + itemPtr->parm[0];
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6;
	gNewObjectDefinition.slot 		= SLOT_OF_DUMB;
	gNewObjectDefinition.moveCall 	= nil;
	leaves = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	trunk->ChainNode = leaves;


	return(true);													// item was added
}


#pragma mark -


/************************* ADD DESERT TREE *********************************/

Boolean AddDesertTree(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*newObj, *canopy;
short	type = itemPtr->parm[0];
long	rot = itemPtr->parm[1];

	if (itemPtr->parm[0] > 4)
		DoFatalAlert("\pAddDesertTree: illegal subtype");

				/********************/
				/* MAKE SOLID TRUNK */
				/********************/

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= LEVEL2_ObjType_Tree1 + type;
	gNewObjectDefinition.scale 		= 1.2 + RandomFloat() * .3f;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= itemPtr->terrainY;
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6;
	gNewObjectDefinition.slot 		= 501;
	gNewObjectDefinition.moveCall 	= MoveStaticObject;
	if (rot == 0)
		gNewObjectDefinition.rot 	= RandomFloat()*PI2;
	else
		gNewObjectDefinition.rot 	= (float)(rot-1) * (PI2/8.0f);
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list

			/* SET COLLISION STUFF */

	newObj->CType 			= CTYPE_MISC | CTYPE_WEAPONTEST | CTYPE_PLAYERTEST;
	newObj->CBits			= CBITS_ALLSOLID;

	CreateCollisionBoxFromBoundingBox(newObj, .3, 1);								// tree trunk collision box

	if (type != 0)													// tree #0 is too bent to burn!
		newObj->HitByWeaponHandler = TreeHitByWeaponCallback;


				/*************************/
				/* MAKE NON-SOLID CANOPY */
				/*************************/

	gNewObjectDefinition.type 		= LEVEL2_ObjType_Tree1_Canopy + type;
	gNewObjectDefinition.slot++;
	gNewObjectDefinition.moveCall 	= nil;
	canopy = MakeNewDisplayGroupObject(&gNewObjectDefinition);

			/* SET COLLISION STUFF */

	canopy->CType 			= CTYPE_WEAPONTEST | CTYPE_PLAYERTEST;
	canopy->CBits			= 0;
	canopy->TriggerCallback = DoTrig_Canopy;


	newObj->ChainNode = canopy;


	return(true);													// item was added
}


/************************* ADD PALM TREE *********************************/

Boolean AddPalmTree(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*newObj, *canopy;
short	type = itemPtr->parm[0];
long	rot = itemPtr->parm[1];

				/********************/
				/* MAKE SOLID TRUNK */
				/********************/

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= LEVEL2_ObjType_PalmTree1 + type;
	gNewObjectDefinition.scale 		= 1.2 + RandomFloat() * .3f;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= itemPtr->terrainY;
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6;
	gNewObjectDefinition.slot 		= 501;
	gNewObjectDefinition.moveCall 	= MoveStaticObject;
	if (rot == 0)
		gNewObjectDefinition.rot 	= RandomFloat()*PI2;
	else
		gNewObjectDefinition.rot 	= (float)(rot-1) * (PI2/8.0f);
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list

			/* SET COLLISION STUFF */

	newObj->CType 			= CTYPE_SOLIDTOENEMY | CTYPE_WEAPONTEST | CTYPE_PLAYERTEST;
	newObj->CBits			= CBITS_ALLSOLID;

	CreateCollisionBoxFromBoundingBox(newObj, .3, 1);								// tree trunk collision box


	if (type != 2)															// don't allow the bent trees to burn
		newObj->HitByWeaponHandler = TreeHitByWeaponCallback;

				/*************************/
				/* MAKE NON-SOLID CANOPY */
				/*************************/

	gNewObjectDefinition.type 		= LEVEL2_ObjType_PalmTree1_Canopy + type;
	gNewObjectDefinition.slot++;
	gNewObjectDefinition.moveCall 	= nil;
	canopy = MakeNewDisplayGroupObject(&gNewObjectDefinition);

			/* SET COLLISION STUFF */

	canopy->CType 			= CTYPE_WEAPONTEST | CTYPE_PLAYERTEST;
	canopy->CBits			= 0;
	canopy->TriggerCallback = DoTrig_Canopy;


	newObj->ChainNode = canopy;


	return(true);													// item was added
}



/************************* ADD BURNT DESERT TREE *********************************/

Boolean AddBurntDesertTree(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*newObj;
short	type = itemPtr->parm[0];

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= LEVEL2_ObjType_BurntTree1 + type;
	gNewObjectDefinition.scale 		= 1.2f + RandomFloat() * .3f;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= itemPtr->terrainY;
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6;
	gNewObjectDefinition.slot 		= 501;
	gNewObjectDefinition.moveCall 	= MoveStaticObject;
	gNewObjectDefinition.rot 	= RandomFloat()*PI2;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list

			/* SET COLLISION STUFF */

	newObj->CType 			= CTYPE_MISC | CTYPE_WEAPONTEST | CTYPE_TRIGGER;
	newObj->CBits			= CBITS_ALLSOLID;

	CreateCollisionBoxFromBoundingBox(newObj, .3, .95);								// tree trunk collision box

	newObj->TriggerCallback = DoTrig_Tree;

	return(true);													// item was added
}

#pragma mark -

/************************* ADD HYDRA TREE *********************************/

Boolean AddHydraTree(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*newObj;
short	type = itemPtr->parm[0];

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= LEVEL3_ObjType_HydraTree_Small + type;
	gNewObjectDefinition.scale 		= 1.5f + RandomFloat() * .5f;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= itemPtr->terrainY;
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6;
	gNewObjectDefinition.slot 		= 501;
	gNewObjectDefinition.moveCall 	= MoveStaticObject;
	gNewObjectDefinition.rot 	= RandomFloat()*PI2;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list

			/* SET COLLISION STUFF */

	newObj->CType 			= CTYPE_MISC | CTYPE_WEAPONTEST | CTYPE_TRIGGER;
	newObj->CBits			= CBITS_ALLSOLID;

	newObj->TriggerCallback = DoTrig_Tree;

	CreateCollisionBoxFromBoundingBox(newObj, .1, .7);								// tree trunk collision box

	return(true);													// item was added
}


/************************* ADD ODD TREE *********************************/

Boolean AddOddTree(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*newObj;
short	type = itemPtr->parm[0];

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= LEVEL3_ObjType_OddTree_Small + type;
	gNewObjectDefinition.scale 		= 1.3f + RandomFloat() * .3f;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= itemPtr->terrainY;
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6;
	gNewObjectDefinition.slot 		= 501;
	gNewObjectDefinition.moveCall 	= MoveStaticObject;
	gNewObjectDefinition.rot 	= RandomFloat()*PI2;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list

			/* SET COLLISION STUFF */

	newObj->CType 			= CTYPE_MISC | CTYPE_WEAPONTEST | CTYPE_TRIGGER;
	newObj->CBits			= CBITS_ALLSOLID;

	newObj->Damage			= .9;
	newObj->TriggerCallback = DoTrig_FallenSwampTree;

	CreateCollisionBoxFromBoundingBox(newObj, .25, .9);								// tree trunk collision box

	return(true);													// item was added
}


/************************* ADD SWAMP FALLEN TREE *********************************/

Boolean AddSwampFallenTree(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*trunk;

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= LEVEL3_ObjType_FallenTree1 + itemPtr->parm[0];
	gNewObjectDefinition.scale 		= 1.2 + RandomFloat2() * .2f;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= itemPtr->terrainY;
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits;
	gNewObjectDefinition.slot 		= 444;
	gNewObjectDefinition.moveCall 	= MoveStaticObject;
	if (itemPtr->parm[1] > 0)
		gNewObjectDefinition.rot 		= (float)(itemPtr->parm[1]-1) * (PI2/8.0);
	else
		gNewObjectDefinition.rot 		= RandomFloat() * PI2;

	trunk = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	trunk->TerrainItemPtr = itemPtr;								// keep ptr to item list

			/* SET COLLISION STUFF */

	trunk->Damage = .25;

	trunk->CType 			= CTYPE_SOLIDTOENEMY | CTYPE_PLAYERTEST | CTYPE_WEAPONTEST;
	trunk->CBits			= CBITS_ALLSOLID;
	CreateCollisionBoxFromBoundingBox_Rotated(trunk, 1, 1);

	trunk->TriggerCallback = DoTrig_FallenSwampTree;

}


/******************** TRIGGER CALLBACK:  FALLEN SWAMP TREE ************************/
//
// Returns TRUE if want to handle hit as a solid
//

static Boolean DoTrig_FallenSwampTree(ObjNode *tree, ObjNode *player)
{
short   p = player->PlayerNum;

	if (gPlayerInfo[p].invincibilityTimer > 0.0f)
		return(false);

	if (!gGamePrefs.kiddieMode)							// don't hurt in kiddie mode
	{
		if (MyRandomLong() & 1)
			PlayerLoseHealth(p, tree->Damage, PLAYER_DEATH_TYPE_DEATHDIVE, nil, true);
		else
			PlayerLoseHealth(p, tree->Damage, PLAYER_DEATH_TYPE_EXPLODE, nil, true);
	}

	gPlayerInfo[p].invincibilityTimer = .5f;

	PlayEffect3D(EFFECT_BODYHIT, &player->Coord);

	return(false);
}


/************************* ADD SWAMP TREE STUMP *********************************/

Boolean AddSwampStump(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*newObj;

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= LEVEL3_ObjType_Stump1 + itemPtr->parm[0];
	gNewObjectDefinition.scale 		= 1.3;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= itemPtr->terrainY;
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits;
	gNewObjectDefinition.slot 		= 380;
	gNewObjectDefinition.moveCall 	= MoveStaticObject;
	gNewObjectDefinition.rot 		= RandomFloat()*PI2;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list

			/* SET COLLISION STUFF */

	newObj->CType 			= CTYPE_MISC | CTYPE_PLAYERTEST | CTYPE_WEAPONTEST;
	newObj->CBits			= CBITS_ALLSOLID;
	CreateCollisionBoxFromBoundingBox_Rotated(newObj, .8, .9);

	newObj->TriggerCallback = DoTrig_Tree;


	return(true);													// item was added
}

