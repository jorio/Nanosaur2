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
static void MakeSubtitleObjects(int slideNum);


/****************************/
/*    CONSTANTS             */
/****************************/


enum
{
	INTROSTORY_SObjType_PangeaLogo,
	INTROSTORY_SObjType_Image1,
	INTROSTORY_SObjType_Image2,
	INTROSTORY_SObjType_Image3,
	INTROSTORY_SObjType_Image4,
	INTROSTORY_SObjType_Image5,
	INTROSTORY_SObjType_Image6,
	INTROSTORY_SObjType_Image7,
	INTROSTORY_SObjType_NanoLogo,
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
		.narrationSound = EFFECT_NULL,		// effect #
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
		.narrationSound = EFFECT_STORY1,
		.subtitleKey = STR_STORY_1,
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
		.narrationSound = EFFECT_STORY2,
		.subtitleKey = STR_STORY_2,
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
		.narrationSound = EFFECT_STORY3,
		.subtitleKey = STR_STORY_3,
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
		.narrationSound = EFFECT_STORY4,
		.subtitleKey = STR_STORY_4,
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
		.narrationSound = EFFECT_STORY5,
		.subtitleKey = STR_STORY_5,
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
		.narrationSound = EFFECT_STORY6,
		.subtitleKey = STR_STORY_6,
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
		.narrationSound = EFFECT_STORY7,
		.subtitleKey = STR_STORY_7,
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
		.narrationSound = EFFECT_NULL,
	},


};


/********************** DO INTRO STORY **************************/

void DoIntroStoryScreen(void)
{
			/* SETUP */

	SetupIntroStoryScreen();
	MakeFadeEvent(true, 2.0);

	PlaySong(SONG_INTRO, true);


			/* LOOP */

	gEndSlideShow = false;

	while(!gEndSlideShow)
	{
		CalcFramesPerSecond();
		DoSDLMaintenance();
		if (UserWantsOut())
			break;


				/* MOVE */

		MoveObjects();


				/* DRAW */

		OGL_DrawScene(DrawObjects);
	}

			/* FADE OUT */

	OGL_FadeOutScene(DrawObjects, NULL);


			/* CLEANUP */

	FreeIntroStoryScreen();
}



/********************* SETUP INTRO STORY **********************/

static void SetupIntroStoryScreen(void)
{
FSSpec				spec;
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

	static const char* introSlides[NUM_SLIDES] =
	{
		":images:intro0.jpg",
		":images:intro1.jpg",
		":images:intro2.jpg",
		":images:intro3.jpg",
		":images:intro4.jpg",
		":images:intro5.jpg",
		":images:intro6.jpg",
		":images:intro7.jpg",
		":images:intro8.jpg",
	};

	LoadSpriteGroupFromFiles(SPRITE_GROUP_INTROSTORY, NUM_SLIDES, introSlides, 0);
	LoadSpriteAtlas(SPRITE_GROUP_FONT, "subtitlefont", kAtlasLoadFont);		// TODO: hacky -- sprite groups & atlas numbers overlap

	LoadSoundBank(SOUND_BANK_NARRATION);


			/****************/
			/* MAKE OBJECTS */
			/****************/

	BuildSlideShowObjects();
}



/********************** FREE INTRO STORY **********************/

static void FreeIntroStoryScreen(void)
{
	MyFlushEvents();
	DeleteAllObjects();
	FreeAllSkeletonFiles(-1);
	DisposeAllSpriteGroups();
	DisposeSpriteAtlas(SPRITE_GROUP_FONT);	// TODO: hacky -- sprite groups & atlas numbers overlap
	DisposeAllBG3DContainers();
	DisposeTerrain();
	DisposeSoundBank(SOUND_BANK_NARRATION);

	OGL_DisposeGameView();
}





#pragma mark -

/**************** BUILD SLIDE SHOW OBJECTS ********************/

