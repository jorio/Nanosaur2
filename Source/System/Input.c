// SDL INPUT
// (C) 2022 Iliyas Jorio
// This file is part of Nanosaur 2. https://github.com/jorio/Nanosaur2

#include "game.h"

/***************/
/* CONSTANTS   */
/***************/

#define MAX_LOCAL_PLAYERS MAX_PLAYERS
#define gNumLocalPlayers gNumPlayers
#define REQUIRE_LOCK_MAPPING 0
#define MOUSE_SMOOTHING 0	// WARNING: Mouse smoothing untested in Nanosaur 2.

#define kJoystickDeadZone				(33 * 32767 / 100)
#define kJoystickDeadZone_UI			(66 * 32767 / 100)
#define kJoystickDeadZoneFrac			(kJoystickDeadZone / 32767.0f)
#define kJoystickDeadZoneFracSquared	(kJoystickDeadZoneFrac * kJoystickDeadZoneFrac)

#if MOUSE_SMOOTHING
static const int kMouseSmoothingAccumulatorWindowNanoseconds = 10 * 1e6;	// 10 ms
#define DELTA_MOUSE_MAX_SNAPSHOTS 64
#endif

/**********************/
/*     PROTOTYPES     */
/**********************/

typedef uint8_t KeyState;

typedef struct Gamepad
{
	bool			open;
	bool			fallbackToKeyboard;
	bool			hasRumble;
	SDL_Gamepad*	sdlGamepad;
	KeyState		needStates[NUM_CONTROL_NEEDS];
	float			needAnalog[NUM_CONTROL_NEEDS];
	OGLVector2D		analogSteering;
} Gamepad;

Boolean				gUserPrefersGamepad = false;

static Boolean		gGamepadPlayerMappingLocked = false;
Gamepad				gGamepads[MAX_LOCAL_PLAYERS];

static KeyState		gKeyboardStates[SDL_SCANCODE_COUNT];
static KeyState		gMouseButtonStates[NUM_SUPPORTED_MOUSE_BUTTONS];
static KeyState		gNeedStates[NUM_CONTROL_NEEDS];
static int			gLastGamepadForNeedAnyP[NUM_CONTROL_NEEDS];

Boolean				gMouseMotionNow = false;
char				gTextInput[64];

#if MOUSE_SMOOTHING
static struct MouseSmoothingState
{
	bool initialized;
	struct
	{
		uint64_t timestamp;
		float dx;
		float dy;
	} snapshots[DELTA_MOUSE_MAX_SNAPSHOTS];
	int ringStart;
	int ringLength;
	float dxAccu;
	float dyAccu;
} gMouseSmoothing = {0};

static void MouseSmoothing_ResetState(void);
static void MouseSmoothing_StartFrame(void);
static void MouseSmoothing_OnMouseMotion(const SDL_MouseMotionEvent* motion);
#endif

static void OnJoystickRemoved(SDL_JoystickID which);
static SDL_Gamepad* TryOpenGamepadFromJoystick(SDL_JoystickID joystickID);
static SDL_Gamepad* TryOpenAnyUnusedGamepad(bool showMessage);
static void TryFillUpVacantGamepadSlots(void);
static int GetGamepadSlotFromJoystick(SDL_JoystickID joystickID);

#pragma mark -
/**********************/

void InitInput(void)
{
	for (int i = 0; i < NUM_CONTROL_NEEDS; i++)
		gLastGamepadForNeedAnyP[i] = -1;

	TryFillUpVacantGamepadSlots();
}

static inline void UpdateKeyState(KeyState* state, bool downNow)
{
	switch (*state)	// look at prev state
	{
		case KEYSTATE_HELD:
		case KEYSTATE_DOWN:
			*state = downNow ? KEYSTATE_HELD : KEYSTATE_UP;
			break;

		case KEYSTATE_OFF:
		case KEYSTATE_UP:
		default:
			*state = downNow ? KEYSTATE_DOWN : KEYSTATE_OFF;
			break;

		case KEYSTATE_IGNOREHELD:
			*state = downNow ? KEYSTATE_IGNOREHELD : KEYSTATE_OFF;
			break;
	}
}

void InvalidateNeedState(int need)
{
	gNeedStates[need] = KEYSTATE_IGNOREHELD;
}

void InvalidateAllInputs(void)
{
	_Static_assert(1 == sizeof(KeyState), "sizeof(KeyState) has changed -- Rewrite this function without SDL_memset()!");

	SDL_memset(gNeedStates, KEYSTATE_IGNOREHELD, NUM_CONTROL_NEEDS);
	SDL_memset(gKeyboardStates, KEYSTATE_IGNOREHELD, SDL_SCANCODE_COUNT);
	SDL_memset(gMouseButtonStates, KEYSTATE_IGNOREHELD, NUM_SUPPORTED_MOUSE_BUTTONS);

	for (int i = 0; i < MAX_LOCAL_PLAYERS; i++)
	{
		SDL_memset(gGamepads[i].needStates, KEYSTATE_IGNOREHELD, NUM_CONTROL_NEEDS);
	}

}

