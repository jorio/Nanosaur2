//
// main.h
//

#pragma once

// LevelNum is now a native Swift enum in GameEnums.swift - nothing in any
// .c file touches it (verified 2026-07-07: LoadLevel.c, the only real C
// user of NUM_LEVELS/LEVEL_NUM_*, was ported to Swift and deleted).


// Biome is now a native Swift enum in GameEnums.swift - nothing in any .c
// file touches it (verified 2026-07-07: not a struct field in any header,
// and LoadLevel.c, the only real C user, was ported to Swift and deleted).

// VSMode is now a native Swift enum in GameEnums.swift - gVSMode moved
// from Main.c to Main.swift (verified 2026-07-07: no other .c file reads
// gVSMode via extern).




//=================================================




void GameMain(void);
