// UIEffects.swift - Port of UIEffects.c to Swift
//
// TwitchDriverData and GetTwitchDriverData moved to UIEffectsInternal.h:
// the struct lives in ObjNode's SpecialPadding, which is a member of an
// anonymous union, and Swift's pointer(to:) nil-crashes on union members —
// so the pointer is handed out by a C shim instead.

private let TWITCH_DRIVER_COOKIE: UInt32 = 0x55494658 // 'UIFX'

// gTwitchPtrPool/gTwitchBackingMemory/gTwitchPresets were `static`
// (file-private) in C, and gFreeTwitches isn't `extern`'d anywhere, so none
// of them need to stay C-linked. Fixed-size C arrays this shape would import
// as unworkable tuples anyway, so we manage the backing storage ourselves
// with the same zero-initializing allocator the C code effectively relied on.
private var gFreeTwitches = Int(MAX_TWITCHES)
private var gTwitchPtrPoolInitialized = false
private let gTwitchPtrPool = AllocPtrClear(MemoryLayout<UnsafeMutablePointer<Twitch>?>.size * Int(MAX_TWITCHES))!.assumingMemoryBound(to: UnsafeMutablePointer<Twitch>?.self)
private let gTwitchBackingMemory = AllocPtrClear(MemoryLayout<Twitch>.size * Int(MAX_TWITCHES))!.assumingMemoryBound(to: Twitch.self)

private let gTwitchPresets = AllocPtrClear(MemoryLayout<Twitch>.size * Int(kTwitchPresetCOUNT))!.assumingMemoryBound(to: Twitch.self)
private var gTwitchPresetsLoaded = false

