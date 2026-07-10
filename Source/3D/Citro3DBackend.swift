// Citro3DBackend.swift - the 3DS RenderBackend implementation, backed by
// ports/3DS/common/c3d_renderer.c (citro3d). Replaces GLRenderBackend +
// picaGL on this platform: picaGL's draw path lost texturing on healthy
// inputs (bound texture, sane UVs, modulate env - probed at the GL
// boundary) and silently downgraded every texture to 4-bit RGBA4, so it
// was removed in favor of a thin, ownable citro3d layer.
//
// This class is a 1:1 forwarding shim - all real state, matrix, texture,
// and draw logic lives in c3d_renderer.c. Phase-A gaps live there too (no
// lighting/fog/sphere-map texgen yet - parity with what picaGL actually
// delivered); the corresponding verbs here are deliberate no-ops.

#if NANOSAUR_3DS

final class Citro3DRenderBackend: RenderBackend {
    // Alpha test is two GL verbs (enable + func) but one C call; track both.
    private var alphaTestEnabled = true
    private var alphaTrimLowAlpha = false

    func enableBlend() { C3DR_SetBlendEnabled(1) }
    func disableBlend() { C3DR_SetBlendEnabled(0) }
    func blendFunc(_ src: RBBlendFactor, _ dst: RBBlendFactor) {
        C3DR_SetBlendFunc(Self.factor(src), Self.factor(dst))
    }

    private static func factor(_ f: RBBlendFactor) -> Int32 {
        switch f {
        case .one: return C3DR_BLEND_ONE
        case .srcAlpha: return C3DR_BLEND_SRC_ALPHA
        case .oneMinusSrcAlpha: return C3DR_BLEND_ONE_MINUS_SRC_ALPHA
        }
    }

    func enableTexture2D() { C3DR_SetTexture2DEnabled(1) }
    func disableTexture2D() { C3DR_SetTexture2DEnabled(0) }

    func enableLighting() {} // phase B (hardware fragment lighting)
    func disableLighting() {}

    func enableCullFace() { C3DR_SetCullEnabled(1) }
    func disableCullFace() { C3DR_SetCullEnabled(0) }

    func enableFog() {} // phase B (C3D_FogLut)
    func disableFog() {}

    func enableDepthTest() { C3DR_SetDepthTestEnabled(1) }
    func disableDepthTest() { C3DR_SetDepthTestEnabled(0) }
    func setDepthWrite(_ enabled: Bool) { C3DR_SetDepthWrite(enabled ? 1 : 0) }

    func setAlphaClipping(trimLowAlpha: Bool) {
        alphaTrimLowAlpha = trimLowAlpha
        C3DR_SetAlphaTest(alphaTestEnabled ? 1 : 0, alphaTrimLowAlpha ? 1 : 0)
    }

    func setAlphaTestEnabled(_ enabled: Bool) {
        alphaTestEnabled = enabled
        C3DR_SetAlphaTest(alphaTestEnabled ? 1 : 0, alphaTrimLowAlpha ? 1 : 0)
    }

    func setTwoSidedLighting(_ enabled: Bool) {} // phase B, with lighting
    func setNormalizeNormals(_ enabled: Bool) {} // no fixed-function normals on PICA

    func setColor4f(_ r: Float, _ g: Float, _ b: Float, _ a: Float) {
        C3DR_SetColor4f(r, g, b, a)
    }

    func matrixMode(_ mode: RBMatrixMode) {
        switch mode {
        case .modelview: C3DR_MatrixMode(C3DR_MATRIX_MODELVIEW)
        case .projection: C3DR_MatrixMode(C3DR_MATRIX_PROJECTION)
        case .texture: C3DR_MatrixMode(C3DR_MATRIX_TEXTURE)
        }
    }

    func pushMatrix() { C3DR_PushMatrix() }
    func popMatrix() { C3DR_PopMatrix() }
    func loadIdentity() { C3DR_LoadIdentity() }
    func loadMatrix(_ m: UnsafePointer<Float>) { C3DR_LoadMatrix(m) }
    func multMatrix(_ m: UnsafePointer<Float>) { C3DR_MultMatrix(m) }
    func getModelViewMatrix(_ out: UnsafeMutablePointer<Float>) { C3DR_GetMatrix(C3DR_MATRIX_MODELVIEW, out) }
    func getProjectionMatrix(_ out: UnsafeMutablePointer<Float>) { C3DR_GetMatrix(C3DR_MATRIX_PROJECTION, out) }

    func frustum(_ left: Double, _ right: Double, _ bottom: Double, _ top: Double, _ near: Double, _ far: Double) {
        C3DR_Frustum(Float(left), Float(right), Float(bottom), Float(top), Float(near), Float(far))
    }

    func ortho(_ left: Double, _ right: Double, _ bottom: Double, _ top: Double, _ near: Double, _ far: Double) {
        C3DR_Ortho(Float(left), Float(right), Float(bottom), Float(top), Float(near), Float(far))
    }

    func bindTexture(_ name: RBTextureHandle) { C3DR_BindTexture(name) }

    func createTexture(width: Int32, height: Int32, format: RBPixelFormat, pixels: UnsafeRawPointer) -> RBTextureHandle {
        // .rgba8888Rev/.rgba1555Rev are BG3D imported-model paths that
        // Nanosaur 2's own data never hits (see RBPixelFormat) - treat as
        // plain RGBA8 rather than carrying dead conversion code.
        return C3DR_CreateTexture(width, height, pixels)
    }

    func updateTexture(_ name: RBTextureHandle, width: Int32, height: Int32, bgraPixels: UnsafeRawPointer) {
        C3DR_UpdateTextureBGRA(name, width, height, bgraPixels)
    }

