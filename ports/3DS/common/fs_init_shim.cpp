// fs_init_shim.cpp - sets up gDataSpec against the mounted RomFS, using the
// engine's own native Swift file-path resolver (Source/System/FileSystem.swift's
// SwHostPathToFSSpec, declared in Source/Headers/file.h) - the same one the
// desktop build's Boot.cpp uses for its own gDataSpec. Used to go through
// Pomme::Files::HostPathToFSSpec/Pomme::Init(), back when Source/**/*.swift's
// file/resource I/O was still Pomme-backed; now that the whole engine is
// natively Swift/SDL3 (see FileSystem.swift/File.swift's header comments -
// grep confirms nothing under Source/ references Pomme anymore), there's
// nothing left for Pomme to do here, so this is a plain chdir() + one
// function call instead of a whole vendored Mac-Toolbox emulation library.
//
// Kept as a separate translation unit from romfs_shim.c only because that
// one needs libctru's romfsMountSelf() from <3ds.h>, and this one needs
// game.h's FSSpec/SwHostPathToFSSpec declarations - no actual symbol clash
// between them anymore (that used to be Pomme.h's Handle vs. libctru's
// Handle - see game_3ds.h's hidScanInput/hidKeysHeld comment for the type
// this project's own SwMacTypes.h now avoids entirely), but there's no
// reason to merge them either.

extern "C" {
    #include "game.h"
    void Pomme3DS_InitFileSystem(void);

    // Not #include <unistd.h>: its read()/write() prototypes conflict with
    // file.h's own hand-declared ones (see file.h's header comment on why
    // it avoids <unistd.h> entirely - same reasoning as the project-wide
    // "no system headers from a bridging-header'd translation unit" rule).
    // Only chdir() is needed here, so it's hand-declared too.
    int chdir(const char* path);
}

void Pomme3DS_InitFileSystem(void)
{
    chdir("romfs:/");

    // Matches Boot.cpp's `gDataSpec = SwHostPathToFSSpec((dataPath / "System")...)`
    // - "System" is the same subfolder name the desktop build's Data
    // folder uses; the 3DS RomFS root plays the role of the desktop app
    // bundle's Data folder here (see romfs_shim.c / the RomFS packaging
    // step for how that folder tree actually gets embedded).
    //
    // MUST be the fully-qualified "romfs:/System", not a bare "System":
    // FileSystem.swift's resolver strips the filename to get the parent
    // dir and registers it verbatim - a bare "System" would register a
    // relative path instead of an absolute one, which nothing else in
    // this codebase's path resolution expects.
    gDataSpec = SwHostPathToFSSpec("romfs:/System");
}