// The C original indexed this array by enum value via designated
// initializers; tuples of (enum value, name) preserve that mapping.
private let kTwitchEnumNames: [(Int, String)] = [
    (Int(kTwitchPreset_MenuSelect), "kTwitchPreset_MenuSelect"),
    (Int(kTwitchPreset_MenuDeselect), "kTwitchPreset_MenuDeselect"),
    (Int(kTwitchPreset_MenuWiggle), "kTwitchPreset_MenuWiggle"),
    (Int(kTwitchPreset_MenuFadeIn), "kTwitchPreset_MenuFadeIn"),
    (Int(kTwitchPreset_MenuFadeOut), "kTwitchPreset_MenuFadeOut"),
    (Int(kTwitchPreset_MenuDarkenPaneResize), "kTwitchPreset_MenuDarkenPaneResize"),
    (Int(kTwitchPreset_MenuDarkenPaneVanish), "kTwitchPreset_MenuDarkenPaneVanish"),
    (Int(kTwitchPreset_MenuSweep), "kTwitchPreset_MenuSweep"),
    (Int(kTwitchPreset_PadlockWiggle), "kTwitchPreset_PadlockWiggle"),
    (Int(kTwitchPreset_DisplaceLTR), "kTwitchPreset_DisplaceLTR"),
    (Int(kTwitchPreset_DisplaceRTL), "kTwitchPreset_DisplaceRTL"),
    (Int(kTwitchPreset_SlideshowLTR), "kTwitchPreset_SlideshowLTR"),
    (Int(kTwitchPreset_SlideshowRTL), "kTwitchPreset_SlideshowRTL"),
    (Int(kTwitchPreset_ItemGain), "kTwitchPreset_ItemGain"),
    (Int(kTwitchPreset_ItemLoss), "kTwitchPreset_ItemLoss"),
    (Int(kTwitchPreset_RankGain), "kTwitchPreset_RankGain"),
    (Int(kTwitchPreset_RankLoss), "kTwitchPreset_RankLoss"),
    (Int(kTwitchPreset_ArrowheadSpin), "kTwitchPreset_ArrowheadSpin"),
    (Int(kTwitchPreset_GiantArrowheadSpin), "kTwitchPreset_GiantArrowheadSpin"),
    (Int(kTwitchPreset_WeaponFlip), "kTwitchPreset_WeaponFlip"),
    (Int(kTwitchPreset_NewBuff), "kTwitchPreset_NewBuff"),
    (Int(kTwitchPreset_NewWeapon), "kTwitchPreset_NewWeapon"),
    (Int(kTwitchPreset_POWExpired), "kTwitchPreset_POWExpired"),
    (Int(kTwitchPreset_LapMessageAppear), "kTwitchPreset_LapMessageAppear"),
    (Int(kTwitchPreset_LapMessageFadeOut), "kTwitchPreset_LapMessageFadeOut"),
    (Int(kTwitchPreset_LapDiffFadeOut), "kTwitchPreset_LapDiffFadeOut"),
    (Int(kTwitchPreset_TrackNameFadeOut), "kTwitchPreset_TrackNameFadeOut"),
    (Int(kTwitchPreset_FinalPlaceReveal), "kTwitchPreset_FinalPlaceReveal"),
    (Int(kTwitchPreset_YourTimeReveal), "kTwitchPreset_YourTimeReveal"),
    (Int(kTwitchPreset_NewRecordReveal), "kTwitchPreset_NewRecordReveal"),
    (Int(kTwitchPreset_ScoreboardFadeIn), "kTwitchPreset_ScoreboardFadeIn"),
    (Int(kTwitchPreset_PressKeyPrompt), "kTwitchPreset_PressKeyPrompt"),

    (Int(kTwitchClass_Heartbeat), "kTwitchClass_Heartbeat"),
    (Int(kTwitchClass_Shrink), "kTwitchClass_Shrink"),
    (Int(kTwitchClass_Spin), "kTwitchClass_Spin"),
    (Int(kTwitchClass_Displace), "kTwitchClass_Displace"),
    (Int(kTwitchClass_Wiggle), "kTwitchClass_Wiggle"),
    (Int(kTwitchClass_AlphaFadeIn), "kTwitchClass_AlphaFadeIn"),
    (Int(kTwitchClass_AlphaFadeOut), "kTwitchClass_AlphaFadeOut"),
    (Int(kTwitchClass_MultAlphaFadeIn), "kTwitchClass_MultAlphaFadeIn"),
    (Int(kTwitchClass_MultAlphaFadeOut), "kTwitchClass_MultAlphaFadeOut"),

    (Int(kEaseLinear), "kEaseLinear"),
    (Int(kEaseInQuad), "kEaseInQuad"),
    (Int(kEaseOutQuad), "kEaseOutQuad"),
    (Int(kEaseOutCubic), "kEaseOutCubic"),
    (Int(kEaseInExpo), "kEaseInExpo"),
    (Int(kEaseOutExpo), "kEaseOutExpo"),
    (Int(kEaseInBack), "kEaseInBack"),
    (Int(kEaseOutBack), "kEaseOutBack"),
    (Int(kEaseBounce0To0), "kEaseBounce0To0"),
]

// MARK: - fixed-array-field helpers (all struct fields, never unions)

@inline(__always) private func fxChainBase(_ d: UnsafeMutablePointer<TwitchDriverData>) -> UnsafeMutablePointer<UnsafeMutablePointer<Twitch>?> {
    UnsafeMutableRawPointer(d.pointer(to: \.fxChain)!).assumingMemoryBound(to: UnsafeMutablePointer<Twitch>?.self)
}

@inline(__always) private func timersBase(_ d: UnsafeMutablePointer<TwitchDriverData>) -> UnsafeMutablePointer<Float> {
    UnsafeMutableRawPointer(d.pointer(to: \.timers)!).assumingMemoryBound(to: Float.self)
}

@inline(__always) private func isObjectBeingDeleted(_ node: UnsafeMutablePointer<ObjNode>) -> Bool {
    node.pointee.CType == INVALID_NODE_FLAG
}

// MARK: - Twitch pool management

private func initTwitchPool() {
    for i in 0..<Int(MAX_TWITCHES) {
        gTwitchPtrPool[i] = gTwitchBackingMemory + i
    }

    gFreeTwitches = Int(MAX_TWITCHES)
    gTwitchPtrPoolInitialized = true
}

private func isPooledTwitchFree(_ e: UnsafeMutablePointer<Twitch>) -> Bool {
    for i in 0..<Int(MAX_TWITCHES) {
        if gTwitchPtrPool[i] == e {
            return true
        }
    }
    return false
}

