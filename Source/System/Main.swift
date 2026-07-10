// Main.swift - Port of Main.c to Swift
//
// gGamePrefs is the only global left in Main.c: Boot.cpp reads/writes
// gGamePrefs.antialiasingLevel directly, so PrefsType must stay a
// C-visible extern global. Every other global that used to live in
// Main.c (gGameViewInfoPtr, gLevelNum, gDebugMode, gAutoFadeStatusBits,
// gTimeDemo, gGameOver, gLevelCompleted, gPlayingFromSavedGame,
// gSkipLevelIntro, gRaceReadySetGoTimer, gPrefsFolderVRefNum/DirID,
// gWorldSunDirection, gBestCheckpointNum/Coord/Aim, gVSMode) is native
// Swift storage now (converted 2026-07-07): nothing in any .c file
// touches them anymore. gBestCheckpointNum/Coord/Aim were exposed via
// Get*/Set* shims in PlayerInternal.h; those are now plain Swift
// functions with the same names/signatures.
//
// gTimeDemoStartTime/EndTime, gGameLevelTimer, gLevelCompletedCoolDownTimer,
// gFillColor1, and gLevelSongs have no `extern` declaration anywhere and
// are only ever touched from this file, so they stay private Swift
// storage.

var gVSMode: VSMode = .none // nano vs. nano mode

var gGameViewInfoPtr: UnsafeMutablePointer<OGLSetupOutputType>!
var gGameFrameNum: UInt32 = 0
var gLevelNum: Int16 = 0
var gDebugMode: UInt8 = 0
var gAutoFadeStatusBits: UInt32 = 0
var gTimeDemo: UInt8 = 0
var gGameOver: UInt8 = 0
var gLevelCompleted: UInt8 = 0
var gPlayingFromSavedGame: UInt8 = 0
var gSkipLevelIntro: UInt8 = 0
var gRaceReadySetGoTimer: Float = 0
var gPrefsFolderVRefNum: Int16 = 0
var gPrefsFolderDirID: Int = 0
var gWorldSunDirection = OGLVector3D()

private var gBestCheckpointNumArr: [Int16] = Array(repeating: 0, count: Int(MAX_PLAYERS))
private var gBestCheckpointCoordArr: [OGLPoint3D] = Array(repeating: OGLPoint3D(), count: Int(MAX_PLAYERS))
private var gBestCheckpointAimArr: [Float] = Array(repeating: 0, count: Int(MAX_PLAYERS))

func GetBestCheckpointNum(_ i: Int32) -> Int16 { gBestCheckpointNumArr[Int(i)] }
func SetBestCheckpointNum(_ i: Int32, _ v: Int16) { gBestCheckpointNumArr[Int(i)] = v }
func GetBestCheckpointCoord(_ i: Int32) -> OGLPoint3D { gBestCheckpointCoordArr[Int(i)] }
func SetBestCheckpointCoord(_ i: Int32, _ v: OGLPoint3D) { gBestCheckpointCoordArr[Int(i)] = v }
func GetBestCheckpointAim(_ i: Int32) -> Float { gBestCheckpointAimArr[Int(i)] }
func SetBestCheckpointAim(_ i: Int32, _ v: Float) { gBestCheckpointAimArr[Int(i)] = v }

private var gTimeDemoStartTime: UInt32 = 0
private var gTimeDemoEndTime: UInt32 = 0
private var gGameLevelTimer: Float = 0
private var gLevelCompletedCoolDownTimer: Float = 0
private var gFillColor1 = OGLColorRGBA(r: 0.8, g: 0.8, b: 0.7, a: 1)

// LEVEL SONGS
private let gLevelSongs: [Int16] = [
    Int16(SONG_LEVEL1), // ADVENTURE LEVEL 1
    Int16(SONG_LEVEL2), // ADVENTURE LEVEL 2
    Int16(SONG_LEVEL3), // ADVENTURE LEVEL 3

    Int16(SONG_LEVEL3), // RACE 1
    Int16(SONG_LEVEL2), // RACE 2
    Int16(SONG_LEVEL1), // BATTLE 1
    Int16(SONG_LEVEL2), // BATTLE 2
    Int16(SONG_LEVEL3), // CAPTURE THE FLAG 1
    Int16(SONG_LEVEL1), // CAPTURE THE FLAG 2
]

// MARK: - Toolbox init

func ToolBoxInit() {
    MyFlushEvents()

    // FIRST VERIFY SYSTEM BEFORE GOING TOO FAR

    VerifySystem()
    InitInput()

    // INIT PREFERENCES

    InitPrefsFolder(0)
    InitDefaultPrefs()
    _ = LoadPrefs()

    SetFullscreenMode(false)

    // BOOT OGL

    OGL_Boot()
}

