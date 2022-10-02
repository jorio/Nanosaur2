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
#include "menu.h"

/****************************/
/*    PROTOTYPES            */
/****************************/

Boolean gGamePaused = false;
static ObjNode* gMouseCursor = NULL;

static void OnExitPause(int outcome);


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

	/*
	{kMISpacer, .customHeight=.3f},

	// 2P split-screen mode chooser
	{
		.type = kMICycler1,
		.text = STR_SPLITSCREEN_MODE,
		.id = 2,	// ShouldDisplaySplitscreenModeCycler looks at this ID to know it's meant for 2P
		.getLayoutFlags = ShouldDisplaySplitscreenModeCycler,
		.callback = OnToggleSplitscreenMode,
		.cycler =
		{
			.valuePtr = &gGamePrefs.splitScreenMode2P,
			.choices =
			{
				{ .text = STR_SPLITSCREEN_HORIZ, .value = SPLITSCREEN_MODE_2P_TALL },
				{ .text = STR_SPLITSCREEN_VERT, .value = SPLITSCREEN_MODE_2P_WIDE },
			},
		},
	},

	// 3P split-screen mode chooser
	{
		.type = kMICycler1,
		.text = STR_SPLITSCREEN_MODE,
		.id = 3,	// ShouldDisplaySplitscreenModeCycler looks at this ID to know it's meant for 3P
		.getLayoutFlags = ShouldDisplaySplitscreenModeCycler,
		.callback = OnToggleSplitscreenMode,
		.cycler =
		{
			.valuePtr = &gGamePrefs.splitScreenMode3P,
			.choices =
			{
				{ .text = STR_SPLITSCREEN_HORIZ, .value = SPLITSCREEN_MODE_3P_TALL },
				{ .text = STR_SPLITSCREEN_VERT, .value = SPLITSCREEN_MODE_3P_WIDE },
			},
		},
	},

	// Race timer
	{
		.type = kMICycler1,
		.text = STR_RACE_TIMER,
		.cycler=
		{
			.valuePtr=&gGamePrefs.raceTimer,
			.choices=
			{
					{STR_RACE_TIMER_HIDDEN, 0},
					{STR_RACE_TIMER_SIMPLE, 1},
					{STR_RACE_TIMER_DETAILED, 2},
			},
		},
	},

	{kMIPick, STR_SETTINGS, .callback=RegisterSettingsMenu, .next='sett' },

	{kMISpacer, .customHeight=.3f},
	*/

	{kMIPick, STR_RETIRE, .id='bail', .next='EXIT' },

	{kMIPick, STR_QUIT, .id='quit', .next='EXIT' },

	{ 0 },
};


/*********************/
/*    VARIABLES      */
/*********************/


/********************** DO PAUSED **************************/

static void UpdatePausedMenuCallback(void)
{
	MoveObjects();
	DoPlayerTerrainUpdate();							// need to call this to keep supertiles active
}

void DoPaused(void)
{
	gGamePaused = true;
	GrabMouse(false);
//	PauseAllChannels(true);		//TODO

	gMouseCursor = MakeMouseCursorObject();

	MenuStyle style = kDefaultMenuStyle;
	style.canBackOutOfRootMenu = true;
	style.darkenPaneOpacity = .6f;
	style.startButtonExits = true;
	style.exitCall = OnExitPause;
	MakeMenu(gPauseMenuTree, &style);
}


static void OnExitPause(int outcome)
{
	gGamePaused = false;
	GrabMouse(true);
//	PauseAllChannels(false);		// TODO

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
