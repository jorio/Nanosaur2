// RenderBackend.swift
//
// The portable rendering facade (docs/metal-renderer-plan.md). The goal:
// every rendering call the game makes goes through this protocol, and the
// protocol's surface is backend-neutral - no GLenum/GLuint/GL semantics -
// so OpenGL, Metal, Vulkan, or Citro3D (3DS) are all "just" implementations.
// GLRenderBackend below is the reference implementation and reproduces the
// exact gl* calls the game made before the facade existed.
//
// Conventions:
// - The pervasive OGL_* wrapper functions (OGL_BlendFunc, OGL_TextureMap_Load,
//   ...) keep their legacy GL-typed signatures - hundreds of call sites use
//   them - and translate to neutral facade calls internally. The *facade
//   boundary* is what must stay portable, not every legacy shim above it.
// - State caching (gMyState_* in OGL_Support.swift) stays ABOVE the facade;
//   backends receive already-deduplicated state changes.
// - Immediate mode is wrapped verb-for-verb on purpose: every call site in
//   this codebase draws one self-contained primitive batch and ends it
//   immediately. GL forwards straight to glBegin/glVertex/glEnd; other
//   backends accumulate internally and emit one draw at endImmediate().
// - The matrix stack is part of the facade because the game's draw code
//   leans on push/translate/scale/pop nesting; backends without a hardware
//   matrix stack (all of them except GL) keep a CPU-side stack.
//
// Not yet behind the facade (see the plan doc's slice list): the indexed
// vertex-array geometry path, lighting/fog setup, GL state introspection in
// OGL_PushState/DrawBlueLine, stereo glColorMask/glDrawBuffer, dual-screen's
// second context, context creation, vertex-array-range memory, glReadPixels.

// MARK: - Neutral types

/// Immediate-mode primitive shapes the game actually uses.
enum RBPrimitive {
    case quads // independent quads per 4 vertices (GL_QUADS semantics)
    case triangles
    case lines
    case lineStrip
    case lineLoop
}

enum RBMatrixMode {
    case modelview
    case projection
    /// Texture-coordinate transform (UV scrolling via STATUS_BIT_UVTRANSFORM).
    case texture
}

/// Only the blend factors the game uses (standard alpha and additive glow).
enum RBBlendFactor {
    case one
    case srcAlpha
    case oneMinusSrcAlpha
}

enum RBTextureAxis {
    case u
    case v
}

/// Pixel layouts accepted by createTexture, mirroring the exact
/// (format, type) pairs the game feeds GL. In practice everything is
/// .rgba8; the other two are BG3D "imported model" paths that Nanosaur 2's
/// own data never hits.
enum RBPixelFormat {
    case rgba8 // (GL_RGBA, GL_UNSIGNED_BYTE) - stb_image, BG3D, terrain
    case rgba8888Rev // (GL_RGBA, GL_UNSIGNED_INT_8_8_8_8_REV)
    case rgba1555Rev // (GL_RGBA, GL_UNSIGNED_SHORT_1_5_5_5_REV)
}

/// Opaque texture handle. 0 means "no texture" (matches GL's convention so
/// legacy code storing texture names keeps working unchanged).
typealias RBTextureHandle = UInt32

/// The texture-combine modes the game uses for its second texture layer
/// (MULTI_TEXTURE_COMBINE_* in MetaObjects/Water): plain modulate, additive
/// RGB with modulated alpha, or additive RGB and alpha.
enum RBTextureEnv {
    case modulate
    case combineAdd
    case combineAddAlpha
}

enum RBFogMode {
    case linear
    case exp
    case exp2
}

// MARK: - Facade protocol

protocol RenderBackend: AnyObject {
    func enableBlend()
    func disableBlend()
    func blendFunc(_ src: RBBlendFactor, _ dst: RBBlendFactor)

    func enableTexture2D()
    func disableTexture2D()

    func enableLighting()
    func disableLighting()

    func enableCullFace()
    func disableCullFace()

    func enableFog()
    func disableFog()

    func enableDepthTest()
    func disableDepthTest()
    /// Depth-buffer *write* toggle, independent of the test.
    func setDepthWrite(_ enabled: Bool)

    /// The two alpha-test configurations the game ever uses
    /// (STATUS_BIT_CLIPALPHA6 in Objects.swift): trimLowAlpha=true trims
    /// pixels with alpha <= 0.6; false is the default "alpha != 0" test.
    func setAlphaClipping(trimLowAlpha: Bool)
    /// Turns the alpha test off/on entirely (terrain and a few items draw
    /// with it disabled; the scene default is enabled).
    func setAlphaTestEnabled(_ enabled: Bool)

