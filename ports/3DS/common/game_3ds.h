// game_3ds.h - EXPERIMENTAL bridging header substitute for the 3DS target,
// proving out how much of the real engine's Swift/C code can import under
// Embedded Swift. See docs/3DS_PORT_PLAN.md, Phase 2.
//
// Unlike an earlier version of this file, this does NOT fork game.h's
// include chain by hand - Source/Headers/sprites.h (among others) lacks an
// include guard, so including it twice (once here, once transitively via
// the real game.h from *Internal.h below) caused enum-redefinition errors.
// Instead this just includes the REAL game.h directly, backed by minimal
// SDL3/Pomme stub headers (ports/3DS/common/SDL3/*, on the include path
// ahead of the real SDL3) so it parses without desktop SDL3/full C++ Pomme.
//
// Swift files that call actual SDL_* functions still fail to resolve those
// symbols (expected - those files need PlatformBackend-style routing before
// they'll compile for 3DS; tracked separately in docs/3DS_PORT_PLAN.md).
#include "game.h"

// libctru's hid API, used by PlatformBackend.swift's CTRUInputBackend.
// Declared directly rather than `#include <3ds.h>`: libctru's
// <3ds/types.h> defines `Handle` as `u32`, which collides with the Mac
// Toolbox's `Handle` (`Ptr*`, i.e. `char**`) already declared via
// game.h/Pomme.h above - "typedef redefinition with different types".
// Only the two functions actually called need to resolve here, so a full
// module/header reconciliation isn't worth doing until Phase 3 needs more
// of libctru than this.
extern void hidScanInput(void);
extern unsigned int hidKeysHeld(void);

// Swift-only helper declarations (SwFatal/SwGameAssert/GetPlayerInfoEntry/
// gNav/etc.) from the real Nanosaur2-Bridging-Header.h - not part of
// game.h itself.
#include "SwiftInternal.h"
#include "MenuInternal.h"
#include "PausedInternal.h"
#include "SplineManagerInternal.h"
#include "LoadLevelInternal.h"
#include "SparkleInternal.h"
#include "AnaglyphCalibrationInternal.h"
#include "PlayerRaceInternal.h"
#include "SpritesInternal.h"
#include "ObjectsInternal.h"
#include "EnemyInternal.h"
#include "BonesInternal.h"
#include "EggsInternal.h"
#include "UIEffectsInternal.h"
#include "WaterInternal.h"
#include "PlayerInternal.h"
#include "InfobarInternal.h"
#include "PickInternal.h"
#include "LevelIntroInternal.h"
#include "MainMenuInternal.h"
