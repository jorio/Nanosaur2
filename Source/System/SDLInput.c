// SDL INPUT
// (C) 2022 Iliyas Jorio
// This file is part of Nanosaur 2. https://github.com/jorio/Nanosaur2

#include "game.h"

// Provide GameController stubs for CI runners that have old SDL packages.
// This lets us run quick compile checks on the CI without recompiling SDL.
#if !(SDL_VERSION_ATLEAST(2,0,12))
	#warning "Multiplayer controller support requires SDL 2.0.12 or later. The game will compile but controllers won't work!"
	static void SDL_GameControllerSetPlayerIndex(SDL_GameController *c, int i) {}
	static SDL_GameController *SDL_GameControllerFromPlayerIndex(int i) { return NULL; }
	#if !(SDL_VERSION_ATLEAST(2,0,9))
		static int SDL_GameControllerGetPlayerIndex(SDL_GameController *c) { return 0; }
	#endif
#endif

/***************/
/* CONSTANTS   */
/***************/

#define MAX_LOCAL_PLAYERS MAX_PLAYERS
#define gNumLocalPlayers gNumPlayers
#define REQUIRE_LOCK_MAPPING 0
#define MOUSE_SMOOTHING 0

#define kJoystickDeadZone				(33 * 32767 / 100)
#define kJoystickDeadZone_UI			(66 * 32767 / 100)
#define kJoystickDeadZoneFrac			(kJoystickDeadZone / 32767.0f)
#define kJoystickDeadZoneFracSquared	(kJoystickDeadZoneFrac * kJoystickDeadZoneFrac)

#if MOUSE_SMOOTHING
static const int kMouseSmoothingAccumulatorWindowTicks = 10;
#define DELTA_MOUSE_MAX_SNAPSHOTS 64
#endif

/**********************/
/*     PROTOTYPES     */
/**********************/

typedef uint8_t KeyState;

typedef struct Controller
{
	bool					open;
	bool					fallbackToKeyboard;
	SDL_GameController*		controllerInstance;
	SDL_JoystickID			joystickInstance;
	KeyState				needStates[NUM_CONTROL_NEEDS];
	float					needAnalog[NUM_CONTROL_NEEDS];
	OGLVector2D				analogSteering;
} Controller;

Boolean				gUserPrefersGamepad = false;

static Boolean		gControllerPlayerMappingLocked = false;
Controller			gControllers[MAX_LOCAL_PLAYERS];

static KeyState		gKeyboardStates[SDL_NUM_SCANCODES];
static KeyState		gMouseButtonStates[NUM_SUPPORTED_MOUSE_BUTTONS];
static KeyState		gNeedStates[NUM_CONTROL_NEEDS];

Boolean				gMouseMotionNow = false;
char				gTextInput[SDL_TEXTINPUTEVENT_TEXT_SIZE];

#if MOUSE_SMOOTHING
static struct MouseSmoothingState
{
	bool initialized;
	struct
	{
		uint32_t timestamp;
		int dx;
		int dy;
	} snapshots[DELTA_MOUSE_MAX_SNAPSHOTS];
	int ringStart;
	int ringLength;
	int dxAccu;
	int dyAccu;
} gMouseSmoothing = {0};

static void MouseSmoothing_ResetState(void);
static void MouseSmoothing_StartFrame(void);
static void MouseSmoothing_OnMouseMotion(const SDL_MouseMotionEvent* motion);
#endif

static void OnJoystickRemoved(SDL_JoystickID which);
static SDL_GameController* TryOpenControllerFromJoystick(int joystickIndex);
static SDL_GameController* TryOpenAnyUnusedController(bool showMessage);
static void TryFillUpVacantControllerSlots(void);
static int GetControllerSlotFromSDLJoystickInstanceID(SDL_JoystickID joystickInstanceID);

#pragma mark -
/**********************/

