#pragma once

#include "menu.h"
#include "game.h"

#pragma clang assume_nonnull begin

// Returns a stable pointer to gGamePrefs.splitScreenMode for use as a
// MenuCyclerData valuePtr. Swift can't form a stable address to a C-global
// struct field without going through a C helper.
static inline Byte* PausedInternal_GetSplitScreenModePtr(void) {
    return (Byte*)&gGamePrefs.splitScreenMode;
}

// Sets fov[0..numPlayers-1] on the given view info struct to the given FOV
// value. The fov field is float[MAX_VIEWPORTS], imported as a tuple in
// Swift and not indexable by a variable, so this must live in C. The FOV
// value, player count, and view info pointer are all computed/held in
// Swift (GetSplitscreenPaneFOV, gNumPlayers, gGameViewInfoPtr) and passed
// in - none of these globals are C-visible anymore, so this shim can't
// reach them by name.
static inline void PausedInternal_UpdateSplitscreenFOV(OGLSetupOutputType* viewInfo, float fov, int numPlayers) {
    for (int i = 0; i < numPlayers; i++)
        viewInfo->fov[i] = fov;
}

#pragma clang assume_nonnull end
