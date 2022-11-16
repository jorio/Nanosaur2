/****************************/
/*   	PAUSED.C			*/
/* By Brian Greenstone      */
/* (c)2002 Pangea Software  */
/* (c)2022 Iliyas Jorio     */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/

#include "game.h"

/****************************/
/*    PROTOTYPES            */
/****************************/

Boolean gGamePaused = false;
static ObjNode* gMouseCursor = NULL;

static void OnExitPause(int outcome);



/****************************/
/*    CALLBACKS             */
/****************************/

/****************** TOGGLE SPLIT-SCREEN MODE ********************/

int ShouldDisplaySplitscreenModeCycler(const MenuItem* mi)
{
	(void) mi;

	if (gNumPlayers >= 2)
		return 0;
	else
		return kMILayoutFlagHidden | kMILayoutFlagDisabled;
}

void OnToggleSplitscreenMode(const MenuItem* mi)
{
	(void) mi;

	gActiveSplitScreenMode = gGamePrefs.splitScreenMode;

	for (int i = 0; i < gNumPlayers; i++)		// smaller FOV for wide panes
	{
		gGameViewInfoPtr->fov[i] = GetSplitscreenPaneFOV();
	}
}

/****************************/
/*    CONSTANTS             */
/****************************/

#define	PAUSED_FONT_SCALE	30.0f
#define	PAUSED_LINE_SPACING	(PAUSED_FONT_SCALE * 1.1f)

#define	PAUSED_TEXT_ANAGLYPH_Z	5.0f

static const MenuItem gPauseMenuTree[] =
{
	{ .id='paus' },

	{kMIPick, STR_RESUME, .id='resu', .next='EXIT' },

	{kMISpacer, .customHeight=.3f},

	// 2P split-screen mode chooser
	{
		.type = kMICycler1,
		.text = STR_SPLITSCREEN_MODE,
		.getLayoutFlags = ShouldDisplaySplitscreenModeCycler,
		.callback = OnToggleSplitscreenMode,
		.cycler =
		{
			.valuePtr = &gGamePrefs.splitScreenMode,
			.choices =
			{
				{ .text = STR_SPLITSCREEN_HORIZ, .value = SPLITSCREEN_MODE_HORIZ },
				{ .text = STR_SPLITSCREEN_VERT, .value = SPLITSCREEN_MODE_VERT },
			},
		},
	},

	{kMIPick, STR_SETTINGS, .next='sett' },

	{kMISpacer, .customHeight=.3f},

	{kMIPick, STR_RETIRE, .id='bail', .next='EXIT' },

//	{kMIPick, STR_QUIT, .id='quit', .next='EXIT' },

	{ 0 },
};


/*********************/
/*    VARIABLES      */
/*********************/


/********************** DO PAUSED **************************/

void DoPaused(void)
{
	gGamePaused = true;
	GrabMouse(false);
	PauseAllChannels(true);

	gMouseCursor = MakeMouseCursorObject();

	MenuStyle style = kDefaultMenuStyle;
	style.canBackOutOfRootMenu = true;
	style.darkenPaneOpacity = .6f;
	style.startButtonExits = true;
	style.exitCall = OnExitPause;
	MakeMenu(gPauseMenuTree, &style);
	RegisterSettingsMenu();
}

static void OnExitPause(int outcome)
{
	gGamePaused = false;
	GrabMouse(true);
	PauseAllChannels(false);

	DeleteObject(gMouseCursor);
	gMouseCursor = NULL;

	InvalidateAllInputs();

	switch (outcome)
	{
		case	'resu':								// RESUME
		default:
//			gHideInfobar = false;
			break;

		case	'bail':								// EXIT
			gGameOver = true;
			break;

		case	'quit':								// QUIT
			CleanQuit();
			break;
	}
}
