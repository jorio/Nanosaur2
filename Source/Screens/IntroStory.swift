// IntroStory.swift - Port of IntroStory.c to Swift
//
// SDL_snprintf/SDL_strchr are unusable from Swift (SDL_snprintf is
// variadic); MakeSubtitleObjects' cursor-walking C string logic is
// reimplemented using Swift string splitting instead.

private let INTROSTORY_SObjType_PangeaLogo: Int16 = 0
private let INTROSTORY_SObjType_Image1: Int16 = 1
private let INTROSTORY_SObjType_Image2: Int16 = 2
private let INTROSTORY_SObjType_Image3: Int16 = 3
private let INTROSTORY_SObjType_Image4: Int16 = 4
private let INTROSTORY_SObjType_Image5: Int16 = 5
private let INTROSTORY_SObjType_Image6: Int16 = 6
private let INTROSTORY_SObjType_Image7: Int16 = 7
private let INTROSTORY_SObjType_NanoLogo: Int16 = 8
private let NUM_SLIDES = 9

private let slideFadeRate: Float = 0.8

// Native Swift struct - was `typedef struct {...} SlideType;` in
// miscscreens.h. Zero C callers/globals reference it (see project memory),
// so it moved entirely off the C ABI. Also used by WinScreen.swift.
struct SlideType {
    var spriteNum: Int16 = 0
    var x: Float = 0
    var y: Float = 0
    var scale: Float = 0
    var rotz: Float = 0
    var alpha: Float = 0
    var delayToNext: Float = 0
    var delayToVanish: Float = 0
    var zoomSpeed: Float = 0
    var dx: Float = 0
    var dy: Float = 0
    var drot: Float = 0
    var delayUntilEffect: Float = 0
    var narrationSound: Int32 = 0
    var subtitleKey: Int32 = 0
}



