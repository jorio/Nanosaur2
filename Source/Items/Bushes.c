/****************************/
/*   		BUSHES.C	    */
/* (c)2004 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/


#include "game.h"


/****************************/
/*    PROTOTYPES            */
/****************************/

static Boolean DoTrig_Grass(ObjNode *grass, ObjNode *player);
static Boolean DoTrig_DesertBush(ObjNode *tree, ObjNode *player);



/****************************/
/*    CONSTANTS             */
/****************************/



/*********************/
/*    VARIABLES      */
/*********************/



/************************* ADD GRASS *********************************/

Boolean AddGrass(TerrainItemEntryType *itemPtr, float  x, float z)
{
	NewObjectDefinitionType def =
	{
		.group 		= MODEL_GROUP_LEVELSPECIFIC,
		.scale 		= 2.0 + RandomFloat2() * .3f,
		.coord.x 	= x,
		.coord.z 	= z,
		.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6,
		.slot 		= 876,
		.moveCall 	= MoveStaticObject,
		.rot 		= RandomFloat()*PI2,
	};


	def.coord.y 	= GetMinTerrainY(x,z, def.group, def.type, 1.0);


	switch(gLevelNum)
	{
		case	LEVEL_NUM_ADVENTURE1:
		case	LEVEL_NUM_FLAG2:
		case	LEVEL_NUM_BATTLE1:
				def.type 		= LEVEL1_ObjType_Grass + itemPtr->parm[0];
				break;

		case	LEVEL_NUM_ADVENTURE2:
		case	LEVEL_NUM_RACE2:
		case	LEVEL_NUM_BATTLE2:
				def.type 		= LEVEL2_ObjType_Grass + itemPtr->parm[0];
				break;

		case	LEVEL_NUM_ADVENTURE3:
		case	LEVEL_NUM_RACE1:
		case	LEVEL_NUM_FLAG1:
				def.type 		= LEVEL3_ObjType_Grass_Single + itemPtr->parm[0];
				break;

		default:
			return(false);
	}

	ObjNode* newObj = MakeNewDisplayGroupObject(&def);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list


			/* SET COLLISION STUFF */

	newObj->CType 			= CTYPE_TRIGGER;
	newObj->CBits			= 0;
	CreateCollisionBoxFromBoundingBox_Rotated(newObj, .7, .3);

	newObj->TriggerCallback = DoTrig_Grass;

	return(true);													// item was added
}


/******************** TRIGGER CALLBACK:  GRASS ************************/
//
// Returns TRUE if want to handle hit as a solid
//

static Boolean DoTrig_Grass(ObjNode *grass, ObjNode *player)
{
#pragma unused (grass)

	if (gPlayerInfo[player->PlayerNum].carriedObj == nil)		// only disorient if not carrying egg
	{
		DisorientPlayer(player);
	}

	return(false);
}


#pragma mark -



/************************* ADD FERN *********************************/

Boolean AddFern(TerrainItemEntryType *itemPtr, float  x, float z)
{
	NewObjectDefinitionType def =
	{
		.group 		= MODEL_GROUP_LEVELSPECIFIC,
		.type 		= LEVEL1_ObjType_LowFern + itemPtr->parm[0],
		.scale 		= 1.4 + RandomFloat2() * .3f,
		.coord.x 	= x,
		.coord.z 	= z,
		.coord.y 	= itemPtr->terrainY,
		.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6,
		.slot 		= 264,
		.moveCall 	= MoveStaticObject,
		.rot 		= RandomFloat()*PI2,
	};

	ObjNode* newObj = MakeNewDisplayGroupObject(&def);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list

			/* SET COLLISION STUFF */

//	newObj->CType 			= CTYPE_MISC | CTYPE_TRIGGER | CTYPE_WEAPONTEST;
//	newObj->CBits			= CBITS_ALLSOLID;
//	CreateCollisionBoxFromBoundingBox(newObj, .4, .5);
//	newObj->TriggerCallback = DoTrig_MiscSmackableObject;

	return(true);													// item was added
}