// MARK: - Init default prefs

func InitDefaultPrefs() {
    withUnsafeMutableBytes(of: &gGamePrefs) { raw in
        _ = SDL_memset(raw.baseAddress, 0, raw.count)
    }

    // DETERMINE WHAT LANGUAGE IS ON THIS MACHINE

    gGamePrefs.fullscreen = 1
    gGamePrefs.vsync = 1

    gGamePrefs.language = UInt8(GetBestLanguageIDFromSystemLocale().rawValue)
    gGamePrefs.cutsceneSubtitles = IsNativeEnglishSystem() ? 0 : 1 // enable subtitles if user's native language isn't English

    gGamePrefs.lowRenderQuality = 0
    gGamePrefs.splitScreenMode = UInt8(SplitscreenMode.vertical.rawValue)
    gGamePrefs.stereoGlassesMode = UInt8(StereoGlassesMode.off.rawValue)
    gGamePrefs.anaglyphCalibrationRed = UInt8(DEFAULT_ANAGLYPH_R)
    gGamePrefs.anaglyphCalibrationGreen = UInt8(DEFAULT_ANAGLYPH_G)
    gGamePrefs.anaglyphCalibrationBlue = UInt8(DEFAULT_ANAGLYPH_B)
    gGamePrefs.doAnaglyphChannelBalancing = 1

    gGamePrefs.showTargetingCrosshairs = 1
    gGamePrefs.kiddieMode = 0

    gGamePrefs.force4x3HUD = 0
    gGamePrefs.hudScale = 100

    gGamePrefs.mouseSensitivityLevel = UInt8(DEFAULT_MOUSE_SENSITIVITY_LEVEL)

    gGamePrefs.musicVolumePercent = 70
    gGamePrefs.sfxVolumePercent = 70

    gGamePrefs.rumbleIntensity = 100

    withUnsafeMutablePointer(to: &gGamePrefs.bindings) { dst in
        withUnsafePointer(to: kDefaultInputBindings) { src in
            UnsafeMutableRawPointer(dst).copyMemory(from: UnsafeRawPointer(src), byteCount: MemoryLayout<InputBinding>.size * Int(NUM_CONTROL_NEEDS))
        }
    }
}

// MARK: -

// MARK: - Play game adventure

// Play the multi-level adventure mode
private func playGameAdventure() {
    // GAME INITIALIZATION

    InitPlayerInfo_Game() // init player info for entire game

    // PLAY THRU LEVELS SEQUENTIALLY

    while gLevelNum <= Int16(LevelNum.adventure3.rawValue) {
        // DO LEVEL INTRO

        PlaySong(gLevelSongs[Int(gLevelNum)], 1)

        if gSkipLevelIntro == 0 {
            if (gLevelNum == 0) || gPlayingFromSavedGame != 0 {
                DoLevelIntroScreen(UInt8(INTRO_MODE_NOSAVE))
            } else {
                DoLevelIntroScreen(UInt8(INTRO_MODE_SAVEGAME))
            }
        }
        gSkipLevelIntro = 0 // reset skip flag

        MyFlushEvents()

        // LOAD ALL OF THE ART & STUFF

        initLevel()

        // PLAY IT

        playLevel()

        gPlayingFromSavedGame = 0 // once we've completed a level after restoring, we're not really playing from a saved game anymore

        // CLEANUP LEVEL

        MyFlushEvents()
        cleanupLevel()

        // SEE IF LOST

        if gGameOver != 0 { // bail out if game has ended
            break
        }

        // DO END-LEVEL BONUS SCREEN

        if gLevelNum == Int16(LevelNum.adventure3.rawValue) { // if just won game then do win screen first!
            DoWinScreen()
        }

        gLevelNum += 1
    }

    gPlayingFromSavedGame = 0
}

// MARK: - Play game: versus

// Play one of the 2-player versus modes.
private func playGameVersus() {
    // GAME INITIALIZATION

    InitPlayerInfo_Game() // init player info for entire game

    // DO LEVEL INTRO

    PlaySong(gLevelSongs[Int(gLevelNum)], 1)

    MyFlushEvents()

    // LOAD ALL OF THE ART & STUFF

    initLevel()

    // PLAY IT

    playLevel()

    // CLEANUP LEVEL

    MyFlushEvents()
    cleanupLevel()
}

// MARK: -

// MARK: - Init level

