// MetalRenderBackend.swift
//
// RenderBackend implementation that drives the MetalRenderer module instead
// of real gl* calls. See docs/metal-renderer-plan.md Phase 2.
//
// IMPORTANT - how this coexists with the rest of the still-GL codebase: only
// the call sites already migrated to `gRenderBackend.*` (see RenderBackend.swift's
// header comment for what's covered) go through this class. Everything NOT
// yet migrated (lighting setup in OGL_CreateLights, GL state introspection
// in OGL_PushState/DrawBlueLine, the 3D vertex-array geometry path in
// MetaObjects.swift's MO_DrawGeometry_VertexArray, stereo/dual-screen calls,
// etc.) still makes real gl* calls. For that to be harmless rather than a
// crash (no GL context) or a corrupted frame (writing into a context that's
// also being presented), the game's normal OpenGL context is left fully
// intact and created as usual - it just never gets SDL_GL_SwapWindow'd when
// a Metal backend is active (this class's `present()` presents the Metal
// layer instead). Any un-migrated gl* call still executes against a live,
// valid context; its output is simply never shown, because nothing swaps
// that context's framebuffer to the window. Only the Metal layer (a
// separate CAMetalLayer on the same window, see MetalSpike.swift) is
// actually presented.
//
// Known correctness gaps in this first cut (documented rather than silently
// wrong):
// - blendFunc(src:dst:) is a no-op - the Metal pipeline has ONE fixed blend
//   equation (standard "source-over" alpha), baked into pipeline state at
//   creation. Effects requesting a different blend (e.g. Atlas_DrawString2's
//   kTextMeshGlow using GL_SRC_ALPHA/GL_ONE additive blend) will render with
//   standard alpha blend instead under Metal.
// - enableLighting/disableLighting, enableCullFace/disableCullFace,
//   enableFog/disableFog are no-ops - the shader has no lighting/fog model
//   and MetalRenderer doesn't set a cull mode. Harmless for this milestone's
//   scope (all draws routed here are unlit 2D quads that already disable
//   lighting before drawing), but wrong if/when the 3D geometry path
//   (MO_DrawGeometry_VertexArray) is migrated later without adding real
//   lighting/fog/cull support first.
// - setTextureWrap is a no-op - MetalRenderer's sampler is fixed to repeat
//   addressing; GL_CLAMP_TO_EDGE requests are ignored (possible edge-bleed
//   on some sprites).
// - The projection matrices this codebase computes (OGL_SetGluPerspectiveMatrix
//   etc.) target GL's [-1,1] NDC z-range; Metal expects [0,1]. Not corrected
//   here. Doesn't affect this milestone (menu screen draws 2D quads with no
//   meaningful depth range), but must be fixed before any real 3D content
//   (MO_DrawGeometry_VertexArray) renders correctly via Metal.
// - setViewport doesn't flip the Y origin (GL measures from the bottom,
//   Metal from the top). Harmless for a single full-window viewport
//   (x=0,y=0 either way - true for the main menu), wrong for split-screen.

import MetalRenderer

final class MetalRenderBackend: RenderBackend {
    private let renderer: MetalRenderer

    init(renderer: MetalRenderer) {
        self.renderer = renderer
    }

    // MARK: - State toggles

    func enableBlend() { renderer.setBlend(true) }
    func disableBlend() { renderer.setBlend(false) }
    func blendFunc(_ src: GLenum, _ dst: GLenum) { /* see header comment: fixed blend equation */ }

    private var lastBoundTexture: GLuint = 0
    private var texture2DEnabled = true

    func enableTexture2D() {
        texture2DEnabled = true
        renderer.bindTexture(Int32(bitPattern: lastBoundTexture))
    }
    func disableTexture2D() {
        texture2DEnabled = false
        renderer.bindTexture(-1)
    }

    func enableLighting() { /* no-op, see header comment */ }
    func disableLighting() { /* no-op, see header comment */ }

    func enableCullFace() { /* no-op, see header comment */ }
    func disableCullFace() { /* no-op, see header comment */ }

    func enableFog() { /* no-op, see header comment */ }
    func disableFog() { /* no-op, see header comment */ }

    func enableDepthTest() { renderer.setDepthTest(true) }
    func disableDepthTest() { renderer.setDepthTest(false) }

    private var currentColor: (Float, Float, Float, Float) = (1, 1, 1, 1)
    func setColor4f(_ r: Float, _ g: Float, _ b: Float, _ a: Float) { currentColor = (r, g, b, a) }

    // MARK: - Matrix stack