private func allocTwitch() -> UnsafeMutablePointer<Twitch>? {
    if gFreeTwitches <= 0 {
        return nil
    }

    // Grab free slot
    let e = gTwitchPtrPool[gFreeTwitches - 1]
    gTwitchPtrPool[gFreeTwitches - 1] = nil

    gFreeTwitches -= 1

    return e
}

private var gDetectedDoubleFree = false // was function-static in C, debug builds only

private func disposeTwitch(_ e: UnsafeMutablePointer<Twitch>?) {
    guard let e else {
        return
    }

    #if _DEBUG
    if !gDetectedDoubleFree && isPooledTwitchFree(e) {
        gDetectedDoubleFree = true // avoid endless double-free messages caused by final cleanup in DoFatalAlert
        SwGameAssertMessage(false, "double-freeing pooled ptr")
    }
    #endif

    let i = gFreeTwitches
    SwGameAssert(i < Int(MAX_TWITCHES))

    gTwitchPtrPool[i] = e
    gFreeTwitches += 1
}

// MARK: - Parse presets from CSV file

private func findEnumString(_ prefix: String, _ column: String?) -> Int {
    guard let column else {
        return -1
    }

    for (value, enumName) in kTwitchEnumNames {
        if enumName.hasPrefix(prefix) && enumName.dropFirst(prefix.count) == column {
            return value
        }
    }

    return -1
}

private func loadTwitchPresets() {
    let kCSVColumn_Preset = 0
    let kCSVColumn_Class = 1
    let kCSVColumn_AxisConstraint = 2
    let kCSVColumn_Easing = 3
    let kCSVColumn_Duration = 4
    let kCSVColumn_Amplitude = 5
    let kCSVColumn_Period = 6
    let kCSVColumn_Phase = 7
    let kCSVColumn_Delay = 8

    gTwitchPresets.update(repeating: Twitch(), count: Int(kTwitchPresetCOUNT))

    let csv = LoadTextFile(":System:twitch.csv", nil)

    var eol = false

    var csvReader: UnsafeMutablePointer<CChar>? = csv
    var column = 0
    var preset: UnsafeMutablePointer<Twitch>? = nil

    while csvReader != nil {
        let cellPtr = CSVIterator(&csvReader, &eol)

        // (the two guards below correspond to `goto nextColumn` in the C)
        if let cellPtr, !(column != 0 && preset == nil) {
            let cell = String(cString: cellPtr)

            switch column {
            case kCSVColumn_Preset:
                preset = nil
                let n = findEnumString("kTwitchPreset_", cell)
                if n >= 0 && n < Int(kTwitchPresetCOUNT) {
                    preset = gTwitchPresets + n
                } else if cell != "PRESET" { // skip header row
                    SwFatal2("Unknown twitch preset name", cell)
                }

            case kCSVColumn_Class:
                let n = findEnumString("kTwitchClass_", cell)
                if n < 0 {
                    SwFatal2("Unknown effect class", cell)
                }
                preset!.pointee.fxClass = UInt8(n)

            case kCSVColumn_AxisConstraint:
                for ch in cell {
                    switch ch {
                    case "x", "X": preset!.pointee.x = true
                    case "y", "Y": preset!.pointee.y = true
                    case "z", "Z": preset!.pointee.z = true
                    default: break
                    }
                }

                if !(preset!.pointee.x || preset!.pointee.y || preset!.pointee.z) { // if the cell was empty, default to XY
                    preset!.pointee.x = true
                    preset!.pointee.y = true
                    preset!.pointee.z = false
                }

            case kCSVColumn_Easing:
                let n = findEnumString("kEase", cell)
                if n < 0 {
                    SwFatal2("Unknown easing type", cell)
                }
                preset!.pointee.easing = UInt8(n)

            case kCSVColumn_Duration:
                preset!.pointee.duration = Float(atof(cellPtr))

            case kCSVColumn_Amplitude:
                preset!.pointee.amplitude = Float(atof(cellPtr))

            case kCSVColumn_Period:
                preset!.pointee.period = Float(PI) * Float(atof(cellPtr))

            case kCSVColumn_Phase:
                preset!.pointee.phase = Float(PI) * Float(atof(cellPtr))

            case kCSVColumn_Delay:
                preset!.pointee.delay = Float(atof(cellPtr))

            default:
                // ignore any other columns
                break
            }
        }

        if eol {
            column = 0
        } else {
            column += 1
        }
    }

    SafeDisposePtr(csv)

    gTwitchPresetsLoaded = true
}