void InitInput(void)
{
	TryFillUpVacantControllerSlots();
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
	_Static_assert(1 == sizeof(KeyState), "sizeof(KeyState) has changed -- Rewrite this function without memset()!");

	memset(gNeedStates, KEYSTATE_IGNOREHELD, NUM_CONTROL_NEEDS);
	memset(gKeyboardStates, KEYSTATE_IGNOREHELD, SDL_NUM_SCANCODES);
	memset(gMouseButtonStates, KEYSTATE_IGNOREHELD, NUM_SUPPORTED_MOUSE_BUTTONS);

	for (int i = 0; i < MAX_LOCAL_PLAYERS; i++)
	{
		memset(gControllers[i].needStates, KEYSTATE_IGNOREHELD, NUM_CONTROL_NEEDS);
	}

}

static void UpdateRawKeyboardStates(void)
{
	int numkeys = 0;
	const UInt8* keystate = SDL_GetKeyboardState(&numkeys);

	int minNumKeys = GAME_MIN(numkeys, SDL_NUM_SCANCODES);

	for (int i = 0; i < minNumKeys; i++)
		UpdateKeyState(&gKeyboardStates[i], keystate[i]);

	// fill out the rest
	for (int i = minNumKeys; i < SDL_NUM_SCANCODES; i++)
		UpdateKeyState(&gKeyboardStates[i], false);
}

