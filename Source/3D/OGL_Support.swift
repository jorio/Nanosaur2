// OGL_Support.swift - Port of OGL_Support.c to Swift
//
// gAnaglyphFocallength, gAnaglyphEyeSeparation, gAnaglyphPass, gAGLContext,
// gViewToFrustumMatrix, gWorldToViewMatrix, gWorldToFrustumMatrix,
// gLocalToViewMatrix, gLocalToFrustumMatrix, gWorldToWindowMatrix,
// gCurrentSplitScreenPane, gActiveSplitScreenMode, gCurrentPaneAspectRatio,
// gMyState_Lighting, gMyState_Color, gPolysThisFrame, and
// gVertexArrayRangeObjects/gUsingVertexArrayRange stay defined here (not as
// private Swift storage) and `extern`'d via game.h: they're read/written
// directly by other files (already-ported and still-C alike).
// gFrustumToWindowMatrix, gStateStack_*, gMyState_Blend/Fog/Texture2D/
// CullFace/TextureUnit/BlendFuncS/BlendFuncD, gAnaglyphGreyTable,
// gDoAnisotropy, gMaxAnisotropy, and the vertex-array-memory bookkeeping
// (gVARMemoryAllocated, gVertexArrayMemoryBlock, gVertexArrayMemory_Head/
// Tail) were never `extern`'d anywhere (either already `static`, or
// non-static but referenced nowhere else) - they move into private Swift
// storage instead, as plain Swift arrays where the C original used a fixed
// array (nothing external needs pointer access to them).
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

private typealias GLActiveTextureProc = @convention(c) (GLenum) -> Void
private var gGlActiveTextureProc: GLActiveTextureProc?
private var gGlClientActiveTextureProc: GLActiveTextureProc?

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
private var gMyState_TextureUnit: UInt32 = 0
private var gMyState_BlendFuncS: GLenum = 0
private var gMyState_BlendFuncD: GLenum = 0

// MARK: - Macro shims (parameterless/parameterized macros aren't importable)

@inline(__always) private func isStereo() -> Bool { gGamePrefs.stereoGlassesMode != UInt8(StereoGlassesMode.off.rawValue) }
@inline(__always) private func isStereoShutter() -> Bool { gGamePrefs.stereoGlassesMode == UInt8(StereoGlassesMode.shutter.rawValue) }
@inline(__always) private func isStereoAnaglyphColor() -> Bool { gGamePrefs.stereoGlassesMode == UInt8(StereoGlassesMode.anaglyphColor.rawValue) }
@inline(__always) private func isStereoAnaglyphMono() -> Bool { gGamePrefs.stereoGlassesMode == UInt8(StereoGlassesMode.anaglyphMono.rawValue) }
@inline(__always) private func isStereoAnaglyph() -> Bool { isStereoAnaglyphColor() || isStereoAnaglyphMono() }
@inline(__always) private func getOverlayPaneNumber() -> Int { Int(gNumPlayers) }