// MARK: - Easing

private func lerp(_ a: Float, _ b: Float, _ p: Float) -> Float {
    (1 - p) * a + p * b
}

private func ease(_ p: Float, _ easingType: Int) -> Float {
    if easingType == Int(kEaseInQuad) {
        return p * p
    } else if easingType == Int(kEaseOutQuad) {
        let q = 1 - p
        return 1 - q * q
    } else if easingType == Int(kEaseOutCubic) {
        let q = 1 - p
        return 1 - q * q * q
    } else if easingType == Int(kEaseInExpo) {
        return p == 0 ? 0 : powf(2, 10 * p - 10)
    } else if easingType == Int(kEaseOutExpo) {
        return p == 1 ? 1 : 1 - powf(2, -10 * p)
    } else if easingType == Int(kEaseInBack) {
        let k: Float = 1.7
        return (k + 1) * p * p * p - k * p * p
    } else if easingType == Int(kEaseOutBack) {
        let q = 1 - p
        let k: Float = 1.7
        return 1 - ((k + 1) * q * q * q - k * q * q)
    } else if easingType == Int(kEaseBounce0To0) {
        let q = 2 * p - 1
        return q * q
        //return 1 - sqrtf(1 - (1-2*p)*(1-2*p));
    } else { // kEaseLinear & default
        return p
    }
}

// MARK: - Twitch runtime

private func multScale(_ puppet: UnsafeMutablePointer<ObjNode>, _ fx: UnsafePointer<Twitch>, _ f: Float) {
    if fx.pointee.x { puppet.pointee.Scale.x *= f }
    if fx.pointee.y { puppet.pointee.Scale.y *= f }
    if fx.pointee.z { puppet.pointee.Scale.z *= f }
}

private func displace(_ puppet: UnsafeMutablePointer<ObjNode>, _ fx: UnsafePointer<Twitch>, _ f: Float) {
    if fx.pointee.x { puppet.pointee.Coord.x += puppet.pointee.Scale.x * f }
    if fx.pointee.y { puppet.pointee.Coord.y += puppet.pointee.Scale.y * f }
    if fx.pointee.z { puppet.pointee.Coord.z += puppet.pointee.Scale.z * f }
}

private func applyTwitch(_ puppet: UnsafeMutablePointer<ObjNode>, _ fx: UnsafePointer<Twitch>, _ timer: Float) -> Bool {
    var duration = fx.pointee.duration
    if duration == 0 {
        #if _DEBUG
        SwLog("Twitch effect is missing duration")
        #endif
        duration = 1
    }

    var p = (timer - fx.pointee.delay) / duration
    var done = false

    if p >= 1 { // twitch complete
        p = 1
        done = true
    } else if p < 0 { // delayed
        p = 0
    }

    p = ease(p, Int(fx.pointee.easing))

    var f: Float

    let fxClass = Int(fx.pointee.fxClass)

    if fxClass == Int(kTwitchClass_Heartbeat) {
        f = lerp(fx.pointee.amplitude, 1, p)
        multScale(puppet, fx, f)
    } else if fxClass == Int(kTwitchClass_Shrink) {
        f = lerp(fx.pointee.amplitude, Float(EPS), p)
        multScale(puppet, fx, f)
    } else if fxClass == Int(kTwitchClass_Displace) {
        f = lerp(fx.pointee.amplitude, 0, p)
        displace(puppet, fx, f)
    } else if fxClass == Int(kTwitchClass_Wiggle) {
        f = 1 - p // dampening
        f = fx.pointee.amplitude * f * sinf(f * fx.pointee.period + fx.pointee.phase)
        displace(puppet, fx, f)
    } else if fxClass == Int(kTwitchClass_Spin) {
        f = cosf(p * fx.pointee.period + fx.pointee.phase)

        if fabsf(f) < 0.2 {
            f = 0.2 * (f < 0 ? -1 : 1)
        }

        f *= fx.pointee.amplitude
        multScale(puppet, fx, f)
    } else if fxClass == Int(kTwitchClass_MultAlphaFadeIn) {
        puppet.pointee.ColorFilter.a *= lerp(0, 1, p)
    } else if fxClass == Int(kTwitchClass_MultAlphaFadeOut) {
        puppet.pointee.ColorFilter.a *= lerp(1, 0, p)
    } else if fxClass == Int(kTwitchClass_AlphaFadeIn) {
        puppet.pointee.ColorFilter.a = lerp(0, fx.pointee.phase, p)
    } else if fxClass == Int(kTwitchClass_AlphaFadeOut) {
        puppet.pointee.ColorFilter.a = lerp(fx.pointee.phase, 0, p)
    } else {
        SwLog("Unknown effect class")
    }

    // Don't rely on p>=1 for completion because some easing functions may overshoot on purpose!
    return done
}

