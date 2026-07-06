//---------------------------------------------------------------------------------
//
//  Nanosaur 2 for Nintendo 3DS -- Embedded Swift ARM11 binary.
//
//  This is a MINIMAL BOOT smoke test, not the real game (see
//  docs/3DS_PORT_PLAN.md, Phase 2/3): it exists to prove the toolchain/link
//  pipeline works end to end - Embedded Swift compiling against picaGL
//  (ports/3DS/vendor/picaGL, a real OpenGL 1.x-style implementation for the
//  PICA200 GPU), linking against libctru, and packaging into a .3dsx -
//  before any of the actual Nanosaur2 engine (Source/) is wired in.
//
//  Previously used citro2d/citro3d directly (import CTRU); switched to
//  picaGL because the real engine's Swift/C code only ever calls standard
//  gl* functions (glBegin/glVertex/glTexEnvi/etc.), never citro2d's own
//  API - and picaGL/citro3d can't coexist in the same app anyway (both
//  directly own the same GPU command queue). See PlatformBackend.swift's
//  CTRUGraphicsBackend for the same picaGL wiring the real engine uses.
//
//  Draws a solid-colored rectangle to both screens via real GL immediate-
//  mode calls, and reads the D-pad/buttons via hidScanInput, then exits on
//  START.
//
//---------------------------------------------------------------------------------

PGL_Init()

while aptMainLoop() {
    hidScanInput()
    if hidKeysDown() & UInt32(NANOSAUR_3DS_KEY_START) != 0 {
        break
    }

    PGL_SelectTopScreen()
    glClearColor(0.125, 0.25, 0.625, 1.0) // dark blue
    glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
    drawTestRect()
    PGL_SwapBuffers()

    PGL_SelectBottomScreen()
    glClearColor(0.125, 0.625, 0.25, 1.0) // dark green
    glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
    drawTestRect()
    PGL_SwapBuffers()
}

private func drawTestRect() {
    glMatrixMode(GLenum(GL_PROJECTION))
    glLoadIdentity()
    glOrtho(0, 400, 240, 0, -1, 1)
    glMatrixMode(GLenum(GL_MODELVIEW))
    glLoadIdentity()

    glColor4f(1, 1, 1, 1)
    glBegin(GLenum(GL_QUADS))
    glVertex2f(60, 40)
    glVertex2f(340, 40)
    glVertex2f(340, 200)
    glVertex2f(60, 200)
    glEnd()
}
