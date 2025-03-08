/****************************/
/*   	MAINMENU SCREEN.C	*/
/* By Brian Greenstone      */
/* (c)2003 Pangea Software  */
/* (c)2022 Iliyas Jorio     */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/

#include "game.h"

/****************************/
/*    PROTOTYPES            */
/****************************/

static void SetupMainMenuScreen(void);
static void FreeMainMenuScreen(void);
static void ProcessMenuOutcome(int outcome);
static void SetMainController1P(void);
static void CheckForLevelCheat(void);
static void DeleteFileSlot(void);


/****************************/
/*    CONSTANTS             */
/****************************/

#define	FONT_SCALE	35.0f
#define	SCREENSAVER_DELAY	15.0f
#define	MENU_TEXT_ANAGLYPH_Z	4.0f
#define	CURSOR_SCALE	35.0f

// This menu tree MUST NOT BE CONST because CheckForLevelCheat needs to change
// a specific MenuItem's .next on the fly!
static MenuItem gMainMenuTree[] =
{
	{ .id='root' },
	{kMIPick, STR_PLAY_GAME,	.next='play', },
	{kMIPick, STR_SETTINGS,		.next='sett', },
	{kMIPick, STR_INFO,			.next='info', },
	{kMIPick, STR_QUIT,			.id='quit', .next='EXIT', },

	{ .id='play' },
	{kMIPick, STR_ADVENTURE,	.next='EXIT', .id='adve', .callback=CheckForLevelCheat},
	{kMIPick, STR_NANO_VS_NANO,	.next='bttl' },
	{kMIPick, STR_SAVED_GAMES,	.next='load'},
	{kMIPick, STR_BACK_SYMBOL,	.next='BACK' },

	{ .id='info' },
	{kMIPick, STR_STORY,			.id='intr',	.next='EXIT' },
	{kMIPick, STR_STORY_SUBTITLED,	.id='ints',	.next='EXIT' },
	{kMIPick, STR_CREDITS,			.id='cred',	.next='EXIT' },
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	{ .id='bttl' },
	{kMIPick, STR_RACE1,			.id='rac1',	.next='EXIT' },
	{kMIPick, STR_RACE2,			.id='rac2',	.next='EXIT' },
	{kMISpacer, .customHeight=.3f},
	{kMIPick, STR_BATTLE1,			.id='bat1',	.next='EXIT' },
	{kMIPick, STR_BATTLE2,			.id='bat2',	.next='EXIT' },
	{kMISpacer, .customHeight=.3f},
	{kMIPick, STR_CAPTURE1,			.id='cap1',	.next='EXIT' },
	{kMIPick, STR_CAPTURE2,			.id='cap2',	.next='EXIT' },
	{kMISpacer, .customHeight=.3f},
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	{ .id='chea' },
	{kMILabel, .rawText="CHEAT MENU!"},
	{kMIPick, .rawText="LEVEL 1: FOREST",	.id='cht1',	.next='EXIT' },
	{kMIPick, .rawText="LEVEL 2: DESERT",	.id='cht2',	.next='EXIT' },
	{kMIPick, .rawText="LEVEL 3: SWAMP",	.id='cht3',	.next='EXIT' },
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	{.id='load'},
	{kMIFileSlot, STR_FILE, .id='lf#0', .fileSlot=0, .getLayoutFlags=DisableEmptyFileSlots, .next='EXIT'},
	{kMIFileSlot, STR_FILE, .id='lf#1', .fileSlot=1, .getLayoutFlags=DisableEmptyFileSlots, .next='EXIT'},
	{kMIFileSlot, STR_FILE, .id='lf#2', .fileSlot=2, .getLayoutFlags=DisableEmptyFileSlots, .next='EXIT'},
	{kMIFileSlot, STR_FILE, .id='lf#3', .fileSlot=3, .getLayoutFlags=DisableEmptyFileSlots, .next='EXIT'},
	{kMIFileSlot, STR_FILE, .id='lf#4', .fileSlot=4, .getLayoutFlags=DisableEmptyFileSlots, .next='EXIT'},
	{kMIPick, STR_DELETE_A_FILE, .next='dele'},
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	{.id='dele'},
	{kMILabel, .text=STR_DELETE_WHICH, .customHeight=1.5f},
	{kMIFileSlot, STR_DELETE, .id='df#0', .fileSlot=0, .getLayoutFlags=DisableEmptyFileSlots, .callback=DeleteFileSlot, .next='BACK'},
	{kMIFileSlot, STR_DELETE, .id='df#1', .fileSlot=1, .getLayoutFlags=DisableEmptyFileSlots, .callback=DeleteFileSlot, .next='BACK'},
	{kMIFileSlot, STR_DELETE, .id='df#2', .fileSlot=2, .getLayoutFlags=DisableEmptyFileSlots, .callback=DeleteFileSlot, .next='BACK'},
	{kMIFileSlot, STR_DELETE, .id='df#3', .fileSlot=3, .getLayoutFlags=DisableEmptyFileSlots, .callback=DeleteFileSlot, .next='BACK'},
	{kMIFileSlot, STR_DELETE, .id='df#4', .fileSlot=4, .getLayoutFlags=DisableEmptyFileSlots, .callback=DeleteFileSlot, .next='BACK'},
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	{ .id=0 }
};

