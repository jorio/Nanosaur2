/****************************/
/*    NANOSAUR 2 - MAIN 	*/
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

static void CleanupLevel(void);
static void PlayGame_Adventure(void);
static void PlayGame_Versus(void);
static void InitLevel(void);
static void PlayLevel(void);
static void DrawLevelCallback(OGLSetupOutputType *setupInfo);
static void MoveTimeDemoOnSpline(ObjNode *theNode);
static void ShowTimeDemoResults(int numFrames, float numSeconds, float averageFPS);


/****************************/
/*    CONSTANTS             */
/****************************/


#define kDefaultNibFileName "Game"

#define	MINUTES_PER_LEVEL	20.0f


/****************************/
/*    VARIABLES             */
/****************************/

short	gPrefsFolderVRefNum;
long	gPrefsFolderDirID;

Byte				gDebugMode = 0;				// 0 == none, 1 = fps, 2 = all

uint32_t				gAutoFadeStatusBits;

OGLSetupOutputType		*gGameViewInfoPtr = nil;

PrefsType			gGamePrefs;

Boolean				gTimeDemo = false;
uint32_t			gTimeDemoStartTime, gTimeDemoEndTime;



OGLVector3D			gWorldSunDirection;		// also serves as lense flare vector
OGLColorRGBA		gFillColor1 = { .8, .8, .7, 1};

uint32_t				gGameFrameNum = 0;
float				gGameLevelTimer = 0;

Boolean				gPlayingFromSavedGame 	= false;
Boolean				gGameOver 				= false;
Boolean				gLevelCompleted 		= false;
float				gLevelCompletedCoolDownTimer = 0;

short				gLevelNum;
short				gVSMode = VS_MODE_NONE;						// nano vs. nano mode

float				gRaceReadySetGoTimer;

			/* CHECKPOINTS */

short				gBestCheckpointNum[MAX_PLAYERS];
OGLPoint3D			gBestCheckpointCoord[MAX_PLAYERS];
float				gBestCheckpointAim[MAX_PLAYERS];

int					gScratch = 0;
float				gScratchF = 0;


			/* LEVEL SONGS */

const short gLevelSongs[] =
{
	SONG_LEVEL1,				// ADVENTURE LEVEL 1
	SONG_LEVEL2,				// ADVENTURE LEVEL 2
	SONG_LEVEL3,				// ADVENTURE LEVEL 3

	SONG_LEVEL3,				// RACE 1
	SONG_LEVEL2,				// RACE 2
	SONG_LEVEL1,				// BATTLE 1
	SONG_LEVEL2,				// BATTLE 2
	SONG_LEVEL3,				// CAPTURE THE FLAG 1
	SONG_LEVEL1,				// CAPTURE THE FLAG 2
};




//======================================================================================
//======================================================================================
//======================================================================================


/****************** TOOLBOX INIT  *****************/

void ToolBoxInit(void)
{
OSErr		iErr;
long		createdDirID;


	MyFlushEvents();


			/*****************/
			/* INIT NIB INFO */
			/*****************/

#if 0
	gBundle = CFBundleGetMainBundle();
	CreateNibReferenceWithCFBundle(gBundle, CFSTR(kDefaultNibFileName), &gNibs);
#endif



			/* CHECK PREFERENCES FOLDER */

	iErr = FindFolder(kOnSystemDisk,kPreferencesFolderType,kDontCreateFolder,			// locate the folder
					&gPrefsFolderVRefNum,&gPrefsFolderDirID);
	if (iErr != noErr)
		DoAlert("Warning: Cannot locate the Preferences folder.");

	iErr = DirCreate(gPrefsFolderVRefNum,gPrefsFolderDirID,"Nanosaur2",&createdDirID);		// make folder in there


			/* MAKE FSSPEC FOR DATA FOLDER */

#if 0
	SetDefaultDirectory();							// be sure to get the default directory

	iErr = FSMakeFSSpec(0, 0, "::Resources:Data:Images", &gDataSpec);
	if (iErr)
	{
		DoAlert("The game's data appears to be missing.  You should reinstall the game.");
		ExitToShell();
	}
#endif


		/* FIRST VERIFY SYSTEM BEFORE GOING TOO FAR */

	VerifySystem();
 	InitInput();							// note:  we must init our default HID settings before we try to read the saved Prefs!


			/********************/
			/* INIT PREFERENCES */
			/********************/

	InitDefaultPrefs();
	LoadPrefs(&gGamePrefs);



			/* BOOT OGL */

	OGL_Boot();


			/* START QUICKTIME */

#if 0
	EnterMovies();
#endif

			/*********************************/
			/* DO BOOT CHECK FOR SCREEN MODE */
			/*********************************/

//	DoAnaglyphCalibrationDialog	();	//---------

	DoScreenModeDialog();

	MyFlushEvents();
}


