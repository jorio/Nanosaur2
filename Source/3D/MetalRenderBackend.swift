// MetalRenderBackend.swift
//
// RenderBackend implementation that drives the MetalRenderer module instead
// of real gl* calls. See docs/metal-renderer-plan.md Phase 2.
//
// IMPORTANT - there is NO GL context at all when this backend is active.
// Tried keeping the game's normal GL context alive alongside a Metal-backed
// view on the same window (just never SDL_GL_SwapWindow'd), so not-yet-
// migrated raw gl* calls elsewhere could keep executing harmlessly - that
// does NOT work empirically: SDL_Metal_CreateView on a window that also has
// a GL context corrupts the GL side (hit "The specified window isn't an
// OpenGL window" when Metal was set up before the GL context; glProcAddress
// results came back nil when set up after). So under --metal,
// OGL_CreateDrawContext() (OGL_Support.swift) skips SDL_GL_CreateContext
// entirely and gSDLWindow is created SDL_WINDOW_METAL-only (Boot.cpp) - no
// GL context exists, ever. This means every raw gl* call actually reachable
// during boot + the menu screen's frame loop had to be migrated to
// RenderBackend or explicitly skipped (see the `gMetalMode == 0` guards in
// OGL_CreateLights/OGL_InitDrawContext/OGL_SetStyles/OGL_PushState/
// OGL_PopState). Anything NOT reachable from there yet - the 3D vertex-array
// geometry path (MO_DrawGeometry_VertexArray), stereo/dual-screen, the debug
// DrawBlueLine path - is simply not safe to hit under --metal yet and will
// crash (calling gl* with no current context) if it is.
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
    func blendFunc(_ src: RBBlendFactor, _ dst: RBBlendFactor) { /* see header comment: fixed blend equation */ }

    private var lastBoundTexture: RBTextureHandle = 0
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
    func setDepthWrite(_ enabled: Bool) { renderer.setDepthWrite(enabled) }

    func setAlphaClipping(trimLowAlpha: Bool) { /* no alpha test in the shader yet - see header comment */ }
    func setNormalizeNormals(_ enabled: Bool) { /* no lighting model, nothing to normalize - see header comment */ }

    private var currentColor: (Float, Float, Float, Float) = (1, 1, 1, 1)
    func setColor4f(_ r: Float, _ g: Float, _ b: Float, _ a: Float) { currentColor = (r, g, b, a) }

    // MARK: - Matrix stack

    // The texture matrix stack (.texture, used by STATUS_BIT_UVTRANSFORM
    // texture scrolling in Objects.swift) is tracked but has no effect on
    // rendering yet - the shader has no texture-matrix uniform. Tracking it
    // as its own mode matters anyway: if it fell through to modelview, a
    // UV-transform's translate would corrupt the modelview stack.
    private var currentMatrixMode: RBMatrixMode = .modelview
    private var modelviewStack: [[Float]] = [MetalRenderBackend.identity]
    private var projectionStack: [[Float]] = [MetalRenderBackend.identity]
    private var textureStack: [[Float]] = [MetalRenderBackend.identity]

    private static let identity: [Float] = [
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    ]

    func matrixMode(_ mode: RBMatrixMode) {
        currentMatrixMode = mode
    }

    private func top() -> [Float] {
        switch currentMatrixMode {
        case .modelview: return modelviewStack[modelviewStack.count - 1]
        case .projection: return projectionStack[projectionStack.count - 1]
        case .texture: return textureStack[textureStack.count - 1]
        }
    }

    private func setTop(_ m: [Float]) {
        switch currentMatrixMode {
        case .modelview: modelviewStack[modelviewStack.count - 1] = m
        case .projection: projectionStack[projectionStack.count - 1] = m
        case .texture: textureStack[textureStack.count - 1] = m
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
        case .texture: textureStack.append(textureStack.last!)
        }
    }

    func popMatrix() {
        switch currentMatrixMode {
        case .modelview: if modelviewStack.count > 1 { modelviewStack.removeLast() }
        case .projection: if projectionStack.count > 1 { projectionStack.removeLast() }
        case .texture: if textureStack.count > 1 { textureStack.removeLast() }
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

    func ortho(_ left: Double, _ right: Double, _ bottom: Double, _ top_: Double, _ near: Double, _ far: Double) {
        // Same matrix glOrtho produces (GL [-1,1] NDC z-range - see the
        // header comment's note on the z-range gap; harmless while
        // everything drawn through this is 2D at z≈0 with depth test off).
        let (l, r, b, t, n, f) = (Float(left), Float(right), Float(bottom), Float(top_), Float(near), Float(far))
        var m = Self.identity
        m[0] = 2 / (r - l)
        m[5] = 2 / (t - b)
        m[10] = -2 / (f - n)
        m[12] = -(r + l) / (r - l)
        m[13] = -(t + b) / (t - b)
        m[14] = -(f + n) / (f - n)
        setTop(Self.multiply(top(), m))
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

    func bindTexture(_ name: RBTextureHandle) {
        lastBoundTexture = name
        if texture2DEnabled {
            renderer.bindTexture(Int32(bitPattern: name))
        }
    }

    func createTexture(width: Int32, height: Int32, format: RBPixelFormat, pixels: UnsafeRawPointer) -> RBTextureHandle {
        switch format {
        case .rgba8:
            let handle = renderer.createTexture(width: Int(width), height: Int(height), pixels: pixels, bgra: false)
            return RBTextureHandle(bitPattern: handle)
        case .rgba8888Rev, .rgba1555Rev:
            // BG3D "imported model" formats that Nanosaur 2's own data never
            // uses (see RBPixelFormat) - not implemented on Metal.
            SwLog("MetalRenderBackend: unsupported texture format \(format)")
            return 0
        }
    }

    func updateTexture(_ name: RBTextureHandle, width: Int32, height: Int32, bgraPixels: UnsafeRawPointer) {
        renderer.updateTexture(Int32(bitPattern: name), width: Int(width), height: Int(height), bgraPixels: bgraPixels)
    }

    func setTextureWrap(_ axis: RBTextureAxis, clamp: Bool) { /* no-op, see header comment */ }

    // MARK: - Immediate mode

    private var immediateMode: RBPrimitive = .quads
    private var immediateVerts: [Float] = []
    private var currentU: Float = 0
    private var currentV: Float = 0

    func beginImmediate(_ mode: RBPrimitive) {
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
        case .quads:
            // Quads are independent per group of 4 vertices (not a fan
            // across the whole batch) - matters for Atlas_ImmediateDraw,
            // which submits many quads (one per glyph) in a single
            // begin/end block.
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

        case .triangles:
            immediateVerts.withUnsafeBufferPointer { buf in
                guard let base = buf.baseAddress else { return }
                renderer.draw(base, vertexCount: vertexCount, primitive: .triangles)
            }

        case .lineLoop, .lineStrip:
            immediateVerts.withUnsafeBufferPointer { buf in
                guard let base = buf.baseAddress else { return }
                renderer.draw(base, vertexCount: vertexCount, primitive: .lineLoop)
            }

        case .lines:
            immediateVerts.withUnsafeBufferPointer { buf in
                guard let base = buf.baseAddress else { return }
                renderer.draw(base, vertexCount: vertexCount, primitive: .lines)
            }
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
