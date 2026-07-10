// MiscScreens.swift - Port of MiscScreens.c to Swift
//
// gLoadingThermoPercent is native Swift storage now (converted
// 2026-07-07): nothing in any .c file touches it anymore.

var gLoadingThermoPercent: Float = 0

private let THERMO_WIDTH: Float = 80.0
private let THERMO_HEIGHT: Float = 4.0
private let THERMO_Y: Float = 180.0
private let THERMO_LEFT: Float = 320 - (THERMO_WIDTH / 2)
private let THERMO_RIGHT: Float = 320 + (THERMO_WIDTH / 2)

// Mirrors the C function-local statics in DrawLoading, which persist
// across calls.
private var gShownYet = false
private var gStartTicks: UInt64 = 0
private var gLastUpdateTicks: UInt64 = 0

private let cDrawLoadingCallback: @convention(c) () -> Void = {
    if gCurrentSplitScreenPane != 0 { // only show in player 1's pane
        return
    }

    SetInfobarSpriteState(0, 1)

    DrawInfobarSprite_Centered(640 / 2, THERMO_Y - 6, 100, Int16(INFOBAR_SObjType_Loading))

    // DRAW THERMO FRAME

    OGL_SetColor4f(0.5, 0.5, 0.5, 1)
    OGL_DisableTexture2D()

    gEngine.renderer.beginImmediate(.quads)
    gEngine.renderer.vertex2f(THERMO_LEFT, THERMO_Y); gEngine.renderer.vertex2f(THERMO_RIGHT, THERMO_Y)
    gEngine.renderer.vertex2f(THERMO_RIGHT, THERMO_Y + THERMO_HEIGHT); gEngine.renderer.vertex2f(THERMO_LEFT, THERMO_Y + THERMO_HEIGHT)
    gEngine.renderer.endImmediate()

    // DRAW THERMO METER

    let w = gLoadingThermoPercent * THERMO_WIDTH
    let x = THERMO_LEFT + w

    let stereoMode = gGamePrefs.stereoGlassesMode
    if stereoMode == UInt8(StereoGlassesMode.anaglyphColor.rawValue) || stereoMode == UInt8(StereoGlassesMode.anaglyphMono.rawValue) {
        OGL_SetColor4f(0.3, 0.3, 0.2, 1)
    } else {
        OGL_SetColor4f(0.8, 0, 0, 1)
    }

    gEngine.renderer.beginImmediate(.quads)
    gEngine.renderer.vertex2f(THERMO_LEFT, THERMO_Y); gEngine.renderer.vertex2f(x, THERMO_Y)
    gEngine.renderer.vertex2f(x, THERMO_Y + THERMO_HEIGHT); gEngine.renderer.vertex2f(THERMO_LEFT, THERMO_Y + THERMO_HEIGHT)
    gEngine.renderer.endImmediate()

    OGL_SetColor4f(1, 1, 1, 1)

    var fadeOpacity: Float = 0
    if gLoadingThermoPercent < 0.1 {
        fadeOpacity = 1.0 - (gLoadingThermoPercent / 0.1)
    } else {
        let fadeoutStart: Float = 0.9
        let fadeoutEnd: Float = 1.0
        if gLoadingThermoPercent > fadeoutStart {
            fadeOpacity = (gLoadingThermoPercent - fadeoutStart) / (fadeoutEnd - fadeoutStart)
        }
    }

    do {
        OGL_SetColor4f(0, 0, 0, fadeOpacity > 1 ? 1 : fadeOpacity)
        gEngine.renderer.beginImmediate(.quads)
        gEngine.renderer.vertex2f(0, 0); gEngine.renderer.vertex2f(640, 0)
        gEngine.renderer.vertex2f(640, 480); gEngine.renderer.vertex2f(0, 480)
        gEngine.renderer.endImmediate()
    }
}

func DoWarmUpScreen() {
    var viewDef = OGLSetupInputType()

    // SETUP VIEW

    OGL_NewViewDef(&viewDef)
    OGL_SetupGameView(&viewDef)

    // SHOW IT

    for _ in 0..<8 {
        OGL_DrawScene(DrawObjects)
        DoSDLMaintenance()
    }

    // CLEANUP

    DeleteAllObjects()

    OGL_DisposeGameView()
}

