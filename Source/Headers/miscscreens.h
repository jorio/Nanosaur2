//
// miscscreens.h
//

#pragma once

void DoPaused(void);
void DoReallyQuit(void);




		/* MAIN MENU */

ObjNode* MakeMouseCursorObject(void);


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



		/* LEVEL INTRO */

enum
{
	INTRO_MODE_SCREENSAVER,
	INTRO_MODE_CREDITS,
	INTRO_MODE_NOSAVE,
	INTRO_MODE_SAVEGAME
};




	/* WIN SCREEN */



	/* GATHER CONTROLLERS */


	/* ANAGLYPH CALIBRATION */

void SetUpAnaglyphCalibrationScreen(void);
