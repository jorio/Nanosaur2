// GameEngine.swift - central owner of the game's Swift-side mutable state.
//
// The C port left ~400 file-scope globals behind; they are migrating into
// this class one subsystem per commit, following the same incremental
// discipline as the original port. Globals still defined in C stubs for
// C-ABI reasons (gGamePrefs in Main.c, gMetalMode in BootGlobals.c, ...)
// cannot move and stay where they are.

final class GameEngine {
    /// Active rendering backend. GL by default; SwMetalBackend_Activate
    /// swaps in the Metal backend under --metal during draw-context
    /// creation, before any drawing happens.
    var renderer: RenderBackend = GLRenderBackend()

    /// Object system: master ObjNode list, per-move coord/delta scratch,
    /// autofade settings, slot storage (see Objects.swift).
    let objects = ObjectSystem()

    /// Player state for both players (see Player.swift).
    let player = PlayerSystem()
}

/// The single engine instance. A plain global (not dependency injection)
/// because hundreds of C-shaped call sites and @convention(c) move/draw
/// callbacks have no way to carry a context parameter.
let gEngine = GameEngine()
