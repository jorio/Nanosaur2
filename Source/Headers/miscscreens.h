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

// SlideType is now a native Swift struct (IntroStory.swift) - nothing in
// any .c file touches it (verified 2026-07-07: no extern globals, no
// static-inline functions, no C-side construction).

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
