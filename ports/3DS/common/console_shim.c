// console_shim.c - see console_shim.h.
//
// This file no longer uses libctru's console at all: under DEBUGLOG the
// bottom screen is a game-font log view rendered through SDL software
// blits (Source/System/BottomLog3DS.swift implements DebugLog itself);
// without DEBUGLOG the bottom screen belongs to dual-screen mode. Either
// way, this file's job is just the SD-card log file plus routing SDL_Log
// output into the right sink. (fatal_shim.c still consoleInits on a
// fatal error - a crash takes the bottom screen over regardless.)
#include "console_shim.h"
#include <stdio.h>
#include <SDL3/SDL.h>

// "sdmc:/" is libctru's standard devoptab mount for the SD card (real or
// emulated) - registered automatically by libctru's startup code, no
// romfsInit()-style call needed. Opened in append mode and flushed after
// every line so the file is readable from the host (in Azahar's case,
// under its sdmc/ directory on the host filesystem) even if the app later
// crashes without a clean shutdown - the on-screen log view alone only
// shows the last ~16 lines and requires a live screenshot to read.
static const char *kLogPath = "sdmc:/nanosaur2_log.txt";
static FILE *s_logFile = NULL;
static int s_logFileTried = 0;

void DebugLogFile3DS(const char *message)
{
    if (!s_logFileTried)
    {
        s_logFileTried = 1;
        s_logFile = fopen(kLogPath, "a");
    }
    if (s_logFile)
    {
        fprintf(s_logFile, "%s\n", message);
        fflush(s_logFile);
    }
}

#ifdef DEBUGLOG
// Route every SDL_Log line through DebugLog (BottomLog3DS.swift), which
// writes the file AND redraws the bottom-screen log view.
static void Console3DS_LogOutput(void *userdata, int category, SDL_LogPriority priority, const char *message)
{
    (void)userdata;
    (void)category;
    (void)priority;
    DebugLog(message);
}
#else
// Without DEBUGLOG the bottom screen belongs to the game (dual-screen
// mode - see main.cpp), so the SDL_Log mirror only writes the file;
// alerts/errors still land in the SD-card log.
static void Console3DS_LogOutput(void *userdata, int category, SDL_LogPriority priority, const char *message)
{
    (void)userdata;
    (void)category;
    (void)priority;
    DebugLogFile3DS(message);
}
#endif

void Console3DS_Init(void)
{
    SDL_SetLogOutputFunction(Console3DS_LogOutput, NULL);
}
