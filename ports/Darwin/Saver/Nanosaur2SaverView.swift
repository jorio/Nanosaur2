// Nanosaur2SaverView.swift - the ScreenSaverView host for the Nanosaur 2
// wormhole screen saver (ports/Darwin).
//
// Its OWN Swift module, separate from the engine: it imports ScreenSaver/
// AppKit, which cannot coexist with the engine's bridging header
// (SwMacTypes.h vs Darwin.MacTypes - same split as MetalRenderer, see
// docs/metal-renderer-plan.md). It talks to the engine exclusively through
// the four C entry points in SaverGlue.swift (declared in saver_api.h,
// this module's bridging header).
//
// GL-in-a-screen-saver, macOS 10.15+: legacyScreenSaver hosts saver views
// in LAYER-BACKED windows, where attaching a plain NSOpenGLContext to the
// view (NSOpenGLContext.view / NSOpenGLView) composites NOTHING - no
// error, no crash, just black (observed 2026-07-10; the same engine build
// renders fine to an offscreen CGL context, see test/SmokeTest.swift).
// The supported way to put legacy GL content into a layer tree is an
// NSOpenGLLayer backing layer, so that's what this does: the view's
// backing layer is a SaverGLLayer, ScreenSaverView's animation timer
// marks it dirty each tick (animateOneFrame -> setNeedsDisplay), and the
// layer's draw callback - where AppKit hands us a current-able GL context
// sized to the layer - boots the engine and advances one frame.
//
// Engine-global caveat: the engine is one global instance (gEngine), but
// the system can create several saver views in one process (one per
// display, plus the System Settings preview). Only the first view to draw
// owns the engine; any other view just clears to black. (Textures live in
// the owning layer's GL context, so a second context couldn't show the
// scene anyway without context sharing.)

import ScreenSaver
import OpenGL.GL

@objc(Nanosaur2SaverView)
public final class Nanosaur2SaverView: ScreenSaverView {
    fileprivate static var engineBooted = false
    fileprivate static weak var engineOwner: Nanosaur2SaverView?

    fileprivate var sceneUp = false

    public override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0 / 60.0
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    public override func makeBackingLayer() -> CALayer {
        let layer = SaverGLLayer()
        layer.host = self
        // We drive redraws explicitly from animateOneFrame; asynchronous
        // mode would let the layer free-run against the display refresh.
        layer.isAsynchronous = false
        return layer
    }

    // MARK: - Animation

    public override func startAnimation() {
        super.startAnimation()
        layer?.setNeedsDisplay()
    }

    public override func stopAnimation() {
        // Tear the scene down NOW if our layer's GL context is available -
        // the system may not schedule another draw after this point, and
        // FreeLevelIntroScene must run with the owning context current.
        if sceneUp, let glLayer = layer as? SaverGLLayer, let ctx = glLayer.openGLContext {
            ctx.makeCurrentContext()
            Nanosaur2Saver_StopScene()
            sceneUp = false
        }

        super.stopAnimation()
    }

    public override func animateOneFrame() {
        // The actual work happens in SaverGLLayer.draw (AppKit provides
        // the GL context there); this just schedules it.
        layer?.setNeedsDisplay()
    }

    // MARK: - Engine frame (called by the layer with its GL context current)

    fileprivate func drawEngineFrame(pixelWidth: Int32, pixelHeight: Int32) {
        // First view to draw owns the process-global engine.
        if Self.engineOwner == nil {
            Self.engineOwner = self
        }
        guard Self.engineOwner === self else {
            glClearColor(0, 0, 0, 1)
            glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
            return
        }

        if !Self.engineBooted {
            let dataPath = Bundle(for: Nanosaur2SaverView.self).resourcePath! + "/Data"
            dataPath.withCString { Nanosaur2Saver_Boot($0) }
            Self.engineBooted = true
        }

        if !sceneUp {
            Nanosaur2Saver_StartScene()
            sceneUp = true
        }

        Nanosaur2Saver_Frame(pixelWidth, pixelHeight)
    }

    // MARK: - ScreenSaverView boilerplate

    public override var hasConfigureSheet: Bool { false }
    public override var configureSheet: NSWindow? { nil }
}

// MARK: - The GL backing layer

private final class SaverGLLayer: NSOpenGLLayer {
    weak var host: Nanosaur2SaverView?

    override init() {
        super.init()
    }

    // CALayer requires this for presentation-tree copies.
    override init(layer: Any) {
        super.init(layer: layer)
        if let other = layer as? SaverGLLayer {
            host = other.host
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    override func openGLPixelFormat(forDisplayMask mask: UInt32) -> NSOpenGLPixelFormat {
        let attrs: [NSOpenGLPixelFormatAttribute] = [
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAScreenMask), NSOpenGLPixelFormatAttribute(mask),
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAAccelerated),
            NSOpenGLPixelFormatAttribute(NSOpenGLPFADoubleBuffer),
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAColorSize), 24,
            NSOpenGLPixelFormatAttribute(NSOpenGLPFADepthSize), 24,
            0,
        ]
        if let pf = NSOpenGLPixelFormat(attributes: attrs) {
            return pf
        }
        return super.openGLPixelFormat(forDisplayMask: mask)
    }

    override func canDraw(
        in context: NSOpenGLContext,
        pixelFormat: NSOpenGLPixelFormat,
        forLayerTime t: CFTimeInterval,
        displayTime ts: UnsafePointer<CVTimeStamp>?) -> Bool
    {
        return host != nil
    }

    override func draw(
        in context: NSOpenGLContext,
        pixelFormat: NSOpenGLPixelFormat,
        forLayerTime t: CFTimeInterval,
        displayTime ts: UnsafePointer<CVTimeStamp>?)
    {
        context.makeCurrentContext()

        guard let host else {
            glClearColor(0, 0, 0, 1)
            glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
            return
        }

        let scale = contentsScale
        let pixelWidth = Int32((bounds.width * scale).rounded())
        let pixelHeight = Int32((bounds.height * scale).rounded())
        host.drawEngineFrame(pixelWidth: max(pixelWidth, 1), pixelHeight: max(pixelHeight, 1))

        // NSOpenGLLayer flushes the context after this returns.
    }
}