/*********************/
/*    VARIABLES      */
/*********************/

Boolean	gPlayNow = false;

OGLPoint2D	gCursorCoord;						// screen coords based on 640x480 system

static ObjNode* gMainMenuBackground = NULL;
static ObjNode* gMainMenuMouseCursor = NULL;


/********************** MAIN MENU MOVE CALLBACK **************************/

static void MoveMainMenu(void)
{
			/* SEE IF DO SCREENSAVER */
			//
			// BEFORE updating the menu (Otherwise MoveObjects may delete it)
			//

	if (GetCurrentMenu() == 'root' && GetMenuIdleTime() > SCREENSAVER_DELAY)
	{
		KillMenu('ssav');
	}
	else if (IsKeyDown(SDL_SCANCODE_T))				// activate time demo?
	{
		KillMenu('demo');
	}

	MoveObjects();
}


/********************** DO MAINMENU SCREEN **************************/

void DoMainMenuScreen(void)
{
	gPlayNow = false;

	while (!gPlayNow)
	{
		if (gCurrentSong != SONG_THEME)
			PlaySong(SONG_THEME, true);

		SetupMainMenuScreen();

		{
			MenuStyle style = kDefaultMenuStyle;
			style.yOffset = 302.5f;
			MakeMenu(gMainMenuTree, &style);
			RegisterSettingsMenu();
		}

		while (0 == gMenuOutcome)
		{
			DoSDLMaintenance();
			CalcFramesPerSecond();
			MoveMainMenu();
			OGL_DrawScene(DrawObjects);
		}

		// Decide whether to fade out the music
		switch (gMenuOutcome)
		{
			case 'cred':
			case 'ssav':
				gGameViewInfoPtr->fadeSound = false;
				break;

			case 'rac1':
			case 'rac2':
			case 'bat1':
			case 'bat2':
			case 'cap1':
			case 'cap2':
				// entering multiplayer; fade sound if we're gonna skip LocalGather
				gGameViewInfoPtr->fadeSound = GetNumGamepad() >= 2;
				break;

			default:
				gGameViewInfoPtr->fadeSound = true;
				break;
		}

		OGL_FadeOutScene(DrawObjects, NULL);
		FreeMainMenuScreen();

		ProcessMenuOutcome(gMenuOutcome);
	}
}

/********************* BUILD MAIN MENU OBJECTS **********************/
//
// We need to expose this to AnaglyphCalibration.c so the background texture
// always reflects the current anaglyph settings
//

void BuildMainMenuObjects(void)
{
	if (gMainMenuBackground)
	{
		DeleteObject(gMainMenuBackground);
	}

	if (gMainMenuMouseCursor)
	{
		DeleteObject(gMainMenuMouseCursor);
	}

	gMainMenuBackground = MakeBackgroundPictureObject(":Sprites:menu:menuback");
	gMainMenuMouseCursor = MakeMouseCursorObject();
}


/********************* SETUP MAINMENU SCREEN **********************/

static void SetupMainMenuScreen(void)
{
OGLSetupInputType	viewDef;
static const OGLVector3D	fillDirection1 = { -.7, .9, -1.0 };
static const OGLVector3D	fillDirection2 = { .3, .8, 1.0 };

	gPlayNow 		= false;


			/**************/
			/* SETUP VIEW */
			/**************/

	OGL_NewViewDef(&viewDef);

	viewDef.camera.fov 			= 1.0;
	viewDef.camera.hither 		= 20;
	viewDef.camera.yon 			= 2500;

	viewDef.styles.useFog			= true;
	viewDef.styles.fogStart			= viewDef.camera.yon * .6f;
	viewDef.styles.fogEnd			= viewDef.camera.yon * .9f;

	viewDef.view.clearBackBuffer	= true;
	viewDef.view.clearColor.r 		= 0;
	viewDef.view.clearColor.g 		= 0;
	viewDef.view.clearColor.b		= 0;

	viewDef.camera.from[0].x		= 0;
	viewDef.camera.from[0].y		= 50;
	viewDef.camera.from[0].z		= 500;

	viewDef.camera.to[0].y 		= 100.0f;

	viewDef.lights.ambientColor.r = .2;
	viewDef.lights.ambientColor.g = .2;
	viewDef.lights.ambientColor.b = .2;

	viewDef.lights.numFillLights 	= 2;

	viewDef.lights.fillDirection[0] = fillDirection1;
	viewDef.lights.fillColor[0].r 	= .8;
	viewDef.lights.fillColor[0].g 	= .8;
	viewDef.lights.fillColor[0].b 	= .6;

	viewDef.lights.fillDirection[1] = fillDirection2;
	viewDef.lights.fillColor[1].r 	= .5;
	viewDef.lights.fillColor[1].g 	= .5;
	viewDef.lights.fillColor[1].b 	= .0;

	OGL_SetupGameView(&viewDef);


	InitSparkles();


			/*****************/
			/* BUILD OBJECTS */
			/*****************/

	BuildMainMenuObjects();
	MakeFadeEvent(kFadeFlags_In, 3.0);
}


