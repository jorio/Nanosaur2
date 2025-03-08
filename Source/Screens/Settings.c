/****************************/
/*     SETTINGS MENU        */
/* (c)2022 Iliyas Jorio     */
/****************************/


#include "game.h"
#include "uieffects.h"
#include "miscscreens.h"
#include "version.h"

static int DisableMenuEntryInGame(const MenuItem* mi)
{
	(void) mi;
	return gPlayNow ? kMILayoutFlagDisabled : 0;
}

static int HideMenuEntryInGame(const MenuItem* mi)
{
	(void) mi;
	return gPlayNow ? kMILayoutFlagHidden : 0;
}

static int ShowMenuEntryInGameOnly(const MenuItem* mi)
{
	(void) mi;
	return gPlayNow ? 0 : kMILayoutFlagHidden;
}

static void OnEnterSettingsMenu(void)
{
	// When re-entering the settings root menu, save the prefs in case the user touched any settings
	// (SavePrefs is smart and won't actually hit the disk if the prefs didn't change)
	SavePrefs();
}

static void OnPickLanguage(void)
{
	int language = gGamePrefs.language;

	gGamePrefs.cutsceneSubtitles = (language != LANGUAGE_ENGLISH) || (!IsNativeEnglishSystem());

	LoadLocalizedStrings(language);

	LayoutCurrentMenuAgain(true);
}

static void OnToggleFullscreen(void)
{
	SetFullscreenMode(true);
}

static void OnPickResetKeyboardBindings(void)
{
	ResetDefaultKeyboardBindings();
	PlayEffect_Parms(EFFECT_TURRETEXPLOSION, FULL_CHANNEL_VOLUME/3, FULL_CHANNEL_VOLUME/3, NORMAL_CHANNEL_RATE);
	LayoutCurrentMenuAgain(true);
}

static void OnPickResetGamepadBindings(void)
{
	ResetDefaultGamepadBindings();
	PlayEffect_Parms(EFFECT_TURRETEXPLOSION, FULL_CHANNEL_VOLUME/3, FULL_CHANNEL_VOLUME/3, NORMAL_CHANNEL_RATE);
	LayoutCurrentMenuAgain(true);
}

static void OnPickResetMouseBindings(void)
{
	ResetDefaultMouseBindings();
	PlayEffect_Parms(EFFECT_TURRETEXPLOSION, FULL_CHANNEL_VOLUME/3, FULL_CHANNEL_VOLUME/3, NORMAL_CHANNEL_RATE);
	LayoutCurrentMenuAgain(true);
}

static void TestGamepadRumble(void)
{
	Rumble(1, 1, 200, ANY_PLAYER);
}

static void MoveTemporaryGraphicsMenuText(ObjNode* theNode)
{
	if (GetCurrentMenu() != 'graf')
	{
		DeleteObject(theNode);
	}
}

static void MoveTemporaryGamepadMenuText(ObjNode* theNode)
{
	if (GetCurrentMenu() != 'gpad')
	{
		DeleteObject(theNode);
	}
}

static void OnChangeVSync(void)
{
	SDL_GL_SetSwapInterval(gGamePrefs.vsync);
}

static int ShouldDisplayMonitorCycler(const MenuItem* mi)
{
	(void) mi;

	// Expose the option if we have more than one display
	return (GetNumDisplays() <= 1) ? kMILayoutFlagHidden : 0;
}

static const char* GetDisplayName(Byte value)
{
	static char textBuf[8];
	SDL_snprintf(textBuf, sizeof(textBuf), "%d", value + 1);
	return textBuf;
}

static void OnChangeMSAA(void)
{
	const long msaaWarningCookie = 'msaa';

	ObjNode* msaaWarning = NULL;
	for (ObjNode* o = gFirstNodePtr; o != NULL; o = o->NextNode)
	{
		if (o->MoveCall == MoveTemporaryGraphicsMenuText
			&& o->Special[0] == msaaWarningCookie)
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
		.group = ATLAS_GROUP_FONT2,
		.coord = {320, 435, 0},
		.scale = 0.25f,
		.slot = SPRITE_SLOT,
		.flags = STATUS_BIT_MOVEINPAUSE,
		.moveCall = MoveTemporaryGraphicsMenuText,
	};

	msaaWarning = TextMesh_New(Localize(STR_ANTIALIASING_CHANGE_WARNING), 0, &def);
	msaaWarning->ColorFilter = (OGLColorRGBA){ 1, 0, 0, 1 };
	msaaWarning->Special[0] = msaaWarningCookie;

	SendNodeToOverlayPane(msaaWarning);

	MakeTwitch(msaaWarning, kTwitchPreset_MenuSelect);
}