/************************* ADD BERRY BUSH *********************************/

Boolean AddBerryBush(TerrainItemEntryType *itemPtr, float  x, float z)
{
	NewObjectDefinitionType def =
	{
		.group 		= MODEL_GROUP_LEVELSPECIFIC,
		.type 		= LEVEL1_ObjType_LowBerryBush + itemPtr->parm[0],
		.scale 		= 2.0 + RandomFloat2() * .3f,
		.coord.x 	= x,
		.coord.z 	= z,
		.coord.y 	= itemPtr->terrainY, //GetMinTerrainY(x,z, gNewObjectDefinition.group, gNewObjectDefinition.type, 1.0),
		.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6,
		.slot 		= 491,
		.moveCall 	= MoveStaticObject,
		.rot 		= RandomFloat()*PI2,
	};

	ObjNode* newObj = MakeNewDisplayGroupObject(&def);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list



			/* SET COLLISION STUFF */

	newObj->CType 			= CTYPE_MISC | CTYPE_TRIGGER | CTYPE_WEAPONTEST;
	newObj->CBits			= CBITS_ALLSOLID;
	CreateCollisionBoxFromBoundingBox(newObj, .4, .3);

	newObj->TriggerCallback = DoTrig_MiscSmackableObject;

	return(true);													// item was added
}


/************************* ADD CATTAIL *********************************/

Boolean AddCatTail(TerrainItemEntryType *itemPtr, float  x, float z)
{
	Boolean randomRot = (itemPtr->parm[3] & 1);

	NewObjectDefinitionType def =
	{
		.group 		= MODEL_GROUP_LEVELSPECIFIC,
		.type 		= LEVEL1_ObjType_SmallCattail + itemPtr->parm[0],
		.scale 		= 1.4 + RandomFloat2() * .3f,
		.rot 		= (randomRot) ? (RandomFloat()*PI2) : ((float)itemPtr->parm[1] * (PI2/8.0f)),
		.coord.x 	= x,
		.coord.z 	= z,
		.coord.y 	= itemPtr->terrainY, //GetMinTerrainY(x,z, gNewObjectDefinition.group, gNewObjectDefinition.type, 1.0),
		.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6,
		.slot 		= 821,
		.moveCall 	= MoveStaticObject,
	};

	ObjNode* newObj = MakeNewDisplayGroupObject(&def);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list


			/* SET COLLISION STUFF */

//	newObj->CType 			= CTYPE_MISC | CTYPE_TRIGGER;
//	newObj->CBits			= CBITS_ALLSOLID;
//	CreateCollisionBoxFromBoundingBox_Rotated(newObj, .5, .2);
//	newObj->TriggerCallback = DoTrig_MiscSmackableObject;

	return(true);													// item was added
}


#pragma mark -

/************************* ADD DESERT BUSH *********************************/

Boolean AddDesertBush(TerrainItemEntryType *itemPtr, float  x, float z)
{
	if (itemPtr->parm[0] > 3)
		DoFatalAlert("AddDesertBush: illegal subtype");

	Boolean halfSizeFlag = (itemPtr->parm[3] & 1);							// bit 0 is the half-size flag

	NewObjectDefinitionType def =
	{
		.group 		= MODEL_GROUP_LEVELSPECIFIC,
		.type 		= LEVEL2_ObjType_Bush1 + itemPtr->parm[0],
		.scale 		= halfSizeFlag ? (1.0f + RandomFloat2() * .15f) : ( 2.0f + RandomFloat2() * .3f),
		.coord.x 	= x,
		.coord.z 	= z,
		.coord.y 	= itemPtr->terrainY, //GetMinTerrainY(x,z, gNewObjectDefinition.group, gNewObjectDefinition.type, 1.0),
		.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6,
		.slot 		= 491,
		.moveCall 	= MoveStaticObject,
		.rot 		= RandomFloat()*PI2,
	};

	ObjNode* newObj = MakeNewDisplayGroupObject(&def);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list



			/* SET COLLISION STUFF */

	newObj->Damage = .25f;

	newObj->CType 			= CTYPE_MISC | CTYPE_TRIGGER | CTYPE_WEAPONTEST;
	newObj->CBits			= CBITS_ALLSOLID;
	CreateCollisionBoxFromBoundingBox_Rotated(newObj, .4, .6);

	newObj->TriggerCallback = DoTrig_DesertBush;

	return(true);													// item was added
}