static void UpdateRawKeyboardStates(void)
{
	int numkeys = 0;
	const bool* keystate = SDL_GetKeyboardState(&numkeys);

	int minNumKeys = GAME_MIN(numkeys, SDL_SCANCODE_COUNT);

	for (int i = 0; i < minNumKeys; i++)
		UpdateKeyState(&gKeyboardStates[i], keystate[i]);

	// fill out the rest
	for (int i = minNumKeys; i < SDL_SCANCODE_COUNT; i++)
		UpdateKeyState(&gKeyboardStates[i], false);
}

static void ProcessSystemKeyChords(void)
{
	if ((gGamePaused || !gPlayNow) && IsCmdQDown())
	{
		CleanQuit();
	}

	if (IsKeyDown(SDL_SCANCODE_RETURN)
		&& (IsKeyHeld(SDL_SCANCODE_LALT) || IsKeyHeld(SDL_SCANCODE_RALT)))
	{
		gGamePrefs.fullscreen = !gGamePrefs.fullscreen;
		SetFullscreenMode(false);

		InvalidateAllInputs();
	}

}

static void UpdateMouseButtonStates(int mouseWheelDeltaX, int mouseWheelDeltaY)
{
	uint32_t mouseButtons = SDL_GetMouseState(NULL, NULL);

	for (int i = 1; i < NUM_SUPPORTED_MOUSE_BUTTONS_PURESDL; i++)	// SDL buttons start at 1!
	{
		bool buttonBit = 0 != (mouseButtons & SDL_BUTTON_MASK(i));
		UpdateKeyState(&gMouseButtonStates[i], buttonBit);
	}

	// Fake buttons for mouse wheel up/down
	UpdateKeyState(&gMouseButtonStates[SDL_BUTTON_WHEELUP], mouseWheelDeltaX > 0);
	UpdateKeyState(&gMouseButtonStates[SDL_BUTTON_WHEELDOWN], mouseWheelDeltaX < 0);
	UpdateKeyState(&gMouseButtonStates[SDL_BUTTON_WHEELLEFT], mouseWheelDeltaY < 0);
	UpdateKeyState(&gMouseButtonStates[SDL_BUTTON_WHEELRIGHT], mouseWheelDeltaY > 0);
}

static void UpdateInputNeeds(void)
{
	for (int need = 0; need < NUM_CONTROL_NEEDS; need++)
	{
		const InputBinding* kb = &gGamePrefs.bindings[need];

		bool pressed = false;

		for (int j = 0; j < MAX_BINDINGS_PER_NEED; j++)
		{
			int16_t scancode = kb->key[j];
			if (scancode && scancode < SDL_SCANCODE_COUNT)
			{
				pressed |= gKeyboardStates[scancode] & KEYSTATE_ACTIVE_BIT;
			}
		}

		pressed |= gMouseButtonStates[kb->mouseButton] & KEYSTATE_ACTIVE_BIT;

		UpdateKeyState(&gNeedStates[need], pressed);
	}
}

static void UpdateControllerSpecificInputNeeds(int controllerNum)
{
	Gamepad* controller = &gGamepads[controllerNum];

	if (!controller->open)
	{
		return;
	}

	SDL_Gamepad* controllerInstance = controller->sdlGamepad;

	for (int needNum = 0; needNum < NUM_CONTROL_NEEDS; needNum++)
	{
		const InputBinding* kb = &gGamePrefs.bindings[needNum];

		int16_t deadZone = needNum >= NUM_REMAPPABLE_NEEDS
						   ? kJoystickDeadZone_UI
						   : kJoystickDeadZone;

		bool pressed = false;
		float analogPressed = 0;

		for (int buttonNum = 0; buttonNum < MAX_BINDINGS_PER_NEED; buttonNum++)
		{
			const PadBinding* pb = &kb->pad[buttonNum];

			switch (pb->type)
			{
				case kInputTypeButton:
					if (0 != SDL_GetGamepadButton(controllerInstance, pb->id))
					{
						pressed = true;
						analogPressed = 1;
					}
					break;

				case kInputTypeAxisPlus:
				{
					int16_t axis = SDL_GetGamepadAxis(controllerInstance, pb->id);
					if (axis > deadZone)
					{
						pressed = true;
						float absAxisFrac = (axis - deadZone) / (32767.0f - deadZone);
						analogPressed = GAME_MAX(analogPressed, absAxisFrac);
					}
					break;
				}

				case kInputTypeAxisMinus:
				{
					int16_t axis = SDL_GetGamepadAxis(controllerInstance, pb->id);
					if (axis < -deadZone)
					{
						pressed = true;
						float absAxisFrac = (-axis - deadZone) / (32767.0f - deadZone);
						analogPressed = GAME_MAX(analogPressed, absAxisFrac);
					}
					break;
				}

				default:
					break;
			}
		}

		controller->needAnalog[needNum] = analogPressed;

		UpdateKeyState(&controller->needStates[needNum], pressed);
	}
}

