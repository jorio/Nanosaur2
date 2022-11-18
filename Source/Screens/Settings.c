/****************************/
/*     SETTINGS MENU        */
/* (c)2022 Iliyas Jorio     */
/****************************/


#include "game.h"
#include "uieffects.h"

static void OnPickLanguage(const MenuItem* mi)
{
	gGamePrefs.language = mi->id;
	LoadLocalizedStrings(gGamePrefs.language);
}

static void OnToggleFullscreen(const MenuItem* mi)
{
	(void) mi;

	SetFullscreenMode(true);
}

static void OnPickResetKeyboardBindings(const MenuItem* mi)
{
	(void) mi;

	ResetDefaultKeyboardBindings();
	PlayEffect_Parms(EFFECT_TURRETEXPLOSION, FULL_CHANNEL_VOLUME/3, FULL_CHANNEL_VOLUME/3, NORMAL_CHANNEL_RATE);
	LayoutCurrentMenuAgain();
}

static void OnPickResetGamepadBindings(const MenuItem* mi)
{
	(void) mi;

	ResetDefaultGamepadBindings();
	PlayEffect_Parms(EFFECT_TURRETEXPLOSION, FULL_CHANNEL_VOLUME/3, FULL_CHANNEL_VOLUME/3, NORMAL_CHANNEL_RATE);
	LayoutCurrentMenuAgain();
}

static void OnPickResetMouseBindings(const MenuItem* mi)
{
	(void) mi;

	ResetDefaultMouseBindings();
	PlayEffect_Parms(EFFECT_TURRETEXPLOSION, FULL_CHANNEL_VOLUME/3, FULL_CHANNEL_VOLUME/3, NORMAL_CHANNEL_RATE);
	LayoutCurrentMenuAgain();
}

static void OnChangeVSync(const MenuItem* mi)
{
	(void) mi;
	SDL_GL_SetSwapInterval(gGamePrefs.vsync);
}

static int ShouldDisplayMSAA(const MenuItem* mi)
{
#if __APPLE__
	// macOS's OpenGL driver doesn't seem to handle MSAA very well,
	// so don't expose the option unless the game was started with MSAA.

	if (gCurrentAntialiasingLevel)
	{
		return 0;
	}
	else
	{
		return kMILayoutFlagHidden;
	}
#else
	return 0;
#endif
}

static void MoveMSAAWarning(ObjNode* theNode)
{
	if (GetCurrentMenu() != 'graf')
	{
		DeleteObject(theNode);
	}
}

static void OnChangeMSAA(const MenuItem* mi)
{
	const long msaaWarningCookie = 'msaa';

	ObjNode* msaaWarning = NULL;
	for (ObjNode* o = gFirstNodePtr; o != NULL; o = o->NextNode)
	{
		if (o->MoveCall == MoveMSAAWarning)
		{
			msaaWarning = o;
			break;
		}
	}

	if (gCurrentAntialiasingLevel == gGamePrefs.antialiasingLevel)
	{
		if (msaaWarning != NULL)
			DeleteObject(msaaWarning);
		return;
	}
	else if (msaaWarning != NULL)
	{
		return;
	}

	NewObjectDefinitionType def =
	{
		.group = SPRITE_GROUP_FONT2,
		.coord = {320, 450, 0},
		.scale = 0.2f,
		.slot = SPRITE_SLOT,
		.flags = STATUS_BIT_MOVEINPAUSE,
		.moveCall = MoveMSAAWarning,
	};

	msaaWarning = TextMesh_New(Localize(STR_ANTIALIASING_CHANGE_WARNING), 0, &def);
	msaaWarning->ColorFilter = (OGLColorRGBA){ 1, 0, 0, 1 };
	msaaWarning->Special[0] = msaaWarningCookie;

	SendNodeToOverlayPane(msaaWarning);

	MakeTwitch(msaaWarning, kTwitchPreset_MenuSelect);
}

