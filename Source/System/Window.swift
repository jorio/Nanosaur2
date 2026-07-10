// Window.swift - Port of Window.c to Swift
//
// gEngine.window.gammaFadeFrac/gEngine.window.width/gEngine.window.height are native Swift
// storage now (converted 2026-07-07): nothing in any .c file touches them
// anymore.

/// Window/fade state. Owned by GameEngine as `gEngine.window`.
final class WindowSystem {
    var gammaFadeFrac: Float = 1.0
    var width: Int32 = 640
    var height: Int32 = 480
}

private let kFaderMode_FadeOut: Int32 = 0
private let kFaderMode_FadeIn: Int32 = 1
private let kFaderMode_Done: Int32 = 2

func InitWindowStuff() {
    gEngine.window.width = 640
    gEngine.window.height = 480
}

private func isFadePaneMoveCall(_ moveCall: (@convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void)?) -> Bool {
    guard let moveCall else { return false }
    return unsafeBitCast(moveCall, to: UnsafeRawPointer.self) == unsafeBitCast(cMoveFadePane, to: UnsafeRawPointer.self)
}

private let cMoveFadePane: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNode in
    guard let theNode else { return }
    let fps = gEngine.framesPerSecondFrac
    let speed = theNode.pointee.Speed * fps

    // SEE IF FADE IN
    if theNode.pointee.Mode == kFaderMode_FadeIn {
        gEngine.window.gammaFadeFrac += speed
        if gEngine.window.gammaFadeFrac >= 1.0 { // see if @ 100%
            gEngine.window.gammaFadeFrac = 1
            theNode.pointee.Mode = kFaderMode_Done
            DeleteObject(theNode) // nuke it if fading in
        }
    }

    // FADE OUT
    else if theNode.pointee.Mode == kFaderMode_FadeOut {
        gEngine.window.gammaFadeFrac -= speed
        if gEngine.window.gammaFadeFrac <= 0.0 { // see if @ 0%
            gEngine.window.gammaFadeFrac = 0
            theNode.pointee.Mode = kFaderMode_Done
            theNode.setStatus(STATUS_BIT_NOMOVE) // DON'T nuke the fader pane if fading out -- but don't run this again
        }
    }

    if gEngine.game.viewInfoPtr!.fadeSound {
        FadeSound(gEngine.window.gammaFadeFrac)
    }
}

private let cDrawFadePane: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { _ in
    OGL_PushState()
    SetInfobarSpriteState(0, 1)

    OGL_DisableTexture2D()

    OGL_EnableBlend()
    OGL_SetColor4f(0, 0, 0, 1.0 - gEngine.window.gammaFadeFrac)

    gEngine.renderer.beginImmediate(.quads)
    gEngine.renderer.vertex3f(gLogicalRect.right, gLogicalRect.top, 0)
    gEngine.renderer.vertex3f(gLogicalRect.left, gLogicalRect.top, 0)
    gEngine.renderer.vertex3f(gLogicalRect.left, gLogicalRect.bottom, 0)
    gEngine.renderer.vertex3f(gLogicalRect.right, gLogicalRect.bottom, 0)
    gEngine.renderer.endImmediate()

    OGL_PopState()
}

func OGL_FadeOutScene(_ drawCall: (@convention(c) () -> Void)!, _ moveCall: (@convention(c) () -> Void)!) {
    let fader = MakeFadeEvent(UInt8(kFadeFlags_Out), 3.0)!

    var pFaderFrameCount = fader.pointee.Special.0

    while fader.pointee.Mode != kFaderMode_Done {
        CalcFramesPerSecond()
        DoSDLMaintenance()

        if let moveCall {
            moveCall()
        }

        // Force fader object to move even if MoveObjects was skipped
        if fader.pointee.Special.0 == pFaderFrameCount { // fader wasn't moved by moveCall
            cMoveFadePane(fader)
            pFaderFrameCount = fader.pointee.Special.0
        }

        OGL_DrawScene(drawCall)
    }

    // Draw one more blank frame
    gEngine.window.gammaFadeFrac = 0
    CalcFramesPerSecond()
    DoSDLMaintenance()
    OGL_DrawScene(drawCall)

    if gEngine.game.viewInfoPtr!.fadeSound {
        FadeSound(0)
        KillSong()
        StopAllEffectChannels()
        FadeSound(1) // restore sound volume for new playback
    }
}

