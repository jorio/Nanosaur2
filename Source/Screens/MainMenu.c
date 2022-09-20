/****************************/
/*   	MAINMENU SCREEN.C	*/
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/

#include "3DMath.h"

extern	float				gFramesPerSecondFrac,gFramesPerSecond,gGlobalTransparency;
extern	FSSpec		gDataSpec;
extern	Boolean		gGameOver;
extern	NewObjectDefinitionType	gNewObjectDefinition;
extern	Boolean		gSongPlayingFlag, gPlayingFromSavedGame;
extern	PrefsType	gGamePrefs;
extern	OGLSetupOutputType		*gGameViewInfoPtr;
extern	SparkleType	gSparkles[MAX_SPARKLES];
extern	OGLPoint3D	gCoord;
extern	OGLPoint2D	gCursorCoord;
extern	OGLVector3D	gDelta;
extern	u_long			gGlobalMaterialFlags;
extern	float			gGammaFadePercent;
extern	OGLColorRGB			gGlobalColorFilter;
extern	MOPictureObject 	*gBackgoundPicture;
extern	int					gGameWindowWidth, gGameWindowHeight;
extern	Boolean				gGameIsRegistered, gPlayFullScreen, gMouseNewButtonState;
extern	short			gCurrentSong;
extern	WindowPtr		gGameWindow;
extern	GrafPtr			gGameWindowGrafPtr;

/****************************/
/*    PROTOTYPES            */
/****************************/

static void SetupMainMenuScreen(void);
static void FreeMainMenuScreen(void);
static void BuildMainMenu(int menuLevel);
static void DrawMainMenuCallback(OGLSetupOutputType *info);
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
	GammaFadeOut();

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
	UpdateInput();

	while(!gPlayNow)
	{
		const float fps = gFramesPerSecondFrac;

		CalcFramesPerSecond();
		UpdateInput();

			/* ONLY DO MENU STUFF IF IS FRONT WINDOW */

		if (!gPlayFullScreen)									// only are if in window mode
			if (!WeAreFrontProcess())
				continue;

				/* MOVE */

		gCurrentMenuItem = -1;									// assume nothing selected
		MoveObjects();
		gOldMenuItem = gCurrentMenuItem;


				/* DRAW */

		OGL_DrawScene(gGameViewInfoPtr, DrawMainMenuCallback);

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

	GammaFadeOut();
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
		FSSpec	spec;
		FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, "\p:images:Credits", &spec);
		DisplayPicture(&spec);
		goto again;
	}
}



/********************* SETUP MAINMENU SCREEN **********************/

