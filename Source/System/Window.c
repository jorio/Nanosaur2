/****************************/
/*        WINDOWS           */
/* By Brian Greenstone      */
/* (c)2004 Pangea Software  */
/* (c)2022 Iliyas Jorio     */
/****************************/


/***************/
/* EXTERNALS   */
/***************/

#include	"game.h"


/****************************/
/*    PROTOTYPES            */
/****************************/

static void MoveFadePane(ObjNode *theNode);
static void DrawFadePane(ObjNode *theNode);

#define FaderFrameCounter	Special[0]

static void CreateDisplayModeList(void);
static void GetDisplayVRAM(void);
static void CalcVRAMAfterBuffers(void);


/****************************/
/*    CONSTANTS             */
/****************************/

#define	MAX_VIDEO_MODES		50

#define	NUM_CALIBRATION_IMAGES	4

enum
{
	kFaderMode_FadeOut,
	kFaderMode_FadeIn,
	kFaderMode_Done,
};

/**********************/
/*     VARIABLES      */
/**********************/

uint32_t			gDisplayVRAM = 0;
uint32_t			gVRAMAfterBuffers = 0;

#if 0
static short				gNumVideoModes = 0;
static VideoModeType		gVideoModeList[MAX_VIDEO_MODES];
#endif


float			gGammaFadeFrac = 1.0f;

int				gGameWindowWidth = 640;
int				gGameWindowHeight = 480;

static	short					gCurrentCalibrationImage = 0;


/****************  INIT WINDOW STUFF *******************/

void InitWindowStuff(void)
{
	gGameWindowWidth = 640;
	gGameWindowHeight = 480;
}

#pragma mark -


/***************** FREEZE-FRAME FADE OUT ********************/

void OGL_FadeOutScene(void (*drawCall)(void), void (*moveCall)(void))
{
#if SKIPFLUFF
	gGammaFadeFrac = 0;
	return;
#endif

#if 0
	if (gDebugMode)
	{
		gGammaFadeFrac = 0;
		return;
	}
#endif

	ObjNode* fader = MakeFadeEvent(kFadeFlags_Out, 3.0f);

	long pFaderFrameCount = fader->FaderFrameCounter;

	while (fader->Mode != kFaderMode_Done)
	{
		CalcFramesPerSecond();
		DoSDLMaintenance();

		if (moveCall)
		{
			moveCall();
		}

		// Force fader object to move even if MoveObjects was skipped
		if (fader->FaderFrameCounter == pFaderFrameCount)	// fader wasn't moved by moveCall
		{
			MoveFadePane(fader);
			pFaderFrameCount = fader->FaderFrameCounter;
		}

		OGL_DrawScene(drawCall);
	}

	// Draw one more blank frame
	gGammaFadeFrac = 0;
	CalcFramesPerSecond();
	DoSDLMaintenance();
	OGL_DrawScene(drawCall);

#if 0
	if (gGameView->fadeSound)
	{
		FadeSound(0);
		KillSong();
		StopAllEffectChannels();
		FadeSound(1);		// restore sound volume for new playback
	}
#endif
}


/******************** MAKE FADE EVENT *********************/
//
// INPUT:	fadeIn = true if want fade IN, otherwise fade OUT.
//

ObjNode* MakeFadeEvent(Byte fadeFlags, float fadeSpeed)
{
ObjNode	*newObj = NULL;
Boolean fadeIn = fadeFlags & kFadeFlags_In;

#if SKIPFLUFF
	if (fadeIn)
		gGammaFadeFrac = 1;
	else
		gGammaFadeFrac = 0;
	return NULL;
#endif

		/* SCAN FOR OLD FADE EVENTS STILL IN LIST */

	for (ObjNode *node = gFirstNodePtr; node != NULL; node = node->NextNode)
	{
		if (node->MoveCall == MoveFadePane)
		{
			newObj = node;
			break;
		}
	}



	if (newObj != NULL)
	{
			/* RECYCLE OLD FADE EVENT */

		newObj->StatusBits = STATUS_BIT_DONTCULL;    // reset status bits in case NOMOVE was set
	}
	else
	{
			/* MAKE NEW FADE EVENT */

		NewObjectDefinitionType def =
		{
			.genre = CUSTOM_GENRE,
			.flags = STATUS_BIT_DONTCULL,
			.slot = FADEPANE_SLOT,
			.moveCall = MoveFadePane,
			.drawCall = DrawFadePane,
			.scale = 1,
		};

		newObj = MakeNewObject(&def);
	}


	gGammaFadeFrac = fadeIn? 0: 1;

	newObj->Mode = fadeIn ? kFaderMode_FadeIn : kFaderMode_FadeOut;
	newObj->FaderFrameCounter = 0;
	newObj->Speed = fadeSpeed;

	if (fadeFlags & kFadeFlags_P1)
	{
		newObj->StatusBits |= STATUS_BIT_ONLYSHOWTHISPLAYER;
		newObj->PlayerNum = 0;
	}
	else if (fadeFlags & kFadeFlags_P2)
	{
		newObj->StatusBits |= STATUS_BIT_ONLYSHOWTHISPLAYER;
		newObj->PlayerNum = 1;
	}
	else
	{
		SendNodeToOverlayPane(newObj);
	}

	return newObj;
}


