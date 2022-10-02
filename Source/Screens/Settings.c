/****************************/
/*     SETTINGS MENU        */
/* (c)2022 Iliyas Jorio     */
/****************************/


#include "game.h"

static void OnPickLanguage(const MenuItem* mi)
{
	gGamePrefs.language = mi->id;
	LoadLocalizedStrings(gGamePrefs.language);
}

static void OnToggleFullscreen(const MenuItem* mi)
{
	SetFullscreenMode(true);
}

static const MenuItem gSettingsMenuTree[] =
{
	{ .id='sett' },
	{kMIPick, STR_GENERAL,			.next='gnrl'},
	{kMIPick, STR_CONTROLS,			.next='ctrl'},
	{kMIPick, STR_GRAPHICS,			.next='graf'},
	{kMIPick, STR_SOUND,			.next='soun'},
	{kMIPick, STR_LANGUAGE,			.next='lang' },
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	{.id='gnrl'},
	{
		kMICycler1, STR_KIDDIE_MODE,
		.cycler=
		{
			.valuePtr=&gGamePrefs.kiddieMode,
			.choices={ {STR_OFF, 0}, {STR_ON, 1} },
		}
	},
	{
		kMICycler1, STR_SUBTITLES,
		.cycler=
		{
			.valuePtr=&gGamePrefs.cutsceneSubtitles,
			.choices={ {STR_OFF, 0}, {STR_ON, 1} },
		},
	},
	{
		kMICycler1, STR_CROSSHAIRS,
		.cycler=
		{
			.valuePtr=&gGamePrefs.showTargetingCrosshairs,
			.choices={ {STR_CROSSHAIRS_OFF, 0}, {STR_CROSSHAIRS_ON, 1} },
		},
	},
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	{.id='ctrl'},
	{kMIPick, STR_CONFIGURE_KEYBOARD, .next='keyb' },
	{kMIPick, STR_CONFIGURE_GAMEPAD, .next='gpad' },
	{kMIPick, STR_CONFIGURE_MOUSE, .next='mous' },
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
//	{
//		kMICycler1, STR_ANTIALIASING,
////		.callback = OnChangeMSAA,
////		.getLayoutFlags = ShouldDisplayMSAA,
////		.cycler =
////		{
////			.valuePtr = &gGamePrefs.antialiasingLevel,
////			.choices =
////			{
////				{STR_OFF, 0},
////				{STR_MSAA_2X, 1},
////				{STR_MSAA_4X, 2},
////				{STR_MSAA_8X, 3},
////			},
////		},
//	},
	{kMISpacer, .customHeight=.5f },
	{kMILabel, STR_FULLSCREEN_HINT, .customHeight=.5f },
	{kMISpacer, .customHeight=.5f },
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	{.id='soun'},
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	{.id='lang'},
	{kMIPick, STR_ENGLISH,	.id=LANGUAGE_ENGLISH,	.callback=OnPickLanguage,	.next='BACK'},
	{kMIPick, STR_FRENCH,	.id=LANGUAGE_FRENCH,	.callback=OnPickLanguage,	.next='BACK'},
	{kMIPick, STR_GERMAN,	.id=LANGUAGE_GERMAN,	.callback=OnPickLanguage,	.next='BACK'},
	{kMIPick, STR_SPANISH,	.id=LANGUAGE_SPANISH,	.callback=OnPickLanguage,	.next='BACK'},
	{kMIPick, STR_ITALIAN,	.id=LANGUAGE_ITALIAN,	.callback=OnPickLanguage,	.next='BACK'},
	{kMIPick, STR_DUTCH,	.id=LANGUAGE_DUTCH,		.callback=OnPickLanguage,	.next='BACK'},
	{kMIPick, STR_SWEDISH,	.id=LANGUAGE_SWEDISH,	.callback=OnPickLanguage,	.next='BACK'},
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	{ .id='keyb' },
	{kMISpacer, .customHeight=.35f },
	{kMILabel, STR_CONFIGURE_KEYBOARD_HELP, .customHeight=.5f },
	{kMISpacer, .customHeight=.4f },
	{kMIKeyBinding, .inputNeed=kNeed_PitchUp },
	{kMIKeyBinding, .inputNeed=kNeed_PitchDown },
	{kMIKeyBinding, .inputNeed=kNeed_YawLeft },
	{kMIKeyBinding, .inputNeed=kNeed_YawRight },
	{kMIKeyBinding, .inputNeed=kNeed_Jetpack },
	{kMIKeyBinding, .inputNeed=kNeed_Fire },
	{kMIKeyBinding, .inputNeed=kNeed_NextWeapon },
	{kMIKeyBinding, .inputNeed=kNeed_PrevWeapon },
	{kMIKeyBinding, .inputNeed=kNeed_CameraMode },
//	{kMISpacer, .customHeight=.25f },
//	{kMIPick, STR_RESET_KEYBINDINGS, .callback=OnPickResetKeyboardBindings, .customHeight=.5f },
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	{ .id='gpad' },
	{kMISpacer, .customHeight=.35f },
	{kMILabel, STR_CONFIGURE_GAMEPAD_HELP, .customHeight=.5f },
	{kMISpacer, .customHeight=.4f },
	{kMIPadBinding, .inputNeed=kNeed_PitchUp },
	{kMIPadBinding, .inputNeed=kNeed_PitchDown },
	{kMIPadBinding, .inputNeed=kNeed_YawLeft },
	{kMIPadBinding, .inputNeed=kNeed_YawRight },
	{kMIPadBinding, .inputNeed=kNeed_Jetpack },
	{kMIPadBinding, .inputNeed=kNeed_Fire },
	{kMIPadBinding, .inputNeed=kNeed_NextWeapon },
	{kMIPadBinding, .inputNeed=kNeed_PrevWeapon },
	{kMIPadBinding, .inputNeed=kNeed_CameraMode },
//	{kMISpacer, .customHeight=.25f },
//	{kMIPick, STR_RESET_KEYBINDINGS, .callback=OnPickResetKeyboardBindings, .customHeight=.5f },
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },

	{ .id='mous' },
	{kMISpacer, .customHeight=.35f },
//	{kMILabel, STR_CONFIGURE_GAMEPAD_HELP, .customHeight=.5f },
//	{kMISpacer, .customHeight=.4f },
	{kMIMouseBinding, .inputNeed=kNeed_Jetpack },
	{kMIMouseBinding, .inputNeed=kNeed_Fire },
	{kMIMouseBinding, .inputNeed=kNeed_NextWeapon },
	{kMIMouseBinding, .inputNeed=kNeed_PrevWeapon },
	{kMIMouseBinding, .inputNeed=kNeed_CameraMode },
//	{kMISpacer, .customHeight=.25f },
//	{kMIPick, STR_RESET_KEYBINDINGS, .callback=OnPickResetKeyboardBindings, .customHeight=.5f },
	{kMIPick, STR_BACK_SYMBOL,		.next='BACK' },




	{ .id=0 }
};

void RegisterSettingsMenu(void)
{
	RegisterMenu(gSettingsMenuTree);
}
