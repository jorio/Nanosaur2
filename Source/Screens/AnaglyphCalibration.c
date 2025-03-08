/*******************************/
/* ANAGLYPH CALIBRATION SCREEN */
/* (c)2022 Iliyas Jorio        */
/*******************************/


/****************************/
/*    EXTERNALS             */
/****************************/

#include "game.h"


/****************************/
/*    PROTOTYPES            */
/****************************/

static void OnChangeAnaglyphMode(void);
static void OnTweakAnaglyphLevels(void);
static int GetAnaglyphDisplayFlags(const MenuItem* mi);
static int GetAnaglyphDisplayFlags_ColorOnly(const MenuItem* mi);
static void DisposeAnaglyphCalibrationScreen(void);
static void MoveAnaglyphScreenHeadObject(ObjNode* theNode);
static void ResetAnaglyphSettings(void);
static int ShouldShowResetAnaglyphSettings(const MenuItem* mi);


/****************************/
/*    VARIABLES             */
/****************************/

static ObjNode* gAnaglyphScreenHead = NULL;

static const MenuItem gInGameAnaglyphMenu[] =
{
	{.id='cali'},
	{kMISpacer, .customHeight=1.5},
	{kMILabel, STR_NO_ANAGLYPH_CALIBRATION_IN_GAME, .customHeight=1.0f},
	{kMISpacer, .customHeight=1.5},
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	//-------------------------------------------------------------------------
	// END SENTINEL

	{ .id=0 }
};

static const MenuItem gAnaglyphMenu[] =
{
	{.id='cali'},
	{
		kMICycler2, STR_3D_GLASSES_MODE,
		.callback = OnChangeAnaglyphMode,
		.cycler =
		{
			.valuePtr = &gGamePrefs.stereoGlassesMode,
			.choices =
			{
				{STR_3D_GLASSES_DISABLED, STEREO_GLASSES_MODE_OFF},
				{STR_3D_GLASSES_ANAGLYPH_COLOR, STEREO_GLASSES_MODE_ANAGLYPH_COLOR},
				{STR_3D_GLASSES_ANAGLYPH_MONO, STEREO_GLASSES_MODE_ANAGLYPH_MONO},
//				{STR_3D_GLASSES_SHUTTER, STEREO_GLASSES_MODE_SHUTTER},
			},
		},
	},
	{
		kMISlider,
		.text = STR_3D_GLASSES_R,
		.callback = OnTweakAnaglyphLevels,
		.getLayoutFlags = GetAnaglyphDisplayFlags,
		.slider=
		{
			.valuePtr=&gGamePrefs.anaglyphCalibrationRed,
			.minValue=0,
			.maxValue=255,
			.equilibrium=DEFAULT_ANAGLYPH_R,
			.increment=5,
			.continuousCallback = false,
		},
	},
	{
		kMISlider,
		.text = STR_3D_GLASSES_G,
		.callback = OnTweakAnaglyphLevels,
		.getLayoutFlags = GetAnaglyphDisplayFlags_ColorOnly,
		.slider=
		{
			.valuePtr=&gGamePrefs.anaglyphCalibrationGreen,
			.minValue=0,
			.maxValue=255,
			.equilibrium=DEFAULT_ANAGLYPH_G,
			.increment=5,
			.continuousCallback = false,
		},
	},
	{
		kMISlider,
		.text = STR_3D_GLASSES_B,
		.callback = OnTweakAnaglyphLevels,
		.getLayoutFlags = GetAnaglyphDisplayFlags,
		.slider=
		{
			.valuePtr=&gGamePrefs.anaglyphCalibrationBlue,
			.minValue=0,
			.maxValue=255,
			.equilibrium=DEFAULT_ANAGLYPH_B,
			.increment=5,
			.continuousCallback = false,
		},
	},
	{
		kMICycler2,
		.text = STR_3D_GLASSES_CHANNEL_BALANCING,
		.callback = OnTweakAnaglyphLevels,
		.getLayoutFlags = GetAnaglyphDisplayFlags_ColorOnly,
		.cycler =
		{
			.valuePtr = &gGamePrefs.doAnaglyphChannelBalancing,
			.choices = { {STR_NO, 0}, {STR_YES, 1}, },
		},
	},
	{
		kMIPick,
		STR_RESTORE_DEFAULT_CONFIG,
		.getLayoutFlags=ShouldShowResetAnaglyphSettings,
		.callback=ResetAnaglyphSettings,
		.customHeight=.7f
	},
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },
	{kMISpacer, .customHeight=8},


	//-------------------------------------------------------------------------
	// END SENTINEL

	{ .id=0 }
};


/******** SET UP ANAGLYPH CALIBRATION SCREEN *********/

