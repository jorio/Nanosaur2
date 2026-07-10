// Main.swift - Port of Main.c to Swift
//
// gGamePrefs is the only global left in Main.c: Boot.cpp reads/writes
// gGamePrefs.antialiasingLevel directly, so PrefsType must stay a
// C-visible extern global. Every other global that used to live in
// Main.c (gEngine.game.viewInfoPtr, gEngine.game.levelNum, gEngine.game.debugMode, gEngine.game.autoFadeStatusBits,
// gEngine.game.timeDemo, gEngine.game.gameOver, gEngine.game.levelCompleted, gEngine.game.playingFromSavedGame,
// gEngine.game.skipLevelIntro, gEngine.game.raceReadySetGoTimer, gEngine.game.prefsFolderVRefNum/DirID,
// gEngine.game.worldSunDirection, gBestCheckpointNum/Coord/Aim, gEngine.game.vsMode) is native
// Swift storage now (converted 2026-07-07): nothing in any .c file
// touches them anymore. gBestCheckpointNum/Coord/Aim were exposed via
// Get*/Set* shims in PlayerInternal.h; those are now plain Swift
// functions with the same names/signatures.
//
// gEngine.game.timeDemoStartTime/EndTime, gEngine.game.levelTimer, gEngine.game.levelCompletedCoolDownTimer,
// gEngine.game.fillColor1, and gLevelSongs have no `extern` declaration anywhere and
// are only ever touched from this file, so they stay private Swift
// storage.

/// Top-level game/session state. Owned by GameEngine as `gEngine.game`.
final class GameState {
    var vsMode: VSMode = .none // nano vs. nano mode

    var viewInfoPtr: UnsafeMutablePointer<OGLSetupOutputType>!
    var frameNum: UInt32 = 0
    var levelNum: Int16 = 0
    var debugMode: UInt8 = 0
    var autoFadeStatusBits: UInt32 = 0
    var timeDemo: UInt8 = 0
    var gameOver: UInt8 = 0
    var levelCompleted: UInt8 = 0
    var playingFromSavedGame: UInt8 = 0
    var skipLevelIntro: UInt8 = 0
    var raceReadySetGoTimer: Float = 0
    var prefsFolderVRefNum: Int16 = 0
    var prefsFolderDirID: Int = 0
    var worldSunDirection = OGLVector3D()

    fileprivate var bestCheckpointNum: [Int16] = Array(repeating: 0, count: Int(MAX_PLAYERS))
    fileprivate var bestCheckpointCoord: [OGLPoint3D] = Array(repeating: OGLPoint3D(), count: Int(MAX_PLAYERS))
    fileprivate var bestCheckpointAim: [Float] = Array(repeating: 0, count: Int(MAX_PLAYERS))

    fileprivate var timeDemoStartTime: UInt32 = 0
    fileprivate var timeDemoEndTime: UInt32 = 0
    fileprivate var levelTimer: Float = 0
    fileprivate var levelCompletedCoolDownTimer: Float = 0
    fileprivate var fillColor1 = OGLColorRGBA(r: 0.8, g: 0.8, b: 0.7, a: 1)
}