    /// Two-sided lighting for thin geometry viewed from both sides
    /// (shards, confetti).
    func setTwoSidedLighting(_ enabled: Bool)

    /// Renormalize normals after scaling - only meaningful for the
    /// fixed-function lit 3D path.
    func setNormalizeNormals(_ enabled: Bool)

    func setColor4f(_ r: Float, _ g: Float, _ b: Float, _ a: Float)

    func matrixMode(_ mode: RBMatrixMode)
    func pushMatrix()
    func popMatrix()
    func loadIdentity()
    /// `m` points to 16 floats, column-major (same layout `OGLMatrix4x4`
    /// uses).
    func loadMatrix(_ m: UnsafePointer<Float>)
    /// Same layout as `loadMatrix`, but multiplies onto the current matrix
    /// instead of replacing it - used by `MO_DrawMatrix` for MetaObject
    /// group transforms.
    func multMatrix(_ m: UnsafePointer<Float>)
    /// Reads back the current modelview matrix (16 floats, column-major)
    /// - used to capture the composed object transform for collision plane
    /// math. GL introspects; matrix-stack-tracking backends copy their
    /// CPU-side top.
    func getModelViewMatrix(_ out: UnsafeMutablePointer<Float>)
    /// Reads back the current projection matrix - load-bearing only in
    /// stereo mode, where frustum() computed it backend-side.
    func getProjectionMatrix(_ out: UnsafeMutablePointer<Float>)
    /// Multiplies a perspective frustum onto the current matrix (glFrustum
    /// semantics) - stereo eye-offset projections.
    func frustum(_ left: Double, _ right: Double, _ bottom: Double, _ top: Double, _ near: Double, _ far: Double)
    /// Multiplies an orthographic projection onto the current matrix
    /// (glOrtho semantics - call sites always loadIdentity() first).
    func ortho(_ left: Double, _ right: Double, _ bottom: Double, _ top: Double, _ near: Double, _ far: Double)

    /// Binds a 2D texture so subsequent draws use it.
    func bindTexture(_ name: RBTextureHandle)

    /// Creates a linear-filtered 2D texture and returns an opaque handle.
    /// Every call site already treats texture names as opaque 32-bit IDs
    /// (stored in MOMaterialObject.objectData.textureName etc.), so
    /// non-GL backends hand back synthesized IDs into their own texture
    /// tables.
    func createTexture(width: Int32, height: Int32, format: RBPixelFormat, pixels: UnsafeRawPointer) -> RBTextureHandle
    /// Re-uploads pixels into an existing texture, keeping its size. The
    /// data is always BGRA8 (GL_UNSIGNED_INT_8_8_8_8_REV) - used for
    /// runtime-modified textures (anaglyph channel balancing).
    func updateTexture(_ name: RBTextureHandle, width: Int32, height: Int32, bgraPixels: UnsafeRawPointer)
    /// Frees `count` textures whose handles start at `names` (material
    /// disposal - a material owns one texture per mipmap level).
    func deleteTextures(_ names: UnsafePointer<RBTextureHandle>, count: Int32)

    func translate(_ x: Float, _ y: Float, _ z: Float)
    func scale(_ x: Float, _ y: Float, _ z: Float)
    /// `angle` is in degrees (matching the glRotatef call sites).
    func rotate(_ angle: Float, _ x: Float, _ y: Float, _ z: Float)

    func setTextureWrap(_ axis: RBTextureAxis, clamp: Bool)

    func beginImmediate(_ mode: RBPrimitive)
    func vertex2f(_ x: Float, _ y: Float)
    func vertex3f(_ x: Float, _ y: Float, _ z: Float)
    func texCoord2f(_ u: Float, _ v: Float)
    func endImmediate()

    /// Selects the texture unit (0 or 1) that subsequent bindTexture/
    /// enable/disableTexture2D/setTextureEnv/setSphereMapTexGen calls apply
    /// to. The game uses at most two units (base texture + reflection map /
    /// second material layer).
    func activeTextureUnit(_ unit: Int32)
    /// Sets how the active unit's texture combines with the incoming
    /// fragment.
    func setTextureEnv(_ mode: RBTextureEnv)
    /// Sphere-map texture-coordinate generation on the active unit
    /// (reflection mapping) - replaces per-vertex UVs when enabled.
    func setSphereMapTexGen(_ enabled: Bool)