#pragma mark -

/**********************/
/* PUBLIC FUNCTIONS   */
/**********************/

void DoSDLMaintenance(void)
{
	gTextInput[0] = '\0';
	gMouseMotionNow = false;
	int mouseWheelDeltaX = 0;
	int mouseWheelDeltaY = 0;

			/**********************/
			/* DO SDL MAINTENANCE */
			/**********************/

#if MOUSE_SMOOTHING
	MouseSmoothing_StartFrame();
#endif

	SDL_PumpEvents();
	SDL_Event event;
	while (SDL_PollEvent(&event))
	{
		switch (event.type)
		{
			case SDL_EVENT_QUIT:
			case SDL_EVENT_WINDOW_CLOSE_REQUESTED:
				CleanQuit();			// throws Pomme::QuitRequest
				return;

			case SDL_EVENT_KEY_DOWN:
				gUserPrefersGamepad = false;
				break;

			case SDL_EVENT_TEXT_INPUT:
				SDL_snprintf(gTextInput, sizeof(gTextInput), "%s", event.text.text);
				break;

			case SDL_EVENT_MOUSE_MOTION:
				gMouseMotionNow = true;
				gUserPrefersGamepad = false;
#if MOUSE_SMOOTHING
				MouseSmoothing_OnMouseMotion(&event.motion);
#endif
				break;

			case SDL_EVENT_MOUSE_WHEEL:
				gUserPrefersGamepad = false;
				mouseWheelDeltaX += event.wheel.y;
				mouseWheelDeltaY += event.wheel.x;
				break;

			case SDL_EVENT_GAMEPAD_ADDED:
				TryOpenGamepadFromJoystick(event.gdevice.which);
				break;

			case SDL_EVENT_GAMEPAD_REMOVED:
				OnJoystickRemoved(event.gdevice.which);
				break;

			case SDL_EVENT_GAMEPAD_BUTTON_DOWN:
			case SDL_EVENT_GAMEPAD_BUTTON_UP:
				gUserPrefersGamepad = true;
				break;
		}
	}

	// Refresh the state of each individual keyboard key
	UpdateRawKeyboardStates();

	// On ALT+ENTER, toggle fullscreen, and ignore ENTER until keyup.
	// Also, on macOS, process Cmd+Q.
	ProcessSystemKeyChords();

	// Refresh the state of each mouse button
	UpdateMouseButtonStates(mouseWheelDeltaX, mouseWheelDeltaY);

	// Refresh the state of each input need
	UpdateInputNeeds();

	//-------------------------------------------------------------------------
	// Multiplayer gamepad input
	//-------------------------------------------------------------------------

	for (int controllerNum = 0; controllerNum < MAX_LOCAL_PLAYERS; controllerNum++)
	{
		UpdateControllerSpecificInputNeeds(controllerNum);
	}
}

#pragma mark - Keyboard states

int GetKeyState(uint16_t sdlScancode)
{
	if (sdlScancode >= SDL_SCANCODE_COUNT)
		return KEYSTATE_OFF;
	return gKeyboardStates[sdlScancode];
}

#pragma mark - Click states

int GetClickState(int mouseButton)
{
	if (mouseButton >= NUM_SUPPORTED_MOUSE_BUTTONS)
		return KEYSTATE_OFF;
	return gMouseButtonStates[mouseButton];
}

#pragma mark - Need states

static int GetNeedStateAnyP(int needID)
{
	gLastGamepadForNeedAnyP[needID] = -1;

	for (int i = 0; i < MAX_LOCAL_PLAYERS; i++)
	{
		if (gGamepads[i].open && gGamepads[i].needStates[needID])
		{
			gLastGamepadForNeedAnyP[needID] = i;
			return gGamepads[i].needStates[needID];
		}
	}

	// Fallback to KB/M
	return gNeedStates[needID];
}

