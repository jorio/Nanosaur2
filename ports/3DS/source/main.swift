//---------------------------------------------------------------------------------
//
//  Nanosaur 2 for Nintendo 3DS -- Embedded Swift ARM11 binary.
//
//  This is a MINIMAL BOOT smoke test, not the real game (see
//  docs/3DS_PORT_PLAN.md, Phase 2): it exists to prove the toolchain/link
//  pipeline works end to end - Embedded Swift compiling against citro2d/
//  citro3d, linking against libctru, and packaging into a .3dsx - before
//  any of the actual Nanosaur2 engine (Source/) is wired in. The real
//  engine's Swift files are pervasively SDL3/Pomme-typed (not cleanly
//  isolated behind a couple of files the way junkbot-swift's engine was),
//  so integrating them is a separate, much larger follow-up pass, not
//  something this file attempts.
//
//  Draws a solid color to both screens and reads the D-pad/buttons so the
//  citro2d render-target/frame pipeline and hidScanInput are both
//  exercised, then exits on START.
//
//---------------------------------------------------------------------------------

import CTRU

gfxInitDefault()
C3D_Init(Int(C3D_DEFAULT_CMDBUF_SIZE))
C2D_Init(Int(C2D_DEFAULT_MAX_OBJECTS))
C2D_Prepare()

let topTarget = C2D_CreateScreenTarget(GFX_TOP, GFX_LEFT)
let bottomTarget = C2D_CreateScreenTarget(GFX_BOTTOM, GFX_LEFT)

let topColor = C2D_Color32(0x20, 0x40, 0xA0, 0xFF) // dark blue
let bottomColor = C2D_Color32(0x20, 0xA0, 0x40, 0xFF) // dark green
let rectColor = C2D_Color32(0xFF, 0xFF, 0xFF, 0xFF) // white

while aptMainLoop() {
    hidScanInput()
    let keysDown = hidKeysDown()
    if keysDown & KEY_START != 0 {
        break
    }

    C3D_FrameBegin(UInt8(C3D_FRAME_SYNCDRAW))

    C2D_TargetClear(topTarget, topColor)
    C2D_SceneBegin(topTarget)
    C2D_DrawRectSolid(60, 40, 0, 280, 120, rectColor)

    C2D_TargetClear(bottomTarget, bottomColor)
    C2D_SceneBegin(bottomTarget)
    C2D_DrawRectSolid(60, 80, 0, 200, 80, rectColor)

    C3D_FrameEnd(0)
}

C2D_Fini()
C3D_Fini()
gfxExit()