@inline(__always) private func OGL_CheckError() -> GLenum {
    OGL_CheckError_Impl(#file, Int32(#line))
}

// MARK: - Fixed-array-field helpers (all struct fields, never unions)

@inline(__always) private func gWorldToWindowMatrixBase() -> UnsafeMutablePointer<OGLMatrix4x4> {
    withUnsafeMutablePointer(to: &gWorldToWindowMatrix) {
        UnsafeMutableRawPointer($0).assumingMemoryBound(to: OGLMatrix4x4.self)
    }
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

    gGameViewInfoPtr!.pointee.isActive = 1 // it's now an active structure

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

    gGameViewInfoPtr!.pointee.fadeSound = 0 // by default, don't fade out sound when exiting scene
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

    gGameViewInfoPtr!.pointee.isActive = 0 // now inactive
    SafeDisposePtr(UnsafeMutableRawPointer(gGameViewInfoPtr))
    gGameViewInfoPtr = nil
}

// MARK: - OGL: Create draw context

// Call this ONCE when booting the game.
// The source port reuses a single draw context throughout the lifespan of the program.

private func OGL_CreateDrawContext() {
    SwGameAssertMessage(gAGLContext == nil, "GL context already exists")
    SwGameAssertMessage(gSDLWindow != nil, "Window must be created before the DC!")

    // CREATE AGL CONTEXT & ATTACH TO WINDOW

    gAGLContext = SDL_GL_CreateContext(gSDLWindow)

    if gAGLContext == nil {
        SwFatalAlert(String(cString: SDL_GetError()))
    }

    SwGameAssert(glGetError() == GL_NO_ERROR)

    // ACTIVATE CONTEXT

    let didMakeCurrent = SDL_GL_MakeCurrent(gSDLWindow, gAGLContext)
    SwGameAssertMessage(didMakeCurrent, String(cString: SDL_GetError()))

    // ENABLE VSYNC

    _ = SDL_GL_SetSwapInterval(Int32(gGamePrefs.vsync))

    // SEE IF SUPPORT 2048x2048 TEXTURES

    var maxTexSize: GLint = 0
    glGetIntegerv(GLenum(GL_MAX_TEXTURE_SIZE), &maxTexSize)
    if maxTexSize < 2048 {
        SwFatalAlert("Your video card cannot do 2048x2048 textures, so it is below the game's minimum system requirements.")
    }

    // GET GL PROCEDURES
    // Necessary on Windows

    gGlActiveTextureProc = unsafeBitCast(SDL_GL_GetProcAddress("glActiveTexture"), to: GLActiveTextureProc?.self)
    SwGameAssert(gGlActiveTextureProc != nil)

    gGlClientActiveTextureProc = unsafeBitCast(SDL_GL_GetProcAddress("glClientActiveTexture"), to: GLActiveTextureProc?.self)
    SwGameAssert(gGlClientActiveTextureProc != nil)
}

// MARK: - OGL: Nuke draw context

// Do this when QUITTING the game!
// The game reuses the same draw context for all scenes!

private func OGL_DisposeDrawContext() {
    guard gAGLContext != nil else {
        return
    }

    _ = SDL_GL_MakeCurrent(gSDLWindow, nil) // make context not current
    SDL_GL_DestroyContext(gAGLContext) // nuke context
    gAGLContext = nil
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

    glClearColor(def!.pointee.view.clearColor.r, def!.pointee.view.clearColor.g, def!.pointee.view.clearColor.b, 1.0)
    glEnable(GLenum(GL_DEPTH_TEST)) // use z-buffer

    var color: [GLfloat] = [1, 1, 1, 1] // set global material color to white
    glMaterialfv(GLenum(GL_FRONT_AND_BACK), GLenum(GL_AMBIENT_AND_DIFFUSE), &color)

    glColorMaterial(GLenum(GL_FRONT_AND_BACK), GLenum(GL_AMBIENT_AND_DIFFUSE))
    glEnable(GLenum(GL_COLOR_MATERIAL))

    glEnable(GLenum(GL_NORMALIZE))

    // INIT DEBUG FONT

    OGL_InitFont()
}

// MARK: - OGL: Set styles

private func OGL_SetStyles(_ setupDefPtr: UnsafeMutablePointer<OGLSetupInputType>!) {
    gMyState_CullFace = false
    OGL_EnableCullFace()
    glCullFace(GLenum(GL_BACK))
    glFrontFace(GLenum(GL_CCW)) // CCW is front face
    _ = OGL_CheckError()

    // SET BLENDING DEFAULTS

    gMyState_BlendFuncS = 0
    gMyState_BlendFuncD = 0
    OGL_BlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA)) // set default blend func

    gMyState_Blend = true
    OGL_DisableBlend()
    _ = OGL_CheckError()

    glDisable(GLenum(GL_RESCALE_NORMAL))
    _ = OGL_CheckError()

    gMyState_TextureUnit = UInt32(GL_TEXTURE0_ARB)
    OGL_ActiveTextureUnit(UInt32(GL_TEXTURE0_ARB))
    gMyState_Texture2D = true
    OGL_DisableTexture2D()
    _ = OGL_CheckError()

    gMyState_Color.r = 0.1
    gMyState_Color.g = 0.1
    gMyState_Color.b = 0.1
    gMyState_Color.a = 0.1
    OGL_SetColor4f(1, 1, 1, 1)

    // ENABLE ALPHA CHANNELS

    glEnable(GLenum(GL_ALPHA_TEST))
    glAlphaFunc(GLenum(GL_NOTEQUAL), 0) // draw any pixel who's Alpha != 0
    _ = OGL_CheckError()

    // SET FOG

    glHint(GLenum(GL_FOG_HINT), GLenum(GL_FASTEST))

    let styleDefPtr = setupDefPtr!.pointer(to: \.styles)!
    if styleDefPtr.pointee.useFog != 0 {
        glFogi(GLenum(GL_FOG_MODE), GLint(styleDefPtr.pointee.fogMode))
        glFogf(GLenum(GL_FOG_DENSITY), styleDefPtr.pointee.fogDensity)
        glFogf(GLenum(GL_FOG_START), styleDefPtr.pointee.fogStart)
        glFogf(GLenum(GL_FOG_END), styleDefPtr.pointee.fogEnd)
        withUnsafeMutablePointer(to: &setupDefPtr!.pointee.view.clearColor.r) {
            glFogfv(GLenum(GL_FOG_COLOR), $0)
        }
        gMyState_Fog = false
        OGL_EnableFog()
    } else {
        gMyState_Fog = true
        OGL_DisableFog()
    }
    _ = OGL_CheckError()

    // ANISOTRIPIC FILTERING

    if gDoAnisotropy {
        glGetFloatv(GLenum(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT), &gMaxAnisotropy)
    }
    _ = OGL_CheckError()
}

