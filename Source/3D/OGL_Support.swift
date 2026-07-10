// OGL_Support.swift - Port of OGL_Support.c to Swift
//
// gAnaglyphFocallength/gAnaglyphEyeSeparation/gAnaglyphPass/gAGLContext/
// gAGLContext2/gViewToFrustumMatrix/gWorldToViewMatrix/gWorldToFrustumMatrix/
// gLocalToViewMatrix/gLocalToFrustumMatrix/gWorldToWindowMatrix/
// gCurrentSplitScreenPane/gActiveSplitScreenMode/gCurrentPaneAspectRatio/
// gMyState_Lighting/gMyState_Color/gPolysThisFrame are native Swift storage
// (converted 2026-07-07): nothing in any .c file touches them anymore -
// the old comment claiming other C files still needed them via extern was
// stale (OGL_Support.c had no real remaining C readers, same pattern as
// bg3d.c/Sound.c/etc. this session). gWorldToWindowMatrix is a 3-tuple
// (MAX_VIEWPORTS), matching the tuple-not-Array pattern already used below
// for gFrustumToWindowMatrix, so withUnsafeMutablePointer(to:) addresses
// real contiguous storage instead of an Array's storage-reference header.
//
// gFrustumToWindowMatrix, gStateStack_*, gMyState_Blend/Fog/Texture2D/
// CullFace/TextureUnit/BlendFuncS/BlendFuncD, gAnaglyphGreyTable,
// gDoAnisotropy, gMaxAnisotropy, and the vertex-array-memory bookkeeping
// (gVARMemoryAllocated, gVertexArrayMemoryBlock, gVertexArrayMemory_Head/
// Tail) were never `extern`'d anywhere (either already `static`, or
// non-static but referenced nowhere else) - they move into private Swift
// storage instead, as plain Swift arrays where the C original used a fixed
// array (nothing external needs pointer access to them).

var gAnaglyphFocallength: Float = 450.0
var gAnaglyphEyeSeparation: Float = 40.0
var gAnaglyphPass: UInt8 = 0

var gAGLContext: OpaquePointer?
var gAGLContext2: OpaquePointer?

var gViewToFrustumMatrix = OGLMatrix4x4()
var gWorldToViewMatrix = OGLMatrix4x4()
var gWorldToFrustumMatrix = OGLMatrix4x4()
var gLocalToViewMatrix = OGLMatrix4x4()
var gLocalToFrustumMatrix = OGLMatrix4x4()

// MAX_VIEWPORTS is 3 (MAX_SPLITSCREENS+1); see gFrustumToWindowMatrix below
// for why this is a tuple, not an Array.
var gWorldToWindowMatrix: (OGLMatrix4x4, OGLMatrix4x4, OGLMatrix4x4) = (OGLMatrix4x4(), OGLMatrix4x4(), OGLMatrix4x4())

var gCurrentSplitScreenPane: UInt8 = 0
var gActiveSplitScreenMode: UInt8 = UInt8(SplitscreenMode.none.rawValue)
var gCurrentPaneAspectRatio: Float = 1

var gMyState_Lighting: UInt8 = 0
var gMyState_Color = OGLColorRGBA()

var gPolysThisFrame: Int32 = 0
//
// VERTEXARRAYRANGES is hardcoded to 0 in game.h (like Water.swift/others
// already noted), so every `#if VERTEXARRAYRANGES` block is dead code and
// is omitted here entirely, including gVertexArrayRangeObjects/
// gHardwareSupportsVertexArrayRange/gUsingVertexArrayRange's *actual*
// underlying storage (the extern'd declarations stay in game.h for any
// still-C file that references them, but since nothing does, and their
// C-side definitions were themselves inside the dead `#if` block already,
// this Swift file just doesn't define gHardwareSupportsVertexArrayRange -
// confirmed zero references anywhere in the codebase) - and
// AssignVertexArrayRangeMemory/ReleaseVertexArrayRangeMemory/
// OGL_UpdateVertexArrayRange (whose entire bodies were behind that same
// flag) are dropped completely, matching how Water.swift already handled
// the identical dead block.
//
// The two `goto` labels in the original (OGL_DrawScene's do_shutter/
// do_anaglyph, OGL_AllocVertexArrayMemory's got_it) are restructured
// without goto - a loop with a flag for OGL_DrawScene (see comment at its
// call site below), and direct early returns for OGL_AllocVertexArrayMemory
// now that its VERTEXARRAYRANGES-only tail is dropped.

private let kNoErr: OSErr = 0

// MARK: - GL extension function pointers (Necessary on Windows; harmless here)

// glActiveTexture/glClientActiveTexture proc pointers moved into
// GLRenderBackend (loadGLProcs) as part of the portable-facade refactor.

// MARK: - Vertex array memory bookkeeping (file-private, never referenced elsewhere)

private struct VertexArrayMemoryNode {
    var prevNode: UnsafeMutablePointer<VertexArrayMemoryNode>?
    var nextNode: UnsafeMutablePointer<VertexArrayMemoryNode>?
    var pointer: UnsafeMutableRawPointer?
    var size: Int
}

private var gVARMemoryAllocated = false
// Deliberately trivial initial values (no `repeating:count:` at global scope) -
// this matches the original C, where these were file-scope arrays implicitly
// zeroed as BSS with no runtime work, then explicitly reset inside
// OGL_InitVertexArrayMemory. Sized/reset there instead of here.
private var gVertexArrayMemoryBlock: [UnsafeMutableRawPointer?] = []
private var gVertexArrayMemory_Head: [UnsafeMutablePointer<VertexArrayMemoryNode>?] = []
private var gVertexArrayMemory_Tail: [UnsafeMutablePointer<VertexArrayMemoryNode>?] = []

// MARK: - Other file-private state

private var gDoAnisotropy = false // WARNING!! THIS IS A MAJOR PERFORMANCE KILLER
private var gMaxAnisotropy: Float = 1.0

private var gAnaglyphGreyTable = [UInt8](repeating: 0, count: 255)

// MAX_VIEWPORTS is 3 (MAX_SPLITSCREENS+1); a tuple (not Array) so
// withUnsafeMutablePointer(to:) below addresses real contiguous storage
// instead of an Array's storage-reference header.
private var gFrustumToWindowMatrix: (OGLMatrix4x4, OGLMatrix4x4, OGLMatrix4x4) = (OGLMatrix4x4(), OGLMatrix4x4(), OGLMatrix4x4())

private let kStateStackSize = 20
private var gStateStackIndex = 0
private var gStateStack_Lighting = [Bool](repeating: false, count: kStateStackSize)
private var gStateStack_CullFace = [Bool](repeating: false, count: kStateStackSize)
private var gStateStack_DepthTest = [Bool](repeating: false, count: kStateStackSize)
private var gStateStack_Normalize = [Bool](repeating: false, count: kStateStackSize)
private var gStateStack_Texture2D = [Bool](repeating: false, count: kStateStackSize)
private var gStateStack_Blend = [Bool](repeating: false, count: kStateStackSize)
private var gStateStack_Fog = [Bool](repeating: false, count: kStateStackSize)
private var gStateStack_DepthMask = [GLboolean](repeating: 0, count: kStateStackSize)
private var gStateStack_BlendDst = [GLint](repeating: 0, count: kStateStackSize)
private var gStateStack_BlendSrc = [GLint](repeating: 0, count: kStateStackSize)
private var gStateStack_Color = [OGLColorRGBA](repeating: OGLColorRGBA(), count: kStateStackSize)

private var gMyState_Blend = false
private var gMyState_Fog = false
private var gMyState_Texture2D = false
private var gMyState_CullFace = false
private var gMyState_DepthTest = false
private var gMyState_TextureUnit: UInt32 = 0
private var gMyState_BlendFuncS: GLenum = 0
private var gMyState_BlendFuncD: GLenum = 0
// Shadow copies of normal-renormalization and depth-write state, so
// OGL_PushState/PopState can save/restore them without GL introspection
// (which isn't portable). Kept accurate by routing every mutation through
// OGL_SetNormalizeNormals/OGL_SetDepthWrite below; both start true because
// prepareSceneDefaults() enables GL_NORMALIZE and depth writes default on.
private var gMyState_Normalize = true
private var gMyState_DepthMask = true

func OGL_SetNormalizeNormals(_ enabled: Bool) {
    gMyState_Normalize = enabled
    gEngine.renderer.setNormalizeNormals(enabled)
}

func OGL_SetDepthWrite(_ enabled: Bool) {
    gMyState_DepthMask = enabled
    gEngine.renderer.setDepthWrite(enabled)
}

// MARK: - Macro shims (parameterless/parameterized macros aren't importable)

@inline(__always) private func isStereo() -> Bool { gGamePrefs.stereoGlassesMode != UInt8(StereoGlassesMode.off.rawValue) }
@inline(__always) private func isStereoShutter() -> Bool { gGamePrefs.stereoGlassesMode == UInt8(StereoGlassesMode.shutter.rawValue) }
@inline(__always) private func isStereoAnaglyphColor() -> Bool { gGamePrefs.stereoGlassesMode == UInt8(StereoGlassesMode.anaglyphColor.rawValue) }
@inline(__always) private func isStereoAnaglyphMono() -> Bool { gGamePrefs.stereoGlassesMode == UInt8(StereoGlassesMode.anaglyphMono.rawValue) }
@inline(__always) private func isStereoAnaglyph() -> Bool { isStereoAnaglyphColor() || isStereoAnaglyphMono() }
@inline(__always) private func getOverlayPaneNumber() -> Int { Int(gNumPlayers) }

// MARK: - Dual-screen mode (--dual-screen)
//
// When gDualScreenMode is set (Boot.cpp parses --dual-screen), gSDLWindow2/
// gAGLContext2 are a second SDL window+GL context for the bottom screen.
// Everything the game draws every frame (menus, 3D world, HUD, intro,
// attract) renders on gSDLWindow/gAGLContext (the top screen) exactly as in
// single-window mode - none of the per-frame draw path is aware of
// dual-screen mode. The bottom screen is static: OGL_CreateDrawContext
// draws the main menu background image to it once at boot and never
// touches it again (see the dual-screen block in that function). Splitting
// per-frame content (e.g. moving the HUD to the bottom window) was tried
// and reverted - toggling which of two *separate* GL contexts is current
// every frame desyncs the cached GL state flags (gMyState_*) this file
// relies on to skip redundant GL calls, since those flags are per-process
// but the real GL server state is now split across two contexts.

