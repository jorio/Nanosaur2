/****************************/
/*   	MISCSCREENS.C	    */
/* By Brian Greenstone      */
/* (c)2002 Pangea Software  */
/* (c)2022 Iliyas Jorio     */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/

#include "game.h"
#include "version.h"


/****************************/
/*    PROTOTYPES            */
/****************************/

static void DrawLoading_Callback(void);


/****************************/
/*    CONSTANTS             */
/****************************/



/*********************/
/*    VARIABLES      */
/*********************/

float		gLoadingThermoPercent = 0;


/******* DO PROGRAM WARM-UP SCREEN AS WE PRELOAD ASSETS **********/

void DoWarmUpScreen(void)
{
	OGLSetupInputType	viewDef;

			/* SETUP VIEW */

	OGL_NewViewDef(&viewDef);
	OGL_SetupGameView(&viewDef);

			/* SHOW IT */

	for (int i = 0; i < 8; i++)
	{
		OGL_DrawScene(DrawObjects);
		DoSDLMaintenance();
	}

			/* CLEANUP */

	DeleteAllObjects();

	OGL_DisposeGameView();
}


/************** DO LEGAL SCREEN *********************/

void DoLegalScreen(void)
{
	OGLSetupInputType	viewDef;
	float	timeout = 10.0f;

	gNumPlayers = 1;									// make sure don't do split-screen

			/* SETUP VIEW */

	OGL_NewViewDef(&viewDef);

	viewDef.camera.hither 			= 10;
	viewDef.camera.yon 				= 3000;
	viewDef.view.clearColor			= (OGLColorRGBA) {0,0,0,1};
	viewDef.styles.useFog			= false;

	OGL_SetupGameView(&viewDef);


			/* BUILD OBJECTS */

	LoadSpriteAtlas(ATLAS_GROUP_FONT3, ":Sprites:fonts:swiss", kAtlasLoadFont);

	NewObjectDefinitionType textDef =
	{
		.scale = 0.19f,
		.group = ATLAS_GROUP_FONT3,
		.coord = {320,240-120,0},
	};


	const char* legalStrings[] =
	{
		"Nanosaur II:  Hatchling",
		"\v" PROJECT_VERSION "\r",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"",
		"pangeasoft.net",
		"jorio.itch.io/nanosaur2",
		"\v\xc2\xa9 2004-2008 Pangea Software, Inc.  Nanosaur is a registered trademark of Pangea Software, Inc.\r",
		NULL
	};

	for (int i = 0; legalStrings[i]; i++)
	{
		if (legalStrings[i][0] != '\0')
		{
			ObjNode* textNode = TextMesh_New(legalStrings[i], 0, &textDef);
			textNode->ColorFilter = (OGLColorRGBA) {1,1,0,1};
		}

		textDef.coord.y += 20;
	}

	MakeFadeEvent(kFadeFlags_In, 2.0);

	DoSDLMaintenance();
	CalcFramesPerSecond();


			/* MAIN LOOP */

	while (1)
	{
		CalcFramesPerSecond();
		MoveObjects();
		OGL_DrawScene(DrawObjects);

		DoSDLMaintenance();
		if (UserWantsOut() || IsClickDown(SDL_BUTTON_LEFT))
			break;

		timeout -= gFramesPerSecondFrac;
		if (timeout < 0.0f)
			break;
	}


			/* FADE OUT */

	OGL_FadeOutScene(DrawObjects, NULL);


			/* CLEANUP */

	DeleteAllObjects();
	OGL_DisposeGameView();
}



#pragma mark -

/********************** DRAW LOADING *************************/

