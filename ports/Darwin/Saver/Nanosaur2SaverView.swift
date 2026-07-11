// Nanosaur2SaverView.swift - the ScreenSaverView host for the Nanosaur 2
// wormhole screen saver (ports/Darwin).
//
// Its OWN Swift module, separate from the engine: it imports ScreenSaver/
// AppKit, which cannot coexist with the engine's bridging header
// (SwMacTypes.h vs Darwin.MacTypes - same split as MetalRenderer, see
// docs/metal-renderer-plan.md). It talks to the engine exclusively through
// the C entry points in SaverGlue.swift (declared in saver_api.h, this
// module's bridging header).
//
// Rendering is METAL: the view is backed by a plain CAMetalLayer and the
// engine's MetalRenderBackend draws/presents into it - the same path as
// the desktop game's --metal mode. (A GL host was tried first, both as
// NSOpenGLContext-attached-to-view and as an NSOpenGLLayer: the former
// composites nothing in legacyScreenSaver's layer-backed windows, the
// latter left System Settings' full-screen preview black. CAMetalLayer
// needs none of those workarounds.)
//
// Engine ownership: the engine is one global instance, but the system can
// create several saver views in one process (System Settings' inline
// thumbnail vs. its full-screen preview, one per display). Exactly one
// view "owns" the engine: the most recent one to start animating. Claiming
// ownership rebinds the renderer to the claimant's layer (a full texture
// reload - see SaverGlue's AttachLayer), so it happens on lifecycle
// events, never per-frame. A stopped owner releases ownership; a running
// non-owner reclaims a released engine on its next animation tick (that's
// how the thumbnail resumes after the full-screen preview closes).

import ScreenSaver
import QuartzCore

@objc(Nanosaur2SaverView)
public final class Nanosaur2SaverView: ScreenSaverView {
    private static var engineBooted = false
    private static var engineBootFailed = false
    private static weak var engineOwner: Nanosaur2SaverView?

    public override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0 / 60.0
        wantsLayer = true
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    public override func makeBackingLayer() -> CALayer {
        let layer = CAMetalLayer()
        layer.backgroundColor = CGColor(gray: 0, alpha: 1)
        return layer
    }

    // The layer's backing size in pixels (CAMetalLayer's drawableSize
    // doesn't track the view on its own; the engine sets it from what we
    // pass into Frame/Boot/AttachLayer).
    private var backingPixelSize: (width: Int32, height: Int32) {
        let scale = window?.backingScaleFactor ?? 2.0
        let size = bounds.size
        return (
            max(Int32((size.width * scale).rounded()), 1),
            max(Int32((size.height * scale).rounded()), 1)
        )
    }

    // MARK: - Engine ownership

    /// Boot the engine on our layer, or steal it from whichever view held
    /// it (full texture reload), then bring the scene up.
    private func claimEngine() {
        guard !Self.engineBootFailed, let metalLayer = layer as? CAMetalLayer else { return }
        let layerPtr = Unmanaged.passUnretained(metalLayer).toOpaque()
        let (w, h) = backingPixelSize

        if !Self.engineBooted {
            let dataPath = Bundle(for: Nanosaur2SaverView.self).resourcePath! + "/Data"
            let ok = dataPath.withCString { Nanosaur2Saver_Boot($0, layerPtr, w, h) }
            guard ok else {
                Self.engineBootFailed = true // don't retry every frame
                NSLog("Nanosaur2Saver: engine boot failed (no Metal device?)")
                return
            }
            Self.engineBooted = true
        } else {
            guard Nanosaur2Saver_AttachLayer(layerPtr, w, h) else { return }
        }

        Self.engineOwner = self
        Nanosaur2Saver_StartScene()
    }

    // MARK: - Animation

    public override func startAnimation() {
        super.startAnimation()
        claimEngine()
    }

    public override func stopAnimation() {
        if Self.engineOwner === self {
            Nanosaur2Saver_StopScene()
            Self.engineOwner = nil
        }
        super.stopAnimation()
    }

    public override func animateOneFrame() {
        // Reclaim a released engine (e.g. the thumbnail resuming after the
        // full-screen preview stopped) - but never steal from a live owner.
        if Self.engineOwner == nil {
            claimEngine()
        }
        guard Self.engineOwner === self else { return }

        let (w, h) = backingPixelSize
        Nanosaur2Saver_Frame(w, h)
    }

    // MARK: - ScreenSaverView boilerplate

    public override var hasConfigureSheet: Bool { false }
    public override var configureSheet: NSWindow? { nil }
}
