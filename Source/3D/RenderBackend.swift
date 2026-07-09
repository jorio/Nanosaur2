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
}

// MARK: - OpenGL implementation

final class GLRenderBackend: RenderBackend {
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

    func setViewport(_ x: Int32, _ y: Int32, _ w: Int32, _ h: Int32) { glViewport(x, y, w, h) }
    func setClearColor(_ r: Float, _ g: Float, _ b: Float) { glClearColor(r, g, b, 1.0) }
    func clearColorAndDepth() { glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT)) }
    func clearDepthOnly() { glClear(GLbitfield(GL_DEPTH_BUFFER_BIT)) }
    func setWireframe(_ enabled: Bool) {
        glPolygonMode(GLenum(GL_FRONT_AND_BACK), GLenum(enabled ? GL_LINE : GL_FILL))
    }
    func present() { SDL_GL_SwapWindow(gSDLWindow) }
}

var gRenderBackend: RenderBackend = GLRenderBackend()
