// sdlcompat.c - implements ports/3DS/common/SDL3/SDL.h's declarations.
// See docs/3DS_PORT_PLAN.md, "Milestone: a real, navigable main menu".
//
// Most of this is deliberately a real no-op, not a stub gap: 3DS has no
// SDL event queue, no SDL_Gamepad subsystem, no window manager, no mouse
// pointer - "no events pending"/"no gamepads connected"/"one fixed-size
// window" are correct answers on this platform, not placeholders. Actual
// 3DS input goes through CTRUInputBackend/hidScanInput
// (PlatformBackend.swift), never through these functions.
//
// A handful of functions here ARE meant to eventually do something real
// once wired up (SDL_GetTicks for timing, SDL_GL_SetSwapInterval for
// vsync) - marked individually below.
//
// Separate translation unit from the Swift bridging header, like
// glcompat.c/shim.c - never compiled through -import-objc-header.

#include "SDL3/SDL.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

// MARK: - String/varargs (real implementations - naming shims only)

int SDL_snprintf(char *text, size_t maxlen, const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    int result = vsnprintf(text, maxlen, fmt, ap);
    va_end(ap);
    return result;
}

int SDL_vsnprintf(char *text, size_t maxlen, const char *fmt, va_list ap)
{
    return vsnprintf(text, maxlen, fmt, ap);
}

const char *SDL_strchr(const char *str, int c) { return strchr(str, c); }
int SDL_strncmp(const char *str1, const char *str2, size_t maxlen) { return strncmp(str1, str2, maxlen); }

SDL_Locale **SDL_GetPreferredLocales(int *count)
{
    if (count) {
        *count = 0;
    }
    return NULL;
}

// glGetString is picaGL's real implementation (source/get.c) now - no
// stub needed here.

const char *SDL_GetCurrentVideoDriver(void) { return "3ds"; }
const char *SDL_GetGamepadName(SDL_Gamepad *gamepad) { (void)gamepad; return "Nintendo 3DS"; }

void SDL_GL_SwapWindow(SDL_Window *window) { (void)window; } // see SDL.h's comment on this declaration

// MARK: - Memory (real implementations - just naming shims for the
// SDL_-prefixed names some call sites use instead of plain libc names)

void *SDL_memcpy(void *dst, const void *src, size_t len) { return memcpy(dst, src, len); }
void *SDL_memset(void *dst, int c, size_t len) { return memset(dst, c, len); }
void SDL_free(void *ptr) { free(ptr); }

// MARK: - Events (always empty queue - see file header comment)

void SDL_PumpEvents(void) { }

bool SDL_PollEvent(SDL_Event *event)
{
    (void)event;
    return false;
}

// MARK: - Mouse/keyboard (no real devices - see file header comment)

const uint8_t *SDL_GetKeyboardState(int *numkeys)
{
    if (numkeys) {
        *numkeys = 0;
    }
    return NULL;
}

uint32_t SDL_GetMouseState(float *x, float *y)
{
    if (x) *x = 0;
    if (y) *y = 0;
    return 0;
}

uint32_t SDL_GetRelativeMouseState(float *x, float *y)
{
    if (x) *x = 0;
    if (y) *y = 0;
    return 0;
}

void SDL_HideCursor(void) { }
void SDL_ShowCursor(void) { }
void SDL_WarpMouseInWindow(SDL_Window *window, float x, float y) { (void)window; (void)x; (void)y; }

// MARK: - Gamepad (no SDL_Gamepad subsystem - see file header comment)

SDL_JoystickID *SDL_GetJoysticks(int *count)
{
    if (count) {
        *count = 0;
    }
    return NULL;
}

const char *SDL_GetJoystickNameForID(SDL_JoystickID instance_id) { (void)instance_id; return NULL; }
bool SDL_IsGamepad(SDL_JoystickID instance_id) { (void)instance_id; return false; }
SDL_Gamepad *SDL_OpenGamepad(SDL_JoystickID instance_id) { (void)instance_id; return NULL; }
void SDL_CloseGamepad(SDL_Gamepad *gamepad) { (void)gamepad; }
SDL_JoystickID SDL_GetGamepadID(SDL_Gamepad *gamepad) { (void)gamepad; return 0; }
int16_t SDL_GetGamepadAxis(SDL_Gamepad *gamepad, SDL_GamepadAxis axis) { (void)gamepad; (void)axis; return 0; }
bool SDL_GetGamepadButton(SDL_Gamepad *gamepad, SDL_GamepadButton button) { (void)gamepad; (void)button; return false; }
const char *SDL_GetGamepadStringForAxis(SDL_GamepadAxis axis) { (void)axis; return ""; }
const char *SDL_GetGamepadStringForButton(SDL_GamepadButton button) { (void)button; return ""; }
void SDL_SetGamepadPlayerIndex(SDL_Gamepad *gamepad, int player_index) { (void)gamepad; (void)player_index; }
void SDL_RumbleGamepad(SDL_Gamepad *gamepad, uint16_t low_freq, uint16_t high_freq, uint32_t duration_ms) { (void)gamepad; (void)low_freq; (void)high_freq; (void)duration_ms; }
unsigned int SDL_GetGamepadProperties(SDL_Gamepad *gamepad) { (void)gamepad; return 0; }
bool SDL_GetBooleanProperty(unsigned int props, const char *name, bool default_value) { (void)props; (void)name; return default_value; }

