//
// miscscreens.h
//

#pragma once

void DoPaused(void);

void DoLegalScreen(void);

void DrawLoading(float percent);


		/* MAIN MENU */

void DoMainMenuScreen(void);
ObjNode* MakeMouseCursorObject(void);

void BuildMainMenuObjects(void);

void RegisterSettingsMenu(void);


		/* INTRO STORY */

typedef struct
{
	short	spriteNum;
	float	x,y;
	float	scale;
	float	rotz;
	float	alpha;
	float	delayToNext;
	float	delayToVanish;
	float	zoomSpeed;
	float	dx,dy;
	float	drot;
	float	delayUntilEffect;
	int		narrationSound;
	int		subtitleKey;
}SlideType;

#define	ZoomSpeed			SpecialF[0]
#define	EffectTimer			SpecialF[1]
#define	EffectNum			Special[0]
#define	HasPlayedEffect		Flag[0]

void DoIntroStoryScreen(void);


		/* LEVEL INTRO */

enum
{
	INTRO_MODE_SCREENSAVER,
	INTRO_MODE_CREDITS,
	INTRO_MODE_NOSAVE,
	INTRO_MODE_SAVEGAME
};

void DoLevelIntroScreen(Byte mode);



	/* WIN SCREEN */

void DoWinScreen(void);


	/* FILE SCREEN */

enum
{
	FILESCREEN_MODE_LOAD,
	FILESCREEN_MODE_SAVE,
};

void RegisterFileScreen(int fileScreenMode);

Boolean DoLocalGatherScreen(void);

	/* ANAGLYPH CALIBRATION */

#include "menu.h"

void DisposeAnaglyphCalibrationScreen(void);
void SetUpAnaglyphCalibrationScreen(const MenuItem* mi);
void OnChangeAnaglyphSetting(const MenuItem* mi);
int GetAnaglyphDisplayFlags(const MenuItem* mi);
int GetAnaglyphDisplayFlags_ColorOnly(const MenuItem* mi);