/********************** FREE MAINMENU SCREEN **********************/

static void FreeMainMenuScreen(void)
{
	MyFlushEvents();

	DeleteAllObjects();
	gMainMenuMouseCursor = NULL;
	gMainMenuBackground = NULL;

	DisposeSpriteGroup(SPRITE_GROUP_LEVELSPECIFIC);
	DisposeAllBG3DContainers();
	OGL_DisposeGameView();
}


#pragma mark -



/*********************** PROCESS MENU OUTCOME ***********************/

static void ProcessMenuOutcome(int outcome)
{
	gPlayNow = false;

	switch (outcome)
	{
		case	'quit':
			CleanQuit();
			break;

		case	'ssav':										// SCREENSAVER
			DoLevelIntroScreen(INTRO_MODE_SCREENSAVER);
			break;

		case	'intr':										// STORY
			gGamePrefs.cutsceneSubtitles = false;
			SavePrefs();
			DoIntroStoryScreen();
			break;

		case	'ints':
			gGamePrefs.cutsceneSubtitles = true;
			SavePrefs();
			DoIntroStoryScreen();
			break;

		case	'cred':										// CREDITS
			DoLevelIntroScreen(INTRO_MODE_CREDITS);
			break;

		case	'demo':										// TIME DEMO (BENCHMARK)
			gTimeDemo = true;
			gSkipLevelIntro = true;
			gNumPlayers = 1;
			gPlayNow = true;
			gPlayingFromSavedGame = false;
			gLevelNum = LEVEL_NUM_ADVENTURE3;
			SDL_GL_SetSwapInterval(0);						// no vsync for time demo
			break;

		case	'adve':										// SINGLE-PLAYER ADVENTURE CAMPAIGN
			SetMainController1P();

			gNumPlayers = 1;
			gPlayNow = true;
			gPlayingFromSavedGame = false;
			gLevelNum = LEVEL_NUM_ADVENTURE1;
			break;

		case	'cht1':
		case	'cht2':
		case	'cht3':
			SetMainController1P();

			gNumPlayers = 1;
			gPlayNow = true;
			gPlayingFromSavedGame = false;
			gSkipLevelIntro = true;
			gLevelNum = LEVEL_NUM_ADVENTURE1 + (outcome - 'cht1');
			break;

		case	'lf#0':										// LOAD SINGLE-PLAYER FILE 0
		case	'lf#1':										// LOAD SINGLE-PLAYER FILE 1
		case	'lf#2':										// LOAD SINGLE-PLAYER FILE 2
		case	'lf#3':										// LOAD SINGLE-PLAYER FILE 3
		case	'lf#4':										// LOAD SINGLE-PLAYER FILE 4
		case	'lf#5':										// LOAD SINGLE-PLAYER FILE 5
		case	'lf#6':										// LOAD SINGLE-PLAYER FILE 6
		case	'lf#7':										// LOAD SINGLE-PLAYER FILE 7
		case	'lf#8':										// LOAD SINGLE-PLAYER FILE 8
		case	'lf#9':										// LOAD SINGLE-PLAYER FILE 9
		{
			SetMainController1P();

			SaveGameType loaded = {0};
			if (LoadSavedGame(outcome - 'lf#0', &loaded))
			{
				UseSaveGame(&loaded);
				gPlayingFromSavedGame = true;
				gNumPlayers = 1;
				gPlayNow = true;
			}
			break;
		}

		case	'rac1':										// RACE 1
		case	'rac2':										// RACE 2
			gNumPlayers = 2;
			gVSMode = VS_MODE_RACE;
			gLevelNum = LEVEL_NUM_RACE1 + (outcome - 'rac1');
			gPlayNow = true;
			gPlayingFromSavedGame = false;
			break;

		case	'bat1':										// BATTLE 1
		case	'bat2':										// BATTLE 2
			gNumPlayers = 2;
			gVSMode = VS_MODE_BATTLE;
			gLevelNum = LEVEL_NUM_BATTLE1 + (outcome - 'bat1');
			gPlayNow = true;
			gPlayingFromSavedGame = false;
			break;

		case	'cap1':										// CAPTURE THE FLAG 1
		case	'cap2':										// CAPTURE THE FLAG 2
			gNumPlayers = 2;
			gVSMode = VS_MODE_CAPTURETHEFLAG;
			gLevelNum = LEVEL_NUM_FLAG1 + (outcome - 'cap1');
			gPlayNow = true;
			gPlayingFromSavedGame = false;
			break;

		default:
			DoAlert("Unimplemented menu outcome '%c%c%c%c'",
						 (outcome >> 24) & 0xFF,
						 (outcome >> 16) & 0xFF,
						 (outcome >> 8) & 0xFF,
						 (outcome >> 0) & 0xFF);
			break;
	}
}