/***************** MOVE FADE EVENT ********************/

static void MoveFadePane(ObjNode *theNode)
{
float	fps = gFramesPerSecondFrac;
float	speed = theNode->Speed * fps;

			/* SEE IF FADE IN */

	if (theNode->Mode == kFaderMode_FadeIn)
	{
		gGammaFadeFrac += speed;
		if (gGammaFadeFrac >= 1.0f)				// see if @ 100%
		{
			gGammaFadeFrac = 1;
			theNode->Mode = kFaderMode_Done;
			DeleteObject(theNode);				// nuke it if fading in
		}
	}

			/* FADE OUT */

	else if (theNode->Mode == kFaderMode_FadeOut)
	{
		gGammaFadeFrac -= speed;
		if (gGammaFadeFrac <= 0.0f)				// see if @ 0%
		{
			gGammaFadeFrac = 0;
			theNode->Mode = kFaderMode_Done;
			theNode->StatusBits |= STATUS_BIT_NOMOVE;	// DON'T nuke the fader pane if fading out -- but don't run this again
		}
	}
}


/***************** DRAW FADE PANE ********************/

static void DrawFadePane(ObjNode* theNode)
{
	OGL_PushState();
	SetInfobarSpriteState(0, 1);

	//glDisable(GL_TEXTURE_2D);
	OGL_DisableTexture2D();

	OGL_SetColor4f(0, 0, 0, 1.0f - gGammaFadeFrac);// (GLfloat*)&theNode->ColorFilter);
	OGL_EnableBlend();

	glBegin(GL_QUADS);
	glVertex3f(-1000, -1000, 0);
	glVertex3f( 1000, -1000, 0);
	glVertex3f( 1000,  1000, 0);
	glVertex3f(-1000,  1000, 0);
	glEnd();

//	glDisable(GL_BLEND);

	OGL_PopState();
}

/************************** ENTER 2D *************************/
//
// For OS X - turn off DSp when showing 2D
//

void Enter2D(void)
{
	GrabMouse(false);
	SDL_ShowCursor(1);
	MyFlushEvents();
}


/************************** EXIT 2D *************************/
//
// For OS X - turn ON DSp when NOT 2D
//

void Exit2D(void)
{
	SDL_ShowCursor(0);

#if 0
		/* BE SURE GREEN CHANNEL IS CLEAR FOR ANAGLYPH */

	if (gAGLContext && (gGamePrefs.stereoGlassesMode == STEREO_GLASSES_MODE_ANAGLYPH))
	{
		glColorMask(GL_FALSE, GL_TRUE, GL_FALSE, GL_FALSE);			// turn on green only
		glClearColor(0,0,0,0);										// clear to 0's
		glClear(GL_COLOR_BUFFER_BIT);
		glClearColor(gGameViewInfoPtr->clearColor.r, gGameViewInfoPtr->clearColor.g, gGameViewInfoPtr->clearColor.b, 1.0);
	}
#endif
}


#pragma mark -

#if 0
/********************* DO SCREEN MODE DIALOG *************************/