/************************* INIT DEFAULT PREFS **************************/

void InitDefaultPrefs(void)
{
int			i;
long 		keyboardScript, languageCode;

		/* DETERMINE WHAT LANGUAGE IS ON THIS MACHINE */

#if 0
	keyboardScript = GetScriptManagerVariable(smKeyScript);
	languageCode = GetScriptVariable(keyboardScript, smScriptLang);
#endif
	SOFTIMPME;
	languageCode = LANGUAGE_ENGLISH;

	switch(languageCode)
	{
		case	langFrench:
				gGamePrefs.language 			= LANGUAGE_FRENCH;
				break;

		case	langGerman:
				gGamePrefs.language 			= LANGUAGE_GERMAN;
				break;

		case	langSpanish:
				gGamePrefs.language 			= LANGUAGE_SPANISH;
				break;

		case	langItalian:
				gGamePrefs.language 			= LANGUAGE_ITALIAN;
				break;

		case	langSwedish:
				gGamePrefs.language 			= LANGUAGE_SWEDISH;
				break;

		case	langDutch:
				gGamePrefs.language 			= LANGUAGE_DUTCH;
				break;

		default:
				gGamePrefs.language 			= LANGUAGE_ENGLISH;
	}

	gGamePrefs.version				= CURRENT_PREFS_VERS;
	gGamePrefs.showScreenModeDialog = true;
	gGamePrefs.depth				= 32;
	gGamePrefs.screenWidth			= 1024;
	gGamePrefs.screenHeight			= 768;
	gGamePrefs.lowRenderQuality		= false;
	gGamePrefs.hasConfiguredISpControls = false;
	gGamePrefs.splitScreenMode		= SPLITSCREEN_MODE_VERT;
	gGamePrefs.stereoGlassesMode	= STEREO_GLASSES_MODE_OFF;
	gGamePrefs.anaglyphColor		= true;
	gGamePrefs.anaglyphCalibrationRed = DEFAULT_ANAGLYPH_R;
	gGamePrefs.anaglyphCalibrationGreen = DEFAULT_ANAGLYPH_G;
	gGamePrefs.anaglyphCalibrationBlue = DEFAULT_ANAGLYPH_B;
	gGamePrefs.doAnaglyphChannelBalancing = true;

	gGamePrefs.showTargetingCrosshairs	= true;
	gGamePrefs.kiddieMode				= false;
	gGamePrefs.dontUseHID				= true;

	gGamePrefs.reserved[0] 			= 0;
	gGamePrefs.reserved[1] 			= 0;
	gGamePrefs.reserved[2] 			= 0;
	gGamePrefs.reserved[3] 			= 0;
	gGamePrefs.reserved[4] 			= 0;
	gGamePrefs.reserved[5] 			= 0;
	gGamePrefs.reserved[6] 			= 0;
	gGamePrefs.reserved[7] 			= 0;
}


#pragma mark -


/*********************** PLAY GAME ADVENTURE **************************/
//
// Play the multi-level adventure mode
//

