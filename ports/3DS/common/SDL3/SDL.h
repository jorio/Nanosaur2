// SDL3/SDL.h - minimal 3DS stub. Only exists so real game.h's
// `#include <SDL3/SDL.h>` parses; provides just enough typedefs for
// the C headers (SDL_Window*/SDL_GLContext-typed externs, SDL_Gamepad
// forward decl in input.h) to import. Swift files that call real SDL_*
// functions still fail to resolve those symbols here (expected - those 14
// files need PlatformBackend-style routing before they'll compile for 3DS,
// tracked separately in docs/3DS_PORT_PLAN.md).
#pragma once

#include <string.h>
#include <stdint.h>
#include <stdbool.h>

typedef struct SDL_Window SDL_Window;
typedef void *SDL_GLContext;
typedef struct SDL_Gamepad SDL_Gamepad;

void SDL_Log(const char *fmt, ...);

// MARK: - Basic types

typedef int32_t SDL_JoystickID;
typedef uint32_t SDL_DisplayID;
typedef int64_t SDL_Time;

typedef struct {
    int x, y, w, h;
} SDL_Rect;

typedef struct {
    int year;
    int month;
    int day;
    int hour;
    int minute;
    int second;
    int nanosecond;
    int day_of_week;
    int utc_offset;
} SDL_DateTime;

// MARK: - Scancodes
//
// Values match the standard USB HID keyboard usage page (same table
// SDL1/2/3 all use) - not load-bearing for correctness on 3DS (nothing
// here talks to a real keyboard), but keeping them consistent with
// upstream avoids surprises if any code ever does arithmetic on these
// (grep shows none does today, but no reason to invent a different table).

