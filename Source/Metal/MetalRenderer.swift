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

/// Interleaved vertex layout every draw call here uses: position (3) + UV
/// (2) + RGBA color (4) = 9 floats. Matches the MSL vertex descriptor below.
private let kFloatsPerVertex = 9

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
    float2 texCoord [[attribute(1)]];
    float4 color [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
};

vertex VertexOut vertex_main(VertexIn in [[stage_in]],
                              constant float4x4 &mvp [[buffer(1)]]) {
    VertexOut out;
    out.position = mvp * float4(in.position, 1.0);
    out.texCoord = in.texCoord;
    out.color = in.color;
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                               texture2d<float> tex [[texture(0)]],
                               sampler samp [[sampler(0)]]) {
    return tex.sample(samp, in.texCoord) * in.color;
}
"""

public final class MetalRenderer {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let layer: CAMetalLayer

    private let pipelineBlendOff: MTLRenderPipelineState
    private let pipelineBlendOn: MTLRenderPipelineState
    private let depthStateOn: MTLDepthStencilState
    private let depthStateOff: MTLDepthStencilState
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
    private var depthTestEnabled = true
    private var boundTextureHandle: Int32 = -1

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
        vertexDescriptor.attributes[2].format = .float4
        vertexDescriptor.attributes[2].offset = MemoryLayout<Float>.stride * 5
        vertexDescriptor.attributes[2].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * kFloatsPerVertex

        func makePipeline(blend: Bool) -> MTLRenderPipelineState? {
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = vertexFunction
            desc.fragmentFunction = fragmentFunction
            desc.vertexDescriptor = vertexDescriptor
            desc.depthAttachmentPixelFormat = .depth32Float
            let colorAttachment = desc.colorAttachments[0]!
            colorAttachment.pixelFormat = .bgra8Unorm
            colorAttachment.isBlendingEnabled = blend
            if blend {
                colorAttachment.rgbBlendOperation = .add
                colorAttachment.alphaBlendOperation = .add
                colorAttachment.sourceRGBBlendFactor = .sourceAlpha
                colorAttachment.sourceAlphaBlendFactor = .sourceAlpha
                colorAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
                colorAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            }
            return try? device.makeRenderPipelineState(descriptor: desc)
        }

        guard let pipelineBlendOff = makePipeline(blend: false),
              let pipelineBlendOn = makePipeline(blend: true) else {
            return nil
        }
        self.pipelineBlendOff = pipelineBlendOff
        self.pipelineBlendOn = pipelineBlendOn

        let depthOnDesc = MTLDepthStencilDescriptor()
        depthOnDesc.depthCompareFunction = .less
        depthOnDesc.isDepthWriteEnabled = true
        guard let depthStateOn = device.makeDepthStencilState(descriptor: depthOnDesc) else { return nil }
        self.depthStateOn = depthStateOn

        let depthOffDesc = MTLDepthStencilDescriptor()
        depthOffDesc.depthCompareFunction = .always
        depthOffDesc.isDepthWriteEnabled = false
        guard let depthStateOff = device.makeDepthStencilState(descriptor: depthOffDesc) else { return nil }
        self.depthStateOff = depthStateOff

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
        depthTestEnabled = true
        boundTextureHandle = -1
        encoder.setRenderPipelineState(pipelineBlendOff)
        encoder.setDepthStencilState(depthStateOn)
        encoder.setFragmentSamplerState(sampler, index: 0)
        encoder.setFragmentTexture(whiteTexture, index: 0)
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

    public func setBlend(_ enabled: Bool) {
        guard blendEnabled != enabled, let encoder else { return }
        blendEnabled = enabled
        encoder.setRenderPipelineState(enabled ? pipelineBlendOn : pipelineBlendOff)
    }

    public func setDepthTest(_ enabled: Bool) {
        guard depthTestEnabled != enabled, let encoder else { return }
        depthTestEnabled = enabled
        encoder.setDepthStencilState(enabled ? depthStateOn : depthStateOff)
    }

    // MARK: - Textures

    public func createTexture(width: Int, height: Int, bgraPixels: UnsafeRawPointer) -> Int32 {
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: max(width, 1), height: max(height, 1), mipmapped: false)
        desc.usage = [.shaderRead]
        guard let texture = device.makeTexture(descriptor: desc) else { return -1 }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: bgraPixels, bytesPerRow: width * 4)

        let handle = nextTextureHandle
        nextTextureHandle += 1
        textures[handle] = texture
        return handle
    }

    public func updateTexture(_ handle: Int32, width: Int, height: Int, bgraPixels: UnsafeRawPointer) {
        guard let texture = textures[handle] else { return }
        texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: bgraPixels, bytesPerRow: width * 4)
    }

    /// `handle` of -1 (or unknown) binds the default white texture, matching
    /// `RenderBackend.disableTexture2D`'s "draw with plain vertex colour"
    /// effect.
    public func bindTexture(_ handle: Int32) {
        guard boundTextureHandle != handle, let encoder else { return }
        boundTextureHandle = handle
        encoder.setFragmentTexture(textures[handle] ?? whiteTexture, index: 0)
    }

    // MARK: - Draw

    /// `vertices` is `vertexCount` vertices, each 9 interleaved floats
    /// (position.xyz, uv, color.rgba) - see `kFloatsPerVertex`.
    public func draw(_ vertices: UnsafePointer<Float>, vertexCount: Int, primitive: MetalPrimitive) {
        guard let encoder, vertexCount > 0 else { return }

        let length = MemoryLayout<Float>.stride * kFloatsPerVertex * vertexCount
        encoder.setVertexBytes(vertices, length: length, index: 0)

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