const char *SDL_GetScancodeName(SDL_Scancode scancode) { (void)scancode; return ""; }

// MARK: - Window/display (one fixed top/bottom LCD pair, no window
// manager - see file header comment. Real geometry (400x240 top /
// 320x240 bottom) still needs wiring into whatever calls
// SDL_GetWindowSize for layout purposes - milestone step 7, boot wiring -
// but isn't needed for these to compile/link.)

SDL_DisplayID *SDL_GetDisplays(int *count)
{
    static SDL_DisplayID one = 1;
    if (count) {
        *count = 1;
    }
    return &one;
}

SDL_DisplayID SDL_GetDisplayForWindow(SDL_Window *window) { (void)window; return 1; }

int SDL_GetDisplayUsableBounds(SDL_DisplayID displayID, SDL_Rect *rect)
{
    (void)displayID;
    if (rect) {
        rect->x = 0; rect->y = 0; rect->w = 400; rect->h = 240;
    }
    return 1;
}

void SDL_GetWindowSize(SDL_Window *window, int *w, int *h)
{
    (void)window;
    if (w) *w = 400;
    if (h) *h = 240;
}

void SDL_GetWindowSizeInPixels(SDL_Window *window, int *w, int *h)
{
    SDL_GetWindowSize(window, w, h);
}

void SDL_SetWindowSize(SDL_Window *window, int w, int h) { (void)window; (void)w; (void)h; }
void SDL_SetWindowPosition(SDL_Window *window, int x, int y) { (void)window; (void)x; (void)y; }
bool SDL_SetWindowFullscreen(SDL_Window *window, bool fullscreen) { (void)window; (void)fullscreen; return true; }
void SDL_SetWindowMouseGrab(SDL_Window *window, bool grabbed) { (void)window; (void)grabbed; }
void SDL_SetWindowRelativeMouseMode(SDL_Window *window, bool enabled) { (void)window; (void)enabled; }
bool SDL_SyncWindow(SDL_Window *window) { (void)window; return true; }

// MARK: - GL context/swap-interval

void *SDL_GL_GetProcAddress(const char *proc) { (void)proc; return NULL; } // citro3d needs no GL extension lookup
int SDL_GL_SetSwapInterval(int interval) { (void)interval; return 0; } // Phase 3: wire to gfxSetVsync/whatever citro3d's frame pacing needs
int SDL_GL_GetSwapInterval(int *interval) { if (interval) *interval = 1; return 0; }

// MARK: - Time
//
// Real implementation still needed (marked, unlike the no-ops above):
// this always reports "no time has passed", which will make anything
// timing-sensitive (animation, frame pacing) misbehave once actually run.
// A real 3DS tick source (osGetTime()/svcGetSystemTick()) needs wiring in
// - deferred because <3ds.h> can't be included here without hitting the
// same Handle-typedef collision documented in game_3ds.h if this file
// ever needs to coexist with Pomme types (it doesn't yet, but osGetTime's
// own declaration lives behind <3ds.h>) - worth a dedicated small
// extern-declaration shim (same trick used for hidScanInput/hidKeysHeld
// in game_3ds.h) rather than pulling in the whole header here blind.

uint64_t SDL_GetTicks(void) { return 0; }
int SDL_GetCurrentTime(SDL_Time *ticks) { if (ticks) *ticks = 0; return 0; }
bool SDL_TimeToDateTime(SDL_Time ticks, SDL_DateTime *dt, bool localTime)
{
    (void)ticks; (void)localTime;
    if (dt) {
        memset(dt, 0, sizeof(*dt));
    }
    return true;
}

// MARK: - Misc

int SDL_ShowSimpleMessageBox(uint32_t flags, const char *title, const char *message, SDL_Window *window)
{
    (void)flags; (void)title; (void)message; (void)window;
    return 0; // no message box UI on 3DS; callers already only use this for fatal-error reporting, which DoFatalAlert handles separately
}

uint32_t SDL_StepUTF8(const char **pstr, size_t *pslen)
{
    // Minimal ASCII-only decode (real SDL_StepUTF8 does full UTF-8) -
    // sufficient for menu text input, which is out of scope for the
    // main-menu-navigation milestone anyway (no text entry needed to
    // reach/navigate the main menu).
    if (!pstr || !*pstr || (pslen && *pslen == 0)) {
        return 0;
    }
    unsigned char c = (unsigned char)**pstr;
    if (c == 0) {
        return 0;
    }
    (*pstr)++;
    if (pslen) {
        (*pslen)--;
    }
    return c;
}