    /// The one true 3D geometry path: indexed triangle lists
    /// (MO_DrawGeometry_VertexArray - terrain, skeletons, models, text
    /// meshes all funnel through it). Material/texture state is set up by
    /// the caller through the other verbs before this is called. Any nil
    /// array means "this geometry has no such data". `uv1` is the second
    /// texture layer's UVs (plain multi-texturing); sphere-map texgen
    /// replaces it for reflection mapping.
    func drawIndexedGeometry(
        points: UnsafePointer<OGLPoint3D>,
        normals: UnsafePointer<OGLVector3D>?,
        colors: UnsafePointer<OGLColorRGBA>?,
        uv0: UnsafePointer<OGLTextureCoord>?,
        uv1: UnsafePointer<OGLTextureCoord>?,
        triangles: UnsafePointer<MOTriangleIndecies>?,
        numTriangles: Int32)

    /// One-time fixed-function scene defaults applied when a game view is
    /// set up (OGL_SetupGameView): back-face culling with CCW front faces,
    /// baseline alpha test ("alpha != 0"), white color-tracking material,
    /// normal renormalization, fog hint. Backends without those fixed-
    /// function concepts treat this as a no-op.
    func prepareSceneDefaults()

    /// Full light rig for a scene: ambient color + `numFillLights`
    /// directional fill lights. Directions are already normalized, pointing
    /// from the light toward the scene.
    func setLights(ambientR: Float, ambientG: Float, ambientB: Float, numFillLights: Int32, fillDirections: UnsafePointer<OGLVector3D>, fillColors: UnsafePointer<OGLColorRGBA>)
    /// Re-sends the fill-light directions after the camera/modelview
    /// changed (fixed-function GL transforms light positions by the
    /// modelview current at set time, so this runs once per pane per frame).
    func updateLightPositions(numFillLights: Int32, fillDirections: UnsafePointer<OGLVector3D>)

    func setFog(mode: RBFogMode, density: Float, start: Float, end: Float, r: Float, g: Float, b: Float, a: Float)

    /// The common single-window per-frame sequence in `OGL_DrawScene`:
    /// viewport, clear, and swap/present. Stereo/dual-screen-specific calls
    /// (color-mask passes, buffer selection, second context) are not
    /// covered yet - see the plan doc.
    func setViewport(_ x: Int32, _ y: Int32, _ w: Int32, _ h: Int32)
    /// Sets the colour clearColorAndDepth() clears to (persistent state -
    /// set once, applies to every subsequent clear until changed).
    func setClearColor(_ r: Float, _ g: Float, _ b: Float)
    func clearColorAndDepth()
    func clearDepthOnly()
    func setWireframe(_ enabled: Bool)
    /// Presents the frame (GL: SDL_GL_SwapWindow).
    func present()

    /// Human-readable renderer description for the Settings screen's info
    /// line (GL: GL_RENDERER + GL_VERSION strings).
    func rendererInfo() -> String

    /// Per-channel color write mask (anaglyph stereo passes and the
    /// calibration screen). Backends without stereo support may no-op.
    func setColorMask(_ r: Bool, _ g: Bool, _ b: Bool, _ a: Bool)

    /// Color-material tracking (lit geometry takes its material color from
    /// the current vertex color). Part of prepareSceneDefaults; also
    /// re-asserted defensively by the debug-text path.
    func setColorMaterialEnabled(_ enabled: Bool)

    /// Polls and clears the backend's pending error state, returning 0 if
    /// none (GL: glGetError). Fatal-error plumbing in OGL_CheckError.
    func checkError() -> UInt32

    /// Creates the backend's rendering context/surface on gSDLWindow.
    /// Called once at boot from OGL_CreateDrawContext; fatal-alerts (does
    /// not return) if the platform can't provide a usable context.
    /// MetalRenderBackend is constructed already-active (see
    /// SwMetalBackend_Activate), so its implementation is a no-op.
    func createContext()
    /// Tears the context down at quit.
    func destroyContext()

    /// Vertical-sync swap interval (0 = off; the game only ever uses 0/1).
    func setVSync(_ interval: Int32)
    func getVSync() -> Int32
}

// MARK: - OpenGL implementation

// Desktop only: the 3DS renders through Citro3DRenderBackend
// (Source/3D/Citro3DBackend.swift over ports/3DS/common/c3d_renderer.c) -
// there is no GL implementation on that platform anymore (picaGL was
// removed), and the 3DS SDL_opengl.h stub deliberately declares no gl*
// prototypes so this class couldn't compile there anyway.
#if !NANOSAUR_3DS