func GetBestCheckpointNum(_ i: Int32) -> Int16 { gEngine.game.bestCheckpointNum[Int(i)] }
func SetBestCheckpointNum(_ i: Int32, _ v: Int16) { gEngine.game.bestCheckpointNum[Int(i)] = v }
func GetBestCheckpointCoord(_ i: Int32) -> OGLPoint3D { gEngine.game.bestCheckpointCoord[Int(i)] }
func SetBestCheckpointCoord(_ i: Int32, _ v: OGLPoint3D) { gEngine.game.bestCheckpointCoord[Int(i)] = v }
func GetBestCheckpointAim(_ i: Int32) -> Float { gEngine.game.bestCheckpointAim[Int(i)] }
func SetBestCheckpointAim(_ i: Int32, _ v: Float) { gEngine.game.bestCheckpointAim[Int(i)] = v }


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

    gGamePrefs.isLowRenderQuality = false
    gGamePrefs.splitScreenMode = UInt8(SplitscreenMode.vertical.rawValue)
    gGamePrefs.stereoGlassesMode = UInt8(StereoGlassesMode.off.rawValue)
    gGamePrefs.anaglyphCalibrationRed = UInt8(DEFAULT_ANAGLYPH_R)
    gGamePrefs.anaglyphCalibrationGreen = UInt8(DEFAULT_ANAGLYPH_G)
    gGamePrefs.anaglyphCalibrationBlue = UInt8(DEFAULT_ANAGLYPH_B)
    gGamePrefs.doAnaglyphChannelBalancing = 1

    gGamePrefs.showTargetingCrosshairs = 1
    gGamePrefs.isKiddieMode = false

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

    while gEngine.game.levelNum <= Int16(LevelNum.adventure3.rawValue) {
        // DO LEVEL INTRO

        PlaySong(gLevelSongs[Int(gEngine.game.levelNum)], 1)

        if gEngine.game.skipLevelIntro == 0 {
            if (gEngine.game.levelNum == 0) || gEngine.game.playingFromSavedGame != 0 {
                DoLevelIntroScreen(UInt8(INTRO_MODE_NOSAVE))
            } else {
                DoLevelIntroScreen(UInt8(INTRO_MODE_SAVEGAME))
            }
        }
        gEngine.game.skipLevelIntro = 0 // reset skip flag

        MyFlushEvents()

        // LOAD ALL OF THE ART & STUFF

        initLevel()

        // PLAY IT

        playLevel()

        gEngine.game.playingFromSavedGame = 0 // once we've completed a level after restoring, we're not really playing from a saved game anymore

        // CLEANUP LEVEL

        MyFlushEvents()
        cleanupLevel()

        // SEE IF LOST

        if gEngine.game.gameOver != 0 { // bail out if game has ended
            break
        }

        // DO END-LEVEL BONUS SCREEN

        if gEngine.game.levelNum == Int16(LevelNum.adventure3.rawValue) { // if just won game then do win screen first!
            DoWinScreen()
        }

        gEngine.game.levelNum += 1
    }

    gEngine.game.playingFromSavedGame = 0
}

// MARK: - Play game: versus