private let cMoveTwitchDriver: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { driverNode in
    moveTwitchDriver(driverNode!)
}

private func moveTwitchDriver(_ driverNode: UnsafeMutablePointer<ObjNode>) {
    let driverData = GetTwitchDriverData(driverNode)
    SwGameAssert(driverData.pointee.cookie == TWITCH_DRIVER_COOKIE)

    let puppet = driverData.pointee.puppet!

    if isObjectBeingDeleted(puppet) // puppet is being destroyed
        || puppet.pointee.TwitchNode != driverNode { // twitch driver was replaced
        DeleteObject(driverNode)
        return
    }

    // Backup home coord/scale/rotation
    let realC = puppet.pointee.Coord
    let realS = puppet.pointee.Scale
    let realR = puppet.pointee.Rot

    var anyEffectActive = false

    let fxChain = fxChainBase(driverData)
    let timers = timersBase(driverData)

    // Work through all effects in chain
    var fxNum = 0
    while fxNum < Int(driverData.pointee.chainLength) {
        let done = applyTwitch(puppet, fxChain[fxNum]!, timers[fxNum])

        if done {
            // Remove this effect from the chain
            disposeTwitch(fxChain[fxNum])
            fxChain[fxNum] = nil

            driverData.pointee.chainLength -= 1
            let lastFx = Int(driverData.pointee.chainLength)

            // Swap
            if fxNum != lastFx {
                timers[fxNum] = timers[lastFx]
                fxChain[fxNum] = fxChain[lastFx]
            }
        } else {
            timers[fxNum] += gFramesPerSecondFrac // tick effect timer
            anyEffectActive = anyEffectActive || timers[fxNum] >= fxChain[fxNum]!.pointee.delay

            fxNum += 1 // onto next effect in chain
        }
    }

    // Commit matrix
    UpdateObjectTransforms(puppet)

    // Restore home coord/scale/rotation
    puppet.pointee.Coord = realC
    puppet.pointee.Scale = realS
    puppet.pointee.Rot = realR

    // If we're done, nuke driverNode
    if driverData.pointee.chainLength == 0 {
        let killPuppet = driverData.pointee.deletePuppetOnCompletion

        puppet.pointee.TwitchNode = nil
        DeleteObject(driverNode)

        if killPuppet {
            DeleteObject(puppet)
        }
    } else {
        if driverData.pointee.hideDuringDelay {
            SetObjectVisible(puppet, anyEffectActive ? 1 : 0)
        }
    }
}

// MARK: - Twitch construction/destruction

private func disposeEffectChain(_ driverData: UnsafeMutablePointer<TwitchDriverData>) {
    let fxChain = fxChainBase(driverData)

    for i in 0..<Int(driverData.pointee.chainLength) {
        disposeTwitch(fxChain[i])
        fxChain[i] = nil
    }

    driverData.pointee.chainLength = 0
}

private let cDestroyTwitchDriver: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { driverNode in
    destroyTwitchDriver(driverNode!)
}

