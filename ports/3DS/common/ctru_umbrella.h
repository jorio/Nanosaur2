// ctru_umbrella.h - exposes libctru + citro2d/citro3d to Swift as `import CTRU`.
//
// This is intentionally just the vendor headers for now (see module.modulemap) -
// no shim.h yet, since the current source/ tree is a minimal toolchain/link
// smoke test (Phase 2 of docs/3DS_PORT_PLAN.md: prove the Embedded Swift +
// libctru + citro2d/citro3d + 3dsxtool pipeline works end to end), not yet
// the real Nanosaur2 engine.
#include <3ds.h>
#include <citro2d.h>
#include <citro3d.h>
