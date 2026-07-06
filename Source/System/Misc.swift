// Misc.swift - Port of Misc.c to Swift
//
// DoAlert/DoFatalAlert stay in Misc.c because they take C variadic
// arguments, which Swift can't implement (same reasoning as
// LocalizeWithPlaceholder staying in Localization.c). gRAMAlloced,
// gFramesPerSecond, gFramesPerSecondFrac, and gNumPointers also stay defined
// in Misc.c so other still-unported C files can keep reading/writing them
// via `extern`; Swift reads/writes them here the same way it already does
// for gGameViewInfoPtr etc. gSeed0/1/2 aren't `extern`'d anywhere else, so
// unlike those they don't need to stay C-linked.

private let MAX_FPS: Float = 300 // mac original was 190
private let DEFAULT_FPS: Float = 13

// gSeed0/1/2 are private to Misc.c/Misc.swift; nothing else `extern`s them.
private var gSeed0: UInt32 = 0
private var gSeed1: UInt32 = 0
private var gSeed2: UInt32 = 0

@c @implementation
public func CleanQuit() -> Never {
    struct Once { static var beenHere = false }

    if !Once.beenHere {
        Once.beenHere = true

        SavePrefs() // save prefs before bailing

        DeleteAllObjects()
        DisposeTerrain() // dispose of any memory allocated by terrain manager
        DisposeAllBG3DContainers() // nuke all models
        DisposeAllSpriteGroups() // nuke all sprites
        DisposeAllSpriteAtlases()

        if gGameViewInfoPtr != nil { // see if need to dispose this
            OGL_DisposeGameView()
        }

        OGL_Shutdown()

        ShutdownSound() // cleanup sound stuff
    }

    #if !NANOSAUR_3DS
    SDL_ShowCursor() // no pointer cursor to restore on a 3DS touchscreen
    #endif
    MyFlushEvents()

    ExitToShell()
}

// MARK: - Random number generator

func MyRandomLong() -> UInt32 {
    gSeed1 ^= (gSeed2 >> 5) &* 1568397607
    gSeed0 = (gSeed0 &+ 1) &* 3141592621
    let sum = (gSeed1 >> 7) &+ gSeed0
    gSeed2 ^= sum &* 2435386481
    return gSeed2
}

// THE RANGE *IS* INCLUSIVE OF MIN AND MAX
func RandomRange(_ min: UInt16, _ max: UInt16) -> UInt16 {
    let qdRdm = UInt16(truncatingIfNeeded: MyRandomLong()) // treat return value as 0-65536
    let range = UInt32(max) + 1 - UInt32(min)
    let t = (UInt32(qdRdm) &* range) >> 16 // now 0 <= t <= range

    return UInt16(t) &+ min
}

// returns a random float between 0 and 1
func RandomFloat() -> Float {
    let r = MyRandomLong() & 0xfff
    if r == 0 {
        return 0
    }

    var f = Float(r) // convert to float
    f = f * (1.0 / Float(0xfff)) // get # between 0..1
    return f
}

// returns a random float between -1 and +1
func RandomFloat2() -> Float {
    let r = MyRandomLong() & 0xfff
    if r == 0 {
        return 0
    }

    var f = Float(r) // convert to float
    f = f * (2.0 / Float(0xfff)) // get # between 0..2
    f -= 1.0 // get -1..+1
    return f
}

func SetMyRandomSeed(_ seed: UInt32) {
    gSeed0 = seed
    gSeed1 = 0
    gSeed2 = 0
}

func InitMyRandomSeed() {
    gSeed0 = 0x2a80ce30
    gSeed1 = 0
    gSeed2 = 0
}

// MARK: - Pointer allocation

private let PTRCOOKIE_SIZE = 16