static void BuildSlideShowObjects(void)
{
ObjNode	*slideObj;


	for (int i = 0; i < NUM_SLIDES; i++)
	{
		gNewObjectDefinition.group 		= SPRITE_GROUP_INTROSTORY;
		gNewObjectDefinition.type 		= gSlides[i].spriteNum;
		gNewObjectDefinition.coord.x 	= 640.0f * gSlides[i].x;
		gNewObjectDefinition.coord.y 	= 480.0f * gSlides[i].y;
		gNewObjectDefinition.coord.z 	= 0;
		gNewObjectDefinition.flags 		= STATUS_BIT_NOTEXTUREWRAP | STATUS_BIT_DOUBLESIDED | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOZBUFFER;
		gNewObjectDefinition.slot 		= SPRITE_SLOT - i;
		gNewObjectDefinition.moveCall 	= MoveSlide;
		gNewObjectDefinition.rot 		= gSlides[i].rotz;
		gNewObjectDefinition.scale 	    = gSlides[i].scale;
		slideObj = MakeSpriteObject(&gNewObjectDefinition, true);

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

	if (gSlides[slideNum].narrationSound != EFFECT_NULL		// does it have an effect?
		&& !theNode->HasPlayedEffect)						// has it been played yet?
	{
		theNode->EffectTimer -= fps;
		if (theNode->EffectTimer <= 0.0f)				// is it time to play it?
		{
			PlayEffect(gSlides[slideNum].narrationSound);
			theNode->HasPlayedEffect = true;

			MakeSubtitleObjects(slideNum);
		}
	}
}




static void MoveSubtitle(ObjNode* theNode)
{
	float* delay = &theNode->SpecialF[0];

	if (floorf(*delay * 100) >= 0)
	{
		theNode->StatusBits |= STATUS_BIT_HIDDEN;
		*delay -= gFramesPerSecondFrac;
		theNode->ColorFilter.a = 0;
	}
	else
	{

		theNode->StatusBits &= ~STATUS_BIT_HIDDEN;
		theNode->Health -= gFramesPerSecondFrac;

		if (theNode->Health < 0.25)
			theNode->ColorFilter.a -= gFramesPerSecondFrac * 5;
		else
			theNode->ColorFilter.a += gFramesPerSecondFrac * 5;

		if (theNode->ColorFilter.a > 1)
			theNode->ColorFilter.a = 1;
		else if (theNode->ColorFilter.a < 0)
			theNode->ColorFilter.a = 0;


		if (floorf(theNode->Health * 100) < 0)
		{
			DeleteObject(theNode);
		}
	}
}

static void MakeSubtitleObjects(int slideNum)
{
	if (!gGamePrefs.cutsceneSubtitles)
		return;

	const char* text = Localize(gSlides[slideNum].subtitleKey);

	if (!text)
		return;

	char textCopy[512];
	strncpy(textCopy, text, sizeof(textCopy));

	char* cursor = textCopy;
	int subRow = 0;
	float subDuration = 0;
	float subDelay = 0;

	int textFrame = 0;

	while (cursor && *cursor)
	{
		char* nextLinebreak = strchr(cursor, '\n');

		if (nextLinebreak)
		{
			*nextLinebreak = '\0';
			nextLinebreak++;
		}

		if (*cursor == '#')
		{
			subDelay += subDuration;
			subDuration = 0;
			subRow = 0;

			cursor++;
			while (*cursor)
			{
				subDuration *= 10;
				subDuration += (*cursor - '0');
				cursor++;
			}
			subDuration *= .001f;
		}
		else if (*cursor)
		{
			NewObjectDefinitionType def =
			{
				.coord = {640/2, 480-60 + 22*subRow, 0},
				.scale = 35 * 0.5f,
				.slot = SPRITE_SLOT,
				.group = SPRITE_GROUP_FONT,
				.flags = STATUS_BIT_HIDDEN,
			};

#if 0
			ObjNode* textNode = MakeFontStringObject(cursor, &def, true);
			textNode->SpecialF[0] = subDelay;
			textNode->Health = subDuration;
			textNode->MoveCall = MoveSubtitle;
			//pChain->ChainNode = textNode;
			//pChain = textNode;
#else
			def.scale *= 0.018f;
			ObjNode* textNode = TextMesh_New(cursor, 0, &def);
			textNode->SpecialF[0] = subDelay;
			textNode->Health = subDuration;
			textNode->MoveCall = MoveSubtitle;
			puts(cursor);
#endif

			subRow++;
		}
		else
		{
			subRow++;
		}

		cursor = nextLinebreak;
	}
}