@inline(__always) private func OGL_CheckError() -> GLenum {
    OGL_CheckError_Impl(#file, Int32(#line))
}

// MARK: - Fixed-array-field helpers (all struct fields, never unions)

@inline(__always) private func gWorldToWindowMatrixBase() -> UnsafeMutablePointer<OGLMatrix4x4> {
    withUnsafeMutablePointer(to: &gWorldToWindowMatrix) {
        UnsafeMutableRawPointer($0).assumingMemoryBound(to: OGLMatrix4x4.self)
    }
}

// Replaces the old InfobarInternal.h C shim of the same name/signature -
// Infobar.swift/Camera.swift call this to index into gWorldToWindowMatrix,
// which (as a tuple) isn't subscriptable by a variable index directly.
func GetWorldToWindowMatrixEntry(_ i: Int32) -> UnsafeMutablePointer<OGLMatrix4x4> {
    gWorldToWindowMatrixBase() + Int(i)
}

@inline(__always) private func cameraPlacementsBase() -> UnsafeMutablePointer<OGLCameraPlacement> {
    UnsafeMutableRawPointer(gGameViewInfoPtr!.pointer(to: \.cameraPlacement)!).assumingMemoryBound(to: OGLCameraPlacement.self)
}

@inline(__always) private func fovBase() -> UnsafeMutablePointer<Float> {
    UnsafeMutableRawPointer(gGameViewInfoPtr!.pointer(to: \.fov)!).assumingMemoryBound(to: Float.self)
}

@inline(__always) private func cameraFromBase(_ viewDef: UnsafeMutablePointer<OGLSetupInputType>) -> UnsafeMutablePointer<OGLPoint3D> {
    UnsafeMutableRawPointer(viewDef.pointer(to: \.camera.from)!).assumingMemoryBound(to: OGLPoint3D.self)
}

@inline(__always) private func cameraToBase(_ viewDef: UnsafeMutablePointer<OGLSetupInputType>) -> UnsafeMutablePointer<OGLPoint3D> {
    UnsafeMutableRawPointer(viewDef.pointer(to: \.camera.to)!).assumingMemoryBound(to: OGLPoint3D.self)
}

@inline(__always) private func cameraUpBase(_ viewDef: UnsafeMutablePointer<OGLSetupInputType>) -> UnsafeMutablePointer<OGLVector3D> {
    UnsafeMutableRawPointer(viewDef.pointer(to: \.camera.up)!).assumingMemoryBound(to: OGLVector3D.self)
}

@inline(__always) private func fillDirectionBase(_ lights: UnsafeMutablePointer<OGLLightDefType>) -> UnsafeMutablePointer<OGLVector3D> {
    UnsafeMutableRawPointer(lights.pointer(to: \.fillDirection)!).assumingMemoryBound(to: OGLVector3D.self)
}

@inline(__always) private func fillColorBase(_ lights: UnsafeMutablePointer<OGLLightDefType>) -> UnsafeMutablePointer<OGLColorRGBA> {
    UnsafeMutableRawPointer(lights.pointer(to: \.fillColor)!).assumingMemoryBound(to: OGLColorRGBA.self)
}

// MARK: - OGL Boot

func OGL_Boot() {
    // GENERATE ANAGLYPH GREY CONVERSION TABLE
    //
    // This makes an intensity curve to brighten things up, but sometimes
    // it washes them out.

    var f: Float = 0
    for i in 0..<255 {
        gAnaglyphGreyTable[i] = UInt8(sin(f) * 255.0)
        f += (Float.pi / 2.0) / 255.0
    }

    // CREATE DRAW CONTEXT
    //
    // The source port reuses a single draw context throughout the lifespan of the program.

    OGL_CreateDrawContext()
}

// MARK: - OGL Shutdown

func OGL_Shutdown() {
    OGL_DisposeDrawContext()
}

// MARK: - OGL: New view def

// fills a view def structure with default values.

func OGL_NewViewDef(_ viewDef: UnsafeMutablePointer<OGLSetupInputType>!) {
    let clearColor = OGLColorRGBA(r: 0, g: 0, b: 0, a: 1)
    let cameraFrom = OGLPoint3D(x: 0, y: 0, z: 0.0)
    let cameraTo = OGLPoint3D(x: 0, y: 0, z: -1)
    let cameraUp = OGLVector3D(x: 0.0, y: 1.0, z: 0.0)
    let ambientColor = OGLColorRGBA(r: 0.2, g: 0.2, b: 0.2, a: 1)
    let fillColor = OGLColorRGBA(r: 1.0, g: 1.0, b: 1.0, a: 1)
    var fillDirection1 = OGLVector3D(x: 1, y: 0, z: -1)
    var fillDirection2 = OGLVector3D(x: -1, y: -0.3, z: -0.3)

    fillDirection1 = fillDirection1.normalized()
    fillDirection2 = fillDirection2.normalized()

    viewDef.pointee.view.clearColor = clearColor
    viewDef.pointee.view.clip.left = 0
    viewDef.pointee.view.clip.right = 0
    viewDef.pointee.view.clip.top = 0
    viewDef.pointee.view.clip.bottom = 0
    viewDef.pointee.view.numPanes = 1 // assume only 1 pane
    viewDef.pointee.view.clearBackBuffer = 1

    let camFrom = cameraFromBase(viewDef)
    let camTo = cameraToBase(viewDef)
    let camUp = cameraUpBase(viewDef)
    camFrom[0] = cameraFrom
    camFrom[1] = cameraFrom
    camTo[0] = cameraTo
    camTo[1] = cameraTo
    camUp[0] = cameraUp
    camUp[1] = cameraUp
    viewDef.pointee.camera.hither = 10
    viewDef.pointee.camera.yon = 4000
    viewDef.pointee.camera.fov = 1.2

    viewDef.pointee.styles.useFog = 0
    viewDef.pointee.styles.fogStart = viewDef.pointee.camera.yon * 0.5
    viewDef.pointee.styles.fogEnd = viewDef.pointee.camera.yon
    viewDef.pointee.styles.fogDensity = 1.0
    viewDef.pointee.styles.fogMode = Int16(GL_LINEAR)

    viewDef.pointee.lights.ambientColor = ambientColor
    viewDef.pointee.lights.numFillLights = 1
    let fillDir = fillDirectionBase(&viewDef.pointee.lights)
    fillDir[0] = fillDirection1
    fillDir[1] = fillDirection2
    let fillCol = fillColorBase(&viewDef.pointee.lights)
    fillCol[0] = fillColor
    fillCol[1] = fillColor
}

// MARK: - Setup OGL window

func OGL_SetupGameView(_ setupDefPtr: UnsafeMutablePointer<OGLSetupInputType>!) {
    SwGameAssert(gGameViewInfoPtr == nil)

    // ALLOC MEMORY FOR OUTPUT DATA

    gGameViewInfoPtr = AllocPtrClear(MemoryLayout<OGLSetupOutputType>.size)?.assumingMemoryBound(to: OGLSetupOutputType.self)
    SwGameAssert(gGameViewInfoPtr != nil)

    // SET SOME PANE INFO

    gCurrentSplitScreenPane = 0
    switch gNumPlayers {
    case 1:
        gActiveSplitScreenMode = UInt8(SplitscreenMode.none.rawValue)

    case 2:
        gActiveSplitScreenMode = gGamePrefs.splitScreenMode

    default:
        SwFatalAlert("OGL_SetupWindow: # panes not implemented")
    }

    // SETUP

    OGL_InitDrawContext(setupDefPtr)
    _ = OGL_CheckError()
    OGL_SetStyles(setupDefPtr)
    _ = OGL_CheckError()
    OGL_CreateLights(&setupDefPtr.pointee.lights)
    _ = OGL_CheckError()

    OGL_InitVertexArrayMemory()
    _ = OGL_CheckError()

    // PASS BACK INFO

    gGameViewInfoPtr!.pointee.clip = setupDefPtr.pointee.view.clip
    gGameViewInfoPtr!.pointee.hither = setupDefPtr.pointee.camera.hither // remember hither/yon
    gGameViewInfoPtr!.pointee.yon = setupDefPtr.pointee.camera.yon
    gGameViewInfoPtr!.pointee.useFog = setupDefPtr.pointee.styles.useFog
    gGameViewInfoPtr!.pointee.clearBackBuffer = setupDefPtr.pointee.view.clearBackBuffer
    gGameViewInfoPtr!.pointee.clearColor = setupDefPtr.pointee.view.clearColor

    gGameViewInfoPtr!.isActive = true // it's now an active structure

    gGameViewInfoPtr!.pointee.lightList = setupDefPtr.pointee.lights // copy lights

    let camFrom = cameraFromBase(setupDefPtr)
    let camTo = cameraToBase(setupDefPtr)
    let fov = fovBase()
    for i in 0..<Int(MAX_VIEWPORTS) {
        fov[i] = setupDefPtr.pointee.camera.fov // each camera will have its own fov so we can change it for special effects
        var from = camFrom[i]
        var to = camTo[i]
        OGL_UpdateCameraFromTo(&from, &to, Int32(i))
    }

    gGameViewInfoPtr!.pointee.frameCount = 0 // init frame counter

    gGameViewInfoPtr!.fadeSound = false // by default, don't fade out sound when exiting scene
}

// MARK: - OGL_DisposeGameView

// Disposes of all data created by OGL_SetupWindow

func OGL_DisposeGameView() {
    SwGameAssert(gGameViewInfoPtr != nil)

    // MAKE SURE TO CLEAR STEREO BUFFERS IF NEEDED

    // SET BUFFER FOR SHUTTER GLASSES

    ClearAllBuffersToBlack()

    // KILL DEBUG FONT

    OGL_FreeFont()

    // FREE VERTEX ARRAY RANGE MEMORY

    OGL_DisableVertexArrayRanges()

    // FREE MEMORY & NIL POINTER

    gGameViewInfoPtr!.isActive = false // now inactive
    SafeDisposePtr(UnsafeMutableRawPointer(gGameViewInfoPtr))
    gGameViewInfoPtr = nil
}

// MARK: - OGL: Create draw context

// Call this ONCE when booting the game.
// The source port reuses a single draw context throughout the lifespan of the program.

private func OGL_CreateDrawContext() {
    SwGameAssertMessage(gAGLContext == nil, "GL context already exists")
    SwGameAssertMessage(gSDLWindow != nil, "Window must be created before the DC!")

    // ACTIVATE THE REAL METAL BACKEND, IF REQUESTED (--metal), AND SKIP GL
    // CONTEXT CREATION ENTIRELY.
    //
    // Keeping the normal GL context alive (just never presented) alongside
    // a second Metal-backed view on the same window doesn't work: SDL's
    // Metal view corrupts the window for GL context creation regardless of
    // ordering (see git history for the exact errors hit). So under --metal
    // there is NO GL context at all - gSDLWindow is created with
    // SDL_WINDOW_METAL only (Boot.cpp). Safe because the portable-facade
    // refactor (docs/metal-renderer-plan.md) moved every raw gl* call the
    // game makes behind RenderBackend, except a handful of inherently-GL
    // features (shutter stereo, dual-screen's 2nd context) this backend
    // can't reach anyway.
    if gMetalMode != 0 {
        if !SwMetalBackend_Activate() {
            SwFatalAlert("--metal: SwMetalBackend_Activate failed")
        }
        return
    }

    // CREATE THE BACKEND'S CONTEXT (GL: SDL context + make-current + vsync
    // + proc loading + capability check - see GLRenderBackend.createContext)

    gEngine.renderer.createContext()

    // DUAL-SCREEN MODE: CREATE A SECOND CONTEXT FOR THE BOTTOM WINDOW AND
    // LOAD THE MAIN MENU BACKGROUND IMAGE FOR IT
    //
    // Shares texture/VBO namespace with gAGLContext (set via
    // SDL_GL_SHARE_WITH_CURRENT_CONTEXT while gAGLContext is current, right
    // before creating the second context). The background texture is
    // redrawn every frame behind the minimap (see
    // OGL_DrawDualScreenBackground/OGL_DrawDualScreenMinimap) rather than
    // drawn once and left alone - with double buffering, a partial
    // (map-only) update each frame only ever touches whichever backbuffer
    // is current, so the other buffer's content lags a frame behind,
    // producing a visible flicker; redrawing the full frame every time
    // keeps both buffers identical.

    if gDualScreenMode != 0, let window2 = gSDLWindow2 {
        try? SDL.glSetAttribute(.shareWithCurrentContext, 1)

        gAGLContext2 = SDL_GL_CreateContext(window2)
        if gAGLContext2 == nil {
            SwFatalAlert(String(cString: SDL_GetError()))
        }

        let didMakeCurrent2 = SDL_GL_MakeCurrent(window2, gAGLContext2)
        SwGameAssertMessage(didMakeCurrent2, String(cString: SDL_GetError()))

        try? SDL.glSetSwapInterval(Int32(gGamePrefs.vsync))

        var bgWidth: Int32 = 0
        var bgHeight: Int32 = 0
        gDualScreenBackgroundTexture = OGL_TextureMap_LoadImageFile(":Sprites:menu:menuback", &bgWidth, &bgHeight, nil)

        var window2Width: Int32 = 0
        var window2Height: Int32 = 0
        SDL_GetWindowSizeInPixels(window2, &window2Width, &window2Height)
        glViewport(0, 0, window2Width, window2Height)

        OGL_DrawDualScreenBackground(window2Width, window2Height) // fill both backbuffer slots so neither shows garbage
        SDL_GL_SwapWindow(window2)
        OGL_DrawDualScreenBackground(window2Width, window2Height)
        SDL_GL_SwapWindow(window2)

        // SWITCH BACK TO THE TOP WINDOW/CONTEXT SO BOOT CAN PROCEED AS NORMAL

        _ = SDL_GL_MakeCurrent(gSDLWindow, gAGLContext)
    }
}

// MARK: - OGL draw scene (dual-screen background)

private var gDualScreenBackgroundTexture: GLuint = 0

// Draws the static main-menu background image full-screen into whichever
// window2 context is currently current. Assumes an orthographic projection
// matching (windowWidth, windowHeight) is already (or about to be) set up
// by the caller - this only sets up the modelview matrix.
private func OGL_DrawDualScreenBackground(_ windowWidth: Int32, _ windowHeight: Int32) {
    gEngine.renderer.matrixMode(.projection)
    gEngine.renderer.loadIdentity()
    glOrtho(0, GLdouble(windowWidth), GLdouble(windowHeight), 0, -1, 1)
    gEngine.renderer.matrixMode(.modelview)
    gEngine.renderer.loadIdentity()

    gEngine.renderer.setClearColor(0, 0, 0)
    gEngine.renderer.clearColorAndDepth()

    glEnable(GLenum(GL_TEXTURE_2D))
    gEngine.renderer.bindTexture(gDualScreenBackgroundTexture)
    glColor4f(1, 1, 1, 1)

    glBegin(GLenum(GL_QUADS))
    glTexCoord2f(0, 0); glVertex2f(0, 0)
    glTexCoord2f(1, 0); glVertex2f(Float(windowWidth), 0)
    glTexCoord2f(1, 1); glVertex2f(Float(windowWidth), Float(windowHeight))
    glTexCoord2f(0, 1); glVertex2f(0, Float(windowHeight))
    glEnd()

    glDisable(GLenum(GL_TEXTURE_2D))
}

// MARK: - OGL: Nuke draw context

// Do this when QUITTING the game!
// The game reuses the same draw context for all scenes!

private func OGL_DisposeDrawContext() {
    // The dual-screen bottom window's second context is a GL-only extra,
    // torn down here before the backend's own context.
    if gAGLContext2 != nil, let window2 = gSDLWindow2 {
        _ = SDL_GL_MakeCurrent(window2, nil)
        SDL_GL_DestroyContext(gAGLContext2)
        gAGLContext2 = nil
    }

    gEngine.renderer.destroyContext()
}

// MARK: - OGL: Init draw context

// Call this when setting up a new scene.
// Note: the source port reuses a SINGLE draw context throughout the lifespan of the program.

private func OGL_InitDrawContext(_ def: UnsafeMutablePointer<OGLSetupInputType>!) {
    // FIX FOG FOR FOR B&W ANAGLYPH
    //
    // The NTSC luminance standard where grayscale = .299r + .587g + .114b

    if isStereoAnaglyphColor() {
        var r = UInt32(def!.pointee.view.clearColor.r * 255.0)
        var g = UInt32(def!.pointee.view.clearColor.g * 255.0)
        var b = UInt32(def!.pointee.view.clearColor.b * 255.0)

        ColorBalanceRGBForAnaglyph(&r, &g, &b, 1)

        def!.pointee.view.clearColor = OGLColorRGBA(r: Float(r) / 255.0, g: Float(g) / 255.0, b: Float(b) / 255.0, a: 1.0)
    } else if isStereoAnaglyphMono() {
        var f = def!.pointee.view.clearColor.r * 0.299
        f += def!.pointee.view.clearColor.g * 0.587
        f += def!.pointee.view.clearColor.b * 0.114

        def!.pointee.view.clearColor = OGLColorRGBA(r: f, g: f, b: f, a: 1.0)
    }

    // CLEAR ALL BUFFERS TO BLACK

    ClearAllBuffersToBlack()

    // SET VARIOUS STATE INFO

    gEngine.renderer.setClearColor(def!.pointee.view.clearColor.r, def!.pointee.view.clearColor.g, def!.pointee.view.clearColor.b)
    OGL_EnableDepthTest() // use z-buffer

    // Fixed-function scene defaults (cull orientation, alpha test, white
    // color-tracking material, normalization, fog hint) - one facade call,
    // no-op on backends without those concepts.
    gEngine.renderer.prepareSceneDefaults()

    // INIT DEBUG FONT

    OGL_InitFont()
}

// MARK: - OGL: Set styles

private func OGL_SetStyles(_ setupDefPtr: UnsafeMutablePointer<OGLSetupInputType>!) {
    // Cull orientation / alpha test / color material / fog hint defaults
    // were applied by prepareSceneDefaults() in OGL_InitDrawContext just
    // before this runs; here we (re)set the cached toggles and per-scene
    // parameters.

    gMyState_CullFace = false
    OGL_EnableCullFace()

    // SET BLENDING DEFAULTS

    gMyState_BlendFuncS = 0
    gMyState_BlendFuncD = 0
    OGL_BlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA)) // set default blend func

    gMyState_Blend = true
    OGL_DisableBlend()

    gMyState_TextureUnit = UInt32(GL_TEXTURE0_ARB)
    OGL_ActiveTextureUnit(UInt32(GL_TEXTURE0_ARB))
    gMyState_Texture2D = true
    OGL_DisableTexture2D()

    gMyState_Color.r = 0.1
    gMyState_Color.g = 0.1
    gMyState_Color.b = 0.1
    gMyState_Color.a = 0.1
    OGL_SetColor4f(1, 1, 1, 1)

    _ = OGL_CheckError()

    // SET FOG

    let styleDefPtr = setupDefPtr!.pointer(to: \.styles)!
    if styleDefPtr.pointee.useFog != 0 {
        let mode: RBFogMode
        switch Int32(styleDefPtr.pointee.fogMode) {
        case GL_EXP: mode = .exp
        case GL_EXP2: mode = .exp2
        default: mode = .linear
        }
        gEngine.renderer.setFog(
            mode: mode,
            density: styleDefPtr.pointee.fogDensity,
            start: styleDefPtr.pointee.fogStart,
            end: styleDefPtr.pointee.fogEnd,
            r: setupDefPtr!.pointee.view.clearColor.r,
            g: setupDefPtr!.pointee.view.clearColor.g,
            b: setupDefPtr!.pointee.view.clearColor.b,
            a: setupDefPtr!.pointee.view.clearColor.a)
        gMyState_Fog = false
        OGL_EnableFog()
    } else {
        gMyState_Fog = true
        OGL_DisableFog()
    }

    _ = OGL_CheckError()

    // ANISOTRIPIC FILTERING

    if gDoAnisotropy, gMetalMode == 0 { // dead flag ("MAJOR PERFORMANCE KILLER") - raw GL introspection, kept guarded
        glGetFloatv(GLenum(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT), &gMaxAnisotropy)
        _ = OGL_CheckError()
    }
}

