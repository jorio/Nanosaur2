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
// typealias PlatformGraphics = CTRUGraphicsBackend // Phase 2
// typealias PlatformInput = CTRUInputBackend // Phase 2
#else
typealias PlatformGraphics = SDLGraphicsBackend
typealias PlatformInput = SDLInputBackend
#endif