    private enum MatrixMode { case modelview, projection }
    private var currentMatrixMode: MatrixMode = .modelview
    private var modelviewStack: [[Float]] = [MetalRenderBackend.identity]
    private var projectionStack: [[Float]] = [MetalRenderBackend.identity]

    private static let identity: [Float] = [
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    ]

    func matrixMode(_ mode: GLenum) {
        currentMatrixMode = (mode == GLenum(GL_PROJECTION)) ? .projection : .modelview
    }

    private func top() -> [Float] {
        switch currentMatrixMode {
        case .modelview: return modelviewStack[modelviewStack.count - 1]
        case .projection: return projectionStack[projectionStack.count - 1]
        }
    }

    private func setTop(_ m: [Float]) {
        switch currentMatrixMode {
        case .modelview: modelviewStack[modelviewStack.count - 1] = m
        case .projection: projectionStack[projectionStack.count - 1] = m
        }
        updateMVP()
    }

    private func updateMVP() {
        let mvp = Self.multiply(projectionStack[projectionStack.count - 1], modelviewStack[modelviewStack.count - 1])
        mvp.withUnsafeBufferPointer { renderer.setMVP($0.baseAddress!) }
    }

    func pushMatrix() {
        switch currentMatrixMode {
        case .modelview: modelviewStack.append(modelviewStack.last!)
        case .projection: projectionStack.append(projectionStack.last!)
        }
    }

    func popMatrix() {
        switch currentMatrixMode {
        case .modelview: if modelviewStack.count > 1 { modelviewStack.removeLast() }
        case .projection: if projectionStack.count > 1 { projectionStack.removeLast() }
        }
        updateMVP()
    }

    func loadIdentity() { setTop(Self.identity) }

    func loadMatrix(_ m: UnsafePointer<Float>) {
        setTop(Array(UnsafeBufferPointer(start: m, count: 16)))
    }

    func multMatrix(_ m: UnsafePointer<Float>) {
        let rhs = Array(UnsafeBufferPointer(start: m, count: 16))
        setTop(Self.multiply(top(), rhs))
    }

    func translate(_ x: Float, _ y: Float, _ z: Float) {
        var m = Self.identity
        m[12] = x; m[13] = y; m[14] = z
        setTop(Self.multiply(top(), m))
    }

    func scale(_ x: Float, _ y: Float, _ z: Float) {
        var m = Self.identity
        m[0] = x; m[5] = y; m[10] = z
        setTop(Self.multiply(top(), m))
    }

    func rotate(_ angle: Float, _ x: Float, _ y: Float, _ z: Float) {
        let len = (x * x + y * y + z * z).squareRoot()
        guard len > 0 else { return }
        let (ax, ay, az) = (x / len, y / len, z / len)
        let rad = angle * .pi / 180
        let c = cos(rad), s = sin(rad), t = 1 - c

        var m = Self.identity
        m[0] = ax * ax * t + c;        m[1] = ay * ax * t + az * s;    m[2] = az * ax * t - ay * s
        m[4] = ax * ay * t - az * s;    m[5] = ay * ay * t + c;         m[6] = az * ay * t + ax * s
        m[8] = ax * az * t + ay * s;    m[9] = ay * az * t - ax * s;    m[10] = az * az * t + c
        setTop(Self.multiply(top(), m))
    }

    /// Column-major 4x4 multiply (matches `OGLMatrix4x4`'s flat `value[16]`
    /// layout): result = a * b.
    private static func multiply(_ a: [Float], _ b: [Float]) -> [Float] {
        var r = [Float](repeating: 0, count: 16)
        for col in 0..<4 {
            for row in 0..<4 {
                var sum: Float = 0
                for k in 0..<4 {
                    sum += a[k * 4 + row] * b[col * 4 + k]
                }
                r[col * 4 + row] = sum
            }
        }
        return r
    }

    // MARK: - Textures

    func bindTexture(_ name: GLuint) {
        lastBoundTexture = name
        if texture2DEnabled {
            renderer.bindTexture(Int32(bitPattern: name))
        }
    }

    func createTexture(width: Int32, height: Int32, destFormat: GLint, srcFormat: GLint, dataType: GLint, imageMemory: UnsafeRawPointer) -> GLuint {
        // destFormat/srcFormat/dataType are ignored: MetalRenderer's texture
        // API always takes BGRA8 (GL_BGRA/GL_UNSIGNED_INT_8_8_8_8_REV in
        // practice, which is what every call site in this codebase passes).
        let handle = renderer.createTexture(width: Int(width), height: Int(height), bgraPixels: imageMemory)
        return GLuint(bitPattern: handle)
    }

