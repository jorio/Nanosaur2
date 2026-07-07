// Paused.swift - Port of Paused.c (menu trees + DoPaused/DoReallyQuit/OnExitPause)

var gGamePaused: UInt8 = 0

private let RESU_FOURCC: Int32 = 0x72657375
private let BAIL_FOURCC: Int32 = 0x6261696C
private let QUIT_FOURCC: Int32 = 0x71756974

// MARK: - Pause menu trees

private let cShouldDisplaySplitscreenModeCycler: @convention(c) (UnsafePointer<MenuItem>?) -> Int32 = { _ in
    gNumPlayers >= 2 ? 0 : Int32(kMILayoutFlagHidden | kMILayoutFlagDisabled)
}

private let cOnToggleSplitscreenMode: @convention(c) () -> Void = {
    gActiveSplitScreenMode = gGamePrefs.splitScreenMode
    PausedInternal_UpdateSplitscreenFOV()
}

private let gPauseMenuTreePtr: UnsafeMutablePointer<MenuItem> = makeMenuTreeBuffer([
    miRoot(fourCC("paus")),
    miPick(STR_RESUME, next: fourCC("EXIT"), id: fourCC("resu")),
    miSpacer(customHeight: 0.3, getLayoutFlags: cShouldDisplaySplitscreenModeCycler),
    miCycler1(STR_SPLITSCREEN_MODE, valuePtr: PausedInternal_GetSplitScreenModePtr(),
              choices: [
                (STR_SPLITSCREEN_HORIZ, UInt8(SplitscreenMode.horizontal.rawValue)),
                (STR_SPLITSCREEN_VERT,  UInt8(SplitscreenMode.vertical.rawValue)),
              ],
              callback: cOnToggleSplitscreenMode,
              getLayoutFlags: cShouldDisplaySplitscreenModeCycler),
    miPick(STR_SETTINGS, next: fourCC("sett")),
    miSpacer(customHeight: 0.3, getLayoutFlags: cShouldDisplaySplitscreenModeCycler),
    miPick(STR_RETIRE, next: fourCC("EXIT"), id: fourCC("bail")),
    miRoot(),
])

private let gReallyQuitMenuTreePtr: UnsafeMutablePointer<MenuItem> = makeMenuTreeBuffer([
    miRoot(fourCC("rlyq")),
    miLabel(STR_REALLY_QUIT, customHeight: 1),
    miSpacer(customHeight: 0.5),
    miPick(STR_RESUME, next: fourCC("EXIT"), id: fourCC("resu")),
    miPick(STR_QUIT,   next: fourCC("EXIT"), id: fourCC("quit")),
    miRoot(),
])

private var gMouseCursor: UnsafeMutablePointer<ObjNode>?

private let cOnExitPause: @convention(c) (Int32) -> Void = { outcome in
    SavePrefs() // save prefs in case user touched them

    gGamePaused = 0
    GrabMouse(1)
    PauseAllChannels(0)

    DeleteObject(gMouseCursor)
    gMouseCursor = nil

    InvalidateAllInputs()

    switch outcome {
    case RESU_FOURCC: // RESUME
        break
    case BAIL_FOURCC: // EXIT
        gGameViewInfoPtr!.pointee.fadeSound = 1
        gGameOver = 1
    case QUIT_FOURCC: // QUIT
        gGameViewInfoPtr!.pointee.fadeSound = 1
        CleanQuit()
    default:
        break
    }
}

@c @implementation
public func DoPaused() {
    // In single-player, reassign main controller to whoever pressed the start button
    if gVSMode == .none {
        let whoPressedStart = GetLastControllerForNeedAnyP(Int32(kNeed_UIPause))
        if whoPressedStart >= 0 {
            SetMainController(whoPressedStart)
        }
    }

    gGammaFadeFrac = 1
    gGamePaused = 1
    GrabMouse(0)
    PauseAllChannels(1)

    gMouseCursor = MakeMouseCursorObject()

    var style = kDefaultMenuStyle
    style.canBackOutOfRootMenu = true
    style.darkenPaneOpacity = 0.5
    style.startButtonExits = true
    style.exitCall = cOnExitPause
    MakeMenu(gPauseMenuTreePtr, &style)
    RegisterSettingsMenu()
}

@c @implementation
public func DoReallyQuit() {
    gGammaFadeFrac = 1
    gGamePaused = 1
    GrabMouse(0)
    PauseAllChannels(1)

    gMouseCursor = MakeMouseCursorObject()

    var style = kDefaultMenuStyle
    style.canBackOutOfRootMenu = true
    style.darkenPaneOpacity = 0.5
    style.startButtonExits = true
    style.exitCall = cOnExitPause
    MakeMenu(gReallyQuitMenuTreePtr, &style)
    RegisterSettingsMenu()
}