// A real C enum, not a plain int typedef + #defines: real SDL3 declares
// SDL_Scancode the same way, and Swift's importer only generates a real
// enum type (with `.rawValue`, which several call sites use) for actual
// C enums - a plain typedef would import as a bare Int32 alias instead.
typedef enum {
    SDL_SCANCODE_A = 4,
    SDL_SCANCODE_B = 5,
    SDL_SCANCODE_C = 6,
    SDL_SCANCODE_D = 7,
    SDL_SCANCODE_E = 8,
    SDL_SCANCODE_F = 9,
    SDL_SCANCODE_G = 10,
    SDL_SCANCODE_H = 11,
    SDL_SCANCODE_I = 12,
    SDL_SCANCODE_J = 13,
    SDL_SCANCODE_K = 14,
    SDL_SCANCODE_L = 15,
    SDL_SCANCODE_M = 16,
    SDL_SCANCODE_N = 17,
    SDL_SCANCODE_O = 18,
    SDL_SCANCODE_P = 19,
    SDL_SCANCODE_Q = 20,
    SDL_SCANCODE_R = 21,
    SDL_SCANCODE_S = 22,
    SDL_SCANCODE_T = 23,
    SDL_SCANCODE_U = 24,
    SDL_SCANCODE_V = 25,
    SDL_SCANCODE_W = 26,
    SDL_SCANCODE_X = 27,
    SDL_SCANCODE_Y = 28,
    SDL_SCANCODE_Z = 29,
    SDL_SCANCODE_1 = 30,
    SDL_SCANCODE_2 = 31,
    SDL_SCANCODE_3 = 32,
    SDL_SCANCODE_4 = 33,
    SDL_SCANCODE_5 = 34,
    SDL_SCANCODE_6 = 35,
    SDL_SCANCODE_7 = 36,
    SDL_SCANCODE_8 = 37,
    SDL_SCANCODE_9 = 38,
    SDL_SCANCODE_0 = 39,
    SDL_SCANCODE_RETURN = 40,
    SDL_SCANCODE_ESCAPE = 41,
    SDL_SCANCODE_BACKSPACE = 42,
    SDL_SCANCODE_TAB = 43,
    SDL_SCANCODE_SPACE = 44,
    SDL_SCANCODE_MINUS = 45,
    SDL_SCANCODE_EQUALS = 46,
    SDL_SCANCODE_LEFTBRACKET = 47,
    SDL_SCANCODE_RIGHTBRACKET = 48,
    SDL_SCANCODE_BACKSLASH = 49,
    SDL_SCANCODE_NONUSHASH = 50,
    SDL_SCANCODE_SEMICOLON = 51,
    SDL_SCANCODE_APOSTROPHE = 52,
    SDL_SCANCODE_GRAVE = 53,
    SDL_SCANCODE_COMMA = 54,
    SDL_SCANCODE_PERIOD = 55,
    SDL_SCANCODE_SLASH = 56,
    SDL_SCANCODE_CAPSLOCK = 57,
    SDL_SCANCODE_F1 = 58,
    SDL_SCANCODE_F2 = 59,
    SDL_SCANCODE_F3 = 60,
    SDL_SCANCODE_F4 = 61,
    SDL_SCANCODE_F5 = 62,
    SDL_SCANCODE_F6 = 63,
    SDL_SCANCODE_F7 = 64,
    SDL_SCANCODE_F8 = 65,
    SDL_SCANCODE_F9 = 66,
    SDL_SCANCODE_F10 = 67,
    SDL_SCANCODE_F11 = 68,
    SDL_SCANCODE_F12 = 69,
    SDL_SCANCODE_PRINTSCREEN = 70,
    SDL_SCANCODE_SCROLLLOCK = 71,
    SDL_SCANCODE_PAUSE = 72,
    SDL_SCANCODE_INSERT = 73,
    SDL_SCANCODE_HOME = 74,
    SDL_SCANCODE_PAGEUP = 75,
    SDL_SCANCODE_DELETE = 76,
    SDL_SCANCODE_END = 77,
    SDL_SCANCODE_PAGEDOWN = 78,
    SDL_SCANCODE_RIGHT = 79,
    SDL_SCANCODE_LEFT = 80,
    SDL_SCANCODE_DOWN = 81,
    SDL_SCANCODE_UP = 82,
    SDL_SCANCODE_NUMLOCKCLEAR = 83,
    SDL_SCANCODE_KP_DIVIDE = 84,
    SDL_SCANCODE_KP_MULTIPLY = 85,
    SDL_SCANCODE_KP_MINUS = 86,
    SDL_SCANCODE_KP_PLUS = 87,
    SDL_SCANCODE_KP_ENTER = 88,
    SDL_SCANCODE_KP_1 = 89,
    SDL_SCANCODE_KP_2 = 90,
    SDL_SCANCODE_KP_3 = 91,
    SDL_SCANCODE_KP_4 = 92,
    SDL_SCANCODE_KP_5 = 93,
    SDL_SCANCODE_KP_6 = 94,
    SDL_SCANCODE_KP_7 = 95,
    SDL_SCANCODE_KP_8 = 96,
    SDL_SCANCODE_KP_9 = 97,
    SDL_SCANCODE_KP_0 = 98,
    SDL_SCANCODE_KP_PERIOD = 99,
    SDL_SCANCODE_NONUSBACKSLASH = 100,
    SDL_SCANCODE_LCTRL = 224,
    SDL_SCANCODE_LSHIFT = 225,
    SDL_SCANCODE_LALT = 226,
    SDL_SCANCODE_LGUI = 227,
    SDL_SCANCODE_RCTRL = 228,
    SDL_SCANCODE_RSHIFT = 229,
    SDL_SCANCODE_RALT = 230,
    SDL_SCANCODE_RGUI = 231,
    SDL_SCANCODE_COUNT = 512
} SDL_Scancode;

// MARK: - Mouse buttons (never real on 3DS - a touchscreen, not a pointer -
// but Menu.swift's rebinding UI references these symbols even though that
// UI path is unreachable/nonfunctional on 3DS; only needs to compile)

#define SDL_BUTTON_LEFT 1
#define SDL_BUTTON_MIDDLE 2
#define SDL_BUTTON_RIGHT 3
#define SDL_BUTTON_X1 4
#define SDL_BUTTON_X2 5

// MARK: - Gamepad
//
// 3DS has no SDL_Gamepad subsystem; every function below is a real no-op
// implementation (SDL_GetJoysticks returns an empty list, SDL_OpenGamepad
// always fails, etc.) rather than an unimplemented stub - this is
// deliberate and correct on 3DS, not a gap: control input goes through
// CTRUInputBackend/hidKeysHeld (see PlatformBackend.swift), never a real
// SDL joystick/gamepad device.