int GetNeedState(int needID, int playerID)
{
	if (playerID == ANY_PLAYER)
	{
		return GetNeedStateAnyP(needID);
	}

	GAME_ASSERT(playerID >= 0);
	GAME_ASSERT(playerID < MAX_LOCAL_PLAYERS);
	GAME_ASSERT(needID >= 0);
	GAME_ASSERT(needID < NUM_CONTROL_NEEDS);

	const Gamepad* controller = &gGamepads[playerID];

	if (controller->open && controller->needStates[needID])
	{
		return controller->needStates[needID];
	}

	// Fallback to KB/M
#if REQUIRE_LOCK_MAPPING
	if (gNumLocalPlayers <= 1 || controller->fallbackToKeyboard)
#else
	if (playerID == KBMFallbackPlayer())
#endif
	{
		return gNeedStates[needID];
	}

	return KEYSTATE_OFF;
}

int GetLastControllerForNeedAnyP(int needID)
{
	GAME_ASSERT(needID >= 0);
	GAME_ASSERT(needID < NUM_CONTROL_NEEDS);

	return gLastGamepadForNeedAnyP[needID];
}

static float GetNeedAnalogValueAnyP(int needID)
{
	for (int i = 0; i < MAX_LOCAL_PLAYERS; i++)
	{
		if (gGamepads[i].open && gGamepads[i].needStates[needID])
		{
			return GetNeedAnalogValue(needID, i);
		}
	}

	// Fallback to KB/M
	return GetNeedAnalogValue(needID, KBMFallbackPlayer());
}

float GetNeedAnalogValue(int needID, int playerID)
{
	if (playerID == ANY_PLAYER)
	{
		return GetNeedAnalogValueAnyP(needID);
	}

	GAME_ASSERT(playerID >= 0);
	GAME_ASSERT(playerID < MAX_LOCAL_PLAYERS);
	GAME_ASSERT(needID >= 0);
	GAME_ASSERT(needID < NUM_CONTROL_NEEDS);

	const Gamepad* controller = &gGamepads[playerID];

	if (controller->open && controller->needAnalog[needID] != 0.0f)
	{
		return controller->needAnalog[needID];
	}

	// Fallback to KB/M
#if REQUIRE_LOCK_MAPPING
	if (gNumLocalPlayers <= 1 || controller->fallbackToKeyboard)
#else
	if (playerID == KBMFallbackPlayer())
#endif
	{
		if (gNeedStates[needID] & KEYSTATE_ACTIVE_BIT)
		{
			return 1.0f;
		}
	}

	return 0.0f;
}

float GetNeedAnalogSteering(int negativeNeedID, int positiveNeedID, int playerID)
{
	float neg = GetNeedAnalogValue(negativeNeedID, playerID);
	float pos = GetNeedAnalogValue(positiveNeedID, playerID);

	if (neg > pos)
	{
		return -neg;
	}
	else
	{
		return pos;
	}
}

Boolean UserWantsOut(void)
{
	if (gGammaFadeFrac < 1)				// disallow skipping during fade-in
		return false;

	return IsNeedDown(kNeed_UIConfirm, ANY_PLAYER)
		|| IsNeedDown(kNeed_UIBack, ANY_PLAYER)
		|| IsNeedDown(kNeed_UIPause, ANY_PLAYER)
		|| IsClickDown(SDL_BUTTON_LEFT);
}

Boolean IsCmdQDown(void)
{
#if __APPLE__
	return (IsKeyHeld(SDL_SCANCODE_LGUI) || IsKeyHeld(SDL_SCANCODE_RGUI))
		&& IsKeyDown(SDL_GetScancodeFromKey(SDLK_Q, NULL));
#else
	// On non-macOS systems, alt-f4 is handled by the system
	return false;
#endif
}

Boolean IsCheatKeyComboDown(void)
{
	// The original Mac version used B-R-I, but some cheap PC keyboards can't register
	// this particular key combo, so C-M-R is available as an alternative.
	return (IsKeyHeld(SDL_SCANCODE_B) && IsKeyHeld(SDL_SCANCODE_R) && IsKeyHeld(SDL_SCANCODE_I))
		|| (IsKeyHeld(SDL_SCANCODE_C) && IsKeyHeld(SDL_SCANCODE_M) && IsKeyHeld(SDL_SCANCODE_R));
}

#pragma mark - Analog steering

static float GetControllerAnalogSteeringAxis(SDL_Gamepad* sdlController, SDL_GamepadAxis axis)
{
			/****************************/
			/* SET PLAYER AXIS CONTROLS */
			/****************************/

	float steer = 0; 											// assume no control input

			/* FIRST CHECK ANALOG AXES */

	if (sdlController)
	{
		Sint16 dxRaw = SDL_GetGamepadAxis(sdlController, axis);

		steer = dxRaw / 32767.0f;
		float steerMag = fabsf(steer);

		if (steerMag < kJoystickDeadZoneFrac)
		{
			steer = 0;
		}
		else if (steer < -1.0f)
		{
			steer = -1.0f;
		}
		else if (steer > 1.0f)
		{
			steer = 1.0f;
		}
		else
		{
			// Avoid magnitude bump when thumbstick is pushed past dead zone:
			// Bring magnitude from [kJoystickDeadZoneFrac, 1.0] to [0.0, 1.0].
			float steerSign = steer < 0 ? -1.0f : 1.0f;
			steer = steerSign * (steerMag - kJoystickDeadZoneFrac) / (1.0f - kJoystickDeadZoneFrac);
		}
	}

	return steer;
}