static const MenuItem gSettingsMenuTree[] =
{
	{ .id='sett' },
	{kMIPick, STR_GENERAL,			.next='gene'},
	{kMIPick, STR_CONTROLS,			.next='ctrl'},
	{kMIPick, STR_GRAPHICS,			.next='graf'},
	{kMIPick, STR_SOUND,			.next='soun'},
	{kMIPick, STR_LANGUAGE,			.next='lang' },
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	{ .id='gene' },
	{
		kMICycler1, STR_DIFFICULTY,
		.cycler=
		{
			.valuePtr=&gGamePrefs.kiddieMode,
			.choices={ {STR_NORMAL_DIFFICULTY, 0}, {STR_KIDDIE_MODE, 1} },
		}
	},
	{
		kMICycler1, STR_CROSSHAIRS,
		.cycler=
		{
				.valuePtr=&gGamePrefs.showTargetingCrosshairs,
				.choices={ {STR_CROSSHAIRS_OFF, 0}, {STR_CROSSHAIRS_ON, 1} },
		},
	},
	{
		kMICycler1, STR_HUD_POSITION,
		.cycler=
		{
			.valuePtr=&gGamePrefs.force4x3HUD,
			.choices={ {STR_HUD_FULLSCREEN, 0}, {STR_HUD_4X3, 1} },
		},
	},
	{
		kMICycler1, STR_HUD_SCALE,
		.cycler=
		{
			.valuePtr=&gGamePrefs.hudScale,
			.choices={
					{STR_HUD_SCALE_50, 50},
					{STR_HUD_SCALE_60, 60},
					{STR_HUD_SCALE_70, 70},
					{STR_HUD_SCALE_80, 80},
					{STR_HUD_SCALE_90, 90},
					{STR_HUD_SCALE_100, 100},
					{STR_HUD_SCALE_110, 110},
					{STR_HUD_SCALE_120, 120},
					{STR_HUD_SCALE_130, 130},
					{STR_HUD_SCALE_140, 140},
					{STR_HUD_SCALE_150, 150},
					{STR_HUD_SCALE_160, 160},
					{STR_HUD_SCALE_170, 170},
					{STR_HUD_SCALE_180, 180},
					{STR_HUD_SCALE_190, 190},
					{STR_HUD_SCALE_200, 200},
					},
		},
	},
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	{.id='ctrl'},
	{kMIPick, STR_CONFIGURE_KEYBOARD, .next='keyb' },
	{kMIPick, STR_CONFIGURE_GAMEPAD, .next='gpad' },
	{kMIPick, STR_CONFIGURE_MOUSE, .next='mous' },
	{
		kMICycler1, STR_VERTICAL_STEERING,
		.cycler =
		{
			.valuePtr=&gGamePrefs.invertVerticalSteering,
			.choices = { {STR_NORMAL, 0}, {STR_INVERTED, 1} },
		}
	},
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	{.id='graf'},
	{
		kMICycler1, STR_FULLSCREEN,
		.callback=OnToggleFullscreen,
		.cycler=
		{
			.valuePtr=&gGamePrefs.fullscreen,
			.choices={ {STR_OFF, 0}, {STR_ON, 1} },
		},
	},
//	{
//		kMICycler1, STR_PREFERRED_DISPLAY,
////		.callback = OnToggleFullscreen,
////		.getLayoutFlags = ShouldDisplayMonitorCycler,
////		.cycler =
////		{
////			.valuePtr = &gGamePrefs.monitorNum,
////			.isDynamicallyGenerated = true,
////			.generator =
////			{
////				.generateNumChoices = GetNumDisplays,
////				.generateChoiceString = GetDisplayName,
////			},
////		},
//	},
	{
		kMICycler1, STR_VSYNC,
		.callback = OnChangeVSync,
		.cycler =
		{
			.valuePtr = &gGamePrefs.vsync,
			.choices =
			{
				{STR_OFF, 0},
				{STR_ON, 1},
			},
		}
	},
	{
		kMICycler1, STR_ANTIALIASING,
		.callback = OnChangeMSAA,
		.getLayoutFlags = ShouldDisplayMSAA,
		.cycler =
		{
			.valuePtr = &gGamePrefs.antialiasingLevel,
			.choices =
			{
				{STR_OFF, 0},
				{STR_MSAA_2X, 1},
				{STR_MSAA_4X, 2},
				{STR_MSAA_8X, 3},
			},
		},
	},
//	{kMISpacer, .customHeight=.5f },
//	{kMILabel, STR_FULLSCREEN_HINT, .customHeight=.5f },
//	{kMISpacer, .customHeight=.5f },
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	{.id='soun'},
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	{.id='lang'},
	{kMIPick, STR_ENGLISH,	.id=LANGUAGE_ENGLISH,	.callback=OnPickLanguage,	.customHeight=.75f,	.next='BACK'},
	{kMIPick, STR_FRENCH,	.id=LANGUAGE_FRENCH,	.callback=OnPickLanguage,	.customHeight=.75f,	.next='BACK'},
	{kMIPick, STR_GERMAN,	.id=LANGUAGE_GERMAN,	.callback=OnPickLanguage,	.customHeight=.75f,	.next='BACK'},
	{kMIPick, STR_SPANISH,	.id=LANGUAGE_SPANISH,	.callback=OnPickLanguage,	.customHeight=.75f,	.next='BACK'},
	{kMIPick, STR_ITALIAN,	.id=LANGUAGE_ITALIAN,	.callback=OnPickLanguage,	.customHeight=.75f,	.next='BACK'},
	{kMIPick, STR_DUTCH,	.id=LANGUAGE_DUTCH,		.callback=OnPickLanguage,	.customHeight=.75f,	.next='BACK'},
	{kMIPick, STR_SWEDISH,	.id=LANGUAGE_SWEDISH,	.callback=OnPickLanguage,	.customHeight=.75f,	.next='BACK'},
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	{ .id='keyb' },
//	{kMISpacer, .customHeight=.35f },
	{kMILabel, STR_CONFIGURE_KEYBOARD_HELP, .customHeight=.5f },
	{kMISpacer, .customHeight=.4f },
	{kMIKeyBinding, .inputNeed=kNeed_PitchUp },
	{kMIKeyBinding, .inputNeed=kNeed_PitchDown },
	{kMIKeyBinding, .inputNeed=kNeed_YawLeft },
	{kMIKeyBinding, .inputNeed=kNeed_YawRight },
	{kMIKeyBinding, .inputNeed=kNeed_Fire },
	{kMIKeyBinding, .inputNeed=kNeed_Jetpack },
	{kMIKeyBinding, .inputNeed=kNeed_NextWeapon },
	{kMIKeyBinding, .inputNeed=kNeed_PrevWeapon },
	{kMIKeyBinding, .inputNeed=kNeed_Drop},
	{kMIKeyBinding, .inputNeed=kNeed_CameraMode},
	{kMISpacer, .customHeight=.25f },
	{kMIPick, STR_RESET_KEYBINDINGS, .callback=OnPickResetKeyboardBindings, .customHeight=.5f },
	{kMISpacer, .customHeight=.25f },
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	{ .id='gpad' },
//	{kMISpacer, .customHeight=.35f },
	{kMILabel, STR_CONFIGURE_GAMEPAD_HELP, .customHeight=.5f },
	{kMISpacer, .customHeight=.4f },
	{kMIPadBinding, .inputNeed=kNeed_PitchUp },
	{kMIPadBinding, .inputNeed=kNeed_PitchDown },
	{kMIPadBinding, .inputNeed=kNeed_YawLeft },
	{kMIPadBinding, .inputNeed=kNeed_YawRight },
	{kMIPadBinding, .inputNeed=kNeed_Fire},
	{kMIPadBinding, .inputNeed=kNeed_Jetpack },
	{kMIPadBinding, .inputNeed=kNeed_NextWeapon },
	{kMIPadBinding, .inputNeed=kNeed_PrevWeapon },
	{kMIPadBinding, .inputNeed=kNeed_Drop },
	{kMIPadBinding, .inputNeed=kNeed_CameraMode },
	{kMISpacer, .customHeight=.25f },
	{kMIPick, STR_RESET_KEYBINDINGS, .callback=OnPickResetGamepadBindings, .customHeight=.5f },
	{kMISpacer, .customHeight=.25f },
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	{ .id='mous' },
//	{kMISpacer, .customHeight=.35f },
//	{kMILabel, STR_CONFIGURE_KEYBOARD_HELP, .customHeight=.5f },
	{
		kMICycler1, STR_MOUSE_SENSITIVITY,
		.cycler=
		{
			.valuePtr=&gGamePrefs.mouseSensitivityLevel,
			.choices=
			{
				{STR_MOUSE_SENSITIVITY_1, 1},
				{STR_MOUSE_SENSITIVITY_2, 2},
				{STR_MOUSE_SENSITIVITY_3, 3},
				{STR_MOUSE_SENSITIVITY_4, 4},
				{STR_MOUSE_SENSITIVITY_5, 5},
				{STR_MOUSE_SENSITIVITY_6, 6},
				{STR_MOUSE_SENSITIVITY_7, 7},
				{STR_MOUSE_SENSITIVITY_8, 8},
				{STR_MOUSE_SENSITIVITY_9, 9},
				{STR_MOUSE_SENSITIVITY_10, 10},
			},
		},
	},
	{kMISpacer, .customHeight=.25f },
	{kMIMouseBinding, .inputNeed=kNeed_Fire },
	{kMIMouseBinding, .inputNeed=kNeed_Jetpack },
	{kMIMouseBinding, .inputNeed=kNeed_Drop },
	{kMIMouseBinding, .inputNeed=kNeed_NextWeapon },
	{kMIMouseBinding, .inputNeed=kNeed_PrevWeapon },
	{kMIMouseBinding, .inputNeed=kNeed_CameraMode },
	{kMISpacer, .customHeight=.25f },
	{kMIPick, STR_RESET_KEYBINDINGS, .callback=OnPickResetMouseBindings, .customHeight=.5f },
	{kMISpacer, .customHeight=.25f },
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },




	{ .id=0 }
};

void RegisterSettingsMenu(void)
{
	RegisterMenu(gSettingsMenuTree);
}
