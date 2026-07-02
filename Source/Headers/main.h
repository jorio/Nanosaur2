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
	BIOME_FOREST SWIFT_NAME(BIOME_FOREST),
	BIOME_DESERT SWIFT_NAME(BIOME_DESERT),
	BIOME_SWAMP SWIFT_NAME(BIOME_SWAMP),
	NUM_BIOMES SWIFT_NAME(NUM_BIOMES),
} Biome;


  	/* NANO VS. NANO MODES */

typedef enum SWIFT_ENUM_CLOSED VSMode
{
	VS_MODE_NONE SWIFT_NAME(VS_MODE_NONE) = 0,
	VS_MODE_RACE SWIFT_NAME(VS_MODE_RACE),
	VS_MODE_BATTLE SWIFT_NAME(VS_MODE_BATTLE),
	VS_MODE_CAPTURETHEFLAG SWIFT_NAME(VS_MODE_CAPTURETHEFLAG),
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
