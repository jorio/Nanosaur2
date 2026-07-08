// RenderBackend.swift
//
// Phase 1 of docs/metal-renderer-plan.md: a small facade over the handful of
// GL state verbs that OGL_Support.swift's OGL_Enable*/OGL_Disable*/
// OGL_SetColor4f/OGL_BlendFunc functions already wrap. This is a pure
// refactor - the state-caching logic in those functions (gMyState_Blend etc.)
// stays exactly where it is; only the raw gl* call each one makes is moved
// behind this protocol. GLRenderBackend below reproduces the same gl* calls,
// so behaviour is unchanged. A future MetalRenderBackend implements the same
// verbs against the Source/Metal module instead.
//
// Deliberately NOT attempting GL state *introspection* (glGetIntegerv/
// glIsEnabled/glGetBooleanv, used by OGL_PushState/DrawBlueLine to snapshot
// "whatever GL's current state happens to be") - that needs a real
// state-tracking design (an explicit stack), not a 1:1 verb wrapper, and is
// a separate, later slice.
//
// Immediate mode (glBegin/glVertex/glTexCoord/glColor/glEnd) IS wrapped
// below, verb-for-verb, on purpose: every call site in this codebase draws
// a handful of vertices and calls end() immediately (one GL_QUADS picture,
// one GL_QUADS sprite, one GL_QUADS run of text glyphs), never spans
// multiple frames or interleaves with other state changes mid-primitive. So
// a 1:1 wrapper (GLRenderBackend forwards to real glBegin/glVertex3f/
// glTexCoord2f/glColor4f/glEnd, byte-for-byte the same calls) is sufficient -
// no batching/accumulation design needed *for this wrapper*; a future
// MetalRenderBackend does its own accumulation internally between
// beginImmediate()/endImmediate() and issues one draw call at endImmediate().
//
// The matrix-stack verbs below ARE a clean 1:1 wrapper, despite Metal having
// no hardware matrix stack: every call site either loads a full 4x4 computed
// in Swift (the camera path - exactly the MVP-uniform shape Metal wants) or
// does plain nested push/load-identity/pop, which a future MetalRenderBackend
// can implement with its own CPU-side matrix stack. Only push/pop/load call
// sites that also introspect current GL state (OGL_PushState's
// glGetBooleanv(GL_DEPTH_WRITEMASK) etc., DrawBlueLine's
// glGetIntegerv(GL_MATRIX_MODE)) are left as raw gl* calls for now.

protocol RenderBackend: AnyObject {
    func enableBlend()
    func disableBlend()
    func blendFunc(_ src: GLenum, _ dst: GLenum)

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
    /// Depth-buffer *write* toggle (`glDepthMask`), independent of the test.
    func setDepthWrite(_ enabled: Bool)

    /// The two alpha-test configurations the game ever uses
    /// (`STATUS_BIT_CLIPALPHA6` in Objects.swift): trimLowAlpha=true is
    /// `glAlphaFunc(GL_GREATER, 0.6)`, false is the default
    /// `glAlphaFunc(GL_NOTEQUAL, 0)`.
    func setAlphaClipping(trimLowAlpha: Bool)

    /// `glEnable/glDisable(GL_NORMALIZE)` - only meaningful for the
    /// fixed-function lit 3D path.
    func setNormalizeNormals(_ enabled: Bool)

    func setColor4f(_ r: Float, _ g: Float, _ b: Float, _ a: Float)

    func matrixMode(_ mode: GLenum)
    func pushMatrix()
    func popMatrix()
    func loadIdentity()
    /// `m` points to 16 floats, column-major (same layout `glLoadMatrixf` and
    /// `OGLMatrix4x4` already use).
    func loadMatrix(_ m: UnsafePointer<Float>)
    /// Same layout as `loadMatrix`, but multiplies onto the current matrix
    /// (`glMultMatrixf`) instead of replacing it - used by `MO_DrawMatrix`
    /// for MetaObject group transforms.
    func multMatrix(_ m: UnsafePointer<Float>)
    /// Multiplies an orthographic projection onto the current matrix
    /// (`glOrtho` semantics - call sites always `loadIdentity()` first).
    func ortho(_ left: Double, _ right: Double, _ bottom: Double, _ top: Double, _ near: Double, _ far: Double)

    /// Binds a 2D texture so subsequent draws use it.
    func bindTexture(_ name: GLuint)

    /// Creates a linear-filtered 2D texture from `width`x`height` pixels at
    /// `imageMemory` and returns an opaque handle. The handle is typed
    /// `GLuint` because every call site already treats texture names as
    /// opaque 32-bit IDs (stored in `MOMaterialObject.objectData.textureName`
    /// etc.) - nothing depends on it being a *real* GL object name, so a
    /// future MetalRenderBackend can hand back a synthesized ID indexing its
    /// own MTLTexture table instead of a GL name. `destFormat`/`srcFormat`/
    /// `dataType` are GL enums (as glTexImage2D takes) describing the pixel
    /// data's layout - always BGRA8/GL_UNSIGNED_INT_8_8_8_8_REV in practice.
    func createTexture(width: Int32, height: Int32, destFormat: GLint, srcFormat: GLint, dataType: GLint, imageMemory: UnsafeRawPointer) -> GLuint
    /// Re-uploads pixels into an existing texture, keeping its size (used for
    /// runtime-drawn/animated textures, e.g. the dual-screen minimap).
    func updateTexture(_ name: GLuint, width: Int32, height: Int32, pixels: UnsafeRawPointer)