    func updateTexture(_ name: GLuint, width: Int32, height: Int32, pixels: UnsafeRawPointer) {
        renderer.updateTexture(Int32(bitPattern: name), width: Int(width), height: Int(height), bgraPixels: pixels)
    }

    func setTextureWrap(_ target: GLenum, clamp: Bool) { /* no-op, see header comment */ }

    // MARK: - Immediate mode

    private var immediateMode: GLenum = 0
    private var immediateVerts: [Float] = []
    private var currentU: Float = 0
    private var currentV: Float = 0

    func beginImmediate(_ mode: GLenum) {
        immediateMode = mode
        immediateVerts.removeAll(keepingCapacity: true)
    }

    func vertex2f(_ x: Float, _ y: Float) { appendVertex(x, y, 0) }
    func vertex3f(_ x: Float, _ y: Float, _ z: Float) { appendVertex(x, y, z) }
    func texCoord2f(_ u: Float, _ v: Float) { currentU = u; currentV = v }

    private func appendVertex(_ x: Float, _ y: Float, _ z: Float) {
        immediateVerts.append(contentsOf: [x, y, z, currentU, currentV, currentColor.0, currentColor.1, currentColor.2, currentColor.3])
    }

    func endImmediate() {
        let vertexCount = immediateVerts.count / 9
        guard vertexCount > 0 else { return }

        switch immediateMode {
        case GLenum(GL_QUADS):
            // GL_QUADS treats every group of 4 vertices as an independent
            // quad (not a fan across the whole batch) - matters for
            // Atlas_ImmediateDraw, which submits many quads (one per glyph)
            // in a single begin/end block.
            var tris: [Float] = []
            tris.reserveCapacity((vertexCount / 4) * 6 * 9)
            var q = 0
            while q + 4 <= vertexCount {
                let base = q * 9
                func vert(_ i: Int) -> ArraySlice<Float> { immediateVerts[(base + i * 9)..<(base + i * 9 + 9)] }
                tris.append(contentsOf: vert(0)); tris.append(contentsOf: vert(1)); tris.append(contentsOf: vert(2))
                tris.append(contentsOf: vert(0)); tris.append(contentsOf: vert(2)); tris.append(contentsOf: vert(3))
                q += 4
            }
            tris.withUnsafeBufferPointer { buf in
                guard let base = buf.baseAddress else { return }
                renderer.draw(base, vertexCount: tris.count / 9, primitive: .triangles)
            }

        case GLenum(GL_TRIANGLES):
            immediateVerts.withUnsafeBufferPointer { buf in
                guard let base = buf.baseAddress else { return }
                renderer.draw(base, vertexCount: vertexCount, primitive: .triangles)
            }

        case GLenum(GL_LINE_LOOP), GLenum(GL_LINE_STRIP):
            immediateVerts.withUnsafeBufferPointer { buf in
                guard let base = buf.baseAddress else { return }
                renderer.draw(base, vertexCount: vertexCount, primitive: .lineLoop)
            }

        case GLenum(GL_LINES):
            immediateVerts.withUnsafeBufferPointer { buf in
                guard let base = buf.baseAddress else { return }
                renderer.draw(base, vertexCount: vertexCount, primitive: .lines)
            }

        default:
            break // unsupported primitive mode - not used by any migrated call site
        }
    }

    // MARK: - Frame / viewport / clear

    private var clearColor: (Float, Float, Float) = (0, 0, 0)
    private var frameActive = false

    func setViewport(_ x: Int32, _ y: Int32, _ w: Int32, _ h: Int32) {
        renderer.setViewport(x: Float(x), y: Float(y), width: Float(w), height: Float(h))
    }

    func setClearColor(_ r: Float, _ g: Float, _ b: Float) { clearColor = (r, g, b) }

    func clearColorAndDepth() {
        // MetalRenderer clears at frame-start (beginFrame), not via a
        // separate mid-frame call like glClear - lazily start the frame
        // here since this is where OGL_DrawScene's single non-stereo clear
        // call happens, before the pane/camera/draw loop.
        if !frameActive {
            frameActive = renderer.beginFrame(red: clearColor.0, green: clearColor.1, blue: clearColor.2)
        }
    }

    func clearDepthOnly() {
        // No depth-only clear in MetalRenderer's frame lifecycle yet; falls
        // back to a full clear (also clears colour). Not hit by the menu
        // screen (which always clears the back buffer), so left unrefined -
        // see header comment.
        clearColorAndDepth()
    }

    func setWireframe(_ enabled: Bool) { /* no-op: MetalRenderer has no wireframe fill mode yet */ }

    func present() {
        if frameActive {
            renderer.endFrame()
            frameActive = false
        }
    }
}