// MARK: - Clear all buffers to black

private func ClearAllBuffersToBlack() {
    glClearColor(0, 0, 0, 1)
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
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT)) // clear buffer
        SDL_GL_SwapWindow(gSDLWindow)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT)) // clear buffer
        SDL_GL_SwapWindow(gSDLWindow)

        _ = OGL_CheckError()
    }
}

// MARK: - OGL: Create lights

// NOTE: The Projection matrix must be the identity or lights will be transformed.

private func OGL_CreateLights(_ lightDefPtr: UnsafeMutablePointer<OGLLightDefType>!) {
    gMyState_Lighting = 0
    OGL_EnableLighting()

    // CREATE AMBIENT LIGHT

    var ambient: [GLfloat] = [
        lightDefPtr.pointee.ambientColor.r,
        lightDefPtr.pointee.ambientColor.g,
        lightDefPtr.pointee.ambientColor.b,
        1,
    ]
    glLightModelfv(GLenum(GL_LIGHT_MODEL_AMBIENT), &ambient) // set scene ambient light

    // CREATE FILL LIGHTS

    let fillDirection = fillDirectionBase(lightDefPtr)
    let fillColor = fillColorBase(lightDefPtr)

    for i in 0..<Int(lightDefPtr.pointee.numFillLights) {
        var lightamb: [GLfloat] = [0.0, 0.0, 0.0, 1.0]
        var lightVec = [GLfloat](repeating: 0, count: 4)
        var diffuse = [GLfloat](repeating: 0, count: 4)

        // SET FILL DIRECTION

        fillDirection[i] = fillDirection[i].normalized()
        lightVec[0] = -fillDirection[i].x // negate vector because OGL is stupid
        lightVec[1] = -fillDirection[i].y
        lightVec[2] = -fillDirection[i].z
        lightVec[3] = 0 // when w==0, this is a directional light, if 1 then point light
        glLightfv(GLenum(GL_LIGHT0) + GLenum(i), GLenum(GL_POSITION), &lightVec)

        // SET COLOR

        glLightfv(GLenum(GL_LIGHT0) + GLenum(i), GLenum(GL_AMBIENT), &lightamb)

        diffuse[0] = fillColor[i].r
        diffuse[1] = fillColor[i].g
        diffuse[2] = fillColor[i].b
        diffuse[3] = 1

        glLightfv(GLenum(GL_LIGHT0) + GLenum(i), GLenum(GL_DIFFUSE), &diffuse)

        glEnable(GLenum(GL_LIGHT0) + GLenum(i)) // enable the light
    }

    // NUKE ANY FILL LIGHTS REMAINING FROM PREVIOUS SCENE

    for i in Int(lightDefPtr.pointee.numFillLights)..<Int(MAX_FILL_LIGHTS) {
        glDisable(GLenum(GL_LIGHT0) + GLenum(i))
    }
}