static void OnEnterGraphicsMenu(void)
{
	NewObjectDefinitionType def =
	{
		.coord = {320, 480 - 8, 0},
		.group = ATLAS_GROUP_FONT2,
		.scale = 0.15,
		.slot = SPRITE_SLOT,
		.moveCall = MoveTemporaryGraphicsMenuText,
		.flags = STATUS_BIT_MOVEINPAUSE,
	};

	char rendererInfo[256];
	SDL_snprintf(rendererInfo, sizeof(rendererInfo), "%s, OpenGL %s, %s",
		(const char*)glGetString(GL_RENDERER),
		(const char*)glGetString(GL_VERSION),
		SDL_GetCurrentVideoDriver());

	ObjNode* rendererText = TextMesh_New(rendererInfo, kTextMeshSmallCaps | kTextMeshAlignBottom, &def);
	rendererText->ColorFilter.a = 0.75f;
	SendNodeToOverlayPane(rendererText);

	// Create MSAA warning text if needed
	OnChangeMSAA();
}

static void OnEnterGamepadMenu(void)
{
	SDL_Gamepad* sdlGamepad = GetGamepad(0);

	const char* controllerName = Localize(STR_NO_GAMEPAD_DETECTED);

	if (sdlGamepad != NULL)
	{
		controllerName = SDL_GetGamepadName(sdlGamepad);
	}

	NewObjectDefinitionType def =
	{
		.coord = {320, 480 - 8, 0},
		.group = ATLAS_GROUP_FONT2,
		.scale = 0.15,
		.slot = SPRITE_SLOT,
		.moveCall = MoveTemporaryGamepadMenuText,
		.flags = STATUS_BIT_MOVEINPAUSE,
	};

	ObjNode* controllerText = TextMesh_New(controllerName, kTextMeshSmallCaps | kTextMeshAlignBottom, &def);
	controllerText->ColorFilter.a = 0.75f;
	SendNodeToOverlayPane(controllerText);
}

