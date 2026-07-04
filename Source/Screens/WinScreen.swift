// WinScreen.swift - Port of WinScreen.c to Swift

private let WIN_SObjType_Win: Int16 = 0

private let NUM_SLIDES = 1
private let SLIDE_FADE_RATE: Float = 0.8

private var gEndSlideShow = false
private var gSlideActive: InlineArray<1, Bool> = InlineArray(repeating: false) // must match NUM_SLIDES

private let gSlides: [SlideType] = [
    // WIN PAGE
    SlideType(
        spriteNum: WIN_SObjType_Win, // sprite #
        x: 0.9, y: 0.5, // x / y
        scale: 1200, // scale
        rotz: -0.1, // rotz
        alpha: 0, // alpha
        delayToNext: 16.0, // delay to next
        delayToVanish: 16.0, // delay to fade
        zoomSpeed: -23.0, // zoom speed
        dx: -23, dy: 0, // dx / dy
        drot: 0.01, // drot
        delayUntilEffect: 0.5, // delay to play effect
        narrationSound: Int32(EFFECT_NULL),
        subtitleKey: 0
    ),
]

private let cMoveSlide: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNode in
    guard let theNode else { return }
    let fps = gFramesPerSecondFrac
    let slideNum = Int(theNode.pointee.Kind)
    let isLastSlide = slideNum >= NUM_SLIDES - 1

    if !gSlideActive[slideNum] { // is this slide still waiting?
        return
    }

    theNode.pointee.StatusBits &= ~UInt32(STATUS_BIT_HIDDEN)

    // MOVE IT

    theNode.pointee.Coord.x += fps * theNode.pointee.Delta.x
    theNode.pointee.Coord.y += fps * theNode.pointee.Delta.y

    theNode.pointee.Scale.y += fps * theNode.pointee.SpecialF.0 // ZoomSpeed
    theNode.pointee.Scale.x = theNode.pointee.Scale.y
    theNode.pointee.Rot.y += fps * theNode.pointee.DeltaRot.z

    // SEE IF TIME TO TRIGGER NEXT SLIDE

    theNode.pointee.Timer -= fps
    if !isLastSlide && theNode.pointee.Timer <= 0.0 {
        gSlideActive[slideNum + 1] = true
    }

    // SEE IF FADE OUT/IN

    theNode.pointee.Health -= fps
    if theNode.pointee.Health < 0.0 {
        theNode.pointee.ColorFilter.a -= fps * SLIDE_FADE_RATE
        if theNode.pointee.ColorFilter.a <= 0.0 {
            theNode.pointee.ColorFilter.a = 0
            if theNode.pointee.Timer <= 0.0 { // dont delete until the other timer is also done
                DeleteObject(theNode)
                if isLastSlide { // was that the last slide?
                    gEndSlideShow = true
                }
                return
            }
        }
    } else { // FADE IN
        theNode.pointee.ColorFilter.a += fps * SLIDE_FADE_RATE
        if theNode.pointee.ColorFilter.a > 1.0 {
            theNode.pointee.ColorFilter.a = 1.0
        }
    }
}

private func BuildSlideShowObjects() {
    for i in 0..<NUM_SLIDES {
        var def = NewObjectDefinitionType()
        def.group = UInt8(SPRITE_GROUP_LEVELSPECIFIC)
        def.type = UInt8(gSlides[i].spriteNum)
        def.coord.x = 640.0 * gSlides[i].x
        def.coord.y = 480.0 * gSlides[i].y
        def.coord.z = 0
        def.flags = UInt32(STATUS_BIT_NOTEXTUREWRAP | STATUS_BIT_DOUBLESIDED | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOZBUFFER)
        def.slot = Int16(SPRITE_SLOT) - Int16(i)
        def.moveCall = cMoveSlide
        def.rot = gSlides[i].rotz
        def.scale = gSlides[i].scale

        let slideObj = MakeSpriteObject(&def, 1)!

        slideObj.pointee.Kind = Int32(i)

        slideObj.pointee.StatusBits |= UInt32(STATUS_BIT_HIDDEN) // hide all slides @ start

        slideObj.pointee.ColorFilter.a = gSlides[i].alpha

        gSlideActive[i] = i == 0 // (this sets which frame we start on)

        slideObj.pointee.Timer = gSlides[i].delayToNext // set time to show before starting next slide
        slideObj.pointee.Health = gSlides[i].delayToVanish // time to show before start fadeout of this slide

        slideObj.pointee.SpecialF.0 = gSlides[i].zoomSpeed // ZoomSpeed
        slideObj.pointee.Delta.x = gSlides[i].dx
        slideObj.pointee.Delta.y = gSlides[i].dy
        slideObj.pointee.DeltaRot.z = gSlides[i].drot
        slideObj.pointee.SpecialF.1 = gSlides[i].delayUntilEffect // EffectTimer

        slideObj.pointee.AnaglyphZ = -10 // make appear deep in the monitor
    }
}

private func SetupWinScreen() {
    var viewDef = OGLSetupInputType()

    // SETUP VIEW

    OGL_NewViewDef(&viewDef)

    viewDef.camera.fov = 0.8

    viewDef.camera.hither = 10
    viewDef.camera.yon = 1000

    viewDef.styles.useFog = 0
    viewDef.view.clearColor.r = 0
    viewDef.view.clearColor.g = 0
    viewDef.view.clearColor.b = 0

    viewDef.view.clearBackBuffer = 1

    OGL_SetupGameView(&viewDef)

    // LOAD ART

    // LOAD SPRITES

    LoadSpriteGroupFromFile(Int32(SPRITE_GROUP_LEVELSPECIFIC), ":Sprites:story:win", 0)

    // MAKE OBJECTS

    BuildSlideShowObjects()
}

private func FreeWinScreen() {
    MyFlushEvents()
    DeleteAllObjects()
    FreeAllSkeletonFiles(-1)
    DisposeSpriteGroup(Int32(SPRITE_GROUP_LEVELSPECIFIC))
    DisposeAllBG3DContainers()
    DisposeTerrain()

    OGL_DisposeGameView()
}

func DoWinScreen() {
    // SETUP

    SetupWinScreen()
    _ = MakeFadeEvent(UInt8(kFadeFlags_In), 2.0)

    PlaySong(Int16(SONG_WIN), 0)

    // LOOP

    gEndSlideShow = false

    while !gEndSlideShow {
        CalcFramesPerSecond()
        DoSDLMaintenance()

        // MOVE
        MoveObjects()

        // DRAW
        OGL_DrawScene(DrawObjects)
    }

    OGL_FadeOutScene(DrawObjects, nil)

    // CLEANUP

    FreeWinScreen()
}