// MARK: - OGL draw scene

func OGL_DrawScene(_ drawRoutine: (@convention(c) () -> Void)!) {
    SDL_GetWindowSizeInPixels(gSDLWindow, &gGameWindowWidth, &gGameWindowHeight)

    if gGameViewInfoPtr!.pointee.isActive == 0 {
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
                    glColorMask(1, 1, 1, 1) // make sure clearing Red/Green/Blue channels
                } else if isStereoAnaglyphMono() {
                    glColorMask(1, 0, 1, 1) // make sure clearing Red/Blue channels
                }

                glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT))
            } else {
                glClear(GLbitfield(GL_DEPTH_BUFFER_BIT))
            }
        }

        // SEE IF DOING ANAGLYPH

        if isStereoAnaglyph() {
            // SET COLOR MASK

            if gAnaglyphPass == 0 {
                glColorMask(1, 0, 0, 1)
            } else {
                if isStereoAnaglyphColor() {
                    glColorMask(0, 1, 1, 1)
                } else {
                    glColorMask(0, 0, 1, 1)
                }
                glClear(GLbitfield(GL_DEPTH_BUFFER_BIT))
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
            glViewport(x, y, w, h)
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

        if gDebugMode == 3 { // see if show wireframe
            glPolygonMode(GLenum(GL_FRONT_AND_BACK), GLenum(GL_LINE))
        } else {
            glPolygonMode(GLenum(GL_FRONT_AND_BACK), GLenum(GL_FILL))
        }
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

    SDL_GL_SwapWindow(gSDLWindow) // end render loop

    if gGamePaused == 0 { // freeze frame count if paused (otherwise double-buffered skeletons will flicker)
        gGameViewInfoPtr!.pointee.frameCount += 1 // inc frame count AFTER drawing (so that the previous Move calls were in sync with this draw frame count)
    }

    if isStereo() {
        RestoreCamerasFromAnaglyph()
    }
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

    // GET A UNIQUE TEXTURE NAME & INITIALIZE IT

    var textureName: GLuint = 0
    glGenTextures(1, &textureName)
    _ = OGL_CheckError()

    glBindTexture(GLenum(GL_TEXTURE_2D), textureName) // this is now the currently active texture
    _ = OGL_CheckError()

    // LOAD TEXTURE AND/OR MIPMAPS

    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)

    glTexImage2D(GLenum(GL_TEXTURE_2D),
                 0, // mipmap level
                 destFormat, // format in OpenGL
                 width, // width in pixels
                 height, // height in pixels
                 0, // border
                 GLenum(srcFormat), // what my format is
                 GLenum(dataType), // size of each r,g,b
                 imageMemory) // pointer to the actual texture pixels

    // SEE IF RAN OUT OF MEMORY WHILE COPYING TO OPENGL

    _ = OGL_CheckError()

    // SET THIS TEXTURE AS CURRENTLY ACTIVE FOR DRAWING

    OGL_Texture_SetOpenGLTexture(textureName)

    return textureName
}

// MARK: - OGL texturemap load from PNG/JPG