/******************** TRIGGER CALLBACK:  DESERT BUSH ************************/
//
// Returns TRUE if want to handle hit as a solid
//

static Boolean DoTrig_DesertBush(ObjNode *tree, ObjNode *player)
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
	PlayRumbleEffect(EFFECT_BODYHIT, p);

	return(false);
}

#pragma mark -


/************************* ADD CACTUS *********************************/

Boolean AddCactus(TerrainItemEntryType *itemPtr, float  x, float z)
{
	if (itemPtr->parm[0] > 2)
		DoFatalAlert("AddCactus: illegal subtype");

	NewObjectDefinitionType def =
	{
		.group 		= MODEL_GROUP_LEVELSPECIFIC,
		.type 		= LEVEL2_ObjType_Cactus_Low + itemPtr->parm[0],
		.scale 		= 2.0 + RandomFloat2() * .3f,
		.coord.x 	= x,
		.coord.z 	= z,
		.coord.y 	= itemPtr->terrainY, //GetMinTerrainY(x,z, gNewObjectDefinition.group, gNewObjectDefinition.type, 1.0),
		.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6,
		.slot 		= 491,
		.moveCall 	= MoveStaticObject,
		.rot 		= RandomFloat()*PI2,
	};

	ObjNode* newObj = MakeNewDisplayGroupObject(&def);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list

	RotateOnTerrain(newObj, -2, nil);							// keep flat on terrain
	SetObjectTransformMatrix(newObj);



			/* SET COLLISION STUFF */

	newObj->CType 			= CTYPE_MISC | CTYPE_TRIGGER | CTYPE_WEAPONTEST;
	newObj->CBits			= CBITS_ALLSOLID;
	CreateCollisionBoxFromBoundingBox_Rotated(newObj, .8, .8);

	newObj->Damage = .8f;

	newObj->TriggerCallback = DoTrig_MiscSmackableObject;

	return(true);													// item was added
}



/************************* ADD PALM BUSH *********************************/

Boolean AddPalmBush(TerrainItemEntryType *itemPtr, float  x, float z)
{
	if (itemPtr->parm[0] > 2)
		DoFatalAlert("AddPalmBush: illegal subtype");

	NewObjectDefinitionType def =
	{
		.group 		= MODEL_GROUP_LEVELSPECIFIC,
		.type 		= LEVEL2_ObjType_PalmBush1 + itemPtr->parm[0],
		.scale 		= 2.0f + RandomFloat2() * .3f,
		.coord.x 	= x,
		.coord.z 	= z,
		.coord.y 	= itemPtr->terrainY,
		.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6,
		.slot 		= 491,
		.moveCall 	= MoveStaticObject,
		.rot 		= RandomFloat()*PI2,
	};

	ObjNode* newObj = MakeNewDisplayGroupObject(&def);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list



			/* SET COLLISION STUFF */

	newObj->CType 			= CTYPE_MISC | CTYPE_TRIGGER | CTYPE_WEAPONTEST;
	newObj->CBits			= CBITS_ALLSOLID;
	CreateCollisionBoxFromBoundingBox_Rotated(newObj, .5, .6);

	newObj->Damage = .5f;
	newObj->TriggerCallback = DoTrig_DesertBush;

	return(true);													// item was added
}


#pragma mark -

/************************* ADD GECKO PLANT *********************************/