#pragma mark - Controller mapping

/****************************** SDL JOYSTICK FUNCTIONS ********************************/

int GetNumGamepad(void)
{
	int count = 0;

#if 0
	for (int i = 0; i < SDL_NumJoysticks(); ++i)
	{
		if (SDL_IsGameController(i))
		{
			count++;
		}
	}
#else
	for (int i = 0; i < MAX_LOCAL_PLAYERS; i++)
	{
		if (gGamepads[i].open)
		{
			count++;
		}
	}
#endif

	return count;
}

SDL_Gamepad* GetGamepad(int n)
{
	if (gGamepads[n].open)
	{
		return gGamepads[n].sdlGamepad;
	}
	else
	{
		return NULL;
	}
}

static int FindFreeGamepadSlot()
{
	for (int i = 0; i < MAX_LOCAL_PLAYERS; i++)
	{
		if (!gGamepads[i].open)
		{
			return i;
		}
	}

	return -1;
}

static int GetGamepadSlotFromJoystick(SDL_JoystickID joystickID)
{
	for (int gamepadSlot = 0; gamepadSlot < MAX_LOCAL_PLAYERS; gamepadSlot++)
	{
		Gamepad* gamepad = &gGamepads[gamepadSlot];
		if (gamepad->open && SDL_GetGamepadID(gamepad->sdlGamepad) == joystickID)
		{
			return gamepadSlot;
		}
	}

	return -1;
}

static SDL_Gamepad* TryOpenGamepadFromJoystick(SDL_JoystickID joystickID)
{
	int gamepadSlot = -1;

	// First, check that it's not in use already
	gamepadSlot = GetGamepadSlotFromJoystick(joystickID);
	if (gamepadSlot >= 0)	// in use
	{
		return gGamepads[gamepadSlot].sdlGamepad;
	}

	// If we can't get an SDL_Gamepad from that joystick, don't bother
	if (!SDL_IsGamepad(joystickID))
	{
		return NULL;
	}

	// Reserve a gamepad slot
	gamepadSlot = FindFreeGamepadSlot();
	if (gamepadSlot < 0)
	{
		SDL_Log("All controller slots used up.");
		// TODO: when a controller is unplugged, if all controller slots are used up, re-scan connected joysticks and try to open any unopened joysticks.
		return NULL;
	}

	// Use this one
	SDL_Gamepad* sdlGamepad = SDL_OpenGamepad(joystickID);

	// Assign player ID
	SDL_SetGamepadPlayerIndex(sdlGamepad, gamepadSlot);

	// Get properties
	SDL_PropertiesID props = SDL_GetGamepadProperties(sdlGamepad);

	gGamepads[gamepadSlot] = (Gamepad)
	{
		.open = true,
		.sdlGamepad = sdlGamepad,
		.hasRumble = SDL_GetBooleanProperty(props, SDL_PROP_GAMEPAD_CAP_RUMBLE_BOOLEAN, false),
	};

	SDL_Log("Opened joystick %d as gamepad: \"%s\" - Rumble support: %d",
			joystickID,
			SDL_GetGamepadName(gGamepads[gamepadSlot].sdlGamepad),
			gGamepads[gamepadSlot].hasRumble);

	gUserPrefersGamepad = true;

	return gGamepads[gamepadSlot].sdlGamepad;
}

