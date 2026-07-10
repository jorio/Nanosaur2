// romfs_shim.c - mounts the 3DS's RomFS. Kept separate from fs_init_shim.cpp
// (which does the rest of file-system init) because this needs libctru's
// romfsMountSelf(), and <3ds.h>'s Handle-typedef collision with the Mac
// Toolbox's own Handle (SwMacTypes.h, pulled in via fs_init_shim.cpp's
// game.h include) means this translation unit can never see both - see
// game_3ds.h's comment on hidScanInput/hidKeysHeld for the full explanation
// of that collision.
#include "romfs_shim.h"

// libctru; Result is just `typedef u32 Result`. Mounts the RomFS embedded
// in this app's own .3dsx (built in via 3dsxtool's --romfs argument) under
// the "romfs" mount name, so it's reachable at "romfs:/" - matching
// fs_init_shim.cpp's chdir("romfs:/"). (Not romfsInit() - that name doesn't
// exist in current libctru; an earlier version of this file guessed wrong
// and was never actually exercised until now.)
extern unsigned int romfsMountSelf(const char *name);

int Romfs3DS_Mount(void)
{
    return (int)romfsMountSelf("romfs");
}