// MARK: - Clear all buffers to black

private func ClearAllBuffersToBlack() {
    gEngine.renderer.setClearColor(0, 0, 0)
    if isStereoShutter() {
        glDrawBuffer(GLenum(GL_BACK_LEFT))
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
        glDrawBuffer(GLenum(GL_BACK_RIGHT))
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
        SDL_GL_SwapWindow(gSDLWindow)
        glDrawBuffer(GLenum(GL_BACK_LEFT))
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
        glDrawBuffer(GLenum(GL_BACK_RIGHT))
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
        SDL_GL_SwapWindow(gSDLWindow)
        _ = OGL_CheckError()
    } else {
        gEngine.renderer.clearColorAndDepth() // clear buffer
        gEngine.renderer.present()
        gEngine.renderer.clearColorAndDepth() // clear buffer
        gEngine.renderer.present()

        _ = OGL_CheckError()
    }
}

// MARK: - OGL: Create lights

// NOTE: The Projection matrix must be the identity or lights will be transformed.

private func OGL_CreateLights(_ lightDefPtr: UnsafeMutablePointer<OGLLightDefType>!) {
    gMyState_Lighting = 0
    OGL_EnableLighting()

    let fillDirection = fillDirectionBase(lightDefPtr)
    let fillColor = fillColorBase(lightDefPtr)

    // Normalize the fill directions in place (the game reads them back
    // elsewhere, e.g. the per-frame light-position update) before handing
    // the rig to the backend.
    for i in 0..<Int(lightDefPtr.pointee.numFillLights) {
        fillDirection[i] = fillDirection[i].normalized()
    }

    gEngine.renderer.setLights(
        ambientR: lightDefPtr.pointee.ambientColor.r,
        ambientG: lightDefPtr.pointee.ambientColor.g,
        ambientB: lightDefPtr.pointee.ambientColor.b,
        numFillLights: Int32(lightDefPtr.pointee.numFillLights),
        fillDirections: fillDirection,
        fillColors: fillColor)
}

// MARK: - OGL draw scene

