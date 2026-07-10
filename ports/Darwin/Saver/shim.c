// shim.c - the screen-saver bundle's platform shim (ports/Darwin).
//
// The curated engine subset compiles against the real SDL3 headers
// (extern/SDL3.framework) for types/constants, but the bundle does NOT
// link SDL3: a screen saver must not spin up SDL's video/event machinery
// inside legacyScreenSaver, and the handful of SDL calls the subset
// actually reaches at runtime are trivial (monotonic clock, logging,
// sleep). This file implements those few for real, plus link-only no-op
// stubs for SDL calls that live in compiled-but-unreachable code paths
// (Swift compiles whole files; the linker still wants every symbol).
// Same philosophy as ports/3DS's shim.c.

#include <dlfcn.h>
#include <mach/mach_time.h>
#include <os/log.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

// MARK: - GL proc lookup (real)

// OpenGL.framework is linked directly, so dlsym on our own image space
// resolves gl* entry points - replaces SDL_GL_GetProcAddress.
void* Saver_GLGetProcAddress(const char* name)
{
	return dlsym(RTLD_DEFAULT, name);
}

// MARK: - Timing (real)

// SDL_GetTicksNS: nanoseconds, monotonic, arbitrary epoch. The engine only
// does wrapping differences (SwMicroseconds/CalcFramesPerSecond), so
// CLOCK_UPTIME_RAW's epoch is fine as-is.
uint64_t SDL_GetTicksNS(void)
{
	return clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
}

uint64_t SDL_GetTicks(void)
{
	return SDL_GetTicksNS() / 1000000u;
}

void SDL_Delay(uint32_t ms)
{
	usleep(ms * 1000u);
}

// MARK: - Logging / alerts (real, via os_log)

static void SaverLogV(const char* fmt, va_list args)
{
	char message[1024];
	vsnprintf(message, sizeof(message), fmt, args);
	os_log(OS_LOG_DEFAULT, "[Nanosaur2Saver] %{public}s", message);
}

void SDL_Log(const char* fmt, ...)
{
	va_list args;
	va_start(args, fmt);
	SaverLogV(fmt, args);
	va_end(args);
}

void SDL_LogError(int category, const char* fmt, ...)
{
	(void) category;
	va_list args;
	va_start(args, fmt);
	SaverLogV(fmt, args);
	va_end(args);
}

// A screen saver can't show dialogs; log and carry on (DoFatalAlert's
// caller exits via SwExitToShell anyway).
int SDL_ShowSimpleMessageBox(uint32_t flags, const char* title, const char* message, void* window)
{
	(void) flags;
	(void) window;
	os_log_error(OS_LOG_DEFAULT, "[Nanosaur2Saver] ALERT: %{public}s: %{public}s",
		title ? title : "", message ? message : "");
	return 1;
}

// MARK: - libc passthroughs

int SDL_vsnprintf(char* text, size_t maxlen, const char* fmt, va_list ap)
{
	return vsnprintf(text, maxlen, fmt, ap);
}

int SDL_snprintf(char* text, size_t maxlen, const char* fmt, ...)
{
	va_list args;
	va_start(args, fmt);
	int rc = vsnprintf(text, maxlen, fmt, args);
	va_end(args);
	return rc;
}

void* SDL_memset(void* dst, int c, size_t len)
{
	return memset(dst, c, len);
}

void* SDL_memcpy(void* dst, const void* src, size_t len)
{
	return memcpy(dst, src, len);
}

// MARK: - Memory (real - AllocPtr/SafeDisposePtr route through these)

#include <stdlib.h>

void* SDL_malloc(size_t size) { return malloc(size); }
void* SDL_calloc(size_t nmemb, size_t size) { return calloc(nmemb, size); }
void* SDL_realloc(void* mem, size_t size) { return realloc(mem, size); }
void SDL_free(void* mem) { free(mem); }

// MARK: - UTF-8 decoding (real - Atlas.swift's kerning-table parser)

// Matches SDL_StepUTF8's contract: decode the codepoint at **pstr, advance
// *pstr past it (and decrement *pslen if given), return the codepoint;
// 0xFFFD for malformed bytes, 0 at the end of the string.
uint32_t SDL_StepUTF8(const char** pstr, size_t* pslen)
{
	const unsigned char* p = (const unsigned char*) *pstr;
	size_t avail = pslen ? *pslen : (size_t) -1;

	if (avail == 0 || *p == '\0')
	{
		return 0;
	}

	uint32_t cp = 0;
	int len = 1;

	if (*p < 0x80)          { cp = *p; len = 1; }
	else if ((*p >> 5) == 0x6 && avail >= 2) { cp = *p & 0x1F; len = 2; }
	else if ((*p >> 4) == 0xE && avail >= 3) { cp = *p & 0x0F; len = 3; }
	else if ((*p >> 3) == 0x1E && avail >= 4) { cp = *p & 0x07; len = 4; }
	else
	{
		*pstr += 1;
		if (pslen) *pslen -= 1;
		return 0xFFFD;
	}

	for (int i = 1; i < len; i++)
	{
		if ((p[i] & 0xC0) != 0x80)
		{
			*pstr += 1;
			if (pslen) *pslen -= 1;
			return 0xFFFD;
		}
		cp = (cp << 6) | (p[i] & 0x3F);
	}

	*pstr += len;
	if (pslen) *pslen -= (size_t) len;
	return cp;
}

// MARK: - Link-only stubs
//
// Referenced by compiled-but-unreachable code paths (fullscreen toggling,
// display picking, cursor handling, SDL GL context teardown - all
// desktop-window concerns that never run inside a screen saver).

typedef struct { int x, y, w, h; } SaverSDLRect;

void SDL_HideCursor(void) {}
void SDL_ShowCursor(void) {}
int SDL_GL_MakeCurrent(void* window, void* context) { (void) window; (void) context; return 0; }
void SDL_GL_DestroyContext(void* context) { (void) context; }
uint32_t SDL_GetDisplayForWindow(void* window) { (void) window; return 0; }
int SDL_GetDisplayUsableBounds(uint32_t displayID, SaverSDLRect* rect) { (void) displayID; (void) rect; return 0; }
uint32_t* SDL_GetDisplays(int* count) { if (count) *count = 0; return NULL; }
int SDL_SetWindowFullscreen(void* window, int fullscreen) { (void) window; (void) fullscreen; return 0; }
int SDL_SetWindowPosition(void* window, int x, int y) { (void) window; (void) x; (void) y; return 0; }
int SDL_SetWindowSize(void* window, int w, int h) { (void) window; (void) w; (void) h; return 0; }
int SDL_SyncWindow(void* window) { (void) window; return 0; }

// SwExitToShell's platform teardown (Boot.cpp's on desktop). Nothing to
// tear down here; the process belongs to legacyScreenSaver.
void SwPlatformShutdown(void) {}
