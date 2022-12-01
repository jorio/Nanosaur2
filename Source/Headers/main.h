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


enum
{
	BIOME_FOREST,
	BIOME_DESERT,
	BIOME_SWAMP,
	NUM_BIOMES
};


  	/* NANO VS. NANO MODES */

enum
{
	VS_MODE_NONE = 0,
	VS_MODE_RACE,
	VS_MODE_BATTLE,
	VS_MODE_CAPTURETHEFLAG
};




//=================================================


void GameMain(void);
extern	void ToolBoxInit(void);
void MoveEverything(void);
void InitDefaultPrefs(void);
void StartLevelCompletion(float coolDownTimer);
Boolean PrimeTimeDemoSpline(long splineNum, SplineItemType *itemPtr);

void LoadGlobalAssets(void);
void DisposeGlobalAssets(void);