static void PlayGame_Adventure(void)
{



			/* GAME INITIALIZATION */

	InitPlayerInfo_Game();					// init player info for entire game


			/*********************************/
			/* PLAY THRU LEVELS SEQUENTIALLY */
			/*********************************/

	if (!gPlayingFromSavedGame)				// start on Level 0 if not loading from saved game
	{
		gLevelNum = LEVEL_NUM_ADVENTURE1;

		if (GetKeyState(KEY_F10))		// see if do Level cheat
			if (DoLevelCheatDialog())
				CleanQuit();
	}

	if (gTimeDemo)
	{
		gLevelNum = LEVEL_NUM_ADVENTURE3;
	}


	GammaFadeOut();

	for (;gLevelNum <= LEVEL_NUM_ADVENTURE3; gLevelNum++)
	{
				/* DO LEVEL INTRO */

		PlaySong(gLevelSongs[gLevelNum], true);

		if (!gTimeDemo)
		{
			if ((gLevelNum == 0) || gPlayingFromSavedGame)
				DoLevelIntroScreen(INTRO_MODE_NOSAVE);
			else
				DoLevelIntroScreen(INTRO_MODE_SAVEGAME);
		}

		MyFlushEvents();


	        /* LOAD ALL OF THE ART & STUFF */

		InitLevel();


			/***********/
	        /* PLAY IT */
	        /***********/

		PlayLevel();

		gPlayingFromSavedGame = false;		// once we've completed a level after restoring, we're not really playing from a saved game anymore


			/* CLEANUP LEVEL */

		MyFlushEvents();
		GammaFadeOut();
		CleanupLevel();

			/***************/
			/* SEE IF LOST */
			/***************/

		if (gGameOver)									// bail out if game has ended
		{
//			DoLoseScreen();
			break;
		}


		/* DO END-LEVEL BONUS SCREEN */

		if (gLevelNum == LEVEL_NUM_ADVENTURE3)				// if just won game then do win screen first!
			DoWinScreen();

	}


	gPlayingFromSavedGame = false;
}


/*********************** PLAY GAME: VERSUS **************************/
//
// Play one of the 2-player versus modes.
//

static void PlayGame_Versus(void)
{

			/* GAME INITIALIZATION */

	InitPlayerInfo_Game();														// init player info for entire game
	GammaFadeOut();

			/* DO LEVEL INTRO */

	PlaySong(gLevelSongs[gLevelNum], true);

	MyFlushEvents();


        /* LOAD ALL OF THE ART & STUFF */

	InitLevel();


		/***********/
        /* PLAY IT */
        /***********/

	PlayLevel();


		/* CLEANUP LEVEL */

	MyFlushEvents();
	GammaFadeOut();
	CleanupLevel();
}


#pragma mark -

/***************** INIT LEVEL ************************/
//
// Sets up the OpenGL draw context and loads all the data files
// for the level we're about to play.
//