static SDL_Gamepad* TryOpenAnyUnusedGamepad(bool showMessage)
{
	int numJoysticks = 0;
	int numJoysticksAlreadyInUse = 0;

	SDL_JoystickID* joysticks = SDL_GetJoysticks(&numJoysticks);
	SDL_Gamepad* newGamepad = NULL;

	for (int i = 0; i < numJoysticks; ++i)
	{
		SDL_JoystickID joystickID = joysticks[i];

		// Usable as an SDL_Gamepad?
		if (!SDL_IsGamepad(joystickID))
		{
			continue;
		}

		// Already in use?
		if (GetGamepadSlotFromJoystick(joystickID) >= 0)
		{
			numJoysticksAlreadyInUse++;
			continue;
		}

		// Use this one
		newGamepad = TryOpenGamepadFromJoystick(joystickID);
		if (newGamepad)
		{
			break;
		}
	}

	if (newGamepad)
	{
		// OK
	}
	else if (numJoysticksAlreadyInUse == numJoysticks)
	{
		// No-op; All joysticks already in use (or there might be zero joysticks)
	}
	else
	{
		SDL_Log("%d joysticks found, but none is suitable as an SDL_Gamepad.", numJoysticks);
		if (showMessage)
		{
			char messageBuf[1024];
			SDL_snprintf(messageBuf, sizeof(messageBuf),
						 "The game does not support your controller yet (\"%s\").\n\n"
						 "You can play with the keyboard and mouse instead. Sorry!",
						 SDL_GetJoystickNameForID(joysticks[0]));
			SDL_ShowSimpleMessageBox(
				SDL_MESSAGEBOX_WARNING,
				"Controller not supported",
				messageBuf,
				gSDLWindow);
		}
	}

	SDL_free(joysticks);

	return newGamepad;
}

void Rumble(float lowFrequencyStrength, float highFrequencyStrength, uint32_t ms, int playerID)
{
	// Don't bother if rumble turned off in prefs
	if (gGamePrefs.rumbleIntensity == 0)
	{
		return;
	}

	float rumbleIntensityFrac = ((float) gGamePrefs.rumbleIntensity) * (1.0f / 100.0f);
	lowFrequencyStrength *= rumbleIntensityFrac;
	highFrequencyStrength *= rumbleIntensityFrac;

	// If ANY_PLAYER, do rumble on all controllers
	if (playerID == ANY_PLAYER)
	{
		for (int i = 0; i < MAX_LOCAL_PLAYERS; i++)
		{
			Rumble(lowFrequencyStrength, highFrequencyStrength, ms, i);
		}
		return;
	}

	GAME_ASSERT(playerID >= 0);
	GAME_ASSERT(playerID < MAX_LOCAL_PLAYERS);

	const Gamepad* gamepad = &gGamepads[playerID];

	// Gotta have a valid SDL_Gamepad instance
	if (!gamepad->hasRumble || !gamepad->sdlGamepad)
	{
		return;
	}

	SDL_RumbleGamepad(
		gamepad->sdlGamepad,
		(Uint16)(lowFrequencyStrength * 65535),
		(Uint16)(highFrequencyStrength * 65535),
		(Uint32)((float)ms * rumbleIntensityFrac));

	// Prevent jetpack effect from kicking in while we're playing this
	gPlayerInfo[playerID].jetpackRumbleCooldown = ms * (1.0f / 1000.0f);
}

static void CloseGamepad(int controllerSlot)
{
	GAME_ASSERT(gGamepads[controllerSlot].open);
	GAME_ASSERT(gGamepads[controllerSlot].sdlGamepad);

	SDL_CloseGamepad(gGamepads[controllerSlot].sdlGamepad);
	gGamepads[controllerSlot].open = false;
	gGamepads[controllerSlot].sdlGamepad = NULL;
	gGamepads[controllerSlot].hasRumble = false;
}

static void MoveController(int oldSlot, int newSlot)
{
	if (oldSlot == newSlot)
		return;

	SDL_Log("Remapped player controller %d ---> %d\n", oldSlot, newSlot);

	gGamepads[newSlot] = gGamepads[oldSlot];

	// TODO: Does this actually work??
	if (gGamepads[newSlot].open)
	{
		SDL_SetGamepadPlayerIndex(gGamepads[newSlot].sdlGamepad, newSlot);
	}

	// Clear duplicate slot so we don't read it by mistake in the future
	gGamepads[oldSlot].open = false;
	gGamepads[oldSlot].sdlGamepad = NULL;
	gGamepads[oldSlot].hasRumble = false;
}

static void CompactGamepadSlots(void)
{
	int writeIndex = 0;

	for (int i = 0; i < MAX_LOCAL_PLAYERS; i++)
	{
		GAME_ASSERT(writeIndex <= i);

		if (gGamepads[i].open)
		{
			MoveController(i, writeIndex);
			writeIndex++;
		}
	}
}

void SwapControllers(int slotA, int slotB)
{
	if (slotA == slotB
		|| slotA < 0
		|| slotB < 0)
	{
		return;
	}

	Gamepad copy = gGamepads[slotB];
	gGamepads[slotB] = gGamepads[slotA];
	gGamepads[slotA] = copy;

	if (gGamepads[slotA].open)
		SDL_SetGamepadPlayerIndex(gGamepads[slotA].sdlGamepad, slotA);

	if (gGamepads[slotB].open)
		SDL_SetGamepadPlayerIndex(gGamepads[slotB].sdlGamepad, slotB);
}

