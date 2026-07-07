/****************************/
/*      MISC ROUTINES       */
/* By Brian Greenstone      */
/* (c)2003 Pangea Software  */
/* (c)2022 Iliyas Jorio     */
/****************************/

// Everything else is now in Misc.swift. DoAlert/DoFatalAlert stay here
// because they take C variadic arguments, which Swift can't implement (same
// reasoning as LocalizeWithPlaceholder staying in Localization.c).

#include "game.h"

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
	SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, "Nanosaur 2", message, /*gSDLWindow*/NULL);

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
	SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, "Nanosaur 2", message, /*gSDLWindow*/NULL);

	Exit2D();
	CleanQuit();
}
