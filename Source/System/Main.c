/****************************/
/*    NANOSAUR 2 - MAIN 	*/
/* By Brian Greenstone      */
/* (c)2003 Pangea Software  */
/* (c)2022 Iliyas Jorio     */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/

#include "game.h"
#include "uieffects.h"

/****************************/
/*    PROTOTYPES            */
/****************************/

static void CleanupLevel(void);
static void PlayGame_Adventure(void);
static void PlayGame_Versus(void);
static void InitLevel(void);
static void PlayLevel(void);
static void DrawLevelCallback(void);
static void MoveTimeDemoOnSpline(ObjNode *theNode);
static void ShowTimeDemoResults(int numFrames, float numSeconds, float averageFPS);


/****************************/
/*    CONSTANTS             */
/****************************/


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
Boolean				gSkipLevelIntro			= false;

short				gLevelNum;
short				gVSMode = VS_MODE_NONE;						// nano vs. nano mode

float				gRaceReadySetGoTimer;

			/* CHECKPOINTS */

short				gBestCheckpointNum[MAX_PLAYERS];
OGLPoint3D			gBestCheckpointCoord[MAX_PLAYERS];
float				gBestCheckpointAim[MAX_PLAYERS];


			/* LEVEL SONGS */

const short gLevelSongs[NUM_LEVELS] =
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
	MyFlushEvents();

		/* FIRST VERIFY SYSTEM BEFORE GOING TOO FAR */

	VerifySystem();
	InitInput();

			/********************/
			/* INIT PREFERENCES */
			/********************/

	InitPrefsFolder(false);
	InitDefaultPrefs();
	LoadPrefs();

	SetFullscreenMode(true);



			/* BOOT OGL */

	OGL_Boot();
}


/************************* INIT DEFAULT PREFS **************************/