static void InitLevel(void)
{
short				i;
OGLSetupInputType	viewDef;


	if (gTimeDemo)					// if time demo always reset random seed
		SetMyRandomSeed(0);



		/*********************/
		/* INIT COMMON STUFF */
		/*********************/

	gGameFrameNum 		= 0;
	gGameLevelTimer 	= 0;
	gGameOver 			= false;
	gLevelCompleted 	= false;


	for (i = 0; i < gNumPlayers; i++)
	{
		gBestCheckpointNum[i]	= -1;
		gPlayerInfo[i].objNode = nil;
	}


			/*************/
			/* MAKE VIEW */
			/*************/

	SetTerrainScale(DEFAULT_TERRAIN_SCALE);								// set scale to some default for now


			/* SETUP VIEW DEF */

	OGL_NewViewDef(&viewDef);

	viewDef.camera.hither 			= 20;
	if (gVSMode == VS_MODE_NONE)										// set FOV differently for multiplayer
		viewDef.camera.fov 				= 1.15;
	else
	{
		if (gGamePrefs.splitScreenMode == SPLITSCREEN_MODE_HORIZ)			// smaller FOV for wide panes
			viewDef.camera.fov 				= HORIZ_PANE_FOV;
		else
			viewDef.camera.fov 				= VERT_PANE_FOV;
	}

	viewDef.view.clearBackBuffer	= false;	//true;
	viewDef.camera.yon 				= (gSuperTileActiveRange * SUPERTILE_SIZE * gTerrainPolygonSize) * .95f;

	switch(gLevelNum)
	{
		case	LEVEL_NUM_ADVENTURE2:
		case	LEVEL_NUM_RACE2:
		case	LEVEL_NUM_BATTLE2:
				viewDef.view.clearColor.r 		= .968;
				viewDef.view.clearColor.g 		= .537;
				viewDef.view.clearColor.b		= .278;
				viewDef.styles.useFog			= true;
				viewDef.styles.fogStart			= viewDef.camera.yon * .4f;
				viewDef.styles.fogEnd			= viewDef.camera.yon * .95f;
				viewDef.lights.ambientColor.r 		= .45;
				viewDef.lights.ambientColor.g 		= .45;
				viewDef.lights.ambientColor.b 		= .45;
				gWorldSunDirection.x = .4;
				gWorldSunDirection.y = -.3;
				gWorldSunDirection.z = .2;
				gFillColor1.r = .6;
				gFillColor1.g = .6;
				gFillColor1.b = .6;
				gDrawLensFlare = true;
				break;

		case	LEVEL_NUM_ADVENTURE3:
		case	LEVEL_NUM_RACE1:
		case	LEVEL_NUM_FLAG1:
				viewDef.view.clearColor.r 		= .568;
				viewDef.view.clearColor.g 		= .243;
				viewDef.view.clearColor.b		= .125;
				viewDef.styles.useFog			= true;
				viewDef.styles.fogStart			= viewDef.camera.yon * .4f;
				viewDef.styles.fogEnd			= viewDef.camera.yon * .95f;
				viewDef.lights.ambientColor.r 		= .45;
				viewDef.lights.ambientColor.g 		= .45;
				viewDef.lights.ambientColor.b 		= .45;
				gWorldSunDirection.x = .4;
				gWorldSunDirection.y = -.3;
				gWorldSunDirection.z = .2;
				gFillColor1.r = .6;
				gFillColor1.g = .6;
				gFillColor1.b = .6;
				gDrawLensFlare = true;
				break;

		default:
				viewDef.view.clearColor.r 		= .43;
				viewDef.view.clearColor.g 		= .33;
				viewDef.view.clearColor.b		= .7;
				viewDef.styles.useFog			= true;
				viewDef.styles.fogStart			= viewDef.camera.yon * .35f;
				viewDef.styles.fogEnd			= viewDef.camera.yon * .95f;
				viewDef.lights.ambientColor.r 		= .4;
				viewDef.lights.ambientColor.g 		= .4;
				viewDef.lights.ambientColor.b 		= .4;
				gWorldSunDirection.x = .4;
				gWorldSunDirection.y = -.5;
				gWorldSunDirection.z = .5;
				gFillColor1.r = .7;
				gFillColor1.g = .7;
				gFillColor1.b = .7;
				gDrawLensFlare = true;
				break;

	}


			/* SET LIGHTS */

	viewDef.lights.numFillLights 		= 1;
	OGLVector3D_Normalize(&gWorldSunDirection,&gWorldSunDirection);
	viewDef.lights.fillDirection[0] 	= gWorldSunDirection;
	viewDef.lights.fillColor[0] 		= gFillColor1;


			/*********************/
			/* SET ANAGLYPH INFO */
			/*********************/

	if (gGamePrefs.stereoGlassesMode != STEREO_GLASSES_MODE_OFF)
	{
		gAnaglyphFocallength	= 200.0f;
		gAnaglyphEyeSeparation 	= 35.0f;

		if (gGamePrefs.stereoGlassesMode == STEREO_GLASSES_MODE_ANAGLYPH)
		{
			if (!gGamePrefs.anaglyphColor)
			{
				viewDef.lights.ambientColor.r 		+= .1f;					// make a little brighter
				viewDef.lights.ambientColor.g 		+= .1f;
				viewDef.lights.ambientColor.b 		+= .1f;
			}
		}
	}


			/*********************/
			/* MAKE DRAW CONTEXT */
			/*********************/

	OGL_SetupWindow(&viewDef, &gGameViewInfoPtr);


			/**********************/
			/* SET AUTO-FADE INFO */
			/**********************/

	switch(gLevelNum)
	{
//		case	0:
//				gAutoFadeStartDist = 0;
//				break;

		default:
				gAutoFadeStartDist	= gGameViewInfoPtr->yon * .80;
				gAutoFadeEndDist	= gGameViewInfoPtr->yon * .9f;
	}

	gAutoFadeRange_Frac	= 1.0f / (gAutoFadeEndDist - gAutoFadeStartDist);

	if (gAutoFadeStartDist != 0.0f)
		gAutoFadeStatusBits = STATUS_BIT_AUTOFADE;
	else
		gAutoFadeStatusBits = 0;



			/**********************/
			/* LOAD ART & TERRAIN */
			/**********************/
			//
			// NOTE: only call this *after* draw context is created!
			//

	LoadLevelArt(gGameViewInfoPtr);
	InitInfobar(gGameViewInfoPtr);

			/* INIT OTHER MANAGERS */

	InitSplineManager();
	InitContrails();
	InitEnemyManager();
	InitEffects(gGameViewInfoPtr);
	InitSparkles();
	InitItemsManager();


			/****************/
			/* INIT SPECIAL */
			/****************/

			/* INIT LEVEL & MODE SPECIFICS */

	switch(gLevelNum)
	{
//		case	LEVEL_NUM_SIDEWALK:
//				InitSnakeStuff();
//				CountSquishBerries();
//				break;


	}

	switch(gVSMode)
	{
		case	VS_MODE_RACE:
				gRaceReadySetGoTimer = 3.0;
				break;
	}



		/* INIT THE PLAYER & RELATED STUFF */

	PrimeTerrainWater();						// NOTE:  must do this before items get added since some items may be on the water
	InitPlayerAtStartOfLevel();					// NOTE:  this will also cause the initial items in the start area to be created

	PrimeSplines();
	PrimeFences();

			/* INIT CAMERAS */

	for (i = 0; i < gNumPlayers; i++)
		InitCamera_Terrain(i);




	HideCursor();								// do this again to be sure!
	GammaFadeOut();

 }



