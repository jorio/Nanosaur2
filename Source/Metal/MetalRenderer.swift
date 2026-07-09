// MetalRenderer.swift
//
// The native-Metal renderer, in its OWN Swift module (CMake target
// `MetalRenderer`), compiled WITHOUT this project's -import-objc-header
// bridging header. That isolation is mandatory: `import Metal` transitively
// pulls in the Darwin `MacTypes` Clang module, whose `Point`/`Rect` collide
// with the game's own `SwMacTypes.h` (which every bridging-header'd Swift
// file gets) - see docs/metal-renderer-plan.md's Phase 0 finding. Because
// this module has no bridging header, there is no `SwMacTypes.h` here and no
// collision.
//
// This module deliberately depends on NOTHING from the game (no SDL, no
// game.h): the main module (which has SDL) creates the CAMetalLayer via
// SDL_Metal_CreateView/GetLayer and passes the raw layer pointer in. Its
// public API uses only primitive/Swift-native types and opaque handles, so
// the main module can `import MetalRenderer` without Metal/QuartzCore ever
// becoming visible to the main module's ClangImporter (which would
// re-trigger the collision).
//
// This module also knows NOTHING about GL enums/semantics (GL_QUADS,
// GL_TRIANGLES, blend func constants, etc.) - the main module's
// MetalRenderBackend (Source/3D/MetalRenderBackend.swift) is responsible for
// translating the RenderBackend facade's GL-shaped verbs into the plain
// primitive-typed calls here (interleaved float vertices, a triangle/line
// draw mode, integer texture handles). That keeps this module a dumb, GL-
// agnostic Metal draw layer.

// @_implementationOnly: Metal/QuartzCore are an implementation detail of this
// module and must NOT leak to clients. Without this, the game module (which
// gets SwMacTypes.h via its bridging header) would transitively load Metal's
// Clang modules when it `import MetalRenderer`, re-triggering the
// Point/MacTypes collision (see docs/metal-renderer-plan.md Phase 0). This
// module's public API deliberately exposes zero Metal/QuartzCore types, which
// is what makes implementation-only importing legal here.
@_implementationOnly import Metal
@_implementationOnly import QuartzCore

/// Interleaved vertex layout every draw call here uses: position (3) + UV0
/// (2) + UV1 (2) + normal (3) + RGBA color (4) = 14 floats. Matches the MSL
/// vertex descriptor below.
///  - UV1 feeds the second texture unit (multi-texture modulate, e.g. the
///    Infobar health/shield/fuel gauges' circular mask) - callers that only
///    use one texture leave it at (0,0), harmless since texture unit 1
///    defaults to the 1x1 white texture (multiplying by white is a no-op).
///  - normal feeds sphere-map reflection texgen (MULTI_TEXTURE_MODE_
///    REFLECTIONSPHERE - shiny materials like the jetpack/goggles/crystals),
///    which overrides UV1 with a computed reflection coordinate when
///    enabled (see setSphereMapTexGen). Callers that don't use it leave it
///    at (0,0,0), unused since the flag defaults off.
/// Public so MetalRenderBackend.swift (main module) can size its
/// interleaved vertex buffer identically instead of duplicating the
/// literal.
public let kFloatsPerVertex = 14

/// Mirrors `RenderBackend`'s immediate-mode primitive shapes, but as a plain
/// enum so this module doesn't need to know about GLenum.
public enum MetalPrimitive: Int32 {
    case triangles = 0
    case lines = 1
    case lineLoop = 2
}