func MakeFadeEvent(_ fadeFlags: UInt8, _ fadeSpeed: Float) -> UnsafeMutablePointer<ObjNode>? {
    var newObj: UnsafeMutablePointer<ObjNode>?
    let fadeIn = fadeFlags & UInt8(kFadeFlags_In) != 0

    // SCAN FOR OLD FADE EVENTS STILL IN LIST
    newObj = allObjectNodes.first { isFadePaneMoveCall($0.pointee.MoveCall) }

    if let existing = newObj {
        // RECYCLE OLD FADE EVENT
        existing.pointee.StatusBits = UInt32(STATUS_BIT_DONTCULL) // reset status bits in case NOMOVE was set
    } else {
        // MAKE NEW FADE EVENT
        var def = NewObjectDefinitionType()
        def.genre = UInt8(CUSTOM_GENRE)
        def.flags = UInt32(STATUS_BIT_DONTCULL)
        def.slot = Int16(FADEPANE_SLOT)
        def.moveCall = cMoveFadePane
        def.drawCall = cDrawFadePane
        def.scale = 1

        newObj = MakeNewObject(&def)
    }

    let obj = newObj!

    gEngine.window.gammaFadeFrac = fadeIn ? 0 : 1

    obj.pointee.Mode = fadeIn ? kFaderMode_FadeIn : kFaderMode_FadeOut
    obj.pointee.Special.0 = 0 // FaderFrameCounter == Special[0]
    obj.pointee.Speed = fadeSpeed

    if fadeFlags & UInt8(kFadeFlags_P1) != 0 {
        obj.setStatus(STATUS_BIT_ONLYSHOWTHISPLAYER)
        obj.pointee.PlayerNum = 0
    } else if fadeFlags & UInt8(kFadeFlags_P2) != 0 {
        obj.setStatus(STATUS_BIT_ONLYSHOWTHISPLAYER)
        obj.pointee.PlayerNum = 1
    } else {
        obj.sendToOverlayPane()
    }

    return obj
}

// For OS X - turn off DSp when showing 2D
@c @implementation
public func Enter2D() {
    GrabMouse(0)
    SDL_ShowCursor()
    MyFlushEvents()
}

// For OS X - turn ON DSp when NOT 2D
@c @implementation
public func Exit2D() {
    SDL_HideCursor()
}

func GetDefaultWindowSize(_ display: SDL_DisplayID, _ width: UnsafeMutablePointer<Int32>!, _ height: UnsafeMutablePointer<Int32>!) {
    let aspectRatio: Float = 16.0 / 10.0
    let screenCoverage: Float = 0.8

    var displayBounds = SDL_Rect(x: 0, y: 0, w: 640, h: 480)
    _ = SDL_GetDisplayUsableBounds(display, &displayBounds)

    if displayBounds.w > displayBounds.h {
        width.pointee = Int32(Float(displayBounds.h) * screenCoverage * aspectRatio)
        height.pointee = Int32(Float(displayBounds.h) * screenCoverage)
    } else {
        width.pointee = Int32(Float(displayBounds.w) * screenCoverage)
        height.pointee = Int32(Float(displayBounds.w) * screenCoverage / aspectRatio)
    }
}

func GetNumDisplays() -> Int32 {
    var numDisplays: Int32 = 0
    let displays = SDL_GetDisplays(&numDisplays)
    SDL_free(displays)
    return numDisplays
}

// GamePrefs.displayNum records an index into the array returned by
// SDL_GetDisplays(), not the actual SDL_DisplayID itself.
private func getPreferredSDLDisplayID() -> SDL_DisplayID {
    var numDisplays: Int32 = 0
    let displays = SDL_GetDisplays(&numDisplays)
    var prefDisplay: SDL_DisplayID = 0

    if Int32(gGamePrefs.displayNum) < numDisplays {
        prefDisplay = displays![Int(gGamePrefs.displayNum)]
    } else {
        gGamePrefs.displayNum = 0
    }

    SDL_free(displays)
    return prefDisplay
}

// This works best in windowed mode.
// Turn off fullscreen before calling this!
private func moveToPreferredDisplay() {
    let display = getPreferredSDLDisplayID()

    var w: Int32 = 640
    var h: Int32 = 480
    GetDefaultWindowSize(display, &w, &h)
    _ = SDL_SetWindowSize(gSDLWindow, w, h)
    _ = SDL_SyncWindow(gSDLWindow)

    let centered = Int32(bitPattern: SDL_WINDOWPOS_CENTERED_MASK | display)
    _ = SDL_SetWindowPosition(gSDLWindow, centered, centered)
    _ = SDL_SyncWindow(gSDLWindow)
}

func SetFullscreenMode(_ enforceDisplayPref: Bool) {
    if gGamePrefs.fullscreen == 0 {
        _ = SDL_SetWindowFullscreen(gSDLWindow, false)
        _ = SDL_SyncWindow(gSDLWindow)

        if enforceDisplayPref {
            moveToPreferredDisplay()
        }
    } else {
        if enforceDisplayPref {
            let currentDisplay = SDL_GetDisplayForWindow(gSDLWindow)
            let desiredDisplay = getPreferredSDLDisplayID()

            if currentDisplay != desiredDisplay {
                // We must switch back to windowed mode for the preferred monitor to take effect
                _ = SDL_SetWindowFullscreen(gSDLWindow, false)
                _ = SDL_SyncWindow(gSDLWindow)
                moveToPreferredDisplay()
            }
        }

        // Enter fullscreen mode
        _ = SDL_SetWindowFullscreen(gSDLWindow, true)
        _ = SDL_SyncWindow(gSDLWindow)
    }

    gEngine.renderer.setVSync(Int32(gGamePrefs.vsync))
}
