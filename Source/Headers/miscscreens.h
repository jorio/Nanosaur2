//
// miscscreens.h
//




#define	NUM_SCORES		15
#define	MAX_NAME_LENGTH	15

#define	SCORE_TEXT_SPACING	15.0f
#define	SCORE_DIGITS		9


typedef struct
{
	unsigned char	name[MAX_NAME_LENGTH+1];
	unsigned long	score;
}HighScoreType;

#define	DARKEN_PANE_Z	450.0f

void DisplayPicture(FSSpec *spec);
void DoPaused(void);

void DoLegalScreen(void);
Boolean DoLevelCheatDialog(void);
void DoGameOptionsDialog(void);


void DrawLoading(float percent);

void DoDemoExpiredScreen(void);
void ShowDemoQuitScreen(void);


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
	Str63	narrationFile;
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










