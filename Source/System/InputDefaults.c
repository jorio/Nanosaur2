#include "game.h"

#if __APPLE__
	#define SC_NWEAP SDL_SCANCODE_LGUI
	#define SC_PWEAP SDL_SCANCODE_RGUI
	#define SC_DROP1 SDL_SCANCODE_LALT
	#define SC_DROP2 SDL_SCANCODE_RALT
#else
	#define SC_NWEAP SDL_SCANCODE_LCTRL
	#define SC_PWEAP SDL_SCANCODE_RCTRL
	#define SC_DROP1 SDL_SCANCODE_LALT
	#define SC_DROP2 SDL_SCANCODE_RALT
#endif

// Controller button/axis
#define GB(x)		{kInputTypeButton, SDL_GAMEPAD_BUTTON_##x}
#define GAPLUS(x)	{kInputTypeAxisPlus, SDL_GAMEPAD_AXIS_##x}
#define GAMINUS(x)	{kInputTypeAxisMinus, SDL_GAMEPAD_AXIS_##x}
#define GBNULL()	{kInputTypeUnbound, 0}

const InputBinding kDefaultInputBindings[NUM_CONTROL_NEEDS] =
{
	[kNeed_Fire] =
	{
		.key = { SDL_SCANCODE_SPACE },
		.pad = { GB(WEST) },
		.mouseButton = SDL_BUTTON_LEFT,
	},

	[kNeed_Drop] =
	{
		.key = { SC_DROP1, SC_DROP2 },
		.pad = { GB(NORTH) },
	},

	[kNeed_PrevWeapon] =
	{
		.key = { SC_PWEAP },
		.pad = { GB(LEFT_SHOULDER) },
		.mouseButton = SDL_BUTTON_WHEELUP,
	},

	[kNeed_NextWeapon] =
	{
		.key = { SC_NWEAP },
		.pad = { GB(RIGHT_SHOULDER), GB(EAST) },
		.mouseButton = SDL_BUTTON_WHEELDOWN,
	},

	[kNeed_CameraMode] =
	{
		.key = { SDL_SCANCODE_TAB },
		.pad = { GB(LEFT_STICK) },
		.mouseButton = SDL_BUTTON_MIDDLE,
	},

	[kNeed_Jetpack] =
	{
		.key = { SDL_SCANCODE_LSHIFT, SDL_SCANCODE_RSHIFT },
		.pad = { GB(SOUTH) },
		.mouseButton = SDL_BUTTON_RIGHT,
	},

	[kNeed_PitchUp] =
	{
		.key = { SDL_SCANCODE_UP, SDL_SCANCODE_W },
		.pad = { GAMINUS(LEFTY), GB(DPAD_UP) },
	},

	[kNeed_PitchDown] =
	{
		.key = { SDL_SCANCODE_DOWN, SDL_SCANCODE_S },
		.pad = { GAPLUS(LEFTY), GB(DPAD_DOWN) },
	},

	[kNeed_YawLeft] =
	{
		.key = { SDL_SCANCODE_LEFT, SDL_SCANCODE_A },
		.pad = { GAMINUS(LEFTX), GB(DPAD_LEFT) },
	},

	[kNeed_YawRight] =
	{
		.key = { SDL_SCANCODE_RIGHT, SDL_SCANCODE_D },
		.pad = { GAPLUS(LEFTX), GB(DPAD_RIGHT) },
	},

	// -----------------------------------------------------------
	// Non-remappable UI bindings below

	[kNeed_UIUp] =
	{
		.key = { SDL_SCANCODE_UP, SDL_SCANCODE_W },
		.pad = { GB(DPAD_UP), GAMINUS(LEFTY) },
	},

	[kNeed_UIDown] =
	{
		.key = { SDL_SCANCODE_DOWN, SDL_SCANCODE_S },
		.pad = { GB(DPAD_DOWN), GAPLUS(LEFTY) },
	},

	[kNeed_UIPrev] =
	{
		.key = { SDL_SCANCODE_LEFT, SDL_SCANCODE_A },
		.pad = { GB(DPAD_LEFT), GAMINUS(LEFTX), GB(LEFT_SHOULDER) },
	},

	[kNeed_UINext] =
	{
		.key = { SDL_SCANCODE_RIGHT, SDL_SCANCODE_D },
		.pad = { GB(DPAD_RIGHT), GAPLUS(LEFTX), GB(RIGHT_SHOULDER) },
	},

	[kNeed_UIConfirm] =
	{
		.key = { SDL_SCANCODE_RETURN, SDL_SCANCODE_SPACE, SDL_SCANCODE_KP_ENTER },
		.pad = { GB(SOUTH) },
	},

	[kNeed_UIDelete] =
	{
		.key = { SDL_SCANCODE_DELETE, SDL_SCANCODE_BACKSPACE },
		.pad = { GB(WEST) },
	},

	[kNeed_UIStart] =
	{
		.pad = { GB(START) },
	},

	[kNeed_UIBack] =
	{
		.key = { SDL_SCANCODE_ESCAPE, SDL_SCANCODE_BACKSPACE },
		.pad = { GB(EAST), GB(BACK) },
		.mouseButton = SDL_BUTTON_X1
	},

	[kNeed_UIPause] =
	{
		.key = { SDL_SCANCODE_ESCAPE },
		.pad = { GB(START) },
	},

};