void DoScreenModeDialog(void)
{
Byte			oldStereo = gGamePrefs.stereoGlassesMode;
OSErr			err;
EventHandlerRef	ref;
EventTypeSpec	list[] = { { kEventClassCommand,  kEventProcessCommand } };
ControlID 		idControl;
ControlRef 		control;
int				i;
const char		*rezNames[NUM_LANGUAGES] =
{
	"VideoMode_English",
	"VideoMode_French",
	"VideoMode_German",
	"VideoMode_Spanish",
	"VideoMode_Italian",
	"VideoMode_Swedish",
	"VideoMode_Dutch",
};

	if (gGamePrefs.language > LANGUAGE_DUTCH)					// verify that this is legit
		gGamePrefs.language = LANGUAGE_ENGLISH;


				/* GET LIST OF VIDEO MODES FOR USER TO CHOOSE FROM */

	CreateDisplayModeList();


				/**********************************************/
				/* DETERMINE IF NEED TO DO THIS DIALOG OR NOT */
				/**********************************************/

	UpdateKeyMap();
	UpdateKeyMap();
	if (GetKeyState(KEY_OPTION) || gGamePrefs.showScreenModeDialog)			// see if force it
		goto do_it;

					/* VERIFY THAT CURRENT MODE IS ALLOWED */

	for (i=0; i < gNumVideoModes; i++)
	{
		if ((gVideoModeList[i].rezH == gGamePrefs.screenWidth) &&					// if its a match then bail
			(gVideoModeList[i].rezV == gGamePrefs.screenHeight) &&
			(gVideoModeList[i].hz == gGamePrefs.hz))
			{
				CalcVRAMAfterBuffers();
				return;
			}
	}

			/* BAD MODE, SO RESET TO SOMETHING LEGAL AS DEFAULT */

	gGamePrefs.screenWidth = gVideoModeList[0].rezH;
	gGamePrefs.screenHeight = gVideoModeList[0].rezV;
	gGamePrefs.hz = gVideoModeList[0].hz;



    		/***************/
    		/* INIT DIALOG */
    		/***************/
do_it:

	InitCursor();

				/* CREATE WINDOW FROM THE NIB */

    err = CreateWindowFromNib(gNibs, CFStringCreateWithCString(nil, rezNames[gGamePrefs.language],
    						kCFStringEncodingMacRoman), &gDialogWindow);
	if (err)
		DoFatalAlert("DoScreenModeDialog: CreateWindowFromNib failed!");


			/* CREATE NEW WINDOW EVENT HANDLER */

    gWinEvtHandler = NewEventHandlerUPP(DoScreenModeDialog_EventHandler);
    InstallWindowEventHandler(gDialogWindow, gWinEvtHandler, GetEventTypeCount(list), list, 0, &ref);


			/* SET "DON'T SHOW" CHECKBOX */

    idControl.signature = 'nosh';
    idControl.id 		= 0;
    GetControlByID(gDialogWindow, &idControl, &control);
	SetControlValue(control, !gGamePrefs.showScreenModeDialog);


			/* SET "16/32" BUTTONS */

    idControl.signature = 'bitd';
    idControl.id 		= 0;
    GetControlByID(gDialogWindow, &idControl, &control);
	SetControlValue(control, (gGamePrefs.depth == 32) + 1);

	if (gDisplayVRAM <= 0x2000000)				// if <= 32MB VRAM...
	{
		DisableControl(control);
	}


			/* SET "QUALITY" BUTTONS */

    idControl.signature = 'qual';
    idControl.id 		= 0;
    GetControlByID(gDialogWindow, &idControl, &control);
	SetControlValue(control, gGamePrefs.lowRenderQuality + 1);

	if (gDisplayVRAM <= 0x2000000)				// if <= 32MB VRAM...
	{
		DisableControl(control);
	}

			/* SET STEREO BUTTONS*/

    idControl.signature = '3dmo';
    idControl.id 		= 0;
    GetControlByID(gDialogWindow, &idControl, &control);
	SetControlValue(control, gGamePrefs.stereoGlassesMode + 1);


			/* SET ANAGLYPH COLOR/BW BUTTONS */

    idControl.signature = '3dco';
    idControl.id 		= 0;
    GetControlByID(gDialogWindow, &idControl, &control);
	SetControlValue(control, gGamePrefs.anaglyphColor + 1);



	BuildResolutionMenu();


			/**********************/
			/* PROCESS THE DIALOG */
			/**********************/

    ShowWindow(gDialogWindow);
	RunAppModalLoopForWindow(gDialogWindow);


			/*********************/
			/* GET RESULT VALUES */
			/*********************/

			/* GET "DON'T SHOW" CHECKBOX */

    idControl.signature = 'nosh';
    idControl.id 		= 0;
    GetControlByID(gDialogWindow, &idControl, &control);
	gGamePrefs.showScreenModeDialog = !GetControlValue(control);


			/* GET "16/32" BUTTONS */

    idControl.signature = 'bitd';
    idControl.id 		= 0;
    GetControlByID(gDialogWindow, &idControl, &control);
	if (GetControlValue(control) == 1)
		gGamePrefs.depth = 16;
	else
		gGamePrefs.depth = 32;


			/* GET "QUALITY" BUTTONS */

    idControl.signature = 'qual';
    idControl.id 		= 0;
    GetControlByID(gDialogWindow, &idControl, &control);
	if (GetControlValue(control) == 1)
		gGamePrefs.lowRenderQuality = false;
	else
		gGamePrefs.lowRenderQuality = true;


			/* GET RESOLUTION MENU */

    idControl.signature = 'rezm';
    idControl.id 		= 0;
    GetControlByID(gDialogWindow, &idControl, &control);
	i = GetControlValue(control);
	gGamePrefs.screenWidth = gVideoModeList[i-1].rezH;
	gGamePrefs.screenHeight = gVideoModeList[i-1].rezV;
	gGamePrefs.hz = gVideoModeList[i-1].hz;


			/* GET STEREO BUTTONS*/

    idControl.signature = '3dmo';
    idControl.id 		= 0;
    GetControlByID(gDialogWindow, &idControl, &control);
	gGamePrefs.stereoGlassesMode = GetControlValue(control) - 1;


			/* GET ANAGLYPH COLOR/BW BUTTONS */

    idControl.signature = '3dco';
    idControl.id 		= 0;
    GetControlByID(gDialogWindow, &idControl, &control);
	if (GetControlValue(control) == 2)
		gGamePrefs.anaglyphColor = true;
	else
		gGamePrefs.anaglyphColor = false;



		/* IF JUST NOW SELECTED ANAGLYPH THEN LET'S ALSO DISABLE THE CROSSHAIRS */

	if ((oldStereo == STEREO_GLASSES_MODE_OFF) && (gGamePrefs.stereoGlassesMode != STEREO_GLASSES_MODE_OFF))
		gGamePrefs.showTargetingCrosshairs = false;
	else														// or the opposite...
	if ((oldStereo != STEREO_GLASSES_MODE_OFF) && (gGamePrefs.stereoGlassesMode == STEREO_GLASSES_MODE_OFF))
		gGamePrefs.showTargetingCrosshairs = true;


				/***********/
				/* CLEANUP */
				/***********/

	DisposeEventHandlerUPP (gWinEvtHandler);
	DisposeWindow (gDialogWindow);

#if 0
	if (gGamePrefs.stereoGlassesMode == STEREO_GLASSES_MODE_SHUTTER)		// need at least 64MB VRAM for this
	{
		if (gDisplayVRAM < 0x4000000)				// if < 64MB VRAM...
		{
			DoAlert("Sorry, but to use shutter glasses you need at least 64MB of VRAM");
			gGamePrefs.stereoGlassesMode = STEREO_GLASSES_MODE_OFF;
			goto do_it;
		}
	}
#endif



	CalcVRAMAfterBuffers();
	SavePrefs();
}

