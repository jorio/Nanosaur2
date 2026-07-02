#pragma once

#include "menu.h"

// Menu tree data tables for the pause screen. These stay defined in
// Paused.c: their anonymous-union designated initializers (.cycler.choices,
// four-char-code ids, etc.) aren't practical to construct from Swift.
// DoPaused/DoReallyQuit (in Paused.swift) reference them by name.

extern const MenuItem gPauseMenuTree[];
extern const MenuItem gReallyQuitMenuTree[];

// Swift can't import an extern array of incomplete size directly; hand it
// out as a pointer instead (which is what MakeMenu wants anyway).
static inline const MenuItem* GetPauseMenuTree(void) { return gPauseMenuTree; }
static inline const MenuItem* GetReallyQuitMenuTree(void) { return gReallyQuitMenuTree; }