// Sets up the OpenGL draw context and loads all the data files
// for the level we're about to play.
private func initLevel() {
    if gTimeDemo != 0 { // if time demo always reset random seed
        SetMyRandomSeed(0)
    }

    // INIT COMMON STUFF

    gGameFrameNum = 0
    gGameLevelTimer = 0
    gGameOver = 0
    gLevelCompleted = 0

    for i in 0..<Int(gNumPlayers) {
        SetBestCheckpointNum(Int32(i), -1)
        GetPlayerInfoEntry(Int32(i)).pointee.objNode = nil
    }

    // MAKE VIEW

    SetTerrainScale(Int32(DEFAULT_TERRAIN_SCALE)) // set scale to some default for now

    // SETUP VIEW DEF

    var viewDef = OGLSetupInputType()
    OGL_NewViewDef(&viewDef)

    viewDef.camera.hither = 20
    viewDef.camera.fov = GetSplitscreenPaneFOV()
    viewDef.view.clearBackBuffer = 0
    viewDef.camera.yon = (Float(gSuperTileActiveRange) * Float(SUPERTILE_SIZE) * gTerrainPolygonSize) * 0.95

    switch Int16(gLevelNum) {
    case Int16(LevelNum.adventure2.rawValue), Int16(LevelNum.race2.rawValue), Int16(LevelNum.battle2.rawValue):
        viewDef.view.clearColor.r = 0.968
        viewDef.view.clearColor.g = 0.537
        viewDef.view.clearColor.b = 0.278
        viewDef.styles.useFog = 1
        viewDef.styles.fogStart = viewDef.camera.yon * 0.4
        viewDef.styles.fogEnd = viewDef.camera.yon * 0.95
        viewDef.lights.ambientColor.r = 0.45
        viewDef.lights.ambientColor.g = 0.45
        viewDef.lights.ambientColor.b = 0.45
        gWorldSunDirection.x = 0.4
        gWorldSunDirection.y = -0.3
        gWorldSunDirection.z = 0.2
        gFillColor1.r = 0.6
        gFillColor1.g = 0.6
        gFillColor1.b = 0.6
        gDrawLensFlare = 1

    case Int16(LevelNum.adventure3.rawValue), Int16(LevelNum.race1.rawValue), Int16(LevelNum.flag1.rawValue):
        viewDef.view.clearColor.r = 0.568
        viewDef.view.clearColor.g = 0.243
        viewDef.view.clearColor.b = 0.125
        viewDef.styles.useFog = 1
        viewDef.styles.fogStart = viewDef.camera.yon * 0.4
        viewDef.styles.fogEnd = viewDef.camera.yon * 0.95
        viewDef.lights.ambientColor.r = 0.45
        viewDef.lights.ambientColor.g = 0.45
        viewDef.lights.ambientColor.b = 0.45
        gWorldSunDirection.x = 0.4
        gWorldSunDirection.y = -0.3
        gWorldSunDirection.z = 0.2
        gFillColor1.r = 0.6
        gFillColor1.g = 0.6
        gFillColor1.b = 0.6
        gDrawLensFlare = 1

    default:
        viewDef.view.clearColor.r = 0.43
        viewDef.view.clearColor.g = 0.33
        viewDef.view.clearColor.b = 0.7
        viewDef.styles.useFog = 1
        viewDef.styles.fogStart = viewDef.camera.yon * 0.35
        viewDef.styles.fogEnd = viewDef.camera.yon * 0.95
        viewDef.lights.ambientColor.r = 0.4
        viewDef.lights.ambientColor.g = 0.4
        viewDef.lights.ambientColor.b = 0.4
        gWorldSunDirection.x = 0.4
        gWorldSunDirection.y = -0.5
        gWorldSunDirection.z = 0.5
        gFillColor1.r = 0.7
        gFillColor1.g = 0.7
        gFillColor1.b = 0.7
        gDrawLensFlare = 1
    }

    // SET LIGHTS

    viewDef.lights.numFillLights = 1
    gWorldSunDirection = gWorldSunDirection.normalized()
    viewDef.lights.fillDirection.0 = gWorldSunDirection
    viewDef.lights.fillColor.0 = gFillColor1

    // SET ANAGLYPH INFO

    if isStereo() {
        gAnaglyphFocallength = 200.0
        gAnaglyphEyeSeparation = 35.0

        if isStereoAnaglyphMono() {
            viewDef.lights.ambientColor.r += 0.1 // make a little brighter
            viewDef.lights.ambientColor.g += 0.1
            viewDef.lights.ambientColor.b += 0.1
        }
    }

    // MAKE DRAW CONTEXT

    OGL_SetupGameView(&viewDef)

    // SET AUTO-FADE INFO

    gAutoFadeStartDist = gGameViewInfoPtr!.pointee.yon * 0.80
    gAutoFadeEndDist = gGameViewInfoPtr!.pointee.yon * 0.9

    gAutoFadeRange_Frac = 1.0 / (gAutoFadeEndDist - gAutoFadeStartDist)

    if gAutoFadeStartDist != 0.0 {
        gAutoFadeStatusBits = UInt32(STATUS_BIT_AUTOFADE)
    } else {
        gAutoFadeStatusBits = 0
    }

    // LOAD ART & TERRAIN
    //
    // NOTE: only call this *after* draw context is created!

    LoadLevelArt()
    InitInfobar()

    // INIT OTHER MANAGERS

    InitSplineManager()
    InitContrails()
    InitEnemyManager()
    InitEffects()
    InitSparkles()
    InitItemsManager()

    // INIT SPECIAL

    // INIT LEVEL & MODE SPECIFICS
    //
    // (no cases active; the only original case was for a level that no
    // longer exists in this build, kept as dead code in the original too)

    if gVSMode == .race {
        gRaceReadySetGoTimer = 3.0
    }

    // INIT THE PLAYER & RELATED STUFF

    PrimeTerrainWater() // NOTE:  must do this before items get added since some items may be on the water
    InitPlayerAtStartOfLevel() // NOTE:  this will also cause the initial items in the start area to be created

    PrimeSplines()
    PrimeFences()

    // INIT CAMERAS

    for i in 0..<Int(gNumPlayers) {
        InitCamera_Terrain(Int16(i))
    }
}

