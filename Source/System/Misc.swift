// Misc.swift - Port of Misc.c to Swift
//
// DoAlert/DoFatalAlert stay in Misc.c because they take C variadic
// arguments, which Swift can't implement (same reasoning as
// LocalizeWithPlaceholder staying in Localization.c). gEngine.misc.ramAlloced/
// gEngine.framesPerSecond/gEngine.framesPerSecondFrac/gEngine.misc.numPointers are native Swift
// storage now (converted 2026-07-07): nothing in any .c file touches them
// anymore. gEngine.misc.seed0/1/2 aren't `extern`'d anywhere else, so unlike those
// they didn't need this treatment - already private Swift storage.

// Allocator metrics live at file scope, NOT inside MiscSystem: many
// subsystem classes allocate their permanent buffers via AllocPtrClear in
// stored-property initializers, which run while GameEngine itself is being
// constructed - if the allocator touched gEngine.misc, it would re-enter
// gEngine's own lazy-global dispatch_once and trap (EXC_BREAKPOINT in
// _dispatch_once_wait; hit for real on 2026-07-09). The allocators below
// use this storage directly; MiscSystem exposes it as computed properties
// so gEngine.misc.ramAlloced/numPointers still read naturally.
private var gRAMAllocedStorage: Int = 0
private var gNumPointersStorage: Int32 = 0

/// Allocator metrics + RNG seeds. Owned by GameEngine as `gEngine.misc`
/// (fps lives directly on GameEngine - it's the hottest read in the game).
final class MiscSystem {
    var ramAlloced: Int {
        get { gRAMAllocedStorage }
        set { gRAMAllocedStorage = newValue }
    }
    var numPointers: Int32 {
        get { gNumPointersStorage }
        set { gNumPointersStorage = newValue }
    }

    fileprivate var seed0: UInt32 = 0
    fileprivate var seed1: UInt32 = 0
    fileprivate var seed2: UInt32 = 0
}

private let MAX_FPS: Float = 300 // mac original was 190
private let DEFAULT_FPS: Float = 13


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

        if gEngine.game.viewInfoPtr != nil { // see if need to dispose this
            OGL_DisposeGameView()
        }

        OGL_Shutdown()

        ShutdownSound() // cleanup sound stuff
    }

    #if !NANOSAUR_3DS
    SDL_ShowCursor() // no pointer cursor to restore on a 3DS touchscreen
    #endif
    MyFlushEvents()

    SwExitToShell()
}

// MARK: - Random number generator

func MyRandomLong() -> UInt32 {
    gEngine.misc.seed1 ^= (gEngine.misc.seed2 >> 5) &* 1568397607
    gEngine.misc.seed0 = (gEngine.misc.seed0 &+ 1) &* 3141592621
    let sum = (gEngine.misc.seed1 >> 7) &+ gEngine.misc.seed0
    gEngine.misc.seed2 ^= sum &* 2435386481
    return gEngine.misc.seed2
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
    gEngine.misc.seed0 = seed
    gEngine.misc.seed1 = 0
    gEngine.misc.seed2 = 0
}

func InitMyRandomSeed() {
    gEngine.misc.seed0 = 0x2a80ce30
    gEngine.misc.seed1 = 0
    gEngine.misc.seed2 = 0
}

// MARK: - Pointer allocation

private let PTRCOOKIE_SIZE = 16

// Heap-corruption canary cookies written around every AllocPtr/AllocPtrClear/
// ReallocPtr block (see PTRCOOKIE_SIZE). The 3rd/4th words also encode which
// allocator produced the block.
private let kCookieFACE: UInt32 = fourCC("FACE") // live block
private let kCookieDEAD: UInt32 = fourCC("DEAD") // freed block
private let kCookiePTR3: UInt32 = fourCC("PTR3") // AllocPtr
private let kCookiePTR4: UInt32 = fourCC("PTR4")
private let kCookiePTC3: UInt32 = fourCC("PTC3") // AllocPtrClear
private let kCookiePTC4: UInt32 = fourCC("PTC4")
private let kCookieREA3: UInt32 = fourCC("REA3") // ReallocPtr
private let kCookieREA4: UInt32 = fourCC("REA4")

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
    cookiePtr[0] = kCookieFACE
    cookiePtr[1] = UInt32(size)
    cookiePtr[2] = kCookiePTR3
    cookiePtr[3] = kCookiePTR4

    gNumPointersStorage += 1
    gRAMAllocedStorage += size

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
    cookiePtr[0] = kCookieFACE
    cookiePtr[1] = UInt32(size)
    cookiePtr[2] = kCookiePTC3
    cookiePtr[3] = kCookiePTC4

    gNumPointersStorage += 1
    gRAMAllocedStorage += size

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
    SwGameAssert(cookiePtr[0] == kCookieFACE) // realloc shouldn't have touched our cookie

    let initialSize = cookiePtr[1] // update heap size metric
    gRAMAllocedStorage += newSize - Int(initialSize)

    cookiePtr[0] = kCookieFACE // rewrite cookie
    cookiePtr[1] = UInt32(newSize)
    cookiePtr[2] = kCookieREA3
    cookiePtr[3] = kCookieREA4

    return p + PTRCOOKIE_SIZE
}

