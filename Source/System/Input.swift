// Input.swift - Port of Input.c to Swift
//
// gEngine.input.userPrefersGamepad/gEngine.input.cursorCoord are native Swift storage now (converted
// 2026-07-07): nothing in any .c file touches them anymore. Every other
// global in the original file (gEngine.input.gamepads, gEngine.input.keyboardStates,
// gEngine.input.mouseButtonStates, gEngine.input.needStates, gEngine.input.lastGamepadForNeedAnyP,
// gEngine.input.gamepadPlayerMappingLocked, gEngine.input.mouseMotionNow, gEngine.input.textInput) has no
// `extern` declaration anywhere and is only ever touched from this file,
// so they all stay private Swift storage. The `Gamepad` struct
// itself was only ever defined in Input.c, so it becomes a plain Swift
// struct here rather than a C type.

/// Input state. Owned by GameEngine as `gEngine.input`.
final class InputSystem {
    var userPrefersGamepad: UInt8 = 0
    var cursorCoord = OGLPoint2D()

    fileprivate var gamepadPlayerMappingLocked = false
    fileprivate var gamepads = [Gamepad](repeating: Gamepad(), count: maxLocalPlayers)

    fileprivate var keyboardStates = [UInt8](repeating: 0, count: Int(SDL_SCANCODE_COUNT.rawValue))
    fileprivate var mouseButtonStates = [UInt8](repeating: 0, count: Int(NUM_SUPPORTED_MOUSE_BUTTONS))
    fileprivate var needStates = [UInt8](repeating: 0, count: Int(NUM_CONTROL_NEEDS))
    fileprivate var lastGamepadForNeedAnyP = [Int32](repeating: -1, count: Int(NUM_CONTROL_NEEDS))

    fileprivate var mouseMotionNow = false
    fileprivate var textInput = ""

    fileprivate var mouseDeltaTimeSinceLastCall: Float = 0
    fileprivate var mouseDeltaLast = OGLVector2D()
    fileprivate var cursorCoordBackup = OGLPoint2D(x: -1, y: -1)
}
//
// MOUSE_SMOOTHING and REQUIRE_LOCK_MAPPING are both hardcoded off in the
// original file, so their guarded code (MouseSmoothing_*,
// LockPlayerGamepadMapping/UnlockPlayerGamepadMapping) is dead and
// dropped. GetPlayerName/GetPlayerNameWithInputDeviceHint were already
// #if 0'd out in the original. GetAnalogSteering/LockPlayerControllerMapping/
// UnlockPlayerControllerMapping are declared in input.h but were never
// implemented anywhere (dead declarations - nothing calls or defines
// them), so they're skipped too.

private let maxLocalPlayers = Int(MAX_PLAYERS)
private let kJoystickDeadZone: Int16 = Int16(33 * 32767 / 100)
private let kJoystickDeadZoneUI: Int16 = Int16(66 * 32767 / 100)
private let kJoystickDeadZoneFrac: Float = Float(33 * 32767 / 100) / 32767.0

private struct Gamepad {
    var open = false
    var fallbackToKeyboard = false
    var hasRumble = false
    var sdlGamepad: OpaquePointer?
    var needStates = [UInt8](repeating: 0, count: Int(NUM_CONTROL_NEEDS))
    var needAnalog = [Float](repeating: 0, count: Int(NUM_CONTROL_NEEDS))
    var analogSteering = OGLVector2D()
}




// MARK: - Init input

func InitInput() {
    for i in 0..<Int(NUM_CONTROL_NEEDS) {
        gEngine.input.lastGamepadForNeedAnyP[i] = -1
    }

    tryFillUpVacantGamepadSlots()
}

private func updateKeyState(_ state: inout UInt8, _ downNow: Bool) {
    switch state { // look at prev state
    case UInt8(KEYSTATE_HELD), UInt8(KEYSTATE_DOWN):
        state = downNow ? UInt8(KEYSTATE_HELD) : UInt8(KEYSTATE_UP)

    case UInt8(KEYSTATE_IGNOREHELD):
        state = downNow ? UInt8(KEYSTATE_IGNOREHELD) : UInt8(KEYSTATE_OFF)

    default: // KEYSTATE_OFF, KEYSTATE_UP
        state = downNow ? UInt8(KEYSTATE_DOWN) : UInt8(KEYSTATE_OFF)
    }
}

