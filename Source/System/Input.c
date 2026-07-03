// SDL INPUT
// (C) 2022 Iliyas Jorio
// This file is part of Nanosaur 2. https://github.com/jorio/Nanosaur2

// All function implementations are now in Input.swift. gUserPrefersGamepad
// stays here because LevelIntro.c and MainMenu.c (still unported) read/write
// it directly via `extern`.

#include "game.h"

Boolean				gUserPrefersGamepad = false;
