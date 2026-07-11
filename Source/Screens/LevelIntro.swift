// LevelIntro.swift - Port of LevelIntro.c to Swift

// MARK: - Level intro save menu

private let cGetLevelSpecificMenuLayoutFlags: @convention(c) (UnsafePointer<MenuItem>?) -> Int32 = { mi in
    guard let mi = mi else { return Int32(kMILayoutFlagHidden | kMILayoutFlagDisabled) }
    let id = mi.pointee.id
    if (gEngine.game.levelNum == 1 && id == fourCC("lvl1")) || (gEngine.game.levelNum == 2 && id == fourCC("lvl2")) {
        return 0
    }
    return Int32(kMILayoutFlagHidden | kMILayoutFlagDisabled)
}

private let gSaveMenuTreePtr: UnsafeMutablePointer<MenuItem> = makeMenuTreeBuffer([
    miRoot(fourCC("lvin")),
    miPick(STR_SAVE_GAME, next: fourCC("save"), customHeight: 1),
    miPick(STR_CONTINUE_WITHOUT_SAVING, next: fourCC("EXIT"), id: fourCC("nosv"), customHeight: 1),

    miRoot(fourCC("save")),
    miLabel(STR_ENTERING_LEVEL_2, id: fourCC("lvl1"), getLayoutFlags: cGetLevelSpecificMenuLayoutFlags),
    miLabel(STR_ENTERING_LEVEL_3, id: fourCC("lvl2"), getLayoutFlags: cGetLevelSpecificMenuLayoutFlags),
    miFileSlot(STR_FILE, id: fourCC("sf#0"), fileSlot: 0, next: fourCC("EXIT")),
    miFileSlot(STR_FILE, id: fourCC("sf#1"), fileSlot: 1, next: fourCC("EXIT")),
    miFileSlot(STR_FILE, id: fourCC("sf#2"), fileSlot: 2, next: fourCC("EXIT")),
    miFileSlot(STR_FILE, id: fourCC("sf#3"), fileSlot: 3, next: fourCC("EXIT")),
    miFileSlot(STR_FILE, id: fourCC("sf#4"), fileSlot: 4, next: fourCC("EXIT")),
    miPick(STR_CONTINUE_WITHOUT_SAVING, next: fourCC("EXIT"), id: fourCC("nosv")),
    miSpacer(customHeight: 1.5),
    miRoot(),
])

func MakeLevelIntroSaveSprites() {
    var style = kDefaultMenuStyle
    style.darkenPaneOpacity = 0.6
    style.yOffset = 400
    style.standardScale *= 0.75
    style.rowHeight *= 0.75
    MakeMenu(gSaveMenuTreePtr, &style)
    _ = MakeMouseCursorObject()
}

private let kCreditLineDuration: Float = 3.5
private let kCreditLinePause: Float = 0.5
private let kCreditFirstDelay: Float = 1.0
private let kCreditFadeInTime: Float = 0.2
private let kCreditFadeOutTime: Float = 0.3

private let kCreditsText: [(role: String, name: String)] = [
    ("PROGRAMMING & DESIGN", "Brian Greenstone"),
    ("ART & DESIGN", "Scott Harper"),
    ("MUSIC", "Aleksander Dimitrijevic"),
    ("ANIMATION", "Peter Greenstone"),
    ("ILLUSTRATOR", "Rich Bonk"),
    ("COLORIST", "Ben Prenevost"),
    ("ADDITIONAL PROGRAMMING", "Iliyas Jorio"),
]


private let FULL_CHANNEL_VOLUME: UInt32 = 0x0100

// MARK: - Do level intro screen

func DoLevelIntroScreen(_ mode: UInt8) {
    var bail = false
    var timer: Float = 5.0

    // (SKIPFLUFF is hardcoded off in this build, so this early-return never fires.)

    gEngine.screens.introMode = mode

    // SETUP

    setupLevelIntroScreen()
    _ = MakeFadeEvent(UInt8(kFadeFlags_In), 1.5)

    // MAIN LOOP

    repeat {
        CalcFramesPerSecond()
        DoSDLMaintenance()

        MoveObjects()
        OGL_DrawScene(DrawObjects)

        switch Int(gEngine.screens.introMode) {
        case INTRO_MODE_SCREENSAVER, INTRO_MODE_CREDITS:
            if UserWantsOut() != 0 {
                bail = true
            }

        case INTRO_MODE_NOSAVE:
            timer -= gEngine.framesPerSecondFrac
            if timer < 0.0 || UserWantsOut() != 0 {
                bail = true
            }

        case INTRO_MODE_SAVEGAME:
            if gEngine.menu.outcome != 0 {
                bail = true
            }

        default:
            break
        }
    } while !bail

    // FADE OUT

    OGL_FadeOutScene(DrawObjects, MoveObjects)

    // DO SAVE

    switch gEngine.menu.outcome {
    case 0x7366_2330...0x7366_2339: // 'sf#0'...'sf#9'
        _ = SaveGame(gEngine.menu.outcome - 0x7366_2330)

    default: // 'dont'
        break
    }

    // CLEANUP

    freeLevelIntroScreen()
}

// MARK: - Setup level intro screen

