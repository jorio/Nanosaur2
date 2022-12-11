/****************************/
/*   		POWS.C		    */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/


#include "game.h"


/****************************/
/*    PROTOTYPES            */
/****************************/

static void MovePOW(ObjNode *pow);
static Boolean DoTrig_WeaponPOW(ObjNode *trigger, ObjNode *theNode);
static Boolean DoTrig_HealthPOW(ObjNode *trigger, ObjNode *theNode);
static Boolean DoTrig_FuelPOW(ObjNode *trigger, ObjNode *theNode);
static Boolean DoTrig_ShieldPOW(ObjNode *trigger, ObjNode *theNode);
static Boolean DoTrig_FreeLifePOW(ObjNode *trigger, ObjNode *theNode);



/****************************/
/*    CONSTANTS             */
/****************************/

#define POW_Y_OFF   200.0f

#define	POW_SCALE	10.0

enum
{
	POW_MODE_NORMAL,
	POW_MODE_FADEOUT,
	POW_MODE_FADEIN,
	POW_MODE_DELAY
};


#define POW_REAPPEAR_DELAY  10.0f



/*********************/
/*    VARIABLES      */
/*********************/

#define	WeaponPOWType		Special[0]
#define	WeaponPOWQuantity	Special[1]
#define	Wobble				SpecialF[0]


/************************* ADD WEAPON POWERUP *********************************/

Boolean AddWeaponPOW(TerrainItemEntryType *itemPtr, float  x, float z)
{
short	weaponType = itemPtr->parm[0];

	if (weaponType == WEAPON_TYPE_SONICSCREAM)			// since this in an infinite weapon, don't need POW's
		return(true);

				/**************/
				/* MAKE FRAME */
				/**************/

	NewObjectDefinitionType def =
	{
		.group 		= MODEL_GROUP_GLOBAL,
		.type 		= GLOBAL_ObjType_POWFrame,
		.scale 		= POW_SCALE,
		.coord.x 	= x,
		.coord.z 	= z,
		.coord.y 	= itemPtr->terrainY + POW_Y_OFF,
		.flags 		= gAutoFadeStatusBits,
		.slot 		= PLAYER_SLOT + 55,
		.moveCall 	= MovePOW,
		.rot 		= RandomFloat()*PI2,
	};

	ObjNode* newObj = MakeNewDisplayGroupObject(&def);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list

	newObj->WeaponPOWType 		= weaponType;
	newObj->Mode				= POW_MODE_NORMAL;

	switch(weaponType)
	{
		case	WEAPON_TYPE_HEATSEEKER:
				if (gVSMode == VS_MODE_NONE)						// fewer missiles in 2P modes
					newObj->WeaponPOWQuantity 	= 10;
				else
					newObj->WeaponPOWQuantity 	= 4;
				break;

		case	WEAPON_TYPE_BLASTER:
				newObj->WeaponPOWQuantity 	= 25;
				break;


		default:
				newObj->WeaponPOWQuantity 	= 20;
	}

	newObj->Wobble				= RandomFloat() * PI2;

			/* SET COLLISION STUFF */

	newObj->CType 			= CTYPE_TRIGGER | CTYPE_POWERUP;
	newObj->CBits			= 0;
	CreateCollisionBoxFromBoundingBox_Maximized(newObj, 1.5);

	newObj->TriggerCallback = DoTrig_WeaponPOW;




		/*****************/
		/* MAKE MEMBRANE */
		/*****************/

	def.type 		= GLOBAL_ObjType_BlasterPOWMembrane + weaponType;
	def.flags 		|= STATUS_BIT_DOUBLESIDED | STATUS_BIT_GLOW | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOFOG | STATUS_BIT_NOFOG;
	def.slot		= SLOT_OF_DUMB + 3;
	def.moveCall 	= nil;
	ObjNode* membrane = MakeNewDisplayGroupObject(&def);

	newObj->ChainNode = membrane;


	AttachShadowToObject(newObj, SHADOW_TYPE_CIRCULAR, 5, 2, true);


	return(true);													// item was added
}