/****************** DO SCREEN MODE DIALOG EVENT HANDLER *************************/
//
// main window event handling
//

static pascal OSStatus DoScreenModeDialog_EventHandler(EventHandlerCallRef myHandler, EventRef event, void* userData)
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

							/* "QUIT" BUTTON */

					case	'quit':
		                    ExitToShell();
							break;


							/* CALIBRATE BUTTON */

					case	'cali':
							DoAnaglyphCalibrationDialog();
							break;
				}
				break;
    }

    return (result);
}



/****************** BUILD RESOLUTION MENU *************************/

static void BuildResolutionMenu(void)
{
Str255 		menuStrings[MAX_VIDEO_MODES];
short		i, defaultItem = 1;
Str32		s,t;

	for (i=0; i < gNumVideoModes; i++)
	{
				/* BUILD MENU ITEM STRING */

		NumToString(gVideoModeList[i].rezH, s);			// horiz rez
		s[s[0]+1] = 'x';								// "x"
		s[0]++;

		NumToString(gVideoModeList[i].rezV, t);			// vert rez
		BlockMove(&t[1], &s[s[0]+1], t[0]);
		s[0] += t[0];

		s[s[0]+1] = ' ';								// " "
		s[0]++;

		NumToString(gVideoModeList[i].hz, t);			// refresh hz
		BlockMove(&t[1], &s[s[0]+1], t[0]);
		s[0] += t[0];

		s[s[0]+1] = 'h';								// "hz"
		s[s[0]+2] = 'z';
		s[0] += 2;

		BlockMove(&s[0], &menuStrings[i][0], s[0]+1);

			/* IS THIS THE CURRENT SETTING? */

		if ((gVideoModeList[i].rezH == gGamePrefs.screenWidth) &&
			(gVideoModeList[i].rezV == gGamePrefs.screenHeight) &&
			(gVideoModeList[i].hz == gGamePrefs.hz))
		{
			defaultItem = i;
		}
	}


			/* BUILD THE MENU FROM THE STRING LIST */

	BuildControlMenu (gDialogWindow, 'rezm', 0, &menuStrings[0], gNumVideoModes, defaultItem);
}


/********************** BUILD CONTROL MENU ***************************/
//
// builds menu of id, based on text list of numitems number of strings
//

