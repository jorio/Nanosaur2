// Paused.swift - Port of Paused.c to Swift (DoPaused/DoReallyQuit/OnExitPause)
// The menu tree data tables stay in Paused.c; see PausedInternal.h.

private let RESU_FOURCC: Int32 = 0x72657375
private let BAIL_FOURCC: Int32 = 0x6261696C
private let QUIT_FOURCC: Int32 = 0x71756974

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
    if gVSMode == Int16(VS_MODE_NONE) {
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
    MakeMenu(GetPauseMenuTree(), &style)
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
    MakeMenu(GetReallyQuitMenuTree(), &style)
    RegisterSettingsMenu()
}