func InvalidateNeedState(_ need: Int32) {
    gEngine.input.needStates[Int(need)] = UInt8(KEYSTATE_IGNOREHELD)
}

func InvalidateAllInputs() {
    for i in 0..<gEngine.input.needStates.count { gEngine.input.needStates[i] = UInt8(KEYSTATE_IGNOREHELD) }
    for i in 0..<gEngine.input.keyboardStates.count { gEngine.input.keyboardStates[i] = UInt8(KEYSTATE_IGNOREHELD) }
    for i in 0..<gEngine.input.mouseButtonStates.count { gEngine.input.mouseButtonStates[i] = UInt8(KEYSTATE_IGNOREHELD) }

    for i in 0..<maxLocalPlayers {
        for j in 0..<gEngine.input.gamepads[i].needStates.count {
            gEngine.input.gamepads[i].needStates[j] = UInt8(KEYSTATE_IGNOREHELD)
        }
    }
}

private func updateRawKeyboardStates() {
    let keystate = SDL.keyboardState

    let minNumKeys = min(keystate.count, Int(SDL_SCANCODE_COUNT.rawValue))

    for i in 0..<minNumKeys {
        updateKeyState(&gEngine.input.keyboardStates[i], keystate[i])
    }

    // fill out the rest
    for i in minNumKeys..<Int(SDL_SCANCODE_COUNT.rawValue) {
        updateKeyState(&gEngine.input.keyboardStates[i], false)
    }
}

private func processSystemKeyChords() {
    if (gEngine.screens.gamePaused != 0 || gEngine.screens.playNow == 0) && IsCmdQDown() != 0 {
        CleanQuit()
    }

    if SwIsKeyDown(Int(SDL_SCANCODE_RETURN.rawValue))
        && (SwIsKeyHeld(Int(SDL_SCANCODE_LALT.rawValue)) || SwIsKeyHeld(Int(SDL_SCANCODE_RALT.rawValue))) {
        gGamePrefs.fullscreen = gGamePrefs.fullscreen == 0 ? 1 : 0
        SetFullscreenMode(false)

        InvalidateAllInputs()
    }
}

private func updateMouseButtonStates(_ mouseWheelDeltaX: Int32, _ mouseWheelDeltaY: Int32) {
    let mouseButtons = SDL.mouseState.buttons.rawValue

    for i in 1..<Int(NUM_SUPPORTED_MOUSE_BUTTONS_PURESDL) { // SDL buttons start at 1!
        let buttonBit = (mouseButtons & (UInt32(1) << (UInt32(i) - 1))) != 0 // SDL_BUTTON_MASK(i)
        updateKeyState(&gEngine.input.mouseButtonStates[i], buttonBit)
    }

    // Fake buttons for mouse wheel up/down
    updateKeyState(&gEngine.input.mouseButtonStates[Int(SDL_BUTTON_WHEELUP)], mouseWheelDeltaX > 0)
    updateKeyState(&gEngine.input.mouseButtonStates[Int(SDL_BUTTON_WHEELDOWN)], mouseWheelDeltaX < 0)
    updateKeyState(&gEngine.input.mouseButtonStates[Int(SDL_BUTTON_WHEELLEFT)], mouseWheelDeltaY < 0)
    updateKeyState(&gEngine.input.mouseButtonStates[Int(SDL_BUTTON_WHEELRIGHT)], mouseWheelDeltaY > 0)
}

private func updateInputNeeds() {
    for need in 0..<Int(NUM_CONTROL_NEEDS) {
        var pressed = false

        withUnsafePointer(to: &gGamePrefs.bindings) { bindingsPtr in
            let kb = UnsafeMutableRawPointer(mutating: bindingsPtr).assumingMemoryBound(to: InputBinding.self) + need

            for j in 0..<Int(MAX_BINDINGS_PER_NEED) {
                let scancode = InputBinding_GetKey(kb, Int32(j))
                if scancode != 0 && scancode < Int16(SDL_SCANCODE_COUNT.rawValue) {
                    pressed = pressed || (gEngine.input.keyboardStates[Int(scancode)] & UInt8(KEYSTATE_ACTIVE_BIT)) != 0
                }
            }

            pressed = pressed || (gEngine.input.mouseButtonStates[Int(kb.pointee.mouseButton)] & UInt8(KEYSTATE_ACTIVE_BIT)) != 0
        }

        updateKeyState(&gEngine.input.needStates[need], pressed)
    }
}

