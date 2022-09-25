#include "game.h"

#if __APPLE__
	#define SC_NWEAP1 SDL_SCANCODE_LGUI
	#define SC_NWEAP2 SDL_SCANCODE_RGUI
	#define SC_DROP1 SDL_SCANCODE_LALT
	#define SC_DROP2 SDL_SCANCODE_RALT
#else
	#define SC_NWEAP1 SDL_SCANCODE_LCTRL
	#define SC_NWEAP2 SDL_SCANCODE_RCTRL
	#define SC_DROP1 SDL_SCANCODE_LALT
	#define SC_DROP2 SDL_SCANCODE_RALT
#endif

// Controller button/axis
#define CB(x)		{kInputTypeButton, SDL_CONTROLLER_BUTTON_##x}
#define CAPLUS(x)	{kInputTypeAxisPlus, SDL_CONTROLLER_AXIS_##x}
#define CAMINUS(x)	{kInputTypeAxisMinus, SDL_CONTROLLER_AXIS_##x}
#define CBNULL()	{kInputTypeUnbound, 0}

const InputBinding kDefaultInputBindings[NUM_CONTROL_NEEDS] =
{
	[kNeed_Fire] =
	{
		.key = { SDL_SCANCODE_SPACE },
		.pad = { CB(X) },
	},

	[kNeed_Drop] =
	{
		.key = { SC_DROP1, SC_DROP2 },
		.pad = { CB(Y) },
	},

	[kNeed_NextWeapon] =
	{
		.key = { SC_NWEAP1, SC_NWEAP2 },
		.pad = { CB(RIGHTSHOULDER) },
	},

	[kNeed_CameraMode] =
	{
		.key = { SDL_SCANCODE_TAB },
		.pad = { CB(LEFTSHOULDER) },
	},

	[kNeed_Jetpack] =
	{
		.key = { SDL_SCANCODE_LSHIFT, SDL_SCANCODE_RSHIFT },
		.pad = { CAPLUS(TRIGGERRIGHT) },
	},

	[kNeed_PitchUp_Key] =
	{
		.key = { SDL_SCANCODE_UP, SDL_SCANCODE_W },
		.pad = { CAMINUS(LEFTY), CB(DPAD_UP) },
	},

	[kNeed_PitchDown_Key] =
	{
		.key = { SDL_SCANCODE_DOWN, SDL_SCANCODE_S },
		.pad = { CAPLUS(LEFTY), CB(DPAD_DOWN) },
	},

	[kNeed_TurnLeft_Key] =
	{
		.key = { SDL_SCANCODE_LEFT, SDL_SCANCODE_A },
		.pad = { CAMINUS(LEFTX), CB(DPAD_LEFT) },
	},

	[kNeed_TurnRight_Key] =
	{
		.key = { SDL_SCANCODE_RIGHT, SDL_SCANCODE_D },
		.pad = { CAPLUS(LEFTX), CB(DPAD_RIGHT) },
	},

	// -----------------------------------------------------------
	// Non-remappable UI bindings below

	[kNeed_UIUp] =
	{
		.key = { SDL_SCANCODE_UP, SDL_SCANCODE_W },
		.pad = { CB(DPAD_UP), CAMINUS(LEFTY) },
	},

	[kNeed_UIDown] =
	{
		.key = { SDL_SCANCODE_DOWN, SDL_SCANCODE_S },
		.pad = { CB(DPAD_DOWN), CAPLUS(LEFTY) },
	},

	[kNeed_UILeft] =
	{
		.key = { SDL_SCANCODE_LEFT, SDL_SCANCODE_A },
		.pad = { CB(DPAD_LEFT), CAMINUS(LEFTX) },
	},

	[kNeed_UIRight] =
	{
		.key = { SDL_SCANCODE_RIGHT, SDL_SCANCODE_D },
		.pad = { CB(DPAD_RIGHT), CAPLUS(LEFTX) },
	},

	[kNeed_UIPrev] =
	{
		.pad = { CB(LEFTSHOULDER) },
	},

	[kNeed_UINext] =
	{
		.pad = { CB(RIGHTSHOULDER) },
	},

	[kNeed_UIConfirm] =
	{
		.key = { SDL_SCANCODE_RETURN, SDL_SCANCODE_SPACE, SDL_SCANCODE_KP_ENTER },
		.pad = { CB(A) },
	},

	[kNeed_UIDelete] =
	{
		.key = { SDL_SCANCODE_DELETE, SDL_SCANCODE_BACKSPACE },
		.pad = { CB(X) },
	},

	[kNeed_UIStart] =
	{
		.pad = { CB(START) },
	},

	[kNeed_UIBack] =
	{
		.key = { SDL_SCANCODE_ESCAPE, SDL_SCANCODE_BACKSPACE },
		.pad = { CB(B), CB(BACK) },
		.mouseButton = SDL_BUTTON_X1
	},

	[kNeed_UIPause] =
	{
		.key = { SDL_SCANCODE_ESCAPE },
		.pad = { CB(START) },
	},

};
