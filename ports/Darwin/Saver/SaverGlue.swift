// SaverGlue.swift - the engine-side entry points for the macOS screen
// saver (ports/Darwin). Compiled INTO the engine's Swift module (so it can
// touch gEngine and every engine function directly) and exported as plain
// C symbols, because the ScreenSaverView host lives in a separate Swift
// module: it must `import ScreenSaver`/AppKit, which cannot coexist with
// the game's bridging header (SwMacTypes.h collides with Darwin.MacTypes -
// the same reason MetalRenderer is its own module, see
// docs/metal-renderer-plan.md).
//
// Contract with the host (Nanosaur2SaverView):
// - The host owns the NSOpenGLContext and makes it current BEFORE calling
//   any of these; it flushes (presents) AFTER each call returns.
//   GLRenderBackend's NANOSAUR_SCREENSAVER branches rely on this.
// - Boot once per process, then Start/Frame.../Stop cycles (the system may
//   stop and restart animation, e.g. System Settings preview).

#if NANOSAUR_SCREENSAVER

// MARK: - Boot (once per process)

@_cdecl("Nanosaur2Saver_Boot")
public func Nanosaur2Saver_Boot(_ dataPathC: UnsafePointer<CChar>) {
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

    // BOOT THE RENDERER AGAINST THE HOST'S (CURRENT) GL CONTEXT

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

    LoadSpriteAtlas(Int32(ATLAS_GROUP_FONT1), ":Sprites:fonts:font", Int32(kAtlasLoadFont | kAtlasLoadFontIsUpperCaseOnly))
    LoadSpriteGroupFromSeries(Int32(SPRITE_GROUP_PARTICLES), Int32(PARTICLE_SObjType_COUNT), "particle")
    BlendAllSpritesInGroup(Int16(SPRITE_GROUP_PARTICLES))
}

// MARK: - Scene start/stop

@_cdecl("Nanosaur2Saver_StartScene")
public func Nanosaur2Saver_StartScene() {
    gEngine.screens.introMode = UInt8(INTRO_MODE_SCREENSAVER)

    SetupLevelIntroScene()
    SetupLevelIntroScreensaverObjects()

    _ = MakeFadeEvent(UInt8(kFadeFlags_In), 1.5)
}

@_cdecl("Nanosaur2Saver_StopScene")
public func Nanosaur2Saver_StopScene() {
    FreeLevelIntroScene()
}

// MARK: - Per-frame tick

// The host passes the view's backing size in pixels; OGL_DrawScene's
// NANOSAUR_SCREENSAVER branch expects gEngine.window to be current instead
// of querying an SDL window.
@_cdecl("Nanosaur2Saver_Frame")
public func Nanosaur2Saver_Frame(_ pixelWidth: Int32, _ pixelHeight: Int32) {
    gEngine.window.width = pixelWidth
    gEngine.window.height = pixelHeight

    CalcFramesPerSecond()
    MoveObjects()
    OGL_DrawScene(DrawObjects)
}

#endif // NANOSAUR_SCREENSAVER