private func updateControllerSpecificInputNeeds(_ controllerNum: Int) {
    guard gEngine.input.gamepads[controllerNum].open else {
        return
    }

    let controllerInstance = gEngine.input.gamepads[controllerNum].sdlGamepad

    for needNum in 0..<Int(NUM_CONTROL_NEEDS) {
        let deadZone = needNum >= Int(NUM_REMAPPABLE_NEEDS) ? kJoystickDeadZoneUI : kJoystickDeadZone

        var pressed = false
        var analogPressed: Float = 0

        withUnsafePointer(to: &gGamePrefs.bindings) { bindingsPtr in
            let kb = UnsafeMutableRawPointer(mutating: bindingsPtr).assumingMemoryBound(to: InputBinding.self) + needNum

            for buttonNum in 0..<Int(MAX_BINDINGS_PER_NEED) {
                let type = InputBinding_GetPadType(kb, Int32(buttonNum))
                let id = InputBinding_GetPadID(kb, Int32(buttonNum))

                switch Int(type) {
                case Int(kInputTypeButton):
                    if SDL_GetGamepadButton(controllerInstance, SDL_GamepadButton(Int32(id))) {
                        pressed = true
                        analogPressed = 1
                    }

                case Int(kInputTypeAxisPlus):
                    let axis = SDL_GetGamepadAxis(controllerInstance, SDL_GamepadAxis(Int32(id)))
                    if axis > deadZone {
                        pressed = true
                        let absAxisFrac = Float(axis - deadZone) / (32767.0 - Float(deadZone))
                        analogPressed = max(analogPressed, absAxisFrac)
                    }

                case Int(kInputTypeAxisMinus):
                    let axis = SDL_GetGamepadAxis(controllerInstance, SDL_GamepadAxis(Int32(id)))
                    if axis < -deadZone {
                        pressed = true
                        let absAxisFrac = Float(-axis - deadZone) / (32767.0 - Float(deadZone))
                        analogPressed = max(analogPressed, absAxisFrac)
                    }

                default:
                    break
                }
            }
        }

        gEngine.input.gamepads[controllerNum].needAnalog[needNum] = analogPressed
        updateKeyState(&gEngine.input.gamepads[controllerNum].needStates[needNum], pressed)
    }
}

// MARK: -

// MARK: - Public functions

func DoSDLMaintenance() {
    gEngine.input.textInput = ""
    gEngine.input.mouseMotionNow = false
    var mouseWheelDeltaX: Int32 = 0
    var mouseWheelDeltaY: Int32 = 0

    // DO SDL MAINTENANCE

    SDL_PumpEvents()
    var event = SDL_Event()
    while SDL_PollEvent(&event) {
        switch SDL_EventType(UInt32(event.type)) {
        case SDL_EVENT_QUIT, SDL_EVENT_WINDOW_CLOSE_REQUESTED:
            CleanQuit() // exits the process (noreturn) - see SwExitToShell in Misc.swift

        case SDL_EVENT_KEY_DOWN:
            gEngine.input.userPrefersGamepad = 0

        case SDL_EVENT_TEXT_INPUT:
            if let text = event.text.text {
                gEngine.input.textInput = String(cString: text)
            }

        case SDL_EVENT_MOUSE_MOTION:
            gEngine.input.mouseMotionNow = true
            gEngine.input.userPrefersGamepad = 0

        case SDL_EVENT_MOUSE_WHEEL:
            gEngine.input.userPrefersGamepad = 0
            mouseWheelDeltaX += Int32(event.wheel.y)
            mouseWheelDeltaY += Int32(event.wheel.x)

        case SDL_EVENT_GAMEPAD_ADDED:
            _ = tryOpenGamepadFromJoystick(event.gdevice.which)

        case SDL_EVENT_GAMEPAD_REMOVED:
            onJoystickRemoved(event.gdevice.which)

        case SDL_EVENT_GAMEPAD_BUTTON_DOWN, SDL_EVENT_GAMEPAD_BUTTON_UP:
            gEngine.input.userPrefersGamepad = 1

        default:
            break
        }
    }

    // Refresh the state of each individual keyboard key
    updateRawKeyboardStates()

    // On ALT+ENTER, toggle fullscreen, and ignore ENTER until keyup.
    // Also, on macOS, process Cmd+Q.
    processSystemKeyChords()

    // Refresh the state of each mouse button
    updateMouseButtonStates(mouseWheelDeltaX, mouseWheelDeltaY)

    // Refresh the state of each input need
    updateInputNeeds()

    // Multiplayer gamepad input

    for controllerNum in 0..<maxLocalPlayers {
        updateControllerSpecificInputNeeds(controllerNum)
    }
}