void DrawLoading(float percent)
{
	static bool shownYet = false;
	static uint64_t startTicks = 0;
	static uint64_t lastUpdateTicks = 0;

	// Prevent the OS from thinking our process has locked up
	DoSDLMaintenance();

#if SDL_VERSION_ATLEAST(2,0,18)
	uint64_t nowTicks = SDL_GetTicks64();
#else
	uint64_t nowTicks = SDL_GetTicks();
#endif

	if (percent == 0)
	{
		startTicks = nowTicks;
		lastUpdateTicks = 0;
		shownYet = false;
	}

	// Give illusion of instant loading (don't draw thermometer) if we can predict the level will be loaded in under a second
	if (!shownYet)
	{
		uint64_t ticksSinceStart = nowTicks - startTicks;
		if (ticksSinceStart < 200								// let loading warm up for 200 ms before considering whether to draw or not
			|| ticksSinceStart <= (uint64_t)(percent * 1000))	// don't draw as long as we're keeping up with the ideal loading time (1000 ms)
		{
			return;
		}
	}

	// Don't redraw too often or if percentage is out of bounds
	if (percent > 0
		&& percent < 1
		&& nowTicks - lastUpdateTicks < 16)
	{
		return;
	}

	shownYet = true;
	lastUpdateTicks = nowTicks;

	//if (percent > 0.75f)
	//{
	//	MakeFadeEvent(kFadeFlags_Out, 0.0001);
	//	gGammaFadeFrac = 1.0f - (percent - 0.75f) / 0.25f;
	//}

	// Kill vsync so we don't waste 16ms before loading the next asset
	int vsyncBackup = SDL_GL_GetSwapInterval();
	SDL_GL_SetSwapInterval(0);

	// Draw thermometer
	glClear(GL_COLOR_BUFFER_BIT);
	OGL_DrawScene(DrawLoading_Callback);
	gLoadingThermoPercent = percent;

	// Restore vsync setting
	SDL_GL_SetSwapInterval(vsyncBackup);
}




/***************** DRAW LOADING CALLBACK *******************/

#define	THERMO_WIDTH		80.0f
#define	THERMO_HEIGHT		4.0f
#define	THERMO_Y			180.0f
#define	THERMO_LEFT			(320 - (THERMO_WIDTH/2))
#define	THERMO_RIGHT		(320 + (THERMO_WIDTH/2))

static void DrawLoading_Callback(void)
{
float	w, x;

	if (gCurrentSplitScreenPane != 0)						// only show in player 1's pane
		return;

	SetInfobarSpriteState(0, 1);

	DrawInfobarSprite_Centered(640/2, THERMO_Y-6, 100, INFOBAR_SObjType_Loading);

			/* DRAW THERMO FRAME */

	OGL_SetColor4f(.5,.5,.5,1);
	OGL_DisableTexture2D();

	glBegin(GL_QUADS);
	glVertex2f(THERMO_LEFT,THERMO_Y);					glVertex2f(THERMO_RIGHT,THERMO_Y);
	glVertex2f(THERMO_RIGHT,THERMO_Y+THERMO_HEIGHT);		glVertex2f(THERMO_LEFT,THERMO_Y+THERMO_HEIGHT);
	glEnd();


			/* DRAW THERMO METER */

	w = gLoadingThermoPercent * THERMO_WIDTH;
	x = THERMO_LEFT + w;

	if (IsStereoAnaglyph())
		OGL_SetColor4f(.3,.3,.2,1);
	else
		OGL_SetColor4f(.8,0,0,1);

	glBegin(GL_QUADS);
	glVertex2f(THERMO_LEFT,THERMO_Y);		glVertex2f(x,THERMO_Y);
	glVertex2f(x,THERMO_Y+THERMO_HEIGHT);	glVertex2f(THERMO_LEFT,THERMO_Y+THERMO_HEIGHT);
	glEnd();


	OGL_SetColor4f(1,1,1,1);

	float fadeOpacity = 0;
	if (gLoadingThermoPercent < 0.1f)
	{
		fadeOpacity = 1.0f - (gLoadingThermoPercent / 0.1f);
	}
	else
	{
		float fadeoutStart = 0.9f;
		float fadeoutEnd = 1.0f;
		if (gLoadingThermoPercent > fadeoutStart)
		{
			fadeOpacity = (gLoadingThermoPercent - fadeoutStart) / (fadeoutEnd - fadeoutStart);
		}
	}

	{
		OGL_SetColor4f(0,0,0, fadeOpacity>1? 1: fadeOpacity);
		glBegin(GL_QUADS);
		glVertex2f(0,0);		glVertex2f(640,0);
		glVertex2f(640,480);	glVertex2f(0,480);
		glEnd();
	}
}