static void SetupMainMenuScreen(void)
{
FSSpec				spec;
OGLSetupInputType	viewDef;
const static OGLVector3D	fillDirection1 = { -.7, .9, -1.0 };
const static OGLVector3D	fillDirection2 = { .3, .8, 1.0 };
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

	OGL_SetupWindow(&viewDef, &gGameViewInfoPtr);


	InitSparkles();


				/************/
				/* LOAD ART */
				/************/



			/* LOAD SPRITES */

	FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, "\p:sprites:mainmenu.sprites", &spec);
	LoadSpriteFile(&spec, SPRITE_GROUP_MAINMENU, gGameViewInfoPtr);

	FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, "\p:sprites:font.sprites", &spec);
	LoadSpriteFile(&spec, SPRITE_GROUP_FONT, gGameViewInfoPtr);


			/* CREATE BACKGROUND OBJECT */

	FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, "\p:images:menuback.jpg", &spec);
	gBackgoundPicture = MO_CreateNewObjectOfType(MO_TYPE_PICTURE, (u_long)gGameViewInfoPtr, &spec);



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
	gMenuCursorObj = MakeSpriteObject(&gNewObjectDefinition, gGameViewInfoPtr, false);

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
					static const Str31 names[MAX_LANGUAGES][4] =
					{
						{									// ENGLISH
							"\pPLAY GAME",
							"\pSETTINGS",
							"\pINFO",
							"\pQUIT",
						},

						{									// FRENCH
							"\pNOUVELLE PARTIE",
							"\pPRƒFƒRENCES",
							"\pINFOS",
							"\pQUITTER",
						},

						{									// GERMAN
							"\pSPIELEN",
							"\pEINSTELLUNGEN",
							"\pINFO",
							"\pBEENDEN",
						},

						{									// SPANISH
							"\pJUGAR",
							"\pPREFERENCIAS",
							"\pINFO",
							"\pSALIR",
						},

						{									// ITALIAN
							"\pGIOCA",
							"\pIMPOSTAZIONI",
							"\pINFO",
							"\pESCI",
						},

						{									// SWEDISH
							"\pSPELA",
							"\pINST€LLNINGAR",
							"\pINFORMATION",
							"\pAVSLUTA",
						},

						{									// DUTCH
							"\pSPEL SPELEN",
							"\pINSTELLINGEN",
							"\pINFO",
							"\pAFSLUITEN",
						},


					};

					gNewObjectDefinition.coord.x 	= 640/2;
					gNewObjectDefinition.coord.y 	= y;
					gNewObjectDefinition.coord.z 	= 0;
					gNewObjectDefinition.flags 		= 0;
					gNewObjectDefinition.moveCall 	= MoveMenuItem;
					gNewObjectDefinition.rot 		= 0;
					gNewObjectDefinition.scale 	    = FONT_SCALE;
					gNewObjectDefinition.slot 		= SPRITE_SLOT;
					gMenuItems[i] = newObj = MakeFontStringObject(names[language][i], &gNewObjectDefinition, gGameViewInfoPtr, true);
					w = GetStringWidth(names[language][i], gNewObjectDefinition.scale);
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
					static const Str31 names[MAX_LANGUAGES][4] =
					{
						{												// ENGLISH
							"\pADVENTURE",
							"\pNANO VS. NANO",
							"\pSAVED GAMES",
							"\p~",
						},

						{												// FRENCH
							"\pAVENTURE",
							"\pNANO CONTRE NANO",
							"\pPARTIES ENREGISTRƒES",
							"\p~",
						},

						{												// GERMAN
							"\pADVENTURE",
							"\pNANO VS. NANO",
							"\pSPIEL FORTSETZEN",
							"\p~",
						},

						{												// SPANISH
							"\pAVENTURA",
							"\pNANO CONTRA NANO",
							"\pCONTINUAR PARTIDA GUARDADA",
							"\p~",
						},

						{												// ITALIAN
							"\pAVVENTURA",
							"\pNANO VS. NANO",
							"\pPARTITE SALVATE",
							"\p~",
						},

						{												// SWEDISH
							"\pADVENTURE",
							"\pNANO VS. NANO",
							"\pLADDA SPARAT SPEL",
							"\p~",
						},

						{												// DUTCH
							"\pAVONTUUR",
							"\pNANO TEGEN NANO",
							"\pOPGESLAGEN SPELEN",
							"\p~",
						},
					};

					gNewObjectDefinition.coord.x 	= 640/2;
					gNewObjectDefinition.coord.y 	= y;
					gNewObjectDefinition.coord.z 	= 0;
					gNewObjectDefinition.flags 		= 0;
					gNewObjectDefinition.moveCall 	= MoveMenuItem;
					gNewObjectDefinition.rot 		= 0;
					gNewObjectDefinition.scale 	    = FONT_SCALE;
					gNewObjectDefinition.slot 		= SPRITE_SLOT;
					gMenuItems[i] = newObj = MakeFontStringObject(names[language][i], &gNewObjectDefinition, gGameViewInfoPtr, true);
					w = GetStringWidth(names[language][i], gNewObjectDefinition.scale);
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
					static const Str31 names[MAX_LANGUAGES][5] =
					{
						{														// ENGLISH
							"\pSTORY",
							"\pCREDITS",
							"\pPANGEA WEB SITE",
							"\p3D GLASSES",
							"\p~",
						},

						{														// FRENCH
							"\pL'UNIVERS",
							"\pCRƒDITS",
							"\pSITE WEB PANGEA",
							"\pLUNETTES 3D",
							"\p~",
						},

						{														// GERMAN
							"\pGESCHICHTE",
							"\pCREDITS",
							"\pPANGEA-WEBSEITE",
							"\p3D-BRILLE",
							"\p~",
						},

						{														// SPANISH
							"\pHISTORIA",
							"\pCRƒDITOS",
							"\pPAGINA WEB DE PANGEA",
							"\pGAFAS 3D",
							"\p~",
						},

						{														// ITALIAN
							"\pBAKGRUNDSHISTORIA",
							"\pTITOLI",
							"\pSITO DI PANGEA",
							"\pOCCHIALI 3D",
							"\p~",
						},

						{														// SWEDISH
							"\pSTORY",
							"\pVI SOM G…R NANOSAUR",
							"\pPANGEAS HEMSIDA",
							"\p3D-GLAS…GON",
							"\p~",
						},

						{														// DUTCH
							"\pGESCHIEDENIS",
							"\pCREDITS",
							"\pPANGEA-WEBSITE",
							"\p3D-BRIL",
							"\p~",
						},

					};

					gNewObjectDefinition.coord.x 	= 640/2;
					gNewObjectDefinition.coord.y 	= y;
					gNewObjectDefinition.coord.z 	= 0;
					gNewObjectDefinition.flags 		= 0;
					gNewObjectDefinition.moveCall 	= MoveMenuItem;
					gNewObjectDefinition.rot 		= 0;
					gNewObjectDefinition.scale 	    = FONT_SCALE;
					gNewObjectDefinition.slot 		= SPRITE_SLOT;
					gMenuItems[i] = newObj = MakeFontStringObject(names[language][i], &gNewObjectDefinition, gGameViewInfoPtr, true);
					w = GetStringWidth(names[language][i], gNewObjectDefinition.scale);
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
					static const Str31 names[MAX_LANGUAGES][7] =
					{
						{											// ENGLISH
							"\pRACE 1",
							"\pRACE 2",
							"\pBATTLE 1",
							"\pBATTLE 2",
							"\pCAPTURE THE EGGS 1",
							"\pCAPTURE THE EGGS 2",
							"\p~",
						},

						{											// FRENCH
							"\pCOURSE 1",
							"\pCOURSE 2",
							"\pCOMBAT 1",
							"\pCOMBAT 2",
							"\pPRISE DES OEUFS 1",
							"\pPRISE DES OEUFS 2",
							"\p~",
						},

						{											// GERMAN
							"\pRENNEN 1",
							"\pRENNEN 2",
							"\pKAMPF 1",
							"\pKAMPF 2",
							"\pEIER EROBERN 1",
							"\pEIER EROBERN 2",
							"\p~",
						},

						{											// SPANISH
							"\pCARRERA 1",
							"\pCARRERA 2",
							"\pBATALLA 1",
							"\pBATALLA 2",
							"\pCAPTURAR LOS HUEVOS 1",
							"\pCAPTURAR LOS HUEVOS 2",
							"\p~",
						},

						{											// ITALIAN
							"\pGARA 1",
							"\pGARA 2",
							"\pBATTAGLIA 1",
							"\pBATTAGLIA 2",
							"\pAFFERRA LE UOVA 1",
							"\pAFFERRA LE UOVA 2",
							"\p~",
						},

						{											// SWEDISH
							"\pT€VLING 1",
							"\pT€VLING 2",
							"\pTVEKAMP 1",
							"\pTVEKAMP 2",
							"\pFNGA €GGEN 1",
							"\pFNGA €GGEN 2",
							"\p~",
						},

						{											// DUTCH
							"\pRACE 1",
							"\pRACE 2",
							"\pSTRIJD 1",
							"\pSTRIJD 2",
							"\pDE EIEREN BEMACHTIGEN 1",
							"\pDE EIEREN BEMACHTIGEN 2",
							"\p~",
						},

					};

					gNewObjectDefinition.coord.x 	= 640/2;
					gNewObjectDefinition.coord.y 	= y;
					gNewObjectDefinition.coord.z 	= 0;
					gNewObjectDefinition.flags 		= 0;
					gNewObjectDefinition.moveCall 	= MoveMenuItem;
					gNewObjectDefinition.rot 		= 0;
					gNewObjectDefinition.scale 	    = FONT_SCALE;
					gNewObjectDefinition.slot 		= SPRITE_SLOT;
					gMenuItems[i] = newObj = MakeFontStringObject(names[language][i], &gNewObjectDefinition, gGameViewInfoPtr, true);
					w = GetStringWidth(names[language][i], gNewObjectDefinition.scale);
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
	OGL_DisposeWindowSetup(&gGameViewInfoPtr);
}


