// picaGL_shim.c - see picaGL_shim.h.
#include "picaGL_shim.h"
#include <3ds.h>
#include <GL/picaGL.h>

void PGL_Init(void)
{
    pglInit();
}

void PGL_SelectTopScreen(void)
{
    pglSelectScreen(GFX_TOP, GFX_LEFT);
}

void PGL_SelectBottomScreen(void)
{
    pglSelectScreen(GFX_BOTTOM, GFX_LEFT);
}

void PGL_SwapBuffers(void)
{
    pglSwapBuffers();
}