func OGL_DrawScene(_ drawRoutine: (@convention(c) () -> Void)!) {
    SDL_GetWindowSizeInPixels(gSDLWindow, &gGameWindowWidth, &gGameWindowHeight)

    if !gGameViewInfoPtr!.isActive {
        SwFatalAlert("OGL_DrawScene isActive == false")
    }

    // INIT SOME STUFF

    if isStereo() {
        gAnaglyphPass = 0
        PrepAnaglyphCameras()
    }

    gPolysThisFrame = 0 // init poly counter
    gMostRecentMaterial = nil
    gGlobalMaterialFlags = 0
    gGlobalTransparency = 1.0
    OGL_SetColor4f(1, 1, 1, 1)

    // The original C used `goto do_shutter`/`goto do_anaglyph` to re-run this
    // block for the 2nd stereo pass, sometimes skipping the buffer-select +
    // clear step (anaglyph's 2nd pass) and sometimes not (shutter glasses'
    // 2nd pass, which has separate buffers that also need clearing).
    // `needClearAndBufferSelect` replicates that: true on entry (always do
    // the full sequence once), then set to `!isStereoAnaglyph()` when
    // looping back for the 2nd pass - false skips straight to do_anaglyph's
    // work (matching goto do_anaglyph), true redoes everything (matching
    // goto do_shutter).
    var needClearAndBufferSelect = true

    while true {
        if needClearAndBufferSelect {
            // SET BUFFER FOR SHUTTER GLASSES

            if isStereoShutter() {
                if gAnaglyphPass == 0 {
                    glDrawBuffer(GLenum(GL_BACK_LEFT))
                } else {
                    glDrawBuffer(GLenum(GL_BACK_RIGHT))
                }

                if OGL_CheckError() != 0 {
                    SwFatalAlert("OGL_DrawScene: glDrawBuffer()")
                }
            }

            // CLEAR BUFFERS

            if gGameViewInfoPtr!.pointee.clearBackBuffer != 0 || gDebugMode == 3 || isStereoAnaglyph() {
                // MAKE SURE GREEN CHANNEL IS CLEAR
                //
                // Bringing up dialogs can write into green channel, so always be sure it's clear

                if isStereoAnaglyphColor() {
                    gEngine.renderer.setColorMask(true, true, true, true) // make sure clearing Red/Green/Blue channels
                } else if isStereoAnaglyphMono() {
                    gEngine.renderer.setColorMask(true, false, true, true) // make sure clearing Red/Blue channels
                }

                gEngine.renderer.clearColorAndDepth()
            } else {
                gEngine.renderer.clearDepthOnly()
            }
        }

        // SEE IF DOING ANAGLYPH

        if isStereoAnaglyph() {
            // SET COLOR MASK

            if gAnaglyphPass == 0 {
                gEngine.renderer.setColorMask(true, false, false, true)
            } else {
                if isStereoAnaglyphColor() {
                    gEngine.renderer.setColorMask(false, true, true, true)
                } else {
                    gEngine.renderer.setColorMask(false, false, true, true)
                }
                gEngine.renderer.clearDepthOnly()
            }
        }

        // DRAW EACH SPLIT-SCREEN PANE IF ANY

        let numPasses = Int(gNumPlayers) + 1

        for pane in 0..<numPasses {
            gCurrentSplitScreenPane = UInt8(pane)

            // OFFSET ANAGLYPH CAMERAS

            if isStereo() {
                CalcAnaglyphCameraOffset(gCurrentSplitScreenPane, gAnaglyphPass)
            }

            // SET SPLIT-SCREEN VIEWPORT

            var x: Int32 = 0
            var y: Int32 = 0
            var w: Int32 = 1
            var h: Int32 = 1
            OGL_GetCurrentViewport(&x, &y, &w, &h, gCurrentSplitScreenPane)
            gEngine.renderer.setViewport(x, y, w, h)
            gCurrentPaneAspectRatio = Float(h) / Float(w)

            // GET UPDATED GLOBAL COPIES OF THE VARIOUS MATRICES

            OGL_Camera_SetPlacementAndUpdateMatrices(Int32(gCurrentSplitScreenPane))

            // CALL INPUT DRAW FUNCTION

            drawRoutine?()
        }

        // SEE IF DO ANOTHER ANAGLYPH PASS

        if isStereo() {
            gAnaglyphPass += 1
            if gAnaglyphPass == 1 {
                needClearAndBufferSelect = !isStereoAnaglyph() // anaglyph doesn't need to clear the backbuffer on the 2nd pass, but shutters have separate buffers so they do need to clear the buffers
                continue
            }
        }

        break
    }

    // SEE IF SHOW DEBUG INFO

    if SwIsKeyDown(Int(SDL_SCANCODE_F8.rawValue)) {
        gDebugMode += 1
        if gDebugMode > 3 {
            gDebugMode = 0
        }

        gEngine.renderer.setWireframe(gDebugMode == 3) // see if show wireframe
    }

    if gTimeDemo != 0 {
        OGL_DrawInt(Int32(gGameFrameNum), 20, 20)
    }

    // SHOW BASIC DEBUG INFO

    if gDebugMode > 0 {
        var y: GLint = 100
        let x2: GLint = 60

        OGL_DrawString("fps:", 10, y)
        OGL_DrawInt(Int32(gFramesPerSecond + 0.5), x2, y)
        y += 15

        OGL_DrawString("tri:", 10, y)
        OGL_DrawInt(Int32(gPolysThisFrame), x2, y)
        y += 15

        OGL_DrawString("KB:", 10, y)
        OGL_DrawInt(Int32(gRAMAlloced / 1024), x2, y)
        y += 15

        OGL_DrawString("PTR:", 10, y)
        OGL_DrawInt(Int32(gNumPointers), x2, y)
        y += 15

        OGL_DrawString("OBJ:", 10, y)
        OGL_DrawInt(Int32(gNumObjectNodes), x2, y)
        y += 15
    }

    // END RENDER

    if isStereoShutter() {
        DrawBlueLine(gGameWindowWidth, gGameWindowHeight)
    }

    // SWAP THE BUFFS

    gEngine.renderer.present() // end render loop

    if gGamePaused == 0 { // freeze frame count if paused (otherwise double-buffered skeletons will flicker)
        gGameViewInfoPtr!.pointee.frameCount += 1 // inc frame count AFTER drawing (so that the previous Move calls were in sync with this draw frame count)
    }

    if isStereo() {
        RestoreCamerasFromAnaglyph()
    }

    if gDualScreenMode != 0 {
        OGL_DrawDualScreenMinimap()
    }
}

// MARK: - OGL draw scene (dual-screen minimap)

// The bottom window is otherwise static (see OGL_CreateDrawContext), but
// while a level's overhead map is active, redraw it there every frame,
// centered and enlarged. Runs as a self-contained excursion onto
// gAGLContext2: OGL_PushState/PopState save and restore the cached GL
// state flags (gMyState_*) around it, so nothing here can desync context1's
// real GL state from what this file's cache believes it to be. Skips
// entirely (no context switch, no swap) when there's no map to draw, so
// the bottom window doesn't do needless work outside gameplay.
private func OGL_DrawDualScreenMinimap() {
    guard let window2 = gSDLWindow2, gAGLContext2 != nil, IsMinimapActive() else {
        return
    }

    let savedWindowWidth = gGameWindowWidth
    let savedWindowHeight = gGameWindowHeight

    // Push while context1 is still current, so this saves ITS real state.
    OGL_PushState()

    _ = SDL_GL_MakeCurrent(window2, gAGLContext2)

    // gMyState_* (and gMostRecentMaterial) reflect whatever context1 last
    // set - but that's Swift-side bookkeeping, not real GL state, and
    // context2's real GL state is its own (fresh/default until we've drawn
    // on it). Force every flag the sprite-drawing helpers below consult to
    // a value that's guaranteed to mismatch their desired target, so they
    // reissue the real GL call against context2 instead of wrongly
    // skipping it because the cache says "already set" (from context1).
    gMyState_Lighting = 1
    gMyState_CullFace = true
    gMyState_Texture2D = false
    gMyState_TextureUnit = UInt32(GL_TEXTURE0)
    gMyState_Blend = false
    gMyState_BlendFuncS = 0
    gMyState_BlendFuncD = 0
    gMyState_Color = OGLColorRGBA(r: -1, g: -1, b: -1, a: -1)
    gMostRecentMaterial = nil

    SDL_GetWindowSizeInPixels(window2, &gGameWindowWidth, &gGameWindowHeight)
    glViewport(0, 0, gGameWindowWidth, gGameWindowHeight)

    // Redraw the full background every frame (not just the map region) so
    // both backbuffers stay identical - see the comment on
    // gDualScreenBackgroundTexture's creation for why a partial update
    // flickers.
    OGL_DrawDualScreenBackground(gGameWindowWidth, gGameWindowHeight)
    DrawMinimapOnSecondaryScreen()

    SDL_GL_SwapWindow(window2)

    gGameWindowWidth = savedWindowWidth
    gGameWindowHeight = savedWindowHeight

    // Switch back to context1 BEFORE popping, so the restore calls PopState
    // issues actually land on context1 (the context they're meant for).
    _ = SDL_GL_MakeCurrent(gSDLWindow, gAGLContext)
    OGL_PopState()
}

// MARK: - Draw blue line

// for stereo blue-line stuff

private func DrawBlueLine(_ windowWidth: Int32, _ windowHeight: Int32) {
    glPushAttrib(GLbitfield(GL_ALL_ATTRIB_BITS))

    glDisable(GLenum(GL_ALPHA_TEST))
    glDisable(GLenum(GL_BLEND))
    glDisable(GLenum(GL_COLOR_LOGIC_OP))
    glDisable(GLenum(GL_COLOR_MATERIAL))
    glDisable(GLenum(GL_DEPTH_TEST))
    glDisable(GLenum(GL_DITHER))
    glDisable(GLenum(GL_FOG))
    glDisable(GLenum(GL_LIGHTING))
    glDisable(GLenum(GL_LINE_SMOOTH))
    glDisable(GLenum(GL_LINE_STIPPLE))
    glDisable(GLenum(GL_SCISSOR_TEST))
    glDisable(GLenum(GL_TEXTURE_1D))
    glDisable(GLenum(GL_TEXTURE_2D))
    glDisable(GLenum(GL_TEXTURE_3D))

    var buffer = GLenum(GL_BACK_LEFT)
    while buffer <= GLenum(GL_BACK_RIGHT) {
        var matrixMode: GLint = 0
        var vp = [GLint](repeating: 0, count: 4)

        glDrawBuffer(buffer)

        glGetIntegerv(GLenum(GL_VIEWPORT), &vp)
        glViewport(0, 0, windowWidth, windowHeight)

        glGetIntegerv(GLenum(GL_MATRIX_MODE), &matrixMode)
        glMatrixMode(GLenum(GL_PROJECTION))
        glPushMatrix()
        glLoadIdentity()

        glMatrixMode(GLenum(GL_MODELVIEW))
        glPushMatrix()
        glLoadIdentity()
        glScalef(2.0 / Float(windowWidth), -2.0 / Float(windowHeight), 1.0)
        glTranslatef(-Float(windowWidth) / 2.0, -Float(windowHeight) / 2.0, 0.0)

        // draw sync lines
        OGL_SetColor4f(0.0, 0.0, 0.0, 1)
        glBegin(GLenum(GL_LINES)) // Draw a background line
        glVertex3f(0.0, Float(windowHeight) - 0.5, 0.0)
        glVertex3f(Float(windowWidth), Float(windowHeight) - 0.5, 0.0)
        glEnd()
        OGL_SetColor4f(0.0, 0.0, 1.0, 1)
        glBegin(GLenum(GL_LINES)) // Draw a line of the correct length (the cross over is about 40% across the screen from the left
        glVertex3f(0.0, Float(windowHeight) - 0.5, 0.0)
        if buffer == GLenum(GL_BACK_LEFT) {
            glVertex3f(Float(windowWidth) * 0.30, Float(windowHeight) - 0.5, 0.0)
        } else {
            glVertex3f(Float(windowWidth) * 0.80, Float(windowHeight) - 0.5, 0.0)
        }
        glEnd()

        glPopMatrix()
        glMatrixMode(GLenum(GL_PROJECTION))
        glPopMatrix()
        glMatrixMode(GLenum(matrixMode))

        glViewport(vp[0], vp[1], vp[2], vp[3])

        buffer += 1
    }
    glPopAttrib()

    if OGL_CheckError() != 0 {
        SwFatalAlert("DrawBlueLine failed")
    }
}