void SetMainController(int oldSlot)
{
	SwapControllers(0, oldSlot);
}

static void TryFillUpVacantGamepadSlots(void)
{
	while (TryOpenAnyUnusedGamepad(false) != NULL)
	{
		// Successful; there might be more joysticks available, keep going
	}
}

static void OnJoystickRemoved(SDL_JoystickID joystickID)
{
	int gamepadSlot = GetGamepadSlotFromJoystick(joystickID);

	if (gamepadSlot >= 0)		// we're using this joystick
	{
		SDL_Log("Joystick %d was removed, was used by gamepad slot #%d", joystickID, gamepadSlot);

		// Nuke reference to this SDL_Gamepad
		CloseGamepad(gamepadSlot);
	}

	if (!gGamepadPlayerMappingLocked)
	{
		CompactGamepadSlots();
	}

	// Fill up any gamepad slots that are vacant
	TryFillUpVacantGamepadSlots();

	// Disable gUserPrefersGamepad if there are no gamepads connected
	if (0 == GetNumGamepad())
		gUserPrefersGamepad = false;
}

#if REQUIRE_LOCK_MAPPING
void LockPlayerGamepadMapping(void)
{
	int keyboardPlayer = gNumLocalPlayers-1;

	for (int i = 0; i < MAX_LOCAL_PLAYERS; i++)
	{
		gGamepads[i].fallbackToKeyboard = (i == keyboardPlayer);
	}

	gGamepadPlayerMappingLocked = true;
}

void UnlockPlayerGamepadMapping(void)
{
	gGamepadPlayerMappingLocked = false;
	CompactGamepadSlots();
	TryFillUpVacantGamepadSlots();
}
#endif

#if 0
const char* GetPlayerName(int whichPlayer)
{
	static char playerName[64];

	SDL_snprintf(playerName, sizeof(playerName),
			"%s %d", Localize(STR_PLAYER), whichPlayer+1);

	return playerName;
}

const char* GetPlayerNameWithInputDeviceHint(int whichPlayer)
{
	static char playerName[128];

	playerName[0] = '\0';

	snprintfcat(playerName, sizeof(playerName),
			"%s %d", Localize(STR_PLAYER), whichPlayer+1);

	if (gGameMode == GAME_MODE_CAPTUREFLAG)
	{
		snprintfcat(playerName, sizeof(playerName),
			", %s", Localize(gPlayerInfo[whichPlayer].team == 0 ? STR_RED_TEAM : STR_GREEN_TEAM));
	}

	bool enoughControllers = GetNumControllers() >= gNumLocalPlayers;

	if (!enoughControllers)
	{
		bool hasGamepad = gControllers[whichPlayer].open;
		snprintfcat(playerName, sizeof(playerName),
					"\n[%s]", Localize(hasGamepad? STR_GAMEPAD: STR_KEYBOARD));
	}

	return playerName;
}
#endif

#pragma mark - Reset bindings

void ResetDefaultKeyboardBindings(void)
{
	for (int i = 0; i < NUM_CONTROL_NEEDS; i++)
	{
		SDL_memcpy(gGamePrefs.bindings[i].key, kDefaultInputBindings[i].key, sizeof(gGamePrefs.bindings[i].key));
	}
}

void ResetDefaultGamepadBindings(void)
{
	for (int i = 0; i < NUM_CONTROL_NEEDS; i++)
	{
		SDL_memcpy(gGamePrefs.bindings[i].pad, kDefaultInputBindings[i].pad, sizeof(gGamePrefs.bindings[i].pad));
	}

	gGamePrefs.rumbleIntensity = 100;
}

void ResetDefaultMouseBindings(void)
{
	gGamePrefs.mouseSensitivityLevel = DEFAULT_MOUSE_SENSITIVITY_LEVEL;

	for (int i = 0; i < NUM_CONTROL_NEEDS; i++)
	{
		gGamePrefs.bindings[i].mouseButton = kDefaultInputBindings[i].mouseButton;
	}
}

#pragma mark - Mouse smoothing

#if MOUSE_SMOOTHING
static void MouseSmoothing_PopOldestSnapshot(void)
{
	struct MouseSmoothingState* state = &gMouseSmoothing;

	state->dxAccu -= state->snapshots[state->ringStart].dx;
	state->dyAccu -= state->snapshots[state->ringStart].dy;

	state->ringStart = (state->ringStart + 1) % DELTA_MOUSE_MAX_SNAPSHOTS;
	state->ringLength--;

	GAME_ASSERT(state->ringLength != 0 || (state->dxAccu == 0 && state->dyAccu == 0));
}

static void MouseSmoothing_ResetState(void)
{
	struct MouseSmoothingState* state = &gMouseSmoothing;
	state->ringLength = 0;
	state->ringStart = 0;
	state->dxAccu = 0;
	state->dyAccu = 0;
}

