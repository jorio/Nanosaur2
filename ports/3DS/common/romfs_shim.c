// romfs_shim.c - mounts the 3DS's RomFS. Kept separate from pomme_shim.cpp
// (which does the rest of file-system init) because this needs libctru's
// romfsInit(), and <3ds.h>'s Handle-typedef collision with Pomme means
// this translation unit can never see both - see game_3ds.h's comment on
// hidScanInput/hidKeysHeld for the full explanation of that collision.
#include "romfs_shim.h"

extern unsigned int romfsInit(void); // libctru; Result is just `typedef u32 Result`

int Romfs3DS_Mount(void)
{
    return (int)romfsInit();
}
