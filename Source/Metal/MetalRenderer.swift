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

// @_implementationOnly: Metal/QuartzCore are an implementation detail of this
// module and must NOT leak to clients. Without this, the game module (which
// gets SwMacTypes.h via its bridging header) would transitively load Metal's
// Clang modules when it `import MetalRenderer`, re-triggering the
// Point/MacTypes collision (see docs/metal-renderer-plan.md Phase 0). This
// module's public API deliberately exposes zero Metal/QuartzCore types, which
// is what makes implementation-only importing legal here.
@_implementationOnly import Metal
@_implementationOnly import QuartzCore

public final class MetalRenderer {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let layer: CAMetalLayer

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
    }

    /// Name of the Metal device, for a startup log line confirming the
    /// renderer is live.
    public var deviceName: String { device.name }

    /// Phase 0 spike: clear the whole drawable to a colour and present it.
    /// Proves the SDL layer -> Metal device -> render pass -> present path
    /// works end to end before any geometry work begins.
    public func clearFrame(red: Float, green: Float, blue: Float) {
        guard let drawable = layer.nextDrawable() else { return }

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(
            red: Double(red), green: Double(green), blue: Double(blue), alpha: 1)

        guard let commandBuffer = queue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
            return
        }
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    /// Keep the drawable size in sync with the window's pixel size (call on
    /// resize / each frame during the spike).
    public func setDrawableSize(width: Int, height: Int) {
        layer.drawableSize = CGSize(width: width, height: height)
    }
}
