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

// Sets fov[0..numPlayers-1] on gGameViewInfoPtr to the given FOV value.
// The fov field is float[MAX_VIEWPORTS], imported as a tuple in Swift and
// not indexable by a variable, so this must live in C. The FOV value and
// player count are both computed in Swift (GetSplitscreenPaneFOV,
// gNumPlayers) and passed in - gNumPlayers moved to native Swift storage
// (Player.swift) and can't be read directly from this C-compiled header.
static inline void PausedInternal_UpdateSplitscreenFOV(float fov, int numPlayers) {
    for (int i = 0; i < numPlayers; i++)
        gGameViewInfoPtr->fov[i] = fov;
}

#pragma clang assume_nonnull end
