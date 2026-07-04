#pragma once

#include "menu.h"

// MakeLevelIntroSaveSprites' menu tree (and the getLayoutFlags callback it
// embeds by designated initializer) stays in LevelIntro.c: four-char-code
// ids aren't practical to construct from Swift. SetupLevelIntroScreen
// (in LevelIntro.swift) calls it by name.

void MakeLevelIntroSaveSprites(void);