#pragma mark -

/********************* MOVE CURSOR *********************/
//
// NOTE:  this function is called from other places which need the cursor, not just the main menu
//

static void MoveMouseCursorObject(ObjNode *theNode)
{


			/*****************************/
			/* UPDATE CROSSHAIR POSITION */
			/*****************************/

	gCursorCoord = GetMouseCoords640x480();

	theNode->Coord.x = gCursorCoord.x;
	theNode->Coord.y = gCursorCoord.y;

	UpdateObjectTransforms(theNode);

	//Boolean visible = !gUserPrefersGamepad;
	Boolean visible = !gUserPrefersGamepad && IsMenuMouseControlled();

	if (visible)
	{
		// Fade in to prevent jarring cursor warp when exiting mouse grab mode
		theNode->ColorFilter.a += 8.0f * gFramesPerSecondFrac;
		if (theNode->ColorFilter.a > 1)
			theNode->ColorFilter.a = 1;
	}
	else
	{
		theNode->ColorFilter.a -= 4.0f * gFramesPerSecondFrac;
		if (theNode->ColorFilter.a < 0)
			theNode->ColorFilter.a = 0;
	}
}

/********************* MAKE MOUSE CURSOR OBJECT *********************/

ObjNode* MakeMouseCursorObject(void)
{
	GAME_ASSERT(gNumSpritesInGroupList[SPRITE_GROUP_CURSOR] != 0);

	NewObjectDefinitionType def =
	{
		.group		= SPRITE_GROUP_CURSOR,
		.type		= 0,					// the only sprite in the group
		.coord		= {0,0,0},
		.flags		= STATUS_BIT_MOVEINPAUSE,
		.slot		= CURSOR_SLOT,			// make sure this is the last sprite drawn
		.moveCall	= MoveMouseCursorObject,
		.rot		= 0,
		.scale		= CURSOR_SCALE,
	};

	ObjNode* cursor = MakeSpriteObject(&def, false);
	cursor->AnaglyphZ = MENU_TEXT_ANAGLYPH_Z + .5f;
	cursor->ColorFilter.a = 0;

	SendNodeToOverlayPane(cursor);

	return cursor;
}


/********* SET MAIN CONTROLLER TO USE IN SINGLE-PLAYER ADVENTURE *********/

static void SetMainController1P(void)
{
	int mainController = GetLastControllerForNeedAnyP(kNeed_UIConfirm);
	if (mainController >= 0)
	{
		SetMainController(mainController);
	}
}


/********* CHECK FOR LEVEL CHEAT KEY AS PLAYER ENTERS ADVENTURE *********/

static void CheckForLevelCheat(void)
{
			/* SCAN FOR 'ADVENTURE' MENU ITEM */

	for (int i = 0; !IsMenuTreeEndSentinel(&gMainMenuTree[i]); i++)
	{
		if (gMainMenuTree[i].id == 'adve')
		{
			if (IsKeyHeld(SDL_SCANCODE_F10))
			{
				gMainMenuTree[i].next = 'chea';
			}
			else
			{
				gMainMenuTree[i].next = 'EXIT';
			}

			break;
		}
	}
}

/********************* DELETE FILE SLOT ******************/

static void DeleteFileSlot(void)
{
	int id = GetCurrentMenuItemID();

	switch (id)
	{
		case 'df#0':
		case 'df#1':
		case 'df#2':
		case 'df#3':
		case 'df#4':
		case 'df#5':
		case 'df#6':
		case 'df#7':
		case 'df#8':
		case 'df#9':
			DeleteSavedGame(id - 'df#0');
			break;

		default:
			DoAlert("DeleteFileSlot: illegal menu item ID");
	}
}
