/****************************/
/*   	MAINMENU SCREEN.C	*/
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
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
static void BuildMainMenu(int menuLevel);
static void DrawMainMenuCallback(void);
static void DrawCredits(void);
static void DoMenuControls(void);
static void MoveMenuItem(ObjNode *theNode);

static void CalcGameCursorCoord(void);
static float CalcMenuTopY(long numLines);


/****************************/
/*    CONSTANTS             */
/****************************/

#define	FONT_SCALE	35.0f

#define	SCREENSAVER_DELAY	15.0f

#define	MAX_MENU_ITEMS	20

#define	MENU_TEXT_ANAGLYPH_Z	4.0f

enum
{
	MENU_PAGE_MAIN,
	MENU_PAGE_PLAY,
	MENU_PAGE_INFO,
	MENU_PAGE_BATTLE
};

#define	LINE_SPACING	(FONT_SCALE * 1.1f)

/*********************/
/*    VARIABLES      */
/*********************/

static	Boolean	gShowScores = false, gShowCredits = false;
Boolean	gPlayNow = false;

static	float	gInactivityTimer;

ObjNode		*gMenuCursorObj;
OGLPoint2D	gCursorCoord;						// screen coords based on 640x480 system

static	int		gMenuMode ;
short	gCurrentMenuItem = -1, gOldMenuItem;

ObjNode	*gMenuItems[MAX_MENU_ITEMS];
float	gMenuItemMinX[MAX_MENU_ITEMS];
float	gMenuItemMaxX[MAX_MENU_ITEMS];

static	float	gScreensaverTimer;

static	Boolean	gDoIntroStory;
static	Boolean	gDoCredits;


/********************** DO MAINMENU SCREEN **************************/

void DoMainMenuScreen(void)
{
Boolean	doScreenSaver;

again:
	if (gCurrentSong != SONG_THEME)
		PlaySong(SONG_THEME, true);


			/* SETUP */

	SetupMainMenuScreen();

	gScreensaverTimer = SCREENSAVER_DELAY;
	doScreenSaver = false;
	gDoIntroStory = false;
	gDoCredits = false;

			/*************/
			/* MAIN LOOP */
			/*************/

	CalcFramesPerSecond();
	DoSDLMaintenance();

	while(!gPlayNow)
	{
		const float fps = gFramesPerSecondFrac;

		CalcFramesPerSecond();
		DoSDLMaintenance();

			/* ONLY DO MENU STUFF IF IS FRONT WINDOW */

		if (!gPlayFullScreen)									// only are if in window mode
			if (!WeAreFrontProcess())
				continue;

				/* MOVE */

		gCurrentMenuItem = -1;									// assume nothing selected
		MoveObjects();
		gOldMenuItem = gCurrentMenuItem;


				/* DRAW */

		OGL_DrawScene(DrawMainMenuCallback);

				/* DO USER INPUT */

		DoMenuControls();


			/* SEE IF DO SCREENSAVER */

		gScreensaverTimer -= fps;
		if (gScreensaverTimer <= 0.0f)
		{
			doScreenSaver = true;
			break;
		}
	}




			/***********/
			/* CLEANUP */
			/***********/

	OGL_FadeOutScene(DrawMainMenuCallback, NULL);
	FreeMainMenuScreen();


			/* DO SCREENSAVER */

	if (doScreenSaver)
	{
		DoLevelIntroScreen(INTRO_MODE_SCREENSAVER);
		goto again;
	}

			/* DO INTRO STORY */
	else
	if (gDoIntroStory)
	{
		DoIntroStoryScreen();
		goto again;
	}

			/* DO CREDITS */
	else
	if (gDoCredits)
	{
		DisplayPicture(":images:credits");
		goto again;
	}
}



/********************* SETUP MAINMENU SCREEN **********************/