@c @implementation
public func AllocPtr(_ size0: Int) -> UnsafeMutableRawPointer? {
    SwGameAssert(size0 >= 0)
    SwGameAssert(size0 <= 0x7FFFFFFF)

    let size = size0 + PTRCOOKIE_SIZE // make room for our cookie & whatever else (also keep to 16-byte alignment!)
    #if NANOSAUR_3DS
    let p = malloc(size)
    #else
    let p = SDL_malloc(size)
    #endif
    SwGameAssert(p != nil)

    let cookiePtr = p!.assumingMemoryBound(to: UInt32.self)
    cookiePtr[0] = 0x46414345 // 'FACE'
    cookiePtr[1] = UInt32(size)
    cookiePtr[2] = 0x50545233 // 'PTR3'
    cookiePtr[3] = 0x50545234 // 'PTR4'

    gNumPointers += 1
    gRAMAlloced += size

    return p! + PTRCOOKIE_SIZE
}

func AllocPtrClear(_ size0: Int) -> UnsafeMutableRawPointer? {
    SwGameAssert(size0 >= 0)
    SwGameAssert(size0 <= 0x7FFFFFFF)

    let size = size0 + PTRCOOKIE_SIZE // make room for our cookie & whatever else (also keep to 16-byte alignment!)
    #if NANOSAUR_3DS
    let p = calloc(1, size)
    #else
    let p = SDL_calloc(1, size)
    #endif
    SwGameAssert(p != nil)

    let cookiePtr = p!.assumingMemoryBound(to: UInt32.self)
    cookiePtr[0] = 0x46414345 // 'FACE'
    cookiePtr[1] = UInt32(size)
    cookiePtr[2] = 0x50544333 // 'PTC3'
    cookiePtr[3] = 0x50544334 // 'PTC4'

    gNumPointers += 1
    gRAMAlloced += size

    return p! + PTRCOOKIE_SIZE
}

@c @implementation
public func ReallocPtr(_ initialPtr: UnsafeMutableRawPointer?, _ newSize0: Int) -> UnsafeMutableRawPointer? {
    SwGameAssert(newSize0 >= 0)
    SwGameAssert(newSize0 <= 0x7FFFFFFF)

    guard let initialPtr else {
        return AllocPtr(newSize0)
    }

    var p = initialPtr - PTRCOOKIE_SIZE // back up pointer to cookie
    let newSize = newSize0 + PTRCOOKIE_SIZE // make room for our cookie & whatever else (also keep to 16-byte alignment!)

    #if NANOSAUR_3DS
    p = realloc(p, newSize)! // reallocate it
    #else
    p = SDL_realloc(p, newSize)! // reallocate it
    #endif

    let cookiePtr = p.assumingMemoryBound(to: UInt32.self)
    SwGameAssert(cookiePtr[0] == 0x46414345) // realloc shouldn't have touched our cookie ('FACE')

    let initialSize = cookiePtr[1] // update heap size metric
    gRAMAlloced += newSize - Int(initialSize)

    cookiePtr[0] = 0x46414345 // rewrite cookie ('FACE')
    cookiePtr[1] = UInt32(newSize)
    cookiePtr[2] = 0x52454133 // 'REA3'
    cookiePtr[3] = 0x52454134 // 'REA4'

    return p + PTRCOOKIE_SIZE
}

@c @implementation
public func SafeDisposePtr(_ ptr: UnsafeMutableRawPointer?) {
    guard let ptr else {
        return
    }

    let p = ptr - PTRCOOKIE_SIZE // back up to pt to cookie

    let cookiePtr = p.assumingMemoryBound(to: UInt32.self)
    SwGameAssert(cookiePtr[0] == 0x46414345) // 'FACE'
    gRAMAlloced -= Int(cookiePtr[1]) // deduct ptr size from heap size

    cookiePtr[0] = 0x44454144 // zap cookie ('DEAD')

    #if NANOSAUR_3DS
    free(p)
    #else
    SDL_free(p)
    #endif

    gNumPointers -= 1
}

// MARK: - Misc

func VerifySystem() {
}