final class GLRenderBackend: RenderBackend {
    // glActiveTexture/glClientActiveTexture must be fetched as proc
    // addresses (necessary on Windows; harmless on macOS). Loaded by
    // loadGLProcs() once the GL context exists - see OGL_CreateDrawContext.
    private typealias ActiveTextureProc = @convention(c) (GLenum) -> Void
    private var activeTextureProc: ActiveTextureProc?
    private var clientActiveTextureProc: ActiveTextureProc?

    func loadGLProcs() {
        #if NANOSAUR_SCREENSAVER
        // No SDL in the screen-saver bundle (ports/Darwin): the host view
        // owns the NSOpenGLContext, and OpenGL.framework is linked directly,
        // so plain dlsym resolves these (Saver_GLGetProcAddress, shim.c).
        activeTextureProc = unsafeBitCast(Saver_GLGetProcAddress("glActiveTexture"), to: ActiveTextureProc?.self)
        SwGameAssert(activeTextureProc != nil)

        clientActiveTextureProc = unsafeBitCast(Saver_GLGetProcAddress("glClientActiveTexture"), to: ActiveTextureProc?.self)
        SwGameAssert(clientActiveTextureProc != nil)
        #else
        activeTextureProc = unsafeBitCast(SDL.glProcAddress("glActiveTexture"), to: ActiveTextureProc?.self)
        SwGameAssert(activeTextureProc != nil)

        clientActiveTextureProc = unsafeBitCast(SDL.glProcAddress("glClientActiveTexture"), to: ActiveTextureProc?.self)
        SwGameAssert(clientActiveTextureProc != nil)
        #endif
    }

    func enableBlend() { glEnable(GLenum(GL_BLEND)) }
    func disableBlend() { glDisable(GLenum(GL_BLEND)) }
    func blendFunc(_ src: RBBlendFactor, _ dst: RBBlendFactor) {
        glBlendFunc(Self.glBlendFactor(src), Self.glBlendFactor(dst))
    }

    private static func glBlendFactor(_ f: RBBlendFactor) -> GLenum {
        switch f {
        case .one: return GLenum(GL_ONE)
        case .srcAlpha: return GLenum(GL_SRC_ALPHA)
        case .oneMinusSrcAlpha: return GLenum(GL_ONE_MINUS_SRC_ALPHA)
        }
    }

    func enableTexture2D() { glEnable(GLenum(GL_TEXTURE_2D)) }
    func disableTexture2D() { glDisable(GLenum(GL_TEXTURE_2D)) }

    func enableLighting() { glEnable(GLenum(GL_LIGHTING)) }
    func disableLighting() { glDisable(GLenum(GL_LIGHTING)) }

    func enableCullFace() { glEnable(GLenum(GL_CULL_FACE)) }
    func disableCullFace() { glDisable(GLenum(GL_CULL_FACE)) }

    func enableFog() { glEnable(GLenum(GL_FOG)) }
    func disableFog() { glDisable(GLenum(GL_FOG)) }

    func enableDepthTest() { glEnable(GLenum(GL_DEPTH_TEST)) }
    func disableDepthTest() { glDisable(GLenum(GL_DEPTH_TEST)) }
    func setDepthWrite(_ enabled: Bool) { glDepthMask(enabled ? 1 : 0) }

    func setAlphaClipping(trimLowAlpha: Bool) {
        if trimLowAlpha {
            glAlphaFunc(GLenum(GL_GREATER), 0.6) // draw any pixel who's Alpha > .6 (effectively trims low alpha pixels)
        } else {
            glAlphaFunc(GLenum(GL_NOTEQUAL), 0) // draw any pixel who's Alpha != 0
        }
    }

    func setNormalizeNormals(_ enabled: Bool) {
        if enabled {
            glEnable(GLenum(GL_NORMALIZE))
        } else {
            glDisable(GLenum(GL_NORMALIZE))
        }
    }

    func setAlphaTestEnabled(_ enabled: Bool) {
        if enabled {
            glEnable(GLenum(GL_ALPHA_TEST))
        } else {
            glDisable(GLenum(GL_ALPHA_TEST))
        }
    }

    func setTwoSidedLighting(_ enabled: Bool) {
        glLightModeli(GLenum(GL_LIGHT_MODEL_TWO_SIDE), enabled ? GL_TRUE : GL_FALSE)
    }

    func setColor4f(_ r: Float, _ g: Float, _ b: Float, _ a: Float) { glColor4f(r, g, b, a) }