/************************* PLAY LEVEL *******************************/

static void PlayLevel(void)
{
short	i;
float	fps;


			/* PREP STUFF */

	UpdateInput();
	CalcFramesPerSecond();
	CalcFramesPerSecond();

	if (gTimeDemo)
	{
		gTimeDemoStartTime = TickCount();
	}


		/******************/
		/* MAIN GAME LOOP */
		/******************/

	while(true)
	{
				/* MOVE OBJECTS & UPDATE TERRAIN & DRAW */

		UpdateInput();									// read local keys
		MoveEverything();
		DoPlayerTerrainUpdate();
		OGL_DrawScene(gGameViewInfoPtr,DrawLevelCallback);


			/*************************/
			/* UPDATE FPS AND TIMERS */
			/*************************/

		CalcFramesPerSecond();
		fps = gFramesPerSecondFrac;

		if (gGameFrameNum == 1)										// if that was 2nd frame, then create a fade event
			MakeFadeEvent(true, 1.0);

		gGameFrameNum++;
		gGameLevelTimer += fps;
		gDisableHiccupTimer = false;								// reenable this after the 1st frame


				/***************************/
				/* SEE IF RESET PLAYER NOW */
				/***************************/

		for (i = 0; i < gNumPlayers; i++)							// check all players
		{
			if (gPlayerIsDead[i])									// is this player dead?
			{
				float	oldTimer = gDeathTimer[i];
				gDeathTimer[i] -= fps;
				if (gDeathTimer[i] <= 0.0f)							// is it time to reincarnate player?
				{
					if (gNumPlayers == 1)							// if only 1 player, then do nice fade in/out for reincarnation
					{
						if (oldTimer > 0.0f)						// if just now crossed zero then start fade
							MakeFadeEvent(false, 4.0);
						else
						if (gGammaFadePercent <= 0.0f)				// once fully faded out reset player @ checkpoint
							ResetPlayerAtBestCheckpoint(i);
					}
					else
						ResetPlayerAtBestCheckpoint(i);				// multiple players, so just reset player now
				}
			}
		}


			/*****************/
			/* SEE IF PAUSED */
			/*****************/

		if (GetNewKeyState(KEY_ESC))								// do regular pause mode
			DoPaused();

#if 0
		if (GetNewKeyState(KEY_F15))								// do screen-saver-safe paused mode
		{
			glFinish();

			do
			{
				EventRecord	e;
				WaitNextEvent(everyEvent,&e, 0, 0);
				UpdateInput();
			}while(!GetNewKeyState(KEY_F15));

			CalcFramesPerSecond();
		}
#endif

				/* LEVEL CHEAT */

		if (GetKeyState(KEY_APPLE))								// see if skip level
			if (GetNewKeyState(KEY_F10))
				gLevelCompleted = true;



				/*****************************/
				/* SEE IF LEVEL IS COMPLETED */
				/*****************************/

		if (gGameOver)												// if we need immediate abort, then bail now
			break;

		if (gLevelCompleted)
		{
			gLevelCompletedCoolDownTimer -= fps;					// game is done, but wait for cool-down timer before bailing
			if (gLevelCompletedCoolDownTimer <= 0.0f)
				break;
		}
	}

	if (gTimeDemo)
	{
		uint32_t	ticks;
		float	seconds;

		gTimeDemoEndTime = TickCount();
		ticks = gTimeDemoEndTime - gTimeDemoStartTime;
		seconds = (float)ticks / 60.0f;

//		ShowSystemErr_NonFatal(seconds);
//		ShowSystemErr_NonFatal(gGameFrameNum / seconds);

		ShowTimeDemoResults(gGameFrameNum, seconds, (float)gGameFrameNum / seconds);


		ExitToShell();
	}

}

