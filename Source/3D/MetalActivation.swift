// MetalActivation.swift
//
// Phase 2 "real" Metal activation (docs/metal-renderer-plan.md), as opposed
// to MetalSpike.swift's Phase 0 throwaway clear-loop. Called once from
// OGL_CreateDrawContext() (OGL_Support.swift) when gMetalMode is set - NOT
// from Boot.cpp - as a full REPLACEMENT for GL context creation, not an
// addition to it: gSDLWindow was created SDL_WINDOW_METAL-only (Boot.cpp),
// with no GL context ever created (see OGL_CreateDrawContext's comment for
// why - a GL context and a Metal view on the same window don't coexist,
// tried it, broke). Switches gEngine.renderer over to a MetalRenderBackend.
// From this point on, GameMain()'s normal frame loop runs exactly as it
// always has - only gEngine.renderer's concrete type changed, which is what
// makes every already-migrated RenderBackend call site (see
// RenderBackend.swift) draw via Metal instead of GL, with zero changes
// needed to the frame loop itself. Anything NOT migrated must not be
// reachable under --metal (see MetalRenderBackend.swift's header comment).

import MetalRenderer

/// Retains the Metal layer view + renderer for the lifetime of the
/// backend. Owned by GameEngine as `gEngine.metalBackend`.
final class MetalBackendHolder {
    var view: SDL_MetalView?
    var metalRenderer: MetalRenderer?
}

// Activates the real Metal render backend. Returns false (leaving
// gEngine.renderer on GLRenderBackend, i.e. falls back to normal GL rendering)
// if Metal setup fails for any reason.
@c @implementation
public func SwMetalBackend_Activate() -> Bool {
    guard let window = gSDLWindow else { return false }

    guard let view = SDL_Metal_CreateView(window) else {
        SwLog("MetalBackend: SDL_Metal_CreateView failed: \(String(cString: SDL_GetError()))")
        return false
    }
    gEngine.metalBackend.view = view

    guard let layer = SDL_Metal_GetLayer(view) else {
        SwLog("MetalBackend: SDL_Metal_GetLayer returned nil")
        return false
    }

    guard let renderer = MetalRenderer(layerPointer: layer) else {
        SwLog("MetalBackend: MetalRenderer init failed (no Metal device?)")
        return false
    }
    gEngine.metalBackend.metalRenderer = renderer

    var w: Int32 = 0
    var h: Int32 = 0
    SDL_GetWindowSizeInPixels(window, &w, &h)
    renderer.setDrawableSize(width: Int(w), height: Int(h))

    gEngine.renderer = MetalRenderBackend(renderer: renderer)

    SwLog("MetalBackend: active on device '\(renderer.deviceName)' (\(w)x\(h))")
    return true
}