void BuildControlMenu(WindowRef window, SInt32 controlSig, SInt32 id, Str255 textList[], short numItems, short defaultSelection)
{
MenuHandle 	hMenu;
Size 		tempSize;
ControlID 	idControl;
ControlRef 	control;
short 		i;
OSStatus 	err = noErr;

    		/* GET MENU DATA */

    idControl.signature = controlSig;
    idControl.id 		= id;
    GetControlByID(window, &idControl, &control);
    GetControlData(control, kControlMenuPart, kControlPopupButtonMenuHandleTag, sizeof (MenuHandle), &hMenu, &tempSize);

    	/* REMOVE ALL ITEMS FROM EXISTING MENU */

    err = DeleteMenuItems(hMenu, 1, CountMenuItems (hMenu));


			/* ADD NEW ITEMS TO THE MENU */

    for (i = 0; i < numItems; i++)
        AppendMenu(hMenu, textList[i]);


			/* FORCE UPDATE OF MENU EXTENTS */

    SetControlMaximum(control, numItems);

	if (defaultSelection >= numItems)					// make sure default isn't over
		defaultSelection = 0;

	SetControlValue(control, defaultSelection+1);

}



#pragma mark -

/********************* CREATE DISPLAY MODE LIST *************************/

static void CreateDisplayModeList(void)
{
int					i, j, numDeviceModes;
CFArrayRef 			modeList;
CFDictionaryRef 	mode;
long				width, height, dep;
double				hz;

			/* MAKE SURE IT SHOWS 640X480 */

	gVideoModeList[0].rezH = 640;
	gVideoModeList[0].rezV = 480;
	gVideoModeList[0].hz = 60;
	gNumVideoModes = 1;

				/* GET MAIN MONITOR ID & VRAM FOR IT */

	gCGDisplayID = CGMainDisplayID();
	GetDisplayVRAM();										// calc the amount of vram on this device

				/* GET LIST OF MODES FOR THIS MONITOR */

	modeList = CGDisplayAvailableModes(gCGDisplayID);
	if (modeList == nil)
		DoFatalAlert("CreateDisplayModeList: CGDisplayAvailableModes failed!");

	numDeviceModes = CFArrayGetCount(modeList);


				/*********************/
				/* EXTRACT MODE INFO */
				/*********************/

	for (i = 0; i < numDeviceModes; i++)
    {
    	CFNumberRef	number;
    	Boolean		skip;

        mode = CFArrayGetValueAtIndex( modeList, i );				  	// Pull the mode dictionary out of the CFArray
		if (mode == nil)
			DoFatalAlert("CreateDisplayModeList: CFArrayGetValueAtIndex failed!");

		number = CFDictionaryGetValue(mode, kCGDisplayWidth);			// get width
		CFNumberGetValue(number, kCFNumberLongType, &width) ;

		number = CFDictionaryGetValue(mode, kCGDisplayHeight);	 		// get height
		CFNumberGetValue(number, kCFNumberLongType, &height);

		number = CFDictionaryGetValue(mode, kCGDisplayBitsPerPixel);	// get depth
		CFNumberGetValue(number, kCFNumberLongType, &dep);
		if (dep != 32)
			continue;

		number = CFDictionaryGetValue(mode, kCGDisplayRefreshRate);		// get refresh rate
		if (number == nil)
			hz = 85;
		else
		{
			CFNumberGetValue(number, kCFNumberDoubleType, &hz);
			if (hz == 0)												// LCD's tend to return 0 since there's no real refresh rate
				hz = 60;
		}

				/* IN LOW-VRAM SITUATIONS, DON'T ALLOW LARGE MODES */

		if (gDisplayVRAM <= 0x4000000)				// if <= 64MB VRAM...
		{
			if (width > 1280)
				continue;
		}

		if (gDisplayVRAM <= 0x2000000)				// if <= 32MB VRAM...
		{
			if (width > 1024)
				continue;
		}

					/***************************/
					/* SEE IF ADD TO MODE LIST */
					/***************************/

					/* SEE IF IT'S A VALID MODE FOR US */

		if (CFDictionaryGetValue(mode, kCGDisplayModeUsableForDesktopGUI) != kCFBooleanTrue)	// is it a displayable rez?
			continue;


						/* SEE IF ALREADY IN LIST */

		skip = false;
		for (j = 0; j < gNumVideoModes; j++)
		{
			if ((gVideoModeList[j].rezH == width) &&
				(gVideoModeList[j].rezV == height) &&
				(gVideoModeList[j].hz == hz))
			{
				skip = true;
				break;
			}
		}

		if (!skip)
		{
				/* THIS REZ NOT IN LIST YET, SO ADD */

			if (gNumVideoModes < MAX_VIDEO_MODES)
			{
				gVideoModeList[gNumVideoModes].rezH = width;
				gVideoModeList[gNumVideoModes].rezV = height;
				gVideoModeList[gNumVideoModes].hz = hz;
				gNumVideoModes++;
			}
		}
	}
}

/******************** GET DISPLAY VRAM ***********************/