/************************* SHOW TIME DEMO RESULTS *******************************/

static void ShowTimeDemoResults(int numFrames, float numSeconds, float averageFPS)
{
	IMPME;
#if 0
ControlID 	idControl;
ControlRef 	control;
OSStatus		err;
char 		text[256];
EventHandlerUPP winEvtHandler;
EventHandlerRef	ref;
EventTypeSpec	list[] = {   { kEventClassWindow, kEventWindowClose },
                             { kEventClassWindow, kEventWindowDrawContent },
                             { kEventClassControl, kEventControlClick },
                             { kEventClassCommand,  kEventProcessCommand } };

    Enter2D();

				/* CREATE WINDOW FROM THE NIB */

    err = CreateWindowFromNib(gNibs, CFStringCreateWithCString(nil, "TimeDemo",
    						kCFStringEncodingMacRoman), &gDialogWindow);
	if (err)
		DoFatalAlert("ShowTimeDemoResults: CreateWindowFromNib failed!");

    winEvtHandler = NewEventHandlerUPP(ShowTimeDemoResults_EventHandler);
    InstallWindowEventHandler(gDialogWindow, winEvtHandler, GetEventTypeCount(list), list, 0, &ref);



		/* SET TEXTEDIT FIELDS */

	idControl.signature = 'fcnt';
	idControl.id 		= 0;
	GetControlByID(gDialogWindow, &idControl, &control);

	sprintf (text, "%3ld", numFrames);
	SetControlData (control, kControlNoPart, kControlStaticTextTextTag, strlen(text), text);
	Draw1Control (control);


	idControl.signature = 'time';
	idControl.id 		= 0;
	GetControlByID(gDialogWindow, &idControl, &control);

	sprintf (text, "%f", numSeconds);
	SetControlData (control, kControlNoPart, kControlStaticTextTextTag, strlen(text), text);
	Draw1Control (control);


	idControl.signature = 'afps';
	idControl.id 		= 0;
	GetControlByID(gDialogWindow, &idControl, &control);

	sprintf (text, "%f", averageFPS);
	SetControlData (control, kControlNoPart, kControlStaticTextTextTag, strlen(text), text);
	Draw1Control (control);



    ShowWindow(gDialogWindow);
    BringToFront(gDialogWindow);
	SelectWindow(gDialogWindow);

			/* START THE EVENT LOOP */

    RunAppModalLoopForWindow(gDialogWindow);
#endif
}


#if 0
static pascal OSStatus ShowTimeDemoResults_EventHandler(EventHandlerCallRef myHandler, EventRef event, void* userData)
{
#pragma unused (myHandler, userData)
OSStatus		result = eventNotHandledErr;
HICommand 		command;

	switch(GetEventKind(event))
	{

				/*******************/
				/* PROCESS COMMAND */
				/*******************/

		case	kEventProcessCommand:
				GetEventParameter (event, kEventParamDirectObject, kEventParamHICommand, NULL, sizeof(command), NULL, &command);
				switch(command.commandID)
				{
							/* "OK" BUTTON */

					case	'ok  ':
		                    QuitAppModalLoopForWindow(gDialogWindow);
							break;
				}
				break;
    }

    return (result);
}
#endif





