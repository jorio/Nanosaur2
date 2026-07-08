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

    /// Binds a 2D texture so subsequent draws use it. Texture *creation*
    /// (glGenTextures/glTexImage2D/glTexSubImage2D upload) is NOT covered
    /// here - that's a much bigger Phase 2 design (maps to MTLTexture
    /// creation + a copy pass, not a 1:1 verb) - this is only the per-draw
    /// "make this existing texture current" step.
    func bindTexture(_ name: GLuint)

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

    func setColor4f(_ r: Float, _ g: Float, _ b: Float, _ a: Float) { glColor4f(r, g, b, a) }

    func matrixMode(_ mode: GLenum) { glMatrixMode(mode) }
    func pushMatrix() { glPushMatrix() }
    func popMatrix() { glPopMatrix() }
    func loadIdentity() { glLoadIdentity() }
    func loadMatrix(_ m: UnsafePointer<Float>) { glLoadMatrixf(m) }
    func multMatrix(_ m: UnsafePointer<Float>) { glMultMatrixf(m) }

    func bindTexture(_ name: GLuint) { glBindTexture(GLenum(GL_TEXTURE_2D), name) }

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
    func clearColorAndDepth() { glClear(GLbitfield(GL_COLOR_BUFFER_BIT) | GLbitfield(GL_DEPTH_BUFFER_BIT)) }
    func clearDepthOnly() { glClear(GLbitfield(GL_DEPTH_BUFFER_BIT)) }
    func setWireframe(_ enabled: Bool) {
        glPolygonMode(GLenum(GL_FRONT_AND_BACK), GLenum(enabled ? GL_LINE : GL_FILL))
    }
    func present() { SDL_GL_SwapWindow(gSDLWindow) }
}

var gRenderBackend: RenderBackend = GLRenderBackend()
