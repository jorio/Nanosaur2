// SplineManager.swift - Port of SplineManager.c to Swift
//
// This is not code for the terrain splines! This does other custom spline management.
//
// gCustomSplines is native Swift storage now (converted 2026-07-07):
// nothing in any .c file touches it anymore. It was a fixed-size C array
// exposed via SplineManagerInternal.h's GetCustomSplineSlot shim; it's now
// a permanent, never-freed UnsafeMutablePointer buffer, with the accessor
// reimplemented in plain Swift under the same name/signature so its call
// sites in Terrain.swift/Holes.swift didn't need to change.

private let gCustomSplinesBuf: UnsafeMutablePointer<CustomSplineType> = {
    let buf = UnsafeMutablePointer<CustomSplineType>.allocate(capacity: 40)
    buf.initialize(repeating: CustomSplineType(), count: 40)
    return buf
}()
func GetCustomSplineSlot(_ i: Int32) -> UnsafeMutablePointer<CustomSplineType> {
    gCustomSplinesBuf + Int(i)
}

extension UnsafeMutablePointer where Pointee == CustomSplineType {
    var isUsed: Bool {
        get { pointee.isUsed != 0 }
        nonmutating set { pointee.isUsed = newValue ? 1 : 0 }
    }
}

func InitSplineManager() {
    for i in 0..<Int32(MAX_CUSTOM_SPLINES) {
        let slot = GetCustomSplineSlot(i)
        slot.isUsed = false
        slot.pointee.numPoints = 0
        slot.pointee.splinePoints = nil
    }
}

func FreeAllCustomSplines() {
    for i in 0..<Int16(MAX_CUSTOM_SPLINES) {
        FreeACustomSpline(i)
    }
}

func FreeACustomSpline(_ splineNum: Int16) {
    let slot = GetCustomSplineSlot(Int32(splineNum))
    if slot.isUsed {
        SafeDisposePtr(slot.pointee.splinePoints)
        slot.pointee.splinePoints = nil
        slot.isUsed = false
    }
}