private let gSlides: [SlideType] = [
    // PANGEA LOGO
    SlideType(
        spriteNum: INTROSTORY_SObjType_PangeaLogo, // sprite #
        x: 0.5, y: 0.5, // x / y
        scale: 250, // scale
        rotz: 0, // rotz
        alpha: 0, // alpha
        delayToNext: 4.0, // delay to next
        delayToVanish: 2.5, // delay to fade
        zoomSpeed: 20.0, // zoom speed
        dx: 0, dy: 0, // dx / dy
        drot: 0, // drot
        delayUntilEffect: 0, // delay to play effect
        narrationSound: Int32(EFFECT_NULL), // effect #
        subtitleKey: 0
    ),

    // IN THE YEAR 4222...
    SlideType(
        spriteNum: INTROSTORY_SObjType_Image1, // sprite #
        x: 0.5, y: 0.5, // x / y
        scale: 500, // scale
        rotz: -0.2, // rotz
        alpha: 0, // alpha
        delayToNext: 9.0, // delay to next
        delayToVanish: 9.0, // delay to fade
        zoomSpeed: 35.0, // zoom speed
        dx: 0, dy: 0, // dx / dy
        drot: 0.03, // drot
        delayUntilEffect: 0.5, // delay to play effect
        narrationSound: Int32(EFFECT_STORY1),
        subtitleKey: Int32(STR_STORY_1.rawValue)
    ),

    // HIS MISSION WAS TO...
    SlideType(
        spriteNum: INTROSTORY_SObjType_Image2, // sprite #
        x: -0.1, y: 0.8, // x / y
        scale: 350, // scale
        rotz: 0.2, // rotz
        alpha: 0, // alpha
        delayToNext: 12.0, // delay to next
        delayToVanish: 12.0, // delay to fade
        zoomSpeed: 35.0, // zoom speed
        dx: 35, dy: -12, // dx / dy
        drot: -0.02, // drot
        delayUntilEffect: 1.0, // delay to play effect
        narrationSound: Int32(EFFECT_STORY2),
        subtitleKey: Int32(STR_STORY_2.rawValue)
    ),

    // THE MISSION WAS A SUCCESS
    SlideType(
        spriteNum: INTROSTORY_SObjType_Image3, // sprite #
        x: 0.9, y: 0.5, // x / y
        scale: 400, // scale
        rotz: -0.3, // rotz
        alpha: 0, // alpha
        delayToNext: 8.0, // delay to next
        delayToVanish: 7.5, // delay to fade
        zoomSpeed: 35.0, // zoom speed
        dx: -40, dy: 0, // dx / dy
        drot: 0.05, // drot
        delayUntilEffect: 1.0, // delay to play effect
        narrationSound: Int32(EFFECT_STORY3),
        subtitleKey: Int32(STR_STORY_3.rawValue)
    ),

    // BUT BEFORE...
    SlideType(
        spriteNum: INTROSTORY_SObjType_Image4, // sprite #
        x: 0.5, y: 0.5, // x / y
        scale: 350, // scale
        rotz: 0, // rotz
        alpha: 0, // alpha
        delayToNext: 8.0, // delay to next
        delayToVanish: 8.0, // delay to fade
        zoomSpeed: 35.0, // zoom speed
        dx: 0, dy: 0, // dx / dy
        drot: 0, // drot
        delayUntilEffect: 1.0, // delay to play effect
        narrationSound: Int32(EFFECT_STORY4),
        subtitleKey: Int32(STR_STORY_4.rawValue)
    ),

    // THE EGGS WERE TAKEN TO...
    SlideType(
        spriteNum: INTROSTORY_SObjType_Image5, // sprite #
        x: 1.0, y: 0.5, // x / y
        scale: 500, // scale
        rotz: -0.2, // rotz
        alpha: 0, // alpha
        delayToNext: 14.0, // delay to next
        delayToVanish: 12.0, // delay to fade
        zoomSpeed: 20.0, // zoom speed
        dx: -40, dy: 0, // dx / dy
        drot: 0.02, // drot
        delayUntilEffect: 1.0, // delay to play effect
        narrationSound: Int32(EFFECT_STORY5),
        subtitleKey: Int32(STR_STORY_5.rawValue)
    ),

    // BUT THE REBELS LEFT...
    SlideType(
        spriteNum: INTROSTORY_SObjType_Image6, // sprite #
        x: 0.5, y: 0.5, // x / y
        scale: 350, // scale
        rotz: 0.2, // rotz
        alpha: 0, // alpha
        delayToNext: 8.5, // delay to next
        delayToVanish: 8.5, // delay to fade
        zoomSpeed: 30.0, // zoom speed
        dx: 0, dy: 0, // dx / dy
        drot: -0.02, // drot
        delayUntilEffect: 1.0, // delay to play effect
        narrationSound: Int32(EFFECT_STORY6),
        subtitleKey: Int32(STR_STORY_6.rawValue)
    ),

    // THIS HATCHLING...
    SlideType(
        spriteNum: INTROSTORY_SObjType_Image7, // sprite #
        x: 0.5, y: 0, // x / y
        scale: 400, // scale
        rotz: 0.3, // rotz
        alpha: 0, // alpha
        delayToNext: 9.0, // delay to next
        delayToVanish: 9.0, // delay to fade
        zoomSpeed: 40.0, // zoom speed
        dx: 0, dy: 20, // dx / dy
        drot: -0.05, // drot
        delayUntilEffect: 1.0, // delay to play effect
        narrationSound: Int32(EFFECT_STORY7),
        subtitleKey: Int32(STR_STORY_7.rawValue)
    ),

    SlideType(
        spriteNum: INTROSTORY_SObjType_NanoLogo, // sprite #
        x: 0.5, y: 0.5, // x / y
        scale: 300, // scale
        rotz: 0, // rotz
        alpha: 0, // alpha
        delayToNext: 8.0, // delay to next
        delayToVanish: 5.0, // delay to fade
        zoomSpeed: 30.0, // zoom speed
        dx: 0, dy: 0, // dx / dy
        drot: 0, // drot
        delayUntilEffect: 0.0, // delay to play effect
        narrationSound: Int32(EFFECT_NULL),
        subtitleKey: 0
    ),
]

// MARK: - Do intro story

func DoIntroStoryScreen() {
    // SETUP

    #if DEBUGLOG
    DebugLog("DoIntroStoryScreen: setupIntroStoryScreen...")
    #endif
    setupIntroStoryScreen()
    #if DEBUGLOG
    DebugLog("DoIntroStoryScreen: MakeFadeEvent...")
    #endif
    _ = MakeFadeEvent(UInt8(kFadeFlags_In), 2.0)

    #if DEBUGLOG
    DebugLog("DoIntroStoryScreen: PlaySong...")
    #endif
    PlaySong(Int16(SONG_INTRO), 1)

    // LOOP

    #if DEBUGLOG
    DebugLog("DoIntroStoryScreen: entering slideshow loop...")
    #endif
    gEngine.screens.introStoryEndSlideShow = false

    while !gEngine.screens.introStoryEndSlideShow {
        CalcFramesPerSecond()
        DoSDLMaintenance()
        if UserWantsOut() != 0 {
            gEngine.game.viewInfoPtr!.fadeSound = true
            break
        }

        // MOVE

        MoveObjects()

        // DRAW

        OGL_DrawScene(DrawObjects)
    }

    // FADE OUT

    #if DEBUGLOG
    DebugLog("DoIntroStoryScreen: slideshow loop exited, OGL_FadeOutScene...")
    #endif
    OGL_FadeOutScene(DrawObjects, nil)

    // CLEANUP

    #if DEBUGLOG
    DebugLog("DoIntroStoryScreen: freeIntroStoryScreen...")
    #endif
    freeIntroStoryScreen()
    #if DEBUGLOG
    DebugLog("DoIntroStoryScreen: done.")
    #endif
}