    func translate(_ x: Float, _ y: Float, _ z: Float)
    func scale(_ x: Float, _ y: Float, _ z: Float)
    /// `angle` is in degrees, matching `glRotatef`.
    func rotate(_ angle: Float, _ x: Float, _ y: Float, _ z: Float)

    /// `target` is `GL_TEXTURE_WRAP_S` or `GL_TEXTURE_WRAP_T`.
    func setTextureWrap(_ target: GLenum, clamp: Bool)

    /// `mode` is a GL primitive enum (GL_QUADS, GL_TRIANGLES, GL_LINE_LOOP,
    /// ...) - see the type header comment for why a straight glBegin/glEnd
    /// wrapper is adequate here.
    func beginImmediate(_ mode: GLenum)
    func vertex2f(_ x: Float, _ y: Float)
    func vertex3f(_ x: Float, _ y: Float, _ z: Float)
    func texCoord2f(_ u: Float, _ v: Float)
    func endImmediate()

    /// The common single-window per-frame sequence in `OGL_DrawScene`:
    /// viewport, clear, and swap/present. Deliberately NOT covering the
    /// stereo/dual-screen-specific calls in the same function
    /// (glColorMask for anaglyph, glDrawBuffer for shutter glasses) - those
    /// are edge cases (plan's Phase 4), left as raw gl* calls for now.
    func setViewport(_ x: Int32, _ y: Int32, _ w: Int32, _ h: Int32)
    /// Sets the colour `clearColorAndDepth()` clears to (matches
    /// `glClearColor`'s persistent-state semantics - set once, applies to
    /// every subsequent clear until changed again).
    func setClearColor(_ r: Float, _ g: Float, _ b: Float)
    func clearColorAndDepth()
    func clearDepthOnly()
    func setWireframe(_ enabled: Bool)
    /// Presents the frame. GLRenderBackend does `SDL_GL_SwapWindow`.
    func present()
}

final class GLRenderBackend: RenderBackend {
    func enableBlend() { glEnable(GLenum(GL_BLEND)) }
    func disableBlend() { glDisable(GLenum(GL_BLEND)) }
    func blendFunc(_ src: GLenum, _ dst: GLenum) { glBlendFunc(src, dst) }

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

    func matrixMode(_ mode: GLenum) { glMatrixMode(mode) }
    func pushMatrix() { glPushMatrix() }
    func popMatrix() { glPopMatrix() }
    func loadIdentity() { glLoadIdentity() }
    func loadMatrix(_ m: UnsafePointer<Float>) { glLoadMatrixf(m) }
    func multMatrix(_ m: UnsafePointer<Float>) { glMultMatrixf(m) }
    func ortho(_ left: Double, _ right: Double, _ bottom: Double, _ top: Double, _ near: Double, _ far: Double) {
        glOrtho(left, right, bottom, top, near, far)
    }

    func bindTexture(_ name: GLuint) { glBindTexture(GLenum(GL_TEXTURE_2D), name) }

    func createTexture(width: Int32, height: Int32, destFormat: GLint, srcFormat: GLint, dataType: GLint, imageMemory: UnsafeRawPointer) -> GLuint {
        var textureName: GLuint = 0
        glGenTextures(1, &textureName)
        glBindTexture(GLenum(GL_TEXTURE_2D), textureName)

        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)

        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, destFormat, width, height, 0, GLenum(srcFormat), GLenum(dataType), imageMemory)

        return textureName
    }

    func updateTexture(_ name: GLuint, width: Int32, height: Int32, pixels: UnsafeRawPointer) {
        glBindTexture(GLenum(GL_TEXTURE_2D), name)
        glTexSubImage2D(GLenum(GL_TEXTURE_2D), 0, 0, 0, width, height, GLenum(GL_BGRA), GLenum(GL_UNSIGNED_INT_8_8_8_8_REV), pixels)
    }

    func translate(_ x: Float, _ y: Float, _ z: Float) { glTranslatef(x, y, z) }
    func scale(_ x: Float, _ y: Float, _ z: Float) { glScalef(x, y, z) }
    func rotate(_ angle: Float, _ x: Float, _ y: Float, _ z: Float) { glRotatef(angle, x, y, z) }

    func setTextureWrap(_ target: GLenum, clamp: Bool) {
        glTexParameterf(GLenum(GL_TEXTURE_2D), target, Float(clamp ? GL_CLAMP_TO_EDGE : GL_REPEAT))
    }

    func beginImmediate(_ mode: GLenum) { glBegin(mode) }
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
