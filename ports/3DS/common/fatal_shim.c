// fatal_shim.c - see fatal_shim.h.
//
// Uses libctru's console (regular gfx framebuffer text output on the
// BOTTOM screen) rather than picaGL - the top screen is owned by picaGL's
// GPU command queue for real game rendering, and mixing that with the
// software console framebuffer swap on the same screen would fight over
// the same hardware. The bottom screen is otherwise unused by this port
// (no dual-screen mode active), so it's free for this.
#include "fatal_shim.h"
#include <3ds.h>
#include <stdio.h>

void Fatal3DS_Print(const char *message)
{
    // consoleInit() takes over the given screen's framebuffer for text
    // output - safe to call here even mid-game, since nothing else is
    // driving the bottom screen right now.
    consoleInit(GFX_BOTTOM, NULL);

    printf("\n\n  *** NANOSAUR 2 FATAL ERROR ***\n\n  %s\n\n  (Press START to exit)\n", message);
    gfxFlushBuffers();
    gfxSwapBuffers();

    // Also persist to the emulated/real SD card - unlike the bottom-screen
    // console, this survives even if nobody's watching the screen live.
    FILE *logFile = fopen("sdmc:/nanosaur2_log.txt", "a");
    if (logFile)
    {
        fprintf(logFile, "*** FATAL: %s ***\n", message);
        fclose(logFile);
    }

    // Never returns: keep servicing APT/HID so the app doesn't look fully
    // hung (Home button etc. still work), keeping the message on screen
    // until the user manually exits.
    while (aptMainLoop())
    {
        hidScanInput();
        if (hidKeysDown() & KEY_START)
        {
            break;
        }
        gspWaitForVBlank();
    }
}