static void ParseAltEnter(void)
{
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
		bool buttonBit = 0 != (mouseButtons & SDL_BUTTON(i));
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
			if (scancode && scancode < SDL_NUM_SCANCODES)
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
	Controller* controller = &gControllers[controllerNum];

	if (!controller->open)
	{
		return;
	}

	SDL_GameController* controllerInstance = controller->controllerInstance;

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
					if (0 != SDL_GameControllerGetButton(controllerInstance, pb->id))
					{
						pressed = true;
						analogPressed = 1;
					}
					break;

				case kInputTypeAxisPlus:
				{
					int16_t axis = SDL_GameControllerGetAxis(controllerInstance, pb->id);
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
					int16_t axis = SDL_GameControllerGetAxis(controllerInstance, pb->id);
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
			case SDL_QUIT:
				CleanQuit();			// throws Pomme::QuitRequest
				return;

			case SDL_WINDOWEVENT:
				switch (event.window.event)
				{
					case SDL_WINDOWEVENT_CLOSE:
						CleanQuit();	// throws Pomme::QuitRequest
						return;

					/*
					case SDL_WINDOWEVENT_RESIZED:
						QD3D_OnWindowResized(event.window.data1, event.window.data2);
						break;
					*/
				}
				break;

				case SDL_TEXTINPUT:
					memcpy(gTextInput, event.text.text, sizeof(gTextInput));
					_Static_assert(sizeof(gTextInput) == sizeof(event.text.text), "size mismatch: gTextInput/event.text.text");
					break;

				case SDL_MOUSEMOTION:
					gMouseMotionNow = true;
					gUserPrefersGamepad = false;
#if MOUSE_SMOOTHING
					MouseSmoothing_OnMouseMotion(&event.motion);
#endif
					break;

				case SDL_MOUSEWHEEL:
					gUserPrefersGamepad = false;
					mouseWheelDeltaX += event.wheel.y;
					mouseWheelDeltaY += event.wheel.x;
					break;

				case SDL_CONTROLLERDEVICEADDED:
					// event.cdevice.which is the joystick's DEVICE INDEX (not an instance id!)
					TryOpenControllerFromJoystick(event.cdevice.which);
					break;

				case SDL_CONTROLLERDEVICEREMOVED:
					// event.cdevice.which is the joystick's UNIQUE INSTANCE ID (not an index!)
					OnJoystickRemoved(event.cdevice.which);
					break;

				/*
				case SDL_CONTROLLERDEVICEREMAPPED:
					printf("C-Device remapped! %d\n", event.cdevice.which);
					break;
				*/

				case SDL_KEYDOWN:
					gUserPrefersGamepad = false;
					break;

				case SDL_CONTROLLERBUTTONDOWN:
				case SDL_CONTROLLERBUTTONUP:
				case SDL_JOYBUTTONDOWN:
					gUserPrefersGamepad = true;
					break;
		}
	}


	// Refresh the state of each individual keyboard key
	UpdateRawKeyboardStates();

	// On ALT+ENTER, toggle fullscreen, and ignore ENTER until keyup
	ParseAltEnter();

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
	if (sdlScancode >= SDL_NUM_SCANCODES)
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
	for (int i = 0; i < MAX_LOCAL_PLAYERS; i++)
	{
		if (gControllers[i].open && gControllers[i].needStates[needID])
		{
			return gControllers[i].needStates[needID];
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

	const Controller* controller = &gControllers[playerID];

	if (controller->open && controller->needStates[needID])
	{
		return controller->needStates[needID];
	}

	// Fallback to KB/M
#if REQUIRE_LOCK_MAPPING
	if (gNumLocalPlayers <= 1 || controller->fallbackToKeyboard)
#else
	if (playerID == 0)
#endif
	{
		return gNeedStates[needID];
	}

	return KEYSTATE_OFF;
}

float GetNeedAnalogValue(int needID, int playerID)
{
	GAME_ASSERT(playerID >= 0);
	GAME_ASSERT(playerID < MAX_LOCAL_PLAYERS);
	GAME_ASSERT(needID >= 0);
	GAME_ASSERT(needID < NUM_CONTROL_NEEDS);

	const Controller* controller = &gControllers[playerID];

	if (controller->open && controller->needAnalog[needID] != 0.0f)
	{
		return controller->needAnalog[needID];
	}

	// Fallback to KB/M
#if REQUIRE_LOCK_MAPPING
	if (gNumLocalPlayers <= 1 || controller->fallbackToKeyboard)
#else
	if (playerID == 0)
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
	return IsNeedDown(kNeed_UIConfirm, ANY_PLAYER)
		|| IsNeedDown(kNeed_UIBack, ANY_PLAYER)
		|| IsNeedDown(kNeed_UIPause, ANY_PLAYER)
//		|| GetNewClickState(SDL_BUTTON_LEFT)
        ;
}

Boolean IsCheatKeyComboDown(void)
{
	// The original Mac version used B-R-I, but some cheap PC keyboards can't register
	// this particular key combo, so C-M-R is available as an alternative.
	return (IsKeyHeld(SDL_SCANCODE_B) && IsKeyHeld(SDL_SCANCODE_R) && IsKeyHeld(SDL_SCANCODE_I))
		|| (IsKeyHeld(SDL_SCANCODE_C) && IsKeyHeld(SDL_SCANCODE_M) && IsKeyHeld(SDL_SCANCODE_R));
}

#pragma mark - Analog steering

static float GetControllerAnalogSteeringAxis(SDL_GameController* sdlController, SDL_GameControllerAxis axis)
{
			/****************************/
			/* SET PLAYER AXIS CONTROLS */
			/****************************/

	float steer = 0; 											// assume no control input

			/* FIRST CHECK ANALOG AXES */

	if (sdlController)
	{
		Sint16 dxRaw = SDL_GameControllerGetAxis(sdlController, axis);

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

int GetNumControllers(void)
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
		if (gControllers[i].open)
		{
			count++;
		}
	}
#endif

	return count;
}

SDL_GameController* GetController(int n)
{
	if (gControllers[n].open)
	{
		return gControllers[n].controllerInstance;
	}
	else
	{
		return NULL;
	}
}

static int FindFreeControllerSlot()
{
	for (int i = 0; i < MAX_LOCAL_PLAYERS; i++)
	{
		if (!gControllers[i].open)
		{
			return i;
		}
	}

	return -1;
}

static int GetControllerSlotFromJoystick(int joystickIndex)
{
	SDL_JoystickID joystickInstanceID = SDL_JoystickGetDeviceInstanceID(joystickIndex);

	for (int controllerSlot = 0; controllerSlot < MAX_LOCAL_PLAYERS; controllerSlot++)
	{
		if (gControllers[controllerSlot].open &&
			gControllers[controllerSlot].joystickInstance == joystickInstanceID)
		{
			return controllerSlot;
		}
	}

	return -1;
}

static SDL_GameController* TryOpenControllerFromJoystick(int joystickIndex)
{
	int controllerSlot = -1;

	// First, check that it's not in use already
	controllerSlot = GetControllerSlotFromJoystick(joystickIndex);
	if (controllerSlot >= 0)	// in use
	{
		return gControllers[controllerSlot].controllerInstance;
	}
	
	// If we can't get an SDL_GameController from that joystick, don't bother
	if (!SDL_IsGameController(joystickIndex))
	{
		return NULL;
	}

	// Reserve a controller slot
	controllerSlot = FindFreeControllerSlot();
	if (controllerSlot < 0)
	{
		printf("All controller slots used up.\n");
		// TODO: when a controller is unplugged, if all controller slots are used up, re-scan connected joysticks and try to open any unopened joysticks.
		return NULL;
	}

	// Use this one
	SDL_GameController* controllerInstance = SDL_GameControllerOpen(joystickIndex);

	// Assign player ID
	SDL_GameControllerSetPlayerIndex(controllerInstance, controllerSlot);

	gControllers[controllerSlot] = (Controller)
	{
		.open = true,
		.controllerInstance = controllerInstance,
		.joystickInstance = SDL_JoystickGetDeviceInstanceID(joystickIndex),
	};

	printf("Opened joystick %d as controller: %s\n",
		gControllers[controllerSlot].joystickInstance,
		SDL_GameControllerName(gControllers[controllerSlot].controllerInstance));

	gUserPrefersGamepad = true;

	return gControllers[controllerSlot].controllerInstance;
}

static SDL_GameController* TryOpenAnyUnusedController(bool showMessage)
{
	int numJoysticks = SDL_NumJoysticks();
	int numJoysticksAlreadyInUse = 0;

	if (numJoysticks == 0)
	{
		return NULL;
	}

	for (int i = 0; i < numJoysticks; ++i)
	{
		// Usable as an SDL GameController?
		if (!SDL_IsGameController(i))
		{
			continue;
		}

		// Already in use?
		if (GetControllerSlotFromJoystick(i) >= 0)
		{
			numJoysticksAlreadyInUse++;
			continue;
		}

		// Use this one
		SDL_GameController* newController = TryOpenControllerFromJoystick(i);
		if (newController)
		{
			return newController;
		}
	}

	if (numJoysticksAlreadyInUse == numJoysticks)
	{
		// All joysticks already in use
		return NULL;
	}

	printf("Joystick(s) found, but none is suitable as an SDL_GameController.\n");
	if (showMessage)
	{
		char messageBuf[1024];
		snprintf(messageBuf, sizeof(messageBuf),
					"The game does not support your controller yet (\"%s\").\n\n"
					"You can play with the keyboard and mouse instead. Sorry!",
					SDL_JoystickNameForIndex(0));
		SDL_ShowSimpleMessageBox(
				SDL_MESSAGEBOX_WARNING,
				"Controller not supported",
				messageBuf,
				gSDLWindow);
	}

	return NULL;
}

void Rumble(float strength, uint32_t ms)
{
	#if 0	// TODO: Rumble for specific player
	if (NULL == gSDLController || !gGamePrefs.gamepadRumble)
		return;

#if !(SDL_VERSION_ATLEAST(2,0,9))
	#warning Rumble support requires SDL 2.0.9 or later
#else
	SDL_GameControllerRumble(gSDLController, (Uint16)(strength * 65535), (Uint16)(strength * 65535), ms);
#endif
	#endif
}

static int GetControllerSlotFromSDLJoystickInstanceID(SDL_JoystickID joystickInstanceID)
{
	for (int i = 0; i < MAX_LOCAL_PLAYERS; i++)
	{
		if (gControllers[i].open && gControllers[i].joystickInstance == joystickInstanceID)
		{
			return i;
		}
	}

	return -1;
}

static void CloseController(int controllerSlot)
{
	GAME_ASSERT(gControllers[controllerSlot].open);
	GAME_ASSERT(gControllers[controllerSlot].controllerInstance);

	SDL_GameControllerClose(gControllers[controllerSlot].controllerInstance);
	gControllers[controllerSlot].open = false;
	gControllers[controllerSlot].controllerInstance = NULL;
	gControllers[controllerSlot].joystickInstance = -1;
}

static void MoveController(int oldSlot, int newSlot)
{
	if (oldSlot == newSlot)
		return;

	printf("Remapped player controller %d ---> %d\n", oldSlot, newSlot);

	gControllers[newSlot] = gControllers[oldSlot];
	
	// TODO: Does this actually work??
	if (gControllers[newSlot].open)
	{
		SDL_GameControllerSetPlayerIndex(gControllers[newSlot].controllerInstance, newSlot);
	}

	// Clear duplicate slot so we don't read it by mistake in the future
	gControllers[oldSlot].controllerInstance = NULL;
	gControllers[oldSlot].joystickInstance = -1;
	gControllers[oldSlot].open = false;
}

static void CompactControllerSlots(void)
{
	int writeIndex = 0;

	for (int i = 0; i < MAX_LOCAL_PLAYERS; i++)
	{
		GAME_ASSERT(writeIndex <= i);

		if (gControllers[i].open)
		{
			MoveController(i, writeIndex);
			writeIndex++;
		}
	}
}

static void TryFillUpVacantControllerSlots(void)
{
	while (TryOpenAnyUnusedController(false) != NULL)
	{
		// Successful; there might be more joysticks available, keep going
	}
}

static void OnJoystickRemoved(SDL_JoystickID joystickInstanceID)
{
	int controllerSlot = GetControllerSlotFromSDLJoystickInstanceID(joystickInstanceID);

	if (controllerSlot >= 0)		// we're using this joystick
	{
		printf("Joystick %d was removed, was used by controller slot #%d\n", joystickInstanceID, controllerSlot);

		// Nuke reference to this controller+joystick
		CloseController(controllerSlot);
	}

	if (!gControllerPlayerMappingLocked)
	{
		CompactControllerSlots();
	}

	// Fill up any controller slots that are vacant
	TryFillUpVacantControllerSlots();

	// Disable gUserPrefersGamepad if there are no controllers connected
	if (0 == GetNumControllers())
		gUserPrefersGamepad = false;
}

#if REQUIRE_LOCK_MAPPING
void LockPlayerControllerMapping(void)
{
	int keyboardPlayer = gNumLocalPlayers-1;

	for (int i = 0; i < MAX_LOCAL_PLAYERS; i++)
	{
		gControllers[i].fallbackToKeyboard = (i == keyboardPlayer);
	}

	gControllerPlayerMappingLocked = true;
}

void UnlockPlayerControllerMapping(void)
{
	gControllerPlayerMappingLocked = false;
	CompactControllerSlots();
	TryFillUpVacantControllerSlots();
}
#endif

#if 0
const char* GetPlayerName(int whichPlayer)
{
	static char playerName[64];

	snprintf(playerName, sizeof(playerName),
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
		memcpy(gGamePrefs.bindings[i].key, kDefaultInputBindings[i].key, sizeof(gGamePrefs.bindings[i].key));
	}
}

void ResetDefaultGamepadBindings(void)
{
	for (int i = 0; i < NUM_CONTROL_NEEDS; i++)
	{
		memcpy(gGamePrefs.bindings[i].pad, kDefaultInputBindings[i].pad, sizeof(gGamePrefs.bindings[i].pad));
	}
}

void ResetDefaultMouseBindings(void)
{
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

	uint32_t now = SDL_GetTicks();
	uint32_t cutoffTimestamp = now - kMouseSmoothingAccumulatorWindowTicks;

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
//		printf("%s: buffer full!!\n", __func__);
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

	return (OGLVector2D) {(float) state->dxAccu, (float) state->dyAccu};
#else
	int x = 0;
	int y = 0;
	SDL_GetRelativeMouseState(&x, &y);
	return (OGLVector2D) {(float) x, (float) y};
#endif
}

void GrabMouse(Boolean capture)
{
	SDL_SetWindowGrab(gSDLWindow, capture);
	SDL_SetRelativeMouseMode(capture? SDL_TRUE: SDL_FALSE);
//	SDL_ShowCursor(capture? 0: 1);
	SetMacLinearMouse(capture);
}
