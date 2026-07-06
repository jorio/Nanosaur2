// console_shim.c - see console_shim.h.
#include "console_shim.h"
#include <3ds.h>
#include <stdio.h>
#include <SDL3/SDL.h>

// "sdmc:/" is libctru's standard devoptab mount for the SD card (real or
// emulated) - registered automatically by libctru's startup code, no
// romfsInit()-style call needed. Opened in append mode and flushed after
// every line so the file is readable from the host (in Azahar's case,
// under its sdmc/ directory on the host filesystem) even if the app later
// crashes without a clean shutdown - the bottom-screen console alone only
// shows the last ~20 lines and requires a live screenshot to read.
static const char *kLogPath = "sdmc:/nanosaur2_log.txt";
static FILE *s_logFile = NULL;
static int s_logFileTried = 0;

static void Console3DS_WriteToSDCard(const char *message)
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

static void Console3DS_LogOutput(void *userdata, int category, SDL_LogPriority priority, const char *message)
{
    (void)userdata;
    (void)category;
    (void)priority;
    // libctru's console already scrolls the bottom screen for us as lines
    // are printed past the bottom - no manual line management needed.
    printf("%s\n", message);
    gfxFlushBuffers();
    gfxSwapBuffers();
    Console3DS_WriteToSDCard(message);
}

static int s_consoleReady = 0;

void Console3DS_Init(void)
{
    consoleInit(GFX_BOTTOM, NULL);
    SDL_SetLogOutputFunction(Console3DS_LogOutput, NULL);
    s_consoleReady = 1;
}

void Debug3DS_Log(const char *message)
{
    if (!s_consoleReady)
    {
        consoleInit(GFX_BOTTOM, NULL);
        s_consoleReady = 1;
    }
    printf("%s\n", message);
    gfxFlushBuffers();
    gfxSwapBuffers();
    Console3DS_WriteToSDCard(message);
}