// MARK: - Setup intro story

private func setupIntroStoryScreen() {
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

    #if DEBUGLOG
    DebugLog("setupIntroStoryScreen: OGL_SetupGameView...")
    #endif
    OGL_SetupGameView(&viewDef)

    // LOAD ART

    // LOAD SPRITES

    #if DEBUGLOG
    DebugLog("setupIntroStoryScreen: LoadSpriteGroupFromSeries(story)...")
    #endif
    LoadSpriteGroupFromSeries(Int32(SPRITE_GROUP_LEVELSPECIFIC), Int32(NUM_SLIDES), "story")
    #if DEBUGLOG
    DebugLog("setupIntroStoryScreen: LoadSpriteAtlas(swiss)...")
    #endif
    LoadSpriteAtlas(Int32(ATLAS_GROUP_FONT3), ":Sprites:fonts:swiss", Int32(kAtlasLoadFont))

    #if DEBUGLOG
    DebugLog("setupIntroStoryScreen: LoadSoundBank(narration)...")
    #endif
    LoadSoundBank(UInt8(SOUND_BANK_NARRATION))

    // MAKE OBJECTS

    #if DEBUGLOG
    DebugLog("setupIntroStoryScreen: buildSlideShowObjects...")
    #endif
    buildSlideShowObjects()
    #if DEBUGLOG
    DebugLog("setupIntroStoryScreen: done.")
    #endif
}

// MARK: - Free intro story

private func freeIntroStoryScreen() {
    MyFlushEvents()
    DeleteAllObjects()
    FreeAllSkeletonFiles(-1)
    DisposeSpriteGroup(Int32(SPRITE_GROUP_LEVELSPECIFIC))
    DisposeSpriteAtlas(Int32(ATLAS_GROUP_FONT3))
    DisposeAllBG3DContainers()
    DisposeTerrain()
    DisposeSoundBank(UInt8(SOUND_BANK_NARRATION))

    OGL_DisposeGameView()
}

// MARK: -

// MARK: - Build slide show objects

private let cDrawBottomGradient: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { _ in
    OGL_PushState()
    SetInfobarSpriteState(0, 1)
    OGL_DisableTexture2D()
    OGL_EnableBlend()

    let y: Float = 320

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

private func buildSlideShowObjects() {
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

        slideObj.setStatus(STATUS_BIT_HIDDEN) // hide all slides @ start

        slideObj.pointee.ColorFilter.a = gSlides[i].alpha

        gEngine.screens.introStorySlideActive[i] = i == 0 // (this sets which frame we start on)

        slideObj.pointee.Timer = gSlides[i].delayToNext // set time to show before starting next slide
        slideObj.pointee.Health = gSlides[i].delayToVanish // time to show before start fadeout of this slide

        slideObj.pointee.SpecialF.0 = gSlides[i].zoomSpeed // ZoomSpeed
        slideObj.pointee.Delta.x = gSlides[i].dx
        slideObj.pointee.Delta.y = gSlides[i].dy
        slideObj.pointee.DeltaRot.z = gSlides[i].drot
        slideObj.pointee.SpecialF.1 = gSlides[i].delayUntilEffect // EffectTimer

        slideObj.pointee.AnaglyphZ = -10 // make appear deep in the monitor
    }

    if gGamePrefs.cutsceneSubtitles != 0 {
        var gradientDef = NewObjectDefinitionType()
        gradientDef.genre = UInt8(CUSTOM_GENRE)
        gradientDef.coord = OGLPoint3D(x: 0, y: 0, z: 0)
        gradientDef.slot = Int16(SPRITE_SLOT)
        gradientDef.scale = 1
        gradientDef.drawCall = cDrawBottomGradient
        _ = MakeNewObject(&gradientDef)
    }
}

// MARK: - Move slide