static void GetDisplayVRAM(void)
{
io_service_t	port;
CFTypeRef		classCode;

			/* SEE HOW MUCH VRAM WE HAVE */

	port = CGDisplayIOServicePort(gCGDisplayID);
	classCode = IORegistryEntryCreateCFProperty(port, CFSTR(kIOFBMemorySizeKey), kCFAllocatorDefault, kNilOptions);

	if (CFGetTypeID(classCode) == CFNumberGetTypeID())
	{
		CFNumberGetValue(classCode, kCFNumberSInt32Type, &gDisplayVRAM);
	}
	else
		gDisplayVRAM = 0x8000000;				// if failed, then just assume 128MB VRAM to be safe


			/* SET SOME PREFS IF THINGS ARE LOOKING LOW */

	if (gDisplayVRAM <= 0x2000000)				// if <= 32MB VRAM...
	{
		gGamePrefs.depth = 16;
		gGamePrefs.lowRenderQuality = true;
	}

	if (gDisplayVRAM < 0x1000000)				// if < 16MB VRAM...
	{
		DoFatalAlert("This game requires at least 32MB of VRAM, and you appear to have much less than that.  You will need to install a newer video card with more VRAM to play this game.");
	}


	SavePrefs();
}


/*********************** CALC VRAM AFTER BUFFERS ***********************/
//
// CALC HOW MUCH VRAM REMAINS AFTER OUR BUFFERS
//

static void CalcVRAMAfterBuffers(void)
{
int	bufferSpace;

	bufferSpace = gGamePrefs.screenWidth * gGamePrefs.screenHeight * 2 * 2;		// calc main pixel/z buffers @ 16-bit
	if (gGamePrefs.depth == 32)
		bufferSpace *= 2;
	if (gGamePrefs.stereoGlassesMode == STEREO_GLASSES_MODE_SHUTTER)
		bufferSpace *= 2;

	gVRAMAfterBuffers = gDisplayVRAM - bufferSpace;
}
#endif


#pragma mark -

/********************* DO ANAGLYPH CALIBRATION DIALOG *************************/

void DoAnaglyphCalibrationDialog(void)
{
	IMPME;
#if 0
OSErr			err;
EventHandlerRef	ref;
EventTypeSpec	list[] = { { kEventClassCommand,  kEventProcessCommand } };
ControlID 		idControl;
ControlRef 		control;
FSSpec			spec;
short			i;
const unsigned char	*names[NUM_CALIBRATION_IMAGES] =
{
	":images:calibration1.tif",
	":images:calibration2.jpg",
	":images:calibration3.jpg",
	":images:calibration4.jpg",
};

	InitCursor();


				/* LOAD THE SOURCE TEST IMAGES INTO 2 BUFFERS */

	for (i = 0; i < NUM_CALIBRATION_IMAGES; i++)
	{
		FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, names[i], &spec);
		DrawPictureIntoGWorld(&spec, &gCalibrationImage_Original[i], 32);
		DrawPictureIntoGWorld(&spec, &gCalibrationImage_Modified[i], 32);
	}


    		/***************/
    		/* INIT DIALOG */
    		/***************/

				/* CREATE WINDOW FROM THE NIB */

    err = CreateWindowFromNib(gNibs, CFStringCreateWithCString(nil, "AnaglyphCalibration",
    						kCFStringEncodingMacRoman), &gCalibrationWindow);
	if (err)
		DoFatalAlert("DoAnaglyphCalibrationDialog: CreateWindowFromNib failed!");


			/* CREATE NEW WINDOW EVENT HANDLER */

    gCalibrationEvtHandler = NewEventHandlerUPP(DoAnaglyphCalibrationDialog_EventHandler);
    InstallWindowEventHandler(gCalibrationWindow, gCalibrationEvtHandler, GetEventTypeCount(list), list, 0, &ref);



			/* SET "RED" SLIDER */

    idControl.signature = 'redb';
    idControl.id 		= 0;
    GetControlByID(gCalibrationWindow, &idControl, &control);
	SetControlValue(control, gGamePrefs.anaglyphCalibrationRed);

			/* SET "GREEN" SLIDER */

    idControl.signature = 'greb';
    idControl.id 		= 0;
    GetControlByID(gCalibrationWindow, &idControl, &control);
	SetControlValue(control, gGamePrefs.anaglyphCalibrationGreen);

			/* SET "BLUE" SLIDER */

    idControl.signature = 'blub';
    idControl.id 		= 0;
    GetControlByID(gCalibrationWindow, &idControl, &control);
	SetControlValue(control, gGamePrefs.anaglyphCalibrationBlue);

			/* SET "CHANNEL BALANCE" CHECKBOX */

    idControl.signature = 'noca';
    idControl.id 		= 0;
    GetControlByID(gCalibrationWindow, &idControl, &control);
	SetControlValue(control, gGamePrefs.doAnaglyphChannelBalancing);


			/* SET DRAW PROC FOR USER PANE */

    idControl.signature = 'prev';
    idControl.id 		= 0;
    GetControlByID(gCalibrationWindow, &idControl, &gCalibrationUserItemControl);

	gCalibrationUserPaneDrawUPP = NewControlUserPaneDrawUPP(DrawCalibrationImageProc);
	err = SetControlData(gCalibrationUserItemControl, kControlNoPart, kControlUserPaneDrawProcTag,
						sizeof(gCalibrationUserPaneDrawUPP), &gCalibrationUserPaneDrawUPP);

	if (err)
		DoFatalAlert("DoAnaglyphCalibrationDialog: SetControlData failed!");



			/**********************/
			/* PROCESS THE DIALOG */
			/**********************/

    ShowWindow(gCalibrationWindow);
	RunAppModalLoopForWindow(gCalibrationWindow);


				/***********/
				/* CLEANUP */
				/***********/

	DisposeEventHandlerUPP (gCalibrationEvtHandler);
	DisposeControlUserPaneDrawUPP (gCalibrationUserPaneDrawUPP);
	DisposeWindow (gCalibrationWindow);
	for (i = 0; i < NUM_CALIBRATION_IMAGES; i++)
	{
		DisposeGWorld(gCalibrationImage_Original[i]);
		DisposeGWorld(gCalibrationImage_Modified[i]);
	}
	SavePrefs();
