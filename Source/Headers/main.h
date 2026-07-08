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

// Phase 0 Metal spike (Source/3D/MetalSpike.swift) - see
// docs/metal-renderer-plan.md. Exercised by `--metal` in Boot.cpp.
bool SwMetalSpike_Init(void);
void SwMetalSpike_ClearFrame(float red, float green, float blue);
void SwMetalSpike_Shutdown(void);

// Phase 2 real Metal backend activation (Source/3D/MetalActivation.swift).
// Called from main() after Boot() when --metal is passed.
bool SwMetalBackend_Activate(void);
