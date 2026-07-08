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
// Deliberately NOT attempting the immediate-mode (glBegin/glVertex/glEnd) or
// matrix-stack surface yet - those need a real design (batching, MVP
// uniforms) rather than a 1:1 verb wrapper, and are separate, larger Phase 1
// slices. This first slice covers only the cleanly-1:1-mappable state verbs.

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
}

var gRenderBackend: RenderBackend = GLRenderBackend()