static void SetupMainMenuScreen(void)
{
FSSpec				spec;
OGLSetupInputType	viewDef;
static const OGLVector3D	fillDirection1 = { -.7, .9, -1.0 };
static const OGLVector3D	fillDirection2 = { .3, .8, 1.0 };
int					i;

	gPlayNow 		= false;
	gInactivityTimer = 0;
	gCurrentMenuItem = -1;
	gShowScores 	= false;
	gShowCredits 	= false;


	for (i = 0; i < MAX_MENU_ITEMS; i++)
		gMenuItems[i] = nil;


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

	LoadSpriteGroup(SPRITE_GROUP_MAINMENU, ":sprites:mainmenu.sprites", 0);
	LoadSpriteGroup(SPRITE_GROUP_FONT, ":sprites:font.sprites", 0);


			/* CREATE BACKGROUND OBJECT */

	gBackgoundPicture = MO_CreateNewObjectOfType(MO_TYPE_PICTURE, 0, ":images:menuback.jpg");



			/*****************/
			/* BUILD OBJECTS */
			/*****************/

			/* CURSOR */

	gNewObjectDefinition.group 		= SPRITE_GROUP_FONT;
	gNewObjectDefinition.type 		= FONT_SObjType_ArrowCursor;
	gNewObjectDefinition.coord.x 	= 0;
	gNewObjectDefinition.coord.y 	= 0;
	gNewObjectDefinition.coord.z 	= 0;
	gNewObjectDefinition.flags 		= 0;
	gNewObjectDefinition.slot 		= SPRITE_SLOT+5;			// make sure this is the last sprite drawn
	gNewObjectDefinition.moveCall 	= MoveCursor;
	gNewObjectDefinition.rot 		= 0;
	gNewObjectDefinition.scale 	    = CURSOR_SCALE;
	gMenuCursorObj = MakeSpriteObject(&gNewObjectDefinition, false);

	gMenuCursorObj->AnaglyphZ = MENU_TEXT_ANAGLYPH_Z + .5f;




			/* BUILD MAIN MENU */

	BuildMainMenu(MENU_PAGE_MAIN);


	MakeFadeEvent(true, 3.0);
}


/********************* BUILD MAIN MENU ***************************/

