// PlatformBackend.swift - platform abstraction seams for the 3DS port.
//
// See docs/3DS_PORT_PLAN.md for why Input gets a protocol here. File/Sound/
// Memory are deliberately NOT protocols: they're already "one Swift file
// per subsystem, swappable wholesale per build target" (File.swift,
// Sound.swift, Misc.swift's AllocPtr/SafeDisposePtr), which is the right
// shape for a compile-time platform choice - a 3DS build never picks SDL
// vs. libctru at runtime within the same binary, so a runtime polymorphism
// mechanism (a protocol) would add indirection for no benefit there.
// Input.swift gets a real protocol because it already has a thin,
// genuinely swappable raw-polling seam (updateRawKeyboardStates)
// underneath a state machine that's pure Swift logic and identical on
// every backend.
//
// Graphics used to have a matching GraphicsBackend protocol/
// SDLGraphicsBackend/CTRUGraphicsBackend trio here, but the RenderBackend
// facade (Source/3D/RenderBackend.swift, see docs/metal-renderer-plan.md)
// now owns context create/make-current/swap/destroy for every backend
// (GL, Metal, and 3DS via #if NANOSAUR_3DS branches inside
// GLRenderBackend) - this file's Graphics half was fully superseded and
// removed rather than kept as a second, unused abstraction.

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

typealias PlatformInput = CTRUInputBackend
#else
typealias PlatformInput = SDLInputBackend
#endif