@c @implementation
public func SafeDisposePtr(_ ptr: UnsafeMutableRawPointer?) {
    guard let ptr else {
        return
    }

    let p = ptr - PTRCOOKIE_SIZE // back up to pt to cookie

    let cookiePtr = p.assumingMemoryBound(to: UInt32.self)
    SwGameAssert(cookiePtr[0] == kCookieFACE)
    gRAMAllocedStorage -= Int(cookiePtr[1]) // deduct ptr size from heap size

    cookiePtr[0] = kCookieDEAD // zap cookie

    #if NANOSAUR_3DS
    free(p)
    #else
    SDL_free(p)
    #endif

    gNumPointersStorage -= 1
}

// MARK: - Time (replaces Pomme's Microseconds/TickCount - see extern/Pomme/src/Time/TimeManager.cpp)
//
// Both are only ever used for relative timing (frame-rate smoothing, level-
// load duration logging, demo-recording elapsed time), always via
// subtraction/wraparound arithmetic, so the exact epoch doesn't matter as
// long as it's monotonic within a single run - SDL's own monotonic clock
// (nanoseconds since SDL_Init, already running well before these are ever
// called) is a fine substitute for Pomme's "static-init time" epoch.

private let gSwBootTimeNS = SDL_GetTicksNS()

// Matches Microseconds(UnsignedWide*)'s signature so call sites don't change.
func SwMicroseconds(_ out: inout UnsignedWide) {
    // Wrapping subtraction: gSwBootTimeNS's lazy initializer runs on this
    // global's first reference, which happens a few nanoseconds *after* the
    // SDL_GetTicksNS() call to its left in this same expression - so the
    // very first call here would otherwise underflow (SDL_GetTicksNS() at
    // init time > the value just captured) and trap.
    let usecs = (SDL_GetTicksNS() &- gSwBootTimeNS) / 1000
    out.lo = UInt32(truncatingIfNeeded: usecs)
    out.hi = UInt32(truncatingIfNeeded: usecs >> 32)
}

// Matches TickCount()'s signature (ticks are ~1/60 sec) so call sites don't change.
func SwTickCount() -> UInt32 {
    // Wrapping subtraction - see SwMicroseconds above for why.
    let usecs = (SDL_GetTicksNS() &- gSwBootTimeNS) / 1000
    return UInt32(truncatingIfNeeded: 60 * usecs / 1_000_000)
}

// MARK: - Misc

func VerifySystem() {
}

// Plain memmove - replaces Pomme's BlockMove (which was just a wrapper
// around it, with 64-bit-clean pointer args).
@c @implementation
public func SwBlockMove(_ srcPtr: UnsafeRawPointer?, _ destPtr: UnsafeMutableRawPointer?, _ byteCount: Int) {
    guard let srcPtr, let destPtr, byteCount > 0 else { return }
    destPtr.copyMemory(from: srcPtr, byteCount: byteCount)
}

// Seconds since the classic Mac epoch (Jan 1 1904) - replaces Pomme's
// GetDateTime, same offset from the UNIX epoch it used
// (extern/Pomme/src/Time/TimeManager.cpp).
private let kMacEpochOffsetFromUnixEpoch: Int64 = -2_082_844_800

@c @implementation
public func SwGetDateTime(_ secs: UnsafeMutablePointer<UInt>?) {
    // SwTimeNow (file.h), not a raw time() call: time_t's spelling differs
    // per platform, and calling time() with the wrong pointer width
    // clobbered this function's stack frame and hung 3DS boot - see the
    // prototype comment in file.h (2026-07-09).
    secs?.pointee = UInt(truncatingIfNeeded: SwTimeNow() + kMacEpochOffsetFromUnixEpoch)
}

// Replaces Pomme's ExitToShell(), which unwound the C++/Swift call stack
// back to Boot.cpp's main() via a thrown Pomme::QuitRequest exception, which
// then fell through to main()'s own post-try/catch call to Shutdown()
// (mouse-acceleration restore, window teardown, SDL_Quit). CleanQuit() above
// already does all of this project's own game-level cleanup before calling
// this, so there's nothing left for an unwind to accomplish - calling
// Boot.cpp's Shutdown() directly (via the SwPlatformShutdown trampoline)
// and then exiting the process is equivalent, without relying on a C++
// exception propagating through Swift stack frames.
@c @implementation
public func SwExitToShell() -> Never {
    SwPlatformShutdown()
    exit(0)
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
        SwMicroseconds(&currTime)

        if gEngine.game.timeDemo != 0 {
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
    gEngine.framesPerSecond = 0
    for i in 0..<8 {
        gEngine.framesPerSecond += Statics.sampleList[i]
    }
    gEngine.framesPerSecond *= 1.0 / 8.0

    if gEngine.framesPerSecond < DEFAULT_FPS { // (avoid divide by 0's later)
        gEngine.framesPerSecond = DEFAULT_FPS
    }
    gEngine.framesPerSecondFrac = 1.0 / gEngine.framesPerSecond // calc fractional for multiplication

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