typedef enum {
    SDL_GAMEPAD_AXIS_INVALID = -1,
    SDL_GAMEPAD_AXIS_LEFTX = 0,
    SDL_GAMEPAD_AXIS_LEFTY = 1,
    SDL_GAMEPAD_AXIS_RIGHTX = 2,
    SDL_GAMEPAD_AXIS_RIGHTY = 3,
    SDL_GAMEPAD_AXIS_LEFT_TRIGGER = 4,
    SDL_GAMEPAD_AXIS_RIGHT_TRIGGER = 5,
    SDL_GAMEPAD_AXIS_COUNT = 6
} SDL_GamepadAxis;

typedef enum {
    SDL_GAMEPAD_BUTTON_INVALID = -1,
    SDL_GAMEPAD_BUTTON_SOUTH = 0,
    SDL_GAMEPAD_BUTTON_EAST = 1,
    SDL_GAMEPAD_BUTTON_WEST = 2,
    SDL_GAMEPAD_BUTTON_NORTH = 3,
    SDL_GAMEPAD_BUTTON_START = 6,
    SDL_GAMEPAD_BUTTON_LEFT_STICK = 7,
    SDL_GAMEPAD_BUTTON_RIGHT_STICK = 8,
    SDL_GAMEPAD_BUTTON_LEFT_SHOULDER = 9,
    SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER = 10,
    SDL_GAMEPAD_BUTTON_DPAD_UP = 11,
    SDL_GAMEPAD_BUTTON_DPAD_DOWN = 12,
    SDL_GAMEPAD_BUTTON_DPAD_LEFT = 13,
    SDL_GAMEPAD_BUTTON_DPAD_RIGHT = 14,
    SDL_GAMEPAD_BUTTON_COUNT = 15
} SDL_GamepadButton;

#define SDL_PROP_GAMEPAD_CAP_RUMBLE_BOOLEAN "SDL.gamepad.cap.rumble"

SDL_JoystickID *SDL_GetJoysticks(int *count);
const char *SDL_GetJoystickNameForID(SDL_JoystickID instance_id);
bool SDL_IsGamepad(SDL_JoystickID instance_id);
SDL_Gamepad *SDL_OpenGamepad(SDL_JoystickID instance_id);
void SDL_CloseGamepad(SDL_Gamepad *gamepad);
SDL_JoystickID SDL_GetGamepadID(SDL_Gamepad *gamepad);
int16_t SDL_GetGamepadAxis(SDL_Gamepad *gamepad, SDL_GamepadAxis axis);
bool SDL_GetGamepadButton(SDL_Gamepad *gamepad, SDL_GamepadButton button);
const char *SDL_GetGamepadStringForAxis(SDL_GamepadAxis axis);
const char *SDL_GetGamepadStringForButton(SDL_GamepadButton button);
void SDL_SetGamepadPlayerIndex(SDL_Gamepad *gamepad, int player_index);
void SDL_RumbleGamepad(SDL_Gamepad *gamepad, uint16_t low_freq, uint16_t high_freq, uint32_t duration_ms);
unsigned int SDL_GetGamepadProperties(SDL_Gamepad *gamepad);
bool SDL_GetBooleanProperty(unsigned int props, const char *name, bool default_value);

const char *SDL_GetScancodeName(SDL_Scancode scancode);

// MARK: - Events
//
// 3DS has no SDL event queue - SDL_PollEvent always reports "no events
// pending" (a real, correct answer, not a stub gap: this engine's 3DS
// input goes through CTRUInputBackend/hidScanInput instead, same
// reasoning as the gamepad functions above). The struct only needs to
// support the field accesses Input.swift's switch statement already uses
// (event.type/.text.text/.wheel.x/.wheel.y/.gdevice.which) - not a real
// union matching desktop SDL_Event's memory layout, since nothing ever
// populates or reads it meaningfully here.

