// MetalSpike.swift
//
// Phase 0 glue between the game (this main module, which has SDL via the
// bridging header) and the isolated MetalRenderer module (which has Metal).
// The game side creates the CAMetalLayer through SDL and hands its raw
// pointer to MetalRenderer - see docs/metal-renderer-plan.md for why the two
// live in separate modules.
//
// This is scaffolding to prove the SDL-layer -> Metal path works end to end.
// It is NOT wired into the real frame loop yet; call SwMetalSpike_Run() from a
// debug entry point (or temporarily from GameMain) to exercise it.

import MetalRenderer

private var gMetalView: SDL_MetalView?
private var gMetalRenderer: MetalRenderer?

// Creates the SDL Metal view on the main game window, hands its CAMetalLayer
// to the MetalRenderer module, and returns whether setup succeeded.
@c @implementation
public func SwMetalSpike_Init() -> Bool {
    guard let window = gSDLWindow else { return false }

    let view = SDL_Metal_CreateView(window)
    guard let view else {
        SwLog("MetalSpike: SDL_Metal_CreateView failed: \(String(cString: SDL_GetError()))")
        return false
    }
    gMetalView = view

    guard let layer = SDL_Metal_GetLayer(view) else {
        SwLog("MetalSpike: SDL_Metal_GetLayer returned nil")
        return false
    }

    guard let renderer = MetalRenderer(layerPointer: layer) else {
        SwLog("MetalSpike: MetalRenderer init failed (no Metal device?)")
        return false
    }
    gMetalRenderer = renderer

    var w: Int32 = 0
    var h: Int32 = 0
    SDL_GetWindowSizeInPixels(window, &w, &h)
    renderer.setDrawableSize(width: Int(w), height: Int(h))

    SwLog("MetalSpike: renderer live on device '\(renderer.deviceName)' (\(w)x\(h))")
    return true
}

// Clears the drawable to a colour and presents it. Call each frame during the
// spike.
@c @implementation
public func SwMetalSpike_ClearFrame(_ red: Float, _ green: Float, _ blue: Float) {
    gMetalRenderer?.clearFrame(red: red, green: green, blue: blue)
}

// Tears down the spike renderer/view.
@c @implementation
public func SwMetalSpike_Shutdown() {
    gMetalRenderer = nil
    if let view = gMetalView {
        SDL_Metal_DestroyView(view)
        gMetalView = nil
    }
}
