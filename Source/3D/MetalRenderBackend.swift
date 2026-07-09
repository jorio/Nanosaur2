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
// - Lighting is a real (if simplified) implementation: ambient + up to
//   MAX_FILL_LIGHTS directional diffuse lights, matching this game's actual
//   fixed-function GL setup exactly (GL_COLOR_MATERIAL tracks both ambient
//   and diffuse to the vertex color, no specular is ever set, lights are
//   always directional/w=0 so there's no attenuation - see the shader's
//   fragment_main). enableCullFace/disableCullFace and enableFog/
//   disableFog are still no-ops (MetalRenderer doesn't set a cull mode or
//   fog model) - real 3D content renders lit but unfogged and
//   double-sided.
// - Two texture units are honored (base + a second, MODULATE-combined
//   texture - covers Infobar's health/shield/fuel circular mask, plain
//   2-layer multi-texture materials, and sphere-map reflection texgen -
//   jetpack/goggles/crystals), but setTextureEnv's ADD/ADD_ALPHA combine
//   modes still render as MODULATE.
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
    func blendFunc(_ src: RBBlendFactor, _ dst: RBBlendFactor) {
        // The only two configurations the game ever requests (see
        // RenderBackend.swift's rbBlendFactor): standard "source-over"
        // alpha (srcAlpha, oneMinusSrcAlpha) and additive glow/light
        // sprites (srcAlpha, one). src is always .srcAlpha in practice;
        // only dst distinguishes them.
        renderer.setBlendAdditive(dst == .one)
    }

    private var lastBoundTexture: RBTextureHandle = 0
    private var texture2DEnabled = true
    private var lastBoundTexture1: RBTextureHandle = 0
    private var texture1Enabled = false
    // MetalRenderer's shader samples two textures and modulates them
    // (MODULATE combine only - see setTextureEnv/setSphereMapTexGen below
    // for what's still unimplemented). activeTextureUnit selects which unit
    // subsequent bind/enable/disable calls apply to.
    private var currentTextureUnit: Int32 = 0

    func enableTexture2D() {
        if currentTextureUnit == 0 {
            texture2DEnabled = true
            renderer.bindTexture(Int32(bitPattern: lastBoundTexture))
        } else {
            texture1Enabled = true
            renderer.bindTexture1(Int32(bitPattern: lastBoundTexture1))
        }
    }
    func disableTexture2D() {
        if currentTextureUnit == 0 {
            texture2DEnabled = false
            renderer.bindTexture(-1)
        } else {
            texture1Enabled = false
            renderer.bindTexture1(-1)
        }
    }

    func activeTextureUnit(_ unit: Int32) { currentTextureUnit = unit }
    func setTextureEnv(_ mode: RBTextureEnv) { /* only MODULATE is implemented (the shader's fixed combine) - ADD/ADD_ALPHA render as MODULATE */ }
    func setSphereMapTexGen(_ enabled: Bool) { renderer.setSphereMapTexGen(enabled) }

    func prepareSceneDefaults() { /* no fixed-function defaults to apply */ }

    // Ambient + per-light diffuse color change rarely (scene setup only);
    // cached here so updateLightPositions (called every pane, every frame)
    // can resend the full lighting uniform without the caller re-passing
    // data it doesn't have.
    private var lightAmbient: (Float, Float, Float) = (0, 0, 0)
    private var lightCount: Int32 = 0
    private var lightColors: [Float] = [Float](repeating: 0, count: 4 * 3)

    func setLights(ambientR: Float, ambientG: Float, ambientB: Float, numFillLights: Int32, fillDirections: UnsafePointer<OGLVector3D>, fillColors: UnsafePointer<OGLColorRGBA>) {
        lightAmbient = (ambientR, ambientG, ambientB)
        lightCount = numFillLights
        for i in 0..<Int(numFillLights) {
            lightColors[i * 3 + 0] = fillColors[i].r
            lightColors[i * 3 + 1] = fillColors[i].g
            lightColors[i * 3 + 2] = fillColors[i].b
        }
        // Push once immediately with un-transformed (world-space) directions
        // as a harmless placeholder - updateLightPositions always runs
        // (from the camera setup that precedes every frame's draws) before
        // any lit geometry is actually drawn, overwriting this with the
        // correct eye-space directions.
        updateLightPositions(numFillLights: numFillLights, fillDirections: fillDirections)
    }

    /// GL's glLightfv(..., GL_POSITION, ...) bakes in whatever modelview is
    /// current AT THE CALL SITE - which, for this codebase's calling
    /// convention (called from OGL_Camera_SetPlacementAndUpdateMatrices
    /// right after loading the camera's view matrix, before any per-object
    /// transform is pushed), is the camera's view matrix alone. Replicate
    /// that explicitly: transform each direction by the current modelview
    /// top here, rather than relying on per-fragment/vertex re-transforms
    /// with whatever matrix happens to be active at draw time.
    func updateLightPositions(numFillLights: Int32, fillDirections: UnsafePointer<OGLVector3D>) {
        let mv = modelviewStack[modelviewStack.count - 1]
        var eyeDirections = [Float](repeating: 0, count: 4 * 3)
        for i in 0..<Int(numFillLights) {
            // Negate (GL's lightVec = -direction convention) and rotate by
            // the view matrix's upper 3x3 (a direction has w=0, so
            // translation doesn't apply).
            let d = fillDirections[i]
            let (dx, dy, dz) = (-d.x, -d.y, -d.z)
            eyeDirections[i * 3 + 0] = mv[0] * dx + mv[4] * dy + mv[8] * dz
            eyeDirections[i * 3 + 1] = mv[1] * dx + mv[5] * dy + mv[9] * dz
            eyeDirections[i * 3 + 2] = mv[2] * dx + mv[6] * dy + mv[10] * dz
        }
        eyeDirections.withUnsafeBufferPointer { dirs in
            lightColors.withUnsafeBufferPointer { colors in
                renderer.setLightingData(ambient: lightAmbient, count: numFillLights, directions: dirs.baseAddress!, colors: colors.baseAddress!)
            }
        }
    }

    func setFog(mode: RBFogMode, density: Float, start: Float, end: Float, r: Float, g: Float, b: Float, a: Float) { /* no fog model */ }

    func enableLighting() { renderer.setLightingEnabled(true) }
    func disableLighting() { renderer.setLightingEnabled(false) }

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
        syncGPUMatrices()
    }

    private func syncGPUMatrices() {
        let modelview = modelviewStack[modelviewStack.count - 1]
        let mvp = Self.multiply(projectionStack[projectionStack.count - 1], modelview)
        mvp.withUnsafeBufferPointer { renderer.setMVP($0.baseAddress!) }
        // Texture matrix - animates scrolling UVs (Wormhole.swift's tunnel
        // effect, Water.swift's surface scroll, STATUS_BIT_UVTRANSFORM
        // items). Pushed unconditionally alongside MVP rather than only
        // when currentMatrixMode == .texture - cheap (one more
        // setVertexBytes call) and keeps this in lockstep with the stack by
        // construction instead of needing every call site to remember.
        textureStack[textureStack.count - 1].withUnsafeBufferPointer { renderer.setTextureMatrix($0.baseAddress!) }
        // Modelview alone (not combined with projection) - sphere-map
        // reflection texgen needs the eye-space transform specifically.
        modelview.withUnsafeBufferPointer { renderer.setModelView($0.baseAddress!) }
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
        syncGPUMatrices()
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
        if currentTextureUnit == 0 {
            lastBoundTexture = name
            if texture2DEnabled {
                renderer.bindTexture(Int32(bitPattern: name))
            }
        } else {
            lastBoundTexture1 = name
            if texture1Enabled {
                renderer.bindTexture1(Int32(bitPattern: name))
            }
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
    // Second texture unit's per-vertex UV - only ever set by
    // drawIndexedGeometry's multi-texture path (setTexCoord1 below); every
    // other call site leaves these at 0, which is harmless since unit 1
    // defaults to the white texture there.
    private var currentU1: Float = 0
    private var currentV1: Float = 0
    // Per-vertex normal - only ever set by drawIndexedGeometry's
    // sphere-map-texgen path (setNormal below); every other call site
    // leaves this at 0, unused since the shader's useSphereMap flag defaults
    // off.
    private var currentNormal: (Float, Float, Float) = (0, 0, 0)

    func beginImmediate(_ mode: RBPrimitive) {
        immediateMode = mode
        immediateVerts.removeAll(keepingCapacity: true)
        currentU1 = 0
        currentV1 = 0
        currentNormal = (0, 0, 0)
    }

    func vertex2f(_ x: Float, _ y: Float) { appendVertex(x, y, 0) }
    func vertex3f(_ x: Float, _ y: Float, _ z: Float) { appendVertex(x, y, z) }
    func texCoord2f(_ u: Float, _ v: Float) { currentU = u; currentV = v }
    private func setTexCoord1(_ u: Float, _ v: Float) { currentU1 = u; currentV1 = v }
    private func setNormal(_ x: Float, _ y: Float, _ z: Float) { currentNormal = (x, y, z) }

    private func appendVertex(_ x: Float, _ y: Float, _ z: Float) {
        immediateVerts.append(contentsOf: [x, y, z, currentU, currentV, currentU1, currentV1, currentNormal.0, currentNormal.1, currentNormal.2, currentColor.0, currentColor.1, currentColor.2, currentColor.3])
    }

    func endImmediate() {
        let vertexCount = immediateVerts.count / kFloatsPerVertex
        guard vertexCount > 0 else { return }

        switch immediateMode {
        case .quads:
            // Quads are independent per group of 4 vertices (not a fan
            // across the whole batch) - matters for Atlas_ImmediateDraw,
            // which submits many quads (one per glyph) in a single
            // begin/end block.
            var tris: [Float] = []
            tris.reserveCapacity((vertexCount / 4) * 6 * kFloatsPerVertex)
            var q = 0
            while q + 4 <= vertexCount {
                let base = q * kFloatsPerVertex
                func vert(_ i: Int) -> ArraySlice<Float> { immediateVerts[(base + i * kFloatsPerVertex)..<(base + i * kFloatsPerVertex + kFloatsPerVertex)] }
                tris.append(contentsOf: vert(0)); tris.append(contentsOf: vert(1)); tris.append(contentsOf: vert(2))
                tris.append(contentsOf: vert(0)); tris.append(contentsOf: vert(2)); tris.append(contentsOf: vert(3))
                q += 4
            }
            tris.withUnsafeBufferPointer { buf in
                guard let base = buf.baseAddress else { return }
                renderer.draw(base, vertexCount: tris.count / kFloatsPerVertex, primitive: .triangles)
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
    /// accumulator (one interleaved vertex per index). Normals feed sphere-
    /// map reflection texgen only - there's still no lighting model, so
    /// they're otherwise unused. Per-vertex colors override the current
    /// material color exactly like GL's color arrays do. uv1 feeds the
    /// second texture unit (plain multi-texture MODULATE, e.g. Infobar's
    /// health/shield/fuel circular mask, when texgen isn't active).
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
                if let uv1 {
                    setTexCoord1(uv1[i].u, uv1[i].v)
                }
                if let normals {
                    setNormal(normals[i].x, normals[i].y, normals[i].z)
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
