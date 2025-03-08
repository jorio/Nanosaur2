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


/****************************/
/*    CONSTANTS             */
/****************************/

enum
{
	kFaderMode_FadeOut,
	kFaderMode_FadeIn,
	kFaderMode_Done,
};

/**********************/
/*     VARIABLES      */
/**********************/

float			gGammaFadeFrac = 1.0f;

int				gGameWindowWidth = 640;
int				gGameWindowHeight = 480;


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

	if (gGameViewInfoPtr->fadeSound)
	{
		FadeSound(0);
		KillSong();
		StopAllEffectChannels();
		FadeSound(1);		// restore sound volume for new playback
	}
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


	if (gGameViewInfoPtr->fadeSound)
	{
		FadeSound(gGammaFadeFrac);
	}
}


/***************** DRAW FADE PANE ********************/

static void DrawFadePane(ObjNode* theNode)
{
	OGL_PushState();
	SetInfobarSpriteState(0, 1);

	OGL_DisableTexture2D();

	OGL_EnableBlend();
	OGL_SetColor4f(0, 0, 0, 1.0f - gGammaFadeFrac);

	glBegin(GL_QUADS);
	glVertex3f(gLogicalRect.right, gLogicalRect.top, 0);
	glVertex3f(gLogicalRect.left, gLogicalRect.top, 0);
	glVertex3f(gLogicalRect.left, gLogicalRect.bottom, 0);
	glVertex3f(gLogicalRect.right, gLogicalRect.bottom, 0);
	glEnd();

	OGL_PopState();
}

/************************** ENTER 2D *************************/
//
// For OS X - turn off DSp when showing 2D
//

void Enter2D(void)
{
	GrabMouse(false);
	SDL_ShowCursor();
	MyFlushEvents();
}


/************************** EXIT 2D *************************/
//
// For OS X - turn ON DSp when NOT 2D
//

void Exit2D(void)
{
	SDL_HideCursor();

#if 0
		/* BE SURE GREEN CHANNEL IS CLEAR FOR ANAGLYPH */

	if (gAGLContext && IsStereoAnaglyph())
	{
		glColorMask(GL_FALSE, GL_TRUE, GL_FALSE, GL_FALSE);			// turn on green only
		glClearColor(0,0,0,0);										// clear to 0's
		glClear(GL_COLOR_BUFFER_BIT);
		glClearColor(gGameViewInfoPtr->clearColor.r, gGameViewInfoPtr->clearColor.g, gGameViewInfoPtr->clearColor.b, 1.0);
	}
#endif
}


#pragma mark -

/******************** GET DEFAULT WINDOW SIZE *******************/

void GetDefaultWindowSize(SDL_DisplayID display, int* width, int* height)
{
	const float aspectRatio = 16.0f / 10.0f;
	const float screenCoverage = .8f;

	SDL_Rect displayBounds = { .x = 0, .y = 0, .w = 640, .h = 480 };
	SDL_GetDisplayUsableBounds(display, &displayBounds);

	if (displayBounds.w > displayBounds.h)
	{
		*width = displayBounds.h * screenCoverage * aspectRatio;
		*height = displayBounds.h * screenCoverage;
	}
	else
	{
		*width = displayBounds.w * screenCoverage;
		*height = displayBounds.w * screenCoverage / aspectRatio;
	}
}

/******************** GET NUM DISPLAYS *******************/

int GetNumDisplays(void)
{
	int numDisplays = 0;
	SDL_DisplayID* displays = SDL_GetDisplays(&numDisplays);
	SDL_free(displays);
	return numDisplays;
}

/******************** MOVE WINDOW TO PREFERRED DISPLAY *******************/
//
// This works best in windowed mode.
// Turn off fullscreen before calling this!
//

void MoveToPreferredDisplay(void)
{
	if (gGamePrefs.displayNumMinus1 >= GetNumDisplays())
	{
		gGamePrefs.displayNumMinus1 = 0;
	}

	SDL_DisplayID display = gGamePrefs.displayNumMinus1 + 1;

	int w = 640;
	int h = 480;
	GetDefaultWindowSize(display, &w, &h);
	SDL_SetWindowSize(gSDLWindow, w, h);
	SDL_SyncWindow(gSDLWindow);

	int centered = SDL_WINDOWPOS_CENTERED_DISPLAY(display);
	SDL_SetWindowPosition(gSDLWindow, centered, centered);
	SDL_SyncWindow(gSDLWindow);
}

/*********************** SET FULLSCREEN MODE **********************/

void SetFullscreenMode(bool enforceDisplayPref)
{
	if (!gGamePrefs.fullscreen)
	{
		SDL_SetWindowFullscreen(gSDLWindow, 0);
		SDL_SyncWindow(gSDLWindow);

		if (enforceDisplayPref)
		{
			MoveToPreferredDisplay();
		}
	}
	else
	{
		if (enforceDisplayPref)
		{
			SDL_DisplayID currentDisplay = SDL_GetDisplayForWindow(gSDLWindow);
			SDL_DisplayID desiredDisplay = gGamePrefs.displayNumMinus1 + 1;

			if (currentDisplay != desiredDisplay)
			{
				// We must switch back to windowed mode for the preferred monitor to take effect
				SDL_SetWindowFullscreen(gSDLWindow, false);
				SDL_SyncWindow(gSDLWindow);
				MoveToPreferredDisplay();
			}
		}

		// Enter fullscreen mode
		SDL_SetWindowFullscreen(gSDLWindow, true);
		SDL_SyncWindow(gSDLWindow);
	}

	SDL_GL_SetSwapInterval(gGamePrefs.vsync);
}
