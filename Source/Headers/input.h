//
// input.h
//

#pragma once


		/* NEEDS */

#define ANY_PLAYER (-1)

#define MAX_USER_BINDINGS_PER_NEED		2
#define MAX_HARD_BINDINGS_PER_NEED		1
#define MAX_BINDINGS_PER_NEED		(MAX_USER_BINDINGS_PER_NEED + MAX_HARD_BINDINGS_PER_NEED)

#define NUM_SUPPORTED_MOUSE_BUTTONS			31
#define NUM_SUPPORTED_MOUSE_BUTTONS_PURESDL	(NUM_SUPPORTED_MOUSE_BUTTONS-2)
#define SDL_BUTTON_WHEELUP					(NUM_SUPPORTED_MOUSE_BUTTONS-2)		// make wheelup look like it's a button
#define SDL_BUTTON_WHEELDOWN				(NUM_SUPPORTED_MOUSE_BUTTONS-1)		// make wheeldown look like it's a button

#define NUM_MOUSE_SENSITIVITY_LEVELS		8
#define DEFAULT_MOUSE_SENSITIVITY_LEVEL		(NUM_MOUSE_SENSITIVITY_LEVELS/2)

enum
{
	KEYSTATE_ACTIVE_BIT		= 0b001,
	KEYSTATE_CHANGE_BIT		= 0b010,
	KEYSTATE_IGNORE_BIT		= 0b100,

	KEYSTATE_OFF			= 0b000,
	KEYSTATE_DOWN			= KEYSTATE_ACTIVE_BIT | KEYSTATE_CHANGE_BIT,
	KEYSTATE_HELD			= KEYSTATE_ACTIVE_BIT,
	KEYSTATE_UP				= KEYSTATE_OFF | KEYSTATE_CHANGE_BIT,
	KEYSTATE_IGNOREHELD		= KEYSTATE_OFF | KEYSTATE_IGNORE_BIT,
};

typedef struct
{
	int8_t		type;
	int8_t		id;
} PadBinding;

typedef struct
{
	int16_t			key[MAX_BINDINGS_PER_NEED];
	PadBinding		pad[MAX_BINDINGS_PER_NEED];
	int8_t			mouseButton;

} InputBinding;

enum
{
	kInputTypeUnbound = 0,
	kInputTypeButton,
	kInputTypeAxisPlus,
	kInputTypeAxisMinus,
};

enum
{
	kNeed_TurnLeft_Key	= 0,
	kNeed_TurnRight_Key,
	kNeed_PitchUp_Key,
	kNeed_PitchDown_Key,
	kNeed_Fire,
	kNeed_Drop,
	kNeed_NextWeapon,
	kNeed_Jetpack,
	kNeed_CameraMode,
	NUM_REMAPPABLE_NEEDS,

	kNeed_UIUp,
	kNeed_UIDown,
	kNeed_UILeft,
	kNeed_UIRight,
	kNeed_UIPrev,
	kNeed_UINext,
	kNeed_UIConfirm,
	kNeed_UIDelete,
	kNeed_UIStart,
	kNeed_UIBack,
	kNeed_UIPause,
	NUM_CONTROL_NEEDS
};


//============================================================================================

#if 0

void InitInput(void);
void UpdateInput(void);
Boolean GetNewKeyState(unsigned short key);
Boolean GetKeyState(unsigned short key);
Boolean AreAnyNewKeysPressed(void);
void UpdateKeyMap(void);


void ShutdownHID(void);

void DoInputConfigDialog(void);

void BuildHIDControlSettings(HIDControlSettingsType *settings);
void RestoreHIDControlSettings(HIDControlSettingsType *settings);
#endif


void InitInput(void);
void ReadKeyboard(void);
void InvalidateAllInputs(void);
void InvalidateNeedState(int need);

int GetKeyState(uint16_t sdlScancode);
int GetClickState(int mouseButton);
int GetNeedState(int needID, int playerID);
//int GetNeedStateAnyP(int needID);

#define IsKeyDown(scancode) (KEYSTATE_DOWN == GetKeyState((scancode)))
#define IsKeyHeld(scancode) (KEYSTATE_HELD == GetKeyState((scancode)))
#define IsKeyActive(scancode) (KEYSTATE_ACTIVE_BIT & GetKeyState((scancode)))
#define IsKeyUp(scancode) (KEYSTATE_UP == GetKeyState((scancode)))

#define IsClickDown(button) (KEYSTATE_DOWN == GetClickState((button)))
#define IsClickHeld(button) (KEYSTATE_HELD == GetClickState((button)))
#define IsClickUp(button) (KEYSTATE_UP == GetClickState((button)))

#define IsNeedDown(needID, playerID) (KEYSTATE_DOWN == GetNeedState((needID), (playerID)))
#define IsNeedHeld(needID, playerID) (KEYSTATE_HELD == GetNeedState((needID), (playerID)))
#define IsNeedActive(needID, playerID) (KEYSTATE_ACTIVE_BIT & GetNeedState((needID), (playerID)))
#define IsNeedUp(needID, playerID) (KEYSTATE_UP == GetNeedState((needID), (playerID)))

OGLVector2D GetAnalogSteering(int playerID);

Boolean UserWantsOut(void);
Boolean IsCheatKeyComboDown(void);
void InitControlBits(void);
void GetLocalKeyState(void);

Boolean GetControlState(short player, uint32_t control);
Boolean GetControlStateNew(short player, uint32_t control);

void PushKeys(void);
void PopKeys(void);

void DoSDLMaintenance(void);

int GetNumControllers(void);
struct _SDL_GameController* GetController(int n);
void Rumble(float strength, uint32_t ms);

void LockPlayerControllerMapping(void);
void UnlockPlayerControllerMapping(void);
const char* GetPlayerName(int whichPlayer);
const char* GetPlayerNameWithInputDeviceHint(int whichPlayer);

void ResetDefaultKeyboardBindings(void);
void ResetDefaultGamepadBindings(void);
void ResetDefaultMouseBindings(void);



