//
// items.h
//

#pragma once

#define	BUMBLEBEE_JOINTNUM_HAND		23


			/* ITEMS */




		/* EGGS */

typedef enum SWIFT_ENUM_CLOSED EggColor
{
	EGG_COLOR_RED SWIFT_NAME(red),
	EGG_COLOR_GREEN SWIFT_NAME(green),
	EGG_COLOR_BLUE SWIFT_NAME(blue),
	EGG_COLOR_YELLOW SWIFT_NAME(yellow),
	EGG_COLOR_PURPLE SWIFT_NAME(purple),

	NUM_EGG_TYPES SWIFT_NAME(_count)
} EggColor;



extern	Byte	gNumEggsToSave[NUM_EGG_TYPES];
extern	Byte	gNumEggsSaved[NUM_EGG_TYPES];



		/* WORMHOLE */


extern	Boolean			gOpenPlayerWormhole;
extern	ObjNode			*gExitWormhole;



		/* POWERUPS */

enum
{
	POW_KIND_HEALTH,
	POW_KIND_FLIGHT,
	POW_KIND_MAP,
	POW_KIND_FREELIFE,
	POW_KIND_RAMGRAIN,
	POW_KIND_BUDDYBUG,
	POW_KIND_REDKEY,
	POW_KIND_GREENKEY,
	POW_KIND_BLUEKEY,
	POW_KIND_GREENCLOVER,
	POW_KIND_BLUECLOVER,
	POW_KIND_GOLDCLOVER,
	POW_KIND_SHIELD
};

		/* BUSHES */
//
// AddGrass/AddFern/AddBerryBush/AddCatTail/AddDesertBush/AddCactus/
// AddPalmBush/AddGeckoPlant/AddSproutPlant/AddIvy are now
// TerrainItemEntryType-pointer methods in Bushes.swift - nothing in C
// calls them anymore, so they're no longer declared here.


	/* FOREST DOOR */



	/* ELECTRODES */



		/* DUST DEVIL */



		/* LASER ORBS */







