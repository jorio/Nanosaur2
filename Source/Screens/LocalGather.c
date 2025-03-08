/****************************/
/* LOCAL GATHER.C           */
/* (C) 2022 Iliyas Jorio    */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/

#include "game.h"
#include "uieffects.h"


/****************************/
/*    PROTOTYPES            */
/****************************/

static void SetupLocalGatherScreen(void);
static int DoLocalGatherControls(void);



/****************************/
/*    CONSTANTS             */
/****************************/

/*********************/
/*    VARIABLES      */
/*********************/

static ObjNode* gGatherPrompt = NULL;
static int gNumControllersMissing = 4;




static void UpdateGatherPrompt(int numControllersMissing)
{
	if (numControllersMissing <= 0)
	{
		TextMesh_Update("OK", 0, gGatherPrompt);
		gGatherPrompt->Scale.x = 1;
		gGatherPrompt->Scale.y = 1;
		UpdateObjectTransforms(gGatherPrompt);
//		gGameViewInfoPtr->fadeOutDuration = .3f;
	}
	else
	{
		const char* message;
		if (numControllersMissing == 1)
			message = Localize(STR_CONNECT_1_CONTROLLER);
		else
			message = Localize(STR_CONNECT_2_CONTROLLERS);

		TextMesh_Update(message, 0, gGatherPrompt);
	}

}




/********************** DO GATHER SCREEN **************************/
//
// Return true if user aborts.
//

Boolean DoLocalGatherScreen(void)
{
	gNumControllersMissing = gNumPlayers;
//	UnlockPlayerControllerMapping();

	if (GetNumGamepad() >= gNumPlayers)
	{
		// Skip gather screen if we already have enough controllers
		return false;
	}

	SetupLocalGatherScreen();
	MakeFadeEvent(kFadeFlags_In, 3);


	/*************/
	/* MAIN LOOP */
	/*************/

	CalcFramesPerSecond();
	DoSDLMaintenance(); //ReadKeyboard();

	int outcome = 0;

	while (outcome == 0)
	{
		/* SEE IF MAKE SELECTION */

		outcome = DoLocalGatherControls();


		int numControllers = GetNumGamepad();

		gNumControllersMissing = gNumPlayers - numControllers;
		if (gNumControllersMissing < 0)
			gNumControllersMissing = 0;

		UpdateGatherPrompt(gNumControllersMissing);


		/**************/
		/* DRAW STUFF */
		/**************/

		CalcFramesPerSecond();
		DoSDLMaintenance(); //ReadKeyboard();
		MoveObjects();
		OGL_DrawScene(DrawObjects);
	}

	/* SHOW 'OK!' */

	if (outcome >= 0)
	{
		UpdateGatherPrompt(0);
	}


	/***********/
	/* CLEANUP */
	/***********/

	OGL_FadeOutScene(DrawObjects, MoveObjects);

	DeleteAllObjects();
	FreeAllSkeletonFiles(-1);
	DisposeAllBG3DContainers();
	OGL_DisposeGameView();


	/* SET CHARACTER TYPE SELECTED */

	return (outcome < 0);
}


/********************* SETUP LOCAL GATHER SCREEN **********************/

static void SetupLocalGatherScreen(void)
{
	OGLSetupInputType	viewDef;
	OGLColorRGBA		ambientColor = { .5, .5, .5, 1 };
	OGLColorRGBA		fillColor1 = { 1.0, 1.0, 1.0, 1 };
	OGLVector3D			fillDirection1 = { .9, -.3, -1 };

	/**************/
	/* SETUP VIEW */
	/**************/

	OGL_NewViewDef(&viewDef);

	viewDef.camera.fov 				= .3;
	viewDef.camera.hither 			= 10;
	viewDef.camera.yon 				= 3000;
	viewDef.camera.from[0].z		= 700;

	viewDef.view.clearColor 		= (OGLColorRGBA) { 0, 0, 0, 1 };
	viewDef.styles.useFog			= false;
//	viewDef.view.pillarboxRatio		= PILLARBOX_RATIO_4_3;

	viewDef.lights.ambientColor 	= ambientColor;
	viewDef.lights.numFillLights 	= 1;
	viewDef.lights.fillDirection[0] = fillDirection1;
	viewDef.lights.fillColor[0] 	= fillColor1;

//	viewDef.view.fontName			= "rockfont";

	OGL_SetupGameView(&viewDef);



	/************/
	/* LOAD ART */
	/************/

	/* MAKE BACKGROUND PICTURE OBJECT */

//	MakeBackgroundPictureObject(":images:CharSelectScreen.jpg");
//	MakeScrollingBackgroundPattern();


	/*****************/
	/* BUILD OBJECTS */
	/*****************/

	NewObjectDefinitionType def2 =
			{
					.scale = 0.4f,
					.coord = {640/2, 480/2, 0},
					.slot = SPRITE_SLOT,
					.group = ATLAS_GROUP_FONT2
			};

	gGatherPrompt = TextMesh_NewEmpty(256, &def2);
	SendNodeToOverlayPane(gGatherPrompt);

	def2.coord.y = 480/2 + 220;
	def2.scale = 0.27f;
	ObjNode* pressEsc = TextMesh_New(Localize(STR_PRESS_ESC_TO_GO_BACK), 0, &def2);
	SendNodeToOverlayPane(pressEsc);
	pressEsc->ColorFilter = (OGLColorRGBA) {.5, .5, .5, 1};
	MakeTwitch(pressEsc, kTwitchPreset_PressKeyPrompt);
}



/***************** DO CHARACTERSELECT CONTROLS *******************/

static int DoLocalGatherControls(void)
{
	if (gNumControllersMissing == 0)
		return 1;

	if (IsNeedDown(kNeed_UIBack, ANY_PLAYER))
	{
		return -1;
	}

	/* SEE IF SELECT THIS ONE */

	if (IsKeyDown(SDL_SCANCODE_RETURN) || IsKeyDown(SDL_SCANCODE_KP_ENTER))
	{
		// User pressed [ENTER] on keyboard
		if (gNumControllersMissing == 1)
		{
			PlayEffect_Parms(EFFECT_MENUSELECT, FULL_CHANNEL_VOLUME, FULL_CHANNEL_VOLUME, NORMAL_CHANNEL_RATE * 2/3);
			return 1;
		}
		else
		{
			PlayEffect_Parms(EFFECT_BADSELECT, FULL_CHANNEL_VOLUME/4, FULL_CHANNEL_VOLUME/4, NORMAL_CHANNEL_RATE);
			MakeTwitch(gGatherPrompt, kTwitchPreset_PadlockWiggle);
		}
	}
	else if (IsNeedDown(kNeed_UIConfirm, ANY_PLAYER))
	{
		// User pressed [A] on gamepad
		if (gNumControllersMissing > 0)
		{
			PlayEffect_Parms(EFFECT_BADSELECT, FULL_CHANNEL_VOLUME/4, FULL_CHANNEL_VOLUME/4, NORMAL_CHANNEL_RATE);
			MakeTwitch(gGatherPrompt, kTwitchPreset_PadlockWiggle);
		}
	}
	else if (IsCheatKeyComboDown())		// useful to test local multiplayer without having all controllers plugged in
	{
		PlayEffect(EFFECT_CRYSTALSHATTER);
		return 1;
	}

	return 0;
}