/******************** MOVE WEAPON POWERUP ********************/

static void MovePOW(ObjNode *pow)
{
ObjNode	*mem = pow->ChainNode;
float	fps = gFramesPerSecondFrac;

	if (TrackTerrainItem(pow))							// just check to see if it's gone
	{
		DeleteObject(pow);
		return;
	}

		/* SPIN */

	pow->Rot.y += fps * PI;


		/* WOBBLE */

	pow->Wobble += fps * 2.5f;
	pow->Coord.y = pow->InitCoord.y + sin(pow->Wobble) * 15.0f;

	UpdateObjectTransforms(pow);
	UpdateShadow(pow);


		/************************/
		/* UPDATE MODE SPECIFIC */
		/************************/

	switch(pow->Mode)
	{
		case	POW_MODE_NORMAL:
				break;

		case	POW_MODE_FADEOUT:
				mem->ColorFilter.a -= fps * 2.0f;
				if (mem->ColorFilter.a <= 0.0f)
				{
					mem->ColorFilter.a = 0.0f;
					if (gNumPlayers > 1)					// if in multi-player level, then set delay until POW fades back in
					{
						pow->Mode = POW_MODE_DELAY;

						if (gVSMode == VS_MODE_RACE)
							pow->Timer = POW_REAPPEAR_DELAY * .5;
						else
							pow->Timer = POW_REAPPEAR_DELAY;
					}
					else
					{
						if (IsObjectTotallyCulled(pow))		// 1-player mode, so just nix once culled
						{
							pow->TerrainItemPtr = nil;		// don't come back
							DeleteObject(pow);
							return;
						}
					}
				}
				break;


		case	POW_MODE_FADEIN:
				mem->ColorFilter.a += fps * 2.0f;
				if (mem->ColorFilter.a >= 1.0f)
				{
					mem->ColorFilter.a  = 1.0f;
					pow->Mode			= POW_MODE_NORMAL;
					pow->CType 			= CTYPE_TRIGGER | CTYPE_POWERUP;
				}
				break;

		case	POW_MODE_DELAY:
				pow->Timer -= fps;
				if (pow->Timer <= 0.0f)
				{
					pow->Mode = POW_MODE_FADEIN;
				}
				break;
	}


		/* UPDATE MEMBRANE */

	mem->Rot.y = pow->Rot.y;
	mem->Coord.y = pow->Coord.y;
	UpdateObjectTransforms(mem);
}


/******************** TRIGGER CALLBACK:  WEAPON POW ************************/
//
// Returns TRUE if want to handle hit as a solid
//

static Boolean DoTrig_WeaponPOW(ObjNode *trigger, ObjNode *theNode)
{
short	weaponType, playerNum, quan;


	weaponType 	= trigger->WeaponPOWType;
	quan 		= trigger->WeaponPOWQuantity;
	playerNum 	= theNode->PlayerNum;

	gPlayerInfo[playerNum].weaponQuantity[weaponType] += quan;		// add in quantity
	if (gPlayerInfo[playerNum].weaponQuantity[weaponType] > 999)	// max @ 999
		gPlayerInfo[playerNum].weaponQuantity[weaponType] = 999;

	if (gPlayerInfo[playerNum].currentWeapon == WEAPON_TYPE_NONE)	// if no weapon was selected then select this
		gPlayerInfo[playerNum].currentWeapon = weaponType;


			/* MAKE FADE OUT */

	trigger->Mode = POW_MODE_FADEOUT;
	trigger->CType = 0;


			/* PLAY EFFECT */

	PlayEffect_Parms3D(EFFECT_GETPOW, &trigger->Coord, NORMAL_CHANNEL_RATE, .6);
	PlayRumbleEffect(EFFECT_GETPOW, playerNum);

	return(false);
}



