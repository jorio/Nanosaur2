// MainMenu.swift - Port of MainMenu.c to Swift
// The main menu tree (and the callbacks it embeds by designated
// initializer) stays in MainMenu.c; see MainMenuInternal.h.

private let screensaverDelay: Float = 15.0
private let menuTextAnaglyphZ: Float = 4.0
private let cursorScale: Float = 35.0

private var gMainMenuBackground: UnsafeMutablePointer<ObjNode>?
private var gMainMenuMouseCursor: UnsafeMutablePointer<ObjNode>?

// MARK: - Main menu move callback

private func moveMainMenu() {
    // SEE IF DO SCREENSAVER
    //
    // BEFORE updating the menu (Otherwise MoveObjects may delete it)

    if GetCurrentMenu() == 0x726F_6F74 && GetMenuIdleTime() > screensaverDelay { // 'root'
        KillMenu(0x7373_6176) // 'ssav'
    } else if SwIsKeyDown(Int(SDL_SCANCODE_T.rawValue)) { // activate time demo?
        KillMenu(0x6465_6D6F) // 'demo'
    }

    MoveObjects()
}

// MARK: - Do mainmenu screen

func DoMainMenuScreen() {
    gPlayNow = 0

    while gPlayNow == 0 {
        if gCurrentSong != Int16(SONG_THEME) {
            PlaySong(Int16(SONG_THEME), 1)
        }

        setupMainMenuScreen()

        var style = kDefaultMenuStyle
        style.yOffset = 302.5
        _ = MakeMenu(GetMainMenuTree(), &style)
        RegisterSettingsMenu()

        while gMenuOutcome == 0 {
            DoSDLMaintenance()
            CalcFramesPerSecond()
            moveMainMenu()
            OGL_DrawScene(DrawObjects)
        }

        // Decide whether to fade out the music
        switch gMenuOutcome {
        case 0x6372_6564, 0x7373_6176: // 'cred', 'ssav'
            gGameViewInfoPtr!.pointee.fadeSound = 0

        case 0x7261_6331, 0x7261_6332, 0x6261_7431, 0x6261_7432, 0x6361_7031, 0x6361_7032: // 'rac1','rac2','bat1','bat2','cap1','cap2'
            // entering multiplayer; fade sound if we're gonna skip LocalGather
            gGameViewInfoPtr!.pointee.fadeSound = GetNumGamepad() >= 2 ? 1 : 0

        default:
            gGameViewInfoPtr!.pointee.fadeSound = 1
        }

        OGL_FadeOutScene(DrawObjects, nil)
        freeMainMenuScreen()

        processMenuOutcome(gMenuOutcome)
    }
}

// MARK: - Build main menu objects
//
// We need to expose this to AnaglyphCalibration.c so the background texture
// always reflects the current anaglyph settings

func BuildMainMenuObjects() {
    if let gMainMenuBackground {
        DeleteObject(gMainMenuBackground)
    }

    if let gMainMenuMouseCursor {
        DeleteObject(gMainMenuMouseCursor)
    }

    gMainMenuBackground = MakeBackgroundPictureObject(":Sprites:menu:menuback")
    gMainMenuMouseCursor = MakeMouseCursorObject()
}

// MARK: - Setup mainmenu screen