#endif
}


/***************** DRAW CALIBRATION IMAGE PROC ********************/

#if 0
static pascal void DrawCalibrationImageProc(ControlRef control, SInt16 id)
{
Rect			bounds, r;
Ptr				pictMapAddr;
uint32_t			pictRowBytes;
PixMapHandle 	hPixMap;
int				width, height, x, y;
uint32_t			*pixels;
short			i = gCurrentCalibrationImage;

#pragma unused (id)

	GetControlBounds(control, &bounds);

  			/* COPY ORIGINAL INTO THE MODIFIED GWORLD */

	DumpGWorldToGWorld (gCalibrationImage_Original[i], gCalibrationImage_Modified[i]);


  				/****************************************/
  				/* NOW DO THE CALIBRATION ON THE GWORLD */
  				/****************************************/

			/* GET GWORLD INFO */

	GetPortBounds(gCalibrationImage_Modified[i], &r);
	width = r.right - r.left;									// get width/height
	height = r.bottom - r.top;
	hPixMap = GetGWorldPixMap(gCalibrationImage_Modified[i]);		// get gworld's pixmap
	pictMapAddr = GetPixBaseAddr(hPixMap);
	pictRowBytes = (uint32_t)(**hPixMap).rowBytes & 0x3fff;

	pixels = (uint32_t *)pictMapAddr;

	for (y = 0; y < height; y++)
	{
		for (x = 0; x < width; x++)
		{
			uint32_t	pixel 	= SwizzleULong(&pixels[x]);
			uint32_t	red 	= (pixel & 0x00ff0000) >> 16;
			uint32_t	green 	= (pixel & 0x0000ff00) >> 8;
			uint32_t	blue 	= (pixel & 0x000000ff) >> 0;

			ColorBalanceRGBForAnaglyph(&red, &green, &blue, false);

			pixels[x] = (red << 16) | (green << 8) | (blue << 0) | 0xff000000;
			pixels[x] = SwizzleULong(&pixels[x]);

		}


		pixels += pictRowBytes/4;								// next row
	}



  			/* SHOW IT */

	DumpGWorld2(gCalibrationImage_Modified[i], gCalibrationWindow, &bounds);


}


/****************** DO ANAGLYPH CALIBRATION DIALOG EVENT HANDLER *************************/
//
// main window event handling
//