// MARK: - OGL: Get current viewport

// Remember that with OpenGL, the bottom of the screen is y==0, so some of this code
// may look upside down.

func OGL_GetCurrentViewport(_ x: UnsafeMutablePointer<Int32>!, _ y: UnsafeMutablePointer<Int32>!, _ w: UnsafeMutablePointer<Int32>!, _ h: UnsafeMutablePointer<Int32>!, _ whichPane: UInt8) {
    let t = Int32(gGameViewInfoPtr!.pointee.clip.top)
    let b = Int32(gGameViewInfoPtr!.pointee.clip.bottom)
    let l = Int32(gGameViewInfoPtr!.pointee.clip.left)
    let r = Int32(gGameViewInfoPtr!.pointee.clip.right)

    if Int(whichPane) >= getOverlayPaneNumber() {
        x.pointee = l
        y.pointee = t
        w.pointee = gGameWindowWidth - l - r
        h.pointee = gGameWindowHeight - t - b
    } else {
        switch gActiveSplitScreenMode {
        case UInt8(SplitscreenMode.none.rawValue):
            x.pointee = l
            y.pointee = t
            w.pointee = gGameWindowWidth - l - r
            h.pointee = gGameWindowHeight - t - b

        case UInt8(SplitscreenMode.horizontal.rawValue):
            x.pointee = l
            w.pointee = gGameWindowWidth - l - r
            h.pointee = (gGameWindowHeight - l - r) / 2
            switch whichPane {
            case 0:
                y.pointee = t + (gGameWindowHeight - l - r) / 2

            case 1:
                y.pointee = t

            default:
                break
            }

        case UInt8(SplitscreenMode.vertical.rawValue):
            w.pointee = (gGameWindowWidth - l - r) / 2
            h.pointee = gGameWindowHeight - t - b
            y.pointee = t
            switch whichPane {
            case 0:
                x.pointee = l

            case 1:
                x.pointee = l + (gGameWindowWidth - l - r) / 2

            default:
                break
            }

        default:
            break
        }
    }
}

// MARK: - OGL texturemap load

// INPUT:
//			textureInRAM = true if OpenGL is to use the texture directly from imageMemory.
//							In this case we are in control of the texture, and must remember to delete it later

func OGL_TextureMap_Load(_ imageMemory: UnsafeMutableRawPointer!, _ width: Int32, _ height: Int32, _ destFormat: GLint, _ srcFormat: GLint, _ dataType: GLint) -> GLuint {
    if isStereoAnaglyphColor() {
        ConvertTextureToColorAnaglyph(imageMemory, Int16(width), Int16(height), srcFormat, dataType)
    } else if isStereoAnaglyphMono() {
        ConvertTextureToGrey(imageMemory, Int16(width), Int16(height), srcFormat, dataType)
    }

    // GET A UNIQUE TEXTURE NAME & INITIALIZE IT, LOAD TEXTURE AND/OR MIPMAPS
    //
    // Legacy GL-typed shim (see RenderBackend.swift's header): translate the
    // (srcFormat, dataType) pair to the facade's neutral pixel format. Every
    // caller passes srcFormat GL_RGBA; only dataType varies (and only in
    // theory - see RBPixelFormat).
    let format: RBPixelFormat
    switch dataType {
    case GLint(GL_UNSIGNED_INT_8_8_8_8_REV): format = .rgba8888Rev
    case GLint(GL_UNSIGNED_SHORT_1_5_5_5_REV): format = .rgba1555Rev
    default: format = .rgba8
    }

    let textureName = gEngine.renderer.createTexture(
        width: width, height: height, format: format, pixels: imageMemory)

    // SEE IF RAN OUT OF MEMORY WHILE COPYING TO OPENGL

    _ = OGL_CheckError()

    // SET THIS TEXTURE AS CURRENTLY ACTIVE FOR DRAWING

    OGL_Texture_SetOpenGLTexture(textureName)

    return textureName
}

// MARK: - OGL texturemap load from PNG/JPG

func OGL_TextureMap_LoadImageFile(_ partialPath: String, _ outWidth: UnsafeMutablePointer<Int32>!, _ outHeight: UnsafeMutablePointer<Int32>!, _ outHasAlpha: UnsafeMutablePointer<Int32>!) -> GLuint {
    var dummySpec = FSSpec()
    let partialPathStr = partialPath
    var jpgExists = false
    var pngExists = false
    var colorPixels: UnsafeMutablePointer<UInt8>?
    var width: Int32 = 0
    var height: Int32 = 0
    var textureName: GLuint = 0

    // Try to load a JPEG file first.
    let jpgPath = partialPathStr + ".jpg"
    jpgExists = kNoErr == SwFSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, jpgPath, &dummySpec)
    if jpgExists {
        var jpgLength: Int = 0
        let jpgData = LoadDataFile(jpgPath, &jpgLength)
        SwGameAssert(jpgData != nil)

        colorPixels = stbi_load_from_memory(UnsafeRawPointer(jpgData!).assumingMemoryBound(to: UInt8.self), Int32(jpgLength), &width, &height, nil, 4)
        SwGameAssert(colorPixels != nil)

        SafeDisposePtr(UnsafeMutableRawPointer(jpgData))
    }

    // Now try to load the PNG version of the same image.
    // If we've already loaded a JPEG, the PNG is used as an alpha mask.
    // Otherwise, load the PNG as an RGBA image.
    let pngPath = partialPathStr + ".png"
    pngExists = kNoErr == SwFSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, pngPath, &dummySpec)
    if pngExists {
        var pngLength: Int = 0
        let pngData = LoadDataFile(pngPath, &pngLength)
        SwGameAssert(pngData != nil)

        if colorPixels == nil {
            // We haven't loaded a JPEG, so the PNG will serve as an RGBA image.
            colorPixels = stbi_load_from_memory(UnsafeRawPointer(pngData!).assumingMemoryBound(to: UInt8.self), Int32(pngLength), &width, &height, nil, 4)
            SwGameAssert(colorPixels != nil)
        } else {
            var alphaWidth: Int32 = 0
            var alphaHeight: Int32 = 0

            // Load PNG as alpha
            let alphaPixels = stbi_load_from_memory(UnsafeRawPointer(pngData!).assumingMemoryBound(to: UInt8.self), Int32(pngLength), &alphaWidth, &alphaHeight, nil, 1)

            SwGameAssert(alphaPixels != nil)

            // Apply alpha channel to existing colorPixels
            SwGameAssert(colorPixels != nil) // we must have read colors from the JPEG file prior

            if alphaWidth != width || alphaHeight != height {
                SwFatalAlert("\(#function): PNG mask dimensions must match JPEG file: \(pngPath)")
            }

            // Merge alpha into color pixels
            var a = 0
            var c = 3
            while a < Int(width * height) {
                colorPixels![c] = alphaPixels![a]
                a += 1
                c += 4
            }

            SafeDisposePtr(UnsafeMutableRawPointer(alphaPixels))
        }

        SafeDisposePtr(UnsafeMutableRawPointer(pngData))
    }

    // See if texture file was missing
    if colorPixels == nil {
        SwFatalAlert("\(#function): Texture file missing: \(partialPathStr)")
    }

    // Load colorPixels as OpenGL texture
    textureName = OGL_TextureMap_Load(
        UnsafeMutableRawPointer(colorPixels),
        width,
        height,
        GL_RGBA,
        GL_RGBA,
        GLint(GL_UNSIGNED_BYTE))

    _ = OGL_CheckError()
    SwGameAssert(textureName != 0)

    SafeDisposePtr(UnsafeMutableRawPointer(colorPixels))

    if let outWidth { outWidth.pointee = width }
    if let outHeight { outHeight.pointee = height }
    if let outHasAlpha { outHasAlpha.pointee = pngExists ? 1 : 0 }

    return textureName
}

// MARK: - Convert texture to grey

// The NTSC luminance standard where grayscale = .299r + .587g + .114b

private func ConvertTextureToGrey(_ imageMemory: UnsafeMutableRawPointer!, _ width: Int16, _ height: Int16, _ srcFormat: GLint, _ dataType: GLint) {
    let redCal = UInt32(gGamePrefs.anaglyphCalibrationRed)
    let blueCal = UInt32(gGamePrefs.anaglyphCalibrationBlue)

    if dataType == GL_UNSIGNED_INT_8_8_8_8_REV {
        var pix32 = imageMemory.assumingMemoryBound(to: UInt32.self)
        for _ in 0..<Int(height) {
            for x in 0..<Int(width) {
                let pix = pix32[x]

                let r = Float((pix >> 16) & 0xff) / 255.0 * 0.299
                let g = Float((pix >> 8) & 0xff) / 255.0 * 0.586
                let b = Float(pix & 0xff) / 255.0 * 0.114
                let a = (pix >> 24) & 0xff

                var q = UInt32((r + g + b) * 255.0) // pass thru the brightness curve
                if q > 0xff { q = 0xff }
                q = UInt32(gAnaglyphGreyTable[Int(q)])

                let rq = (q * redCal) / 0xff // balance the red & blue
                let bq = (q * blueCal) / 0xff

                pix32[x] = (a << 24) | (rq << 16) | (q << 8) | bq
            }
            pix32 += Int(width)
        }
    } else if dataType == GL_UNSIGNED_BYTE && srcFormat == GL_RGBA {
        var pix32 = imageMemory.assumingMemoryBound(to: UInt32.self)
        for _ in 0..<Int(height) {
            for x in 0..<Int(width) {
                var raw = pix32[x]
                let pix = SwizzleULong(&raw)

                let r = Float((pix >> 24) & 0xff) / 255.0 * 0.299
                let g = Float((pix >> 16) & 0xff) / 255.0 * 0.586
                let b = Float((pix >> 8) & 0xff) / 255.0 * 0.114
                let a = pix & 0xff

                var q = UInt32((r + g + b) * 255.0) // pass thru the brightness curve
                if q > 0xff { q = 0xff }
                q = UInt32(gAnaglyphGreyTable[Int(q)])

                let rq = (q * redCal) / 0xff // balance the red & blue
                let bq = (q * blueCal) / 0xff

                var outPix = (rq << 24) | (q << 16) | (bq << 8) | a
                pix32[x] = SwizzleULong(&outPix)
            }
            pix32 += Int(width)
        }
    } else if dataType == GL_UNSIGNED_SHORT_1_5_5_5_REV {
        var pix16 = imageMemory.assumingMemoryBound(to: UInt16.self)
        for _ in 0..<Int(height) {
            for x in 0..<Int(width) {
                let pix = pix16[x]

                let r = Float((pix >> 10) & 0x1f) / 31.0 * 0.299
                let g = Float((pix >> 5) & 0x1f) / 31.0 * 0.586
                let b = Float(pix & 0x1f) / 31.0 * 0.114
                let a = pix & 0x8000

                var q32 = UInt32((r + g + b) * 255.0) // pass thru the brightness curve
                if q32 > 0xff { q32 = 0xff }
                q32 = UInt32(gAnaglyphGreyTable[Int(q32)])

                var rq32 = (q32 * redCal) / 0xff // balance the red & blue
                var bq32 = (q32 * blueCal) / 0xff

                q32 = UInt32(Float(q32) / 8.0)
                if q32 > 0x1f { q32 = 0x1f }

                rq32 = UInt32(Float(rq32) / 8.0)
                if rq32 > 0x1f { rq32 = 0x1f }
                bq32 = UInt32(Float(bq32) / 8.0)
                if bq32 > 0x1f { bq32 = 0x1f }

                pix16[x] = a | (UInt16(rq32) << 10) | (UInt16(q32) << 5) | UInt16(bq32)
            }
            pix16 += Int(width)
        }
    }
}