private func setupLevelIntroScreen() {
    // BUILD THE WORMHOLE SCENE (view, art, wormhole, nano, star dome)
    // - shared with the macOS screen-saver port, see LevelIntroScene.swift

    SetupLevelIntroScene()

    // WORMHOLE SOUND (not for the passive screensaver/credits modes)

    if Int(gEngine.screens.introMode) != INTRO_MODE_SCREENSAVER && Int(gEngine.screens.introMode) != INTRO_MODE_CREDITS {
        PlayEffect_Parms(Int16(EFFECT_WORMHOLE), FULL_CHANNEL_VOLUME / 2, FULL_CHANNEL_VOLUME / 3, UInt(NORMAL_CHANNEL_RATE))
    }

    // DO MODE SPECIFICS

    switch Int(gEngine.screens.introMode) {
    case INTRO_MODE_SAVEGAME:
        MakeLevelIntroSaveSprites()

    case INTRO_MODE_SCREENSAVER:
        SetupLevelIntroScreensaverObjects()

    case INTRO_MODE_CREDITS:
        setupCreditsObjects()

    default:
        break
    }
}

// MARK: - Free level intro screen

private func freeLevelIntroScreen() {
    StopAllEffectChannels()
    MyFlushEvents()
    FreeLevelIntroScene()
}

// MARK: - Make credits objects

private func setupCreditsObjects() {
    // MAKE GRADIENT SO TEXT IS MORE READABLE

    var gradientDef = NewObjectDefinitionType()
    gradientDef.genre = UInt8(CUSTOM_GENRE)
    gradientDef.coord = OGLPoint3D(x: 0, y: 0, z: 0)
    gradientDef.slot = 150 // between wormhole and nano
    gradientDef.scale = 1
    gradientDef.drawCall = cDrawBottomGradient
    _ = MakeNewObject(&gradientDef)

    // MAKE TEXT

    var delay = kCreditFirstDelay

    for credit in kCreditsText {
        var textDef = NewObjectDefinitionType()
        textDef.group = UInt8(ATLAS_GROUP_FONT2)
        textDef.coord = OGLPoint3D(x: 640 / 2, y: 400, z: 0)
        textDef.slot = Int16(SPRITE_SLOT)
        textDef.scale = 0.4
        textDef.moveCall = cMoveCreditsLine

        let obj0 = TextMesh_New(credit.role, Int32(kTextMeshAlignCenter), &textDef)
        obj0.pointee.AnaglyphZ = 6.0
        obj0.pointee.ColorFilter = OGLColorRGBA(r: 1, g: 0.6, b: 0.2, a: 1)

        textDef.group = UInt8(ATLAS_GROUP_FONT1)
        textDef.coord.y += 32
        textDef.scale = 0.6
        let obj1 = TextMesh_New(credit.name, Int32(kTextMeshAlignCenter | kTextMeshSmallCaps), &textDef)
        obj1.pointee.AnaglyphZ = 6.0

        for obj in [obj0, obj1] {
            obj.pointee.ColorFilter.a = 0
            obj.pointee.Timer = -delay
        }

        delay += kCreditLineDuration + kCreditLinePause
    }

    // MAKE END LOGO

    var logoDef = NewObjectDefinitionType()
    logoDef.group = UInt8(SPRITE_GROUP_LEVELSPECIFIC)
    logoDef.type = UInt8(MAINMENU_SObjType_NanoLogo)
    logoDef.coord = OGLPoint3D(x: 640 / 2, y: 400 + 15, z: 0)
    logoDef.slot = Int16(SPRITE_SLOT)
    logoDef.scale = 250
    logoDef.moveCall = cMoveCreditsLine
    let logo = MakeSpriteObject(&logoDef, 1)!
    logo.pointee.AnaglyphZ = 6.0
    logo.pointee.Timer = -delay
    logo.pointee.Flag.0 = 1
    logo.pointee.ColorFilter.a = 0
}

// MARK: - Move credits line

private let cMoveCreditsLine: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    let theNode = theNodeOpt!
    theNode.pointee.Timer += gEngine.framesPerSecondFrac
    let t = theNode.pointee.Timer

    let liveForever = theNode.pointee.Flag.0 != 0

    if t <= 0.0 {
        SetObjectVisible(theNode, 0)
    } else if !liveForever && t >= kCreditLineDuration {
        DeleteObject(theNode)
        return
    } else {
        SetObjectVisible(theNode, 1)

        var a: Float
        if t < kCreditFadeInTime {
            a = t / kCreditFadeInTime
        } else if !liveForever && t > kCreditLineDuration - kCreditFadeOutTime {
            a = 1 - (t - kCreditLineDuration + kCreditFadeOutTime) / kCreditFadeOutTime
        } else {
            a = 1
        }

        theNode.pointee.ColorFilter.a = a
    }
}

// MARK: - Draw bottom gradient

private let cDrawBottomGradient: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { _ in
    OGL_PushState()
    SetInfobarSpriteState(0, 1)
    OGL_DisableTexture2D()
    OGL_EnableBlend()

    let y: Float = 200

    gEngine.renderer.beginImmediate(.quads)
    gEngine.renderer.setColor4f(0, 0, 0, 0)
    gEngine.renderer.vertex2f(gEngine.infobar.logicalRect.left, y)
    gEngine.renderer.vertex2f(gEngine.infobar.logicalRect.right, y)
    gEngine.renderer.setColor4f(0, 0, 0, 1)
    gEngine.renderer.vertex2f(gEngine.infobar.logicalRect.right, gEngine.infobar.logicalRect.bottom)
    gEngine.renderer.vertex2f(gEngine.infobar.logicalRect.left, gEngine.infobar.logicalRect.bottom)
    gEngine.renderer.endImmediate()

    OGL_PopState()
}
