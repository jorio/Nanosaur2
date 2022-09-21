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
	LANGUAGE_ENGLISH = 0,
	LANGUAGE_FRENCH,
	LANGUAGE_GERMAN,
	LANGUAGE_SPANISH,
	LANGUAGE_ITALIAN,
	LANGUAGE_SWEDISH,
	LANGUAGE_DUTCH,

	MAX_LANGUAGES
};


  	/* NANO VS. NANO MODES */

enum
{
	VS_MODE_NONE = 0,
	VS_MODE_RACE,
	VS_MODE_BATTLE,
	VS_MODE_CAPTURETHEFLAG
};


#define		HORIZ_PANE_FOV		.7
#define		VERT_PANE_FOV		1.1


//=================================================


int GameMain(void);
extern	void ToolBoxInit(void);
void MoveEverything(void);
void InitDefaultPrefs(void);
void StartLevelCompletion(float coolDownTimer);
Boolean PrimeTimeDemoSpline(long splineNum, SplineItemType *itemPtr);
