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

// Sets fov[0..gNumPlayers-1] on gGameViewInfoPtr to the given FOV value.
// The fov field is float[MAX_VIEWPORTS], imported as a tuple in Swift and
// not indexable by a variable, so this must live in C. The FOV value itself
// is computed in Swift (GetSplitscreenPaneFOV) and passed in.
static inline void PausedInternal_UpdateSplitscreenFOV(float fov) {
    for (int i = 0; i < gNumPlayers; i++)
        gGameViewInfoPtr->fov[i] = fov;
}

#pragma clang assume_nonnull end
