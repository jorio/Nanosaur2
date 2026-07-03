//
// main.h
//

#pragma once

enum
{
	LEVEL_NUM_ADVENTURE1 = 0,
	LEVEL_NUM_ADVENTURE2,
	LEVEL_NUM_ADVENTURE3,

	LEVEL_NUM_RACE1,
	LEVEL_NUM_RACE2,
	LEVEL_NUM_BATTLE1,
	LEVEL_NUM_BATTLE2,
	LEVEL_NUM_FLAG1,
	LEVEL_NUM_FLAG2,

	NUM_LEVELS
};


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
extern	void ToolBoxInit(void);
void MoveEverything(void);
void InitDefaultPrefs(void);
void StartLevelCompletion(float coolDownTimer);
Boolean PrimeTimeDemoSpline(long splineNum, SplineItemType *itemPtr);

void LoadGlobalAssets(void);
void DisposeGlobalAssets(void);
