// game_3ds.h - EXPERIMENTAL bridging header substitute for the 3DS target,
// proving out how much of the real engine's Swift/C code can import under
// Embedded Swift. See docs/3DS_PORT_PLAN.md, Phase 2.
//
// Unlike an earlier version of this file, this does NOT fork game.h's
// include chain by hand - Source/Headers/sprites.h (among others) lacks an
// include guard, so including it twice (once here, once transitively via
// the real game.h from *Internal.h below) caused enum-redefinition errors.
// Instead this just includes the REAL game.h directly, backed by a minimal
// SDL3 stub header (ports/3DS/common/SDL3/*, on the include path ahead of
// the real SDL3) so it parses without desktop SDL3.
//
// Swift files that call actual SDL_* functions still fail to resolve those
// symbols (expected - those files need PlatformBackend-style routing before
// they'll compile for 3DS; tracked separately in docs/3DS_PORT_PLAN.md).
#include "game.h"

// libctru's hid API, used by PlatformBackend.swift's CTRUInputBackend.
// Declared directly rather than `#include <3ds.h>`: libctru's
// <3ds/types.h> defines `Handle` as `u32`, which collides with the Mac
// Toolbox's `Handle` (`Ptr*`, i.e. `char**`) already declared via
// game.h/SwMacTypes.h above - "typedef redefinition with different types".
// Only the two functions actually called need to resolve here, so a full
// module/header reconciliation isn't worth doing until Phase 3 needs more
// of libctru than this.
extern void hidScanInput(void);
extern unsigned int hidKeysHeld(void);
extern unsigned int hidKeysDown(void);
extern void gfxInitDefault(void);
extern void gfxExit(void);
extern _Bool aptMainLoop(void);

// DebugLog (implemented in Swift, BottomLog3DS.swift - bottom-screen log
// view in the game font + SD-card file) and DebugLogFile3DS (the file
// sink, console_shim.c). DebugLog only exists under -DDEBUGLOG; every
// call site is gated behind the same flag, so flipping it off removes
// all checkpoint-logging code from the binary.
#include "console_shim.h" 
#define NANOSAUR_3DS_KEY_START 8 // BIT(3), from libctru's hid.h KEY_START - not included via <3ds.h> here (see above)

// citro3d renderer (replaced picaGL - see c3d_renderer.h's header comment),
// backing Source/3D/Citro3DBackend.swift. Scalar-typed API, safe alongside
// game.h for the same Handle-collision reasons as the other shim headers.
#include "c3d_renderer.h"

// RomFS mount (romfs_shim.c) + gDataSpec setup against it (fs_init_shim.cpp)
// - see those files' own comments for why they're two separate translation
// units. Call Romfs3DS_Mount() before Fs3DS_InitFileSystem() - the latter
// chdir()s into the RomFS root, which only exists once the former has
// mounted it.
#include "romfs_shim.h"
void Fs3DS_InitFileSystem(void); // fs_init_shim.cpp

// Swift-only helper declarations (SwFatal/SwGameAssert/GetPlayerInfoEntry/
// gNav/etc.) from the real Nanosaur2-Bridging-Header.h - not part of
// game.h itself. Mirrors that file's own include list exactly (several
// *Internal.h headers that used to be here - SplineManager/LoadLevel/
// Sparkle/PlayerRace/Sprites/Objects/Bones/Eggs/Player/Infobar/Pick - were
// deleted once their last C caller was ported to Swift; keep this list in
// sync with Nanosaur2-Bridging-Header.h rather than re-adding stale names).
#include "SwiftInternal.h"
#include "MenuInternal.h"
#include "PausedInternal.h"
#include "AnaglyphCalibrationInternal.h"
#include "EnemyInternal.h"
#include "UIEffectsInternal.h"
#include "WaterInternal.h"
#include "LevelIntroInternal.h"
#include "MainMenuInternal.h"
#include "SettingsInternal.h"
