/*******************************/
/* ANAGLYPH CALIBRATION SCREEN */
/* (c)2022 Iliyas Jorio        */
/*******************************/

// SetUpAnaglyphCalibrationScreen/DisposeAnaglyphCalibrationScreen/
// MoveAnaglyphScreenHeadObject are now in AnaglyphCalibration.swift.
// The menu tree data tables (and the callbacks they embed by designated
// initializer) stay here; see AnaglyphCalibrationInternal.h.

/****************************/
/*    EXTERNALS             */
/****************************/

#include "game.h"
#include "AnaglyphCalibrationInternal.h"

/****************************/
/*    PROTOTYPES            */
/****************************/

static void OnChangeAnaglyphMode(void);
static void OnTweakAnaglyphLevels(void);
static int GetAnaglyphDisplayFlags(const MenuItem* mi);
static int GetAnaglyphDisplayFlags_ColorOnly(const MenuItem* mi);
static void ResetAnaglyphSettings(void);
static int ShouldShowResetAnaglyphSettings(const MenuItem* mi);


/****************************/
/*    VARIABLES             */
/****************************/

const MenuItem gInGameAnaglyphMenu[] =
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

const MenuItem gAnaglyphMenu[] =
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