// MARK: - Keyboard states

@c @implementation
public func GetKeyState(_ sdlScancode: UInt16) -> Int32 {
    if sdlScancode >= SDL_SCANCODE_COUNT.rawValue {
        return Int32(KEYSTATE_OFF)
    }
    return Int32(gEngine.input.keyboardStates[Int(sdlScancode)])
}

// MARK: - Click states

@c @implementation
public func GetClickState(_ mouseButton: Int32) -> Int32 {
    if mouseButton >= Int32(NUM_SUPPORTED_MOUSE_BUTTONS) {
        return Int32(KEYSTATE_OFF)
    }
    return Int32(gEngine.input.mouseButtonStates[Int(mouseButton)])
}

// MARK: - Need states

private func getNeedStateAnyP(_ needID: Int) -> Int32 {
    gEngine.input.lastGamepadForNeedAnyP[needID] = -1

    for i in 0..<maxLocalPlayers {
        if gEngine.input.gamepads[i].open && gEngine.input.gamepads[i].needStates[needID] != 0 {
            gEngine.input.lastGamepadForNeedAnyP[needID] = Int32(i)
            return Int32(gEngine.input.gamepads[i].needStates[needID])
        }
    }

    // Fallback to KB/M
    return Int32(gEngine.input.needStates[needID])
}

@c @implementation
public func GetNeedState(_ needID: Int32, _ playerID: Int32) -> Int32 {
    if playerID == Int32(ANY_PLAYER) {
        return getNeedStateAnyP(Int(needID))
    }

    SwGameAssert(playerID >= 0)
    SwGameAssert(playerID < Int32(maxLocalPlayers))
    SwGameAssert(needID >= 0)
    SwGameAssert(needID < Int32(NUM_CONTROL_NEEDS))

    let controller = gEngine.input.gamepads[Int(playerID)]

    if controller.open && controller.needStates[Int(needID)] != 0 {
        return Int32(controller.needStates[Int(needID)])
    }

    // Fallback to KB/M
    if playerID == Int32(gEngine.player.numPlayers) - 1 { // KBMFallbackPlayer()
        return Int32(gEngine.input.needStates[Int(needID)])
    }

    return Int32(KEYSTATE_OFF)
}

func GetLastControllerForNeedAnyP(_ needID: Int32) -> Int32 {
    SwGameAssert(needID >= 0)
    SwGameAssert(needID < Int32(NUM_CONTROL_NEEDS))

    return gEngine.input.lastGamepadForNeedAnyP[Int(needID)]
}

private func getNeedAnalogValueAnyP(_ needID: Int32) -> Float {
    for i in 0..<maxLocalPlayers {
        if gEngine.input.gamepads[i].open && gEngine.input.gamepads[i].needStates[Int(needID)] != 0 {
            return GetNeedAnalogValue(needID, Int32(i))
        }
    }

    // Fallback to KB/M
    return GetNeedAnalogValue(needID, Int32(gEngine.player.numPlayers) - 1) // KBMFallbackPlayer()
}

func GetNeedAnalogValue(_ needID: Int32, _ playerID: Int32) -> Float {
    if playerID == Int32(ANY_PLAYER) {
        return getNeedAnalogValueAnyP(needID)
    }

    SwGameAssert(playerID >= 0)
    SwGameAssert(playerID < Int32(maxLocalPlayers))
    SwGameAssert(needID >= 0)
    SwGameAssert(needID < Int32(NUM_CONTROL_NEEDS))

    let controller = gEngine.input.gamepads[Int(playerID)]

    if controller.open && controller.needAnalog[Int(needID)] != 0.0 {
        return controller.needAnalog[Int(needID)]
    }

    // Fallback to KB/M
    if playerID == Int32(gEngine.player.numPlayers) - 1 { // KBMFallbackPlayer()
        if gEngine.input.needStates[Int(needID)] & UInt8(KEYSTATE_ACTIVE_BIT) != 0 {
            return 1.0
        }
    }

    return 0.0
}