func OGL_TextureMap_LoadImageFile(_ partialPath: UnsafePointer<CChar>!, _ outWidth: UnsafeMutablePointer<Int32>!, _ outHeight: UnsafeMutablePointer<Int32>!, _ outHasAlpha: UnsafeMutablePointer<Int32>!) -> GLuint {
    var dummySpec = FSSpec()
    let partialPathStr = String(cString: partialPath)
    var jpgExists = false
    var pngExists = false
    var colorPixels: UnsafeMutablePointer<UInt8>?
    var width: Int32 = 0
    var height: Int32 = 0
    var textureName: GLuint = 0

    // Try to load a JPEG file first.
    let jpgPath = partialPathStr + ".jpg"
    jpgExists = kNoErr == FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, jpgPath, &dummySpec)
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
    pngExists = kNoErr == FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, pngPath, &dummySpec)
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
    glBindTexture(GLenum(GL_TEXTURE_2D), textureName) // this is now the currently active texture

    glTexSubImage2D(GLenum(GL_TEXTURE_2D), 0, 0, 0, Int32(width), Int32(height), GLenum(GL_BGRA), GLenum(GL_UNSIGNED_INT_8_8_8_8_REV), pixels)
}

// MARK: - OGL: Texture set OpenGL texture

// Sets the current OpenGL texture using glBindTexture et.al. so any textured triangles will use it.

func OGL_Texture_SetOpenGLTexture(_ textureName: GLuint) {
    glBindTexture(GLenum(GL_TEXTURE_2D), textureName)
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

    glMatrixMode(GLenum(GL_PROJECTION))
    glLoadIdentity()

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

        glFrustum(Double(left), Double(right), Double(-wd2), Double(wd2), Double(gGameViewInfoPtr!.pointee.hither), Double(gGameViewInfoPtr!.pointee.yon))
    } else {
        // SETUP STANDARD PERSPECTIVE CAMERA

        OGL_SetGluPerspectiveMatrix(
            &gViewToFrustumMatrix, // projection
            fov[Int(camNum)], // our version uses radians for the fov (unlike GLU)
            aspect,
            gGameViewInfoPtr!.pointee.hither,
            gGameViewInfoPtr!.pointee.yon)

        glMatrixMode(GLenum(GL_PROJECTION))
        withUnsafeMutablePointer(to: &gViewToFrustumMatrix) {
            UnsafeMutableRawPointer($0).withMemoryRebound(to: Float.self, capacity: 16) { glLoadMatrixf($0) }
        }
    }

    // INIT MODELVIEW MATRIX

    OGL_SetGluLookAtMatrix(
        &gWorldToViewMatrix, // modelview
        &placements[Int(camNum)].cameraLocation,
        &placements[Int(camNum)].pointOfInterest,
        &placements[Int(camNum)].upVector)

    glMatrixMode(GLenum(GL_MODELVIEW))
    withUnsafeMutablePointer(to: &gWorldToViewMatrix) {
        UnsafeMutableRawPointer($0).withMemoryRebound(to: Float.self, capacity: 16) { glLoadMatrixf($0) }
    }

    // UPDATE LIGHT POSITIONS

    let lights = gGameViewInfoPtr!.pointer(to: \.lightList)!
    let fillDirection = fillDirectionBase(lights)
    for i in 0..<Int(lights.pointee.numFillLights) {
        var lightVec = [GLfloat](repeating: 0, count: 4)

        lightVec[0] = -fillDirection[i].x // negate vector because OGL is stupid
        lightVec[1] = -fillDirection[i].y
        lightVec[2] = -fillDirection[i].z
        lightVec[3] = 0 // when w==0, this is a directional light, if 1 then point light
        glLightfv(GLenum(GL_LIGHT0) + GLenum(i), GLenum(GL_POSITION), &lightVec)
    }

    // GET VARIOUS CAMERA MATRICES

    withUnsafeMutablePointer(to: &gWorldToViewMatrix) {
        UnsafeMutableRawPointer($0).withMemoryRebound(to: Float.self, capacity: 16) { glGetFloatv(GLenum(GL_MODELVIEW_MATRIX), $0) }
    }
    withUnsafeMutablePointer(to: &gLocalToViewMatrix) {
        UnsafeMutableRawPointer($0).withMemoryRebound(to: Float.self, capacity: 16) { glGetFloatv(GLenum(GL_MODELVIEW_MATRIX), $0) }
    }
    withUnsafeMutablePointer(to: &gViewToFrustumMatrix) {
        UnsafeMutableRawPointer($0).withMemoryRebound(to: Float.self, capacity: 16) { glGetFloatv(GLenum(GL_PROJECTION_MATRIX), $0) }
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

func OGL_CheckError_Impl(_ file: UnsafePointer<CChar>!, _ line: Int32) -> GLenum {
    let error = glGetError()
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

        SwFatalAlert("OpenGL error 0x\(String(error, radix: 16)) (\(text))\nin \(String(cString: file)):\(line)")
    }
    return error
}