static void BuildMainMenu(int menuLevel)
{
ObjNode		*newObj;
int			i;
float		y,w;
int			language;
	gMenuMode = menuLevel;

			/* DELETE EXISTING MENU DATA */

	for (i = 0; i < MAX_MENU_ITEMS; i++)
	{
		if (gMenuItems[i])
		{
			DeleteObject(gMenuItems[i]);
			gMenuItems[i] = nil;
		}
	}


	language = gGamePrefs.language;


	switch(menuLevel)
	{
				/*************/
				/* MAIN MENU */
				/*************/

		case	MENU_PAGE_MAIN:
				y = CalcMenuTopY(4);
				for (i = 0; i < 4; i++)
				{
					static const LocStrID nameIDs[4] = {STR_PLAY_GAME, STR_SETTINGS, STR_INFO, STR_QUIT};
					const char* name = Localize(nameIDs[i]);

					gNewObjectDefinition.coord.x 	= 640/2;
					gNewObjectDefinition.coord.y 	= y;
					gNewObjectDefinition.coord.z 	= 0;
					gNewObjectDefinition.flags 		= 0;
					gNewObjectDefinition.moveCall 	= MoveMenuItem;
					gNewObjectDefinition.rot 		= 0;
					gNewObjectDefinition.scale 	    = FONT_SCALE;
					gNewObjectDefinition.slot 		= SPRITE_SLOT;
					gMenuItems[i] = newObj = MakeFontStringObject(name, &gNewObjectDefinition, true);
					w = GetStringWidth(name, gNewObjectDefinition.scale);
					gMenuItemMinX[i] = gNewObjectDefinition.coord.x - (w/2);
					gMenuItemMaxX[i] = gMenuItemMinX[i] + w;

					newObj->AnaglyphZ = MENU_TEXT_ANAGLYPH_Z;
					newObj->Kind = i;


					y += LINE_SPACING;
				}
				break;


				/*************/
				/* PLAY MENU */
				/*************/

		case	MENU_PAGE_PLAY:
				y = CalcMenuTopY(4);
				for (i = 0; i < 4; i++)
				{
					static const LocStrID nameIDs[4] = {STR_ADVENTURE, STR_NANO_VS_NANO, STR_SAVED_GAMES, STR_BACK_SYMBOL};
					const char* name = Localize(nameIDs[i]);

					gNewObjectDefinition.coord.x 	= 640/2;
					gNewObjectDefinition.coord.y 	= y;
					gNewObjectDefinition.coord.z 	= 0;
					gNewObjectDefinition.flags 		= 0;
					gNewObjectDefinition.moveCall 	= MoveMenuItem;
					gNewObjectDefinition.rot 		= 0;
					gNewObjectDefinition.scale 	    = FONT_SCALE;
					gNewObjectDefinition.slot 		= SPRITE_SLOT;
					gMenuItems[i] = newObj = MakeFontStringObject(name, &gNewObjectDefinition, true);
					w = GetStringWidth(name, gNewObjectDefinition.scale);
					gMenuItemMinX[i] = gNewObjectDefinition.coord.x - (w/2);
					gMenuItemMaxX[i] = gMenuItemMinX[i] + w;

					newObj->AnaglyphZ = MENU_TEXT_ANAGLYPH_Z;
					newObj->Kind = i;

					y += LINE_SPACING;
				}
				break;

				/*************/
				/* INFO MENU */
				/*************/

		case	MENU_PAGE_INFO:
				y = CalcMenuTopY(5);
				for (i = 0; i < 5; i++)
				{
					static const LocStrID nameIDs[5] = {STR_STORY, STR_CREDITS, STR_PANGEA_WEBSITE, STR_3D_GLASSES, STR_BACK_SYMBOL};
					const char* name = Localize(nameIDs[i]);

					gNewObjectDefinition.coord.x 	= 640/2;
					gNewObjectDefinition.coord.y 	= y;
					gNewObjectDefinition.coord.z 	= 0;
					gNewObjectDefinition.flags 		= 0;
					gNewObjectDefinition.moveCall 	= MoveMenuItem;
					gNewObjectDefinition.rot 		= 0;
					gNewObjectDefinition.scale 	    = FONT_SCALE;
					gNewObjectDefinition.slot 		= SPRITE_SLOT;
					gMenuItems[i] = newObj = MakeFontStringObject(name, &gNewObjectDefinition, true);
					w = GetStringWidth(name, gNewObjectDefinition.scale);
					gMenuItemMinX[i] = gNewObjectDefinition.coord.x - (w/2);
					gMenuItemMaxX[i] = gMenuItemMinX[i] + w;

					newObj->AnaglyphZ = MENU_TEXT_ANAGLYPH_Z;
					newObj->Kind = i;

					y += LINE_SPACING;
				}
				break;

				/***************/
				/* BATTLE MENU */
				/***************/

		case	MENU_PAGE_BATTLE:
				y = CalcMenuTopY(7);
				for (i = 0; i < 7; i++)
				{
					static const LocStrID nameIDs[7] = {STR_RACE1, STR_RACE2, STR_BATTLE1, STR_BATTLE2, STR_CAPTURE1, STR_CAPTURE2, STR_BACK_SYMBOL};
					const char* name = Localize(nameIDs[i]);

					gNewObjectDefinition.coord.x 	= 640/2;
					gNewObjectDefinition.coord.y 	= y;
					gNewObjectDefinition.coord.z 	= 0;
					gNewObjectDefinition.flags 		= 0;
					gNewObjectDefinition.moveCall 	= MoveMenuItem;
					gNewObjectDefinition.rot 		= 0;
					gNewObjectDefinition.scale 	    = FONT_SCALE;
					gNewObjectDefinition.slot 		= SPRITE_SLOT;
					gMenuItems[i] = newObj = MakeFontStringObject(name, &gNewObjectDefinition, true);
					w = GetStringWidth(name, gNewObjectDefinition.scale);
					gMenuItemMinX[i] = gNewObjectDefinition.coord.x - (w/2);
					gMenuItemMaxX[i] = gMenuItemMinX[i] + w;

					newObj->AnaglyphZ = MENU_TEXT_ANAGLYPH_Z;
					newObj->Kind = i;

					y += LINE_SPACING;
				}
				break;
	}
}


/********************** CALC MENU TOP Y ************************/
//
// We try to center the menu in the window since there's no good way to
// hard-wire it.  Different screen size ratios will cause issues with hard-wired alignment.
//

static float CalcMenuTopY(long numLines)
{
//float	centerY = 640.0f * gGameViewInfoPtr->windowAspectRatio  * .5f;
float	centerY = 700.0f * gGameViewInfoPtr->windowAspectRatio  * .5f;
float	y;

	y = centerY - (float)numLines * .5f * LINE_SPACING;
	y += FONT_SCALE * .5f;													// characters are centered, so offset y by half a char height

	y += 40.0f;												// this offset just moves it down, out of the way of the header/titling

	return(y);
}




/********************** FREE MAINMENU SCREEN **********************/

static void FreeMainMenuScreen(void)
{
	MyFlushEvents();
	DeleteAllObjects();
	if (gBackgoundPicture)
	{
		MO_DisposeObjectReference(gBackgoundPicture);
		gBackgoundPicture = nil;
	}
	DisposeAllSpriteGroups();
	DisposeAllBG3DContainers();
	OGL_DisposeGameView();
}