// This version uses UpTime() which is only available on PCI Macs.
func CalcFramesPerSecond() {
    struct Statics {
        static var time = UnsignedWide()
        static var sampIndex: Int32 = 0
        static var sampleList: [Float] = Array(repeating: 60, count: 16)
    }

    var fps: Float = 0
    var currTime = UnsignedWide()

    while true {
        Microseconds(&currTime)

        if gTimeDemo != 0 {
            fps = 40
            break
        }

        let deltaTime = currTime.lo &- Statics.time.lo

        if deltaTime == 0 {
            fps = DEFAULT_FPS
        } else {
            fps = 1_000_000.0 / Float(deltaTime)

            if fps < DEFAULT_FPS { // (avoid divide by 0's later)
                fps = DEFAULT_FPS
            } else if fps > MAX_FPS { // limit to avoid issue
                if fps - MAX_FPS > 1000 { // try to sneak in some sleep if we have 1 ms to spare
                    #if !NANOSAUR_3DS
                    SDL_Delay(1)
                    #endif
                    // 3DS: no real sleep call available without pulling in
                    // <3ds.h> wholesale (see game_3ds.h's Handle-collision
                    // comment) - just busy-spin instead, matching what
                    // happens here today whenever this branch fires without
                    // 1ms to spare anyway.
                }
                continue
            }
        }

        #if _DEBUG && !NANOSAUR_3DS
        if SwIsKeyDown(Int(SDL_SCANCODE_KP_PLUS.rawValue)) { // debug speed-up with KP_PLUS
            fps = DEFAULT_FPS
        }
        #endif

        break
    }

    // ADD TO LIST
    Statics.sampleList[Int(Statics.sampIndex)] = fps
    Statics.sampIndex += 1
    Statics.sampIndex &= 0x7

    // CALC AVERAGE
    gFramesPerSecond = 0
    for i in 0..<8 {
        gFramesPerSecond += Statics.sampleList[i]
    }
    gFramesPerSecond *= 1.0 / 8.0

    if gFramesPerSecond < DEFAULT_FPS { // (avoid divide by 0's later)
        gFramesPerSecond = DEFAULT_FPS
    }
    gFramesPerSecondFrac = 1.0 / gFramesPerSecond // calc fractional for multiplication

    Statics.time = currTime // reset for next time interval
}

func IsPowerOf2(_ num: Int32) -> UInt8 {
    var i: Int32 = 2
    repeat {
        if i == num { // see if this power of 2 matches
            return 1
        }
        i *= 2 // next power of 2
    } while i <= num // search until power is > number

    return 0
}

func MyFlushEvents() {
}

// MARK: - Swizzling

func SwizzleShort(_ shortPtr: UnsafePointer<Int16>?) -> Int16 {
    Int16(bitPattern: SwizzleUShort(UnsafeRawPointer(shortPtr)?.assumingMemoryBound(to: UInt16.self)))
}

func SwizzleUShort(_ shortPtr: UnsafePointer<UInt16>?) -> UInt16 {
    // The original C used `#if __LITTLE_ENDIAN__`, which Swift's #if can't
    // see (it's a C preprocessor macro, not a Swift compilation condition).
    // All of this project's actual build targets (Apple Silicon/x86_64
    // macOS) are little-endian, so the swap is unconditional here.
    let theShort = shortPtr!.pointee

    let b1 = theShort & 0xff
    let b2 = (theShort & 0xff00) >> 8

    return (b1 << 8) | b2
}

func SwizzleLong(_ longPtr: UnsafePointer<Int32>?) -> Int32 {
    Int32(bitPattern: SwizzleULong(UnsafeRawPointer(longPtr)?.assumingMemoryBound(to: UInt32.self)))
}

func SwizzleULong(_ longPtr: UnsafePointer<UInt32>?) -> UInt32 {
    // See SwizzleUShort: unconditional swap since every real build target
    // of this project is little-endian.
    let theLong = longPtr!.pointee

    let b1 = theLong & 0xff
    let b2 = (theLong & 0xff00) >> 8
    let b3 = (theLong & 0xff0000) >> 16
    let b4 = (theLong & 0xff000000) >> 24

    return (b1 << 24) | (b2 << 16) | (b3 << 8) | b4
}

func SwizzleFloat(_ floatPtr: UnsafePointer<Float>?) -> Float {
    var theLong = SwizzleULong(UnsafeRawPointer(floatPtr)?.assumingMemoryBound(to: UInt32.self))
    return withUnsafePointer(to: &theLong) { $0.withMemoryRebound(to: Float.self, capacity: 1) { $0.pointee } }
}