// MARK: - Push state

func OGL_PushState() {
    // PUSH MATRIES WITH OPENGL

    glMatrixMode(GLenum(GL_MODELVIEW))
    glPushMatrix()
    glMatrixMode(GLenum(GL_PROJECTION))
    glPushMatrix()

    glMatrixMode(GLenum(GL_MODELVIEW)) // in my code, I keep modelview matrix as the currently active one all the time.

    // SAVE OTHER INFO

    let i = gStateStackIndex
    gStateStackIndex += 1 // get stack index and increment

    if i >= kStateStackSize {
        SwFatalAlert("OGL_PushState: stack overflow")
    }

    gStateStack_Lighting[i] = (gMyState_Lighting != 0)
    gStateStack_CullFace[i] = gMyState_CullFace
    gStateStack_DepthTest[i] = glIsEnabled(GLenum(GL_DEPTH_TEST)) != 0
    gStateStack_Normalize[i] = glIsEnabled(GLenum(GL_NORMALIZE)) != 0
    gStateStack_Texture2D[i] = gMyState_Texture2D
    gStateStack_Fog[i] = glIsEnabled(GLenum(GL_FOG)) != 0
    gStateStack_Blend[i] = gMyState_Blend
    gStateStack_Color[i] = gMyState_Color

    gStateStack_BlendSrc[i] = GLint(gMyState_BlendFuncS)
    gStateStack_BlendDst[i] = GLint(gMyState_BlendFuncD)

    glGetBooleanv(GLenum(GL_DEPTH_WRITEMASK), &gStateStack_DepthMask[i])
}

// MARK: - Pop state

func OGL_PopState() {
    // RETREIVE OPENGL MATRICES

    glMatrixMode(GLenum(GL_PROJECTION))
    glPopMatrix()
    glMatrixMode(GLenum(GL_MODELVIEW))
    glPopMatrix()

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
        glEnable(GLenum(GL_DEPTH_TEST))
    } else {
        glDisable(GLenum(GL_DEPTH_TEST))
    }

    if gStateStack_Normalize[i] {
        glEnable(GLenum(GL_NORMALIZE))
    } else {
        glDisable(GLenum(GL_NORMALIZE))
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

    glDepthMask(gStateStack_DepthMask[i])

    OGL_BlendFunc(GLenum(gStateStack_BlendSrc[i]), GLenum(gStateStack_BlendDst[i]))
    OGL_SetColor4fv(&gStateStack_Color[i])
}

// MARK: - OGL enable lighting

func OGL_EnableLighting() {
    if gMyState_Lighting == 0 {
        gMyState_Lighting = 1
        glEnable(GLenum(GL_LIGHTING))
    }
}

// MARK: - OGL disable lighting

func OGL_DisableLighting() {
    if gMyState_Lighting != 0 {
        gMyState_Lighting = 0
        glDisable(GLenum(GL_LIGHTING))
    }
}

// MARK: - OGL enable blend

func OGL_EnableBlend() {
    if !gMyState_Blend {
        gMyState_Blend = true
        glEnable(GLenum(GL_BLEND))
    }
}

// MARK: - OGL disable blend

func OGL_DisableBlend() {
    if gMyState_Blend {
        gMyState_Blend = false
        glDisable(GLenum(GL_BLEND))
    }
}

// MARK: - OGL enable texture 2D

