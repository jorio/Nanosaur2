//---------------------------------------------------------------------------------
//
//  Nanosaur 2 for Nintendo 3DS -- real entry point.
//
//  Mirrors Source/Boot.cpp's desktop entry point (Boot(argc, argv) then
//  GameMain()) but skips everything Boot.cpp does that's desktop-specific
//  (argv parsing, SDL_CreateWindow, --dual-screen handling). On 3DS: mount
//  RomFS, set up gDataSpec against it (see fs_init_shim.cpp), bring up the
//  GPU (picaGL), then hand off to GameMain() completely unmodified - no
//  skip-intro/init-trimming logic, per an explicit decision not to
//  shortcut the boot sequence.
//
//  Only declares the handful of plain, scalar-typed entry points this
//  needs (Romfs3DS_Mount/Fs3DS_InitFileSystem/PGL_Init/GameMain) rather
//  than including game_3ds.h or <3ds.h> wholesale - this file doesn't need
//  libctru's own types, just C-linkage function declarations, so it
//  sidesteps its Handle-typedef collision with libctru's <3ds/types.h>
//  (documented in ports/3DS/common/game_3ds.h) entirely rather than
//  needing to avoid it.
//
//---------------------------------------------------------------------------------

#include <exception>
#include "fatal_shim.h" // ports/3DS/common - so an uncaught C++ exception is visible instead of silently exiting
#include "console_shim.h" // ports/3DS/common - mirrors SDL_Log output to the bottom screen live
#include <SDL3/SDL.h>

extern "C" {
    int Romfs3DS_Mount(void);
    void Fs3DS_InitFileSystem(void); // fs_init_shim.cpp
    void GameMain(void); // Source/System/Main.swift, @c @implementation
    extern SDL_Window* gSDLWindow; // common/boot_shim.c

    // libctru's crt0 startup code (weak symbols - see common/boot_shim.c's
    // comment on __ctru_heap_size/__ctru_linear_heap_size for the full
    // explanation). Declared directly here (not via <3ds/env.h>) to avoid
    // pulling in libctru's Handle typedef, which collides with the Mac
    // Toolbox's own Handle (SwMacTypes.h - see game_3ds.h's comment on
    // this exact issue).
    extern unsigned int __ctru_heap_size;
    extern unsigned int __ctru_linear_heap_size;
}

// Callable from Swift's SwExitToShell() (Misc.swift) - see that function's
// header comment. Desktop's equivalent (Boot.cpp's SwPlatformShutdown)
// restores mouse acceleration and tears down its (possibly dual-screen)
// window(s) before SDL_Quit(); neither applies here (no mouse-acceleration
// concept on 3DS, no dual-screen window), so this is just SDL_Quit().
extern "C" void SwPlatformShutdown()
{
    SDL_Quit();
}

int main()
{
    Romfs3DS_Mount();
    Fs3DS_InitFileSystem();

    // Real SDL_Window, even though picaGL (not SDL's own GL/renderer
    // backend) does the actual drawing - several engine call sites
    // (window-size queries, mouse cursor tracking, mouse warp/grab)
    // dereference gSDLWindow as a real SDL_Window every frame. SDL_Init
    // must run before SDL_CreateWindow (mirrors desktop's Boot.cpp).
    //
    // SDL_INIT_GAMEPAD (which also brings up the joystick subsystem) is
    // required too: Input.swift's default bindings (InputDefaults.c) rely
    // entirely on .pad = {GB(SOUTH), ...}-style gamepad button checks via
    // SDL_GetGamepadButton, read through the n3ds joystick backend - the
    // 3DS build has no keyboard, so without this subsystem initialized,
    // SDL_GetGamepads() never finds a controller and NO button input
    // (A/B/X/Y/Start/D-pad) ever reaches the game at all.
    SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMEPAD);
    gSDLWindow = SDL_CreateWindow("Nanosaur 2", 400, 240, 0);

    // Bottom-screen console mirroring every SDL_Log call, so the game's own
    // extensive existing SDL_Log usage (not just fatal errors) is visible
    // live during boot instead of guessing blind - the console log file
    // Azahar itself writes never picks up guest output.
    Console3DS_Init();

    {
        char msg[128];
        SDL_snprintf(msg, sizeof(msg), "heap_size=%u (%u MiB) linear_heap_size=%u (%u MiB)",
            __ctru_heap_size, __ctru_heap_size / (1024 * 1024),
            __ctru_linear_heap_size, __ctru_linear_heap_size / (1024 * 1024));
        Debug3DS_Log(msg);
    }

    // NOT calling PGL_Init() here: GameMain() -> ToolBoxInit() -> OGL_Boot()
    // -> OGL_CreateDrawContext() -> gRenderBackend.createContext()
    // (GLRenderBackend's #if NANOSAUR_3DS branch, Source/3D/RenderBackend.swift)
    // already calls PGL_Init() itself. Calling it again here
    // double-initializes picaGL/GSP state - the same bug pattern as the
    // gfxInitDefault() double-init above, just one layer deeper.

    // GameMain() never returns normally on clean quit - CleanQuit() (Input.swift)
    // calls SwExitToShell() (Misc.swift), which tears down the platform layer
    // and calls exit(0) directly (see that function's header comment for why
    // this replaced the old Pomme::QuitRequest exception-unwind mechanism).
    // What's left for this try/catch to handle is genuinely unexpected
    // termination, matching Boot.cpp's own last-resort catch.
    try
    {
        GameMain();
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
