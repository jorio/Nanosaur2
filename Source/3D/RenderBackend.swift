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
// Deliberately NOT attempting the immediate-mode (glBegin/glVertex/glEnd)
// surface yet, nor GL state *introspection* (glGetIntegerv/glIsEnabled/
// glGetBooleanv, used by OGL_PushState/DrawBlueLine to snapshot "whatever
// GL's current state happens to be") - those need a real design (batching,
// an explicit state-tracking stack) rather than a 1:1 verb wrapper, and are
// separate, larger Phase 1 slices.
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

    func setColor4f(_ r: Float, _ g: Float, _ b: Float, _ a: Float)

    func matrixMode(_ mode: GLenum)
    func pushMatrix()
    func popMatrix()
    func loadIdentity()
    /// `m` points to 16 floats, column-major (same layout `glLoadMatrixf` and
    /// `OGLMatrix4x4` already use).
    func loadMatrix(_ m: UnsafePointer<Float>)

    /// Binds a 2D texture so subsequent draws use it. Texture *creation*
    /// (glGenTextures/glTexImage2D/glTexSubImage2D upload) is NOT covered
    /// here - that's a much bigger Phase 2 design (maps to MTLTexture
    /// creation + a copy pass, not a 1:1 verb) - this is only the per-draw
    /// "make this existing texture current" step.
    func bindTexture(_ name: GLuint)
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

    func setColor4f(_ r: Float, _ g: Float, _ b: Float, _ a: Float) { glColor4f(r, g, b, a) }

    func matrixMode(_ mode: GLenum) { glMatrixMode(mode) }
    func pushMatrix() { glPushMatrix() }
    func popMatrix() { glPopMatrix() }
    func loadIdentity() { glLoadIdentity() }
    func loadMatrix(_ m: UnsafePointer<Float>) { glLoadMatrixf(m) }

    func bindTexture(_ name: GLuint) { glBindTexture(GLenum(GL_TEXTURE_2D), name) }
}

var gRenderBackend: RenderBackend = GLRenderBackend()
