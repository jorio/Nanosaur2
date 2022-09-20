/****************************/
/*   	WIN SCREEN.C		*/
/* (c)2004 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/

#include "game.h"

extern	float				gFramesPerSecondFrac,gFramesPerSecond,gGlobalTransparency;
extern	FSSpec		gDataSpec;
extern	Boolean		gGameOver;
extern	NewObjectDefinitionType	gNewObjectDefinition;
extern	Boolean		gSongPlayingFlag,gDisableAnimSounds;
extern	PrefsType	gGamePrefs;
extern	OGLSetupOutputType		*gGameViewInfoPtr;
extern	SparkleType	gSparkles[MAX_SPARKLES];
extern	OGLPoint3D	gCoord;
extern	OGLVector3D	gDelta;
extern	u_long			gGlobalMaterialFlags;
extern	float			gGammaFadePercent, gTerrainPolygonSize;
extern	OGLBoundingBox			gObjectGroupBBoxList[MAX_BG3D_GROUPS][MAX_OBJECTS_IN_GROUP];
extern	u_long				gAutoFadeStatusBits;
extern	float		gAutoFadeStartDist,gAutoFadeEndDist,gAutoFadeRange_Frac;

/****************************/
/*    PROTOTYPES            */
/****************************/

static void SetupWinScreen(void);
static void FreeWinScreen(void);
static void BuildSlideShowObjects(void);
static void MoveSlide(ObjNode *theNode);


/****************************/
/*    CONSTANTS             */
/****************************/


enum
{
	WIN_SObjType_Win
};


#define	NUM_SLIDES	1

#define	SLIDE_FADE_RATE	.8f


/*********************/
/*    VARIABLES      */
/*********************/

static	Boolean		gEndSlideShow;

static Boolean		gSlideActive[NUM_SLIDES];


static SlideType 	gSlides[NUM_SLIDES] =
{
			/* WIN PAGE */
	{
		WIN_SObjType_Win,			// sprite #
		.9, .5,								// x / y
		1200,								// scale
		-.1,									// rotz
		0,									// alpha
		16.0,								// delay to next
		16.0,								// delay to fade
		-23.0f,								// zoom speed
		-23,0,								// dx / dy
		.01,									// drot
		.5,									// delay to play effect
		nil, //":audio:intro:story1.m4a",		// narration pathname
	},


};


/********************** DO WIN SCREEN **************************/

void DoWinScreen(void)
{

	GammaFadeOut();

			/* SETUP */

	SetupWinScreen();
	MakeFadeEvent(true, 2.0);

	PlaySong(SONG_WIN, false);


			/* LOOP */

	gEndSlideShow = false;

	while(!gEndSlideShow)
	{
		CalcFramesPerSecond();
		UpdateKeyMap();
//		if (AreAnyNewKeysPressed())
//			break;


				/* MOVE */

		MoveObjects();


				/* DRAW */

		OGL_DrawScene(gGameViewInfoPtr, DrawObjects);

	}


			/* CLEANUP */

	GammaFadeOut();
	FreeWinScreen();
}



/********************* SETUP WIN SCREEN **********************/

static void SetupWinScreen(void)
{
FSSpec				spec;
OGLSetupInputType	viewDef;
short				i;


			/**************/
			/* SETUP VIEW */
			/**************/

	OGL_NewViewDef(&viewDef);

	viewDef.camera.fov 			= .8;

	viewDef.camera.hither 		= 10;
	viewDef.camera.yon 			= 1000;

	viewDef.styles.useFog			= false;
	viewDef.view.clearColor.r 		= 0;
	viewDef.view.clearColor.g 		= 0;
	viewDef.view.clearColor.b		= 0;

	viewDef.view.clearBackBuffer	= true;

	OGL_SetupWindow(&viewDef, &gGameViewInfoPtr);


				/************/
				/* LOAD ART */
				/************/

			/* LOAD SPRITES */

	FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ":sprites:Win.sprites", &spec);
	LoadSpriteFile(&spec, SPRITE_GROUP_INTROSTORY, gGameViewInfoPtr);



			/****************/
			/* MAKE OBJECTS */
			/****************/

	BuildSlideShowObjects();




		/* PRIME STREAMING AUDIO */


	for (i = 0; i < NUM_SLIDES; i++)
	{
		if (gSlides[i].narrationFile != nil)
		{
			StreamAudioFile(gSlides[i].narrationFile, i, 1.8, false);
		}
	}
}



/********************** FREE WIN SCREEN **********************/