void SetUpAnaglyphCalibrationScreen(void)
{
			/* REGISTER MENU */

	if (gPlayNow)
	{
		RegisterMenu(gInGameAnaglyphMenu);		// can't show actual menu in-game
		return;
	}
	else
	{
		RegisterMenu(gAnaglyphMenu);
	}

			/* NUKE AND RELOAD TEXTURES SO THE CURRENT ANAGLYPH FILTER APPLIES TO THEM */

	DisposeAnaglyphCalibrationScreen();

	DisposeGlobalAssets();		// reload the font - won't apply to current menu because it keeps a reference to the
	LoadGlobalAssets();			// old material, but at least the text will look correct when we exit the menu.

	BuildMainMenuObjects();		// rebuild background image

	DisposeSpriteAtlas(ATLAS_GROUP_FONT3);
	LoadSpriteAtlas(ATLAS_GROUP_FONT3, ":Sprites:fonts:swiss", kAtlasLoadFont);

			/* CREATE HEAD SENTINEL - ALL ANAGLYPH CALIB OBJECTS WILL BE CHAINED TO IT */

	NewObjectDefinitionType headSentinelDef =
	{
		.group = CUSTOM_GENRE,
		.scale = 1,
		.slot = SPRITE_SLOT,
		.flags = STATUS_BIT_HIDDEN | STATUS_BIT_MOVEINPAUSE,
		.moveCall = MoveAnaglyphScreenHeadObject,
	};
	ObjNode* anaglyphScreenHead = MakeNewObject(&headSentinelDef);
	gAnaglyphScreenHead = anaglyphScreenHead;


			/* MAKE TEST PATTERN */

	NewObjectDefinitionType imageDef =
	{
		.group		= SPRITE_GROUP_LEVELSPECIFIC,
		.type		= 0,		// 0th image in sprite group
		.coord		= {500,380,0},
		.slot		= SPRITE_SLOT+1,
		.scale		= 250,
	};

	if (IsStereo())
	{
		LoadSpriteGroupFromFile(SPRITE_GROUP_LEVELSPECIFIC, ":Sprites:calibration:calibration000", 0);
	}
	else
	{
		imageDef.scale = 350;
		imageDef.coord = (OGLPoint3D) {320, 350, 0};
		LoadSpriteGroupFromFile(SPRITE_GROUP_LEVELSPECIFIC, ":Sprites:calibration:glasses", 0);
	}

	ObjNode* sampleImage = MakeSpriteObject(&imageDef, true);
	sampleImage->AnaglyphZ = 4.0f;

	AppendNodeToChain(anaglyphScreenHead, sampleImage);


			/* MAKE HELP BLURB */

	NewObjectDefinitionType blurbDef =
	{
		.group		= ATLAS_GROUP_FONT3,
		.scale		= 0.16f,
		.slot		= SPRITE_SLOT+2,
		.coord		= {10, 470, 0},
	};

	char blurb[1024];

	if (IsStereoAnaglyphColor())
	{
		SDL_snprintf(blurb, sizeof(blurb),
				"%s\n \n"
				"1. %s\n \n"
				"2. %s\n \n"
				"3. %s",
				Localize(STR_ANAGLYPH_HELP_WHILEWEARING),
				Localize(STR_ANAGLYPH_HELP_ADJUSTRB),
				Localize(STR_ANAGLYPH_HELP_ADJUSTG),
				Localize(STR_ANAGLYPH_HELP_CHANNELBALANCING));

	}
	else if (IsStereoAnaglyphMono())
	{
		SDL_snprintf(blurb, sizeof(blurb), "%s\n \n%s",
				Localize(STR_ANAGLYPH_HELP_WHILEWEARING),
				Localize(STR_ANAGLYPH_HELP_ADJUSTRB));
	}
	else
	{
		SDL_snprintf(blurb, sizeof(blurb), "%s", Localize(STR_ANAGLYPH_HELP_GRABYOURGLASSES));
		blurbDef.coord = (OGLPoint3D) {320, 470, 0};
	}

	ObjNode* blurbNode = TextMesh_New(blurb, (IsStereo()?kTextMeshAlignLeft:kTextMeshAlignCenter) | kTextMeshAlignBottom, &blurbDef);
	AppendNodeToChain(anaglyphScreenHead, blurbNode);
}


/****************************/
/*    CALLBACKS             */
/****************************/

static void OnChangeAnaglyphMode(void)
{
	gAnaglyphPass = 0;
	for (int i = 0; i < 4; i++)
	{
		glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		SDL_GL_SwapWindow(gSDLWindow);
	}

	SetUpAnaglyphCalibrationScreen();
	LayoutCurrentMenuAgain(true);
}

static void OnTweakAnaglyphLevels(void)
{
	SetUpAnaglyphCalibrationScreen();
	LayoutCurrentMenuAgain(false);
}

static int GetAnaglyphDisplayFlags(const MenuItem* mi)
{
	(void) mi;

	if (IsStereoAnaglyph())
		return 0;
	else
		return kMILayoutFlagHidden;
}

static int GetAnaglyphDisplayFlags_ColorOnly(const MenuItem* mi)
{
	(void) mi;

	if (IsStereoAnaglyphColor())
		return 0;
	else
		return kMILayoutFlagHidden;
}

static void DisposeAnaglyphCalibrationScreen(void)
{
	DisposeSpriteAtlas(ATLAS_GROUP_FONT3);
	DisposeSpriteGroup(SPRITE_GROUP_LEVELSPECIFIC);

	if (gAnaglyphScreenHead)
	{
		DeleteObject(gAnaglyphScreenHead);
		gAnaglyphScreenHead = NULL;
	}
}

static void MoveAnaglyphScreenHeadObject(ObjNode* theNode)
{
	(void) theNode;

	if (GetCurrentMenu() != 'cali')
	{
		DisposeAnaglyphCalibrationScreen();
	}
}

static void ResetAnaglyphSettings(void)
{
	gGamePrefs.doAnaglyphChannelBalancing = true;
	gGamePrefs.anaglyphCalibrationRed = DEFAULT_ANAGLYPH_R;
	gGamePrefs.anaglyphCalibrationGreen = DEFAULT_ANAGLYPH_G;
	gGamePrefs.anaglyphCalibrationBlue = DEFAULT_ANAGLYPH_B;
	SetUpAnaglyphCalibrationScreen();
	LayoutCurrentMenuAgain(true);
}

static int ShouldShowResetAnaglyphSettings(const MenuItem* mi)
{
	(void) mi;
	return IsStereo() ? 0 : kMILayoutFlagHidden;
}
