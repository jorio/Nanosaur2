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


/****************************/
/*    CONSTANTS             */
/****************************/

#define	FONT_SCALE	35.0f
#define	SCREENSAVER_DELAY	15.0f
#define	MENU_TEXT_ANAGLYPH_Z	4.0f
#define	LINE_SPACING	(FONT_SCALE * 1.1f)
#define	CURSOR_SCALE	35.0f

static const MenuItem gMainMenuTree[] =
{
	{ .id='root' },
	{kMIPick, STR_PLAY_GAME,	.next='play', },
	{kMIPick, STR_SETTINGS,		.next='sett', },
	{kMIPick, STR_INFO,			.next='info', },
	{kMIPick, STR_QUIT,			.id='quit', .next='EXIT', },

	{ .id='play' },
	{kMIPick, STR_ADVENTURE,	.id='camp', .next='EXIT' },
	{kMIPick, STR_NANO_VS_NANO,	.next='bttl' },
	{kMIPick, STR_SAVED_GAMES,	.next='load'},
	{kMIPick, STR_BACK_SYMBOL,	.next='BACK' },

	{ .id='info' },
	{kMIPick, STR_STORY,			.id='intr',	.next='EXIT' },
	{kMIPick, STR_CREDITS,			.id='cred',	.next='EXIT' },
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	{ .id='bttl' },
	{kMIPick, STR_RACE1,			.id='rac1',	.next='EXIT' },
	{kMIPick, STR_RACE2,			.id='rac2',	.next='EXIT' },
	{kMIPick, STR_BATTLE1,			.id='bat1',	.next='EXIT' },
	{kMIPick, STR_BATTLE2,			.id='bat2',	.next='EXIT' },
	{kMIPick, STR_CAPTURE1,			.id='cap1',	.next='EXIT' },
	{kMIPick, STR_CAPTURE2,			.id='cap2',	.next='EXIT' },
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	{ .id=0 }
};

/*********************/
/*    VARIABLES      */
/*********************/

static Boolean	gPlayNow = false;

OGLPoint2D	gCursorCoord;						// screen coords based on 640x480 system



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
			RegisterFileScreen(FILESCREEN_MODE_LOAD);
		}

		while (0 == gMenuOutcome)
		{
			DoSDLMaintenance();
			CalcFramesPerSecond();
			MoveMainMenu();
			OGL_DrawScene(DrawObjects);
		}

		OGL_FadeOutScene(DrawObjects, NULL);
		FreeMainMenuScreen();

		ProcessMenuOutcome(gMenuOutcome);
	}
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


				/************/
				/* LOAD ART */
				/************/



			/* LOAD SPRITES */

	LoadSpriteAtlas(SPRITE_GROUP_FONT, "font", kAtlasLoadFont);





			/*****************/
			/* BUILD OBJECTS */
			/*****************/

	MakeBackgroundPictureObject(":images:menuback.jpg");
	MakeMouseCursorObject();
	MakeFadeEvent(true, 3.0);
}


/********************** FREE MAINMENU SCREEN **********************/

static void FreeMainMenuScreen(void)
{
	MyFlushEvents();
	DeleteAllObjects();
	DisposeAllSpriteGroups();
	DisposeSpriteAtlas(SPRITE_GROUP_FONT);
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
			DoIntroStoryScreen();
			break;

		case	'cred':										// CREDITS
			DisplayPicture(":images:credits.jpg");
			break;

		case	'demo':										// TIME DEMO (BENCHMARK)
			gTimeDemo = true;
			gNumPlayers = 1;
			gPlayNow = true;
			gPlayingFromSavedGame = false;
			SDL_GL_SetSwapInterval(0);						// no vsync for time demo
			break;

		case	'camp':										// SINGLE-PLAYER ADVENTURE CAMPAIGN
			gNumPlayers = 1;
			gPlayNow = true;
			gPlayingFromSavedGame = false;
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
			gNumPlayers = 2;
			gVSMode = VS_MODE_RACE;
			gLevelNum = LEVEL_NUM_RACE1;
			gPlayNow = true;
			gPlayingFromSavedGame = false;
			break;

		case	'rac2':										// RACE 2
			gNumPlayers = 2;
			gVSMode = VS_MODE_RACE;
			gLevelNum = LEVEL_NUM_RACE2;
			gPlayNow = true;
			gPlayingFromSavedGame = false;
			break;

		case	'bat1':										// BATTLE 1
			gNumPlayers = 2;
			gVSMode = VS_MODE_BATTLE;
			gLevelNum = LEVEL_NUM_BATTLE1;
			gPlayNow = true;
			gPlayingFromSavedGame = false;
			break;

		case	'bat2':										// BATTLE 2
			gNumPlayers = 2;
			gVSMode = VS_MODE_BATTLE;
			gLevelNum = LEVEL_NUM_BATTLE2;
			gPlayNow = true;
			gPlayingFromSavedGame = false;
			break;

		case	'cap1':										// CAPTURE THE FLAG 1
			gNumPlayers = 2;
			gVSMode = VS_MODE_CAPTURETHEFLAG;
			gLevelNum = LEVEL_NUM_FLAG1;
			gPlayNow = true;
			gPlayingFromSavedGame = false;
			break;

		case	'cap2':										// CAPTURE THE FLAG 2
			gNumPlayers = 2;
			gVSMode = VS_MODE_CAPTURETHEFLAG;
			gLevelNum = LEVEL_NUM_FLAG2;
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
	extern OGLRect gLogicalRect;


			/*****************************/
			/* UPDATE CROSSHAIR POSITION */
			/*****************************/


	int mx, my;
	int ww, wh;
	SDL_GetMouseState(&mx, &my);
	SDL_GetWindowSize(gSDLWindow, &ww, &wh);

	float screenToPaneX = (gLogicalRect.right - gLogicalRect.left) / (float)ww;
	float screenToPaneY = (gLogicalRect.bottom - gLogicalRect.top) / (float)wh;

	theNode->Coord.x = (float)mx * screenToPaneX + gLogicalRect.left;
	theNode->Coord.y = (float)my * screenToPaneY + gLogicalRect.top;

	gCursorCoord.x = theNode->Coord.x;
	gCursorCoord.y = theNode->Coord.x;

	UpdateObjectTransforms(theNode);


	SetObjectVisible(theNode, !gUserPrefersGamepad);
}

/********************* MAKE MOUSE CURSOR OBJECT *********************/

ObjNode* MakeMouseCursorObject(void)
{
	if (gNumSpritesInGroupList[SPRITE_GROUP_CURSOR] == 0)
	{
		LoadSpriteGroupFromFiles(SPRITE_GROUP_CURSOR, 1, (const char*[]) {":sprites:cursor.png"}, 0);
	}

	NewObjectDefinitionType def =
	{
		.group		= SPRITE_GROUP_CURSOR,
		.type		= CURSOR_SObjType_ArrowCursor,
		.coord		= {0,0,0},
		.flags		= STATUS_BIT_MOVEINPAUSE,
		.slot		= CURSOR_SLOT,			// make sure this is the last sprite drawn
		.moveCall	= MoveMouseCursorObject,
		.rot		= 0,
		.scale		= CURSOR_SCALE,
	};

	ObjNode* cursor = MakeSpriteObject(&def, false);
	cursor->AnaglyphZ = MENU_TEXT_ANAGLYPH_Z + .5f;

	return cursor;
}