func OGL_EnableTexture2D() {
    // DO STATE CACHINE FOR UNIT 0

    if gMyState_TextureUnit == UInt32(GL_TEXTURE0) {
        if !gMyState_Texture2D {
            gMyState_Texture2D = true
            glEnable(GLenum(GL_TEXTURE_2D))
        }
    } else {
        // FOR ALL OTHER TEXTURE UNITS JUST DO IT

        glEnable(GLenum(GL_TEXTURE_2D))
    }
}

// MARK: - OGL disable texture 2D

func OGL_DisableTexture2D() {
    // DO STATE CACHINE FOR UNIT 0

    if gMyState_TextureUnit == UInt32(GL_TEXTURE0) {
        if gMyState_Texture2D {
            gMyState_Texture2D = false
            glDisable(GLenum(GL_TEXTURE_2D))
        }
    } else {
        // FOR ALL OTHER TEXTURE UNITS JUST DO IT

        glDisable(GLenum(GL_TEXTURE_2D))
    }
}

// MARK: - OGL: Active texture unit

// Sets the currently active texture unit for GL_TEXTURE0...n

func OGL_ActiveTextureUnit(_ texUnit: UInt32) {
    gGlActiveTextureProc?(texUnit)
    gGlClientActiveTextureProc?(texUnit)

    gMyState_TextureUnit = texUnit
}

// MARK: - OGL set color 4fv

func OGL_SetColor4fv(_ color: UnsafeMutablePointer<OGLColorRGBA>!) {
    if color.pointee.r != gMyState_Color.r ||
        color.pointee.g != gMyState_Color.g ||
        color.pointee.b != gMyState_Color.b ||
        color.pointee.a != gMyState_Color.a
    {
        UnsafeRawPointer(color).withMemoryRebound(to: Float.self, capacity: 4) { glColor4fv($0) }

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
        glColor4f(r, g, b, a)

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
        glEnable(GLenum(GL_CULL_FACE))
    }
}

// MARK: - OGL disable cull face

func OGL_DisableCullFace() {
    if gMyState_CullFace {
        gMyState_CullFace = false
        glDisable(GLenum(GL_CULL_FACE))
    }
}

// MARK: - OGL enable fog

func OGL_EnableFog() {
    if !gMyState_Fog {
        gMyState_Fog = true
        glEnable(GLenum(GL_FOG))
    }
}

// MARK: - OGL disable fog

func OGL_DisableFog() {
    if gMyState_Fog {
        gMyState_Fog = false
        glDisable(GLenum(GL_FOG))
    }
}

// MARK: - OGL blend func

func OGL_BlendFunc(_ sfactor: GLenum, _ dfactor: GLenum) {
    if sfactor != gMyState_BlendFuncS || dfactor != gMyState_BlendFuncD {
        glBlendFunc(sfactor, dfactor)

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

func OGL_DrawString(_ s: UnsafePointer<CChar>!, _ x: GLint, _ y: GLint) {
    OGL_PushState()

    glMatrixMode(GLenum(GL_MODELVIEW))
    glLoadIdentity()
    glMatrixMode(GLenum(GL_PROJECTION))
    glLoadIdentity()
    glOrtho(0, 640, 480, 0, -10.0, 10.0)

    glDisable(GLenum(GL_LIGHTING))
    glEnable(GLenum(GL_COLOR_MATERIAL))

    OGL_SetColor4f(1, 1, 1, 1)

    Atlas_DrawString2(Int32(ATLAS_GROUP_FONT2), s, Float(x), Float(y), 0.25, 0.25, 0, UInt32(kTextMeshAlignLeft) | UInt32(kTextMeshAllCaps))

    OGL_PopState()
}

// MARK: - OGL_Draw float

func OGL_DrawFloat(_ f: Float, _ x: GLint, _ y: GLint) {
    let s = "\(f)"
    s.withCString { OGL_DrawString($0, x, y) }
}

// MARK: - OGL_Draw int

func OGL_DrawInt(_ f: Int32, _ x: GLint, _ y: GLint) {
    let s = "\(f)"
    s.withCString { OGL_DrawString($0, x, y) }
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
