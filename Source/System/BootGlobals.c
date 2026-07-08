// BootGlobals.c
//
// Storage for the handful of globals that used to be defined directly in
// Boot.cpp. Moved here so this storage lives in the C core library instead
// of the executable target - under Swift Package Manager, Boot.cpp (the
// executable target, containing main()) needs to both call into the Swift
// library (GameMain) and share these globals with it, which would be a
// circular target dependency if the storage stayed in Boot.cpp itself.

#include "game.h"

SDL_Window* gSDLWindow = NULL;
SDL_Window* gSDLWindow2 = NULL;
Boolean gDualScreenMode = 0;
FSSpec gDataSpec;
int gCurrentAntialiasingLevel;
