// SaverGlue.swift - the engine-side entry points for the macOS screen
// saver (ports/Darwin). Compiled INTO the engine's Swift module (so it can
// touch gEngine and every engine function directly) and exported as plain
// C symbols, because the ScreenSaverView host lives in a separate Swift
// module: it must `import ScreenSaver`/AppKit, which cannot coexist with
// the game's bridging header (SwMacTypes.h collides with Darwin.MacTypes -
// the same reason MetalRenderer is its own module, see
// docs/metal-renderer-plan.md).
//
// RENDERING IS METAL, not GL: the host view is backed by a plain
// CAMetalLayer, and boot swaps gEngine.renderer to a MetalRenderBackend
// driving the game's own MetalRenderer module against that layer - the
// same "known working" path as the desktop game's --metal mode
// (MetalActivation.swift), minus SDL: the host passes the CAMetalLayer
// pointer straight in. The GL path (NSOpenGLContext/NSOpenGLLayer) was
// tried first and rendered black in legacyScreenSaver's layer-backed
// windows; CAMetalLayer composites natively there.
//
// Layer handoff: the system can create several saver views in one process
// (System Settings' inline thumbnail vs. its full-screen preview, one view
// per display). MetalRenderer binds to ONE CAMetalLayer at construction,
// and its texture handles live in that instance - so switching views
// means rebuilding the renderer AND every texture: AttachLayer tears down
// the scene + the boot-time texture groups (font, particles), builds a
// fresh MetalRenderer on the new layer, and reloads. The host decides
// when to hand off (see Nanosaur2SaverView.claimEngine).

#if NANOSAUR_SCREENSAVER

import MetalRenderer

/// Retained for the life of the process (rebuilt on AttachLayer).
private var gSaverRenderer: MetalRenderer?
private var gSceneUp = false
private var gManagersInited = false
private var gDrawableSize = (width: Int32(0), height: Int32(0))

// MARK: - Renderer (re)binding

private func bindRenderer(toLayer layerPointer: UnsafeMutableRawPointer, _ pixelWidth: Int32, _ pixelHeight: Int32) -> Bool {
    guard let renderer = MetalRenderer(layerPointer: layerPointer) else {
        SwLog("Saver: MetalRenderer init failed (no Metal device?)")
        return false
    }
    renderer.setDrawableSize(width: Int(pixelWidth), height: Int(pixelHeight))
    gDrawableSize = (pixelWidth, pixelHeight)
    gSaverRenderer = renderer
    gEngine.renderer = MetalRenderBackend(renderer: renderer)
    SwLog("Saver: Metal active on '\(renderer.deviceName)' (\(pixelWidth)x\(pixelHeight))")
    return true
}

// The texture groups loaded at boot rather than per-scene. Their GPU
// textures live in the current MetalRenderer instance, so they must be
// reloaded whenever the renderer is rebuilt on a new layer.
private func loadGlobalTextureGroups() {
    LoadSpriteAtlas(Int32(ATLAS_GROUP_FONT1), ":Sprites:fonts:font", Int32(kAtlasLoadFont | kAtlasLoadFontIsUpperCaseOnly))
    LoadSpriteGroupFromSeries(Int32(SPRITE_GROUP_PARTICLES), Int32(PARTICLE_SObjType_COUNT), "particle")
    BlendAllSpritesInGroup(Int16(SPRITE_GROUP_PARTICLES))
}

private func disposeGlobalTextureGroups() {
    DisposeSpriteAtlas(Int32(ATLAS_GROUP_FONT1))
    DisposeSpriteGroup(Int32(SPRITE_GROUP_PARTICLES))
}

// MARK: - Boot (once per process)

@_cdecl("Nanosaur2Saver_Boot")
public func Nanosaur2Saver_Boot(
    _ dataPathC: UnsafePointer<CChar>,
    _ metalLayer: UnsafeMutableRawPointer,
    _ pixelWidth: Int32,
    _ pixelHeight: Int32) -> Bool
{
    if gManagersInited {
        // Already booted (defensive - the host guards this too): treat as
        // a plain layer handoff.
        return Nanosaur2Saver_AttachLayer(metalLayer, pixelWidth, pixelHeight)
    }

    // POINT THE ENGINE'S FILE LAYER AT THE BUNDLE'S Data FOLDER
    // (mirrors Boot.cpp's FindGameData: gDataSpec's parID is Data/ itself,
    // so ":Sprites:menu:nanologo"-style paths resolve relative to Data/)

    let dataPath = String(cString: dataPathC)
    gDataSpec = SwHostPathToFSSpec(dataPath + "/System")

    // MINIMAL PREFS (no prefs file in the saver - defaults only; the
    // parts of InitDefaultPrefs (Main.swift) the compiled subset reads)

    withUnsafeMutableBytes(of: &gGamePrefs) { raw in
        raw.initializeMemory(as: UInt8.self, repeating: 0)
    }
    gGamePrefs.stereoGlassesMode = UInt8(StereoGlassesMode.off.rawValue)
    gGamePrefs.language = UInt8(LANGUAGE_ENGLISH.rawValue)
    gGamePrefs.hudScale = 100

    // BRING UP THE METAL BACKEND ON THE HOST'S LAYER, THEN BOOT THE
    // RENDER PATH (OGL_Boot -> OGL_CreateDrawContext -> createContext,
    // which is a no-op on MetalRenderBackend - it's constructed active)

    guard bindRenderer(toLayer: metalLayer, pixelWidth, pixelHeight) else {
        return false
    }

    OGL_Boot()

    // ENGINE MANAGERS + THE FEW GLOBAL ASSETS THIS SCENE NEEDS
    // (the trimmed recipe proven by GameMainCreditsPOC, Main.swift)

    LoadLocalizedStrings(LANGUAGE_ENGLISH)
    InitSpriteManager()
    InitBG3DManager()
    InitWindowStuff()
    InitSkeletonManager()
    InitObjectManager()

    var someLong: UInt = 0
    SwGetDateTime(&someLong)
    SetMyRandomSeed(UInt32(truncatingIfNeeded: someLong))

    loadGlobalTextureGroups()

    gManagersInited = true
    return true
}