private let shaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float2 texCoord0 [[attribute(1)]];
    float2 texCoord1 [[attribute(2)]];
    float3 normal [[attribute(3)]];
    float4 color [[attribute(4)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord0;
    float2 texCoord1;
    float3 eyeNormal;
    float4 color;
};

// Ambient + up to 4 directional fill lights (MAX_FILL_LIGHTS - see
// RenderBackend.setLights). lights[0].xyz = ambient, lights[0].w = light
// count; lights[1..4] = eye-space directions (see MetalRenderBackend's
// syncLighting); lights[5..8] = diffuse colors. One struct instead of
// separate buffers - it's all pushed together every time it changes.
struct LightingData {
    float4 ambientAndCount;
    float4 directions[4];
    float4 colors[4];
};

vertex VertexOut vertex_main(VertexIn in [[stage_in]],
                              constant float4x4 &mvp [[buffer(1)]],
                              constant float4x4 &textureMatrix [[buffer(2)]],
                              constant float4x4 &modelview [[buffer(3)]],
                              constant float &useSphereMap [[buffer(4)]]) {
    VertexOut out;
    out.position = mvp * float4(in.position, 1.0);
    // Every projection matrix in the game (glOrtho/glFrustum-equivalent
    // math in RenderBackend.swift/3DMath_Matrix.swift) is built to OpenGL's
    // convention: clip-space z/w lands in [-1,1]. Metal's rasterizer clips
    // against [0,1] instead, so left as-is this discards roughly the near
    // half of every projection's range - for 2D content drawn at z=0 with
    // an orthographic near/far of (0,1), that's clip.z/w == -1 for
    // *everything*, i.e. the whole 2D UI vanishes. Standard GL->Metal port
    // fix: remap after the transform, independent of which matrix produced
    // it.
    out.position.z = (out.position.z + out.position.w) * 0.5;
    // GL's texture matrix only ever affects the active server-side texture
    // unit (unit 0 in every call site in this codebase - see
    // MetalRenderBackend.swift's syncGPUMatrices) - animates scrolling UVs
    // (Wormhole.swift's tunnel, Water.swift's surface, UV-transform items).
    // Unit 1 (the mask/modulate texture, when used) intentionally stays
    // unscrolled, UNLESS sphere-map reflection texgen is active (shiny
    // materials - jetpack, goggles, crystals), which computes it instead of
    // using the per-vertex UV: GL_SPHERE_MAP's formula on the eye-space
    // reflection vector.
    out.texCoord0 = (textureMatrix * float4(in.texCoord0, 0.0, 1.0)).xy;
    // Eye-space normal - feeds both sphere-map texgen below and the
    // fragment shader's lighting (only actually read there when lighting is
    // enabled for this draw; a zero input normal, from geometry that never
    // populates one, normalizes to NaN but is simply never sampled in that
    // case). GL_NORMALIZE is effectively always applied here (this game
    // only skips it as a perf optimization when scale==1, which produces an
    // identical result anyway).
    float3 eyeNormal = normalize((modelview * float4(in.normal, 0.0)).xyz);
    out.eyeNormal = eyeNormal;
    if (useSphereMap > 0.5) {
        float3 eyePos = (modelview * float4(in.position, 1.0)).xyz;
        float3 r = reflect(normalize(eyePos), eyeNormal);
        float m = 2.0 * sqrt(r.x * r.x + r.y * r.y + (r.z + 1.0) * (r.z + 1.0));
        out.texCoord1 = float2(r.x / m + 0.5, r.y / m + 0.5);
    } else {
        out.texCoord1 = in.texCoord1;
    }
    out.color = in.color;
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                               texture2d<float> tex0 [[texture(0)]],
                               texture2d<float> tex1 [[texture(1)]],
                               sampler samp [[sampler(0)]],
                               constant float &alphaThreshold [[buffer(1)]],
                               constant float &lightingEnabled [[buffer(2)]],
                               constant LightingData &lighting [[buffer(3)]]) {
    float4 vertexColor = in.color;
    if (lightingEnabled > 0.5) {
        // Matches this game's fixed-function GL lighting setup exactly:
        // GL_COLOR_MATERIAL tracks both ambient and diffuse material color
        // to glColor (the current vertex color), no specular is ever set,
        // and lights are directional-only (w=0, so no attenuation) - which
        // reduces the standard GL lighting equation to
        // vertexColor * (globalAmbient + sum(max(0, N.L) * lightDiffuse)).
        float3 n = normalize(in.eyeNormal);
        float3 lit = lighting.ambientAndCount.xyz;
        int numLights = int(lighting.ambientAndCount.w);
        for (int i = 0; i < numLights; i++) {
            float ndotl = max(0.0, dot(n, lighting.directions[i].xyz));
            lit += ndotl * lighting.colors[i].xyz;
        }
        vertexColor = float4(in.color.rgb * lit, in.color.a);
    }
    // Texture unit 1 defaults to a 1x1 white texture when the draw doesn't
    // use a second texture, so this modulate is a no-op in the common case.
    // Implements GL's plain multi-texture MODULATE combine (the Infobar
    // health/shield/fuel gauges' circular mask, sphere-map reflections,
    // etc.) - the ADD/ADD_ALPHA combine modes still render as MODULATE
    // (see MetalRenderBackend.swift's header comment).
    float4 c = tex0.sample(samp, in.texCoord0) * tex1.sample(samp, in.texCoord1) * vertexColor;
    // Emulates GL_ALPHA_TEST (alphaThreshold < 0 means the test is off).
    // Matches the two configurations the game uses (RenderBackend.swift's
    // setAlphaClipping): default is "discard fully-transparent pixels only"
    // (threshold 0), STATUS_BIT_CLIPALPHA6 trims low alpha (threshold 0.6).
    // Without this, cutout sprites that rely on the test (not blending) to
    // punch out their background render as solid quads.
    if (alphaThreshold >= 0.0 && c.a <= alphaThreshold) {
        discard_fragment();
    }
    return c;
}
"""

public final class MetalRenderer {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let layer: CAMetalLayer

    private let pipelineBlendOff: MTLRenderPipelineState
    private let pipelineBlendOn: MTLRenderPipelineState
    private let pipelineBlendAdditive: MTLRenderPipelineState
    /// Indexed [testEnabled][writeEnabled] - GL exposes depth *test*
    /// (GL_DEPTH_TEST) and depth *write* (glDepthMask) as independent
    /// toggles, so all four combinations must exist as pre-built states.
    private let depthStates: [[MTLDepthStencilState]]
    private let sampler: MTLSamplerState

    /// 1x1 opaque white texture bound whenever the facade has no texture
    /// bound, so the shader can always sample instead of branching on a
    /// "textured?" flag - matches `RenderBackend.disableTexture2D`'s effect
    /// (draws using only the vertex/material color).
    private let whiteTexture: MTLTexture

    private var textures: [Int32: MTLTexture] = [:]
    private var nextTextureHandle: Int32 = 1

    private var depthTexture: MTLTexture?
    private var drawableWidth: Int = 1
    private var drawableHeight: Int = 1

    // Per-frame state
    private var commandBuffer: MTLCommandBuffer?
    private var encoder: MTLRenderCommandEncoder?
    private var currentDrawable: CAMetalDrawable?
    private var blendEnabled = false
    private var blendAdditive = false
    private var depthTestEnabled = true
    private var depthWriteEnabled = true
    private var boundTextureHandle: Int32 = -1
    private var boundTexture1Handle: Int32 = -1
    private var alphaThreshold: Float = 0
    private var lightingEnabled: Float = 0
    /// Matches the shader's LightingData layout: ambient.xyz + count, 4x
    /// direction.xyz+pad, 4x color.xyz+pad = 36 floats.
    private var lightingData = [Float](repeating: 0, count: 36)

    /// - Parameter layerPointer: a `CAMetalLayer*` obtained by the caller via
    ///   `SDL_Metal_GetLayer(SDL_Metal_CreateView(window))`, passed as a raw
    ///   pointer so this module needs no SDL dependency.
    public init?(layerPointer: UnsafeMutableRawPointer) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            return nil
        }
        self.device = device
        self.queue = queue
        self.layer = Unmanaged<CAMetalLayer>.fromOpaque(layerPointer).takeUnretainedValue()
        self.layer.device = device
        self.layer.pixelFormat = .bgra8Unorm
        self.layer.framebufferOnly = true

        guard let library = try? device.makeLibrary(source: shaderSource, options: nil),
              let vertexFunction = library.makeFunction(name: "vertex_main"),
              let fragmentFunction = library.makeFunction(name: "fragment_main") else {
            return nil
        }

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.stride * 3
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[2].format = .float2
        vertexDescriptor.attributes[2].offset = MemoryLayout<Float>.stride * 5
        vertexDescriptor.attributes[2].bufferIndex = 0
        vertexDescriptor.attributes[3].format = .float3
        vertexDescriptor.attributes[3].offset = MemoryLayout<Float>.stride * 7
        vertexDescriptor.attributes[3].bufferIndex = 0
        vertexDescriptor.attributes[4].format = .float4
        vertexDescriptor.attributes[4].offset = MemoryLayout<Float>.stride * 10
        vertexDescriptor.attributes[4].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * kFloatsPerVertex

        // The game only ever calls glBlendFunc with two factor pairs (see
        // RenderBackend.swift's RBBlendFactor/rbBlendFactor): standard
        // "source-over" alpha (srcAlpha, oneMinusSrcAlpha) for normal
        // transparency, and additive (srcAlpha, one) for glow/light sprites
        // that paint a black "background" meant to vanish under addition
        // (black * anything = 0, so it just adds nothing) - GL bakes the
        // factors into per-draw state; Metal bakes them into pipeline state,
        // so each combination needs its own precompiled pipeline.
        func makePipeline(dst: MTLBlendFactor?) -> MTLRenderPipelineState? {
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = vertexFunction
            desc.fragmentFunction = fragmentFunction
            desc.vertexDescriptor = vertexDescriptor
            desc.depthAttachmentPixelFormat = .depth32Float
            let colorAttachment = desc.colorAttachments[0]!
            colorAttachment.pixelFormat = .bgra8Unorm
            colorAttachment.isBlendingEnabled = dst != nil
            if let dst {
                colorAttachment.rgbBlendOperation = .add
                colorAttachment.alphaBlendOperation = .add
                colorAttachment.sourceRGBBlendFactor = .sourceAlpha
                colorAttachment.sourceAlphaBlendFactor = .sourceAlpha
                colorAttachment.destinationRGBBlendFactor = dst
                colorAttachment.destinationAlphaBlendFactor = dst
            }
            return try? device.makeRenderPipelineState(descriptor: desc)
        }

        guard let pipelineBlendOff = makePipeline(dst: nil),
              let pipelineBlendOn = makePipeline(dst: .oneMinusSourceAlpha),
              let pipelineBlendAdditive = makePipeline(dst: .one) else {
            return nil
        }
        self.pipelineBlendOff = pipelineBlendOff
        self.pipelineBlendOn = pipelineBlendOn
        self.pipelineBlendAdditive = pipelineBlendAdditive

        var depthStates: [[MTLDepthStencilState]] = []
        for testEnabled in [false, true] {
            var row: [MTLDepthStencilState] = []
            for writeEnabled in [false, true] {
                let desc = MTLDepthStencilDescriptor()
                desc.depthCompareFunction = testEnabled ? .less : .always
                desc.isDepthWriteEnabled = writeEnabled
                guard let state = device.makeDepthStencilState(descriptor: desc) else { return nil }
                row.append(state)
            }
            depthStates.append(row)
        }
        self.depthStates = depthStates

        let samplerDesc = MTLSamplerDescriptor()
        samplerDesc.minFilter = .linear
        samplerDesc.magFilter = .linear
        samplerDesc.sAddressMode = .repeat
        samplerDesc.tAddressMode = .repeat
        guard let sampler = device.makeSamplerState(descriptor: samplerDesc) else { return nil }
        self.sampler = sampler

        let whiteDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 1, height: 1, mipmapped: false)
        whiteDesc.usage = [.shaderRead]
        guard let whiteTexture = device.makeTexture(descriptor: whiteDesc) else { return nil }
        var whitePixel: UInt32 = 0xFFFF_FFFF
        whiteTexture.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: &whitePixel, bytesPerRow: 4)
        self.whiteTexture = whiteTexture
    }

    /// Name of the Metal device, for a startup log line confirming the
    /// renderer is live.
    public var deviceName: String { device.name }

    public func setDrawableSize(width: Int, height: Int) {
        drawableWidth = max(width, 1)
        drawableHeight = max(height, 1)
        layer.drawableSize = CGSize(width: drawableWidth, height: drawableHeight)

        let depthDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: drawableWidth, height: drawableHeight, mipmapped: false)
        depthDesc.usage = [.renderTarget]
        depthDesc.storageMode = .private
        depthTexture = device.makeTexture(descriptor: depthDesc)
    }

    /// Phase 0 spike: clear the whole drawable to a colour and present it.
    /// Kept for the `--metal` spike path (Boot.cpp's `RunMetalSpike`).
    public func clearFrame(red: Float, green: Float, blue: Float) {
        guard let drawable = layer.nextDrawable() else { return }

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: Double(red), green: Double(green), blue: Double(blue), alpha: 1)

        guard let commandBuffer = queue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
            return
        }
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Real frame lifecycle

    /// Starts a frame: acquires a drawable, clears colour+depth, and opens a
    /// render command encoder that subsequent draw calls append to. Returns
    /// false if no drawable was available (caller should just skip the
    /// frame, same as GL's `OGL_DrawScene` implicitly does when the window
    /// isn't presentable).
    public func beginFrame(red: Float, green: Float, blue: Float) -> Bool {
        guard let drawable = layer.nextDrawable(), let depthTexture else { return false }
        currentDrawable = drawable

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: Double(red), green: Double(green), blue: Double(blue), alpha: 1)
        pass.depthAttachment.texture = depthTexture
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.storeAction = .dontCare
        pass.depthAttachment.clearDepth = 1.0

        guard let commandBuffer = queue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
            currentDrawable = nil
            return false
        }
        self.commandBuffer = commandBuffer
        self.encoder = encoder

        blendEnabled = false
        blendAdditive = false
        depthTestEnabled = true
        depthWriteEnabled = true
        boundTextureHandle = -1
        boundTexture1Handle = -1
        alphaThreshold = 0
        encoder.setRenderPipelineState(pipelineBlendOff)
        encoder.setDepthStencilState(depthStates[1][1])
        encoder.setFragmentSamplerState(sampler, index: 0)
        encoder.setFragmentTexture(whiteTexture, index: 0)
        encoder.setFragmentTexture(whiteTexture, index: 1)
        encoder.setFragmentBytes(&alphaThreshold, length: MemoryLayout<Float>.stride, index: 1)
        // Default to identity. A new encoder has nothing bound at buffer
        // index 2 until the first setTextureMatrix call each frame - most
        // draws don't animate UVs and never call it, but everything sharing
        // this encoder still needs a valid (identity = no-op) matrix bound
        // before its first draw.
        var identityMatrix: [Float] = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
        encoder.setVertexBytes(&identityMatrix, length: MemoryLayout<Float>.stride * 16, index: 2)
        encoder.setVertexBytes(&identityMatrix, length: MemoryLayout<Float>.stride * 16, index: 3)
        sphereMapEnabled = 0
        encoder.setVertexBytes(&sphereMapEnabled, length: MemoryLayout<Float>.stride, index: 4)
        lightingEnabled = 0
        encoder.setFragmentBytes(&lightingEnabled, length: MemoryLayout<Float>.stride, index: 2)
        lightingData.withUnsafeBufferPointer { buf in
            encoder.setFragmentBytes(buf.baseAddress!, length: MemoryLayout<Float>.stride * 36, index: 3)
        }
        encoder.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(drawableWidth), height: Double(drawableHeight), znear: 0, zfar: 1))

        return true
    }

    public func endFrame() {
        guard let encoder, let commandBuffer, let drawable = currentDrawable else { return }
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()

        self.encoder = nil
        self.commandBuffer = nil
        self.currentDrawable = nil
    }

    public func setViewport(x: Float, y: Float, width: Float, height: Float) {
        encoder?.setViewport(MTLViewport(originX: Double(x), originY: Double(y), width: Double(width), height: Double(height), znear: 0, zfar: 1))
    }

    /// `m` points to 16 floats, column-major (matches `OGLMatrix4x4`/
    /// `glLoadMatrixf`'s layout).
    public func setMVP(_ m: UnsafePointer<Float>) {
        encoder?.setVertexBytes(m, length: MemoryLayout<Float>.stride * 16, index: 1)
    }

    /// Same layout as `setMVP`. Transforms texCoord0 in the vertex shader -
    /// animates scrolling UV effects (see MetalRenderBackend.swift's
    /// syncGPUMatrices).
    public func setTextureMatrix(_ m: UnsafePointer<Float>) {
        encoder?.setVertexBytes(m, length: MemoryLayout<Float>.stride * 16, index: 2)
    }

    /// Same layout as `setMVP`. Used (only) for sphere-map reflection
    /// texgen's eye-space position/normal transform - GL's GL_SPHERE_MAP
    /// reflects in eye space, so the vertex shader needs modelview
    /// separately from the combined MVP.
    public func setModelView(_ m: UnsafePointer<Float>) {
        encoder?.setVertexBytes(m, length: MemoryLayout<Float>.stride * 16, index: 3)
    }

    private var sphereMapEnabled: Float = 0
    /// Enables sphere-map reflection texgen (GL_SPHERE_MAP) for subsequent
    /// draws - computes texCoord1 from the eye-space reflection vector
    /// instead of using the per-vertex UV. Used for shiny materials
    /// (jetpack, goggles, crystals - MULTI_TEXTURE_MODE_REFLECTIONSPHERE).
    public func setSphereMapTexGen(_ enabled: Bool) {
        let v: Float = enabled ? 1 : 0
        guard sphereMapEnabled != v, let encoder else { return }
        sphereMapEnabled = v
        encoder.setVertexBytes(&sphereMapEnabled, length: MemoryLayout<Float>.stride, index: 4)
    }

    public func setLightingEnabled(_ enabled: Bool) {
        let v: Float = enabled ? 1 : 0
        guard lightingEnabled != v, let encoder else { return }
        lightingEnabled = v
        encoder.setFragmentBytes(&lightingEnabled, length: MemoryLayout<Float>.stride, index: 2)
    }

    /// `ambient` and each of up to 4 `directions`/`colors` are 3 floats
    /// (rgb / xyz); `directions` must already be in eye space (see
    /// MetalRenderBackend.swift's syncLighting) - matches GL's glLightfv
    /// semantics, which bakes in whatever modelview was active at the time
    /// of the call. Pushed every time the game recomputes this (ambient/
    /// colors rarely, directions every frame the camera moves), not just
    /// when enabled - so the data is always current by the time
    /// setLightingEnabled(true) is (re-)asserted for the next lit draw.
    public func setLightingData(ambient: (Float, Float, Float), count: Int32, directions: UnsafePointer<Float>, colors: UnsafePointer<Float>) {
        lightingData[0] = ambient.0
        lightingData[1] = ambient.1
        lightingData[2] = ambient.2
        lightingData[3] = Float(count)
        for i in 0..<Int(count) {
            lightingData[4 + i * 4 + 0] = directions[i * 3 + 0]
            lightingData[4 + i * 4 + 1] = directions[i * 3 + 1]
            lightingData[4 + i * 4 + 2] = directions[i * 3 + 2]
            lightingData[20 + i * 4 + 0] = colors[i * 3 + 0]
            lightingData[20 + i * 4 + 1] = colors[i * 3 + 1]
            lightingData[20 + i * 4 + 2] = colors[i * 3 + 2]
        }
        lightingData.withUnsafeBufferPointer { buf in
            encoder?.setFragmentBytes(buf.baseAddress!, length: MemoryLayout<Float>.stride * 36, index: 3)
        }
    }

    public func setBlend(_ enabled: Bool) {
        guard blendEnabled != enabled else { return }
        blendEnabled = enabled
        applyBlendPipeline()
    }

    /// Selects which blend factors to use while blending is enabled -
    /// standard "source-over" alpha, or additive (glow/light sprites). A
    /// no-op while blending is disabled; takes effect next time it's
    /// enabled, matching GL's glBlendFunc (a persistent setting independent
    /// of glEnable(GL_BLEND)).
    public func setBlendAdditive(_ additive: Bool) {
        guard blendAdditive != additive else { return }
        blendAdditive = additive
        if blendEnabled {
            applyBlendPipeline()
        }
    }

    private func applyBlendPipeline() {
        guard let encoder else { return }
        if !blendEnabled {
            encoder.setRenderPipelineState(pipelineBlendOff)
        } else {
            encoder.setRenderPipelineState(blendAdditive ? pipelineBlendAdditive : pipelineBlendOn)
        }
    }

    public func setDepthTest(_ enabled: Bool) {
        guard depthTestEnabled != enabled else { return }
        depthTestEnabled = enabled
        applyDepthState()
    }

    public func setDepthWrite(_ enabled: Bool) {
        guard depthWriteEnabled != enabled else { return }
        depthWriteEnabled = enabled
        applyDepthState()
    }

    /// `threshold` of nil disables the test (always passes); otherwise
    /// fragments with alpha <= threshold are discarded.
    public func setAlphaTest(threshold: Float?) {
        let t = threshold ?? -1
        guard alphaThreshold != t, let encoder else { return }
        alphaThreshold = t
        encoder.setFragmentBytes(&alphaThreshold, length: MemoryLayout<Float>.stride, index: 1)
    }

    private func applyDepthState() {
        encoder?.setDepthStencilState(depthStates[depthTestEnabled ? 1 : 0][depthWriteEnabled ? 1 : 0])
    }

    // MARK: - Textures

    /// `bgra` selects the byte order of `pixels`: true = BGRA8 (the game's
    /// runtime-generated textures), false = RGBA8 (stb_image-decoded
    /// PNG/JPG and BG3D textures - the common case). Metal samples both
    /// identically; picking the matching pixel format avoids a CPU swizzle.
    public func createTexture(width: Int, height: Int, pixels: UnsafeRawPointer, bgra: Bool) -> Int32 {
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: bgra ? .bgra8Unorm : .rgba8Unorm, width: max(width, 1), height: max(height, 1), mipmapped: false)
        desc.usage = [.shaderRead]
        guard let texture = device.makeTexture(descriptor: desc) else { return -1 }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: pixels, bytesPerRow: width * 4)

        let handle = nextTextureHandle
        nextTextureHandle += 1
        textures[handle] = texture
        return handle
    }

    public func updateTexture(_ handle: Int32, width: Int, height: Int, bgraPixels: UnsafeRawPointer) {
        guard let texture = textures[handle] else { return }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: bgraPixels, bytesPerRow: width * 4)
    }

    public func deleteTexture(_ handle: Int32) {
        textures.removeValue(forKey: handle)
    }

    /// Vertical sync (drawable presentation paced to display refresh).
    public func setVSync(_ enabled: Bool) {
        layer.displaySyncEnabled = enabled
    }

    /// `handle` of -1 (or unknown) binds the default white texture, matching
    /// `RenderBackend.disableTexture2D`'s "draw with plain vertex colour"
    /// effect.
    public func bindTexture(_ handle: Int32) {
        guard boundTextureHandle != handle, let encoder else { return }
        boundTextureHandle = handle
        encoder.setFragmentTexture(textures[handle] ?? whiteTexture, index: 0)
    }

    /// Second texture unit, for plain multi-texture MODULATE draws (see the
    /// shader's fragment_main). `handle` of -1 binds the default white
    /// texture, which makes the modulate a no-op for single-texture draws.
    public func bindTexture1(_ handle: Int32) {
        guard boundTexture1Handle != handle, let encoder else { return }
        boundTexture1Handle = handle
        encoder.setFragmentTexture(textures[handle] ?? whiteTexture, index: 1)
    }

    // MARK: - Draw

    /// `vertices` is `vertexCount` vertices, each 11 interleaved floats
    /// (position.xyz, uv0, uv1, color.rgba) - see `kFloatsPerVertex`.
    public func draw(_ vertices: UnsafePointer<Float>, vertexCount: Int, primitive: MetalPrimitive) {
        guard let encoder, vertexCount > 0 else { return }

        let length = MemoryLayout<Float>.stride * kFloatsPerVertex * vertexCount
        if length <= 4096 {
            // Metal caps setVertexBytes at 4KB (hit in practice: a ~20-quad
            // text mesh is 4320 bytes and trips the validation layer).
            encoder.setVertexBytes(vertices, length: length, index: 0)
        } else {
            // Larger draws need a real buffer. Per-draw allocation is fine
            // at menu-scale draw counts; revisit (ring buffer) if this ever
            // handles per-frame 3D-world volume.
            guard let buffer = device.makeBuffer(bytes: vertices, length: length, options: .storageModeShared) else { return }
            encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        }

        switch primitive {
        case .triangles:
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
        case .lines:
            encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: vertexCount)
        case .lineLoop:
            // Metal has no line-loop primitive. Everywhere this is used is a
            // debug bounding-rect outline (F8 debug mode), so a line strip
            // missing only the closing edge is a cosmetic gap, not a
            // correctness issue.
            encoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: vertexCount)
        }
    }
}