private let cMoveSlide: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    let theNode = theNodeOpt!
    let fps = gEngine.framesPerSecondFrac
    let slideNum = Int(theNode.pointee.Kind)
    let isLastSlide = slideNum >= NUM_SLIDES - 1

    if !gEngine.screens.introStorySlideActive[slideNum] { // is this slide still waiting?
        return
    }

    theNode.clearStatus(STATUS_BIT_HIDDEN)

    // MOVE IT

    theNode.pointee.Coord.x += fps * theNode.pointee.Delta.x
    theNode.pointee.Coord.y += fps * theNode.pointee.Delta.y

    theNode.pointee.Scale.y += fps * theNode.pointee.SpecialF.0 // ZoomSpeed
    theNode.pointee.Scale.x = theNode.pointee.Scale.y
    theNode.pointee.Rot.y += fps * theNode.pointee.DeltaRot.z

    // SEE IF TIME TO TRIGGER NEXT SLIDE

    theNode.pointee.Timer -= fps
    if !isLastSlide && theNode.pointee.Timer <= 0.0 {
        gEngine.screens.introStorySlideActive[slideNum + 1] = true
    }

    // SEE IF FADE OUT/IN

    theNode.pointee.Health -= fps
    if theNode.pointee.Health < 0.0 {
        theNode.pointee.ColorFilter.a -= fps * slideFadeRate
        if theNode.pointee.ColorFilter.a <= 0.0 {
            theNode.pointee.ColorFilter.a = 0
            if theNode.pointee.Timer <= 0.0 { // dont delete until the other timer is also done
                DeleteObject(theNode)
                if isLastSlide { // was that the last slide?
                    gEngine.screens.introStoryEndSlideShow = true
                }
                return
            }
        }
    }

    // FADE IN
    else {
        theNode.pointee.ColorFilter.a += fps * slideFadeRate
        if theNode.pointee.ColorFilter.a > 1.0 {
            theNode.pointee.ColorFilter.a = 1.0
        }
    }

    // PLAY EFFECT?

    if gSlides[slideNum].narrationSound != Int32(EFFECT_NULL) // does it have an effect?
        && theNode.pointee.Flag.0 == 0 { // has it been played yet?
        theNode.pointee.SpecialF.1 -= fps // EffectTimer
        if theNode.pointee.SpecialF.1 <= 0.0 { // is it time to play it?
            let volume = UInt32(FULL_CHANNEL_VOLUME) * 175 / 100
            PlayEffect_Parms(Int16(gSlides[slideNum].narrationSound), volume, volume, UInt(NORMAL_CHANNEL_RATE))
            theNode.pointee.Flag.0 = 1

            makeSubtitleObjects(slideNum)
        }
    }
}

private let FULL_CHANNEL_VOLUME: UInt32 = 0x0100

// MARK: -

private let cMoveSubtitle: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    let theNode = theNodeOpt!
    let fps = gEngine.framesPerSecondFrac

    if floorf(theNode.pointee.SpecialF.0 * 100) >= 0 {
        theNode.setStatus(STATUS_BIT_HIDDEN)
        theNode.pointee.SpecialF.0 -= fps
        theNode.pointee.ColorFilter.a = 0
    } else {
        theNode.clearStatus(STATUS_BIT_HIDDEN)
        theNode.pointee.Health -= fps

        if theNode.pointee.Health < 0.25 {
            theNode.pointee.ColorFilter.a -= fps * 5
        } else {
            theNode.pointee.ColorFilter.a += fps * 5
        }

        if theNode.pointee.ColorFilter.a > 1 {
            theNode.pointee.ColorFilter.a = 1
        } else if theNode.pointee.ColorFilter.a < 0 {
            theNode.pointee.ColorFilter.a = 0
        }

        if floorf(theNode.pointee.Health * 100) < 0 {
            DeleteObject(theNode)
        }
    }
}

private func makeSubtitleObjects(_ slideNum: Int) {
    if gGamePrefs.cutsceneSubtitles == 0 {
        return
    }

    let text = localized(LocStrID(rawValue: UInt32(gSlides[slideNum].subtitleKey)))

    if text.isEmpty {
        return
    }

    var subRow: Int32 = 0
    var subDuration: Float = 0
    var subDelay: Float = 0

    for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
        if line.first == "#" {
            subDelay += subDuration
            subDuration = 0
            subRow = 0

            let digits = line.dropFirst()
            for ch in digits {
                subDuration *= 10
                subDuration += Float(ch.asciiValue! - Character("0").asciiValue!)
            }
            subDuration *= 0.001
        } else if !line.isEmpty {
            var def = NewObjectDefinitionType()
            def.coord = OGLPoint3D(x: 640 / 2, y: 480 - 60 + 22 * Float(subRow), z: 0)
            def.scale = 35 * 0.5 * 0.015
            def.slot = Int16(SPRITE_SLOT)
            def.group = UInt8(ATLAS_GROUP_FONT3)
            def.flags = UInt32(STATUS_BIT_HIDDEN)

            let textNode = TextMesh_New(String(line), 0, &def)
            textNode.pointee.SpecialF.0 = subDelay
            textNode.pointee.Health = subDuration
            textNode.pointee.MoveCall = cMoveSubtitle
            textNode.pointee.ColorFilter = OGLColorRGBA(r: 1, g: 1, b: 0.7, a: 1)

            subRow += 1
        } else {
            subRow += 1
        }
    }
}
