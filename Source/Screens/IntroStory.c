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
	NUM_SLIDES
};

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
	MakeFadeEvent(kFadeFlags_In, 2.0);

	PlaySong(SONG_INTRO, true);


			/* LOOP */

	gEndSlideShow = false;

	while(!gEndSlideShow)
	{
		CalcFramesPerSecond();
		DoSDLMaintenance();
		if (UserWantsOut())
		{
			gGameViewInfoPtr->fadeSound = true;
			break;
		}


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

	LoadSpriteGroupFromSeries(SPRITE_GROUP_LEVELSPECIFIC, NUM_SLIDES, "story");
	LoadSpriteAtlas(ATLAS_GROUP_FONT3, ":Sprites:fonts:swiss", kAtlasLoadFont);

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
	DisposeSpriteGroup(SPRITE_GROUP_LEVELSPECIFIC);
	DisposeSpriteAtlas(ATLAS_GROUP_FONT3);
	DisposeAllBG3DContainers();
	DisposeTerrain();
	DisposeSoundBank(SOUND_BANK_NARRATION);

	OGL_DisposeGameView();
}





#pragma mark -

/**************** BUILD SLIDE SHOW OBJECTS ********************/


static void DrawBottomGradient(ObjNode* theNode)
{
	OGL_PushState();
	SetInfobarSpriteState(0, 1);
	OGL_DisableTexture2D();
	OGL_EnableBlend();

	float y = 320;
	glBegin(GL_QUADS);
	glColor4f(0,0,0,0); glVertex2f(gLogicalRect.left, y); glVertex2f(gLogicalRect.right, y);
	glColor4f(0,0,0,1); glVertex2f(gLogicalRect.right, gLogicalRect.bottom); glVertex2f(gLogicalRect.left, gLogicalRect.bottom);
	glEnd();
	OGL_PopState();
}


static void BuildSlideShowObjects(void)
{
ObjNode	*slideObj;


	for (int i = 0; i < NUM_SLIDES; i++)
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
			.scale		= gSlides[i].scale,
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


	if (gGamePrefs.cutsceneSubtitles)
	{
		NewObjectDefinitionType gradientDef =
		{
			.genre		= CUSTOM_GENRE,
			.coord		= {0, 0, 0},
			.slot		= SPRITE_SLOT,
			.scale		= 1,
			.drawCall	= DrawBottomGradient,
		};
		MakeNewObject(&gradientDef);
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
			int volume = FULL_CHANNEL_VOLUME*175/100;
			PlayEffect_Parms(gSlides[slideNum].narrationSound, volume, volume, NORMAL_CHANNEL_RATE);
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
	snprintf(textCopy, sizeof(textCopy), "%s", text);

	char* cursor = textCopy;
	int subRow = 0;
	float subDuration = 0;
	float subDelay = 0;

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
				.scale = 35 * 0.5f * 0.015f,
				.slot = SPRITE_SLOT,
				.group = ATLAS_GROUP_FONT3,
				.flags = STATUS_BIT_HIDDEN,
			};

			ObjNode* textNode = TextMesh_New(cursor, 0, &def);
			textNode->SpecialF[0] = subDelay;
			textNode->Health = subDuration;
			textNode->MoveCall = MoveSubtitle;
			textNode->ColorFilter = (OGLColorRGBA){1,1,0.7,1};

			subRow++;
		}
		else
		{
			subRow++;
		}

		cursor = nextLinebreak;
	}
}
