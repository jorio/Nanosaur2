// PlatformBackend.swift - platform abstraction seams for the 3DS port.
//
// See docs/3DS_PORT_PLAN.md for why only Graphics/Input get protocols here.
// File/Sound/Memory are deliberately NOT protocols: they're already
// "one Swift file per subsystem, swappable wholesale per build target"
// (File.swift, Sound.swift, Misc.swift's AllocPtr/SafeDisposePtr), which is
// the right shape for a compile-time platform choice - a 3DS build never
// picks SDL vs. libctru at runtime within the same binary, so a runtime
// polymorphism mechanism (a protocol) would add indirection for no benefit
// there. Graphics/Input get real protocols because:
//   - Input.swift already has a thin, genuinely swappable raw-polling seam
//     (updateRawKeyboardStates) underneath a state machine that's pure
//     Swift logic and identical on every backend.
//   - Graphics's context lifecycle (create/make-current/swap/destroy)
//     translates onto citro3d's context-free-but-still-has-a-presentable-
//     surface model, as long as the protocol stays narrow: it does NOT
//     cover OGL_CreateDrawContext's desktop-GL-specific capability queries
//     (SDL_GL_GetProcAddress for extension functions, GL_MAX_TEXTURE_SIZE),
//     which have no citro3d equivalent and stay in SDLGraphicsBackend's own
//     createContext(), not in shared call sites.

// MARK: - Graphics: GL/GPU context lifecycle and presentation only

protocol GraphicsBackend {
    associatedtype ContextHandle

    /// Called once at boot (OGL_CreateDrawContext's job today). Fatal-alerts
    /// on failure, matching the existing SDL_GL_CreateContext call site.
    mutating func createContext(window: OpaquePointer) -> ContextHandle

    /// Bottom-window/dual-screen support: a second, independent presentable
    /// surface sharing the first's texture/resource namespace. Callers must
    /// make `sharedWith` current before calling this (SDL's sharing model
    /// is "whatever's current when the new context is created", not an
    /// explicit handle reference). Returns nil (ContextHandle is expected to
    /// be an optional-pointer-shaped type on every conformance) on backends
    /// with only one screen/context, e.g. a single-context 3DS conformance.
    mutating func createSecondaryContext(window: OpaquePointer, sharedWith: ContextHandle) -> ContextHandle

    func makeCurrent(_ context: ContextHandle, window: OpaquePointer)

    /// Present this frame (SDL_GL_SwapWindow today; "submit this frame's
    /// command list and present" on a citro3d backend).
    func swap(_ context: ContextHandle, window: OpaquePointer)

    mutating func destroyContext(_ context: ContextHandle, window: OpaquePointer)
}

// Gated out entirely (not just unselected via the typealias below) on 3DS:
// the struct bodies below reference real SDL_* symbols, which the 3DS
// build's bridging header (ports/3DS/common/game_3ds.h) deliberately never
// declares (only opaque SDL_Window/SDL_GLContext/SDL_Gamepad stand-ins) -
// Swift type-checks every declaration in a file regardless of which
// typealias ends up selected, so these would fail to compile on 3DS even
// though nothing calls them there.
#if !NANOSAUR_3DS
struct SDLGraphicsBackend: GraphicsBackend {
    typealias ContextHandle = OpaquePointer?

    mutating func createContext(window: OpaquePointer) -> ContextHandle {
        let context = SDL_GL_CreateContext(window)
        if context == nil {
            SwFatalAlert(String(cString: SDL_GetError()))
        }
        return context
    }

    mutating func createSecondaryContext(window: OpaquePointer, sharedWith: ContextHandle) -> ContextHandle {
        SDL_GL_SetAttribute(SDL_GL_SHARE_WITH_CURRENT_CONTEXT, 1)
        let context = SDL_GL_CreateContext(window)
        if context == nil {
            SwFatalAlert(String(cString: SDL_GetError()))
        }
        return context
    }

    func makeCurrent(_ context: ContextHandle, window: OpaquePointer) {
        let ok = SDL_GL_MakeCurrent(window, context)
        SwGameAssertMessage(ok, String(cString: SDL_GetError()))
    }

    func swap(_ context: ContextHandle, window: OpaquePointer) {
        SDL_GL_SwapWindow(window)
    }

    mutating func destroyContext(_ context: ContextHandle, window: OpaquePointer) {
        _ = SDL_GL_MakeCurrent(window, nil)
        SDL_GL_DestroyContext(context)
    }
}
#endif // !NANOSAUR_3DS

// MARK: - Input: raw digital-input polling only
//
// Wraps exactly the one raw call updateRawKeyboardStates already isolates
// (SDL_GetKeyboardState). The KEYSTATE_*/Need state machine built on top in
// Input.swift is NOT part of this protocol - it's pure Swift logic over
// whatever raw state comes back, and stays identical on every backend. A
// 3DS conformance maps hidKeysHeld()'s KEY_* bitmask into the same
// "is digital input N held" shape (there's no literal keyboard, but
// D-pad/buttons/circle-pad map to a fixed set of indices the same way the
// SDL backend maps physical scancodes).
//
// Mouse/gamepad polling (updateMouseButtonStates,
// updateControllerSpecificInputNeeds) aren't covered here yet: the former
// is a genuinely desktop-shaped multi-button-plus-wheel API that doesn't
// map onto a touchscreen, and gamepad polling needs its own design pass once
// the 3DS's actual D-pad/circle-pad/button semantics are being implemented
// (Phase 2) rather than guessed at now.
protocol InputBackend {
    /// Fills `states[0..<count]` with true/false "is this input index
    /// currently held" - mirrors SDL_GetKeyboardState's `bool*` output
    /// shape so updateRawKeyboardStates' loop is otherwise unchanged.
    func pollDigitalInputs(into states: inout [Bool])

