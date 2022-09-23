//
// miscscreens.h
//

#pragma once

void DisplayPicture(const char* path);
void DoPaused(void);

void DoLegalScreen(void);
Boolean DoLevelCheatDialog(void);
void DoGameOptionsDialog(void);


void DrawLoading(float percent);


		/* MAIN MENU */

#define	CURSOR_SCALE	35.0f


void DoMainMenuScreen(void);
void MoveCursor(ObjNode *theNode);

extern	ObjNode		*gMenuCursorObj;
extern	OGLPoint2D	gCursorCoord;
extern	ObjNode	*gMenuItems[];
extern	float	gMenuItemMinX[];
extern	float	gMenuItemMaxX[];
extern	short	gCurrentMenuItem, gOldMenuItem;



		/* LEVEL INTROS */

void DoLevelIntro(void);


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
	int 	narrationSound;
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
	INTRO_MODE_NOSAVE,
	INTRO_MODE_SAVEGAME
};

void DoLevelIntroScreen(Byte mode);



	/* WIN SCREEN */

void DoWinScreen(void);