    func matrixMode(_ mode: RBMatrixMode) {
        switch mode {
        case .modelview: glMatrixMode(GLenum(GL_MODELVIEW))
        case .projection: glMatrixMode(GLenum(GL_PROJECTION))
        case .texture: glMatrixMode(GLenum(GL_TEXTURE))
        }
    }

    func pushMatrix() { glPushMatrix() }
    func popMatrix() { glPopMatrix() }
    func loadIdentity() { glLoadIdentity() }
    func loadMatrix(_ m: UnsafePointer<Float>) { glLoadMatrixf(m) }
    func multMatrix(_ m: UnsafePointer<Float>) { glMultMatrixf(m) }
    func getModelViewMatrix(_ out: UnsafeMutablePointer<Float>) { glGetFloatv(GLenum(GL_MODELVIEW_MATRIX), out) }
    func getProjectionMatrix(_ out: UnsafeMutablePointer<Float>) { glGetFloatv(GLenum(GL_PROJECTION_MATRIX), out) }
    func frustum(_ left: Double, _ right: Double, _ bottom: Double, _ top: Double, _ near: Double, _ far: Double) {
        glFrustum(left, right, bottom, top, near, far)
    }
    func ortho(_ left: Double, _ right: Double, _ bottom: Double, _ top: Double, _ near: Double, _ far: Double) {
        glOrtho(left, right, bottom, top, near, far)
    }

    func bindTexture(_ name: RBTextureHandle) { glBindTexture(GLenum(GL_TEXTURE_2D), name) }

    func createTexture(width: Int32, height: Int32, format: RBPixelFormat, pixels: UnsafeRawPointer) -> RBTextureHandle {
        var textureName: GLuint = 0
        glGenTextures(1, &textureName)
        glBindTexture(GLenum(GL_TEXTURE_2D), textureName)

        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)