#pragma mark -



/*********************** DO MENU CONTROLS ***********************/

static void DoMenuControls(void)
{
	if (GetNewKeyState(KEY_T))					// activate time demo?
	{
		gTimeDemo = true;
		gNumPlayers = 1;
		gPlayNow = true;
		gPlayingFromSavedGame = false;
		return;
	}

			/* BACK UP? */

	if (GetNewKeyState(KEY_ESC))
	{
		if (gMenuMode != MENU_PAGE_MAIN)
		{
			BuildMainMenu(MENU_PAGE_MAIN);
			return;
		}
	}


	if (!gMouseNewButtonState)								// did the user click?
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
								if (LaunchURL("\phttp://www.pangeasoft.net/nano2") == noErr)	// PANGEA WEB SITE
								{
									if (gPlayFullScreen)
					                   ExitToShell();
				             	}
								break;

						case	3:
								if (LaunchURL("\phttp://www.pangeasoft.net/nano2/3dglasses.html") == noErr)	// 3D GLASSES
								{
									if (gPlayFullScreen)
					                   ExitToShell();
				             	}
								break;

						case	4:							// BACK
								BuildMainMenu(MENU_PAGE_MAIN);
								break;
					}
					break;

			case	MENU_PAGE_BATTLE:

#if !ALLOW_2P_INDEMO
					if ((!gGameIsRegistered) && (gCurrentMenuItem != 6))								// no multi-player in demo mode
					{
						DoAlert("\pNano vs. Nano games are not available in Demo mode.  You must purchase a Nanosaur 2 serial number to play these games.");
					}
