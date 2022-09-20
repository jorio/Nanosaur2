/****************************/
/*   		BUSHES.C	    */
/* (c)2004 Pangea Software  */
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
extern	short				gNumEnemies;
extern	SpriteType	*gSpriteGroupList[];
extern	AGLContext		gAGLContext;
extern	Byte				gCurrentSplitScreenPane;


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
ObjNode	*newObj;

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;

	switch(gLevelNum)
	{
		case	LEVEL_NUM_ADVENTURE1:
		case	LEVEL_NUM_FLAG2:
		case	LEVEL_NUM_BATTLE1:
				gNewObjectDefinition.type 		= LEVEL1_ObjType_Grass + itemPtr->parm[0];
				break;

		case	LEVEL_NUM_ADVENTURE2:
		case	LEVEL_NUM_RACE2:
		case	LEVEL_NUM_BATTLE2:
				gNewObjectDefinition.type 		= LEVEL2_ObjType_Grass + itemPtr->parm[0];
				break;

		case	LEVEL_NUM_ADVENTURE3:
		case	LEVEL_NUM_RACE1:
		case	LEVEL_NUM_FLAG1:
				gNewObjectDefinition.type 		= LEVEL3_ObjType_Grass_Single + itemPtr->parm[0];
				break;

		default:
			return(false);
	}

	gNewObjectDefinition.scale 		= 2.0 + RandomFloat2() * .3f;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= GetMinTerrainY(x,z, gNewObjectDefinition.group, gNewObjectDefinition.type, 1.0);
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6;
	gNewObjectDefinition.slot 		= 876;
	gNewObjectDefinition.moveCall 	= MoveStaticObject;
	gNewObjectDefinition.rot 		= RandomFloat()*PI2;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

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
ObjNode	*newObj;

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= LEVEL1_ObjType_LowFern + itemPtr->parm[0];
	gNewObjectDefinition.scale 		= 1.4 + RandomFloat2() * .3f;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= itemPtr->terrainY;
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6;
	gNewObjectDefinition.slot 		= 264;
	gNewObjectDefinition.moveCall 	= MoveStaticObject;
	gNewObjectDefinition.rot 		= RandomFloat()*PI2;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

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
ObjNode	*newObj;

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= LEVEL1_ObjType_LowBerryBush + itemPtr->parm[0];
	gNewObjectDefinition.scale 		= 2.0 + RandomFloat2() * .3f;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= itemPtr->terrainY; //GetMinTerrainY(x,z, gNewObjectDefinition.group, gNewObjectDefinition.type, 1.0);
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6;
	gNewObjectDefinition.slot 		= 491;
	gNewObjectDefinition.moveCall 	= MoveStaticObject;
	gNewObjectDefinition.rot 		= RandomFloat()*PI2;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

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
ObjNode	*newObj;

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= LEVEL1_ObjType_SmallCattail + itemPtr->parm[0];
	gNewObjectDefinition.scale 		= 1.4 + RandomFloat2() * .3f;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= itemPtr->terrainY; //GetMinTerrainY(x,z, gNewObjectDefinition.group, gNewObjectDefinition.type, 1.0);
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6;
	gNewObjectDefinition.slot 		= 821;
	gNewObjectDefinition.moveCall 	= MoveStaticObject;
	if (itemPtr->parm[3] & 1)										// random rot?
		gNewObjectDefinition.rot 		= RandomFloat()*PI2;
	else
		gNewObjectDefinition.rot 		= (float)itemPtr->parm[1] * (PI2/8.0f);

	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

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
ObjNode	*newObj;

	if (itemPtr->parm[0] > 3)
		DoFatalAlert("AddDesertBush: illegal subtype");

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= LEVEL2_ObjType_Bush1 + itemPtr->parm[0];
	if (itemPtr->parm[3] & 1)							// bit 0 is the half-size flag
		gNewObjectDefinition.scale 		= 1.0f + RandomFloat2() * .15f;
	else
		gNewObjectDefinition.scale 		= 2.0f + RandomFloat2() * .3f;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= itemPtr->terrainY; //GetMinTerrainY(x,z, gNewObjectDefinition.group, gNewObjectDefinition.type, 1.0);
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6;
	gNewObjectDefinition.slot 		= 491;
	gNewObjectDefinition.moveCall 	= MoveStaticObject;
	gNewObjectDefinition.rot 		= RandomFloat()*PI2;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

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

	return(false);
}

#pragma mark -


/************************* ADD CACTUS *********************************/

Boolean AddCactus(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*newObj;

	if (itemPtr->parm[0] > 2)
		DoFatalAlert("AddCactus: illegal subtype");

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= LEVEL2_ObjType_Cactus_Low + itemPtr->parm[0];
	gNewObjectDefinition.scale 		= 2.0 + RandomFloat2() * .3f;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= itemPtr->terrainY; //GetMinTerrainY(x,z, gNewObjectDefinition.group, gNewObjectDefinition.type, 1.0);
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6;
	gNewObjectDefinition.slot 		= 491;
	gNewObjectDefinition.moveCall 	= MoveStaticObject;
	gNewObjectDefinition.rot 		= RandomFloat()*PI2;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

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
ObjNode	*newObj;

	if (itemPtr->parm[0] > 2)
		DoFatalAlert("AddPalmBush: illegal subtype");

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= LEVEL2_ObjType_PalmBush1 + itemPtr->parm[0];
	gNewObjectDefinition.scale 		= 2.0f + RandomFloat2() * .3f;
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
ObjNode	*newObj;

	if (itemPtr->parm[0] > 2)
		DoFatalAlert("AddGeckoPlant: illegal subtype");

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= LEVEL3_ObjType_GeckoPlant_Small + itemPtr->parm[0];
	gNewObjectDefinition.scale 		= 2.0f + RandomFloat2() * 1.0f;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= itemPtr->terrainY;
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6;
	gNewObjectDefinition.slot 		= 60;
	gNewObjectDefinition.moveCall 	= MoveStaticObject;
	gNewObjectDefinition.rot 		= RandomFloat()*PI2;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

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
ObjNode	*newObj;

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= LEVEL3_ObjType_SproutPlant;
	gNewObjectDefinition.scale 		= 2.5f + RandomFloat2() * .3f;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= itemPtr->terrainY;
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6;
	gNewObjectDefinition.slot 		= 40;
	gNewObjectDefinition.moveCall 	= MoveStaticObject;
	gNewObjectDefinition.rot 		= RandomFloat()*PI2;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

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
ObjNode	*newObj;
short   type = itemPtr->parm[0];
short   color = itemPtr->parm[1];


	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;

	if (color == 0)
		gNewObjectDefinition.type 		= LEVEL3_ObjType_PurpleIvy_Small + type;
	else
		gNewObjectDefinition.type 		= LEVEL3_ObjType_RedIvy_Small + type;

	gNewObjectDefinition.scale 		= 2.0f + RandomFloat2() * .3f;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= itemPtr->terrainY;
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6;
	gNewObjectDefinition.slot 		= 30;
	gNewObjectDefinition.moveCall 	= MoveStaticObject;
	gNewObjectDefinition.rot 		= RandomFloat()*PI2;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

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











