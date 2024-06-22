/****************************/
/*   	WIN SCREEN.C		*/
/* (c)2004 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/

#include "game.h"

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
		.narrationSound = EFFECT_NULL,
	},


};


/********************** DO WIN SCREEN **************************/

void DoWinScreen(void)
{
			/* SETUP */

	SetupWinScreen();
	MakeFadeEvent(kFadeFlags_In, 2.0);

	PlaySong(SONG_WIN, false);


			/* LOOP */

	gEndSlideShow = false;

	while(!gEndSlideShow)
	{
		CalcFramesPerSecond();
		DoSDLMaintenance();

				/* MOVE */

		MoveObjects();

				/* DRAW */

		OGL_DrawScene(DrawObjects);
	}

	OGL_FadeOutScene(DrawObjects, NULL);

			/* CLEANUP */

	FreeWinScreen();
}



/********************* SETUP WIN SCREEN **********************/

static void SetupWinScreen(void)
{
OGLSetupInputType	viewDef;


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

	OGL_SetupGameView(&viewDef);


				/************/
				/* LOAD ART */
				/************/

			/* LOAD SPRITES */

	LoadSpriteGroupFromFile(SPRITE_GROUP_LEVELSPECIFIC, ":Sprites:story:win", 0);



			/****************/
			/* MAKE OBJECTS */
			/****************/

	BuildSlideShowObjects();
}



/********************** FREE WIN SCREEN **********************/

static void FreeWinScreen(void)
{
	MyFlushEvents();
	DeleteAllObjects();
	FreeAllSkeletonFiles(-1);
	DisposeSpriteGroup(SPRITE_GROUP_LEVELSPECIFIC);
	DisposeAllBG3DContainers();
	DisposeTerrain();

	OGL_DisposeGameView();
}





#pragma mark -

/**************** BUILD SLIDE SHOW OBJECTS ********************/

static void BuildSlideShowObjects(void)
{
short	i;
ObjNode	*slideObj;


	for (i = 0; i < NUM_SLIDES; i++)
	{
		NewObjectDefinitionType def =
		{
			.group 		= SPRITE_GROUP_LEVELSPECIFIC,
			.type 		= gSlides[i].spriteNum,
			.coord.x 	= 640.0f * gSlides[i].x,
			.coord.y 	= 480.0f * gSlides[i].y,
			.coord.z 	= 0,
			.flags 		= STATUS_BIT_NOTEXTUREWRAP | STATUS_BIT_DOUBLESIDED | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOZBUFFER,
			.slot 		= SPRITE_SLOT - i,
			.moveCall 	= MoveSlide,
			.rot 		= gSlides[i].rotz,
			.scale 	    = gSlides[i].scale,
		};
		slideObj = MakeSpriteObject(&def, true);

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
}