#pragma mark -

/************************* ADD HEALTH POWERUP *********************************/

Boolean AddHealthPOW(TerrainItemEntryType *itemPtr, float  x, float z)
{
				/**************/
				/* MAKE FRAME */
				/**************/

	NewObjectDefinitionType def =
	{
		.group 		= MODEL_GROUP_GLOBAL,
		.type 		= GLOBAL_ObjType_HealthPOWFrame,
		.scale 		= POW_SCALE,
		.coord.x 	= x,
		.coord.z 	= z,
		.coord.y 	= itemPtr->terrainY + POW_Y_OFF,
		.flags 		= gAutoFadeStatusBits,
		.slot 		= PLAYER_SLOT + 55,
		.moveCall 	= MovePOW,
		.rot 		= RandomFloat()*PI2,
	};
	ObjNode* newObj = MakeNewDisplayGroupObject(&def);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list
	newObj->Mode				= POW_MODE_NORMAL;

			/* SET COLLISION STUFF */

	newObj->CType 			= CTYPE_TRIGGER | CTYPE_POWERUP;
	newObj->CBits			= 0;
	CreateCollisionBoxFromBoundingBox_Maximized(newObj, 1.5);

	newObj->TriggerCallback = DoTrig_HealthPOW;


		/*****************/
		/* MAKE MEMBRANE */
		/*****************/

	def.type 		= GLOBAL_ObjType_HealthPOWMembrane;
	def.flags 		|= STATUS_BIT_DOUBLESIDED | STATUS_BIT_GLOW | STATUS_BIT_NOLIGHTING  | STATUS_BIT_NOFOG;
	def.slot		= SLOT_OF_DUMB + 3;
	def.moveCall 	= nil;
	ObjNode* membrane = MakeNewDisplayGroupObject(&def);

	newObj->ChainNode = membrane;


	AttachShadowToObject(newObj, SHADOW_TYPE_CIRCULAR, 4, 1.5, true);


	return(true);													// item was added
}



/******************** TRIGGER CALLBACK:  HEALTH POW ************************/
//
// Returns TRUE if want to handle hit as a solid
//

static Boolean DoTrig_HealthPOW(ObjNode *trigger, ObjNode *theNode)
{
short	playerNum;

	playerNum 	= theNode->PlayerNum;

	gPlayerInfo[playerNum].health += .5f;
	if (gPlayerInfo[playerNum].health > 1.0f)
		gPlayerInfo[playerNum].health = 1.0f;

			/* MAKE FADE OUT */

	trigger->Mode = POW_MODE_FADEOUT;
	trigger->CType = 0;


			/* PLAY EFFECT */

	PlayEffect_Parms3D(EFFECT_GETPOW, &trigger->Coord, NORMAL_CHANNEL_RATE, .6);
	PlayRumbleEffect(EFFECT_GETPOW, playerNum);

	return(false);
}



#pragma mark -

/************************* ADD FUEL POWERUP *********************************/

Boolean AddFuelPOW(TerrainItemEntryType *itemPtr, float  x, float z)
{
				/**************/
				/* MAKE FRAME */
				/**************/

	NewObjectDefinitionType def =
	{
		.group 		= MODEL_GROUP_GLOBAL,
		.type 		= GLOBAL_ObjType_POWFrame,
		.scale 		= POW_SCALE,
		.coord.x 	= x,
		.coord.z 	= z,
		.coord.y 	= itemPtr->terrainY + POW_Y_OFF,
		.flags 		= gAutoFadeStatusBits,
		.slot 		= PLAYER_SLOT + 55,
		.moveCall 	= MovePOW,
		.rot 		= RandomFloat()*PI2,
	};
	ObjNode* newObj = MakeNewDisplayGroupObject(&def);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list
	newObj->Mode				= POW_MODE_NORMAL;

			/* SET COLLISION STUFF */

	newObj->CType 			= CTYPE_TRIGGER | CTYPE_POWERUP;
	newObj->CBits			= 0;
	CreateCollisionBoxFromBoundingBox_Maximized(newObj, 1.5);

	newObj->TriggerCallback = DoTrig_FuelPOW;


		/*****************/
		/* MAKE MEMBRANE */
		/*****************/

	def.type 		= GLOBAL_ObjType_FuelPOWMembrane;
	def.flags 		|= STATUS_BIT_DOUBLESIDED | STATUS_BIT_GLOW | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOFOG;
	def.slot		= SLOT_OF_DUMB + 3;
	def.moveCall 	= nil;
	ObjNode* membrane = MakeNewDisplayGroupObject(&def);

	newObj->ChainNode = membrane;


	AttachShadowToObject(newObj, SHADOW_TYPE_CIRCULAR, 5, 2, true);


	return(true);													// item was added
}



