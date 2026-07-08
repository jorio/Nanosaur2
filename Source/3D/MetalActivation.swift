// MetalActivation.swift
//
// Phase 2 "real" Metal activation (docs/metal-renderer-plan.md), as opposed
// to MetalSpike.swift's Phase 0 throwaway clear-loop. Called once from
// OGL_CreateDrawContext() (OGL_Support.swift) when gMetalMode is set - NOT
// from Boot.cpp, and specifically AFTER SDL_GL_CreateContext/MakeCurrent
// have already run there. Order matters: adding a Metal-backed view to
// gSDLWindow before the GL context exists corrupts the window's surface for
// SDL_GL_CreateContext, which then fails ("The specified window isn't an
// OpenGL window" - hit this empirically). The GL context itself is
// deliberately left alive once Metal is active (see
// MetalRenderBackend.swift's header comment for why: any not-yet-migrated
// raw gl* call elsewhere in the codebase needs a valid context to execute
// against, even though nothing ever presents it once a Metal backend is
// active).
//
// Creates a second CAMetalLayer-backed SDL Metal view on the SAME window
// (alongside the existing GL-backed view), and switches gRenderBackend over
// to a MetalRenderBackend driving it. From this point on, GameMain()'s
// normal frame loop runs exactly as it always has - only gRenderBackend's
// concrete type changed, which is what makes every already-migrated
// RenderBackend call site (see RenderBackend.swift) draw via Metal instead
// of GL, with zero changes needed to the frame loop itself.

import MetalRenderer

private var gMetalBackendView: SDL_MetalView?
private var gMetalBackendRenderer: MetalRenderer?

// Activates the real Metal render backend. Returns false (leaving
// gRenderBackend on GLRenderBackend, i.e. falls back to normal GL rendering)
// if Metal setup fails for any reason.
@c @implementation
public func SwMetalBackend_Activate() -> Bool {
    guard let window = gSDLWindow else { return false }

    guard let view = SDL_Metal_CreateView(window) else {
        SwLog("MetalBackend: SDL_Metal_CreateView failed: \(String(cString: SDL_GetError()))")
        return false
    }
    gMetalBackendView = view

    guard let layer = SDL_Metal_GetLayer(view) else {
        SwLog("MetalBackend: SDL_Metal_GetLayer returned nil")
        return false
    }

    guard let renderer = MetalRenderer(layerPointer: layer) else {
        SwLog("MetalBackend: MetalRenderer init failed (no Metal device?)")
        return false
    }
    gMetalBackendRenderer = renderer

    var w: Int32 = 0
    var h: Int32 = 0
    SDL_GetWindowSizeInPixels(window, &w, &h)
    renderer.setDrawableSize(width: Int(w), height: Int(h))

    gRenderBackend = MetalRenderBackend(renderer: renderer)

    SwLog("MetalBackend: active on device '\(renderer.deviceName)' (\(w)x\(h))")
    return true
}