/****************** DRAW LEVEL CALLBACK *********************/

static void DrawLevelCallback(OGLSetupOutputType *setupInfo)
{

	if (gGamePrefs.stereoGlassesMode != STEREO_GLASSES_MODE_OFF)
	{
		Byte	p = gCurrentSplitScreenPane;			// get the player # who's draw context is being drawn

			/* MAKE SURE ANAGLYPH SETTINGS ARE GOOD FOR THIS CAMERA MODE */

		switch(gCameraMode[p])
		{
			case	CAMERA_MODE_NORMAL:
					if (gGamePrefs.stereoGlassesMode == STEREO_GLASSES_MODE_SHUTTER)
					{
						gAnaglyphFocallength	= 280.0f;
						gAnaglyphEyeSeparation 	= 45.0f;
					}
					else
					{
						gAnaglyphFocallength	= 260.0f;
						gAnaglyphEyeSeparation 	= 35.0f;
					}
					break;

			case	CAMERA_MODE_FIRSTPERSON:
					gAnaglyphFocallength	= 300.0f;
					gAnaglyphEyeSeparation 	= 80.0f;
					break;

			case	CAMERA_MODE_ANAGLYPHCLOSE:
					gAnaglyphFocallength	= 700.0f;
					gAnaglyphEyeSeparation 	= 50.0f;
					break;
		}
	}

	DrawObjects(setupInfo);
}


/**************** CLEANUP LEVEL **********************/

static void CleanupLevel(void)
{
	FreeAllCustomSplines();
	StopAllEffectChannels();
 	EmptySplineObjectList();
	DeleteAllObjects();
	FreeAllSkeletonFiles(-1);
	DisposeTerrain();
	DeleteAllParticleGroups();
	DeleteAllConfettiGroups();
	DisposeInfobar();
	DisposeParticleSystem();
	DisposeAllSpriteGroups();
	DisposeAllBG3DContainers();
	DisposeContrails();

	OGL_DisposeWindowSetup(&gGameViewInfoPtr);	// do this last!


		/* SET SOME IMPORTANT GLOBALS BACK TO DEFAULTS */

	gVSMode = VS_MODE_NONE;
	gNumPlayers = 1;
}

#pragma mark -


/******************** MOVE EVERYTHING ************************/

void MoveEverything(void)
{
	MoveObjects();
	MoveSplineObjects();
	UpdateCameras();								// update camera
	UpdateFences();
	UpdateDustDevilUVAnimation();

		/***********************/
		/* MODE-SPECIFIC STUFF */
		/***********************/

	switch(gVSMode)
	{
			/* ADVENTURE MODE */

		case	VS_MODE_NONE:
				break;

			/* RACE MODE */

		case	VS_MODE_RACE:
				gRaceReadySetGoTimer -= gFramesPerSecondFrac;
				CalcPlayerPlaces();									// determinw who is in what place
				break;


	}


}


/***************** START LEVEL COMPLETION ****************/

void StartLevelCompletion(float coolDownTimer)
{
	if (!gLevelCompleted)
	{
		gLevelCompleted = true;
		gLevelCompletedCoolDownTimer = coolDownTimer;
	}
}


#pragma mark -

/******************* PRIME TIME DEMO SPLINE *************************/
//
//
//

Boolean PrimeTimeDemoSpline(long splineNum, SplineItemType *itemPtr)
{
ObjNode			*newObj;
float			x,z,placement;


	if (!gTimeDemo)												// are we in time demo mode?
		return(false);


			/* GET SPLINE INFO */

	placement = itemPtr->placement;
	GetCoordOnSpline(&gSplineList[splineNum], placement, &x, &z);


				/* MAKE DUMMY SPLINE TRACKER OBJECT */

	gNewObjectDefinition.genre		= CUSTOM_GENRE;
	gNewObjectDefinition.slot 		= 0;
	gNewObjectDefinition.moveCall 	= nil;
	gNewObjectDefinition.flags 		= 0;

	newObj = MakeNewObject(&gNewObjectDefinition);


				/* SET SPLINE INFO */

	newObj->StatusBits		|= STATUS_BIT_ONSPLINE;
	newObj->SplineItemPtr 	= itemPtr;
	newObj->SplineNum 		= splineNum;
	newObj->SplinePlacement = placement;
	newObj->SplineMoveCall 	= MoveTimeDemoOnSpline;					// set move call

			/* ADD SPLINE OBJECT TO SPLINE OBJECT LIST */

	DetachObject(newObj, true);										// detach this object from the linked list
	AddToSplineObjectList(newObj, true);

	return(true);
}