        let dataType: GLenum
        switch format {
        case .rgba8: dataType = GLenum(GL_UNSIGNED_BYTE)
        case .rgba8888Rev: dataType = GLenum(GL_UNSIGNED_INT_8_8_8_8_REV)
        case .rgba1555Rev: dataType = GLenum(GL_UNSIGNED_SHORT_1_5_5_5_REV)
        }
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGBA, width, height, 0, GLenum(GL_RGBA), dataType, pixels)

        return textureName
    }

    func updateTexture(_ name: RBTextureHandle, width: Int32, height: Int32, bgraPixels: UnsafeRawPointer) {
        glBindTexture(GLenum(GL_TEXTURE_2D), name)
        glTexSubImage2D(GLenum(GL_TEXTURE_2D), 0, 0, 0, width, height, GLenum(GL_BGRA), GLenum(GL_UNSIGNED_INT_8_8_8_8_REV), bgraPixels)
    }

    func deleteTextures(_ names: UnsafePointer<RBTextureHandle>, count: Int32) {
        glDeleteTextures(GLsizei(count), names)
    }

    func translate(_ x: Float, _ y: Float, _ z: Float) { glTranslatef(x, y, z) }
    func scale(_ x: Float, _ y: Float, _ z: Float) { glScalef(x, y, z) }
    func rotate(_ angle: Float, _ x: Float, _ y: Float, _ z: Float) { glRotatef(angle, x, y, z) }

    func setTextureWrap(_ axis: RBTextureAxis, clamp: Bool) {
        let target = axis == .u ? GLenum(GL_TEXTURE_WRAP_S) : GLenum(GL_TEXTURE_WRAP_T)
        glTexParameterf(GLenum(GL_TEXTURE_2D), target, Float(clamp ? GL_CLAMP_TO_EDGE : GL_REPEAT))
    }

    func beginImmediate(_ mode: RBPrimitive) {
        switch mode {
        case .quads: glBegin(GLenum(GL_QUADS))
        case .triangles: glBegin(GLenum(GL_TRIANGLES))
        case .lines: glBegin(GLenum(GL_LINES))
        case .lineStrip: glBegin(GLenum(GL_LINE_STRIP))
        case .lineLoop: glBegin(GLenum(GL_LINE_LOOP))
        }
    }

    func vertex2f(_ x: Float, _ y: Float) { glVertex2f(x, y) }
    func vertex3f(_ x: Float, _ y: Float, _ z: Float) { glVertex3f(x, y, z) }
    func texCoord2f(_ u: Float, _ v: Float) { glTexCoord2f(u, v) }
    func endImmediate() { glEnd() }

    func activeTextureUnit(_ unit: Int32) {
        let glUnit = GLenum(GL_TEXTURE0 + unit)
        activeTextureProc?(glUnit)
        clientActiveTextureProc?(glUnit)
    }

    func setTextureEnv(_ mode: RBTextureEnv) {
        switch mode {
        case .modulate:
            glTexEnvi(GLenum(GL_TEXTURE_ENV), GLenum(GL_TEXTURE_ENV_MODE), GL_MODULATE)
        case .combineAdd:
            glTexEnvi(GLenum(GL_TEXTURE_ENV), GLenum(GL_TEXTURE_ENV_MODE), GL_COMBINE)
            glTexEnvi(GLenum(GL_TEXTURE_ENV), GLenum(GL_COMBINE_RGB), GL_ADD)
            glTexEnvi(GLenum(GL_TEXTURE_ENV), GLenum(GL_COMBINE_ALPHA), GL_MODULATE)
        case .combineAddAlpha:
            glTexEnvi(GLenum(GL_TEXTURE_ENV), GLenum(GL_TEXTURE_ENV_MODE), GL_COMBINE)
            glTexEnvi(GLenum(GL_TEXTURE_ENV), GLenum(GL_COMBINE_RGB), GL_ADD)
            glTexEnvi(GLenum(GL_TEXTURE_ENV), GLenum(GL_COMBINE_ALPHA), GL_ADD)
        }
    }

    func setSphereMapTexGen(_ enabled: Bool) {
        if enabled {
            glTexGeni(GLenum(GL_S), GLenum(GL_TEXTURE_GEN_MODE), GL_SPHERE_MAP)
            glTexGeni(GLenum(GL_T), GLenum(GL_TEXTURE_GEN_MODE), GL_SPHERE_MAP)
            glEnable(GLenum(GL_TEXTURE_GEN_S))
            glEnable(GLenum(GL_TEXTURE_GEN_T))
        } else {
            glDisable(GLenum(GL_TEXTURE_GEN_S))
            glDisable(GLenum(GL_TEXTURE_GEN_T))
        }
    }

    func drawIndexedGeometry(
        points: UnsafePointer<OGLPoint3D>,
        normals: UnsafePointer<OGLVector3D>?,
        colors: UnsafePointer<OGLColorRGBA>?,
        uv0: UnsafePointer<OGLTextureCoord>?,
        uv1: UnsafePointer<OGLTextureCoord>?,
        triangles: UnsafePointer<MOTriangleIndecies>?,
        numTriangles: Int32)
    {
        glEnableClientState(GLenum(GL_VERTEX_ARRAY))
        glVertexPointer(3, GLenum(GL_FLOAT), 0, points)

        if let colors {
            glColorPointer(4, GLenum(GL_FLOAT), 0, colors)
            glEnableClientState(GLenum(GL_COLOR_ARRAY))
        } else {
            glDisableClientState(GLenum(GL_COLOR_ARRAY))
        }

        // UV arrays are bound per *client* texture unit; do unit 1 first so
        // client unit 0 is the active one on exit (matching the rest of the
        // code's assumption that unit 0 is current).
        if let clientActiveTextureProc {
            clientActiveTextureProc(GLenum(GL_TEXTURE1))
            if let uv1 {
                glTexCoordPointer(2, GLenum(GL_FLOAT), 0, uv1)
                glEnableClientState(GLenum(GL_TEXTURE_COORD_ARRAY))
            } else {
                glDisableClientState(GLenum(GL_TEXTURE_COORD_ARRAY))
            }
            clientActiveTextureProc(GLenum(GL_TEXTURE0))
        }
        if let uv0 {
            glTexCoordPointer(2, GLenum(GL_FLOAT), 0, uv0)
            glEnableClientState(GLenum(GL_TEXTURE_COORD_ARRAY))
        } else {
            glDisableClientState(GLenum(GL_TEXTURE_COORD_ARRAY))
        }

        if let normals {
            glNormalPointer(GLenum(GL_FLOAT), 0, normals)
            glEnableClientState(GLenum(GL_NORMAL_ARRAY))
        } else {
            glDisableClientState(GLenum(GL_NORMAL_ARRAY))
        }

        if numTriangles != 0, let triangles {
            glDrawElements(GLenum(GL_TRIANGLES), numTriangles * 3, GLenum(GL_UNSIGNED_INT), triangles)
        }
    }

    func prepareSceneDefaults() {
        glCullFace(GLenum(GL_BACK))
        glFrontFace(GLenum(GL_CCW)) // CCW is front face

        glDisable(GLenum(GL_RESCALE_NORMAL))

        // ENABLE ALPHA CHANNELS
        glEnable(GLenum(GL_ALPHA_TEST))
        glAlphaFunc(GLenum(GL_NOTEQUAL), 0) // draw any pixel who's Alpha != 0

        glHint(GLenum(GL_FOG_HINT), GLenum(GL_FASTEST))

        // Global material: white, tracking glColor (so per-vertex/current
        // color drives lit geometry), with normal renormalization on.
        var color: [GLfloat] = [1, 1, 1, 1]
        glMaterialfv(GLenum(GL_FRONT_AND_BACK), GLenum(GL_AMBIENT_AND_DIFFUSE), &color)
        glColorMaterial(GLenum(GL_FRONT_AND_BACK), GLenum(GL_AMBIENT_AND_DIFFUSE))
        glEnable(GLenum(GL_COLOR_MATERIAL))
        glEnable(GLenum(GL_NORMALIZE))
    }

    func setLights(ambientR: Float, ambientG: Float, ambientB: Float, numFillLights: Int32, fillDirections: UnsafePointer<OGLVector3D>, fillColors: UnsafePointer<OGLColorRGBA>) {
        // CREATE AMBIENT LIGHT

        var ambient: [GLfloat] = [ambientR, ambientG, ambientB, 1]
        glLightModelfv(GLenum(GL_LIGHT_MODEL_AMBIENT), &ambient) // set scene ambient light

        // CREATE FILL LIGHTS

        for i in 0..<Int(numFillLights) {
            var lightamb: [GLfloat] = [0.0, 0.0, 0.0, 1.0]
            var lightVec = [GLfloat](repeating: 0, count: 4)
            var diffuse = [GLfloat](repeating: 0, count: 4)

            // SET FILL DIRECTION

            lightVec[0] = -fillDirections[i].x // negate vector because OGL is stupid
            lightVec[1] = -fillDirections[i].y
            lightVec[2] = -fillDirections[i].z
            lightVec[3] = 0 // when w==0, this is a directional light, if 1 then point light
            glLightfv(GLenum(GL_LIGHT0) + GLenum(i), GLenum(GL_POSITION), &lightVec)

            // SET COLOR

            glLightfv(GLenum(GL_LIGHT0) + GLenum(i), GLenum(GL_AMBIENT), &lightamb)

            diffuse[0] = fillColors[i].r
            diffuse[1] = fillColors[i].g
            diffuse[2] = fillColors[i].b
            diffuse[3] = 1

            glLightfv(GLenum(GL_LIGHT0) + GLenum(i), GLenum(GL_DIFFUSE), &diffuse)

            glEnable(GLenum(GL_LIGHT0) + GLenum(i)) // enable the light
        }

        // NUKE ANY FILL LIGHTS REMAINING FROM PREVIOUS SCENE

        for i in Int(numFillLights)..<Int(MAX_FILL_LIGHTS) {
            glDisable(GLenum(GL_LIGHT0) + GLenum(i))
        }
    }

    func updateLightPositions(numFillLights: Int32, fillDirections: UnsafePointer<OGLVector3D>) {
        for i in 0..<Int(numFillLights) {
            var lightVec = [GLfloat](repeating: 0, count: 4)

            lightVec[0] = -fillDirections[i].x // negate vector because OGL is stupid
            lightVec[1] = -fillDirections[i].y
            lightVec[2] = -fillDirections[i].z
            lightVec[3] = 0 // when w==0, this is a directional light, if 1 then point light
            glLightfv(GLenum(GL_LIGHT0) + GLenum(i), GLenum(GL_POSITION), &lightVec)
        }
    }

    func setFog(mode: RBFogMode, density: Float, start: Float, end: Float, r: Float, g: Float, b: Float, a: Float) {
        let glMode: GLint
        switch mode {
        case .linear: glMode = GL_LINEAR
        case .exp: glMode = GL_EXP
        case .exp2: glMode = GL_EXP2
        }
        glFogi(GLenum(GL_FOG_MODE), glMode)
        glFogf(GLenum(GL_FOG_DENSITY), density)
        glFogf(GLenum(GL_FOG_START), start)
        glFogf(GLenum(GL_FOG_END), end)
        var color: [GLfloat] = [r, g, b, a]
        glFogfv(GLenum(GL_FOG_COLOR), &color)
    }

    func setViewport(_ x: Int32, _ y: Int32, _ w: Int32, _ h: Int32) { glViewport(x, y, w, h) }
    func setClearColor(_ r: Float, _ g: Float, _ b: Float) { glClearColor(r, g, b, 1.0) }
    func clearColorAndDepth() { glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT)) }
    func clearDepthOnly() { glClear(GLbitfield(GL_DEPTH_BUFFER_BIT)) }
    func setWireframe(_ enabled: Bool) {
        glPolygonMode(GLenum(GL_FRONT_AND_BACK), GLenum(enabled ? GL_LINE : GL_FILL))
    }
    func present() {
        #if NANOSAUR_SCREENSAVER
        // The screen-saver host (Nanosaur2SaverView) owns the
        // NSOpenGLContext and flushes it after each frame callback returns;
        // presenting mid-frame from engine code would tear.
        #else
        SDL_GL_SwapWindow(gSDLWindow)
        #endif
    }

    func rendererInfo() -> String {
        let rendererStr = String(cString: glGetString(GLenum(GL_RENDERER))!)
        let versionStr = String(cString: glGetString(GLenum(GL_VERSION))!)
        return "\(rendererStr), OpenGL \(versionStr)"
    }

    func setColorMask(_ r: Bool, _ g: Bool, _ b: Bool, _ a: Bool) {
        glColorMask(r ? 1 : 0, g ? 1 : 0, b ? 1 : 0, a ? 1 : 0)
    }

    func setColorMaterialEnabled(_ enabled: Bool) {
        if enabled {
            glEnable(GLenum(GL_COLOR_MATERIAL))
        } else {
            glDisable(GLenum(GL_COLOR_MATERIAL))
        }
    }

    func checkError() -> UInt32 { UInt32(glGetError()) }

    func createContext() {
        #if NANOSAUR_SCREENSAVER
        // The host view already created its NSOpenGLContext and made it
        // current before booting the engine - just run the capability check
        // and proc loading against it.
        var maxTexSize: GLint = 0
        glGetIntegerv(GLenum(GL_MAX_TEXTURE_SIZE), &maxTexSize)
        if maxTexSize < 2048 {
            SwFatalAlert("Your video card cannot do 2048x2048 textures, so it is below the game's minimum system requirements.")
        }

        loadGLProcs()
        #else
        SwGameAssertMessage(gEngine.view.aglContext == nil, "GL context already exists")

        // CREATE AGL CONTEXT & ATTACH TO WINDOW

        gEngine.view.aglContext = SDL_GL_CreateContext(gSDLWindow)

        if gEngine.view.aglContext == nil {
            SwFatalAlert(String(cString: SDL_GetError()))
        }

        SwGameAssert(glGetError() == GL_NO_ERROR)

        // ACTIVATE CONTEXT

        let didMakeCurrent = SDL_GL_MakeCurrent(gSDLWindow, gEngine.view.aglContext)
        SwGameAssertMessage(didMakeCurrent, String(cString: SDL_GetError()))

        // ENABLE VSYNC

        setVSync(Int32(gGamePrefs.vsync))

        // SEE IF SUPPORT 2048x2048 TEXTURES

        var maxTexSize: GLint = 0
        glGetIntegerv(GLenum(GL_MAX_TEXTURE_SIZE), &maxTexSize)
        if maxTexSize < 2048 {
            SwFatalAlert("Your video card cannot do 2048x2048 textures, so it is below the game's minimum system requirements.")
        }

        // GET GL PROCEDURES (glActiveTexture etc. - necessary on Windows)

        loadGLProcs()
        #endif // NANOSAUR_SCREENSAVER
    }

    func destroyContext() {
        #if NANOSAUR_SCREENSAVER
        // Host-owned context - nothing to tear down engine-side.
        #else
        guard gEngine.view.aglContext != nil else {
            return
        }

        _ = SDL_GL_MakeCurrent(gSDLWindow, nil) // make context not current
        SDL_GL_DestroyContext(gEngine.view.aglContext) // nuke context
        gEngine.view.aglContext = nil
        #endif
    }

    #if NANOSAUR_SCREENSAVER
    // Swap pacing is the ScreenSaverView's business (animationTimeInterval).
    func setVSync(_ interval: Int32) {}
    func getVSync() -> Int32 { 0 }
    #else
    func setVSync(_ interval: Int32) { try? SDL.glSetSwapInterval(interval) }
    func getVSync() -> Int32 { (try? SDL.glSwapInterval) ?? 0 }
    #endif
}

#endif // !NANOSAUR_3DS
