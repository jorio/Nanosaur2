/****************************/
/*      LOAD LEVEL.C        */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/

// LoadLevelArt is now in LoadLevel.swift. The lookup tables below stay
// here (sparse designated initializers) and are exposed via accessors
// declared in LoadLevelInternal.h.

/***************/
/* EXTERNALS   */
/***************/

#include "game.h"
#include "LoadLevelInternal.h"

/**********************/
/*     VARIABLES      */
/**********************/

static const Biome kLevelBiomes[NUM_LEVELS] =
{
	[LEVEL_NUM_ADVENTURE1]	= BIOME_FOREST,
	[LEVEL_NUM_ADVENTURE2]	= BIOME_DESERT,
	[LEVEL_NUM_ADVENTURE3]	= BIOME_SWAMP,
	[LEVEL_NUM_RACE1]		= BIOME_SWAMP,
	[LEVEL_NUM_RACE2]		= BIOME_DESERT,
	[LEVEL_NUM_BATTLE1]		= BIOME_FOREST,
	[LEVEL_NUM_BATTLE2]		= BIOME_DESERT,
	[LEVEL_NUM_FLAG1]		= BIOME_SWAMP,
	[LEVEL_NUM_FLAG2]		= BIOME_FOREST,
};

static const char* kLevelNames[NUM_LEVELS] =
{
	[LEVEL_NUM_ADVENTURE1]	= "level1",
	[LEVEL_NUM_ADVENTURE2]	= "level2",
	[LEVEL_NUM_ADVENTURE3]	= "level3",
	[LEVEL_NUM_RACE1]		= "race1",
	[LEVEL_NUM_RACE2]		= "race2",
	[LEVEL_NUM_BATTLE1]		= "battle1",
	[LEVEL_NUM_BATTLE2]		= "battle2",
	[LEVEL_NUM_FLAG1]		= "flag1",
	[LEVEL_NUM_FLAG2]		= "flag2",
};

static const char*	kBiomeNames[NUM_BIOMES] =
{
	[BIOME_FOREST]			= "forest",
	[BIOME_DESERT]			= "desert",
	[BIOME_SWAMP]			= "swamp",
};

Biome GetLevelBiome(int levelNum) { return kLevelBiomes[levelNum]; }
const char* GetLevelName(int levelNum) { return kLevelNames[levelNum]; }
const char* GetBiomeName(Biome biomeNum) { return kBiomeNames[biomeNum]; }