    func deleteTextures(_ names: UnsafePointer<RBTextureHandle>, count: Int32) {
        for i in 0..<Int(count) {
            C3DR_DeleteTexture(names[i])
        }
    }

    func translate(_ x: Float, _ y: Float, _ z: Float) { C3DR_Translate(x, y, z) }
    func scale(_ x: Float, _ y: Float, _ z: Float) { C3DR_Scale(x, y, z) }
    func rotate(_ angle: Float, _ x: Float, _ y: Float, _ z: Float) { C3DR_Rotate(angle, x, y, z) }

    func setTextureWrap(_ axis: RBTextureAxis, clamp: Bool) {
        C3DR_SetTextureWrap(axis == .u ? 0 : 1, clamp ? 1 : 0)
    }

    func beginImmediate(_ mode: RBPrimitive) {
        switch mode {
        case .quads: C3DR_Begin(C3DR_PRIM_QUADS)
        case .triangles: C3DR_Begin(C3DR_PRIM_TRIANGLES)
        case .lines: C3DR_Begin(C3DR_PRIM_LINES)
        case .lineStrip: C3DR_Begin(C3DR_PRIM_LINE_STRIP)
        case .lineLoop: C3DR_Begin(C3DR_PRIM_LINE_LOOP)
        }
    }

    func vertex2f(_ x: Float, _ y: Float) { C3DR_Vertex3f(x, y, 0) }
    func vertex3f(_ x: Float, _ y: Float, _ z: Float) { C3DR_Vertex3f(x, y, z) }
    func texCoord2f(_ u: Float, _ v: Float) { C3DR_TexCoord2f(u, v) }
    func endImmediate() { C3DR_End() }

    func activeTextureUnit(_ unit: Int32) { C3DR_ActiveTextureUnit(unit) }

    func setTextureEnv(_ mode: RBTextureEnv) {
        switch mode {
        case .modulate: C3DR_SetTextureEnv(C3DR_TEXENV_MODULATE)
        case .combineAdd: C3DR_SetTextureEnv(C3DR_TEXENV_COMBINE_ADD)
        case .combineAddAlpha: C3DR_SetTextureEnv(C3DR_TEXENV_COMBINE_ADD_ALPHA)
        }
    }

    func setSphereMapTexGen(_ enabled: Bool) {} // phase B (envmapped models draw with base UVs)

    func drawIndexedGeometry(
        points: UnsafePointer<OGLPoint3D>,
        normals: UnsafePointer<OGLVector3D>?,
        colors: UnsafePointer<OGLColorRGBA>?,
        uv0: UnsafePointer<OGLTextureCoord>?,
        uv1: UnsafePointer<OGLTextureCoord>?,
        triangles: UnsafePointer<MOTriangleIndecies>?,
        numTriangles: Int32)
    {
        guard numTriangles != 0, let triangles else { return }
        // normals unused in phase A (no lighting)
        C3DR_DrawIndexedTriangles(
            UnsafeRawPointer(points).assumingMemoryBound(to: Float.self),
            colors.map { UnsafeRawPointer($0).assumingMemoryBound(to: Float.self) },
            uv0.map { UnsafeRawPointer($0).assumingMemoryBound(to: Float.self) },
            uv1.map { UnsafeRawPointer($0).assumingMemoryBound(to: Float.self) },
            UnsafeRawPointer(triangles).assumingMemoryBound(to: UInt32.self),
            numTriangles)
    }

    func prepareSceneDefaults() {
        alphaTestEnabled = true
        alphaTrimLowAlpha = false
        C3DR_SetAlphaTest(1, 0)
    }

    func setLights(ambientR: Float, ambientG: Float, ambientB: Float, numFillLights: Int32, fillDirections: UnsafePointer<OGLVector3D>, fillColors: UnsafePointer<OGLColorRGBA>) {
        // phase B: C3D_LightEnv hardware fragment lighting
    }

    func updateLightPositions(numFillLights: Int32, fillDirections: UnsafePointer<OGLVector3D>) {}

    func setFog(mode: RBFogMode, density: Float, start: Float, end: Float, r: Float, g: Float, b: Float, a: Float) {
        // phase B: C3D_FogLut
    }

    func setViewport(_ x: Int32, _ y: Int32, _ w: Int32, _ h: Int32) { C3DR_SetViewport(x, y, w, h) }
    func setClearColor(_ r: Float, _ g: Float, _ b: Float) { C3DR_SetClearColor(r, g, b) }
    func clearColorAndDepth() { C3DR_ClearColorAndDepth() }
    func clearDepthOnly() { C3DR_ClearDepthOnly() }
    func setWireframe(_ enabled: Bool) {} // no PICA polygon mode
    func present() { C3DR_Present() }

    func rendererInfo() -> String { "Nintendo 3DS (citro3d)" }

    func setColorMask(_ r: Bool, _ g: Bool, _ b: Bool, _ a: Bool) {
        C3DR_SetColorMask(r ? 1 : 0, g ? 1 : 0, b ? 1 : 0, a ? 1 : 0)
    }

    func setColorMaterialEnabled(_ enabled: Bool) {} // fixed-function GL concept

    func checkError() -> UInt32 { 0 }

    func createContext() {
        C3DR_Init()
        // Nominal sentinel so "is there a context" checks keep working
        // (same pattern picaGL's branch used).
        gEngine.view.aglContext = OpaquePointer(bitPattern: 1)
    }

    func destroyContext() {
        guard gEngine.view.aglContext != nil else { return }
        C3DR_Shutdown()
        gEngine.view.aglContext = nil
    }

    func setVSync(_ interval: Int32) {} // C3D_FrameEnd syncs to vblank
    func getVSync() -> Int32 { 1 }
}

#endif // NANOSAUR_3DS