private func setupMainMenuScreen() {
    var viewDef = OGLSetupInputType()
    let fillDirection1 = OGLVector3D(x: -0.7, y: 0.9, z: -1.0)
    let fillDirection2 = OGLVector3D(x: 0.3, y: 0.8, z: 1.0)

    gPlayNow = 0

    // SETUP VIEW

    OGL_NewViewDef(&viewDef)

    viewDef.camera.fov = 1.0
    viewDef.camera.hither = 20
    viewDef.camera.yon = 2500

    viewDef.styles.useFog = 1
    viewDef.styles.fogStart = viewDef.camera.yon * 0.6
    viewDef.styles.fogEnd = viewDef.camera.yon * 0.9

    viewDef.view.clearBackBuffer = 1
    viewDef.view.clearColor.r = 0
    viewDef.view.clearColor.g = 0
    viewDef.view.clearColor.b = 0

    viewDef.camera.from.0.x = 0
    viewDef.camera.from.0.y = 50
    viewDef.camera.from.0.z = 500

    viewDef.camera.to.0.y = 100.0

    viewDef.lights.ambientColor.r = 0.2
    viewDef.lights.ambientColor.g = 0.2
    viewDef.lights.ambientColor.b = 0.2

    viewDef.lights.numFillLights = 2

    viewDef.lights.fillDirection.0 = fillDirection1
    viewDef.lights.fillColor.0.r = 0.8
    viewDef.lights.fillColor.0.g = 0.8
    viewDef.lights.fillColor.0.b = 0.6

    viewDef.lights.fillDirection.1 = fillDirection2
    viewDef.lights.fillColor.1.r = 0.5
    viewDef.lights.fillColor.1.g = 0.5
    viewDef.lights.fillColor.1.b = 0.0

    OGL_SetupGameView(&viewDef)

    InitSparkles()

    // BUILD OBJECTS

    BuildMainMenuObjects()
    _ = MakeFadeEvent(UInt8(kFadeFlags_In), 3.0)
}

// MARK: - Free mainmenu screen

private func freeMainMenuScreen() {
    MyFlushEvents()

    DeleteAllObjects()
    gMainMenuMouseCursor = nil
    gMainMenuBackground = nil

    DisposeSpriteGroup(Int32(SPRITE_GROUP_LEVELSPECIFIC))
    DisposeAllBG3DContainers()
    OGL_DisposeGameView()
}

// MARK: -

// MARK: - Process menu outcome

private func processMenuOutcome(_ outcome: Int32) {
    gPlayNow = 0

    switch outcome {
    case 0x7175_6974: // 'quit'
        CleanQuit()

    case 0x7373_6176: // 'ssav' SCREENSAVER
        DoLevelIntroScreen(UInt8(INTRO_MODE_SCREENSAVER))

    case 0x696E_7472: // 'intr' STORY
        gGamePrefs.cutsceneSubtitles = 0
        _ = SavePrefs()
        DoIntroStoryScreen()

    case 0x696E_7473: // 'ints'
        gGamePrefs.cutsceneSubtitles = 1
        _ = SavePrefs()
        DoIntroStoryScreen()

    case 0x6372_6564: // 'cred' CREDITS
        DoLevelIntroScreen(UInt8(INTRO_MODE_CREDITS))

    case 0x6465_6D6F: // 'demo' TIME DEMO (BENCHMARK)
        gTimeDemo = 1
        gSkipLevelIntro = 1
        gNumPlayers = 1
        gPlayNow = 1
        gPlayingFromSavedGame = 0
        gLevelNum = Int16(LevelNum.adventure3.rawValue)
        SDL_GL_SetSwapInterval(0) // no vsync for time demo

    case 0x6164_7665: // 'adve' SINGLE-PLAYER ADVENTURE CAMPAIGN
        setMainController1P()

        gNumPlayers = 1
        gPlayNow = 1
        gPlayingFromSavedGame = 0
        gLevelNum = Int16(LevelNum.adventure1.rawValue)

    case 0x6368_7431, 0x6368_7432, 0x6368_7433: // 'cht1','cht2','cht3'
        setMainController1P()

        gNumPlayers = 1
        gPlayNow = 1
        gPlayingFromSavedGame = 0
        gSkipLevelIntro = 1
        gLevelNum = Int16(LevelNum.adventure1.rawValue) + Int16(outcome - 0x6368_7431)

    case 0x6C66_2330, 0x6C66_2331, 0x6C66_2332, 0x6C66_2333, 0x6C66_2334, // 'lf#0'..'lf#4'
         0x6C66_2335, 0x6C66_2336, 0x6C66_2337, 0x6C66_2338, 0x6C66_2339: // 'lf#5'..'lf#9'
        setMainController1P()

        var loaded = SaveGameType()
        if LoadSavedGame(outcome - 0x6C66_2330, &loaded) != 0 {
            UseSaveGame(&loaded)
            gPlayingFromSavedGame = 1
            gNumPlayers = 1
            gPlayNow = 1
        }

    case 0x7261_6331, 0x7261_6332: // 'rac1','rac2' RACE
        gNumPlayers = 2
        gVSMode = .race
        gLevelNum = Int16(LevelNum.race1.rawValue) + Int16(outcome - 0x7261_6331)
        gPlayNow = 1
        gPlayingFromSavedGame = 0

    case 0x6261_7431, 0x6261_7432: // 'bat1','bat2' BATTLE
        gNumPlayers = 2
        gVSMode = .battle
        gLevelNum = Int16(LevelNum.battle1.rawValue) + Int16(outcome - 0x6261_7431)
        gPlayNow = 1
        gPlayingFromSavedGame = 0

    case 0x6361_7031, 0x6361_7032: // 'cap1','cap2' CAPTURE THE FLAG
        gNumPlayers = 2
        gVSMode = .captureTheFlag
        gLevelNum = Int16(LevelNum.flag1.rawValue) + Int16(outcome - 0x6361_7031)
        gPlayNow = 1
        gPlayingFromSavedGame = 0

    default:
        let c0 = Character(UnicodeScalar(UInt8((outcome >> 24) & 0xFF)))
        let c1 = Character(UnicodeScalar(UInt8((outcome >> 16) & 0xFF)))
        let c2 = Character(UnicodeScalar(UInt8((outcome >> 8) & 0xFF)))
        let c3 = Character(UnicodeScalar(UInt8((outcome >> 0) & 0xFF)))
        SwAlert("Unimplemented menu outcome '\(c0)\(c1)\(c2)\(c3)'")
    }
}