    var digitalInputCount: Int { get }
}

#if !NANOSAUR_3DS
struct SDLInputBackend: InputBackend {
    var digitalInputCount: Int { Int(SDL_SCANCODE_COUNT.rawValue) }

    func pollDigitalInputs(into states: inout [Bool]) {
        var numkeys: Int32 = 0
        guard let keystate = SDL_GetKeyboardState(&numkeys) else {
            for i in states.indices { states[i] = false }
            return
        }

        let minNumKeys = min(Int(numkeys), states.count)
        for i in 0..<minNumKeys {
            states[i] = keystate[i]
        }
        for i in minNumKeys..<states.count {
            states[i] = false
        }
    }
}
#endif // !NANOSAUR_3DS

// MARK: - Platform selection
//
// A 3DS build is a compile-time target choice, never a runtime one, so this
// resolves statically - no existential boxing, no witness-table dispatch.
// NANOSAUR_3DS is a custom compilation condition (-DNANOSAUR_3DS via
// -Xswiftc, or equivalent Makefile flag) rather than a Swift `os()` check:
// Embedded Swift/3DS targets don't get their own recognized `os()` platform
// identifier, and "3DS" isn't a valid Swift identifier token to begin with
// (it starts with a digit).
#if NANOSAUR_3DS

// MARK: - 3DS conformances
//
// citro3d has no per-window GL-style context object: C3D_Init/C2D_Init set
// up one global render pipeline for the whole app, and screens are
// identified by C3D_RenderTarget, not a context handle you make current.
// ContextHandle is a nominal placeholder rather than a real handle -
// createContext/createSecondaryContext just record which screen a caller
// means; the actual C3D_RenderTarget setup and glVertex-equivalent
// citro2d/citro3d draw calls happen in Phase 3's renderer rewrite, not
// here. This conformance exists now only to satisfy the protocol boundary
// so OGL_Support.swift's call sites can be routed through
// `gGraphicsBackend` unconditionally on every platform.
//
// ContextHandle MUST be `SDL_GLContext` (an `UnsafeMutableRawPointer?`),
// matching `SDLGraphicsBackend`'s - NOT a 3DS-only type like `Bool`. The
// real `game.h` (shared by both platforms) declares the global
// `gAGLContext`/`gAGLContext2` storage that callers pass into these
// methods as `SDL_GLContext`, so both conformances' `ContextHandle` need
// to be assignable to/from that same global storage. `Bool` compiled fine
// in isolation (see the earlier `PlatformBackend.swift` update) but broke
// the moment `OGL_Support.swift` - which only knows about `SDL_GLContext`,
// not either backend's ContextHandle - tried to pass `gAGLContext` into
// `makeCurrent`/`swap`/etc. The pointer values themselves are meaningless
// on 3DS (never dereferenced), just distinct sentinels.
struct CTRUGraphicsBackend: GraphicsBackend {
    typealias ContextHandle = SDL_GLContext

    mutating func createContext(window: OpaquePointer) -> ContextHandle {
        UnsafeMutableRawPointer(bitPattern: 1)!
    }

    mutating func createSecondaryContext(window: OpaquePointer, sharedWith: ContextHandle) -> ContextHandle {
        UnsafeMutableRawPointer(bitPattern: 2)!
    }

    func makeCurrent(_ context: ContextHandle, window: OpaquePointer) {
        // No-op: citro3d has no current-context concept to switch.
    }

    func swap(_ context: ContextHandle, window: OpaquePointer) {
        // Phase 3: C3D_FrameEnd(0) belongs here once frame begin/end is
        // wired up to this call site instead of being main-loop-only.
    }

    mutating func destroyContext(_ context: ContextHandle, window: OpaquePointer) {
        // No-op: nothing owned per-context to tear down.
    }
}

// Maps the fixed SDL_SCANCODE_* indices Input.swift's KEYSTATE machine
// already polls by index into libctru's KEY_* bitmask via hidKeysHeld().
// Only the subset of scancodes InputBindings.swift's default bindings
// actually reference need real mappings; everything else reports "never
// held" (index out of libctru's range, e.g. keyboard letter keys with no
// physical 3DS equivalent).
struct CTRUInputBackend: InputBackend {
    // Matches SDL_SCANCODE_COUNT (512) rather than importing the SDL enum,
    // which isn't declared at all in the 3DS build's stub SDL3 headers -
    // updateRawKeyboardStates sizes gRawDigitalInputStates off this value on
    // every platform, so it needs to stay in lockstep with SDLInputBackend's.
    var digitalInputCount: Int { 512 }

    func pollDigitalInputs(into states: inout [Bool]) {
        hidScanInput()
        let held = hidKeysHeld()
        for i in states.indices {
            states[i] = false
        }
        _ = held // Phase 2: map KEY_* bits onto the scancode indices used
                 // by kDefaultInputBindings once 3DS-specific bindings
                 // replace the desktop keyboard/gamepad defaults.
    }
}

typealias PlatformGraphics = CTRUGraphicsBackend
typealias PlatformInput = CTRUInputBackend
#else
typealias PlatformGraphics = SDLGraphicsBackend
typealias PlatformInput = SDLInputBackend
#endif