func GetNeedAnalogSteering(_ negativeNeedID: Int32, _ positiveNeedID: Int32, _ playerID: Int32) -> Float {
    let neg = GetNeedAnalogValue(negativeNeedID, playerID)
    let pos = GetNeedAnalogValue(positiveNeedID, playerID)

    if neg > pos {
        return -neg
    } else {
        return pos
    }
}

func UserWantsOut() -> UInt8 {
    if gEngine.window.gammaFadeFrac < 1 { // disallow skipping during fade-in
        return 0
    }

    let out = SwIsNeedDown(Int(kNeed_UIConfirm), Int(ANY_PLAYER))
        || SwIsNeedDown(Int(kNeed_UIBack), Int(ANY_PLAYER))
        || SwIsNeedDown(Int(kNeed_UIPause), Int(ANY_PLAYER))
        || SwIsClickDown(Int(SDL_BUTTON_LEFT))
    return out ? 1 : 0
}

func IsCmdQDown() -> UInt8 {
#if os(macOS)
    let cmdHeld = SwIsKeyHeld(Int(SDL_SCANCODE_LGUI.rawValue)) || SwIsKeyHeld(Int(SDL_SCANCODE_RGUI.rawValue))
    let qScancode = SDL_GetScancodeFromKey(SDLK_Q, nil)
    return (cmdHeld && SwIsKeyDown(Int(qScancode.rawValue))) ? 1 : 0
#else
    // On non-macOS systems, alt-f4 is handled by the system
    return 0
#endif
}

func IsCheatKeyComboDown() -> UInt8 {
    // The original Mac version used B-R-I, but some cheap PC keyboards can't register
    // this particular key combo, so C-M-R is available as an alternative.
    let combo = (SwIsKeyHeld(Int(SDL_SCANCODE_B.rawValue)) && SwIsKeyHeld(Int(SDL_SCANCODE_R.rawValue)) && SwIsKeyHeld(Int(SDL_SCANCODE_I.rawValue)))
        || (SwIsKeyHeld(Int(SDL_SCANCODE_C.rawValue)) && SwIsKeyHeld(Int(SDL_SCANCODE_M.rawValue)) && SwIsKeyHeld(Int(SDL_SCANCODE_R.rawValue)))
    return combo ? 1 : 0
}

// MARK: - Controller mapping

func GetNumGamepad() -> Int32 {
    var count: Int32 = 0

    for i in 0..<maxLocalPlayers {
        if gEngine.input.gamepads[i].open {
            count += 1
        }
    }

    return count
}

func GetGamepad(_ n: Int32) -> OpaquePointer? {
    if gEngine.input.gamepads[Int(n)].open {
        return gEngine.input.gamepads[Int(n)].sdlGamepad
    } else {
        return nil
    }
}

private func findFreeGamepadSlot() -> Int {
    for i in 0..<maxLocalPlayers {
        if !gEngine.input.gamepads[i].open {
            return i
        }
    }

    return -1
}

private func getGamepadSlotFromJoystick(_ joystickID: SDL_JoystickID) -> Int {
    for gamepadSlot in 0..<maxLocalPlayers {
        let gamepad = gEngine.input.gamepads[gamepadSlot]
        if gamepad.open && SDL_GetGamepadID(gamepad.sdlGamepad) == joystickID {
            return gamepadSlot
        }
    }

    return -1
}

@discardableResult
private func tryOpenGamepadFromJoystick(_ joystickID: SDL_JoystickID) -> OpaquePointer? {
    // First, check that it's not in use already
    var gamepadSlot = getGamepadSlotFromJoystick(joystickID)
    if gamepadSlot >= 0 { // in use
        return gEngine.input.gamepads[gamepadSlot].sdlGamepad
    }

    // If we can't get an SDL_Gamepad from that joystick, don't bother
    if !SDL_IsGamepad(joystickID) {
        return nil
    }

    // Reserve a gamepad slot
    gamepadSlot = findFreeGamepadSlot()
    if gamepadSlot < 0 {
        // SDL_Log unavailable (variadic); diagnostic only.
        // TODO: when a controller is unplugged, if all controller slots are used up, re-scan connected joysticks and try to open any unopened joysticks.
        return nil
    }

    // Use this one
    let sdlGamepad = SDL_OpenGamepad(joystickID)

    // Assign player ID
    SDL_SetGamepadPlayerIndex(sdlGamepad, Int32(gamepadSlot))

    // Get properties
    let props = SDL_GetGamepadProperties(sdlGamepad)

    gEngine.input.gamepads[gamepadSlot] = Gamepad()
    gEngine.input.gamepads[gamepadSlot].open = true
    gEngine.input.gamepads[gamepadSlot].sdlGamepad = sdlGamepad
    gEngine.input.gamepads[gamepadSlot].hasRumble = SDL_GetBooleanProperty(props, SDL_PROP_GAMEPAD_CAP_RUMBLE_BOOLEAN, false)

    // SDL_Log unavailable (variadic); diagnostic only.

    gEngine.input.userPrefersGamepad = 1

    return gEngine.input.gamepads[gamepadSlot].sdlGamepad
}