func GenerateCustomSpline(_ numNubs: Int16, _ nubPoints: UnsafeMutablePointer<OGLPoint3D>, _ pointsPerSpan: Int) -> Int16 {
    // FIND FREE SLOT
    var slot: Int32 = 0
    while slot < Int32(MAX_CUSTOM_SPLINES) {
        if !GetCustomSplineSlot(slot).isUsed {
            break
        }
        slot += 1
    }
    if slot >= Int32(MAX_CUSTOM_SPLINES) {
        return -1
    }

    let splineSlot = GetCustomSplineSlot(slot)
    splineSlot.isUsed = true

    // ALLOCATE 2D ARRAY FOR CALCULATIONS: 8 rows of numNubs OGLPoint3D each
    let n = Int(numNubs)
    let flat = AllocPtrClear(MemoryLayout<OGLPoint3D>.size * 8 * n)!.assumingMemoryBound(to: OGLPoint3D.self)
    var space: InlineArray<8, UnsafeMutablePointer<OGLPoint3D>> = InlineArray(repeating: flat)
    for i in 1..<8 {
        space[i] = space[i - 1] + n
    }

    // ALLOC POINT ARRAY
    let maxPoints = pointsPerSpan * n
    let splinePoints = AllocPtrClear(MemoryLayout<OGLPoint3D>.size * maxPoints)!.assumingMemoryBound(to: OGLPoint3D.self)
    splineSlot.pointee.splinePoints = splinePoints

    // DO MAGICAL CUBIC SPLINE CALCULATIONS ON CONTROL PTS

    let h0 = space[0]
    let h1 = space[1]
    let h2 = space[2]
    let h3 = space[3]

    var a = space[4]
    var b = space[5]
    var c = space[6]
    var d = space[7]

    // COPY CONTROL POINTS INTO ARRAY
    for i in 0..<n {
        d[i] = nubPoints[i]
    }

    let imax0 = n - 2
    for i in 0..<imax0 {
        h2[i].x = 1; h2[i].y = 1; h2[i].z = 1
        h3[i].x = 3 * (d[i + 2].x - 2 * d[i + 1].x + d[i].x)
        h3[i].y = 3 * (d[i + 2].y - 2 * d[i + 1].y + d[i].y)
        h3[i].z = 3 * (d[i + 2].z - 2 * d[i + 1].z + d[i].z)
    }
    h2[n - 3].x = 0; h2[n - 3].z = 0

    a[0].x = 4; a[0].y = 4; a[0].z = 4
    h1[0].x = h3[0].x / a[0].x
    h1[0].y = h3[0].y / a[0].y
    h1[0].z = h3[0].z / a[0].z

    var i1 = 0
    let imax1 = n - 2
    var i = 1
    while i < imax1 {
        h0[i1].x = h2[i1].x / a[i1].x
        a[i].x = 4.0 - h0[i1].x
        h1[i].x = (h3[i].x - h1[i1].x) / a[i].x

        h0[i1].y = h2[i1].y / a[i1].y
        a[i].y = 4.0 - h0[i1].y
        h1[i].y = (h3[i].y - h1[i1].y) / a[i].y

        h0[i1].z = h2[i1].z / a[i1].z
        a[i].z = 4.0 - h0[i1].z
        h1[i].z = (h3[i].z - h1[i1].z) / a[i].z

        i += 1; i1 += 1
    }

    b[n - 3] = h1[n - 3]

    i = n - 4
    while i >= 0 {
        b[i].x = h1[i].x - h0[i].x * b[i + 1].x
        b[i].y = h1[i].y - h0[i].y * b[i + 1].y
        b[i].z = h1[i].z - h0[i].z * b[i + 1].z
        i -= 1
    }

    i = n - 2
    while i >= 1 {
        b[i] = b[i - 1]
        i -= 1
    }

    b[0].x = 0; b[n - 1].x = 0
    b[0].y = 0; b[n - 1].y = 0
    b[0].z = 0; b[n - 1].z = 0
    let hiA = a + (n - 1)

    while a < hiA {
        c.pointee.x = (d + 1).pointee.x - d.pointee.x - (2.0 * b.pointee.x + (b + 1).pointee.x) * (1.0 / 3.0)
        a.pointee.x = ((b + 1).pointee.x - b.pointee.x) * (1.0 / 3.0)

        c.pointee.y = (d + 1).pointee.y - d.pointee.y - (2.0 * b.pointee.y + (b + 1).pointee.y) * (1.0 / 3.0)
        a.pointee.y = ((b + 1).pointee.y - b.pointee.y) * (1.0 / 3.0)

        c.pointee.z = (d + 1).pointee.z - d.pointee.z - (2.0 * b.pointee.z + (b + 1).pointee.z) * (1.0 / 3.0)
        a.pointee.z = ((b + 1).pointee.z - b.pointee.z) * (1.0 / 3.0)

        a += 1; b += 1; c += 1; d += 1
    }

    // NOW CALCULATE THE SPLINE POINTS

    a = space[4]
    b = space[5]
    c = space[6]
    d = space[7]

    var numPoints = 0
    while a < hiA {
        // CALC THIS SPAN
        let dt = Float(1.0) / Float(pointsPerSpan)
        var t: Float = 0
        while t < (1.0 - Float(EPS)) {
            if numPoints >= maxPoints { // see if overflow
                SwFatal("GenerateCustomSpline: numPoints >= maxPoints")
            }

            splinePoints[numPoints].x = ((a.pointee.x * t + b.pointee.x) * t + c.pointee.x) * t + d.pointee.x
            splinePoints[numPoints].y = ((a.pointee.y * t + b.pointee.y) * t + c.pointee.y) * t + d.pointee.y
            splinePoints[numPoints].z = ((a.pointee.z * t + b.pointee.z) * t + c.pointee.z) * t + d.pointee.z

            numPoints += 1
            t += dt
        }
        a += 1; b += 1; c += 1; d += 1
    }

    // END

    splineSlot.pointee.numPoints = Int(numPoints)

    // Free_2d_array(space): free the flat backing buffer (the row-pointer
    // array itself is a native Swift array, no manual free needed for it)
    SafeDisposePtr(flat)

    return Int16(slot)
}
