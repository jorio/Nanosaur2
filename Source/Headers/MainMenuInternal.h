#pragma once

#include "menu.h"

// The main menu tree (and the callbacks it embeds by designated
// initializer - CheckForLevelCheat/DeleteFileSlot) stays in MainMenu.c:
// four-char-code ids aren't practical to construct from Swift, and
// CheckForLevelCheat mutates the tree's `.next` field in place, so the
// tree can't be a `let` either. DoMainMenuScreen (in MainMenu.swift)
// references it by name.

MenuItem* GetMainMenuTree(void);