// Play one of the 2-player versus modes.
private func playGameVersus() {
    // GAME INITIALIZATION

    InitPlayerInfo_Game() // init player info for entire game

    // DO LEVEL INTRO

    PlaySong(gLevelSongs[Int(gEngine.game.levelNum)], 1)

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
    if gEngine.game.timeDemo != 0 { // if time demo always reset random seed
        SetMyRandomSeed(0)
    }

    // INIT COMMON STUFF

    gEngine.game.frameNum = 0
    gEngine.game.levelTimer = 0
    gEngine.game.gameOver = 0
    gEngine.game.levelCompleted = 0

    for i in 0..<Int(gEngine.player.numPlayers) {
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
    viewDef.camera.yon = (Float(gEngine.terrain.superTileActiveRange) * Float(SUPERTILE_SIZE) * gEngine.terrain.polygonSize) * 0.95

    switch Int16(gEngine.game.levelNum) {
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
        gEngine.game.worldSunDirection.x = 0.4
        gEngine.game.worldSunDirection.y = -0.3
        gEngine.game.worldSunDirection.z = 0.2
        gEngine.game.fillColor1.r = 0.6
        gEngine.game.fillColor1.g = 0.6
        gEngine.game.fillColor1.b = 0.6
        gEngine.camera.drawLensFlare = 1

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
        gEngine.game.worldSunDirection.x = 0.4
        gEngine.game.worldSunDirection.y = -0.3
        gEngine.game.worldSunDirection.z = 0.2
        gEngine.game.fillColor1.r = 0.6
        gEngine.game.fillColor1.g = 0.6
        gEngine.game.fillColor1.b = 0.6
        gEngine.camera.drawLensFlare = 1

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
        gEngine.game.worldSunDirection.x = 0.4
        gEngine.game.worldSunDirection.y = -0.5
        gEngine.game.worldSunDirection.z = 0.5
        gEngine.game.fillColor1.r = 0.7
        gEngine.game.fillColor1.g = 0.7
        gEngine.game.fillColor1.b = 0.7
        gEngine.camera.drawLensFlare = 1
    }

    // SET LIGHTS

    viewDef.lights.numFillLights = 1
    gEngine.game.worldSunDirection = gEngine.game.worldSunDirection.normalized()
    viewDef.lights.fillDirection.0 = gEngine.game.worldSunDirection
    viewDef.lights.fillColor.0 = gEngine.game.fillColor1

    // SET ANAGLYPH INFO

    if isStereo() {
        gEngine.view.anaglyphFocallength = 200.0
        gEngine.view.anaglyphEyeSeparation = 35.0

        if isStereoAnaglyphMono() {
            viewDef.lights.ambientColor.r += 0.1 // make a little brighter
            viewDef.lights.ambientColor.g += 0.1
            viewDef.lights.ambientColor.b += 0.1
        }
    }

    // MAKE DRAW CONTEXT

    OGL_SetupGameView(&viewDef)

    // SET AUTO-FADE INFO

    gEngine.objects.autoFadeStartDist = gEngine.game.viewInfoPtr!.pointee.yon * 0.80
    gEngine.objects.autoFadeEndDist = gEngine.game.viewInfoPtr!.pointee.yon * 0.9

    gEngine.objects.autoFadeRangeFrac = 1.0 / (gEngine.objects.autoFadeEndDist - gEngine.objects.autoFadeStartDist)

    if gEngine.objects.autoFadeStartDist != 0.0 {
        gEngine.game.autoFadeStatusBits = UInt32(STATUS_BIT_AUTOFADE)
    } else {
        gEngine.game.autoFadeStatusBits = 0
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

    if gEngine.game.vsMode == .race {
        gEngine.game.raceReadySetGoTimer = 3.0
    }

    // INIT THE PLAYER & RELATED STUFF

    PrimeTerrainWater() // NOTE:  must do this before items get added since some items may be on the water
    InitPlayerAtStartOfLevel() // NOTE:  this will also cause the initial items in the start area to be created

    PrimeSplines()
    PrimeFences()

    // INIT CAMERAS

    for i in 0..<Int(gEngine.player.numPlayers) {
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

    if gEngine.game.timeDemo != 0 {
        gEngine.game.timeDemoStartTime = SwTickCount()
    }

    GrabMouse(1)

    // MAIN GAME LOOP

    while true {
        // INPUT

        DoSDLMaintenance()

        if gEngine.screens.gamePaused != 0 {
            MoveObjects()
            CalcFramesPerSecond()
            DoPlayerTerrainUpdate()
            OGL_DrawScene(cDrawLevelCallback)
            continue
        }

        for i in 0..<Int(gEngine.player.numPlayers) {
            UpdatePlayerSteering(Int32(i))
        }

        // MOVE OBJECTS & UPDATE TERRAIN & DRAW

        MoveEverything()
        DoPlayerTerrainUpdate()
        OGL_DrawScene(cDrawLevelCallback)

        // UPDATE FPS AND TIMERS

        CalcFramesPerSecond()
        let fps = gEngine.framesPerSecondFrac

        gEngine.game.frameNum += 1
        gEngine.game.levelTimer += fps
        gEngine.terrain.disableHiccupTimer = 0 // reenable this after the 1st frame

        // SEE IF RESET PLAYER NOW

        for i in 0..<Int(gEngine.player.numPlayers) { // check all players
            if GetPlayerIsDead(Int32(i)) != 0 { // is this player dead?
                let oldTimer = GetDeathTimer(Int32(i))
                var deathTimer = oldTimer - fps
                SetDeathTimer(Int32(i), deathTimer)
                if deathTimer <= 0.0 { // is it time to reincarnate player?
                    let fadeOutSpeed: Float = 4.0

                    if oldTimer > 0.0 { // if just now crossed zero then start fade
                        if gEngine.player.numPlayers > 1
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
            gEngine.game.levelCompleted = 1
        }

        // SEE IF LEVEL IS COMPLETED

        if gEngine.game.gameOver != 0 { // if we need immediate abort, then bail now
            break
        }

        if gEngine.game.levelCompleted != 0 {
            gEngine.game.levelCompletedCoolDownTimer -= fps // game is done, but wait for cool-down timer before bailing
            if gEngine.game.levelCompletedCoolDownTimer <= 0.0 {
                break
            }
        }
    }

    GrabMouse(0)

    if gEngine.window.gammaFadeFrac > 0 { // only fade out if we haven't called MakeFadeEvent(kFadeFlags_Out) already
        gEngine.game.viewInfoPtr!.fadeSound = true
        OGL_FadeOutScene(cDrawLevelCallback, cUpdateTerrainForFadeOut)
    }

    if gEngine.game.timeDemo != 0 {
        gEngine.game.timeDemoEndTime = SwTickCount()
        let ticks = gEngine.game.timeDemoEndTime - gEngine.game.timeDemoStartTime
        let seconds = Float(ticks) / 60.0

        showTimeDemoResults(Int32(gEngine.game.frameNum), seconds, Float(gEngine.game.frameNum) / seconds)

        SwExitToShell()
    }
}

// MARK: - Show time demo results

private func showTimeDemoResults(_ numFrames: Int32, _ numSeconds: Float, _ averageFPS: Float) {
    SwAlert("showTimeDemoResults:\nFrames: \(numFrames)\nTime: \(numSeconds)\nAverage FPS: \(averageFPS)\nPeak #Objs: \(gEngine.objects.numObjectNodesPeak)")
}

// MARK: - Draw level callback

private let cDrawLevelCallback: @convention(c) () -> Void = {
    if isStereo() {
        let p = Int(gEngine.view.currentSplitScreenPane) // get the player # who's draw context is being drawn

        // MAKE SURE ANAGLYPH SETTINGS ARE GOOD FOR THIS CAMERA MODE

        switch GetCameraMode(Int32(p)) {
        case UInt8(CameraMode.normal.rawValue):
            if isStereoShutter() {
                gEngine.view.anaglyphFocallength = 280.0
                gEngine.view.anaglyphEyeSeparation = 45.0
            } else {
                gEngine.view.anaglyphFocallength = 260.0
                gEngine.view.anaglyphEyeSeparation = 35.0
            }

        case UInt8(CameraMode.firstPerson.rawValue):
            gEngine.view.anaglyphFocallength = 300.0
            gEngine.view.anaglyphEyeSeparation = 80.0

        case UInt8(CameraMode.anaglyphClose.rawValue):
            gEngine.view.anaglyphFocallength = 700.0
            gEngine.view.anaglyphEyeSeparation = 50.0

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

    gEngine.game.vsMode = .none
    gEngine.player.numPlayers = 1
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

    switch gEngine.game.vsMode {
    // ADVENTURE MODE
    case .none:
        break

    // RACE MODE
    case .race:
        gEngine.game.raceReadySetGoTimer -= gEngine.framesPerSecondFrac
        CalcPlayerPlaces() // determinw who is in what place

    default:
        break
    }
}

// MARK: - Start level completion

func StartLevelCompletion(_ coolDownTimer: Float) {
    if gEngine.game.levelCompleted == 0 {
        gEngine.game.levelCompleted = 1
        gEngine.game.levelCompletedCoolDownTimer = coolDownTimer
    }
}

// MARK: -

// MARK: - Prime time demo spline

func PrimeTimeDemoSpline(_ splineNum: Int, _ itemPtr: UnsafeMutablePointer<SplineItemType>!) -> UInt8 {
    if gEngine.game.timeDemo == 0 { // are we in time demo mode?
        return 0
    }

    // GET SPLINE INFO

    let placement = itemPtr.pointee.placement
    var x: Float = 0
    var z: Float = 0
    GetCoordOnSpline(gEngine.splines.splineList + splineNum, placement, &x, &z)

    // MAKE DUMMY SPLINE TRACKER OBJECT

    var def = NewObjectDefinitionType()
    def.genre = UInt8(CUSTOM_GENRE)
    def.slot = 0
    def.moveCall = nil
    def.flags = 0
    def.scale = 1

    let newObj = MakeNewObject(&def)!

    // SET SPLINE INFO

    newObj.setStatus(STATUS_BIT_ONSPLINE)
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
        gEngine.game.gameOver = 1
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
    LoadSpriteAtlas(Int32(ATLAS_GROUP_FONT1), ":Sprites:fonts:font", Int32(kAtlasLoadFont | kAtlasLoadFontIsUpperCaseOnly))
    LoadSpriteAtlas(Int32(ATLAS_GROUP_FONT2), ":Sprites:fonts:font", Int32(kAtlasLoadFont | kAtlasLoadFontIsUpperCaseOnly | kAtlasLoadAltSkin1))
    LoadSpriteGroupFromFile(Int32(SPRITE_GROUP_CURSOR), ":Sprites:menu:cursor", 0)
    LoadSpriteGroupFromSeries(Int32(SPRITE_GROUP_INFOBAR), Int32(INFOBAR_SObjType_COUNT), "infobar")
    LoadSpriteGroupFromSeries(Int32(SPRITE_GROUP_GLOBAL), Int32(GLOBAL_SObjType_COUNT), "global")
    LoadSpriteGroupFromSeries(Int32(SPRITE_GROUP_SPHEREMAPS), Int32(SPHEREMAP_SObjType_COUNT), "spheremap")
    LoadSpriteGroupFromSeries(Int32(SPRITE_GROUP_PARTICLES), Int32(PARTICLE_SObjType_COUNT), "particle")
    BlendAllSpritesInGroup(Int16(SPRITE_GROUP_PARTICLES))
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

    ToolBoxInit()

    #if !DEBUG
    SDL_HideCursor()
    #endif

    DoWarmUpScreen()

    // INIT SOME OF MY STUFF

    LoadLocalizedStrings(GameLanguageID(rawValue: Int32(gGamePrefs.language)))
    InitSpriteManager()
    InitBG3DManager()
    InitWindowStuff()
    InitTerrainManager()
    InitSkeletonManager()
    InitSoundTools()
    InitTwitchSystem()

    // INIT MORE MY STUFF

    InitObjectManager()

    var someLong: UInt = 0
    SwGetDateTime(&someLong) // init random seed
    SetMyRandomSeed(UInt32(truncatingIfNeeded: someLong)) // matches original C's implicit truncation on cast

    // PRELOAD SPRITES FOR ENTIRE GAME

    LoadGlobalAssets()

    // SHOW TITLES
    // (SKIPFLUFF is hardcoded off in this build, so this block always runs.)

    DoLegalScreen()

    DoIntroStoryScreen()

    // MAIN LOOP

    while true {
        gEngine.game.timeDemo = 0

        // DO MAIN MENU

        MyFlushEvents()
        DoMainMenuScreen()

        // PLAY ADVENTURE OR VS. MODE

        if gEngine.game.vsMode == .none {
            playGameAdventure()
        } else {
            if DoLocalGatherScreen() != 0 {
                gEngine.game.vsMode = .none
                gEngine.player.numPlayers = 1
                continue
            }
            playGameVersus()
        }
    }
}
