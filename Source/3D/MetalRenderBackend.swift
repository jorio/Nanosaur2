// MetalRenderBackend.swift
//
// RenderBackend implementation that drives the MetalRenderer module instead
// of real gl* calls. See docs/metal-renderer-plan.md.
//
// There is NO GL context at all when this backend is active - under
// --metal, OGL_CreateDrawContext() (OGL_Support.swift) skips
// SDL_GL_CreateContext entirely and gSDLWindow is created SDL_WINDOW_METAL-
// only (Boot.cpp). This is safe now that the portable-facade refactor
// (docs/metal-renderer-plan.md's "REFACTOR COMPLETE" section) has moved
// every raw gl* call in the game behind RenderBackend, except a handful of
// inherently-GL-only features (shutter-glasses stereo, the dual-screen
// second context) that this backend cannot reach in the first place.
//
// Known correctness gaps (documented rather than silently wrong):
// - blendFunc(src:dst:) is a no-op - the Metal pipeline has ONE fixed blend
//   equation (standard "source-over" alpha), baked into pipeline state at
//   creation. Effects requesting a different blend (e.g. Atlas_DrawString2's
//   kTextMeshGlow using GL_SRC_ALPHA/GL_ONE additive blend) will render with
//   standard alpha blend instead under Metal.
// - enableLighting/disableLighting, enableCullFace/disableCullFace,
//   enableFog/disableFog are no-ops - the shader has no lighting/fog model
//   and MetalRenderer doesn't set a cull mode. Real 3D content (terrain,
//   skeletons) will render unlit and unfogged until the shader grows a
//   lighting/fog model.
// - setTextureEnv/setSphereMapTexGen are no-ops and only texture unit 0 is
//   honored (see currentTextureUnit below) - multi-texture/reflection-map
//   materials render as their base texture only.
// - setTextureWrap is a no-op - MetalRenderer's sampler is fixed to repeat
//   addressing; GL_CLAMP_TO_EDGE requests are ignored (possible edge-bleed
//   on some sprites).
// - setViewport doesn't flip the Y origin (GL measures from the bottom,
//   Metal from the top). Harmless for a single full-window viewport
//   (x=0,y=0 either way - true outside split-screen), wrong for
//   split-screen/dual-screen.
//
// Fixed, not a gap: every projection matrix this codebase computes targets
// GL's [-1,1] clip-space z convention; Metal clips against [0,1]. Rather
// than rewrite every matrix-producing function (ortho/frustum here, plus
// OGL_SetGluPerspectiveMatrix et al in 3DMath_Matrix.swift, all used
// interchangeably via loadMatrix), the vertex shader remaps z after the
// MVP transform (MetalRenderer.swift's vertex_main) - one fix, correct for
// every matrix regardless of source.

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
    // Only texture unit 0 is honored: MetalRenderer's shader samples a
    // single texture. Multi-texture passes (second material layer,
    // reflection maps) select unit 1 and bind/toggle textures there - those
    // operations are ignored so they can't clobber the base texture.
    private var currentTextureUnit: Int32 = 0

    func enableTexture2D() {
        guard currentTextureUnit == 0 else { return }
        texture2DEnabled = true
        renderer.bindTexture(Int32(bitPattern: lastBoundTexture))
    }
    func disableTexture2D() {
        guard currentTextureUnit == 0 else { return }
        texture2DEnabled = false
        renderer.bindTexture(-1)
    }

    func activeTextureUnit(_ unit: Int32) { currentTextureUnit = unit }
    func setTextureEnv(_ mode: RBTextureEnv) { /* single-texture shader - combine modes not implemented */ }
    func setSphereMapTexGen(_ enabled: Bool) { /* reflection mapping not implemented */ }

    func prepareSceneDefaults() { /* no fixed-function defaults to apply */ }
    func setLights(ambientR: Float, ambientG: Float, ambientB: Float, numFillLights: Int32, fillDirections: UnsafePointer<OGLVector3D>, fillColors: UnsafePointer<OGLColorRGBA>) {
        // No lighting model in the shader yet - see header comment.
    }
    func updateLightPositions(numFillLights: Int32, fillDirections: UnsafePointer<OGLVector3D>) { /* no lighting model */ }
    func setFog(mode: RBFogMode, density: Float, start: Float, end: Float, r: Float, g: Float, b: Float, a: Float) { /* no fog model */ }

    func enableLighting() { /* no-op, see header comment */ }
    func disableLighting() { /* no-op, see header comment */ }

    func enableCullFace() { /* no-op, see header comment */ }
    func disableCullFace() { /* no-op, see header comment */ }

    func enableFog() { /* no-op, see header comment */ }
    func disableFog() { /* no-op, see header comment */ }

    func enableDepthTest() { renderer.setDepthTest(true) }
    func disableDepthTest() { renderer.setDepthTest(false) }
    func setDepthWrite(_ enabled: Bool) { renderer.setDepthWrite(enabled) }

    // Mirrors OGL_SetStyles' default (alpha test on, "alpha != 0") so a
    // fresh MetalRenderBackend matches the GL steady state without needing
    // an explicit first call.
    private var alphaTestEnabled = true
    private var alphaTrimLowAlpha = false

    func setAlphaClipping(trimLowAlpha: Bool) {
        alphaTrimLowAlpha = trimLowAlpha
        applyAlphaTest()
    }
    func setAlphaTestEnabled(_ enabled: Bool) {
        alphaTestEnabled = enabled
        applyAlphaTest()
    }
    private func applyAlphaTest() {
        renderer.setAlphaTest(threshold: alphaTestEnabled ? (alphaTrimLowAlpha ? 0.6 : 0.0) : nil)
    }
    func setNormalizeNormals(_ enabled: Bool) { /* no lighting model, nothing to normalize - see header comment */ }
    func setTwoSidedLighting(_ enabled: Bool) { /* no lighting model */ }

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

    func getModelViewMatrix(_ out: UnsafeMutablePointer<Float>) {
        let m = modelviewStack[modelviewStack.count - 1]
        for i in 0..<16 { out[i] = m[i] }
    }

    func getProjectionMatrix(_ out: UnsafeMutablePointer<Float>) {
        let m = projectionStack[projectionStack.count - 1]
        for i in 0..<16 { out[i] = m[i] }
    }

    func frustum(_ left: Double, _ right: Double, _ bottom: Double, _ top_: Double, _ near: Double, _ far: Double) {
        // Same matrix glFrustum produces (GL [-1,1] NDC z-range - see the
        // header comment's z-range note).
        let (l, r, b, t, n, f) = (Float(left), Float(right), Float(bottom), Float(top_), Float(near), Float(far))
        var m = [Float](repeating: 0, count: 16)
        m[0] = 2 * n / (r - l)
        m[5] = 2 * n / (t - b)
        m[8] = (r + l) / (r - l)
        m[9] = (t + b) / (t - b)
        m[10] = -(f + n) / (f - n)
        m[11] = -1
        m[14] = -2 * f * n / (f - n)
        setTop(Self.multiply(top(), m))
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
        guard currentTextureUnit == 0 else { return } // see currentTextureUnit
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

    func deleteTextures(_ names: UnsafePointer<RBTextureHandle>, count: Int32) {
        for i in 0..<Int(count) {
            renderer.deleteTexture(Int32(bitPattern: names[i]))
        }
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

    // MARK: - Indexed geometry

    /// Expands the indexed triangle list through the immediate-mode
    /// accumulator (one interleaved vertex per index). Ignores normals (no
    /// lighting model) and uv1 (single-texture shader) - see the header
    /// comment's gap list. Per-vertex colors override the current material
    /// color exactly like GL's color arrays do.
    func drawIndexedGeometry(
        points: UnsafePointer<OGLPoint3D>,
        normals: UnsafePointer<OGLVector3D>?,
        colors: UnsafePointer<OGLColorRGBA>?,
        uv0: UnsafePointer<OGLTextureCoord>?,
        uv1: UnsafePointer<OGLTextureCoord>?,
        triangles: UnsafePointer<MOTriangleIndecies>?,
        numTriangles: Int32)
    {
        guard numTriangles > 0, let triangles else { return }

        beginImmediate(.triangles)
        for t in 0..<Int(numTriangles) {
            let tri = triangles[t].vertexIndices
            for index in [tri.0, tri.1, tri.2] {
                let i = Int(index)
                if let colors {
                    setColor4f(colors[i].r, colors[i].g, colors[i].b, colors[i].a)
                }
                if let uv0 {
                    texCoord2f(uv0[i].u, uv0[i].v)
                }
                vertex3f(points[i].x, points[i].y, points[i].z)
            }
        }
        endImmediate()
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

    func rendererInfo() -> String {
        return "\(renderer.deviceName), Metal"
    }

    func setColorMask(_ r: Bool, _ g: Bool, _ b: Bool, _ a: Bool) { /* stereo not supported */ }
    func setColorMaterialEnabled(_ enabled: Bool) { /* no fixed-function material */ }
    func checkError() -> UInt32 { 0 }

    func createContext() { /* constructed already-active - see SwMetalBackend_Activate */ }
    func destroyContext() { /* nothing to tear down beyond ARC */ }

    private var vsyncInterval: Int32 = 1 // CAMetalLayer.displaySyncEnabled defaults on
    func setVSync(_ interval: Int32) {
        vsyncInterval = interval
        renderer.setVSync(interval != 0)
    }
    func getVSync() -> Int32 { vsyncInterval }

    func present() {
        if frameActive {
            renderer.endFrame()
            frameActive = false
        }
    }
}
