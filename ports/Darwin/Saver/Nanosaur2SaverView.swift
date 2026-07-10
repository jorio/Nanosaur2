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
// Contract (see SaverGlue.swift): this view owns the NSOpenGLContext,
// makes it current before every engine call, and flushes after the frame.

import ScreenSaver

@objc(Nanosaur2SaverView)
public final class Nanosaur2SaverView: ScreenSaverView {
    private var glContext: NSOpenGLContext?
    private static var booted = false // engine boots once per process; the system can create several views (one per display + previews)
    private var sceneUp = false

    public override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0 / 60.0
        wantsBestResolutionOpenGLSurface = true
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    // MARK: - GL context

    private func makeGLContext() -> NSOpenGLContext? {
        let attrs: [NSOpenGLPixelFormatAttribute] = [
            NSOpenGLPixelFormatAttribute(NSOpenGLPFADoubleBuffer),
            NSOpenGLPixelFormatAttribute(NSOpenGLPFADepthSize), 24,
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAColorSize), 24,
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAAccelerated),
            0,
        ]
        guard let pixelFormat = NSOpenGLPixelFormat(attributes: attrs) else {
            return nil
        }
        return NSOpenGLContext(format: pixelFormat, share: nil)
    }

    // MARK: - Animation

    public override func startAnimation() {
        super.startAnimation()

        if glContext == nil {
            glContext = makeGLContext()
            glContext?.view = self
        }

        guard let ctx = glContext else { return }
        ctx.makeCurrentContext()

        if !Self.booted {
            let dataPath = Bundle(for: Nanosaur2SaverView.self).resourcePath! + "/Data"
            dataPath.withCString { Nanosaur2Saver_Boot($0) }
            Self.booted = true
        }

        if !sceneUp {
            Nanosaur2Saver_StartScene()
            sceneUp = true
        }
    }

    public override func stopAnimation() {
        if sceneUp, let ctx = glContext {
            ctx.makeCurrentContext()
            Nanosaur2Saver_StopScene()
            sceneUp = false
        }
        super.stopAnimation()
    }

    public override func animateOneFrame() {
        guard sceneUp, let ctx = glContext else { return }

        ctx.makeCurrentContext()
        ctx.update() // track view size/position changes

        let backing = convertToBacking(bounds).size
        Nanosaur2Saver_Frame(Int32(backing.width), Int32(backing.height))

        ctx.flushBuffer()
    }

    // MARK: - ScreenSaverView boilerplate

    public override var hasConfigureSheet: Bool { false }
    public override var configureSheet: NSWindow? { nil }

    public override func draw(_ rect: NSRect) {
        // GL renders in animateOneFrame; nothing to draw with AppKit.
        // Fill black so the first moment before the first frame isn't white.
        NSColor.black.setFill()
        rect.fill()
    }
}