@discardableResult
private func tryOpenAnyUnusedGamepad(_ showMessage: Bool) -> OpaquePointer? {
    var numJoysticks: Int32 = 0
    var numJoysticksAlreadyInUse = 0

    guard let joysticks = SDL_GetJoysticks(&numJoysticks) else {
        return nil
    }
    var newGamepad: OpaquePointer?

    for i in 0..<Int(numJoysticks) {
        let joystickID = joysticks[i]

        // Usable as an SDL_Gamepad?
        if !SDL_IsGamepad(joystickID) {
            continue
        }

        // Already in use?
        if getGamepadSlotFromJoystick(joystickID) >= 0 {
            numJoysticksAlreadyInUse += 1
            continue
        }

        // Use this one
        newGamepad = tryOpenGamepadFromJoystick(joystickID)
        if newGamepad != nil {
            break
        }
    }

    if newGamepad != nil {
        // OK
    } else if numJoysticksAlreadyInUse == Int(numJoysticks) {
        // No-op; All joysticks already in use (or there might be zero joysticks)
    } else {
        // SDL_Log unavailable (variadic); diagnostic only.
        if showMessage {
            let name = SDL_GetJoystickNameForID(joysticks[0])
            let message = "The game does not support your controller yet (\"\(name.map { String(cString: $0) } ?? "")\").\n\nYou can play with the keyboard and mouse instead. Sorry!"
            do {
                _ = SDL_ShowSimpleMessageBox(
                    UInt32(SDL_MESSAGEBOX_WARNING),
                    "Controller not supported",
                    message,
                    gSDLWindow)
            }
        }
    }

    SDL_free(joysticks)

    return newGamepad
}

func Rumble(_ lowFrequencyStrength: Float, _ highFrequencyStrength: Float, _ ms: UInt32, _ playerID: Int32) {
    // Don't bother if rumble turned off in prefs
    if gGamePrefs.rumbleIntensity == 0 {
        return
    }

    let rumbleIntensityFrac = Float(gGamePrefs.rumbleIntensity) * (1.0 / 100.0)
    var lowFrequencyStrength = lowFrequencyStrength * rumbleIntensityFrac
    var highFrequencyStrength = highFrequencyStrength * rumbleIntensityFrac

    // If ANY_PLAYER, do rumble on all controllers
    if playerID == Int32(ANY_PLAYER) {
        for i in 0..<maxLocalPlayers {
            Rumble(lowFrequencyStrength, highFrequencyStrength, ms, Int32(i))
        }
        return
    }

    SwGameAssert(playerID >= 0)
    SwGameAssert(playerID < Int32(maxLocalPlayers))

    let gamepad = gEngine.input.gamepads[Int(playerID)]

    // Gotta have a valid SDL_Gamepad instance
    guard gamepad.hasRumble, gamepad.sdlGamepad != nil else {
        return
    }

    SDL_RumbleGamepad(
        gamepad.sdlGamepad,
        UInt16(lowFrequencyStrength * 65535),
        UInt16(highFrequencyStrength * 65535),
        UInt32(Float(ms) * rumbleIntensityFrac))

    // Prevent jetpack effect from kicking in while we're playing this
    GetPlayerInfoEntry(playerID).pointee.jetpackRumbleCooldown = Float(ms) * (1.0 / 1000.0)

    _ = lowFrequencyStrength
    _ = highFrequencyStrength
    lowFrequencyStrength = 0
    highFrequencyStrength = 0
}