// MARK: - Play level

private func playLevel() {
    // PREP STUFF

    DoSDLMaintenance()
    CalcFramesPerSecond()
    CalcFramesPerSecond()

    _ = MakeFadeEvent(UInt8(kFadeFlags_In), 1.0)

    if gTimeDemo != 0 {
        gTimeDemoStartTime = SwTickCount()
    }

    GrabMouse(1)

    // MAIN GAME LOOP

    while true {
        // INPUT

        DoSDLMaintenance()

        if gGamePaused != 0 {
            MoveObjects()
            CalcFramesPerSecond()
            DoPlayerTerrainUpdate()
            OGL_DrawScene(cDrawLevelCallback)
            continue
        }

        for i in 0..<Int(gNumPlayers) {
            UpdatePlayerSteering(Int32(i))
        }

        // MOVE OBJECTS & UPDATE TERRAIN & DRAW

        MoveEverything()
        DoPlayerTerrainUpdate()
        OGL_DrawScene(cDrawLevelCallback)

        // UPDATE FPS AND TIMERS

        CalcFramesPerSecond()
        let fps = gFramesPerSecondFrac

        gGameFrameNum += 1
        gGameLevelTimer += fps
        gDisableHiccupTimer = 0 // reenable this after the 1st frame

        // SEE IF RESET PLAYER NOW

        for i in 0..<Int(gNumPlayers) { // check all players
            if GetPlayerIsDead(Int32(i)) != 0 { // is this player dead?
                let oldTimer = GetDeathTimer(Int32(i))
                var deathTimer = oldTimer - fps
                SetDeathTimer(Int32(i), deathTimer)
                if deathTimer <= 0.0 { // is it time to reincarnate player?
                    let fadeOutSpeed: Float = 4.0

                    if oldTimer > 0.0 { // if just now crossed zero then start fade
                        if gNumPlayers > 1
                            || GetPlayerInfoEntry(Int32(i)).pointee.numFreeLives > 0 { // ...only if hasn't lost adventure mode yet (gameover will freeze-frame fadeout)
                            _ = MakeFadeEvent(UInt8(kFadeFlags_Out) | (UInt8(kFadeFlags_P1) << i), fadeOutSpeed)
                        }
                    } else if deathTimer < -(1.0 / fadeOutSpeed) { // once fully faded out reset player @ checkpoint
                        ResetPlayerAtBestCheckpoint(Int16(i))
                    }
                }
                _ = deathTimer
                deathTimer = 0
            }
        }

        // SEE IF PAUSED

        if SwIsNeedDown(Int(kNeed_UIPause), Int(ANY_PLAYER)) { // do regular pause mode
            DoPaused()
        }

        #if os(macOS)
        if IsCmdQDown() != 0 {
            DoReallyQuit()
        }
        #endif

        // LEVEL CHEAT

        if (SwIsKeyHeld(Int(SDL_SCANCODE_LGUI.rawValue)) || SwIsKeyHeld(Int(SDL_SCANCODE_RGUI.rawValue)))
            && SwIsKeyDown(Int(SDL_SCANCODE_F10.rawValue)) { // see if skip level
            gLevelCompleted = 1
        }

        // SEE IF LEVEL IS COMPLETED

        if gGameOver != 0 { // if we need immediate abort, then bail now
            break
        }

        if gLevelCompleted != 0 {
            gLevelCompletedCoolDownTimer -= fps // game is done, but wait for cool-down timer before bailing
            if gLevelCompletedCoolDownTimer <= 0.0 {
                break
            }
        }
    }

    GrabMouse(0)

    if gGammaFadeFrac > 0 { // only fade out if we haven't called MakeFadeEvent(kFadeFlags_Out) already
        gGameViewInfoPtr!.pointee.fadeSound = 1
        OGL_FadeOutScene(cDrawLevelCallback, cUpdateTerrainForFadeOut)
    }

    if gTimeDemo != 0 {
        gTimeDemoEndTime = SwTickCount()
        let ticks = gTimeDemoEndTime - gTimeDemoStartTime
        let seconds = Float(ticks) / 60.0

        showTimeDemoResults(Int32(gGameFrameNum), seconds, Float(gGameFrameNum) / seconds)

        SwExitToShell()
    }
}

