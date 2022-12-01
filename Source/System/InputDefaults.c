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
		.mouseButton = SDL_BUTTON_LEFT,
	},

	[kNeed_Drop] =
	{
		.key = { SC_DROP1, SC_DROP2 },
		.pad = { CB(Y) },
	},

	[kNeed_PrevWeapon] =
	{
		.key = { SC_PWEAP },
		.pad = { CB(LEFTSHOULDER) },
		.mouseButton = SDL_BUTTON_WHEELUP,
	},

	[kNeed_NextWeapon] =
	{
		.key = { SC_NWEAP },
		.pad = { CB(RIGHTSHOULDER), CB(B) },
		.mouseButton = SDL_BUTTON_WHEELDOWN,
	},

	[kNeed_CameraMode] =
	{
		.key = { SDL_SCANCODE_TAB },
		.pad = { CB(LEFTSTICK) },
		.mouseButton = SDL_BUTTON_MIDDLE,
	},

	[kNeed_Jetpack] =
	{
		.key = { SDL_SCANCODE_LSHIFT, SDL_SCANCODE_RSHIFT },
		.pad = { CB(A) },
		.mouseButton = SDL_BUTTON_RIGHT,
	},

	[kNeed_PitchUp] =
	{
		.key = { SDL_SCANCODE_UP, SDL_SCANCODE_W },
		.pad = { CAMINUS(LEFTY), CB(DPAD_UP) },
	},

	[kNeed_PitchDown] =
	{
		.key = { SDL_SCANCODE_DOWN, SDL_SCANCODE_S },
		.pad = { CAPLUS(LEFTY), CB(DPAD_DOWN) },
	},

	[kNeed_YawLeft] =
	{
		.key = { SDL_SCANCODE_LEFT, SDL_SCANCODE_A },
		.pad = { CAMINUS(LEFTX), CB(DPAD_LEFT) },
	},

	[kNeed_YawRight] =
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

	[kNeed_UIPrev] =
	{
		.key = { SDL_SCANCODE_LEFT, SDL_SCANCODE_A },
		.pad = { CB(DPAD_LEFT), CAMINUS(LEFTX), CB(LEFTSHOULDER) },
	},

	[kNeed_UINext] =
	{
		.key = { SDL_SCANCODE_RIGHT, SDL_SCANCODE_D },
		.pad = { CB(DPAD_RIGHT), CAPLUS(LEFTX), CB(RIGHTSHOULDER) },
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