void InitDefaultPrefs(void)
{
	SDL_memset(&gGamePrefs, 0, sizeof(gGamePrefs));

		/* DETERMINE WHAT LANGUAGE IS ON THIS MACHINE */

	gGamePrefs.fullscreen				= true;
	gGamePrefs.vsync					= true;

	gGamePrefs.language				= GetBestLanguageIDFromSystemLocale();
	gGamePrefs.cutsceneSubtitles	= !IsNativeEnglishSystem();		// enable subtitles if user's native language isn't English

	gGamePrefs.lowRenderQuality		= false;
	gGamePrefs.splitScreenMode		= SPLITSCREEN_MODE_VERT;
	gGamePrefs.stereoGlassesMode	= STEREO_GLASSES_MODE_OFF;
	gGamePrefs.anaglyphCalibrationRed = DEFAULT_ANAGLYPH_R;
	gGamePrefs.anaglyphCalibrationGreen = DEFAULT_ANAGLYPH_G;
	gGamePrefs.anaglyphCalibrationBlue = DEFAULT_ANAGLYPH_B;
	gGamePrefs.doAnaglyphChannelBalancing = true;

	gGamePrefs.showTargetingCrosshairs	= true;
	gGamePrefs.kiddieMode				= false;

	gGamePrefs.force4x3HUD				= false;
	gGamePrefs.hudScale					= 100;

	gGamePrefs.mouseSensitivityLevel	= DEFAULT_MOUSE_SENSITIVITY_LEVEL;

	gGamePrefs.musicVolumePercent	= 70;
	gGamePrefs.sfxVolumePercent		= 70;

	gGamePrefs.rumbleIntensity		= 100;

	_Static_assert(sizeof(gGamePrefs.bindings) == sizeof(kDefaultInputBindings), "input binding size mismatch: prefs vs defaults");
	SDL_memcpy(&gGamePrefs.bindings, &kDefaultInputBindings, sizeof(kDefaultInputBindings));
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


	for (;gLevelNum <= LEVEL_NUM_ADVENTURE3; gLevelNum++)
	{
				/* DO LEVEL INTRO */

		PlaySong(gLevelSongs[gLevelNum], true);

		if (!gSkipLevelIntro)
		{
			if ((gLevelNum == 0) || gPlayingFromSavedGame)
				DoLevelIntroScreen(INTRO_MODE_NOSAVE);
			else
				DoLevelIntroScreen(INTRO_MODE_SAVEGAME);
		}
		gSkipLevelIntro = false;			// reset skip flag

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
//		GammaFadeOut();
		CleanupLevel();

			/***************/
			/* SEE IF LOST */
			/***************/

		if (gGameOver)									// bail out if game has ended
		{
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
//	GammaFadeOut();
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
	viewDef.camera.fov 				= GetSplitscreenPaneFOV();
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

	if (IsStereo())
	{
		gAnaglyphFocallength	= 200.0f;
		gAnaglyphEyeSeparation 	= 35.0f;

		if (IsStereoAnaglyphMono())
		{
			viewDef.lights.ambientColor.r 		+= .1f;					// make a little brighter
			viewDef.lights.ambientColor.g 		+= .1f;
			viewDef.lights.ambientColor.b 		+= .1f;
		}
	}


			/*********************/
			/* MAKE DRAW CONTEXT */
			/*********************/

	OGL_SetupGameView(&viewDef);


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

	LoadLevelArt();
	InitInfobar();

			/* INIT OTHER MANAGERS */

	InitSplineManager();
	InitContrails();
	InitEnemyManager();
	InitEffects();
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
 }



/************************* PLAY LEVEL *******************************/

static void PlayLevel(void)
{
float	fps;


			/* PREP STUFF */

	DoSDLMaintenance();
	CalcFramesPerSecond();
	CalcFramesPerSecond();

	MakeFadeEvent(kFadeFlags_In, 1.0);

	if (gTimeDemo)
	{
		gTimeDemoStartTime = TickCount();
	}


	GrabMouse(true);


		/******************/
		/* MAIN GAME LOOP */
		/******************/

	while(true)
	{
				/* INPUT */

		DoSDLMaintenance();


		if (gGamePaused)
		{
			MoveObjects();
			CalcFramesPerSecond();
			DoPlayerTerrainUpdate();
			OGL_DrawScene(DrawLevelCallback);
			continue;
		}


		for (int i = 0; i < gNumPlayers; i++)
			UpdatePlayerSteering(i);

				/* MOVE OBJECTS & UPDATE TERRAIN & DRAW */

		MoveEverything();
		DoPlayerTerrainUpdate();
		OGL_DrawScene(DrawLevelCallback);


			/*************************/
			/* UPDATE FPS AND TIMERS */
			/*************************/

		CalcFramesPerSecond();
		fps = gFramesPerSecondFrac;

		gGameFrameNum++;
		gGameLevelTimer += fps;
		gDisableHiccupTimer = false;								// reenable this after the 1st frame


				/***************************/
				/* SEE IF RESET PLAYER NOW */
				/***************************/

		for (int i = 0; i < gNumPlayers; i++)						// check all players
		{
			if (gPlayerIsDead[i])									// is this player dead?
			{
				float	oldTimer = gDeathTimer[i];
				gDeathTimer[i] -= fps;
				if (gDeathTimer[i] <= 0.0f)							// is it time to reincarnate player?
				{
					const float fadeOutSpeed = 4.0f;

					if (oldTimer > 0.0f)							// if just now crossed zero then start fade
					{
						if (gNumPlayers > 1
							|| gPlayerInfo[i].numFreeLives > 0)		// ...only if hasn't lost adventure mode yet (gameover will freeze-frame fadeout)
						{
							MakeFadeEvent(kFadeFlags_Out | (kFadeFlags_P1<<i), fadeOutSpeed);
						}
					}
					else if (gDeathTimer[i] < -(1.0f / fadeOutSpeed))	// once fully faded out reset player @ checkpoint
					{
						ResetPlayerAtBestCheckpoint(i);
					}
				}
			}
		}


			/*****************/
			/* SEE IF PAUSED */
			/*****************/

		if (IsNeedDown(kNeed_UIPause, ANY_PLAYER))					// do regular pause mode
		{
			DoPaused();
		}

#if __APPLE__
		if (IsCmdQDown())
		{
			DoReallyQuit();
		}
#endif

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

		if ((IsKeyActive(SDL_SCANCODE_LGUI) || IsKeyActive(SDL_SCANCODE_RGUI))
			&& IsKeyDown(SDL_SCANCODE_F10))								// see if skip level
		{
			gLevelCompleted = true;
//			gSkipLevelIntro = true;
		}



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

	GrabMouse(false);

	if (gGammaFadeFrac > 0)											// only fade out if we haven't called MakeFadeEvent(kFadeFlags_Out) already
	{
		gGameViewInfoPtr->fadeSound = true;
		OGL_FadeOutScene(DrawLevelCallback, DoPlayerTerrainUpdate);
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
	DoAlert("%s:\n"
			"Frames: %d\n"
			"Time: %f\n"
			"Average FPS: %f\n"
			"Peak #Objs: %d",
			__func__, numFrames, numSeconds, averageFPS, gNumObjectNodesPeak);
}


/****************** DRAW LEVEL CALLBACK *********************/

static void DrawLevelCallback(void)
{

	if (IsStereo())
	{
		Byte	p = gCurrentSplitScreenPane;			// get the player # who's draw context is being drawn

			/* MAKE SURE ANAGLYPH SETTINGS ARE GOOD FOR THIS CAMERA MODE */

		switch(gCameraMode[p])
		{
			case	CAMERA_MODE_NORMAL:
					if (IsStereoShutter())
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

	DrawObjects();
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
	DisposeSpriteGroup(SPRITE_GROUP_LEVELSPECIFIC);
	DisposeSpriteGroup(SPRITE_GROUP_OVERHEADMAP);
	DisposeAllBG3DContainers();
	DisposeContrails();
	FreeAllZaps();

	OGL_DisposeGameView();	// do this last!


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

	NewObjectDefinitionType def =
	{
		.genre		= CUSTOM_GENRE,
		.slot 		= 0,
		.moveCall 	= nil,
		.flags 		= 0,
		.scale		= 1,
	};

	newObj = MakeNewObject(&def);


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

	OGL_UpdateCameraFromToUp(&theNode->OldCoord, &theNode->Coord, &gUp, 0);


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


/****** LOAD/DISPOSE FONT USED THROUGHOUT THE GAME *****/

void LoadGlobalAssets(void)
{
	LoadSpriteAtlas(ATLAS_GROUP_FONT1, ":Sprites:fonts:font", kAtlasLoadFont | kAtlasLoadFontIsUpperCaseOnly);
	LoadSpriteAtlas(ATLAS_GROUP_FONT2, ":Sprites:fonts:font", kAtlasLoadFont | kAtlasLoadFontIsUpperCaseOnly | kAtlasLoadAltSkin1);
	LoadSpriteGroupFromFile(SPRITE_GROUP_CURSOR, ":Sprites:menu:cursor", 0);
	LoadSpriteGroupFromSeries(SPRITE_GROUP_INFOBAR,		INFOBAR_SObjType_COUNT,		"infobar");
	LoadSpriteGroupFromSeries(SPRITE_GROUP_GLOBAL,		GLOBAL_SObjType_COUNT,		"global");
	LoadSpriteGroupFromSeries(SPRITE_GROUP_SPHEREMAPS,	SPHEREMAP_SObjType_COUNT,	"spheremap");
	LoadSpriteGroupFromSeries(SPRITE_GROUP_PARTICLES,	PARTICLE_SObjType_COUNT,	"particle");
	BlendAllSpritesInGroup(SPRITE_GROUP_PARTICLES);
}

void DisposeGlobalAssets(void)
{
	DisposeSpriteAtlas(ATLAS_GROUP_FONT1);
	DisposeSpriteAtlas(ATLAS_GROUP_FONT2);
	DisposeSpriteGroup(SPRITE_GROUP_CURSOR);
	DisposeSpriteGroup(SPRITE_GROUP_INFOBAR);
	DisposeSpriteGroup(SPRITE_GROUP_GLOBAL);
	DisposeSpriteGroup(SPRITE_GROUP_SPHEREMAPS);
	DisposeSpriteGroup(SPRITE_GROUP_PARTICLES);
}


#pragma mark -


/************************************************************/
/******************** PROGRAM MAIN ENTRY  *******************/
/************************************************************/


void GameMain(void)
{
unsigned long	someLong;


				/**************/
				/* BOOT STUFF */
				/**************/

	ToolBoxInit();


#if !_DEBUG
	SDL_HideCursor();
#endif

	DoWarmUpScreen();



			/* INIT SOME OF MY STUFF */

	LoadLocalizedStrings(gGamePrefs.language);
	InitSpriteManager();
	InitBG3DManager();
	InitWindowStuff();
	InitTerrainManager();
	InitSkeletonManager();
	InitSoundTools();
	InitTwitchSystem();


			/* INIT MORE MY STUFF */

	InitObjectManager();

	GetDateTime ((unsigned long *)(&someLong));		// init random seed
	SetMyRandomSeed((uint32_t) someLong);


			/* PRELOAD SPRITES FOR ENTIRE GAME */

	LoadGlobalAssets();


#if !SKIPFLUFF
		/* SHOW TITLES */

	DoLegalScreen();

	DoIntroStoryScreen();
#endif


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
		{
			if (DoLocalGatherScreen())
			{
				gVSMode = VS_MODE_NONE;
				gNumPlayers = 1;
				continue;
			}
			PlayGame_Versus();
		}
	}

}