func DoLegalScreen() {
    var viewDef = OGLSetupInputType()
    var timeout: Float = 10.0

    gEngine.player.numPlayers = 1 // make sure don't do split-screen

    // SETUP VIEW

    OGL_NewViewDef(&viewDef)

    viewDef.camera.hither = 10
    viewDef.camera.yon = 3000
    viewDef.view.clearColor = OGLColorRGBA(r: 0, g: 0, b: 0, a: 1)
    viewDef.styles.useFog = 0

    OGL_SetupGameView(&viewDef)

    // BUILD OBJECTS

    LoadSpriteAtlas(Int32(ATLAS_GROUP_FONT3), ":Sprites:fonts:swiss", Int32(kAtlasLoadFont))

    var textDef = NewObjectDefinitionType()
    textDef.scale = 0.19
    textDef.group = UInt8(ATLAS_GROUP_FONT3)
    textDef.coord = OGLPoint3D(x: 320, y: 240 - 120, z: 0)

    let legalStrings: [String] = [
        "Nanosaur II:  Hatchling",
        "\u{0B}" + GAME_VERSION + "\r",
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        "pangeasoft.net",
        "jorio.itch.io/nanosaur2",
        "\u{0B}\u{00A9} 2004-2008 Pangea Software, Inc.  Nanosaur is a registered trademark of Pangea Software, Inc.\r",
    ]

    for s in legalStrings {
        if !s.isEmpty {
            let textNode = TextMesh_New(s, 0, &textDef)
            textNode.pointee.ColorFilter = OGLColorRGBA(r: 1, g: 1, b: 0, a: 1)
        }

        textDef.coord.y += 20
    }

    _ = MakeFadeEvent(UInt8(kFadeFlags_In), 2.0)

    DoSDLMaintenance()
    CalcFramesPerSecond()

    // MAIN LOOP

    while true {
        CalcFramesPerSecond()
        MoveObjects()
        OGL_DrawScene(DrawObjects)

        DoSDLMaintenance()
        if UserWantsOut() != 0 || SwIsClickDown(Int(SDL_BUTTON_LEFT)) {
            break
        }

        timeout -= gEngine.framesPerSecondFrac
        if timeout < 0.0 {
            break
        }
    }

    // FADE OUT

    OGL_FadeOutScene(DrawObjects, nil)

    // CLEANUP

    DeleteAllObjects()
    OGL_DisposeGameView()
}

func DrawLoading(_ percent: Float) {
    // Prevent the OS from thinking our process has locked up
    DoSDLMaintenance()

    let nowTicks = SDL_GetTicks()

    if percent == 0 {
        gStartTicks = nowTicks
        gLastUpdateTicks = 0
        gShownYet = false
    }

    // Give illusion of instant loading (don't draw thermometer) if we can predict the level will be loaded in under a second
    if !gShownYet {
        let ticksSinceStart = nowTicks - gStartTicks
        if ticksSinceStart < 200 // let loading warm up for 200 ms before considering whether to draw or not
            || ticksSinceStart <= UInt64(percent * 1000) { // don't draw as long as we're keeping up with the ideal loading time (1000 ms)
            return
        }
    }

    // Don't redraw too often or if percentage is out of bounds
    if percent > 0
        && percent < 1
        && nowTicks - gLastUpdateTicks < 16 {
        return
    }

    gShownYet = true
    gLastUpdateTicks = nowTicks

    // if percent > 0.75 {
    //     MakeFadeEvent(kFadeFlags_Out, 0.0001);
    //     gEngine.window.gammaFadeFrac = 1.0 - (percent - 0.75) / 0.25;
    // }

    // Kill vsync so we don't waste 16ms before loading the next asset
    let vsyncBackup = gEngine.renderer.getVSync()
    gEngine.renderer.setVSync(0)

    // Draw thermometer
    gEngine.renderer.clearColorAndDepth()
    OGL_DrawScene(cDrawLoadingCallback)
    gLoadingThermoPercent = percent

    // Restore vsync setting
    gEngine.renderer.setVSync(vsyncBackup)
}
