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



/************** DO LEGAL SCREEN *********************/

void DoLegalScreen(void)
{
	OGLSetupInputType	viewDef;
	float	timeout = 40.0f;

	gNumPlayers = 1;									// make sure don't do split-screen

			/* SETUP VIEW */

	OGL_NewViewDef(&viewDef);

	viewDef.camera.hither 			= 10;
	viewDef.camera.yon 				= 3000;
	viewDef.view.clearColor			= (OGLColorRGBA) {0,0,0,1};
	viewDef.styles.useFog			= false;

	OGL_SetupGameView(&viewDef);


			/* BUILD OBJECTS */

	LoadSpriteAtlas(SPRITE_GROUP_FONT3, "subtitlefont", kAtlasLoadFont);		// TODO: hacky -- sprite groups & atlas numbers overlap

	NewObjectDefinitionType textDef =
	{
		.scale = 0.2f,
		.group = SPRITE_GROUP_FONT3,
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
		"www.pangeasoft.net",
		"jorio.itch.io/nanosaur2",
		"\v\u00A9 2004-2008 Pangea Software, Inc.  Nanosaur is a registered trademark of Pangea Software, Inc.\r",
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
	DisposeAllSpriteGroups();
	OGL_DisposeGameView();
}



#pragma mark -

#if 0
/********************** DO GAME SETTINGS DIALOG ************************/

void DoGameOptionsDialog(void)
{
	SOFTIMPME;
OSErr			err;
EventTypeSpec	list[] = { { kEventClassCommand,  kEventProcessCommand } };
WindowRef 		dialogWindow = nil;
EventHandlerUPP winEvtHandler;
ControlID 		idControl;
ControlRef 		control;
EventHandlerRef	ref;

const char		*rezNames[NUM_LANGUAGES] =
{
	"Settings_English",
	"Settings_French",
	"Settings_German",
	"Settings_Spanish",
	"Settings_Italian",
	"Settings_Swedish",
	"Settings_Dutch",
};


	if (gGamePrefs.language >= NUM_LANGUAGES)		// verify prefs for the hell of it.
		InitDefaultPrefs();

	Enter2D();
	InitCursor();
	MyFlushEvents();


    		/***************/
    		/* INIT DIALOG */
    		/***************/

do_again:

	gLanguageChanged  = false;

			/* CREATE WINDOW FROM THE NIB */

    err = CreateWindowFromNib(gNibs,CFStringCreateWithCString(nil, rezNames[gGamePrefs.language],
    						kCFStringEncodingMacRoman), &dialogWindow);
	if (err)
		DoFatalAlert("DoGameOptionsDialog: CreateWindowFromNib failed!");

			/* CREATE NEW WINDOW EVENT HANDLER */

    winEvtHandler = NewEventHandlerUPP(DoGameSettingsDialog_EventHandler);
    InstallWindowEventHandler(dialogWindow, winEvtHandler, GetEventTypeCount(list), list, dialogWindow, &ref);


			/* SET "SHOW VIDEO" CHECKBOX */

    idControl.signature = 'vido';
    idControl.id 		= 0;
    GetControlByID(dialogWindow, &idControl, &control);
	SetControlValue(control, gGamePrefs.showScreenModeDialog);


			/* SET "KIDDIE MODE" CHECKBOX */

    idControl.signature = 'kidm';
    idControl.id 		= 0;
    GetControlByID(dialogWindow, &idControl, &control);
	SetControlValue(control, gGamePrefs.kiddieMode);


			/* SET "SHOW CROSSHAIRS" CHECKBOX */

    idControl.signature = 'targ';
    idControl.id 		= 0;
    GetControlByID(dialogWindow, &idControl, &control);
	SetControlValue(control, gGamePrefs.showTargetingCrosshairs);


			/* SET "VERT/HORIZ" BUTTONS */

    idControl.signature = '2pla';
    idControl.id 		= 0;
    GetControlByID(dialogWindow, &idControl, &control);
	SetControlValue(control, (gGamePrefs.splitScreenMode == SPLITSCREEN_MODE_HORIZ) + 1);


			/* SET LANGUAGE MENU */

    idControl.signature = 'lang';
    idControl.id 		= 0;
    GetControlByID(dialogWindow, &idControl, &control);
	SetControlValue(control, gGamePrefs.language + 1);



			/**********************/
			/* PROCESS THE DIALOG */
			/**********************/

    ShowWindow(dialogWindow);
	RunAppModalLoopForWindow(dialogWindow);


			/*********************/
			/* GET RESULT VALUES */
			/*********************/

			/* GET "SHOW VIDEO" CHECKBOX */

    idControl.signature = 'vido';
    idControl.id 		= 0;
    GetControlByID(dialogWindow, &idControl, &control);
	gGamePrefs.showScreenModeDialog = GetControlValue(control);


			/* GET "SHOW CROSSHAIRS" CHECKBOX */

    idControl.signature = 'targ';
    idControl.id 		= 0;
    GetControlByID(dialogWindow, &idControl, &control);
	gGamePrefs.showTargetingCrosshairs = GetControlValue(control);

			/* GET "KIDDIE MODE" CHECKBOX */

    idControl.signature = 'kidm';
    idControl.id 		= 0;
    GetControlByID(dialogWindow, &idControl, &control);
	gGamePrefs.kiddieMode = GetControlValue(control);


			/* GET LANGUAGE */

    idControl.signature = 'lang';
    idControl.id 		= 0;
    GetControlByID(dialogWindow, &idControl, &control);
	gGamePrefs.language = GetControlValue(control) - 1;


			/* GET PANE BUTTONS */

    idControl.signature = '2pla';
    idControl.id 		= 0;
    GetControlByID(dialogWindow, &idControl, &control);
	if (GetControlValue(control) == 1)
		gGamePrefs.splitScreenMode = SPLITSCREEN_MODE_VERT;
	else
		gGamePrefs.splitScreenMode = SPLITSCREEN_MODE_HORIZ;

	if (gActiveSplitScreenMode != SPLITSCREEN_MODE_NONE)					// should we set the current active split mode?
	{
		gActiveSplitScreenMode = gGamePrefs.splitScreenMode;


		if (gGamePrefs.splitScreenMode == SPLITSCREEN_MODE_HORIZ)			// smaller FOV for wide panes
		{
			gGameViewInfoPtr->fov[0] =
			gGameViewInfoPtr->fov[1] = HORIZ_PANE_FOV;
		}
		else
			gGameViewInfoPtr->fov[0] =
			gGameViewInfoPtr->fov[1] = VERT_PANE_FOV;
	}

				/***********/
				/* CLEANUP */
				/***********/

	DisposeEventHandlerUPP (winEvtHandler);
	DisposeWindow (dialogWindow);

			/* IF IT WAS JUST A LANGUAGE CHANGE THEN GO BACK TO THE DIALOG */

	if (gLanguageChanged)
		goto do_again;


	HideCursor();
	Exit2D();
	SavePrefs();

	CalcFramesPerSecond();				// reset this so things dont go crazy when we return
	CalcFramesPerSecond();

}


/****************** DO GAME SETTINGS DIALOG EVENT HANDLER *************************/

static pascal OSStatus DoGameSettingsDialog_EventHandler(EventHandlerCallRef myHandler, EventRef event, void* userData)
{
#pragma unused (myHandler, userData)
OSStatus			result = eventNotHandledErr;
HICommand 			command;

	switch(GetEventKind(event))
	{

				/*******************/
				/* PROCESS COMMAND */
				/*******************/

		case	kEventProcessCommand:
				GetEventParameter (event, kEventParamDirectObject, kEventParamHICommand, NULL, sizeof(command), NULL, &command);
				switch(command.commandID)
				{
							/* OK BUTTON */

					case	kHICommandOK:
		                    QuitAppModalLoopForWindow((WindowRef) userData);
		                    break;


							/* CONFIGURE INPUT BUTTON */

					case	'cnfg':
							DoInputConfigDialog();
							break;


							/* LANGUAGE */

					case	'lang':
							gLanguageChanged = true;
		                    QuitAppModalLoopForWindow((WindowRef) userData);
							break;

				}
				break;
    }

    return (result);
}



/********************* DO GAME SETTINGS DIALOG *********************/

void DoGameOptionsDialog(void)
{
DialogRef 		myDialog;
DialogItemType	itemHit;
ControlRef		ctrlHandle;
Boolean			dialogDone;
Boolean			doAgain = false;

	if (gGamePrefs.language >= NUM_LANGUAGES)		// verify prefs for the hell of it.
		InitDefaultPrefs();

	Enter2D();


	InitCursor();

	MyFlushEvents();

	UseResFile(gMainAppRezFile);

do_again:

	myDialog = GetNewDialog(1000 + gGamePrefs.language,nil,MOVE_TO_FRONT);
	if (myDialog == nil)
	{
		DoAlert("DoGameOptionsDialog: GetNewDialog failed!");
		ShowSystemErr(gGamePrefs.language);
	}


				/* SET CONTROL VALUES */

	GetDialogItemAsControl(myDialog,4,&ctrlHandle);
	SetControlValue(ctrlHandle,gGamePrefs.kiddieMode);

	GetDialogItemAsControl(myDialog,6,&ctrlHandle);				// language
	SetControlValue(ctrlHandle,gGamePrefs.language == LANGUAGE_ENGLISH);
	GetDialogItemAsControl(myDialog,7,&ctrlHandle);
	SetControlValue(ctrlHandle,gGamePrefs.language == LANGUAGE_FRENCH);
	GetDialogItemAsControl(myDialog,8,&ctrlHandle);
	SetControlValue(ctrlHandle,gGamePrefs.language == LANGUAGE_GERMAN);
	GetDialogItemAsControl(myDialog,9,&ctrlHandle);
	SetControlValue(ctrlHandle,gGamePrefs.language == LANGUAGE_SPANISH);
	GetDialogItemAsControl(myDialog,10,&ctrlHandle);
	SetControlValue(ctrlHandle,gGamePrefs.language == LANGUAGE_ITALIAN);
	GetDialogItemAsControl(myDialog,11,&ctrlHandle);
	SetControlValue(ctrlHandle,gGamePrefs.language == LANGUAGE_SWEDISH);
	GetDialogItemAsControl(myDialog,12,&ctrlHandle);
	SetControlValue(ctrlHandle,gGamePrefs.language == LANGUAGE_DUTCH);

	AutoSizeDialog(myDialog);



				/* DO IT */

	dialogDone = false;
	while(dialogDone == false)
	{
		ModalDialog(nil, &itemHit);
		switch (itemHit)
		{
			case 	1:									// hit ok
					dialogDone = true;
					break;

			case	4:
					gGamePrefs.kiddieMode = !gGamePrefs.kiddieMode;
					GetDialogItemAsControl(myDialog,itemHit,&ctrlHandle);
					SetControlValue(ctrlHandle,gGamePrefs.kiddieMode);
					break;

			case	5:
//					ClearHighScores();
					break;

			case	6:
			case	7:
			case	8:
			case	9:
			case	10:
			case	11:
			case	12:
					gGamePrefs.language = LANGUAGE_ENGLISH + (itemHit - 6);
					GetDialogItemAsControl(myDialog,6,&ctrlHandle);
					SetControlValue(ctrlHandle,gGamePrefs.language == LANGUAGE_ENGLISH);
					GetDialogItemAsControl(myDialog,7,&ctrlHandle);
					SetControlValue(ctrlHandle,gGamePrefs.language == LANGUAGE_FRENCH);
					GetDialogItemAsControl(myDialog,8,&ctrlHandle);
					SetControlValue(ctrlHandle,gGamePrefs.language == LANGUAGE_GERMAN);
					GetDialogItemAsControl(myDialog,9,&ctrlHandle);
					SetControlValue(ctrlHandle,gGamePrefs.language == LANGUAGE_SPANISH);
					GetDialogItemAsControl(myDialog,10,&ctrlHandle);
					SetControlValue(ctrlHandle,gGamePrefs.language == LANGUAGE_ITALIAN);
					GetDialogItemAsControl(myDialog,11,&ctrlHandle);
					SetControlValue(ctrlHandle,gGamePrefs.language == LANGUAGE_SWEDISH);
					GetDialogItemAsControl(myDialog,12,&ctrlHandle);
					SetControlValue(ctrlHandle,gGamePrefs.language == LANGUAGE_DUTCH);

					doAgain = true;
					dialogDone  = true;
					break;

		}
	}

			/* CLEAN UP */

	DisposeDialog(myDialog);

	if (doAgain)								// see if need to do dialog again (after language switch)
	{
		doAgain = false;
		goto do_again;
	}

	HideCursor();

	Exit2D();


	SavePrefs();

	CalcFramesPerSecond();				// reset this so things dont go crazy when we return
	CalcFramesPerSecond();
}

#endif




#pragma mark -

/********************** DRAW LOADING *************************/

void DrawLoading(float percent)
{
	if (percent > 0.75f)
	{
		MakeFadeEvent(kFadeFlags_Out, 0.0001);
		gGammaFadeFrac = 1.0f - (percent - 0.75f) / 0.25f;
	}

	// Kill vsync so we don't waste 16ms before loading the next asset
	int vsyncBackup = SDL_GL_GetSwapInterval();
	SDL_GL_SetSwapInterval(0);

	// Prevent the OS from thinking our process has locked up
	DoSDLMaintenance();

	// Draw thermometer
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

	if (gGamePrefs.stereoGlassesMode == STEREO_GLASSES_MODE_ANAGLYPH)
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