// MARK: - Layer handoff

// Rebinds the renderer to a different CAMetalLayer (System Settings
// swapping its thumbnail for the full-screen preview, or back). Tears down
// everything holding GPU textures, rebuilds against the new layer, and
// reloads. The caller starts the scene again afterwards.
@_cdecl("Nanosaur2Saver_AttachLayer")
public func Nanosaur2Saver_AttachLayer(
    _ metalLayer: UnsafeMutableRawPointer,
    _ pixelWidth: Int32,
    _ pixelHeight: Int32) -> Bool
{
    guard gManagersInited else { return false }

    Nanosaur2Saver_StopScene() // no-op if the scene isn't up
    disposeGlobalTextureGroups()

    guard bindRenderer(toLayer: metalLayer, pixelWidth, pixelHeight) else {
        return false
    }

    loadGlobalTextureGroups()
    return true
}

// MARK: - Scene start/stop (idempotent - the host doesn't track state)

@_cdecl("Nanosaur2Saver_StartScene")
public func Nanosaur2Saver_StartScene() {
    guard gManagersInited, !gSceneUp else { return }

    gEngine.screens.introMode = UInt8(INTRO_MODE_SCREENSAVER)

    SetupLevelIntroScene()
    SetupLevelIntroScreensaverObjects()

    _ = MakeFadeEvent(UInt8(kFadeFlags_In), 1.5)

    gSceneUp = true
}

@_cdecl("Nanosaur2Saver_StopScene")
public func Nanosaur2Saver_StopScene() {
    guard gSceneUp else { return }
    FreeLevelIntroScene()
    gSceneUp = false
}

// MARK: - Per-frame tick

// The host passes the view's backing size in pixels; the drawable and
// gEngine.window follow it (OGL_DrawScene's NANOSAUR_SCREENSAVER branch
// expects gEngine.window to be current instead of querying an SDL window).
@_cdecl("Nanosaur2Saver_Frame")
public func Nanosaur2Saver_Frame(_ pixelWidth: Int32, _ pixelHeight: Int32) {
    guard gSceneUp, let renderer = gSaverRenderer else { return }

    if gDrawableSize.width != pixelWidth || gDrawableSize.height != pixelHeight {
        renderer.setDrawableSize(width: Int(pixelWidth), height: Int(pixelHeight))
        gDrawableSize = (pixelWidth, pixelHeight)
    }

    gEngine.window.width = pixelWidth
    gEngine.window.height = pixelHeight

    CalcFramesPerSecond()
    MoveObjects()
    OGL_DrawScene(DrawObjects)
}

// MARK: - Frame capture (SaverSmoke only)

@_cdecl("Nanosaur2Saver_SetCaptureEnabled")
public func Nanosaur2Saver_SetCaptureEnabled(_ enabled: Bool) {
    gSaverRenderer?.captureFrames = enabled
}

/// Copies the last captured frame (BGRA, top-down) into `out` if it fits.
@_cdecl("Nanosaur2Saver_CopyLastFrame")
public func Nanosaur2Saver_CopyLastFrame(
    _ out: UnsafeMutablePointer<UInt8>,
    _ outCapacity: Int32,
    _ outWidth: UnsafeMutablePointer<Int32>,
    _ outHeight: UnsafeMutablePointer<Int32>) -> Bool
{
    guard let renderer = gSaverRenderer, let bgra = renderer.lastCaptureBGRA else { return false }
    guard bgra.count <= Int(outCapacity) else { return false }
    bgra.withUnsafeBufferPointer { buf in
        out.update(from: buf.baseAddress!, count: buf.count)
    }
    outWidth.pointee = Int32(renderer.lastCaptureWidth)
    outHeight.pointee = Int32(renderer.lastCaptureHeight)
    return true
}

#endif // NANOSAUR_SCREENSAVER