#pragma mark -



/*********************** DO MENU CONTROLS ***********************/

static void DoMenuControls(void)
{
	if (IsKeyDown(SDL_SCANCODE_T))					// activate time demo?
	{
		gTimeDemo = true;
		gNumPlayers = 1;
		gPlayNow = true;
		gPlayingFromSavedGame = false;
		return;
	}

			/* BACK UP? */

	if (IsNeedDown(kNeed_UIBack, ANY_PLAYER) && gMenuMode != MENU_PAGE_MAIN)
	{
		BuildMainMenu(MENU_PAGE_MAIN);
		return;
	}


	if (!IsClickDown(SDL_BUTTON_LEFT))				// did the user click?
		return;


			/* SEE WHAT WAS SELECTED */

	if (gCurrentMenuItem != -1)
	{
		PlayEffect_Parms(EFFECT_MENUSELECT, FULL_CHANNEL_VOLUME/3, FULL_CHANNEL_VOLUME/5, NORMAL_CHANNEL_RATE);
		switch(gMenuMode)
		{
			case	MENU_PAGE_MAIN:
					switch(gCurrentMenuItem)
					{
						case	0:							// PLAY GAME
								BuildMainMenu(MENU_PAGE_PLAY);
								break;

						case	1:							// SETTINGS
								DoGameOptionsDialog();
								BuildMainMenu(gMenuMode);	// rebuild menu in case language changed
								break;

						case	2:							// INFO
								BuildMainMenu(MENU_PAGE_INFO);
								break;

						case	3:							// EXIT
								CleanQuit();
								break;
					}
					break;


			case	MENU_PAGE_PLAY:
					switch(gCurrentMenuItem)
					{
						case	0:							// START NEW GAME
								gNumPlayers = 1;
								gPlayNow = true;
								gPlayingFromSavedGame = false;
								break;

						case	1:							// NANO VS. NANO
								BuildMainMenu(MENU_PAGE_BATTLE);
								break;

						case	2:							// CONTINUE GAME
								if (LoadSavedGame())
								{
									gPlayingFromSavedGame = true;
									gNumPlayers = 1;
									gPlayNow = true;
								}
								break;

						case	3:							// BACK
								BuildMainMenu(MENU_PAGE_MAIN);
								break;


					}
					break;


			case	MENU_PAGE_INFO:
					switch(gCurrentMenuItem)
					{
						case	0:							// STORY
								gDoIntroStory = true;
								gPlayNow = true;
								break;

						case	1:							// CREDITS
								gDoCredits = true;
								gPlayNow = true;
								break;

						case	2:
								SOFTIMPME;
#if 0
							if (LaunchURL("http://www.pangeasoft.net/nano2") == noErr)	// PANGEA WEB SITE
								{
									if (gPlayFullScreen)
					                   ExitToShell();
				             	}
#endif
								break;

						case	3:
								SOFTIMPME;
#if 0
								if (LaunchURL("http://www.pangeasoft.net/nano2/3dglasses.html") == noErr)	// 3D GLASSES
								{
									if (gPlayFullScreen)
					                   ExitToShell();
				             	}
#endif
								break;

						case	4:							// BACK
								BuildMainMenu(MENU_PAGE_MAIN);
								break;
					}
					break;

			case	MENU_PAGE_BATTLE:
					switch(gCurrentMenuItem)
					{
						case	0:										// RACE 1
								gNumPlayers = 2;
								gVSMode = VS_MODE_RACE;
								gLevelNum = LEVEL_NUM_RACE1;
								gPlayNow = true;
								gPlayingFromSavedGame = false;
								break;

						case	1:										// RACE 2
								gNumPlayers = 2;
								gVSMode = VS_MODE_RACE;
								gLevelNum = LEVEL_NUM_RACE2;
								gPlayNow = true;
								gPlayingFromSavedGame = false;
								break;

						case	2:										// BATTLE 1
								gNumPlayers = 2;
								gVSMode = VS_MODE_BATTLE;
								gLevelNum = LEVEL_NUM_BATTLE1;
								gPlayNow = true;
								gPlayingFromSavedGame = false;
								break;

						case	3:										// BATTLE 2
								gNumPlayers = 2;
								gVSMode = VS_MODE_BATTLE;
								gLevelNum = LEVEL_NUM_BATTLE2;
								gPlayNow = true;
								gPlayingFromSavedGame = false;
								break;

						case	4:										// CAPTURE THE FLAG 1
								gNumPlayers = 2;
								gVSMode = VS_MODE_CAPTURETHEFLAG;
								gLevelNum = LEVEL_NUM_FLAG1;
								gPlayNow = true;
								gPlayingFromSavedGame = false;
								break;

						case	5:										// CAPTURE THE FLAG 2
								gNumPlayers = 2;
								gVSMode = VS_MODE_CAPTURETHEFLAG;
								gLevelNum = LEVEL_NUM_FLAG2;
								gPlayNow = true;
								gPlayingFromSavedGame = false;
								break;

						case	6:										// BACK
								gVSMode = VS_MODE_NONE;
								BuildMainMenu(MENU_PAGE_MAIN);
								break;
					}

		}
	}
}



