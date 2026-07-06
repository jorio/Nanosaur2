// pomme_shim.cpp - bridges Pomme's real file/resource-manager C++
// implementation (extern/Pomme/src/Files, Memory, Pomme.cpp) into the 3DS
// build. See docs/3DS_PORT_PLAN.md's "Milestone: a real, navigable main
// menu", step 4 (File I/O).
//
// Deliberately does NOT include <3ds.h> - romfsInit()/chdir() (which
// actually mount and select the RomFS root) live in romfs_shim.c instead,
// a separate translation unit, for the same reason hidScanInput/
// PGL_Init/etc. are split out: libctru's <3ds/types.h> defines `Handle` as
// `u32`, which collides with the Mac Toolbox's `Handle` (`Ptr*`) that
// Pomme.h/game.h bring in here. chdir() itself is plain POSIX (<unistd.h>),
// not a libctru header, so it's safe to call from here even though its
// *effect* (making relative paths resolve against the RomFS mount) only
// matters once romfs_shim.c's Romfs3DS_Mount() has already run.
//
// Compiled with -DPOMME_NO_GRAPHICS -DPOMME_NO_INPUT (see Pomme.cpp's
// Init()) so Pomme::Init() skips its own QuickDraw-emulation graphics and
// legacy Mac Toolbox input glue - unrelated to and unused alongside this
// engine's own rendering (picaGL) and input (PlatformBackend.swift)
// conformances. Sound IS initialized here: Pomme's SoundMixer calls real
// SDL3 audio APIs directly, which real SDL3's n3ds backend backs for real
// now - see the Makefile's POMME_DEFS comment.

#include "Pomme.h"
#include "PommeInit.h"
#include "PommeFiles.h"
#include <unistd.h>

extern "C" {
    FSSpec gDataSpec;
    void Pomme3DS_InitFileSystem(void);
}

void Pomme3DS_InitFileSystem(void)
{
    chdir("romfs:/");

    Pomme::Init();

    // Matches Boot.cpp's `gDataSpec = Pomme::Files::HostPathToFSSpec(dataPath / "System")`
    // - "System" is the same subfolder name the desktop build's Data
    // folder uses; the 3DS RomFS root plays the role of the desktop app
    // bundle's Data folder here (see romfs_shim.c / the eventual RomFS
    // packaging step for how that folder tree actually gets embedded).
    //
    // MUST be the fully-qualified "romfs:/System", not a bare "System":
    // HostVolume::ToFSSpec() strips the filename to get the parent dir,
    // and GetDirectoryID() only skips its fs::exists() stat call when the
    // parent matches an already-registered directory verbatim. A bare
    // "System" strips down to an empty path "", which never matches
    // directories[0] ("romfs:/") and falls through to fs::exists("") -
    // stat-ing an empty path through the emulated RomFS archive backend,
    // which is what hung boot indefinitely (desktop never hits this since
    // Boot.cpp always passes an absolute dataPath, never a bare relative
    // "System").
    gDataSpec = Pomme::Files::HostPathToFSSpec(fs::path("romfs:/System"));
}