// MARK: - Color balance RGB for anaglyph

func ColorBalanceRGBForAnaglyph(_ rr: UnsafeMutablePointer<UInt32>!, _ gg: UnsafeMutablePointer<UInt32>!, _ bb: UnsafeMutablePointer<UInt32>!, _ allowChannelBalancing: UInt8) {
    var r = rr.pointee
    var g = gg.pointee
    var b = bb.pointee

    // ADJUST FOR USER CALIBRATION

    r = r * UInt32(gGamePrefs.anaglyphCalibrationRed) / 255
    b = b * UInt32(gGamePrefs.anaglyphCalibrationBlue) / 255
    g = g * UInt32(gGamePrefs.anaglyphCalibrationGreen) / 255

    // DO LUMINOSITY CHANNEL BALANCING

    if allowChannelBalancing != 0 && gGamePrefs.doAnaglyphChannelBalancing != 0 {
        let fr = Float(r)
        let fg = Float(g)
        let fb = Float(b)

        var lumR = fr * 0.299
        var lumGB = fg * 0.587 + fb * 0.114

        lumR += 1.0
        lumGB += 1.0

        // BALANCE BLUE

        var ratio = lumR / lumGB
        ratio *= 1.5
        var d = fb * ratio
        if d > fb {
            b = UInt32(d)
            if b > 0xff { b = 0xff }
        }

        // SMALL BALANCE ON GREEN

        ratio *= 0.8
        d = fg * ratio
        if d > fg {
            g = UInt32(d)
            if g > 0xff { g = 0xff }
        }

        // BALANCE RED

        ratio = lumGB / lumR
        ratio *= 0.4
        d = fr * ratio
        if d > fr {
            r = UInt32(d)
            if r > 0xff { r = 0xff }
        }
    }

    rr.pointee = r
    gg.pointee = g
    bb.pointee = b
}

// MARK: - Convert texture to color anaglyph

private func ConvertTextureToColorAnaglyph(_ imageMemory: UnsafeMutableRawPointer!, _ width: Int16, _ height: Int16, _ srcFormat: GLint, _ dataType: GLint) {
    if dataType == GL_UNSIGNED_INT_8_8_8_8_REV {
        var pix32 = imageMemory.assumingMemoryBound(to: UInt32.self)
        for _ in 0..<Int(height) {
            for x in 0..<Int(width) {
                let pix = pix32[x]

                let a = (pix >> 24) & 0xff
                var r = (pix >> 16) & 0xff
                var g = (pix >> 8) & 0xff
                var b = (pix >> 0) & 0xff

                ColorBalanceRGBForAnaglyph(&r, &g, &b, 1)

                pix32[x] = (a << 24) | (r << 16) | (g << 8) | b
            }
            pix32 += Int(width)
        }
    } else if dataType == GL_UNSIGNED_BYTE && srcFormat == GL_RGBA {
        var pix32 = imageMemory.assumingMemoryBound(to: UInt32.self)
        for _ in 0..<Int(height) {
            for x in 0..<Int(width) {
                var raw = pix32[x]
                let pix = SwizzleULong(&raw)

                let a = (pix >> 0) & 0xff
                var r = (pix >> 24) & 0xff
                var g = (pix >> 16) & 0xff
                var b = (pix >> 8) & 0xff

                ColorBalanceRGBForAnaglyph(&r, &g, &b, 1)

                var outPix = (r << 24) | (g << 16) | (b << 8) | a
                pix32[x] = SwizzleULong(&outPix)
            }
            pix32 += Int(width)
        }
    } else if dataType == GL_UNSIGNED_SHORT_1_5_5_5_REV {
        var pix16 = imageMemory.assumingMemoryBound(to: UInt16.self)
        for _ in 0..<Int(height) {
            for x in 0..<Int(width) {
                let pix = pix16[x]

                var r = UInt32((pix >> 10) & 0x1f) << 3 // load 5 bits per channel & convert to 8 bits
                var g = UInt32((pix >> 5) & 0x1f) << 3
                var b = UInt32(pix & 0x1f) << 3
                let a = pix & 0x8000

                ColorBalanceRGBForAnaglyph(&r, &g, &b, 1)

                r >>= 3
                g >>= 3
                b >>= 3

                pix16[x] = a | (UInt16(r) << 10) | (UInt16(g) << 5) | UInt16(b)
            }
            pix16 += Int(width)
        }
    }
}

// MARK: - OGL: RAM texture has changed

func OGL_RAMTextureHasChanged(_ textureName: GLuint, _ width: Int16, _ height: Int16, _ pixels: UnsafeMutablePointer<UInt32>!) {
    gEngine.renderer.updateTexture(textureName, width: Int32(width), height: Int32(height), bgraPixels: pixels)
}

// MARK: - OGL: Texture set OpenGL texture

// Sets the current OpenGL texture using glBindTexture et.al. so any textured triangles will use it.

func OGL_Texture_SetOpenGLTexture(_ textureName: GLuint) {
    gEngine.renderer.bindTexture(textureName)
    if OGL_CheckError() != 0 {
        SwFatalAlert("OGL_Texture_SetOpenGLTexture: glBindTexture failed!")
    }

    OGL_EnableTexture2D()
}

// MARK: - OGL_MoveCameraFromTo

func OGL_MoveCameraFromTo(_ fromDX: Float, _ fromDY: Float, _ fromDZ: Float, _ toDX: Float, _ toDY: Float, _ toDZ: Float, _ camNum: Int32) {
    // SET CAMERA COORDS

    let placements = cameraPlacementsBase()
    placements[Int(camNum)].cameraLocation.x += fromDX
    placements[Int(camNum)].cameraLocation.y += fromDY
    placements[Int(camNum)].cameraLocation.z += fromDZ

    placements[Int(camNum)].pointOfInterest.x += toDX
    placements[Int(camNum)].pointOfInterest.y += toDY
    placements[Int(camNum)].pointOfInterest.z += toDZ

    UpdateListenerLocation()
}

// MARK: - OGL_MoveCameraFrom

func OGL_MoveCameraFrom(_ fromDX: Float, _ fromDY: Float, _ fromDZ: Float, _ camNum: UInt8) {
    // SET CAMERA COORDS

    let placements = cameraPlacementsBase()
    placements[Int(camNum)].cameraLocation.x += fromDX
    placements[Int(camNum)].cameraLocation.y += fromDY
    placements[Int(camNum)].cameraLocation.z += fromDZ

    UpdateListenerLocation()
}

// MARK: - OGL_UpdateCameraFromTo

// from and to are both optional as nil

func OGL_UpdateCameraFromTo(_ from: UnsafeMutablePointer<OGLPoint3D>?, _ to: UnsafeMutablePointer<OGLPoint3D>?, _ camNum: Int32) {
    let up = OGLVector3D(x: 0, y: 1, z: 0)

    if camNum < 0 || camNum >= MAX_VIEWPORTS {
        SwFatalAlert("OGL_UpdateCameraFromTo: illegal camNum")
    }

    let placements = cameraPlacementsBase()
    placements[Int(camNum)].upVector = up

    if let from {
        placements[Int(camNum)].cameraLocation = from.pointee
    }

    if let to {
        placements[Int(camNum)].pointOfInterest = to.pointee
    }

    UpdateListenerLocation()
}

// MARK: - OGL_UpdateCameraFromToUp

func OGL_UpdateCameraFromToUp(_ from: UnsafeMutablePointer<OGLPoint3D>!, _ to: UnsafeMutablePointer<OGLPoint3D>!, _ up: UnsafePointer<OGLVector3D>!, _ camNum: Int32) {
    if camNum < 0 || camNum >= MAX_VIEWPORTS {
        SwFatalAlert("OGL_UpdateCameraFromToUp: illegal camNum")
    }

    let placements = cameraPlacementsBase()
    placements[Int(camNum)].upVector = up.pointee
    placements[Int(camNum)].cameraLocation = from.pointee
    placements[Int(camNum)].pointOfInterest = to.pointee

    UpdateListenerLocation()
}

// MARK: - OGL: Camera set placement & update matrices

// This is called by OGL_DrawScene to initialize all of the view matrices,
// and to extract the current view matrices used for culling et.al.

func OGL_Camera_SetPlacementAndUpdateMatrices(_ camNum: Int32) {
    var tempX: Int32 = 0
    var tempY: Int32 = 0
    var w: Int32 = 0
    var h: Int32 = 0
    OGL_GetCurrentViewport(&tempX, &tempY, &w, &h, 0)
    let aspect = Float(w) / Float(h)

    // INIT PROJECTION MATRIX

    gEngine.renderer.matrixMode(.projection)
    gEngine.renderer.loadIdentity()

    let placements = cameraPlacementsBase()
    let fov = fovBase()

    // SETUP FOR ANAGLYPH STEREO 3D CAMERA

    if isStereo() {
        var left: Float
        var right: Float
        let halfFOV = fov[Int(camNum)] * 0.5
        let znear = gGameViewInfoPtr!.pointee.hither
        let wd2 = znear * tan(halfFOV)
        let ndfl = znear / gAnaglyphFocallength

        if gAnaglyphPass == 0 {
            left = -aspect * wd2 + 0.5 * gAnaglyphEyeSeparation * ndfl
            right = aspect * wd2 + 0.5 * gAnaglyphEyeSeparation * ndfl
        } else {
            left = -aspect * wd2 - 0.5 * gAnaglyphEyeSeparation * ndfl
            right = aspect * wd2 - 0.5 * gAnaglyphEyeSeparation * ndfl
        }

        gEngine.renderer.frustum(Double(left), Double(right), Double(-wd2), Double(wd2), Double(gGameViewInfoPtr!.pointee.hither), Double(gGameViewInfoPtr!.pointee.yon))
    } else {
        // SETUP STANDARD PERSPECTIVE CAMERA

        OGL_SetGluPerspectiveMatrix(
            &gViewToFrustumMatrix, // projection
            fov[Int(camNum)], // our version uses radians for the fov (unlike GLU)
            aspect,
            gGameViewInfoPtr!.pointee.hither,
            gGameViewInfoPtr!.pointee.yon)

        gEngine.renderer.matrixMode(.projection)
        withUnsafeMutablePointer(to: &gViewToFrustumMatrix) {
            UnsafeMutableRawPointer($0).withMemoryRebound(to: Float.self, capacity: 16) { gEngine.renderer.loadMatrix($0) }
        }
    }

    // INIT MODELVIEW MATRIX

    OGL_SetGluLookAtMatrix(
        &gWorldToViewMatrix, // modelview
        &placements[Int(camNum)].cameraLocation,
        &placements[Int(camNum)].pointOfInterest,
        &placements[Int(camNum)].upVector)

    gEngine.renderer.matrixMode(.modelview)
    withUnsafeMutablePointer(to: &gWorldToViewMatrix) {
        UnsafeMutableRawPointer($0).withMemoryRebound(to: Float.self, capacity: 16) { gEngine.renderer.loadMatrix($0) }
    }

    // UPDATE LIGHT POSITIONS

    do {
        let lights = gGameViewInfoPtr!.pointer(to: \.lightList)!
        gEngine.renderer.updateLightPositions(
            numFillLights: Int32(lights.pointee.numFillLights),
            fillDirections: fillDirectionBase(lights))
    }

    // GET VARIOUS CAMERA MATRICES
    //
    // The readbacks re-fetch exactly what was loaded above (modelview from
    // OGL_SetGluLookAtMatrix, projection from OGL_SetGluPerspectiveMatrix) -
    // load-bearing only in stereo mode, where frustum() computed the
    // projection backend-side. Portable now: matrix-stack-tracking backends
    // serve these from their CPU-side stacks.
    withUnsafeMutablePointer(to: &gWorldToViewMatrix) {
        UnsafeMutableRawPointer($0).withMemoryRebound(to: Float.self, capacity: 16) { gEngine.renderer.getModelViewMatrix($0) }
    }
    withUnsafeMutablePointer(to: &gLocalToViewMatrix) {
        UnsafeMutableRawPointer($0).withMemoryRebound(to: Float.self, capacity: 16) { gEngine.renderer.getModelViewMatrix($0) }
    }
    withUnsafeMutablePointer(to: &gViewToFrustumMatrix) {
        UnsafeMutableRawPointer($0).withMemoryRebound(to: Float.self, capacity: 16) { gEngine.renderer.getProjectionMatrix($0) }
    }
    gLocalToFrustumMatrix = gLocalToViewMatrix.multiplied(by: gViewToFrustumMatrix)
    gWorldToFrustumMatrix = gWorldToViewMatrix.multiplied(by: gViewToFrustumMatrix)

    let frustumToWindow = gFrustumToWindowMatrixBase()
    (frustumToWindow + Int(camNum)).pointee.setFrustumToWindow(pane: camNum)
    let worldToWindow = gWorldToWindowMatrixBase()
    (worldToWindow + Int(camNum)).pointee = gLocalToFrustumMatrix.multiplied(by: (frustumToWindow + Int(camNum)).pointee)

    UpdateListenerLocation()
}

