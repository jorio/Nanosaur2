/****************************/
/*   	PAUSED.C			*/
/* By Brian Greenstone      */
/* (c)2002 Pangea Software  */
/* (c)2022 Iliyas Jorio     */
/****************************/

// DoPaused/DoReallyQuit/OnExitPause are now in Paused.swift.
// The menu tree data tables (and the callbacks they embed by designated
// initializer) stay here: Swift can't construct MenuItem's anonymous-union
// fields (.cycler.choices, etc.) or four-char-code literals as cleanly.

/****************************/
/*    EXTERNALS             */
/****************************/

#include "game.h"
#include "PausedInternal.h"

Boolean gGamePaused = false;

/****************************/
/*    CALLBACKS             */
/****************************/

/****************** TOGGLE SPLIT-SCREEN MODE ********************/

static int ShouldDisplaySplitscreenModeCycler(const MenuItem* mi)
{
	(void) mi;

	if (gNumPlayers >= 2)
		return 0;
	else
		return kMILayoutFlagHidden | kMILayoutFlagDisabled;
}

static void OnToggleSplitscreenMode(void)
{
	gActiveSplitScreenMode = gGamePrefs.splitScreenMode;

	for (int i = 0; i < gNumPlayers; i++)		// smaller FOV for wide panes
	{
		gGameViewInfoPtr->fov[i] = GetSplitscreenPaneFOV();
	}
}

/****************************/
/*    CONSTANTS             */
/****************************/

#define	PAUSED_TEXT_ANAGLYPH_Z	5.0f

const MenuItem gReallyQuitMenuTree[] =
{
	{ .id='rlyq' },
	{kMILabel, .text=STR_REALLY_QUIT, .customHeight=1},
	{kMISpacer, .customHeight=0.5f},
	{kMIPick, STR_RESUME, .id='resu', .next='EXIT' },
	{kMIPick, STR_QUIT, .id='quit', .next='EXIT' },
	{0},
};

const MenuItem gPauseMenuTree[] =
{
	{ .id='paus' },

	{kMIPick, STR_RESUME, .id='resu', .next='EXIT' },

	{kMISpacer, .customHeight=.3f, .getLayoutFlags=ShouldDisplaySplitscreenModeCycler},

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

	{kMISpacer, .customHeight=.3f, .getLayoutFlags=ShouldDisplaySplitscreenModeCycler},

	{kMIPick, STR_RETIRE, .id='bail', .next='EXIT' },

//	{kMIPick, STR_QUIT, .id='quit', .next='EXIT' },

	{ 0 },
};
