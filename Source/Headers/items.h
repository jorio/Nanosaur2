//
// items.h
//

#pragma once

#define	BUMBLEBEE_JOINTNUM_HAND		23


			/* ITEMS */




		/* EGGS */

// EggColor is now a native Swift enum in GameEnums.swift; gNumEggsToSave/
// gNumEggsSaved moved to Swift storage (Eggs.swift) - Eggs.c (their only
// real C user) was ported to Swift and deleted (verified 2026-07-07).



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







