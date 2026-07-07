// MainMenuGlobals.c - C-linkage definitions for globals formerly in MainMenu.c
// that are still read by Settings.c (which reads gPlayNow directly).
// These will be removed once Settings.c is ported to Swift.

#include "game.h"

Boolean gPlayNow = false;
OGLPoint2D gCursorCoord;
