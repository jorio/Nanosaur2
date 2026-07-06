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
