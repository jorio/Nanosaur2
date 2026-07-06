//
// main.h
//

#pragma once

typedef enum SWIFT_ENUM_CLOSED LevelNum
{
	LEVEL_NUM_ADVENTURE1 SWIFT_NAME(adventure1) = 0,
	LEVEL_NUM_ADVENTURE2 SWIFT_NAME(adventure2),
	LEVEL_NUM_ADVENTURE3 SWIFT_NAME(adventure3),

	LEVEL_NUM_RACE1 SWIFT_NAME(race1),
	LEVEL_NUM_RACE2 SWIFT_NAME(race2),
	LEVEL_NUM_BATTLE1 SWIFT_NAME(battle1),
	LEVEL_NUM_BATTLE2 SWIFT_NAME(battle2),
	LEVEL_NUM_FLAG1 SWIFT_NAME(flag1),
	LEVEL_NUM_FLAG2 SWIFT_NAME(flag2),

	NUM_LEVELS SWIFT_NAME(_count)
} LevelNum;


typedef enum SWIFT_ENUM_CLOSED Biome
{
	BIOME_FOREST SWIFT_NAME(forest),
	BIOME_DESERT SWIFT_NAME(desert),
	BIOME_SWAMP SWIFT_NAME(swamp),
	NUM_BIOMES SWIFT_NAME(_count),
} Biome;


  	/* NANO VS. NANO MODES */

// Note: VS_MODE_NONE imports as VSMode.none. If a VSMode? (Optional) ever
// appears in Swift, spell it VSMode.none there to avoid ambiguity with
// Optional.none.
typedef enum SWIFT_ENUM_CLOSED VSMode
{
	VS_MODE_NONE SWIFT_NAME(none) = 0,
	VS_MODE_RACE SWIFT_NAME(race),
	VS_MODE_BATTLE SWIFT_NAME(battle),
	VS_MODE_CAPTURETHEFLAG SWIFT_NAME(captureTheFlag),
} VSMode;




//=================================================




void GameMain(void);

#ifdef NANOSAUR_3DS
void GameMainCreditsPOC(void); // Source/System/Main.swift - TEMPORARY 3DS proof-of-concept entry point
#endif