/******************* MOVE TIME DEMO ON SPLINE ***********************/

static void MoveTimeDemoOnSpline(ObjNode *theNode)
{
OGLVector3D	v;
float	r;
OGLMatrix4x4	m;
ObjNode	*player = gPlayerInfo[0].objNode;

		/* MOVE ALONG THE SPLINE */

	if (IncreaseSplineIndex(theNode, 450))
		gGameOver = true;

	GetObjectCoordOnSpline(theNode);

	theNode->OldCoord.y = theNode->Coord.y = GetTerrainY(theNode->Coord.x, theNode->Coord.z) + 600.0f;

	v.x = theNode->Coord.x - theNode->OldCoord.x;				// calc aim vector
	v.y = theNode->Coord.y - theNode->OldCoord.y;
	v.z = theNode->Coord.z - theNode->OldCoord.z;
	OGLVector3D_Normalize(&v, &v);

//	from.x = theNode->Coord.x - (v.x * 500.0f);
//	from.y = theNode->Coord.y - (v.y * 500.0f);
//	from.z = theNode->Coord.z - (v.z * 500.0f);


			/* AIM ALONG SPLINE */

	OGL_UpdateCameraFromToUp(gGameViewInfoPtr, &theNode->OldCoord, &theNode->Coord, &gUp, 0);


	gPlayerInfo[0].camera.cameraLocation = theNode->Coord;
	gPlayerInfo[0].coord = theNode->Coord;				// update player coord
	player->Coord =  theNode->Coord;
	player->MotionVector = v;
	r= player->Rot.y = CalcYAngleFromPointToPoint(0, theNode->OldCoord.x, theNode->OldCoord.z,
															theNode->Coord.x, theNode->Coord.z);

	OGLMatrix4x4_SetTranslate(&player->BaseTransformMatrix, theNode->Coord.x, theNode->Coord.y, theNode->Coord.z);
	OGLMatrix4x4_SetRotate_Y(&m, r);
	OGLMatrix4x4_Multiply(&m, &player->BaseTransformMatrix, &player->BaseTransformMatrix);

	theNode->OldCoord = theNode->Coord;			// remember coord also

	if ((MyRandomLong() & 0xff) < 15)
	{
		gPlayerInfo[0].currentWeapon = RandomRange(WEAPON_TYPE_BLASTER, WEAPON_TYPE_BOMB);
		gPlayerInfo[0].weaponQuantity[gPlayerInfo[0].currentWeapon] = 999;
		PlayerFireButtonPressed(player, true);



	}


}



#pragma mark -

/************************************************************/
/******************** PROGRAM MAIN ENTRY  *******************/
/************************************************************/


int GameMain(void)
{
unsigned long	someLong;


				/**************/
				/* BOOT STUFF */
				/**************/

	ToolBoxInit();



			/* INIT SOME OF MY STUFF */

	InitSpriteManager();
	InitBG3DManager();
	InitWindowStuff();
	InitTerrainManager();
	InitSkeletonManager();
	InitSoundTools();


			/* INIT MORE MY STUFF */

	InitObjectManager();

	GetDateTime ((unsigned long *)(&someLong));		// init random seed
	SetMyRandomSeed(someLong);
	HideCursor();


		/* SHOW TITLES */

	DoLegalScreen();

	DoIntroStoryScreen();



		/*************/
		/* MAIN LOOP */
		/*************/

	while(true)
	{
		gTimeDemo = false;

			/* DO MAIN MENU */

		MyFlushEvents();
		DoMainMenuScreen();

			/* PLAY ADVENTURE OR VS. MODE */

		if (gVSMode == VS_MODE_NONE)
			PlayGame_Adventure();
		else
			PlayGame_Versus();
	}

}