@inline(__always) private func gFrustumToWindowMatrixBase() -> UnsafeMutablePointer<OGLMatrix4x4> {
    withUnsafeMutablePointer(to: &gFrustumToWindowMatrix) {
        UnsafeMutableRawPointer($0).assumingMemoryBound(to: OGLMatrix4x4.self)
    }
}

// MARK: - OGL: Check error

func OGL_CheckError_Impl(_ file: String, _ line: Int32) -> GLenum {
    let error = gEngine.renderer.checkError()
    if error != 0 {
        var text = ""
        switch Int32(error) {
        case GL_INVALID_ENUM: text = "invalid enum"
        case GL_INVALID_VALUE: text = "invalid value"
        case GL_INVALID_OPERATION: text = "invalid operation"
        case GL_STACK_OVERFLOW: text = "stack overflow"
        case GL_STACK_UNDERFLOW: text = "stack underflow"
        default: text = ""
        }

        SwFatalAlert("OpenGL error 0x\(String(error, radix: 16)) (\(text))\nin \(file):\(line)")
    }
    return error
}

// MARK: - Push state

func OGL_PushState() {
    // PUSH MATRIES WITH OPENGL

    gEngine.renderer.matrixMode(.modelview)
    gEngine.renderer.pushMatrix()
    gEngine.renderer.matrixMode(.projection)
    gEngine.renderer.pushMatrix()

    gEngine.renderer.matrixMode(.modelview) // in my code, I keep modelview matrix as the currently active one all the time.

    // SAVE OTHER INFO

    let i = gStateStackIndex
    gStateStackIndex += 1 // get stack index and increment

    if i >= kStateStackSize {
        SwFatalAlert("OGL_PushState: stack overflow")
    }

    gStateStack_Lighting[i] = (gMyState_Lighting != 0)
    gStateStack_CullFace[i] = gMyState_CullFace
    gStateStack_DepthTest[i] = gMyState_DepthTest
    gStateStack_Texture2D[i] = gMyState_Texture2D
    gStateStack_Fog[i] = gMyState_Fog
    gStateStack_Blend[i] = gMyState_Blend
    gStateStack_Color[i] = gMyState_Color

    gStateStack_BlendSrc[i] = GLint(gMyState_BlendFuncS)
    gStateStack_BlendDst[i] = GLint(gMyState_BlendFuncD)

    gStateStack_Normalize[i] = gMyState_Normalize
    gStateStack_DepthMask[i] = gMyState_DepthMask ? 1 : 0
}

// MARK: - Pop state

func OGL_PopState() {
    // RETREIVE OPENGL MATRICES

    gEngine.renderer.matrixMode(.projection)
    gEngine.renderer.popMatrix()
    gEngine.renderer.matrixMode(.modelview)
    gEngine.renderer.popMatrix()

    // GET OTHER INFO

    gStateStackIndex -= 1 // dec stack index
    let i = gStateStackIndex

    if i < 0 {
        SwFatalAlert("OGL_PopState: stack underflow!")
    }

    if gStateStack_Lighting[i] {
        OGL_EnableLighting()
    } else {
        OGL_DisableLighting()
    }

    if gStateStack_CullFace[i] {
        OGL_EnableCullFace()
    } else {
        OGL_DisableCullFace()
    }

    if gStateStack_DepthTest[i] {
        OGL_EnableDepthTest()
    } else {
        OGL_DisableDepthTest()
    }

    if gStateStack_Texture2D[i] {
        OGL_EnableTexture2D()
    } else {
        OGL_DisableTexture2D()
    }

    if gStateStack_Blend[i] {
        OGL_EnableBlend()
    } else {
        OGL_DisableBlend()
    }

    if gStateStack_Fog[i] {
        OGL_EnableFog()
    } else {
        OGL_DisableFog()
    }

    OGL_SetNormalizeNormals(gStateStack_Normalize[i])
    OGL_SetDepthWrite(gStateStack_DepthMask[i] != 0)

    OGL_BlendFunc(GLenum(gStateStack_BlendSrc[i]), GLenum(gStateStack_BlendDst[i]))
    OGL_SetColor4fv(&gStateStack_Color[i])
}

// MARK: - OGL enable lighting

func OGL_EnableLighting() {
    if gMyState_Lighting == 0 {
        gMyState_Lighting = 1
        gEngine.renderer.enableLighting()
    }
}

// MARK: - OGL disable lighting

func OGL_DisableLighting() {
    if gMyState_Lighting != 0 {
        gMyState_Lighting = 0
        gEngine.renderer.disableLighting()
    }
}

// MARK: - OGL enable blend

func OGL_EnableBlend() {
    if !gMyState_Blend {
        gMyState_Blend = true
        gEngine.renderer.enableBlend()
    }
}

// MARK: - OGL disable blend

func OGL_DisableBlend() {
    if gMyState_Blend {
        gMyState_Blend = false
        gEngine.renderer.disableBlend()
    }
}

// MARK: - OGL enable texture 2D

func OGL_EnableTexture2D() {
    // DO STATE CACHINE FOR UNIT 0

    if gMyState_TextureUnit == UInt32(GL_TEXTURE0) {
        if !gMyState_Texture2D {
            gMyState_Texture2D = true
            gEngine.renderer.enableTexture2D()
        }
    } else {
        // FOR ALL OTHER TEXTURE UNITS JUST DO IT

        gEngine.renderer.enableTexture2D()
    }
}

// MARK: - OGL disable texture 2D

func OGL_DisableTexture2D() {
    // DO STATE CACHINE FOR UNIT 0

    if gMyState_TextureUnit == UInt32(GL_TEXTURE0) {
        if gMyState_Texture2D {
            gMyState_Texture2D = false
            gEngine.renderer.disableTexture2D()
        }
    } else {
        // FOR ALL OTHER TEXTURE UNITS JUST DO IT

        gEngine.renderer.disableTexture2D()
    }
}

// MARK: - OGL: Active texture unit

// Sets the currently active texture unit for GL_TEXTURE0...n

func OGL_ActiveTextureUnit(_ texUnit: UInt32) {
    // Legacy GL-typed shim: callers pass GL_TEXTURE0 + n; the facade takes
    // a plain unit index.
    gEngine.renderer.activeTextureUnit(Int32(texUnit) - GL_TEXTURE0)

    gMyState_TextureUnit = texUnit
}

// MARK: - OGL set color 4fv

func OGL_SetColor4fv(_ color: UnsafeMutablePointer<OGLColorRGBA>!) {
    if color.pointee.r != gMyState_Color.r ||
        color.pointee.g != gMyState_Color.g ||
        color.pointee.b != gMyState_Color.b ||
        color.pointee.a != gMyState_Color.a
    {
        gEngine.renderer.setColor4f(color.pointee.r, color.pointee.g, color.pointee.b, color.pointee.a)

        gMyState_Color = color.pointee
    }
}

// MARK: - OGL set color 4f

func OGL_SetColor4f(_ r: Float, _ g: Float, _ b: Float, _ a: Float) {
    if r != gMyState_Color.r ||
        g != gMyState_Color.g ||
        b != gMyState_Color.b ||
        a != gMyState_Color.a
    {
        gEngine.renderer.setColor4f(r, g, b, a)

        gMyState_Color.r = r
        gMyState_Color.g = g
        gMyState_Color.b = b
        gMyState_Color.a = a
    }
}

// MARK: - OGL enable cull face

func OGL_EnableCullFace() {
    if !gMyState_CullFace {
        gMyState_CullFace = true
        gEngine.renderer.enableCullFace()
    }
}

// MARK: - OGL disable cull face

func OGL_DisableCullFace() {
    if gMyState_CullFace {
        gMyState_CullFace = false
        gEngine.renderer.disableCullFace()
    }
}

// MARK: - OGL enable fog

func OGL_EnableFog() {
    if !gMyState_Fog {
        gMyState_Fog = true
        gEngine.renderer.enableFog()
    }
}

// MARK: - OGL disable fog

func OGL_DisableFog() {
    if gMyState_Fog {
        gMyState_Fog = false
        gEngine.renderer.disableFog()
    }
}

// MARK: - OGL enable/disable depth test

// Cached, unlike a plain gEngine.renderer.enableDepthTest() call, so
// OGL_PushState/OGL_PopState (below) can read back "is depth test on?"
// without GL introspection (glIsEnabled) - needed so those functions (called
// by every 2D draw: MO_DrawPicture, Atlas_DrawString2, ...) don't require a
// live GL context, which --metal mode no longer creates.

func OGL_EnableDepthTest() {
    if !gMyState_DepthTest {
        gMyState_DepthTest = true
        gEngine.renderer.enableDepthTest()
    }
}

func OGL_DisableDepthTest() {
    if gMyState_DepthTest {
        gMyState_DepthTest = false
        gEngine.renderer.disableDepthTest()
    }
}

// MARK: - OGL blend func