/******************** TRIGGER CALLBACK:  FUEL POW ************************/
//
// Returns TRUE if want to handle hit as a solid
//

static Boolean DoTrig_FuelPOW(ObjNode *trigger, ObjNode *theNode)
{
short	playerNum;

	playerNum 	= theNode->PlayerNum;

	if (gVSMode == VS_MODE_NONE)
		gPlayerInfo[playerNum].jetpackFuel += .5f;
	else
		gPlayerInfo[playerNum].jetpackFuel += .25f;		// in 2P modes fuel gives less

	if (gPlayerInfo[playerNum].jetpackFuel > 1.0f)
		gPlayerInfo[playerNum].jetpackFuel = 1.0f;


			/* MAKE FADE OUT */

	trigger->Mode = POW_MODE_FADEOUT;
	trigger->CType = 0;


			/* PLAY EFFECT */

	PlayEffect_Parms3D(EFFECT_GETPOW, &trigger->Coord, NORMAL_CHANNEL_RATE, .6);
	PlayRumbleEffect(EFFECT_GETPOW, playerNum);

	return(false);
}

#pragma mark -

/************************* ADD SHIELD POWERUP *********************************/

Boolean AddShieldPOW(TerrainItemEntryType *itemPtr, float  x, float z)
{
				/**************/
				/* MAKE FRAME */
				/**************/

	NewObjectDefinitionType def =
	{
		.group 		= MODEL_GROUP_GLOBAL,
		.type 		= GLOBAL_ObjType_POWFrame,
		.scale 		= POW_SCALE,
		.coord.x 	= x,
		.coord.z 	= z,
		.coord.y 	= itemPtr->terrainY + POW_Y_OFF,
		.flags 		= gAutoFadeStatusBits,
		.slot 		= PLAYER_SLOT + 55,
		.moveCall 	= MovePOW,
		.rot 		= RandomFloat()*PI2,
	};
	ObjNode* newObj = MakeNewDisplayGroupObject(&def);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list
	newObj->Mode				= POW_MODE_NORMAL;

			/* SET COLLISION STUFF */

	newObj->CType 			= CTYPE_TRIGGER | CTYPE_POWERUP;
	newObj->CBits			= 0;
	CreateCollisionBoxFromBoundingBox_Maximized(newObj, 1.5);

	newObj->TriggerCallback = DoTrig_ShieldPOW;


		/*****************/
		/* MAKE MEMBRANE */
		/*****************/

	def.type 		= GLOBAL_ObjType_ShieldPOWMembrane;
	def.flags 		|= STATUS_BIT_DOUBLESIDED | STATUS_BIT_GLOW | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOFOG;
	def.slot		= SLOT_OF_DUMB + 3;
	def.moveCall 	= nil;
	ObjNode* membrane = MakeNewDisplayGroupObject(&def);

	newObj->ChainNode = membrane;


	AttachShadowToObject(newObj, SHADOW_TYPE_CIRCULAR, 5, 2, true);


	return(true);													// item was added
}