// MARK: -

// MARK: - Move cursor
//
// NOTE:  this function is called from other places which need the cursor, not just the main menu

private let cMoveMouseCursorObject: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    let theNode = theNodeOpt!

    // UPDATE CROSSHAIR POSITION

    gCursorCoord = GetMouseCoords640x480()

    theNode.pointee.Coord.x = gCursorCoord.x
    theNode.pointee.Coord.y = gCursorCoord.y

    theNode.updateTransforms()

    // Boolean visible = !gUserPrefersGamepad;
    let visible = gUserPrefersGamepad == 0 && IsMenuMouseControlled()

    if visible {
        // Fade in to prevent jarring cursor warp when exiting mouse grab mode
        theNode.pointee.ColorFilter.a += 8.0 * gFramesPerSecondFrac
        if theNode.pointee.ColorFilter.a > 1 {
            theNode.pointee.ColorFilter.a = 1
        }
    } else {
        theNode.pointee.ColorFilter.a -= 4.0 * gFramesPerSecondFrac
        if theNode.pointee.ColorFilter.a < 0 {
            theNode.pointee.ColorFilter.a = 0
        }
    }
}

// MARK: - Make mouse cursor object

@c @implementation
public func MakeMouseCursorObject() -> UnsafeMutablePointer<ObjNode>! {
    SwGameAssert(GetNumSpritesInGroup(Int32(SPRITE_GROUP_CURSOR)) != 0)

    var def = NewObjectDefinitionType()
    def.group = UInt8(SPRITE_GROUP_CURSOR)
    def.type = 0 // the only sprite in the group
    def.coord = OGLPoint3D(x: 0, y: 0, z: 0)
    def.flags = UInt32(STATUS_BIT_MOVEINPAUSE)
    def.slot = Int16(MENU_SLOT) + 100 // make sure this is the last sprite drawn (CURSOR_SLOT)
    def.moveCall = cMoveMouseCursorObject
    def.rot = 0
    def.scale = cursorScale

    let cursor = MakeSpriteObject(&def, 0)!
    cursor.pointee.AnaglyphZ = menuTextAnaglyphZ + 0.5
    cursor.pointee.ColorFilter.a = 0

    SendNodeToOverlayPane(cursor)

    return cursor
}

// MARK: - Set main controller to use in single-player adventure

private func setMainController1P() {
    let mainController = GetLastControllerForNeedAnyP(Int32(kNeed_UIConfirm))
    if mainController >= 0 {
        SetMainController(mainController)
    }
}