typedef int SDL_EventType;
#define SDL_EVENT_QUIT 0x100
#define SDL_EVENT_WINDOW_CLOSE_REQUESTED 0x201
#define SDL_EVENT_KEY_DOWN 0x300
#define SDL_EVENT_TEXT_INPUT 0x303
#define SDL_EVENT_MOUSE_MOTION 0x400
#define SDL_EVENT_MOUSE_WHEEL 0x403
#define SDL_EVENT_GAMEPAD_ADDED 0x653
#define SDL_EVENT_GAMEPAD_REMOVED 0x654
#define SDL_EVENT_GAMEPAD_BUTTON_DOWN 0x650
#define SDL_EVENT_GAMEPAD_BUTTON_UP 0x651

typedef struct { uint32_t type; const char *text; } SDL_TextInputEventCompat;
typedef struct { uint32_t type; float x, y; } SDL_MouseWheelEventCompat;
typedef struct { uint32_t type; SDL_JoystickID which; } SDL_GamepadDeviceEventCompat;

typedef struct {
    uint32_t type;
    SDL_TextInputEventCompat text;
    SDL_MouseWheelEventCompat wheel;
    SDL_GamepadDeviceEventCompat gdevice;
} SDL_Event;

void SDL_PumpEvents(void);
bool SDL_PollEvent(SDL_Event *event);

// MARK: - Mouse/keyboard queries (no real pointer/keyboard on 3DS)

const uint8_t *SDL_GetKeyboardState(int *numkeys);
uint32_t SDL_GetMouseState(float *x, float *y);
uint32_t SDL_GetRelativeMouseState(float *x, float *y);
void SDL_HideCursor(void);
void SDL_ShowCursor(void);
void SDL_WarpMouseInWindow(SDL_Window *window, float x, float y);

// MARK: - Window/display queries
//
// Real no-ops on 3DS: there's exactly one physical display pair (top/
// bottom LCD), no window manager, no resizing - Window.swift's desktop-
// multi-monitor-aware logic is dead code here, but still needs to compile
// (see docs/3DS_PORT_PLAN.md's milestone checklist, step 7: boot wiring
// skips straight past all of this to DoMainMenuScreen).

SDL_DisplayID *SDL_GetDisplays(int *count);
SDL_DisplayID SDL_GetDisplayForWindow(SDL_Window *window);
int SDL_GetDisplayUsableBounds(SDL_DisplayID displayID, SDL_Rect *rect);
void SDL_GetWindowSize(SDL_Window *window, int *w, int *h);
void SDL_GetWindowSizeInPixels(SDL_Window *window, int *w, int *h);
void SDL_SetWindowSize(SDL_Window *window, int w, int h);
void SDL_SetWindowPosition(SDL_Window *window, int x, int y);
bool SDL_SetWindowFullscreen(SDL_Window *window, bool fullscreen);
void SDL_SetWindowMouseGrab(SDL_Window *window, bool grabbed);
void SDL_SetWindowRelativeMouseMode(SDL_Window *window, bool enabled);
bool SDL_SyncWindow(SDL_Window *window);
#define SDL_WINDOWPOS_CENTERED_MASK 0x2FFF0000u

// MARK: - GL context/swap-interval (context lifecycle itself is
// PlatformBackend.swift's CTRUGraphicsBackend's job - these are the
// handful of extra GL-adjacent calls OGL_Support.swift makes directly)

void *SDL_GL_GetProcAddress(const char *proc);
int SDL_GL_SetSwapInterval(int interval);
int SDL_GL_GetSwapInterval(int *interval);

// MARK: - Time

uint64_t SDL_GetTicks(void);
int SDL_GetCurrentTime(SDL_Time *ticks);
bool SDL_TimeToDateTime(SDL_Time ticks, SDL_DateTime *dt, bool localTime);

// MARK: - Misc

#define SDL_MESSAGEBOX_WARNING 0x0010
int SDL_ShowSimpleMessageBox(uint32_t flags, const char *title, const char *message, SDL_Window *window);
uint32_t SDL_StepUTF8(const char **pstr, size_t *pslen);

void *SDL_memcpy(void *dst, const void *src, size_t len);
void *SDL_memset(void *dst, int c, size_t len);
void SDL_free(void *ptr);