// MARK: - Show time demo results

private func showTimeDemoResults(_ numFrames: Int32, _ numSeconds: Float, _ averageFPS: Float) {
    SwAlert("showTimeDemoResults:\nFrames: \(numFrames)\nTime: \(numSeconds)\nAverage FPS: \(averageFPS)\nPeak #Objs: \(gNumObjectNodesPeak)")
}

// MARK: - Draw level callback

private let cDrawLevelCallback: @convention(c) () -> Void = {
    if isStereo() {
        let p = Int(gCurrentSplitScreenPane) // get the player # who's draw context is being drawn

        // MAKE SURE ANAGLYPH SETTINGS ARE GOOD FOR THIS CAMERA MODE

        switch GetCameraMode(Int32(p)) {
        case UInt8(CameraMode.normal.rawValue):
            if isStereoShutter() {
                gAnaglyphFocallength = 280.0
                gAnaglyphEyeSeparation = 45.0
            } else {
                gAnaglyphFocallength = 260.0
                gAnaglyphEyeSeparation = 35.0
            }

        case UInt8(CameraMode.firstPerson.rawValue):
            gAnaglyphFocallength = 300.0
            gAnaglyphEyeSeparation = 80.0

        case UInt8(CameraMode.anaglyphClose.rawValue):
            gAnaglyphFocallength = 700.0
            gAnaglyphEyeSeparation = 50.0

        default:
            break
        }
    }

    DrawObjects()
}

private let cUpdateTerrainForFadeOut: @convention(c) () -> Void = {
    DoPlayerTerrainUpdate()
}

// IsStereo/IsStereoAnaglyphMono/IsStereoShutter are parameterized C macros,
// which Swift can't import as callable symbols.
private func isStereo() -> Bool { gGamePrefs.stereoGlassesMode != UInt8(StereoGlassesMode.off.rawValue) }
private func isStereoAnaglyphMono() -> Bool { gGamePrefs.stereoGlassesMode == UInt8(StereoGlassesMode.anaglyphMono.rawValue) }
private func isStereoShutter() -> Bool { gGamePrefs.stereoGlassesMode == UInt8(StereoGlassesMode.shutter.rawValue) }

// MARK: - Cleanup level

private func cleanupLevel() {
    FreeAllCustomSplines()
    StopAllEffectChannels()
    EmptySplineObjectList()
    DeleteAllObjects()
    FreeAllSkeletonFiles(-1)
    DisposeTerrain()
    DeleteAllParticleGroups()
    DeleteAllConfettiGroups()
    DisposeInfobar()
    DisposeParticleSystem()
    DisposeSpriteGroup(Int32(SPRITE_GROUP_LEVELSPECIFIC))
    DisposeSpriteGroup(Int32(SPRITE_GROUP_OVERHEADMAP))
    DisposeAllBG3DContainers()
    DisposeContrails()
    FreeAllZaps()

    OGL_DisposeGameView() // do this last!

    // SET SOME IMPORTANT GLOBALS BACK TO DEFAULTS

    gVSMode = .none
    gNumPlayers = 1
}

// MARK: -

// MARK: - Move everything

func MoveEverything() {
    MoveObjects()
    MoveSplineObjects()
    UpdateCameras() // update camera
    UpdateFences()
    UpdateDustDevilUVAnimation()

    // MODE-SPECIFIC STUFF

    switch gVSMode {
    // ADVENTURE MODE
    case .none:
        break

    // RACE MODE
    case .race:
        gRaceReadySetGoTimer -= gFramesPerSecondFrac
        CalcPlayerPlaces() // determinw who is in what place

    default:
        break
    }
}

// MARK: - Start level completion

func StartLevelCompletion(_ coolDownTimer: Float) {
    if gLevelCompleted == 0 {
        gLevelCompleted = 1
        gLevelCompletedCoolDownTimer = coolDownTimer
    }
}

// MARK: -

// MARK: - Prime time demo spline