static const MenuItem gSettingsMenuTree[] =
{
	//-------------------------------------------------------------------------
	// SETTINGS ROOT MENU

	{ .id='sett', .callback=OnEnterSettingsMenu},
	{kMILabel, .text=STR_SETTINGS},
	{kMISpacer, .customHeight=.3f},
	{
		kMICycler1, STR_DIFFICULTY,
		.cycler=
		{
			.valuePtr=&gGamePrefs.kiddieMode,
			.choices={ {STR_NORMAL_DIFFICULTY, 0}, {STR_KIDDIE_MODE, 1} },
		}
	},
	{kMIPick, STR_CONTROLS,			.next='ctrl'},
	{kMIPick, STR_GRAPHICS,			.next='graf'},
	{kMIPick, STR_SOUND,			.next='soun'},
	{kMIPick, STR_INTERFACE,		.next='ifac'},
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	//-------------------------------------------------------------------------
	// INTERFACE

	{ .id='ifac' },
	{kMILabel, .text=STR_INTERFACE},
	{kMISpacer, .customHeight=.3f},
	{
		kMICycler2, STR_LANGUAGE,
		.callback=OnPickLanguage,
		.cycler=
		{
			.valuePtr=&gGamePrefs.language,
			.choices={
					{STR_ENGLISH, LANGUAGE_ENGLISH},
					{STR_FRENCH, LANGUAGE_FRENCH},
					{STR_GERMAN, LANGUAGE_GERMAN},
					{STR_SPANISH, LANGUAGE_SPANISH},
					{STR_ITALIAN, LANGUAGE_ITALIAN},
					{STR_DUTCH, LANGUAGE_DUTCH},
					{STR_SWEDISH, LANGUAGE_SWEDISH},
					{STR_RUSSIAN, LANGUAGE_RUSSIAN},
			},
		},
	},
	{
		kMICycler2, STR_CROSSHAIRS,
		.cycler=
		{
			.valuePtr=&gGamePrefs.showTargetingCrosshairs,
			.choices={ {STR_CROSSHAIRS_OFF, 0}, {STR_CROSSHAIRS_ON, 1} },
		},
	},
	{
		kMICycler2, STR_HUD_POSITION,
		.cycler=
		{
			.valuePtr=&gGamePrefs.force4x3HUD,
			.choices={ {STR_HUD_FULLSCREEN, 0}, {STR_HUD_4X3, 1} },
		},
	},
	{
		kMISlider, STR_HUD_SCALE,
		.slider=
		{
			.valuePtr = &gGamePrefs.hudScale,
			.minValue = 50,
			.maxValue = 200,
			.equilibrium = 100,
			.increment = 5,
			.continuousCallback = true,
		},
	},
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	//-------------------------------------------------------------------------
	// CONTROLS

	{.id='ctrl'},
	{kMILabel, .text=STR_CONTROLS},
	{kMISpacer, .customHeight=.3f},
	{kMIPick, STR_CONFIGURE_GAMEPAD, .next='gpad' },
	{kMIPick, STR_CONFIGURE_KEYBOARD, .next='keyb' },
	{kMIPick, STR_CONFIGURE_MOUSE, .next='mous' },
	{
		kMICycler2, STR_VERTICAL_STEERING,
		.cycler =
		{
			.valuePtr=&gGamePrefs.invertVerticalSteering,
			.choices = { {STR_NORMAL, 0}, {STR_INVERTED, 1} },
		}
	},
	{
		kMISlider, STR_GAMEPAD_RUMBLE,
		.callback = TestGamepadRumble,
		.slider =
		{
			.equilibrium = 100,
			.increment = 25,
			.minValue = 0,
			.maxValue = 100,
			.valuePtr = &gGamePrefs.rumbleIntensity,
			.continuousCallback = false,
		},
	},
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	//-------------------------------------------------------------------------
	// GRAPHICS

	{.id='graf', .callback=OnEnterGraphicsMenu},
	{kMILabel, .text=STR_GRAPHICS},
	{kMISpacer, .customHeight=.3f},
	{
		kMICycler2, STR_FULLSCREEN,
		.callback=OnToggleFullscreen,
		.cycler=
		{
			.valuePtr=&gGamePrefs.fullscreen,
			.choices={ {STR_NO, 0}, {STR_YES, 1} },
		},
	},
	{
		kMICycler2, STR_PREFERRED_DISPLAY,
		.callback = OnToggleFullscreen,
		.getLayoutFlags = ShouldDisplayMonitorCycler,
		.cycler =
		{
			.valuePtr = &gGamePrefs.displayNumMinus1,
			.isDynamicallyGenerated = true,
			.generator =
			{
				.generateNumChoices = GetNumDisplays,
				.generateChoiceString = GetDisplayName,
			},
		},
	},
	{
		kMICycler2, STR_VSYNC,
		.callback = OnChangeVSync,
		.cycler =
		{
			.valuePtr = &gGamePrefs.vsync,
			.choices = { {STR_NO, 0}, {STR_YES, 1} },
		}
	},
	{
		kMICycler2, STR_ANTIALIASING,
		.callback = OnChangeMSAA,
		.cycler =
		{
			.valuePtr = &gGamePrefs.antialiasingLevel,
			.choices =
			{
				{STR_NO, 0},
				{STR_MSAA_2X, 1},
				{STR_MSAA_4X, 2},
				{STR_MSAA_8X, 3},
			},
		},
	},
	{
		kMIPick,
		STR_3D_GLASSES_CALIBRATE,
		.callback=SetUpAnaglyphCalibrationScreen,
		.next='cali'
	},
//	{kMISpacer, .customHeight=.5f },
//	{kMILabel, STR_FULLSCREEN_HINT, .customHeight=.5f },
//	{kMISpacer, .customHeight=.5f },
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	//-------------------------------------------------------------------------
	// AUDIO

	{.id='soun'},
	{kMILabel, .text=STR_SOUND},
	{kMISpacer, .customHeight=.3f},
	{
		kMISlider, STR_MUSIC,
		.callback = UpdateGlobalVolume,
		.slider =
		{
			.valuePtr = &gGamePrefs.musicVolumePercent,
			.minValue = 0,
			.maxValue = 100,
			.equilibrium = 70,
			.increment = 5,
			.continuousCallback = true,
		}
	},
	{
		kMISlider, STR_SFX,
		.callback = UpdateGlobalVolume,
		.slider =
		{
			.valuePtr = &gGamePrefs.sfxVolumePercent,
			.minValue = 0,
			.maxValue = 100,
			.equilibrium = 70,
			.increment = 5,
			.continuousCallback = true,
		}
	},
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	//-------------------------------------------------------------------------
	// KEYBOARD

	{ .id='keyb' },
//	{kMISpacer, .customHeight=.35f },
	{kMILabel, STR_CONFIGURE_KEYBOARD_HELP, .customHeight=.7f },
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
	{kMIPick, STR_RESTORE_DEFAULT_CONFIG, .callback=OnPickResetKeyboardBindings, .customHeight=.5f },
	{kMISpacer, .customHeight=.25f },
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },
	{kMISpacer, .customHeight=2.2f, .getLayoutFlags=HideMenuEntryInGame },

	//-------------------------------------------------------------------------
	// MOUSE

	{ .id='mous' },
	{
		kMISlider, STR_MOUSE_SENSITIVITY,
		.slider = 
		{
			.valuePtr = &gGamePrefs.mouseSensitivityLevel,
			.minValue = 10,
			.maxValue = MAX_MOUSE_SENSITIVITY_LEVEL,
			.equilibrium = DEFAULT_MOUSE_SENSITIVITY_LEVEL,
			.increment = 5,
			.continuousCallback = true,
		}
	},
	{kMISpacer, .customHeight=.25f },
	{kMIMouseBinding, .inputNeed=kNeed_Fire },
	{kMIMouseBinding, .inputNeed=kNeed_Jetpack },
	{kMIMouseBinding, .inputNeed=kNeed_Drop },
	{kMIMouseBinding, .inputNeed=kNeed_NextWeapon },
	{kMIMouseBinding, .inputNeed=kNeed_PrevWeapon },
	{kMIMouseBinding, .inputNeed=kNeed_CameraMode },
	{kMISpacer, .customHeight=.25f },
	{kMIPick, STR_RESTORE_DEFAULT_CONFIG, .callback=OnPickResetMouseBindings, .customHeight=.5f },
	{kMISpacer, .customHeight=.25f },
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	//-------------------------------------------------------------------------
	// GAMEPAD

	{ .id = 'gpad', .callback=OnEnterGamepadMenu },
	//	{kMISpacer, .customHeight=.35f },
	{ kMILabel, STR_CONFIGURE_GAMEPAD_HELP, .customHeight = .6f },
	{ kMISpacer, .customHeight = .25f },
	{ kMIPadBinding, .inputNeed = kNeed_PitchUp },
	{ kMIPadBinding, .inputNeed = kNeed_PitchDown },
	{ kMIPadBinding, .inputNeed = kNeed_YawLeft },
	{ kMIPadBinding, .inputNeed = kNeed_YawRight },
	{ kMIPadBinding, .inputNeed = kNeed_Fire },
	{ kMIPadBinding, .inputNeed = kNeed_Jetpack },
	{ kMIPadBinding, .inputNeed = kNeed_NextWeapon },
	{ kMIPadBinding, .inputNeed = kNeed_PrevWeapon },
	{ kMIPadBinding, .inputNeed = kNeed_Drop },
	{ kMIPadBinding, .inputNeed = kNeed_CameraMode },
	{ kMIPick, STR_RESTORE_DEFAULT_CONFIG, .callback = OnPickResetGamepadBindings, .customHeight = .5f },
	{ kMISpacer, .customHeight = .25f },
	{ kMIPick, STR_BACK_SYMBOL,		.next = 'BACK' },
	{kMISpacer, .customHeight=2.8f, .getLayoutFlags=HideMenuEntryInGame },

	//-------------------------------------------------------------------------
	// END SENTINEL

	{ .id=0 }
};

void RegisterSettingsMenu(void)
{
	RegisterMenu(gSettingsMenuTree);
}
