/****************************/
/*      MISC ROUTINES       */
/* By Brian Greenstone      */
/* (c)2003 Pangea Software  */
/* (c)2022 Iliyas Jorio     */
/****************************/

// Everything else is now in Misc.swift. DoAlert/DoFatalAlert stay here
// because they take C variadic arguments, which Swift can't implement (same
// reasoning as LocalizeWithPlaceholder staying in Localization.c). The
// globals below also stay here so other still-unported C files can keep
// reading/writing them via `extern`.

#include "game.h"

#ifdef __3DS__
#include "fatal_shim.h" // ports/3DS/common - real SDL_ShowSimpleMessageBox equivalent doesn't exist on 3DS's software-only SDL backend
#endif

long	gRAMAlloced = 0;

float	gFramesPerSecond = 13;
float	gFramesPerSecondFrac = 1.0f / 13;

int		gNumPointers = 0;


/*********************** DO ALERT *******************/

void DoAlert(const char* format, ...)
{
	Enter2D();

	char message[1024];
	va_list args;
	va_start(args, format);
	SDL_vsnprintf(message, sizeof(message), format, args);
	va_end(args);

	SDL_Log("Nanosaur 2 Alert: %s\n", message);
#ifdef __3DS__
	// Non-fatal: just log, don't take over the screen (matches this
	// function returning normally to its caller). SDL_ShowSimpleMessageBox
	// doesn't exist on 3DS's software-only SDL backend.
#else
	SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, "Nanosaur 2", message, /*gSDLWindow*/NULL);
#endif

	Exit2D();
}


/*********************** DO FATAL ALERT *******************/

void DoFatalAlert(const char* format, ...)
{
	Enter2D();

	char message[1024];
	va_list args;
	va_start(args, format);
	SDL_vsnprintf(message, sizeof(message), format, args);
	va_end(args);

	SDL_Log("Nanosaur 2 Fatal Alert: %s\n", message);
#ifdef __3DS__
	// Real message box doesn't exist on 3DS - print to the bottom screen
	// via libctru's console instead and never return, rather than hanging
	// invisibly trying (and failing) to show a system dialog.
	Fatal3DS_Print(message);
#else
	SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, "Nanosaur 2", message, /*gSDLWindow*/NULL);
#endif

	Exit2D();
	CleanQuit();
}