func PrimeTimeDemoSpline(_ splineNum: Int, _ itemPtr: UnsafeMutablePointer<SplineItemType>!) -> UInt8 {
    if gTimeDemo == 0 { // are we in time demo mode?
        return 0
    }

    // GET SPLINE INFO

    let placement = itemPtr.pointee.placement
    var x: Float = 0
    var z: Float = 0
    GetCoordOnSpline(gSplineList + splineNum, placement, &x, &z)

    // MAKE DUMMY SPLINE TRACKER OBJECT

    var def = NewObjectDefinitionType()
    def.genre = UInt8(CUSTOM_GENRE)
    def.slot = 0
    def.moveCall = nil
    def.flags = 0
    def.scale = 1

    let newObj = MakeNewObject(&def)!

    // SET SPLINE INFO

    newObj.pointee.StatusBits |= UInt32(STATUS_BIT_ONSPLINE)
    newObj.pointee.SplineItemPtr = itemPtr
    newObj.pointee.SplineNum = UInt8(splineNum)
    newObj.pointee.SplinePlacement = placement
    newObj.pointee.SplineMoveCall = cMoveTimeDemoOnSpline // set move call

    // ADD SPLINE OBJECT TO SPLINE OBJECT LIST

    DetachObject(newObj, 1) // detach this object from the linked list
    AddToSplineObjectList(newObj, 1)

    return 1
}

// MARK: - Move time demo on spline

private let cMoveTimeDemoOnSpline: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }
    let player = GetPlayerInfoEntry(0).pointee.objNode!

    // MOVE ALONG THE SPLINE

    if IncreaseSplineIndex(theNode, 450) != 0 {
        gGameOver = 1
    }

    GetObjectCoordOnSpline(theNode)

    theNode.pointee.Coord.y = GetTerrainY(theNode.pointee.Coord.x, theNode.pointee.Coord.z) + 600.0
    theNode.pointee.OldCoord.y = theNode.pointee.Coord.y

    var v = OGLVector3D()
    v.x = theNode.pointee.Coord.x - theNode.pointee.OldCoord.x // calc aim vector
    v.y = theNode.pointee.Coord.y - theNode.pointee.OldCoord.y
    v.z = theNode.pointee.Coord.z - theNode.pointee.OldCoord.z
    v = v.normalized()

    // AIM ALONG SPLINE

    withUnsafePointer(to: gUp) { upPtr in
        OGL_UpdateCameraFromToUp(&theNode.pointee.OldCoord, &theNode.pointee.Coord, upPtr, 0)
    }

    GetPlayerInfoEntry(0).pointee.camera.cameraLocation = theNode.pointee.Coord
    GetPlayerInfoEntry(0).pointee.coord = theNode.pointee.Coord // update player coord
    player.pointee.Coord = theNode.pointee.Coord
    player.pointee.MotionVector = v
    let r = CalcYAngleFromPointToPoint(0, theNode.pointee.OldCoord.x, theNode.pointee.OldCoord.z,
                                        theNode.pointee.Coord.x, theNode.pointee.Coord.z)
    player.pointee.Rot.y = r

    player.pointee.BaseTransformMatrix.setTranslate(theNode.pointee.Coord.x, theNode.pointee.Coord.y, theNode.pointee.Coord.z)
    var m = OGLMatrix4x4()
    m.setRotateY(r)
    var result = OGLMatrix4x4()
    result = m.multiplied(by: player.pointee.BaseTransformMatrix)
    player.pointee.BaseTransformMatrix = result

    theNode.pointee.OldCoord = theNode.pointee.Coord // remember coord also

    if (MyRandomLong() & 0xff) < 15 {
        let weapon = RandomRange(UInt16(WeaponType.blaster.rawValue), UInt16(WeaponType.bomb.rawValue))
        GetPlayerInfoEntry(0).pointee.currentWeapon = Int16(weapon)
        weaponQuantityBase(GetPlayerInfoEntry(0))[Int(weapon)] = 999
        PlayerFireButtonPressed(player, 1)
    }
}

@inline(__always) private func weaponQuantityBase(_ p: UnsafeMutablePointer<PlayerInfoType>) -> UnsafeMutablePointer<Int16> {
    UnsafeMutableRawPointer(p.pointer(to: \.weaponQuantity)!).assumingMemoryBound(to: Int16.self)
}

// MARK: -

// MARK: - Load/dispose font used throughout the game

