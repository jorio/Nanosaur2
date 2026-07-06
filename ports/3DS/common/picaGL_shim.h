// picaGL_shim.h - plain, scalar-typed wrapper around picaGL's pglInit/
// pglSelectScreen/pglSwapBuffers/pglExit, for PlatformBackend.swift's
// CTRUGraphicsBackend. Declared without any <3ds.h>/<GL/picaGL.h> types in
// sight (just no-argument functions) so this header is safe to include
// from game_3ds.h alongside Pomme/game.h - the real picaGL calls (which do
// need <3ds.h>, GFX_TOP/GFX_BOTTOM/GFX_LEFT etc.) live in
// picaGL_shim.c, a separate translation unit, same pattern as
// hidScanInput/hidKeysHeld's direct declarations in game_3ds.h.
#pragma once

void PGL_Init(void);
void PGL_SelectTopScreen(void);
void PGL_SelectBottomScreen(void);
void PGL_SwapBuffers(void);