private func destroyTwitchDriver(_ driverNode: UnsafeMutablePointer<ObjNode>) {
    let driverData = GetTwitchDriverData(driverNode)

    if let puppet = driverData.pointee.puppet,
        !isObjectBeingDeleted(puppet),
        puppet.pointee.TwitchNode == driverNode {
        puppet.pointee.TwitchNode = nil
    }
    driverData.pointee.puppet = nil

    disposeEffectChain(driverData)
}

func MakeTwitch(_ puppet: UnsafeMutablePointer<ObjNode>?, _ presetAndFlags: Int32) -> UnsafeMutablePointer<Twitch>? {
    guard let puppet else {
        return nil
    }

    SwGameAssert(gTwitchPresetsLoaded)
    SwGameAssert(gTwitchPtrPoolInitialized)

    var driverNode: UnsafeMutablePointer<ObjNode>! = nil
    var driverData: UnsafeMutablePointer<TwitchDriverData>! = nil

    if let twitchNode = puppet.pointee.TwitchNode {
        driverNode = twitchNode
        driverData = GetTwitchDriverData(driverNode)

        SwGameAssert(puppet.pointee.TwitchNode == driverNode)
        SwGameAssert(driverData.pointee.cookie == TWITCH_DRIVER_COOKIE)
        SwGameAssert(driverData.pointee.puppet == puppet)
        SwGameAssert(driverNode.pointee.Slot > puppet.pointee.Slot)

        if presetAndFlags & Int32(kTwitchFlags_Chain) != 0 {
            if Int(driverData.pointee.chainLength) >= MAX_TWITCH_CHAIN_LENGTH {
                return nil
            }
        } else {
            // Interrupt ongoing effect chain
            driverData.pointee.deletePuppetOnCompletion = false
            disposeEffectChain(driverData)
        }
    } else {
        // Create a new twitch driver node
        var def = NewObjectDefinitionType()
        def.genre = UInt8(EVENT_GENRE)
        def.slot = Int16(puppet.pointee.Slot + 1)
        def.scale = 1
        def.moveCall = cMoveTwitchDriver
        def.flags = puppet.pointee.StatusBits & UInt32(STATUS_BIT_MOVEINPAUSE)

        driverNode = MakeNewObject(&def)
        driverNode.pointee.Destructor = cDestroyTwitchDriver
        driverData = GetTwitchDriverData(driverNode)

        driverData.pointee.cookie = TWITCH_DRIVER_COOKIE
        driverData.pointee.puppet = puppet
        puppet.pointee.TwitchNode = driverNode
    }

    driverData.pointee.deletePuppetOnCompletion = driverData.pointee.deletePuppetOnCompletion || (presetAndFlags & Int32(kTwitchFlags_KillPuppet)) != 0
    driverData.pointee.hideDuringDelay = driverData.pointee.hideDuringDelay || (presetAndFlags & Int32(kTwitchFlags_HideDuringDelay)) != 0

    guard let twitch = allocTwitch() else {
        return nil
    }

    let effectNum = Int(driverData.pointee.chainLength)
    driverData.pointee.chainLength += 1
    SwGameAssert(Int(driverData.pointee.chainLength) <= MAX_TWITCH_CHAIN_LENGTH)

    timersBase(driverData)[effectNum] = 0
    fxChainBase(driverData)[effectNum] = twitch

    let presetNum = Int(presetAndFlags & 0xFF)
    SwGameAssertMessage(presetNum <= Int(kTwitchPresetCOUNT), "Not a legal twitch preset")
    twitch.pointee = gTwitchPresets[presetNum]

    // Save current alpha as "phase" for alpha fade effects
    if Int(twitch.pointee.fxClass) == Int(kTwitchClass_AlphaFadeIn)
        || Int(twitch.pointee.fxClass) == Int(kTwitchClass_AlphaFadeOut) {
        twitch.pointee.phase = puppet.pointee.ColorFilter.a
    }

    return twitch
}

// MARK: - Init

func InitTwitchSystem() {
    loadTwitchPresets()
    initTwitchPool()
}