func LoadGlobalAssets() {
    #if NANOSAUR_3DS
    Debug3DS_Log("LoadGlobalAssets: font atlases...")
    #endif
    LoadSpriteAtlas(Int32(ATLAS_GROUP_FONT1), ":Sprites:fonts:font", Int32(kAtlasLoadFont | kAtlasLoadFontIsUpperCaseOnly))
    LoadSpriteAtlas(Int32(ATLAS_GROUP_FONT2), ":Sprites:fonts:font", Int32(kAtlasLoadFont | kAtlasLoadFontIsUpperCaseOnly | kAtlasLoadAltSkin1))
    #if NANOSAUR_3DS
    Debug3DS_Log("LoadGlobalAssets: cursor...")
    #endif
    LoadSpriteGroupFromFile(Int32(SPRITE_GROUP_CURSOR), ":Sprites:menu:cursor", 0)
    #if NANOSAUR_3DS
    Debug3DS_Log("LoadGlobalAssets: infobar...")
    #endif
    LoadSpriteGroupFromSeries(Int32(SPRITE_GROUP_INFOBAR), Int32(INFOBAR_SObjType_COUNT), "infobar")
    #if NANOSAUR_3DS
    Debug3DS_Log("LoadGlobalAssets: global...")
    #endif
    LoadSpriteGroupFromSeries(Int32(SPRITE_GROUP_GLOBAL), Int32(GLOBAL_SObjType_COUNT), "global")
    #if NANOSAUR_3DS
    Debug3DS_Log("LoadGlobalAssets: spheremap...")
    #endif
    LoadSpriteGroupFromSeries(Int32(SPRITE_GROUP_SPHEREMAPS), Int32(SPHEREMAP_SObjType_COUNT), "spheremap")
    #if NANOSAUR_3DS
    Debug3DS_Log("LoadGlobalAssets: particle...")
    #endif
    LoadSpriteGroupFromSeries(Int32(SPRITE_GROUP_PARTICLES), Int32(PARTICLE_SObjType_COUNT), "particle")
    #if NANOSAUR_3DS
    Debug3DS_Log("LoadGlobalAssets: BlendAllSpritesInGroup(particles)...")
    #endif
    BlendAllSpritesInGroup(Int16(SPRITE_GROUP_PARTICLES))
    #if NANOSAUR_3DS
    Debug3DS_Log("LoadGlobalAssets: done.")
    #endif
}

func DisposeGlobalAssets() {
    DisposeSpriteAtlas(Int32(ATLAS_GROUP_FONT1))
    DisposeSpriteAtlas(Int32(ATLAS_GROUP_FONT2))
    DisposeSpriteGroup(Int32(SPRITE_GROUP_CURSOR))
    DisposeSpriteGroup(Int32(SPRITE_GROUP_INFOBAR))
    DisposeSpriteGroup(Int32(SPRITE_GROUP_GLOBAL))
    DisposeSpriteGroup(Int32(SPRITE_GROUP_SPHEREMAPS))
    DisposeSpriteGroup(Int32(SPRITE_GROUP_PARTICLES))
}

// MARK: -

// MARK: - Program main entry

@c @implementation
public func GameMain() {
    // BOOT STUFF

    #if NANOSAUR_3DS
    Debug3DS_Log("GameMain: ToolBoxInit...")
    #endif
    ToolBoxInit()

    #if !DEBUG
    SDL_HideCursor()
    #endif

    #if NANOSAUR_3DS
    Debug3DS_Log("GameMain: DoWarmUpScreen...")
    #endif
    DoWarmUpScreen()

    // INIT SOME OF MY STUFF

    #if NANOSAUR_3DS
    Debug3DS_Log("GameMain: LoadLocalizedStrings...")
    #endif
    LoadLocalizedStrings(GameLanguageID(rawValue: Int32(gGamePrefs.language)))
    #if NANOSAUR_3DS
    Debug3DS_Log("GameMain: InitSpriteManager...")
    #endif
    InitSpriteManager()
    #if NANOSAUR_3DS
    Debug3DS_Log("GameMain: InitBG3DManager...")
    #endif
    InitBG3DManager()
    #if NANOSAUR_3DS
    Debug3DS_Log("GameMain: InitWindowStuff...")
    #endif
    InitWindowStuff()
    #if NANOSAUR_3DS
    Debug3DS_Log("GameMain: InitTerrainManager...")
    #endif
    InitTerrainManager()
    #if NANOSAUR_3DS
    Debug3DS_Log("GameMain: InitSkeletonManager...")
    #endif
    InitSkeletonManager()
    #if NANOSAUR_3DS
    Debug3DS_Log("GameMain: InitSoundTools...")
    #endif
    InitSoundTools()
    #if NANOSAUR_3DS
    Debug3DS_Log("GameMain: InitTwitchSystem...")
    #endif
    InitTwitchSystem()

    // INIT MORE MY STUFF

    #if NANOSAUR_3DS
    Debug3DS_Log("GameMain: InitObjectManager...")
    #endif
    InitObjectManager()

    var someLong: UInt = 0
    SwGetDateTime(&someLong) // init random seed
    #if NANOSAUR_3DS
    "GameMain: SwGetDateTime done, someLong=\(someLong)".withCString { Debug3DS_Log($0) }
    #endif
    SetMyRandomSeed(UInt32(truncatingIfNeeded: someLong)) // matches original C's implicit truncation on cast
    #if NANOSAUR_3DS
    Debug3DS_Log("GameMain: SetMyRandomSeed done")
    #endif

    // PRELOAD SPRITES FOR ENTIRE GAME

    #if NANOSAUR_3DS
    Debug3DS_Log("GameMain: LoadGlobalAssets...")
    #endif
    LoadGlobalAssets()

    // SHOW TITLES
    // (SKIPFLUFF is hardcoded off in this build, so this block always runs.)

    #if NANOSAUR_3DS
    Debug3DS_Log("GameMain: DoLegalScreen...")
    #endif
    DoLegalScreen()

    #if NANOSAUR_3DS
    Debug3DS_Log("GameMain: DoIntroStoryScreen...")
    #endif
    DoIntroStoryScreen()

    // MAIN LOOP

    #if NANOSAUR_3DS
    Debug3DS_Log("GameMain: entering main loop / DoMainMenuScreen...")
    #endif
    while true {
        gTimeDemo = 0

        // DO MAIN MENU

        MyFlushEvents()
        DoMainMenuScreen()

        // PLAY ADVENTURE OR VS. MODE

        if gVSMode == .none {
            playGameAdventure()
        } else {
            if DoLocalGatherScreen() != 0 {
                gVSMode = .none
                gNumPlayers = 1
                continue
            }
            playGameVersus()
        }
    }
}