// Legacy GL-typed shim (see RenderBackend.swift's header): call sites all
// over the codebase pass GL blend-factor enums; translate to the facade's
// neutral factors here. Only the pairs the game actually uses are mapped.
private func rbBlendFactor(_ glFactor: GLenum) -> RBBlendFactor {
    switch Int32(glFactor) {
    case GL_ONE: return .one
    case GL_SRC_ALPHA: return .srcAlpha
    case GL_ONE_MINUS_SRC_ALPHA: return .oneMinusSrcAlpha
    default:
        SwFatal("OGL_BlendFunc: unmapped GL blend factor \(glFactor)")
        return .one
    }
}

func OGL_BlendFunc(_ sfactor: GLenum, _ dfactor: GLenum) {
    if sfactor != gMyState_BlendFuncS || dfactor != gMyState_BlendFuncD {
        gEngine.renderer.blendFunc(rbBlendFactor(sfactor), rbBlendFactor(dfactor))

        gMyState_BlendFuncS = sfactor
        gMyState_BlendFuncD = dfactor
    }
}

// MARK: - OGL_Init font

private func OGL_InitFont() {
}

// MARK: - OGL_Free font

private func OGL_FreeFont() {
}

// MARK: - OGL_Draw string

func OGL_DrawString(_ s: String, _ x: GLint, _ y: GLint) {
    OGL_PushState()

    gEngine.renderer.matrixMode(.modelview)
    gEngine.renderer.loadIdentity()
    gEngine.renderer.matrixMode(.projection)
    gEngine.renderer.loadIdentity()
    gEngine.renderer.ortho(0, 640, 480, 0, -10.0, 10.0)

    OGL_DisableLighting()
    gEngine.renderer.setColorMaterialEnabled(true)

    OGL_SetColor4f(1, 1, 1, 1)

    Atlas_DrawString2(Int32(ATLAS_GROUP_FONT2), s, Float(x), Float(y), 0.25, 0.25, 0, UInt32(kTextMeshAlignLeft) | UInt32(kTextMeshAllCaps))

    OGL_PopState()
}

// MARK: - OGL_Draw float

func OGL_DrawFloat(_ f: Float, _ x: GLint, _ y: GLint) {
    OGL_DrawString("\(f)", x, y)
}

// MARK: - OGL_Draw int

func OGL_DrawInt(_ f: Int32, _ x: GLint, _ y: GLint) {
    OGL_DrawString("\(f)", x, y)
}

// MARK: - OGL init vertex array memory

// This game will try to put all Vertex Array data in a common block of memory so that
// we an use GL_APPLE_vertex_array_range to get massive performance boosts.
//
// So, to do this we need to allocate a large block of memory and then implement our
// own memory management within that block so that we can put as much vertex array
// data there as possible.
//
// Most if not all of this allocation is done at init time, so performance isn't crucial.
//
// Basically, this memory system is implemented as a linked list where each
// node represents a block of memory which we've allocated out of our commom block.
//
// There are two independant systems here: one for vertex array memory which is Shared, and one for Cached.
// Shared memory is that which we can modify freely with no speed penalty by doing so.
// Cached is that which gets stored in VRAM so we don't want to modify it often.

private func OGL_InitVertexArrayMemory() {
    if gVARMemoryAllocated {
        SwFatalAlert("OGL_InitVertexArrayMemory: memory already allocated.")
    }

    // INIT THE LINKED LIST HEAD & TAIL PTRS

    gVertexArrayMemory_Head = [UnsafeMutablePointer<VertexArrayMemoryNode>?](repeating: nil, count: Int(VertexArrayRangeType._count.rawValue))
    gVertexArrayMemory_Tail = [UnsafeMutablePointer<VertexArrayMemoryNode>?](repeating: nil, count: Int(VertexArrayRangeType._count.rawValue))
    gVertexArrayMemoryBlock = [UnsafeMutableRawPointer?](repeating: nil, count: Int(VertexArrayRangeType._count.rawValue))

    // ALLOCATE MASTER BLOCK FOR NON-"USER" V.A.R. TYPES

    for i in 0..<Int(VertexArrayRangeType.user1.rawValue) {
        gVertexArrayMemoryBlock[i] = AllocPtrClear(OGL_MaxMemForVARType(VertexArrayRangeType(rawValue: UInt32(i))!))
    }

    // WE'RE DONE

    gVARMemoryAllocated = true
}

// MARK: - OGL: Disable vertex array ranges

private func OGL_DisableVertexArrayRanges() {
    if !gVARMemoryAllocated {
        SwFatalAlert("OGL_DisableVertexArrayRanges: VAR already off.")
    }

    // FREE UP THE MEMORY
    // Only for non-"User" types. "User" types don't have allocated memory.

    for i in 0..<Int(VertexArrayRangeType.user1.rawValue) {
        if gVertexArrayMemoryBlock[i] != nil {
            SafeDisposePtr(gVertexArrayMemoryBlock[i])
            gVertexArrayMemoryBlock[i] = nil
        }
    }

    gVARMemoryAllocated = false
}

// MARK: - OGL alloc vertex array memory

// Call this function to get a section of our vertex array ranged memory

func OGL_AllocVertexArrayMemory(_ size: Int, _ type: UInt8) -> UnsafeMutableRawPointer! {
    if type >= UInt8(VertexArrayRangeType.user1.rawValue) { // can't allocate memory for the "User" Types
        SwFatalAlert("OGL_AllocVertexArrayMemory: illegal type")
    }

    if !gVARMemoryAllocated {
        SwFatalAlert("OGL_AllocVertexArrayMemory: not initialized")
    }

    // TO BE SAFE, LETS ROUND UP THE SIZE TO THE NEAREST MULTIPLE OF 16

    let roundedSize = (size + 15) & 0xffff_fff0

    let newNode = AllocPtrClear(MemoryLayout<VertexArrayMemoryNode>.size)!.assumingMemoryBound(to: VertexArrayMemoryNode.self) // allocate the node (assume we'll find room for it below)
    newNode.pointee.size = roundedSize // remember how big a chunk we're allocating

    var scanNode = gVertexArrayMemory_Head[Int(type)] // start scanning @ front

    // SEE IF THIS IS THE ONLY ALLOCATION

    if scanNode == nil {
        newNode.pointee.pointer = gVertexArrayMemoryBlock[Int(type)] // point to the front of the master block
        newNode.pointee.prevNode = nil
        newNode.pointee.nextNode = nil

        gVertexArrayMemory_Head[Int(type)] = newNode
        gVertexArrayMemory_Tail[Int(type)] = newNode

        return newNode.pointee.pointer
    }

    // SCAN THRU NODES LOOKING FOR A SPACE TO FIT

    var prevEndPtr = gVertexArrayMemoryBlock[Int(type)]!.advanced(by: -1) // pretend like a node ended before the master block
    while true {
        let freeSpace = scanNode!.pointee.pointer! - prevEndPtr - 1 // how much memory is between these nodes?
        if freeSpace >= roundedSize { // is this big enough for us?
            // INSERT A NEW NODE BEFORE THE CURRENT ONE

            newNode.pointee.pointer = prevEndPtr.advanced(by: 1) // allocate immediately after the end of the previous node

            newNode.pointee.prevNode = scanNode!.pointee.prevNode
            newNode.pointee.nextNode = scanNode

            scanNode!.pointee.prevNode = newNode

            if newNode.pointee.prevNode == nil { // is our new node the head?
                gVertexArrayMemory_Head[Int(type)] = newNode
            } else {
                newNode.pointee.prevNode!.pointee.nextNode = newNode
            }

            return newNode.pointee.pointer
        }

        prevEndPtr = scanNode!.pointee.pointer!.advanced(by: scanNode!.pointee.size - 1) // calc new end ptr

        scanNode = scanNode!.pointee.nextNode

        if scanNode == nil {
            break
        }
    }

    // IT WOULDN'T FIT BEFORE ANY EXISTING NODES, SO TACK IT ONTO THE END

    // WILL OUR NEW ALLOCATION FIT AT THE END?

    let tail = gVertexArrayMemory_Tail[Int(type)]!
    prevEndPtr = tail.pointee.pointer!.advanced(by: tail.pointee.size - 1) // calc end of allocations

    if UInt(bitPattern: prevEndPtr) + UInt(roundedSize) >= UInt(bitPattern: gVertexArrayMemoryBlock[Int(type)]!) + UInt(OGL_MaxMemForVARType(VertexArrayRangeType(rawValue: UInt32(type))!)) { // would this allocation go over our master block's range?
        SafeDisposePtr(UnsafeMutableRawPointer(newNode))

        SwFatalAlert("OGL_AllocVertexArrayMemory:  Master Block is full! Type \(type)")

        return nil
    }

    // YEP IT'LL FIT

    newNode.pointee.pointer = prevEndPtr.advanced(by: 1)

    newNode.pointee.prevNode = tail
    newNode.pointee.nextNode = nil

    tail.pointee.nextNode = newNode

    gVertexArrayMemory_Tail[Int(type)] = newNode

    return newNode.pointee.pointer
}

// MARK: - OGL: Free vertex array memory

func OGL_FreeVertexArrayMemory(_ pointer: UnsafeMutableRawPointer!, _ type: UInt8) {
    if type >= UInt8(VertexArrayRangeType.user1.rawValue) { // can't free memory for the "User" Types
        SwFatalAlert("OGL_FreeVertexArrayMemory: illegal type")
    }

    // IF NOT USING V-A-R THEN JUST DISPOSE REGULAR

    if !gVARMemoryAllocated {
        SwFatalAlert("OGL_FreeVertexArrayMemory: not initialized")
    }

    // SCAN THE LINKED LIST FOR THE MATCHING NODE

    var scanNode = gVertexArrayMemory_Head[Int(type)] // start scanning @ front

    while let node = scanNode {
        if node.pointee.pointer == pointer { // does this node match our pointer
            // REMOVE THE NODE FROM THE LINKED LIST

            let prev = node.pointee.prevNode
            let next = node.pointee.nextNode

            if let prev { // patch the prev node
                prev.pointee.nextNode = next
            } else {
                gVertexArrayMemory_Head[Int(type)] = next
            }

            if let next { // patch the next node
                next.pointee.prevNode = prev
            } else {
                gVertexArrayMemory_Tail[Int(type)] = prev
            }

            SafeDisposePtr(UnsafeMutableRawPointer(node)) // delete the node

            return
        }
        scanNode = node.pointee.nextNode
    }

    // IF GETS HERE THEN NO MATCH WAS FOUND

    SwFatalAlert("OGL_FreeVertexArrayMemory: no matching pointer found!")
}

// MARK: - OGL: Set vertex array range dirty

// Call this to force a Vertex Array range to be updated after modifying geometry
//
// (VERTEXARRAYRANGES is 0 - the original body was entirely behind that flag, so this is a no-op, matching the current C build.)

func OGL_SetVertexArrayRangeDirty(_ buffer: Int16) {
}

// MARK: - OGL: Max mem for VAR type

// Defines how much RAM to allocate for the Vertex Array Range buffers.

private func OGL_MaxMemForVARType(_ varType: VertexArrayRangeType) -> Int {
    switch varType {
    case .particles1, .particles2:
        return 6_000_000

    case .bg3dModels:
        return 6_000_000

    case .terrain:
        return 8_000_000

    case .zaps1, .zaps2:
        return 300_000

    case .skeletons, .skeletons2:
        return 5_000_000

    default:
        return 1_000_000
    }
}