/******************** TRIGGER CALLBACK:  SHIELD POW ************************/
//
// Returns TRUE if want to handle hit as a solid
//

static Boolean DoTrig_ShieldPOW(ObjNode *trigger, ObjNode *theNode)
{
short	playerNum;

			/* GIVE PLAYER SHIELD POWER */

	playerNum 	= theNode->PlayerNum;

	gPlayerInfo[playerNum].shieldPower += MAX_SHIELD_POWER * .5f;
	if (gPlayerInfo[playerNum].shieldPower > MAX_SHIELD_POWER)
		gPlayerInfo[playerNum].shieldPower = MAX_SHIELD_POWER;

	if (gPlayerInfo[playerNum].shieldObj == nil)				// see if need to create the shield object
		CreatePlayerShield(playerNum);


			/* MAKE FADE OUT */

	trigger->Mode = POW_MODE_FADEOUT;
	trigger->CType = 0;


			/* PLAY EFFECT */

	PlayEffect_Parms3D(EFFECT_GETPOW, &trigger->Coord, NORMAL_CHANNEL_RATE, .6);
	PlayRumbleEffect(EFFECT_GETPOW, playerNum);

	return(false);
}




#pragma mark -

/************************* ADD FREE LIFE *********************************/

Boolean AddFreeLifePOW(TerrainItemEntryType *itemPtr, float  x, float z)
{
				/**************/
				/* MAKE FRAME */
				/**************/

	NewObjectDefinitionType def =
	{
		.group 		= MODEL_GROUP_GLOBAL,
		.type 		= GLOBAL_ObjType_POWFrame,
		.scale 		= POW_SCALE,
		.coord.x 	= x,
		.coord.z 	= z,
		.coord.y 	= itemPtr->terrainY + POW_Y_OFF,
		.flags 		= gAutoFadeStatusBits,
		.slot 		= PLAYER_SLOT + 55,
		.moveCall 	= MovePOW,
		.rot 		= RandomFloat()*PI2,
	};
	ObjNode* newObj = MakeNewDisplayGroupObject(&def);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list

			/* SET COLLISION STUFF */

	newObj->CType 			= CTYPE_TRIGGER | CTYPE_POWERUP;
	newObj->CBits			= 0;
	CreateCollisionBoxFromBoundingBox_Maximized(newObj, 1.5);

	newObj->TriggerCallback = DoTrig_FreeLifePOW;


		/*****************/
		/* MAKE MEMBRANE */
		/*****************/

	def.type 		= GLOBAL_ObjType_FreeLifePOWMembrane;
	def.flags 		|= STATUS_BIT_DOUBLESIDED | STATUS_BIT_GLOW | STATUS_BIT_NOLIGHTING  | STATUS_BIT_NOFOG;
	def.slot		= SLOT_OF_DUMB + 3;
	def.moveCall 	= nil;
	ObjNode* membrane = MakeNewDisplayGroupObject(&def);

	newObj->ChainNode = membrane;


	AttachShadowToObject(newObj, SHADOW_TYPE_CIRCULAR, 4, 1.5, true);


	return(true);													// item was added
}



/******************** TRIGGER CALLBACK:  FREE LIFE POW ************************/
//
// Returns TRUE if want to handle hit as a solid
//

static Boolean DoTrig_FreeLifePOW(ObjNode *trigger, ObjNode *theNode)
{
short	playerNum;


	playerNum 	= theNode->PlayerNum;

	gPlayerInfo[playerNum].numFreeLives++;


			/* MAKE FADE OUT */

	trigger->Mode = POW_MODE_FADEOUT;
	trigger->CType = 0;


			/* PLAY EFFECT */

	PlayEffect_Parms3D(EFFECT_GETPOW, &trigger->Coord, NORMAL_CHANNEL_RATE, .6);
	PlayRumbleEffect(EFFECT_GETPOW, playerNum);

	return(false);
}