static pascal OSStatus DoAnaglyphCalibrationDialog_EventHandler(EventHandlerCallRef myHandler, EventRef event, void* userData)
{
#pragma unused (myHandler, userData)
OSStatus		result = eventNotHandledErr;
HICommand 		command;
ControlID 		idControl;
ControlRef 		control;
short			oldRed,oldGreen,oldBlue;
short			oldImage;
Boolean			oldDoCa;

	oldRed = gGamePrefs.anaglyphCalibrationRed;
	oldGreen = gGamePrefs.anaglyphCalibrationGreen;
	oldBlue = gGamePrefs.anaglyphCalibrationBlue;
	oldImage = gCurrentCalibrationImage;
	oldDoCa = gGamePrefs.doAnaglyphChannelBalancing;

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
 		                    QuitAppModalLoopForWindow(gCalibrationWindow);
							break;

							/* DEFAULT BUTTON */

					case	'dlcd':
							gGamePrefs.anaglyphCalibrationRed 	= DEFAULT_ANAGLYPH_R;
							gGamePrefs.anaglyphCalibrationGreen = DEFAULT_ANAGLYPH_G;
							gGamePrefs.anaglyphCalibrationBlue 	= DEFAULT_ANAGLYPH_B;
							gGamePrefs.doAnaglyphChannelBalancing = true;
							oldImage = -1;
							break;

							/* NO CALIBRATION CHECKBOX */

					case	'noca':
							gGamePrefs.doAnaglyphChannelBalancing = !gGamePrefs.doAnaglyphChannelBalancing;
							break;


				}

				if (oldImage == -1)
				{
					idControl.signature = 'redb';
					idControl.id 		= 0;
					GetControlByID(gCalibrationWindow, &idControl, &control);
					SetControlValue(control, gGamePrefs.anaglyphCalibrationRed);

					idControl.signature = 'greb';
					idControl.id 		= 0;
					GetControlByID(gCalibrationWindow, &idControl, &control);
					SetControlValue(control, gGamePrefs.anaglyphCalibrationGreen);

					idControl.signature = 'blub';
					idControl.id 		= 0;
					GetControlByID(gCalibrationWindow, &idControl, &control);
					SetControlValue(control, gGamePrefs.anaglyphCalibrationBlue);

					idControl.signature = 'noca';
					idControl.id 		= 0;
					GetControlByID(gCalibrationWindow, &idControl, &control);
					SetControlValue(control, gGamePrefs.doAnaglyphChannelBalancing);
				}

				result = noErr;
				break;

    }




					/* UPDATE CALIBRATION IMAGE ANYTIME THERE'S AN EVENT */

	if (oldImage != -1)
	{
		idControl.signature = 'redb';
		idControl.id 		= 0;
		GetControlByID(gCalibrationWindow, &idControl, &control);
		gGamePrefs.anaglyphCalibrationRed = GetControlValue(control);

		idControl.signature = 'greb';
		idControl.id 		= 0;
		GetControlByID(gCalibrationWindow, &idControl, &control);
		gGamePrefs.anaglyphCalibrationGreen = GetControlValue(control);

		idControl.signature = 'blub';
		idControl.id 		= 0;
		GetControlByID(gCalibrationWindow, &idControl, &control);
		gGamePrefs.anaglyphCalibrationBlue = GetControlValue(control);
	}

	idControl.signature = 'imag';
	idControl.id 		= 0;
	GetControlByID(gCalibrationWindow, &idControl, &control);
	gCurrentCalibrationImage = GetControlValue(control) - 1;


	if ((oldRed 	!= gGamePrefs.anaglyphCalibrationRed) ||						// only update if something changed
		(oldGreen 	!= gGamePrefs.anaglyphCalibrationGreen) ||
		(oldBlue 	!= gGamePrefs.anaglyphCalibrationBlue) ||
		(oldImage 	!= gCurrentCalibrationImage) ||
		(oldDoCa	!= gGamePrefs.doAnaglyphChannelBalancing))
	{
		DrawCalibrationImageProc(gCalibrationUserItemControl, 0);
    }


    return (result);
}




#endif




/******************** MOVE WINDOW TO PREFERRED DISPLAY *******************/
//
// This works best in windowed mode.
// Turn off fullscreen before calling this!
//

static void MoveToPreferredDisplay(void)
{
#if !(__APPLE__)
	int currentDisplay = SDL_GetWindowDisplayIndex(gSDLWindow);

	if (currentDisplay != gGamePrefs.monitorNum)
	{
		SDL_SetWindowPosition(
			gSDLWindow,
			SDL_WINDOWPOS_CENTERED_DISPLAY(gGamePrefs.monitorNum),
			SDL_WINDOWPOS_CENTERED_DISPLAY(gGamePrefs.monitorNum));
	}
#endif
}

/*********************** SET FULLSCREEN MODE **********************/

void SetFullscreenMode(bool enforceDisplayPref)
{
	if (!gGamePrefs.fullscreen)
	{
		SDL_SetWindowFullscreen(gSDLWindow, 0);

		if (enforceDisplayPref)
		{
			MoveToPreferredDisplay();
		}
	}
	else
	{
#if !(__APPLE__)
		if (enforceDisplayPref)
		{
			int currentDisplay = SDL_GetWindowDisplayIndex(gSDLWindow);

			if (currentDisplay != gGamePrefs.monitorNum)
			{
				// We must switch back to windowed mode for the preferred monitor to take effect
				SDL_SetWindowFullscreen(gSDLWindow, 0);
				MoveToPreferredDisplay();
			}
		}
#endif

		// Enter fullscreen mode
		SDL_SetWindowFullscreen(gSDLWindow, SDL_WINDOW_FULLSCREEN_DESKTOP);
	}

	// Ensure the clipping pane gets resized properly after switching in or out of fullscreen mode
//	int width, height;
//	SDL_GetWindowSize(gSDLWindow, &width, &height);
//	QD3D_OnWindowResized(width, height);

//	SDL_ShowCursor(gGamePrefs.fullscreen ? 0 : 1);
}