/***************** DRAW MAINMENU CALLBACK *******************/

static void DrawMainMenuCallback(void)
{
	if (gBackgoundPicture)
		MO_DrawObject(gBackgoundPicture);

	DrawObjects();

	if (gShowCredits)
		DrawCredits();
}



/****************** DRAW CREDITS ***********************/

static void DrawCredits(void)
{
			/* SET STATE */

	OGL_PushState();

	SetInfobarSpriteState(4);


			/* DRAW CREDITS */

	DrawInfobarSprite2_Centered(640/2, 480/2, 400, SPRITE_GROUP_MAINMENU, MAINMENU_SObjType_Credits);


	OGL_PopState();
}



#pragma mark -

/********************* MOVE CURSOR *********************/
//
// NOTE:  this function is called from other places which need the cursor, not just the main menu
//

void MoveCursor(ObjNode *theNode)
{
	CalcGameCursorCoord();

	theNode->Coord.x = gCursorCoord.x;
	theNode->Coord.y = gCursorCoord.y;

	UpdateObjectTransforms(theNode);

}


/*************** MOVE MENU ITEM ***********************/

static void MoveMenuItem(ObjNode *theNode)
{
float	d;
int		i = theNode->Kind;
float	x,y;

	if (gShowScores || gShowCredits)
	{
		gCurrentMenuItem = -1;
		return;
	}

			/* IS THE CURSOR OVER THIS ITEM? */

	x = gMenuCursorObj->Coord.x;						// get tip of cursor coords
	y = gMenuCursorObj->Coord.y;


	if ((x >= gMenuItemMinX[i]) && (x < gMenuItemMaxX[i]))
	{
		d = fabs(y - theNode->Coord.y);
		if (d < (FONT_SCALE/2))
		{
			theNode->ColorFilter.r =
			theNode->ColorFilter.g =
			theNode->ColorFilter.b = 1.0;
			gCurrentMenuItem = theNode->Kind;

			if (gCurrentMenuItem != gOldMenuItem)			// change?
			{
				gScreensaverTimer = SCREENSAVER_DELAY;
				PlayEffect_Parms(EFFECT_CHANGESELECT, FULL_CHANNEL_VOLUME/5, FULL_CHANNEL_VOLUME/3, NORMAL_CHANNEL_RATE);
			}
			return;
		}
	}
			/* CURSOR NOT ON THIS */

	theNode->ColorFilter.r = .7;
	theNode->ColorFilter.g =
	theNode->ColorFilter.b = .6;
}


#pragma mark -



/********************* CALC GAME CURSOR COORD *****************************/

static void CalcGameCursorCoord(void)
{
float	bottom = 640.0f * gCurrentPaneAspectRatio;

			/*****************************/
			/* UPDATE CROSSHAIR POSITION */
			/*****************************/


	int mx, my;
	int ww, wh;
	SDL_GetMouseState(&mx, &my);
	SDL_GetWindowSize(gSDLWindow, &ww, &wh);

	gCursorCoord.x = ((float)mx / (float)ww) * 640.0f;
	gCursorCoord.y = ((float)my / (float)wh) * bottom;

#if 0
	if (gCursorCoord.x < 0.0f)										// keep in bounds (for multiple monitor systems)
		gCursorCoord.x = 0.0f;
	else
	if (gCursorCoord.x > 640.0f)
		gCursorCoord.x = 640.0f;

	if (gCursorCoord.y < 0.0f)
		gCursorCoord.y = 0.0f;
	else
	if (gCursorCoord.y > bottom)
		gCursorCoord.y = bottom;
#endif
}

