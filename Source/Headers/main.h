//
// main.h
//

#pragma once

// LevelNum is now a native Swift enum in GameEnums.swift - nothing in any
// .c file touches it (verified 2026-07-07: LoadLevel.c, the only real C
// user of NUM_LEVELS/LEVEL_NUM_*, was ported to Swift and deleted).


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