Boolean AddGeckoPlant(TerrainItemEntryType *itemPtr, float  x, float z)
{
	if (itemPtr->parm[0] > 2)
		DoFatalAlert("AddGeckoPlant: illegal subtype");

	NewObjectDefinitionType def =
	{
		.group 		= MODEL_GROUP_LEVELSPECIFIC,
		.type 		= LEVEL3_ObjType_GeckoPlant_Small + itemPtr->parm[0],
		.scale 		= 2.0f + RandomFloat2() * 1.0f,
		.coord.x 	= x,
		.coord.z 	= z,
		.coord.y 	= itemPtr->terrainY,
		.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6,
		.slot 		= 60,
		.moveCall 	= MoveStaticObject,
		.rot 		= RandomFloat()*PI2,
	};

	ObjNode* newObj = MakeNewDisplayGroupObject(&def);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list

	RotateOnTerrain(newObj, -2, nil);							// keep flat on terrain
	SetObjectTransformMatrix(newObj);



			/* SET COLLISION STUFF */

	newObj->CType 			= CTYPE_MISC | CTYPE_TRIGGER | CTYPE_WEAPONTEST;
	newObj->CBits			= CBITS_ALLSOLID;
	CreateCollisionBoxFromBoundingBox_Rotated(newObj, .5, .5);

	newObj->Damage = .6f;

	newObj->TriggerCallback = DoTrig_DesertBush;

	return(true);													// item was added
}


/************************* ADD SPROUT PLANT *********************************/

Boolean AddSproutPlant(TerrainItemEntryType *itemPtr, float  x, float z)
{
	NewObjectDefinitionType def =
	{
		.group 		= MODEL_GROUP_LEVELSPECIFIC,
		.type 		= LEVEL3_ObjType_SproutPlant,
		.scale 		= 2.5f + RandomFloat2() * .3f,
		.coord.x 	= x,
		.coord.z 	= z,
		.coord.y 	= itemPtr->terrainY,
		.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6,
		.slot 		= 40,
		.moveCall 	= MoveStaticObject,
		.rot 		= RandomFloat()*PI2,
	};
	ObjNode* newObj = MakeNewDisplayGroupObject(&def);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list

//	RotateOnTerrain(newObj, -2, nil);							// keep flat on terrain
//	SetObjectTransformMatrix(newObj);


			/* SET COLLISION STUFF */

//	newObj->CType 			= CTYPE_MISC | CTYPE_TRIGGER | CTYPE_WEAPONTEST;
//	newObj->CBits			= CBITS_ALLSOLID;
//	CreateCollisionBoxFromBoundingBox_Rotated(newObj, .5, .5);

//	newObj->TriggerCallback = DoTrig_MiscSmackableObject;

	return(true);													// item was added
}




/************************* ADD IVY *********************************/

Boolean AddIvy(TerrainItemEntryType *itemPtr, float  x, float z)
{
short   type = itemPtr->parm[0];
short   color = itemPtr->parm[1];

	NewObjectDefinitionType def =
	{
		.group 		= MODEL_GROUP_LEVELSPECIFIC,
		.type 		= (color == 0) ? (LEVEL3_ObjType_PurpleIvy_Small + type) : (LEVEL3_ObjType_RedIvy_Small + type),
		.scale 		= 2.0f + RandomFloat2() * .3f,
		.coord.x 	= x,
		.coord.z 	= z,
		.coord.y 	= itemPtr->terrainY,
		.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6,
		.slot 		= 30,
		.moveCall 	= MoveStaticObject,
		.rot 		= RandomFloat()*PI2,
	};

	ObjNode* newObj = MakeNewDisplayGroupObject(&def);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list

//	RotateOnTerrain(newObj, -2, nil);							// keep flat on terrain
//	SetObjectTransformMatrix(newObj);


			/* SET COLLISION STUFF */

//	newObj->CType 			= CTYPE_TRIGGER;
//	newObj->CBits			= 0;
//	CreateCollisionBoxFromBoundingBox(newObj, .8, .7);
//
//	newObj->TriggerCallback = DoTrig_Ivy;

	return(true);													// item was added
}