#else
					if ((!gGameIsRegistered) && (gCurrentMenuItem != 1) && (gCurrentMenuItem != 3) && (gCurrentMenuItem != 6))			// allow race 2 and battle 2 in Apple's .Mac mode
					{
						DoAlert("\pOnly Race 2 and Battle 2 are available in demo mode.  You must purchase a Nanosaur 2 serial number to play all the games.");
					}
#endif
					else
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

static void DrawMainMenuCallback(OGLSetupOutputType *info)
{
	if (gBackgoundPicture)
		MO_DrawObject(gBackgoundPicture, info);

	DrawObjects(info);

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
Point	mousePt;
float	viewAspectRatio = gCurrentPaneAspectRatio;

float	bottom = 640.0f * viewAspectRatio;

			/*****************************/
			/* UPDATE CROSSHAIR POSITION */
			/*****************************/


	if (gPlayFullScreen)
	{
		GetMouse(&mousePt);

		gCursorCoord.x = ((float)mousePt.h / (float)gGameWindowWidth) * 640.0f;
		gCursorCoord.y = ((float)mousePt.v / (float)gGameWindowHeight) * bottom;

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
	}

				/************************/
				/* CALC FOR WINDOW MODE */
				/************************/
	else
	{
		GrafPtr	oldPort;
		Boolean	cursorOut;

			/* CALC WINDOW'S GLOBAL SCREEN COORD */

		GetPort(&oldPort);
		SetPort(gGameWindowGrafPtr);

		GetMouse(&mousePt);

		SetPort(oldPort);

				/* CALC CURSOR COORD IN THE WINDOW */

		gCursorCoord.x = ((float)mousePt.h / (float)gGameWindowWidth) * 640.0f;
		gCursorCoord.y = ((float)mousePt.v / (float)gGameWindowHeight) * bottom;


				/* SHOW CURSOR WHEN OUT OF WINDOW, HIDE WHEN IN */

		if (gCursorCoord.x < 0.0f)										// keep in bounds (for multiple monitor systems)
		{
			cursorOut = true;
		}
		else
		if (gCursorCoord.x > 640.0f)
		{
			cursorOut = true;
		}
		else
			cursorOut = false;

		if (gCursorCoord.y < 0.0f)
		{
			cursorOut = true;
		}
		else
		if (gCursorCoord.y > bottom)
		{
			cursorOut = true;
		}

//		if (cursorOut && (!gRealCursorVisible))
//			ShowRealCursor();
//		else
//		if ((!cursorOut) && gRealCursorVisible)
//			HideRealCursor();
	}




}