private func closeGamepad(_ controllerSlot: Int) {
    SwGameAssert(gEngine.input.gamepads[controllerSlot].open)
    SwGameAssert(gEngine.input.gamepads[controllerSlot].sdlGamepad != nil)

    SDL_CloseGamepad(gEngine.input.gamepads[controllerSlot].sdlGamepad)
    gEngine.input.gamepads[controllerSlot].open = false
    gEngine.input.gamepads[controllerSlot].sdlGamepad = nil
    gEngine.input.gamepads[controllerSlot].hasRumble = false
}

private func moveController(_ oldSlot: Int, _ newSlot: Int) {
    if oldSlot == newSlot {
        return
    }

    // SDL_Log unavailable (variadic); diagnostic only.

    gEngine.input.gamepads[newSlot] = gEngine.input.gamepads[oldSlot]

    // TODO: Does this actually work??
    if gEngine.input.gamepads[newSlot].open {
        SDL_SetGamepadPlayerIndex(gEngine.input.gamepads[newSlot].sdlGamepad, Int32(newSlot))
    }

    // Clear duplicate slot so we don't read it by mistake in the future
    gEngine.input.gamepads[oldSlot].open = false
    gEngine.input.gamepads[oldSlot].sdlGamepad = nil
    gEngine.input.gamepads[oldSlot].hasRumble = false
}

private func compactGamepadSlots() {
    var writeIndex = 0

    for i in 0..<maxLocalPlayers {
        SwGameAssert(writeIndex <= i)

        if gEngine.input.gamepads[i].open {
            moveController(i, writeIndex)
            writeIndex += 1
        }
    }
}

private func swapControllers(_ slotA: Int, _ slotB: Int) {
    if slotA == slotB || slotA < 0 || slotB < 0 {
        return
    }

    let copy = gEngine.input.gamepads[slotB]
    gEngine.input.gamepads[slotB] = gEngine.input.gamepads[slotA]
    gEngine.input.gamepads[slotA] = copy

    if gEngine.input.gamepads[slotA].open {
        SDL_SetGamepadPlayerIndex(gEngine.input.gamepads[slotA].sdlGamepad, Int32(slotA))
    }

    if gEngine.input.gamepads[slotB].open {
        SDL_SetGamepadPlayerIndex(gEngine.input.gamepads[slotB].sdlGamepad, Int32(slotB))
    }
}

func SetMainController(_ oldSlot: Int32) {
    swapControllers(0, Int(oldSlot))
}

private func tryFillUpVacantGamepadSlots() {
    while tryOpenAnyUnusedGamepad(false) != nil {
        // Successful; there might be more joysticks available, keep going
    }
}

private func onJoystickRemoved(_ joystickID: SDL_JoystickID) {
    let gamepadSlot = getGamepadSlotFromJoystick(joystickID)

    if gamepadSlot >= 0 { // we're using this joystick
        // SDL_Log unavailable (variadic); diagnostic only.

        // Nuke reference to this SDL_Gamepad
        closeGamepad(gamepadSlot)
    }

    if !gEngine.input.gamepadPlayerMappingLocked {
        compactGamepadSlots()
    }

    // Fill up any gamepad slots that are vacant
    tryFillUpVacantGamepadSlots()

    // Disable gEngine.input.userPrefersGamepad if there are no gamepads connected
    if GetNumGamepad() == 0 {
        gEngine.input.userPrefersGamepad = 0
    }
}

// MARK: -

// MARK: - Reset bindings

func ResetDefaultKeyboardBindings() {
    withUnsafePointer(to: kDefaultInputBindings) { defaultsPtr in
        let defaults = UnsafeRawPointer(defaultsPtr).assumingMemoryBound(to: InputBinding.self)
        for i in 0..<Int(NUM_CONTROL_NEEDS) {
            withUnsafeMutablePointer(to: &gGamePrefs.bindings) { bindingsPtr in
                let dst = UnsafeMutableRawPointer(bindingsPtr).assumingMemoryBound(to: InputBinding.self) + i
                let src = defaults + i
                for j in 0..<Int(MAX_BINDINGS_PER_NEED) {
                    InputBinding_SetKey(dst, Int32(j), InputBinding_GetKey(src, Int32(j)))
                }
            }
        }
    }
}