static void FreeWinScreen(void)
{
	KillAudioStream(-1);

	MyFlushEvents();
	DeleteAllObjects();
	FreeAllSkeletonFiles(-1);
	DisposeAllSpriteGroups();
	DisposeAllBG3DContainers();
	DisposeTerrain();

	OGL_DisposeWindowSetup(&gGameViewInfoPtr);
}





#pragma mark -

/**************** BUILD SLIDE SHOW OBJECTS ********************/

static void BuildSlideShowObjects(void)
{
short	i;
ObjNode	*slideObj;


	for (i = 0; i < NUM_SLIDES; i++)
	{
		gNewObjectDefinition.group 		= SPRITE_GROUP_INTROSTORY;
		gNewObjectDefinition.type 		= gSlides[i].spriteNum;
		gNewObjectDefinition.coord.x 	= 640.0f * gSlides[i].x;
		gNewObjectDefinition.coord.y 	= 640.0f * gGameViewInfoPtr->windowAspectRatio * gSlides[i].y;
		gNewObjectDefinition.coord.z 	= 0;
		gNewObjectDefinition.flags 		= STATUS_BIT_NOTEXTUREWRAP | STATUS_BIT_DOUBLESIDED | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOZBUFFER;
		gNewObjectDefinition.slot 		= SPRITE_SLOT - i;
		gNewObjectDefinition.moveCall 	= MoveSlide;
		gNewObjectDefinition.rot 		= gSlides[i].rotz;
		gNewObjectDefinition.scale 	    = gSlides[i].scale;
		slideObj = MakeSpriteObject(&gNewObjectDefinition, gGameViewInfoPtr, true);

		slideObj->Kind = i;

		slideObj->StatusBits |= STATUS_BIT_HIDDEN;			// hide all slides @ start

		slideObj->ColorFilter.a = gSlides[i].alpha;

		if (i == 0)							// (this sets which frame we start on)
			gSlideActive[i] = true;
		else
			gSlideActive[i] = false;

		slideObj->Timer = gSlides[i].delayToNext;			// set time to show before starting next slide
		slideObj->Health = gSlides[i].delayToVanish;		// time to show before start fadeout of this slide

		slideObj->ZoomSpeed	= gSlides[i].zoomSpeed;
		slideObj->Delta.x 	= gSlides[i].dx;
		slideObj->Delta.y 	= gSlides[i].dy;
		slideObj->DeltaRot.z = gSlides[i].drot;
		slideObj->EffectTimer = gSlides[i].delayUntilEffect;

		slideObj->AnaglyphZ = -10;						// make appear deep in the monitor
	}
}


/****************** MOVE SLIDE ***********************/

static void MoveSlide(ObjNode *theNode)
{
float	fps = gFramesPerSecondFrac;
short	slideNum = theNode->Kind;

	if (!gSlideActive[slideNum])							// is this slide still waiting?
		return;

	theNode->StatusBits &= ~STATUS_BIT_HIDDEN;


			/* MOVE IT */

	theNode->Coord.x += fps * theNode->Delta.x;
	theNode->Coord.y += fps * theNode->Delta.y;

	theNode->Scale.x = theNode->Scale.y += fps * theNode->ZoomSpeed;
	theNode->Rot.y += fps * theNode->DeltaRot.z;


			/* SEE IF TIME TO TRIGGER NEXT SLIDE */

	theNode->Timer -= fps;
	if (theNode->Timer <= 0.0f)
	{
		slideNum++;
		if (slideNum < NUM_SLIDES)
			gSlideActive[slideNum] = true;
	}


		/* SEE IF FADE OUT/IN */

	theNode->Health	-= fps;
	if (theNode->Health < 0.0f)
	{
		theNode->ColorFilter.a -= fps * SLIDE_FADE_RATE;
		if (theNode->ColorFilter.a <= .0f)
		{
			theNode->ColorFilter.a = 0;
			if (theNode->Timer <= 0.0f)				// dont delete until the other timer is also done
			{
				DeleteObject(theNode);
				if (slideNum >= NUM_SLIDES)			// was that the last slide?
					gEndSlideShow = true;
				return;
			}
		}
	}
			/* FADE IN */
	else
	{
		theNode->ColorFilter.a += fps * SLIDE_FADE_RATE;
		if (theNode->ColorFilter.a > 1.0f)
			theNode->ColorFilter.a = 1.0f;
	}


			/* PLAY EFFECT? */

	if (gSlides[slideNum].narrationFile != nil)				// does it have an effect?
	{
		if (!theNode->HasPlayedEffect)						// has it been played yet?
		{
			theNode->EffectTimer -= fps;
			if (theNode->EffectTimer <= 0.0f)				// is it time to play it?
			{
				StartAudioStream(slideNum);
				theNode->HasPlayedEffect = true;
			}
		}
	}
}





