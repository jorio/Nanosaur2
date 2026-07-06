//---------------------------------------------------------------------------------
//
//  Nanosaur 2 for Nintendo 3DS -- real entry point.
//
//  Mirrors Source/Boot.cpp's desktop entry point (Boot(argc, argv) then
//  GameMain(), wrapped in a try/catch for Pomme::QuitRequest - the
//  exception the game throws to unwind out of its own main loop on clean
//  exit) - but skips everything Boot.cpp does that's desktop-specific
//  (argv parsing, SDL_CreateWindow, --dual-screen handling). On 3DS:
//  mount RomFS, bootstrap Pomme's file layer (see pomme_shim.cpp/
//  romfs_shim.c), bring up the GPU (picaGL), then hand off to GameMain()
//  completely unmodified - no skip-intro/init-trimming logic, per an
//  explicit decision not to shortcut the boot sequence.
//
//  Only declares the handful of plain, scalar-typed entry points this
//  needs (Romfs3DS_Mount/Pomme3DS_InitFileSystem/PGL_Init/GameMain) rather
//  than including game_3ds.h or <3ds.h> wholesale - this file doesn't need
//  Pomme's or libctru's own types, just C-linkage function declarations,
//  so it sidesteps their Handle-typedef collision (documented in
//  ports/3DS/common/game_3ds.h) entirely rather than needing to avoid it.
//
//---------------------------------------------------------------------------------

#include <exception>
#include "PommeInit.h" // for Pomme::QuitRequest only
#include "fatal_shim.h" // ports/3DS/common - so an uncaught C++ exception is visible instead of silently exiting
#include "console_shim.h" // ports/3DS/common - mirrors SDL_Log output to the bottom screen live
#include <SDL3/SDL.h>

extern "C" {
    int Romfs3DS_Mount(void);
    void Pomme3DS_InitFileSystem(void);
    void GameMain(void); // Source/System/Main.swift, @c @implementation
    extern SDL_Window* gSDLWindow; // common/boot_shim.c
}

int main()
{
    Romfs3DS_Mount();
    Pomme3DS_InitFileSystem();

    // Real SDL_Window, even though picaGL (not SDL's own GL/renderer
    // backend) does the actual drawing - several engine call sites
    // (window-size queries, mouse cursor tracking, mouse warp/grab)
    // dereference gSDLWindow as a real SDL_Window every frame. SDL_Init
    // must run before SDL_CreateWindow (mirrors desktop's Boot.cpp).
    SDL_Init(SDL_INIT_VIDEO);
    gSDLWindow = SDL_CreateWindow("Nanosaur 2", 400, 240, 0);

    // Bottom-screen console mirroring every SDL_Log call, so the game's own
    // extensive existing SDL_Log usage (not just fatal errors) is visible
    // live during boot instead of guessing blind - the console log file
    // Azahar itself writes never picks up guest output.
    Console3DS_Init();

    // NOT calling PGL_Init() here: GameMain() -> ToolBoxInit() -> OGL_Boot()
    // -> OGL_CreateDrawContext() -> CTRUGraphicsBackend.createContext()
    // (PlatformBackend.swift) already calls PGL_Init() itself. Calling it
    // again here double-initializes picaGL/GSP state - the same bug
    // pattern as the gfxInitDefault() double-init above, just one layer
    // deeper.

    try
    {
        GameMain();
    }
    catch (Pomme::QuitRequest&)
    {
        // No-op, the game may throw this exception to shut us down cleanly
        // (matches Boot.cpp's own handling of this exact exception).
    }
    catch (std::exception& e)
    {
        // Last-resort catch, matching Boot.cpp's release-build behavior,
        // but show what actually happened instead of silently exiting -
        // an uncaught exception here used to just drop back to Azahar's
        // frontend with zero indication of what went wrong.
        Fatal3DS_Print(e.what());
    }

    return 0;
}