func ResetDefaultGamepadBindings() {
    withUnsafePointer(to: kDefaultInputBindings) { defaultsPtr in
        let defaults = UnsafeRawPointer(defaultsPtr).assumingMemoryBound(to: InputBinding.self)
        for i in 0..<Int(NUM_CONTROL_NEEDS) {
            withUnsafeMutablePointer(to: &gGamePrefs.bindings) { bindingsPtr in
                let dst = UnsafeMutableRawPointer(bindingsPtr).assumingMemoryBound(to: InputBinding.self) + i
                let src = defaults + i
                for j in 0..<Int(MAX_BINDINGS_PER_NEED) {
                    InputBinding_SetPad(dst, Int32(j), InputBinding_GetPadType(src, Int32(j)), InputBinding_GetPadID(src, Int32(j)))
                }
            }
        }
    }

    gGamePrefs.rumbleIntensity = 100
}

func ResetDefaultMouseBindings() {
    gGamePrefs.mouseSensitivityLevel = UInt8(DEFAULT_MOUSE_SENSITIVITY_LEVEL)

    withUnsafePointer(to: kDefaultInputBindings) { defaultsPtr in
        let defaults = UnsafeRawPointer(defaultsPtr).assumingMemoryBound(to: InputBinding.self)
        for i in 0..<Int(NUM_CONTROL_NEEDS) {
            withUnsafeMutablePointer(to: &gGamePrefs.bindings) { bindingsPtr in
                let dst = UnsafeMutableRawPointer(bindingsPtr).assumingMemoryBound(to: InputBinding.self) + i
                dst.pointee.mouseButton = defaults[i].mouseButton
            }
        }
    }
}

// MARK: -

// MARK: - Mouse

// (MOUSE_SMOOTHING is hardcoded off, so the whole smoothing-accumulator
// mechanism is dead code and dropped; GetMouseDelta always uses the
// simple 60Hz-clamped SDL_GetRelativeMouseState path.)


func GetMouseDelta() -> OGLVector2D {
    gEngine.input.mouseDeltaTimeSinceLastCall += gEngine.framesPerSecondFrac

    // Mouse sensitivity settings are calibrated to feel good at 60 FPS,
    // so we mustn't poll GetRelativeMouseState any faster than 60 Hz.
    if gEngine.input.mouseDeltaTimeSinceLastCall >= (1.0 / 60.0) {
        let (_, x, y) = SDL.relativeMouseState
        gEngine.input.mouseDeltaLast = OGLVector2D(x: x, y: y)
        gEngine.input.mouseDeltaTimeSinceLastCall = 0
    }

    return gEngine.input.mouseDeltaLast
}

func GetMouseCoords640x480() -> OGLPoint2D {
    var ww: Int32 = 0
    var wh: Int32 = 0
    let (_, mx, my) = SDL.mouseState
    SDL_GetWindowSize(gSDLWindow, &ww, &wh)

    let r = Get2DLogicalRect(UInt8(gEngine.player.numPlayers), 1)

    let screenToPaneX = (r.right - r.left) / Float(ww)
    let screenToPaneY = (r.bottom - r.top) / Float(wh)

    return OGLPoint2D(x: mx * screenToPaneX + r.left, y: my * screenToPaneY + r.top)
}


func BackupRestoreCursorCoord(_ backup: UInt8) {
    if backup != 0 {
        gEngine.input.cursorCoordBackup = gEngine.input.cursorCoord
    } else if gEngine.input.cursorCoordBackup.x >= 0 {
        gEngine.input.cursorCoord = gEngine.input.cursorCoordBackup
        let r = Get2DLogicalRect(UInt8(gEngine.player.numPlayers), 1)

        var ww: Int32 = 0
        var wh: Int32 = 0
        SDL_GetWindowSize(gSDLWindow, &ww, &wh)

        let screenToPaneX = (r.right - r.left) / Float(ww)
        let screenToPaneY = (r.bottom - r.top) / Float(wh)

        let mx = (gEngine.input.cursorCoord.x - r.left) / screenToPaneX
        let my = (gEngine.input.cursorCoord.y - r.top) / screenToPaneY
        SDL_WarpMouseInWindow(gSDLWindow, mx, my)
    }
}

func GrabMouse(_ capture: UInt8) {
    if capture != 0 {
        BackupRestoreCursorCoord(1)
    }

    SDL_SetWindowMouseGrab(gSDLWindow, capture != 0)
    SDL_SetWindowRelativeMouseMode(gSDLWindow, capture != 0)
    SetMacLinearMouse(capture)

    if capture == 0 {
        BackupRestoreCursorCoord(0)
    }
}