static void MouseSmoothing_StartFrame(void)
{
	struct MouseSmoothingState* state = &gMouseSmoothing;

	if (!state->initialized)
	{
		MouseSmoothing_ResetState();
		state->initialized = true;
	}

	uint32_t now = SDL_GetTicksNS();
	uint32_t cutoffTimestamp = now - kMouseSmoothingAccumulatorWindowNanoseconds;

	// Purge old snapshots
	while (state->ringLength > 0 &&
		   state->snapshots[state->ringStart].timestamp < cutoffTimestamp)
	{
		MouseSmoothing_PopOldestSnapshot();
	}
}

static void MouseSmoothing_OnMouseMotion(const SDL_MouseMotionEvent* motion)
{
	struct MouseSmoothingState* state = &gMouseSmoothing;

	// ignore mouse input if user has alt-tabbed away from the game
	if (!(SDL_GetWindowFlags(gSDLWindow) & SDL_WINDOW_INPUT_FOCUS))
	{
		return;
	}

	if (state->ringLength == DELTA_MOUSE_MAX_SNAPSHOTS)
	{
//		SDL_Log("%s: buffer full!!\n", __func__);
		MouseSmoothing_PopOldestSnapshot();				// make room at start of ring buffer
	}

	int i = (state->ringStart + state->ringLength) % DELTA_MOUSE_MAX_SNAPSHOTS;
	state->ringLength++;

	state->snapshots[i].timestamp = motion->timestamp;
	state->snapshots[i].dx = motion->xrel;
	state->snapshots[i].dy = motion->yrel;

	state->dxAccu += motion->xrel;
	state->dyAccu += motion->yrel;
}
#endif

OGLVector2D GetMouseDelta(void)
{
#if MOUSE_SMOOTHING
	struct MouseSmoothingState* state = &gMouseSmoothing;

	GAME_ASSERT(state->ringLength != 0 || (state->dxAccu == 0 && state->dyAccu == 0));

	return (OGLVector2D) {state->dxAccu, state->dyAccu};
#else
	static float timeSinceLastCall = 0;
	static OGLVector2D lastDelta = { 0, 0 };

	timeSinceLastCall += gFramesPerSecondFrac;

	// Mouse sensitivity settings are calibrated to feel good at 60 FPS,
	// so we mustn't poll GetRelativeMouseState any faster than 60 Hz.
	if (timeSinceLastCall >= (1.0f / 60.0f))
	{
		float x = 0;
		float y = 0;
		SDL_GetRelativeMouseState(&x, &y);
		lastDelta = (OGLVector2D){ x, y };
		timeSinceLastCall = 0;
	}

	return lastDelta;
#endif
}

OGLPoint2D GetMouseCoords640x480(void)
{
	float mx, my;
	int ww, wh;
	SDL_GetMouseState(&mx, &my);
	SDL_GetWindowSize(gSDLWindow, &ww, &wh);

	OGLRect r = Get2DLogicalRect(GetOverlayPaneNumber(), 1);

	float screenToPaneX = (r.right - r.left) / (float)ww;
	float screenToPaneY = (r.bottom - r.top) / (float)wh;

	OGLPoint2D p =
	{
		mx * screenToPaneX + r.left,
		my * screenToPaneY + r.top
	};

	return p;
}

void BackupRestoreCursorCoord(Boolean backup)
{
	static OGLPoint2D cursorCoordBackup = { -1, -1 };

	if (backup)
	{
		cursorCoordBackup = gCursorCoord;
	}
	else if (cursorCoordBackup.x >= 0)
	{
		gCursorCoord = cursorCoordBackup;
		OGLRect r = Get2DLogicalRect(GetOverlayPaneNumber(), 1);

		int ww, wh;
		SDL_GetWindowSize(gSDLWindow, &ww, &wh);

		float screenToPaneX = (r.right - r.left) / (float)ww;
		float screenToPaneY = (r.bottom - r.top) / (float)wh;

		float mx = (gCursorCoord.x - r.left) / screenToPaneX;
		float my = (gCursorCoord.y - r.top) / screenToPaneY;
		SDL_WarpMouseInWindow(gSDLWindow, mx, my);
	}
}

void GrabMouse(Boolean capture)
{
	if (capture)
	{
		BackupRestoreCursorCoord(true);
	}

	SDL_SetWindowMouseGrab(gSDLWindow, capture);
	SDL_SetWindowRelativeMouseMode(gSDLWindow, capture);
//	SDL_ShowCursor(capture? 0: 1);
	SetMacLinearMouse(capture);

	if (!capture)
	{
		BackupRestoreCursorCoord(false);
	}
}
