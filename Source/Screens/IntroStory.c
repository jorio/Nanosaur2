/****************************/
/*   	INTRO STORY.C		*/
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

static void SetupIntroStoryScreen(void);
static void FreeIntroStoryScreen(void);
static void BuildSlideShowObjects(void);
static void MoveSlide(ObjNode *theNode);


/****************************/
/*    CONSTANTS             */
/****************************/


enum
{
	INTROSTORY_SObjType_Image1,
	INTROSTORY_SObjType_Image2,
	INTROSTORY_SObjType_Image3,
	INTROSTORY_SObjType_Image4,
	INTROSTORY_SObjType_Image5,
	INTROSTORY_SObjType_Image6,
	INTROSTORY_SObjType_Image7,

	INTROSTORY_SObjType_NanoLogo,
	INTROSTORY_SObjType_PangeaLogo
};

#define	NUM_SLIDES	9

#define	SLIDE_FADE_RATE	.8f


/*********************/
/*    VARIABLES      */
/*********************/


static	Boolean		gEndSlideShow;

static Boolean	gSlideActive[NUM_SLIDES];


static SlideType gSlides[NUM_SLIDES] =
{
			/* PANGEA LOGO */
	{
		INTROSTORY_SObjType_PangeaLogo,		// sprite #
		.5, .5,								// x / y
		250,								// scale
		0,									// rotz
		0,									// alpha
		4.0,								// delay to next
		2.5,								// delay to fade
		20.0f,								// zoom speed
		0,0,								// dx / dy
		0,									// drot
		0,									// delay to play effect
		nil,								// effect #
	},


			/* IN THE YEAR 4222... */
	{
		INTROSTORY_SObjType_Image1,			// sprite #
		.5, .5,								// x / y
		500,								// scale
		-.2,								// rotz
		0,									// alpha
		9.0,								// delay to next
		9.0,								// delay to fade
		35.0f,								// zoom speed
		0,0,								// dx / dy
		.03,								// drot
		.5,									// delay to play effect
		":audio:intro:story1.m4a",		// narration pathname
	},


			/* HIS MISSION WAS TO... */
	{
		INTROSTORY_SObjType_Image2,			// sprite #
		-.1, .8,							// x / y
		350,								// scale
		.2,									// rotz
		0,									// alpha
		12.0,								// delay to next
		12.0,								// delay to fade
		35.0f,								// zoom speed
		35,-12,								// dx / dy
		-.02,								// drot
		1.0,								// delay to play effect
		":audio:intro:story2.m4a",		// narration pathname
	},

		/* THE MISSION WAS A SUCCESS */
	{
		INTROSTORY_SObjType_Image3,			// sprite #
		.9, .5,							// x / y
		400,								// scale
		-.3,									// rotz
		0,									// alpha
		8.0,								// delay to next
		7.5,								// delay to fade
		35.0f,								// zoom speed
		-40,0,								// dx / dy
		.05,								// drot
		1.0,								// delay to play effect
		":audio:intro:story3.m4a",		// narration pathname
	},

			/* BUT BEFORE... */
	{
		INTROSTORY_SObjType_Image4,			// sprite #
		.5, .5,								// x / y
		350,								// scale
		0,									// rotz
		0,									// alpha
		8.0,								// delay to next
		8.0,								// delay to fade
		35.0f,								// zoom speed
		0,0,								// dx / dy
		0,									// drot
		1.0,								// delay to play effect
		":audio:intro:story4.m4a",		// narration pathname
	},

		/* THE EGGS WERE TAKEN TO... */
	{
		INTROSTORY_SObjType_Image5,			// sprite #
		1.0, .5,								// x / y
		500,								// scale
		-.2,								// rotz
		0,									// alpha
		14.0,								// delay to next
		12.0,								// delay to fade
		20.0f,								// zoom speed
		-40,0,								// dx / dy
		.02,								// drot
		1.0,								// delay to play effect
		":audio:intro:story5.m4a",		// narration pathname
	},

		/* BUT THE REBELS LEFT... */
	{
		INTROSTORY_SObjType_Image6,			// sprite #
		.5, .5,								// x / y
		350,								// scale
		.2,									// rotz
		0,									// alpha
		8.5,								// delay to next
		8.5,								// delay to fade
		30.0f,								// zoom speed
		0,0,								// dx / dy
		-.02,								// drot
		1.0,								// delay to play effect
		":audio:intro:story6.m4a",		// narration pathname
	},


			/* THIS HATCHLING... */
	{
		INTROSTORY_SObjType_Image7,			// sprite #
		.5, 0,								// x / y
		400,								// scale
		.3,									// rotz
		0,									// alpha
		9.0,								// delay to next
		9.0,								// delay to fade
		40.0f,								// zoom speed
		0,20,								// dx / dy
		-.05,								// drot
		1.0,								// delay to play effect
		":audio:intro:story7.m4a",		// narration pathname
	},


	{
		INTROSTORY_SObjType_NanoLogo,		// sprite #
		.5, .5,								// x / y
		300,								// scale
		0,									// rotz
		0,									// alpha
		8.0,								// delay to next
		5.0,								// delay to fade
		30.0f,								// zoom speed
		0,0,								// dx / dy
		0,									// drot
		0.0,								// delay to play effect
		nil,								// narration pathname
	},


};


/********************** DO INTRO STORY **************************/

void DoIntroStoryScreen(void)
{

	GammaFadeOut();

			/* SETUP */

	SetupIntroStoryScreen();
	MakeFadeEvent(true, 2.0);

	PlaySong(SONG_INTRO, true);


			/* LOOP */

	gEndSlideShow = false;

	while(!gEndSlideShow)
	{
		CalcFramesPerSecond();
		UpdateKeyMap();
		if (AreAnyNewKeysPressed())
			break;


				/* MOVE */

		MoveObjects();


				/* DRAW */

		OGL_DrawScene(gGameViewInfoPtr, DrawObjects);

	}


			/* CLEANUP */

	GammaFadeOut();
	FreeIntroStoryScreen();
}



/********************* SETUP INTRO STORY **********************/

static void SetupIntroStoryScreen(void)
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

	FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ":sprites:IntroStory.sprites", &spec);
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



/********************** FREE INTRO STORY **********************/

static void FreeIntroStoryScreen(void)
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
bool	isLastSlide = slideNum >= NUM_SLIDES-1;

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
	if (!isLastSlide && theNode->Timer <= 0.0f)
	{
		gSlideActive[slideNum + 1] = true;
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
				if (isLastSlide)					// was that the last slide?
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





