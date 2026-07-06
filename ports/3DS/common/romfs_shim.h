// romfs_shim.h - see romfs_shim.c.
#pragma once

// Returns 0 on success (a real libctru Result code otherwise) - mirrors
// romfsInit()'s own convention rather than inventing a new one.
int Romfs3DS_Mount(void);