// MARK: - 3DS proof-of-concept entry point (credits scene only)
//
// Temporary alternate entry point for bringing up the 3DS port
// incrementally: skips warm-up/legal/intro-slideshow/main-menu/gameplay
// entirely and jumps straight to the "flying through the wormhole" credits
// scene (DoLevelIntroScreen(INTRO_MODE_CREDITS) - see LevelIntro.swift),
// looping it forever. No audio init (InitSoundTools/InitTwitchSystem)
// since Pomme's sound mixer is compiled out for this build
// (-DPOMME_NO_SOUND_MIXER) and this scene doesn't need it. No
// InitTerrainManager() either - unused by this scene. See
// ports/3DS/source/main.cpp, which calls this instead of GameMain() for
// this proof-of-concept build.
#if NANOSAUR_3DS
@c @implementation
public func GameMainCreditsPOC() {
    ToolBoxInit() // confirmed clean now (maxTexSize fix)

    LoadLocalizedStrings(GameLanguageID(rawValue: Int32(gGamePrefs.language)))
    InitSpriteManager()
    InitBG3DManager()
    InitWindowStuff()
    InitSkeletonManager()
    InitObjectManager()

    var someLong: UInt = 0
    SwGetDateTime(&someLong)
    SetMyRandomSeed(UInt32(truncatingIfNeeded: someLong))

    // NOT calling the real LoadGlobalAssets(): it also loads cursor/
    // infobar/global/spheremap sprite groups, none of which are in the
    // trimmed romfs-poc RomFS (only fonts + particles are) - a missing
    // file there was hanging boot the same way the maxTexSize bug did.
    // Load only what the credits scene actually needs.
    LoadSpriteAtlas(Int32(ATLAS_GROUP_FONT1), ":Sprites:fonts:font", Int32(kAtlasLoadFont | kAtlasLoadFontIsUpperCaseOnly))
    LoadSpriteAtlas(Int32(ATLAS_GROUP_FONT2), ":Sprites:fonts:font", Int32(kAtlasLoadFont | kAtlasLoadFontIsUpperCaseOnly | kAtlasLoadAltSkin1))
    LoadSpriteGroupFromSeries(Int32(SPRITE_GROUP_PARTICLES), Int32(PARTICLE_SObjType_COUNT), "particle")
    // NOTE: BlendAllSpritesInGroup(SPRITE_GROUP_PARTICLES) deliberately
    // skipped - bisected to be the trigger for a SwFatal("material == nil"
    // or "group is empty") that (like the maxTexSize/font-loading issues
    // above) manifests as an unrecoverable APT/GSP hang via the
    // message-box path. Only sets an always-blend flag on particle
    // sprite materials (used for gun-turret sparkle glow) - cosmetic,
    // not required for the credits scene to render correctly enough to
    // prove the pipeline works. Worth root-causing properly later.

    while true {
        DoLevelIntroScreen(UInt8(INTRO_MODE_CREDITS))
    }
}
#endif
