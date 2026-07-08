// MainMenu.swift - Port of MainMenu.c to Swift
//
// gPlayNow is native Swift storage now (converted 2026-07-07): nothing in
// any .c file touches it anymore (MainMenuGlobals.c, its last real C
// owner, is deleted).

var gPlayNow: UInt8 = 0

// MARK: - Main menu tree

private let cDisableEmptyFileSlots: @convention(c) (UnsafePointer<MenuItem>?) -> Int32 = { mi in
    mi.map { DisableEmptyFileSlots($0) } ?? 0
}

private let cCheckForLevelCheat: @convention(c) () -> Void = {
    var i = 0
    while !IsMenuTreeEndSentinel(gMainMenuTreePtr.advanced(by: i)) {
        if gMainMenuTreePtr[i].id == fourCC("adve") {
            gMainMenuTreePtr[i].next = SwIsKeyHeld(Int(SDL_SCANCODE_F10.rawValue)) ? fourCC("chea") : fourCC("EXIT")
            break
        }
        i += 1
    }
}

private let cDeleteFileSlot: @convention(c) () -> Void = {
    let id = GetCurrentMenuItemID()
    let base = fourCC("df#0")
    if id >= base && id < base + 10 {
        _ = DeleteSavedGame(id - base)
    } else {
        SwAlert("DeleteFileSlot: illegal menu item ID")
    }
}

var gMainMenuTreePtr: UnsafeMutablePointer<MenuItem> = makeMenuTreeBuffer([
    miRoot(fourCC("root")),
    miPick(STR_PLAY_GAME, next: fourCC("play")),
    miPick(STR_SETTINGS,  next: fourCC("sett")),
    miPick(STR_INFO,      next: fourCC("info")),
    miPick(STR_QUIT,      next: fourCC("EXIT"), id: fourCC("quit")),

    miRoot(fourCC("play")),
    miPick(STR_ADVENTURE,    next: fourCC("EXIT"), id: fourCC("adve"), callback: cCheckForLevelCheat),
    miPick(STR_NANO_VS_NANO, next: fourCC("bttl")),
    miPick(STR_SAVED_GAMES,  next: fourCC("load")),
    miPick(STR_BACK_SYMBOL,  next: fourCC("BACK")),

    miRoot(fourCC("info")),
    miPick(STR_STORY,           next: fourCC("EXIT"), id: fourCC("intr")),
    miPick(STR_STORY_SUBTITLED, next: fourCC("EXIT"), id: fourCC("ints")),
    miPick(STR_CREDITS,         next: fourCC("EXIT"), id: fourCC("cred")),
    miPick(STR_BACK_SYMBOL,     next: fourCC("BACK")),

    miRoot(fourCC("bttl")),
    miPick(STR_RACE1,    next: fourCC("EXIT"), id: fourCC("rac1")),
    miPick(STR_RACE2,    next: fourCC("EXIT"), id: fourCC("rac2")),
    miSpacer(customHeight: 0.3),
    miPick(STR_BATTLE1,  next: fourCC("EXIT"), id: fourCC("bat1")),
    miPick(STR_BATTLE2,  next: fourCC("EXIT"), id: fourCC("bat2")),
    miSpacer(customHeight: 0.3),
    miPick(STR_CAPTURE1, next: fourCC("EXIT"), id: fourCC("cap1")),
    miPick(STR_CAPTURE2, next: fourCC("EXIT"), id: fourCC("cap2")),
    miSpacer(customHeight: 0.3),
    miPick(STR_BACK_SYMBOL, next: fourCC("BACK")),

    miRoot(fourCC("chea")),
    miLabel(rawText: staticCStr("CHEAT MENU!")),
    miPick(STR_NULL, next: fourCC("EXIT"), id: fourCC("cht1"), rawText: staticCStr("LEVEL 1: FOREST")),
    miPick(STR_NULL, next: fourCC("EXIT"), id: fourCC("cht2"), rawText: staticCStr("LEVEL 2: DESERT")),
    miPick(STR_NULL, next: fourCC("EXIT"), id: fourCC("cht3"), rawText: staticCStr("LEVEL 3: SWAMP")),
    miPick(STR_BACK_SYMBOL, next: fourCC("BACK")),

    miRoot(fourCC("load")),
    miFileSlot(STR_FILE, id: fourCC("lf#0"), fileSlot: 0, next: fourCC("EXIT"), getLayoutFlags: cDisableEmptyFileSlots),
    miFileSlot(STR_FILE, id: fourCC("lf#1"), fileSlot: 1, next: fourCC("EXIT"), getLayoutFlags: cDisableEmptyFileSlots),
    miFileSlot(STR_FILE, id: fourCC("lf#2"), fileSlot: 2, next: fourCC("EXIT"), getLayoutFlags: cDisableEmptyFileSlots),
    miFileSlot(STR_FILE, id: fourCC("lf#3"), fileSlot: 3, next: fourCC("EXIT"), getLayoutFlags: cDisableEmptyFileSlots),
    miFileSlot(STR_FILE, id: fourCC("lf#4"), fileSlot: 4, next: fourCC("EXIT"), getLayoutFlags: cDisableEmptyFileSlots),
    miPick(STR_DELETE_A_FILE, next: fourCC("dele")),
    miPick(STR_BACK_SYMBOL,   next: fourCC("BACK")),

    miRoot(fourCC("dele")),
    miLabel(STR_DELETE_WHICH, customHeight: 1.5),
    miFileSlot(STR_DELETE, id: fourCC("df#0"), fileSlot: 0, next: fourCC("BACK"), getLayoutFlags: cDisableEmptyFileSlots, callback: cDeleteFileSlot),
    miFileSlot(STR_DELETE, id: fourCC("df#1"), fileSlot: 1, next: fourCC("BACK"), getLayoutFlags: cDisableEmptyFileSlots, callback: cDeleteFileSlot),
    miFileSlot(STR_DELETE, id: fourCC("df#2"), fileSlot: 2, next: fourCC("BACK"), getLayoutFlags: cDisableEmptyFileSlots, callback: cDeleteFileSlot),
    miFileSlot(STR_DELETE, id: fourCC("df#3"), fileSlot: 3, next: fourCC("BACK"), getLayoutFlags: cDisableEmptyFileSlots, callback: cDeleteFileSlot),
    miFileSlot(STR_DELETE, id: fourCC("df#4"), fileSlot: 4, next: fourCC("BACK"), getLayoutFlags: cDisableEmptyFileSlots, callback: cDeleteFileSlot),
    miPick(STR_BACK_SYMBOL, next: fourCC("BACK")),

    miRoot(),
])

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
        _ = MakeMenu(gMainMenuTreePtr, &style)
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
        try? SDL.glSetSwapInterval(0) // no vsync for time demo

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

func MakeMouseCursorObject() -> UnsafeMutablePointer<ObjNode>! {
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
