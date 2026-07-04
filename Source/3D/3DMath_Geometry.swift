// 3DMath_Geometry.swift - Port of the remaining geometry/vector/plane functions
// (and fast trig approximations) in 3DMath.c to Swift.
// (Third and final file splitting up 3DMath.c's large function set.)

private let VectorComponent_X: Int32 = 0
private let VectorComponent_Y: Int32 = 1
private let VectorComponent_Z: Int32 = 2

// MARK: - Intersect plane & line segment
//
// Returns true if the input line segment intersects the plane.

@c @implementation
public func IntersectionOfLineSegAndPlane(_ plane: UnsafePointer<OGLPlaneEquation>!, _ v1x: Float, _ v1y: Float, _ v1z: Float, _ v2x: Float, _ v2y: Float, _ v2z: Float, _ outPoint: UnsafeMutablePointer<OGLPoint3D>!) -> UInt8 {
    let nx = plane.pointee.normal.x
    let ny = plane.pointee.normal.y
    let nz = plane.pointee.normal.z
    let planeConst = plane.pointee.constant

    // DETERMINE SIDENESS OF VERT1

    var r = -planeConst
    r += (nx * v1x) + (ny * v1y) + (nz * v1z)
    let a = (r < 0.0) ? 1 : 0

    // DETERMINE SIDENESS OF VERT2

    r = -planeConst
    r += (nx * v2x) + (ny * v2y) + (nz * v2z)
    let b = (r < 0.0) ? 1 : 0

    // SEE IF LINE CROSSES PLANE (INTERSECTS)

    if a == b {
        return 0
    }

    // LINE INTERSECTS, SO CALCULATE INTERSECTION POINT

    // CALC LINE SEGMENT VECTOR BA

    let vBAx = v2x - v1x
    let vBAy = v2y - v1y
    let vBAz = v2z - v1z

    // DOT OF PLANE NORMAL & LINE SEGMENT VECTOR

    let dot = (nx * vBAx) + (ny * vBAy) + (nz * vBAz)

    // IF VALID, CALC INTERSECTION POINT

    if dot != 0 {
        var lam = planeConst
        lam -= (nx * v1x) + (ny * v1y) + (nz * v1z) // calc dot product of plane normal & 1st vertex
        lam /= dot // div by previous dot for scaling factor

        outPoint.pointee.x = v1x + (lam * vBAx) // calc intersect point
        outPoint.pointee.y = v1y + (lam * vBAy)
        outPoint.pointee.z = v1z + (lam * vBAz)
        return 1
    }

    // IF DOT == 0, THEN LINE IS PARALLEL TO PLANE THUS NO INTERSECTION

    return 0
}

// MARK: - Intersection of Y and plane function
//
// INPUT:
//			x/z		:	xz coords of point
//			p		:	ptr to the plane
//
// *** IMPORTANT-->  This function does not check for divides by 0!! As such, there should be no
//					"vertical" polygons (polys with normal->y == 0).

@c @implementation
public func IntersectionOfYAndPlane_Func(_ x: Float, _ z: Float, _ p: UnsafePointer<OGLPlaneEquation>!) -> Float {
    (p.pointee.constant - ((p.pointee.normal.x * x) + (p.pointee.normal.z * z))) / p.pointee.normal.y
}

// MARK: - Calc vector length

@c @implementation
public func CalcVectorLength(_ v: UnsafeMutablePointer<OGLVector3D>!) -> Float {
    let d = (v.pointee.x * v.pointee.x) + (v.pointee.y * v.pointee.y) + (v.pointee.z * v.pointee.z)
    return sqrt(d)
}

// MARK: - Calc vector length 2D

@c @implementation
public func CalcVectorLength2D(_ v: UnsafePointer<OGLVector2D>!) -> Float {
    let d = (v.pointee.x * v.pointee.x) + (v.pointee.y * v.pointee.y)
    return sqrt(d)
}

// MARK: - Apply friction to deltas
//
// INPUT: speed = precalculated length of d vector.

@c @implementation
public func ApplyFrictionToDeltas(_ fIn: Float, _ d: UnsafeMutablePointer<OGLVector3D>!) {
    let f = fIn * gFramesPerSecondFrac

    let speed = sqrt((d.pointee.y * d.pointee.y) + (d.pointee.x * d.pointee.x) + (d.pointee.z * d.pointee.z)) // calc length of vector

    if speed <= Float(EPS) { // avoid divides by 0
        d.pointee.x = 0
        d.pointee.y = 0
        d.pointee.z = 0
        return
    }

    let newSpeed = speed - f // calc target speed by reducing vector length value
    if newSpeed < 0.0 {
        d.pointee.x = 0
        d.pointee.y = 0
        d.pointee.z = 0
        return
    }

    let ratio = newSpeed / speed // calc ratio of new to old

    d.pointee.x *= ratio // reduce deltas by ratio
    d.pointee.y *= ratio
    d.pointee.z *= ratio
}

// MARK: - Apply friction to deltas XZ
//
// INPUT: speed = precalculated length of d vector.

@c @implementation
public func ApplyFrictionToDeltasXZ(_ fIn: Float, _ d: UnsafeMutablePointer<OGLVector3D>!) {
    let f = fIn * gFramesPerSecondFrac

    let speed = sqrt((d.pointee.z * d.pointee.z) + (d.pointee.x * d.pointee.x)) // calc length of vector

    if speed <= Float(EPS) { // avoid divides by 0
        d.pointee.x = 0
        d.pointee.z = 0
        return
    }

    let newSpeed = speed - f // calc target speed by reducing vector length value
    if newSpeed < 0.0 {
        d.pointee.x = 0
        d.pointee.z = 0
        return
    }

    let ratio = newSpeed / speed // calc ratio of new to old

    d.pointee.x *= ratio // reduce deltas by ratio
    d.pointee.z *= ratio
}

// MARK: - Apply friction to rotation

@c @implementation
public func ApplyFrictionToRotation(_ fIn: Float, _ d: UnsafeMutablePointer<OGLVector3D>!) {
    let f = fIn * gFramesPerSecondFrac

    var dx = d.pointee.x
    var dy = d.pointee.y
    var dz = d.pointee.z

    // dx

    if dx < 0.0 {
        dx += f
        if dx > 0.0 {
            dx = 0
        }
    } else if dx > 0.0 {
        dx -= f
        if dx < 0.0 {
            dx = 0
        }
    }

    // dY

    if dy < 0.0 {
        dy += f
        if dy > 0.0 {
            dy = 0
        }
    } else if dy > 0.0 {
        dy -= f
        if dy < 0.0 {
            dy = 0
        }
    }

    // dz

    if dz < 0.0 {
        dz += f
        if dz > 0.0 {
            dz = 0
        }
    } else if dz > 0.0 {
        dz -= f
        if dz < 0.0 {
            dz = 0
        }
    }

    d.pointee.x = dx
    d.pointee.y = dy
    d.pointee.z = dz
}

// MARK: -

// MARK: - Is point in triangle 3D
//
// INPUT:	point3D			= the point to test
//			trianglePoints	= triangle's 3 points
//			normal			= triangle's normal

@c @implementation
public func IsPointInTriangle3D(_ point3D: UnsafePointer<OGLPoint3D>!, _ trianglePoints: UnsafePointer<OGLPoint3D>!, _ normal: UnsafeMutablePointer<OGLVector3D>!) -> UInt8 {
    let maximalComponent: Int32

    // DETERMINE LONGEST COMPONENT OF NORMAL

    let xComp = abs(normal.pointee.x)
    let yComp = abs(normal.pointee.y)
    let zComp = abs(normal.pointee.z)

    if xComp > yComp {
        maximalComponent = xComp > zComp ? VectorComponent_X : VectorComponent_Z
    } else {
        maximalComponent = yComp > zComp ? VectorComponent_Y : VectorComponent_Z
    }

    // PROJECT 3D POINTS TO 2D

    let pX: Float
    let pY: Float
    let verts0x: Float
    let verts0y: Float
    let verts1x: Float
    let verts1y: Float
    let verts2x: Float
    let verts2y: Float

    switch maximalComponent {
    case VectorComponent_X:
        pX = point3D.pointee.y
        pY = point3D.pointee.z

        verts0x = trianglePoints[0].y
        verts0y = trianglePoints[0].z

        verts1x = trianglePoints[1].y
        verts1y = trianglePoints[1].z

        verts2x = trianglePoints[2].y
        verts2y = trianglePoints[2].z

    case VectorComponent_Y:
        pX = point3D.pointee.z
        pY = point3D.pointee.x

        verts0x = trianglePoints[0].z
        verts0y = trianglePoints[0].x

        verts1x = trianglePoints[1].z
        verts1y = trianglePoints[1].x

        verts2x = trianglePoints[2].z
        verts2y = trianglePoints[2].x

    case VectorComponent_Z:
        pX = point3D.pointee.x
        pY = point3D.pointee.y

        verts0x = trianglePoints[0].x
        verts0y = trianglePoints[0].y

        verts1x = trianglePoints[1].x
        verts1y = trianglePoints[1].y

        verts2x = trianglePoints[2].x
        verts2y = trianglePoints[2].y

    default:
        return 0
    }

    // NOW DO 2D POINT-IN-TRIANGLE CHECK

    return IsPointInTriangle(pX, pY, verts0x, verts0y, verts1x, verts1y, verts2x, verts2y)
}

// MARK: -

// MARK: - Intersect line segments
//
// OUTPUT: x,y = coords of intersection
//			true = yes, intersection occured

@c @implementation
public func IntersectLineSegments(_ x1: Float, _ y1: Float, _ x2: Float, _ y2: Float,
                                   _ x3: Float, _ y3: Float, _ x4: Float, _ y4: Float,
                                   _ x: UnsafeMutablePointer<Float>!, _ y: UnsafeMutablePointer<Float>!) -> UInt8 {
    var max1: Float
    var min1: Float
    var max2: Float
    var min2: Float

    // DO BOUNDING BOX CHECK FOR QUICK ELIMINATION

    // SEE IF HORIZ OUT OF BOUNDS

    if x1 > x2 {
        max1 = x1
        min1 = x2
    } else {
        max1 = x2
        min1 = x1
    }

    if x3 < x4 {
        min2 = x3
        max2 = x4
    } else {
        min2 = x4
        max2 = x3
    }

    if max1 < min2 {
        return 0
    }
    if min1 > max2 {
        return 0
    }

    // SEE IF VERT OUT OF BOUNDS

    if y1 > y2 {
        max1 = y1
        min1 = y2
    } else {
        max1 = y2
        min1 = y1
    }

    if y3 < y4 {
        min2 = y3
        max2 = y4
    } else {
        min2 = y4
        max2 = y3
    }

    if max1 < min2 {
        return 0
    }
    if min1 > max2 {
        return 0
    }

    // Compute a1, b1, c1, where line joining points 1 and 2
    // is "a1 x  +  b1 y  +  c1  =  0".

    let a1 = y2 - y1
    let b1 = x1 - x2
    let c1 = (x2 * y1) - (x1 * y2)

    // Compute r3 and r4.

    let r3 = Int32((a1 * x3) + (b1 * y3) + c1)
    let r4 = Int32((a1 * x4) + (b1 * y4) + c1)

    // Check signs of r3 and r4.  If both point 3 and point 4 lie on
    // same side of line 1, the line segments do not intersect.

    if r3 != 0 && r4 != 0 && ((r3 ^ r4) & Int32(bitPattern: 0x8000_0000)) == 0 {
        return 0
    }

    // Compute a2, b2, c2

    let a2 = y4 - y3
    let b2 = x3 - x4
    let c2 = x4 * y3 - x3 * y4

    // Compute r1 and r2

    let r1 = Int32(a2 * x1 + b2 * y1 + c2)
    let r2 = Int32(a2 * x2 + b2 * y2 + c2)

    // Check signs of r1 and r2.  If both point 1 and point 2 lie
    // on same side of second line segment, the line segments do
    // not intersect.

    if r1 != 0 && r2 != 0 && ((r1 ^ r2) & Int32(bitPattern: 0x8000_0000)) == 0 {
        return 0
    }

    // Line segments intersect: compute intersection point.

    var denom = (a1 * b2) - (a2 * b1)
    if denom == 0.0 {
        x.pointee = x1
        y.pointee = y1
        return 1 // collinear
    }

    let offset = denom < 0.0 ? -denom * 0.5 : denom * 0.5

    // The denom/2 is to get rounding instead of truncating.  It
    // is added or subtracted to the numerator, depending upon the
    // sign of the numerator.

    if denom != 0.0 {
        denom = 1.0 / denom
    }

    var num = b1 * c2 - b2 * c1
    x.pointee = (num < 0 ? num - offset : num + offset) * denom

    num = a2 * c1 - a1 * c2
    y.pointee = (num < 0 ? num - offset : num + offset) * denom

    return 1
}

// MARK: - Calc line normal 2D
//
// INPUT: 	p0, p1 = 2 points on the line
//			px,py = point used to determine which way we want the normal aiming
//
// OUTPUT:	normal = normal to the line

@c @implementation
public func CalcLineNormal2D(_ p0x: Float, _ p0y: Float, _ p1x: Float, _ p1y: Float,
                              _ px: Float, _ py: Float, _ normal: UnsafeMutablePointer<OGLVector2D>!) {
    var normalA = OGLVector2D()
    var normalB = OGLVector2D()

    // CALC NORMALIZED VECTOR FROM ENDPOINT TO ENDPOINT

    FastNormalizeVector2D(p0x - p1x, p0y - p1y, &normalA, 0)

    // CALC NORMALIZED VECTOR FROM REF POINT TO ENDPOINT 0

    FastNormalizeVector2D(px - p0x, py - p0y, &normalB, 0)

    let temp = -((normalB.x * normalA.y) - (normalA.x * normalB.y))
    let x = -(temp * normalA.y)
    let y = normalA.x * temp

    FastNormalizeVector2D(x, y, normal, 0) // normalize the result
}

// MARK: - Calc ray normal 2D
//
// INPUT: 	vec = normalized vector of ray
//			p0 = ray origin
//			px,py = point used to determine which way we want the normal aiming
//
// OUTPUT:	TRUE = valid normal, FALSE = could not calculate
//			normal = normal to the line

@c @implementation
public func CalcRayNormal2D(_ vec: UnsafePointer<OGLVector2D>!, _ p0x: Float, _ p0y: Float,
                             _ px: Float, _ py: Float, _ normal: UnsafeMutablePointer<OGLVector2D>!) -> UInt8 {
    var v = OGLVector3D()

    // CALC NORMALIZED VECTOR FROM ENDPOINT 0 TO REF POINT

    normal.pointee.x = px - p0x
    normal.pointee.y = py - p0y
    OGLVector2D_Normalize(normal, normal)

    // CALC CROSS PRODUCT TO DETERMINE WHICH SIDE WE'RE ON

    var vecVar = vec.pointee
    let cross = OGLVector2D_Cross(&vecVar, normal)

    let up: Float = cross >= 0.0 ? 1 : -1

    v.x = vec.pointee.x
    v.z = vec.pointee.y

    // CALC 3D CROSS PRODUCT (ELIMINATING 0'S) TO GET PERP VECTOR

    normal.pointee.x = -up * v.z
    normal.pointee.y = v.x * up
    OGLVector2D_Normalize(normal, normal)

    if abs(normal.pointee.x) < Float(EPS) && abs(normal.pointee.y) < Float(EPS) { // verify vector is valid
        return 0
    } else {
        return 1
    }
}

// MARK: - Reflect vector 2D
//
// NOTE:	This preserves the magnitude of the input vector.
//
// INPUT:	theVector = vector to reflect (not normalized)
//			N 		  = normal to reflect around (normalized)
//
// OUTPUT:	theVector = reflected vector, scaled to magnitude of original

@c @implementation
public func ReflectVector2D(_ theVector: UnsafeMutablePointer<OGLVector2D>!, _ N: UnsafePointer<OGLVector2D>!, _ outVec: UnsafeMutablePointer<OGLVector2D>!) {
    var x = theVector.pointee.x
    var y = theVector.pointee.y

    // CALC LENGTH AND NORMALIZE INPUT VECTOR

    let mag = sqrt(x * x + y * y) // calc magnitude of input vector;
    let oneOverM: Float = mag > Float(EPS) ? 1.0 / mag : 0
    x *= oneOverM // normalize
    y *= oneOverM

    let normalX = N.pointee.x
    let normalY = N.pointee.y

    // compute NxV
    var dotProduct = normalX * x
    dotProduct += normalY * y

    // compute 2(NxV)
    dotProduct += dotProduct

    // compute final vector
    let reflectedX = normalX * dotProduct - x
    let reflectedY = normalY * dotProduct - y

    // Normalize the result

    outVec.pointee.x = reflectedX
    outVec.pointee.y = reflectedY
    OGLVector2D_Normalize(outVec, outVec)

    // SCALE TO ORIGINAL MAGNITUDE

    outVec.pointee.x *= -mag
    outVec.pointee.y *= -mag
}

// MARK: - Reflect vector 3D
//
// compute reflection vector
// which is N(2(N.V)) - V
// N - Surface Normal
// vec = vector aiming at the normal.

@c @implementation
public func ReflectVector3D(_ vec: UnsafePointer<OGLVector3D>!, _ N: UnsafeMutablePointer<OGLVector3D>!, _ out: UnsafeMutablePointer<OGLVector3D>!) {
    let normalX = N.pointee.x
    let normalY = N.pointee.y
    let normalZ = N.pointee.z

    let vx = -vec.pointee.x // we need the vector to be from normal away, so we invert it
    let vy = -vec.pointee.y
    let vz = -vec.pointee.z

    // compute NxV
    var dotProduct = normalX * vx
    dotProduct += normalY * vy
    dotProduct += normalZ * vz

    // compute 2(NxV)
    dotProduct += dotProduct

    // compute final vector
    let reflectedX = normalX * dotProduct - vx
    let reflectedY = normalY * dotProduct - vy
    let reflectedZ = normalZ * dotProduct - vz

    // Normalize the result

    FastNormalizeVector(reflectedX, reflectedY, reflectedZ, out)
}

// MARK: -

// MARK: - OGL point 3D: transform

@c @implementation
public func OGLPoint3D_Transform(_ point3D: UnsafePointer<OGLPoint3D>!, _ matrix4x4: UnsafePointer<OGLMatrix4x4>!, _ result: UnsafeMutablePointer<OGLPoint3D>!) {
    var s = OGLPoint3D()
    let sPtr: UnsafePointer<OGLPoint3D>

    if UnsafeRawPointer(point3D) == UnsafeRawPointer(result) {
        s = point3D.pointee
        sPtr = withUnsafePointer(to: &s) { $0 }
    } else {
        sPtr = point3D
    }

    var m = matrix4x4.pointee

    result.pointee.x = sPtr.pointee.x * matValue(&m, M00) +
        sPtr.pointee.y * matValue(&m, M01) +
        sPtr.pointee.z * matValue(&m, M02) +
        matValue(&m, M03)

    result.pointee.y = sPtr.pointee.x * matValue(&m, M10) +
        sPtr.pointee.y * matValue(&m, M11) +
        sPtr.pointee.z * matValue(&m, M12) +
        matValue(&m, M13)

    result.pointee.z = sPtr.pointee.x * matValue(&m, M20) +
        sPtr.pointee.y * matValue(&m, M21) +
        sPtr.pointee.z * matValue(&m, M22) +
        matValue(&m, M23)

    let w = sPtr.pointee.x * matValue(&m, M30) +
        sPtr.pointee.y * matValue(&m, M31) +
        sPtr.pointee.z * matValue(&m, M32) +
        matValue(&m, M33)

    let inverseW = 1.0 / w

    result.pointee.x *= inverseW
    result.pointee.y *= inverseW
    result.pointee.z *= inverseW
}

// MARK: -

// MARK: - OGL: point 2D transform

@c @implementation
public func OGLPoint2D_Transform(_ p: UnsafeMutablePointer<OGLPoint2D>!, _ m: UnsafePointer<OGLMatrix3x3>!, _ result: UnsafeMutablePointer<OGLPoint2D>!) {
    var mVar = m.pointee
    let newx = (p.pointee.x * mat3Value(&mVar, N00)) + (p.pointee.y * mat3Value(&mVar, N01)) + mat3Value(&mVar, N02)
    let newy = (p.pointee.x * mat3Value(&mVar, N10)) + (p.pointee.y * mat3Value(&mVar, N11)) + mat3Value(&mVar, N12)
    let neww = (p.pointee.x * mat3Value(&mVar, N20)) + (p.pointee.y * mat3Value(&mVar, N21)) + mat3Value(&mVar, N22)

    if neww == 1.0 {
        result.pointee.x = newx
        result.pointee.y = newy
    } else {
        let invw = 1.0 / neww
        result.pointee.x = newx * invw
        result.pointee.y = newy * invw
    }
}

// MARK: - OGL vector 2D transform

@c @implementation
public func OGLVector2D_Transform(_ vector2D: UnsafePointer<OGLVector2D>!, _ matrix3x3: UnsafePointer<OGLMatrix3x3>!, _ result: UnsafeMutablePointer<OGLVector2D>!) {
    var s = OGLVector2D()
    let sPtr: UnsafePointer<OGLVector2D>

    if UnsafeRawPointer(vector2D) == UnsafeRawPointer(result) {
        s = vector2D.pointee
        sPtr = withUnsafePointer(to: &s) { $0 }
    } else {
        sPtr = vector2D
    }

    var m = matrix3x3.pointee

    result.pointee.x = sPtr.pointee.x * mat3Value(&m, N00) +
        sPtr.pointee.y * mat3Value(&m, N01)

    result.pointee.y = sPtr.pointee.x * mat3Value(&m, N10) +
        sPtr.pointee.y * mat3Value(&m, N11)
}

// MARK: - OGLVector3D dot

@c @implementation
public func OGLVector3D_Dot(_ v1: UnsafePointer<OGLVector3D>!, _ v2: UnsafePointer<OGLVector3D>!) -> Float {
    var dot = (v1.pointee.x * v2.pointee.x) + (v1.pointee.y * v2.pointee.y) + (v1.pointee.z * v2.pointee.z) // calc dot

    // CHECK FOR FLOATING POINT PRECISION PROBLEMS
    //
    // Since the acos of anything >1.0 is a NaN, lets be careful
    // that we return something valid!

    if dot > 1.0 {
        dot = 1.0
    } else if dot < -1.0 {
        dot = -1.0
    }

    return dot
}

// MARK: - Vector 2D dot
//
// 0.0 == perpendicular, 1.0 = parallel

@c @implementation
public func OGLVector2D_Dot(_ v1: UnsafePointer<OGLVector2D>!, _ v2: UnsafePointer<OGLVector2D>!) -> Float {
    var dot = v1.pointee.x * v2.pointee.x + v1.pointee.y * v2.pointee.y

    // CHECK FOR FLOATING POINT PRECISION PROBLEMS
    //
    // Since the acos of anything >1.0 is a NaN, lets be careful
    // that we return something valid!

    if dot > 1.0 {
        dot = 1.0
    } else if dot < -1.0 {
        dot = -1.0
    }

    return dot
}

// MARK: - Vector 3D normalize

@c @implementation
public func OGLVector3D_Normalize(_ vector3D: UnsafePointer<OGLVector3D>!, _ result: UnsafeMutablePointer<OGLVector3D>!) {
    var length = (vector3D.pointee.x * vector3D.pointee.x) +
        (vector3D.pointee.y * vector3D.pointee.y) +
        (vector3D.pointee.z * vector3D.pointee.z)

    length = sqrt(length)

    //  Check for zero-length vector

    if length <= Float(EPS) {
        result.pointee.x = 0
        result.pointee.y = 0
        result.pointee.z = 0
    } else {
        let oneOverLength = 1.0 / length

        let x = vector3D.pointee.x * oneOverLength
        let y = vector3D.pointee.y * oneOverLength
        let z = vector3D.pointee.z * oneOverLength
        result.pointee.x = x
        result.pointee.y = y
        result.pointee.z = z
    }
}

// MARK: - Vector 2D normalize

@c @implementation
public func OGLVector2D_Normalize(_ vector2D: UnsafePointer<OGLVector2D>!, _ result: UnsafeMutablePointer<OGLVector2D>!) {
    var length = (vector2D.pointee.x * vector2D.pointee.x) + (vector2D.pointee.y * vector2D.pointee.y)

    length = sqrt(length)

    //  Check for zero-length vector

    if length <= Float(EPS) {
        result.pointee.x = 0
        result.pointee.y = 0
    } else {
        let oneOverLength = 1.0 / length

        let x = vector2D.pointee.x * oneOverLength
        let y = vector2D.pointee.y * oneOverLength
        result.pointee.x = x
        result.pointee.y = y
    }
}

// MARK: - Vector 3D cross

@c @implementation
public func OGLVector3D_Cross(_ v1: UnsafePointer<OGLVector3D>!, _ v2: UnsafePointer<OGLVector3D>!, _ result: UnsafeMutablePointer<OGLVector3D>!) {
    var s1 = OGLVector3D()
    var s2 = OGLVector3D()
    var temp = OGLVector3D()

    let s1Ptr: UnsafePointer<OGLVector3D>
    let s2Ptr: UnsafePointer<OGLVector3D>

    if UnsafeRawPointer(v1) == UnsafeRawPointer(result) {
        s1 = v1.pointee
        s1Ptr = withUnsafePointer(to: &s1) { $0 }
    } else {
        s1Ptr = v1
    }

    if UnsafeRawPointer(v2) == UnsafeRawPointer(result) {
        s2 = v2.pointee
        s2Ptr = withUnsafePointer(to: &s2) { $0 }
    } else {
        s2Ptr = v2
    }

    temp.x = s1Ptr.pointee.y * s2Ptr.pointee.z - s2Ptr.pointee.y * s1Ptr.pointee.z
    temp.y = s2Ptr.pointee.x * s1Ptr.pointee.z - s1Ptr.pointee.x * s2Ptr.pointee.z
    temp.z = s1Ptr.pointee.x * s2Ptr.pointee.y - s2Ptr.pointee.x * s1Ptr.pointee.y

    OGLVector3D_Normalize(&temp, result)
}

// MARK: - Vector 3D transform

@c @implementation
public func OGLVector3D_Transform(_ vector3D: UnsafePointer<OGLVector3D>!, _ matrix4x4: UnsafePointer<OGLMatrix4x4>!, _ result: UnsafeMutablePointer<OGLVector3D>!) {
    var s = OGLVector3D()
    let sPtr: UnsafePointer<OGLVector3D>

    // SEE IF VECTOR BASHING

    if UnsafeRawPointer(vector3D) == UnsafeRawPointer(result) {
        s = vector3D.pointee
        sPtr = withUnsafePointer(to: &s) { $0 }
    } else {
        sPtr = vector3D
    }

    // TRANSFORM IT

    var m = matrix4x4.pointee

    result.pointee.x = sPtr.pointee.x * matValue(&m, M00) +
        sPtr.pointee.y * matValue(&m, M01) +
        sPtr.pointee.z * matValue(&m, M02)

    result.pointee.y = sPtr.pointee.x * matValue(&m, M10) +
        sPtr.pointee.y * matValue(&m, M11) +
        sPtr.pointee.z * matValue(&m, M12)

    result.pointee.z = sPtr.pointee.x * matValue(&m, M20) +
        sPtr.pointee.y * matValue(&m, M21) +
        sPtr.pointee.z * matValue(&m, M22)

    // NORMALIZE IT

    OGLVector3D_Normalize(result, result)
}

// MARK: - Vector 3D transform array

@c @implementation
public func OGLVector3D_TransformArray(_ inVectors: UnsafePointer<OGLVector3D>!, _ m: UnsafePointer<OGLMatrix4x4>!, _ outVectors: UnsafeMutablePointer<OGLVector3D>!, _ numVectors: Int32) {
    var mVar = m.pointee
    let m00 = matValue(&mVar, M00); let m01 = matValue(&mVar, M01); let m02 = matValue(&mVar, M02)
    let m10 = matValue(&mVar, M10); let m11 = matValue(&mVar, M11); let m12 = matValue(&mVar, M12)
    let m20 = matValue(&mVar, M20); let m21 = matValue(&mVar, M21); let m22 = matValue(&mVar, M22)

    for i in 0..<Int(numVectors) {
        let x = inVectors[i].x
        let y = inVectors[i].y
        let z = inVectors[i].z

        // TRANSFORM IT

        var accum = x * m00
        accum += y * m01
        outVectors[i].x = accum + z * m02

        accum = x * m10
        accum += y * m11
        outVectors[i].y = accum + z * m12

        accum = x * m20
        accum += y * m21
        outVectors[i].z = accum + z * m22

        // NORMALIZE IT

        OGLVector3D_Normalize(&outVectors[i], &outVectors[i])
    }
}

// MARK: - OGL: vector 3D: move to vector
//
// Interpolates between two vectors based on input interpolation ratio

@c @implementation
public func OGLVector3D_MoveToVector(_ from: UnsafeMutablePointer<OGLVector3D>!, _ to: UnsafeMutablePointer<OGLVector3D>!, _ out: UnsafeMutablePointer<OGLVector3D>!, _ ratioIn: Float) {
    var ratio = ratioIn
    var v = OGLVector3D()

    // CALC INTERPOLATION BETWEEN AIM & MOTION

    if ratio > 1.0 {
        ratio = 1.0
    }
    let oneMinusRatio = 1.0 - ratio

    v.x = (from.pointee.x * oneMinusRatio) + (to.pointee.x * ratio) // interpolate it
    v.y = (from.pointee.y * oneMinusRatio) + (to.pointee.y * ratio)
    v.z = (from.pointee.z * oneMinusRatio) + (to.pointee.z * ratio)

    OGLVector3D_Normalize(&v, out)
}

// MARK: - Vector 2D cross

@c @implementation
public func OGLVector2D_Cross(_ v1: UnsafePointer<OGLVector2D>!, _ v2: UnsafePointer<OGLVector2D>!) -> Float {
    (v1.pointee.x * v2.pointee.y) - (v1.pointee.y * v2.pointee.x)
}

// MARK: - Point 3D distance

@c @implementation
public func OGLPoint3D_Distance(_ p1: UnsafePointer<OGLPoint3D>!, _ p2: UnsafePointer<OGLPoint3D>!) -> Float {
    let dx = p1.pointee.x - p2.pointee.x
    let dy = p1.pointee.y - p2.pointee.y
    let dz = p1.pointee.z - p2.pointee.z

    return sqrt(dx * dx + dy * dy + dz * dz)
}

// MARK: - Point 2D distance

@c @implementation
public func OGLPoint2D_Distance(_ p1: UnsafeMutablePointer<OGLPoint2D>!, _ p2: UnsafeMutablePointer<OGLPoint2D>!) -> Float {
    let dx = p1.pointee.x - p2.pointee.x
    let dy = p1.pointee.y - p2.pointee.y

    return sqrt(dx * dx + dy * dy)
}

// MARK: -

// MARK: - OGL: point 3D calc bounding box

@c @implementation
public func OGLPoint3D_CalcBoundingBox(_ points: UnsafePointer<OGLPoint3D>!, _ numPoints: Int32, _ bBox: UnsafeMutablePointer<OGLBoundingBox>!) {
    if numPoints == 0 {
        bBox.pointee.isEmpty = 1
        return
    }

    // INIT BBOX TO BOGUS VALUES

    var minx: Float = 100_000_000
    var miny: Float = 100_000_000
    var minz: Float = 100_000_000
    var maxx: Float = -minx
    var maxy: Float = -miny
    var maxz: Float = -minz

    // CALC BBOX

    for i in 0..<Int(numPoints) {
        let px = points[i].x
        let py = points[i].y
        let pz = points[i].z

        if px < minx { minx = px }
        if px > maxx { maxx = px }

        if py < miny { miny = py }
        if py > maxy { maxy = py }

        if pz < minz { minz = pz }
        if pz > maxz { maxz = pz }
    }

    // SAVE BBOX

    bBox.pointee.min.x = minx
    bBox.pointee.min.y = miny
    bBox.pointee.min.z = minz
    bBox.pointee.max.x = maxx
    bBox.pointee.max.y = maxy
    bBox.pointee.max.z = maxz
    bBox.pointee.isEmpty = 0
}

// MARK: - OGL: point 3D to 4D transform array

@c @implementation
public func OGLPoint3D_To4DTransformArray(_ inVertex: UnsafePointer<OGLPoint3D>!, _ matrix: UnsafePointer<OGLMatrix4x4>!, _ outVertex: UnsafeMutablePointer<OGLPoint4D>!, _ numVertices: Int) {
    var m = matrix.pointee
    let m00 = matValue(&m, M00); let m01 = matValue(&m, M01); let m02 = matValue(&m, M02); let m03 = matValue(&m, M03)
    let m10 = matValue(&m, M10); let m11 = matValue(&m, M11); let m12 = matValue(&m, M12); let m13 = matValue(&m, M13)
    let m20 = matValue(&m, M20); let m21 = matValue(&m, M21); let m22 = matValue(&m, M22); let m23 = matValue(&m, M23)
    let m30 = matValue(&m, M30); let m31 = matValue(&m, M31); let m32 = matValue(&m, M32); let m33 = matValue(&m, M33)

    for i in 0..<numVertices {
        var accum = inVertex[i].x * m00
        accum += inVertex[i].y * m01
        accum += inVertex[i].z * m02
        outVertex[i].x = accum + m03

        accum = inVertex[i].x * m10
        accum += inVertex[i].y * m11
        accum += inVertex[i].z * m12
        outVertex[i].y = accum + m13

        accum = inVertex[i].x * m20
        accum += inVertex[i].y * m21
        accum += inVertex[i].z * m22
        outVertex[i].z = accum + m23

        accum = inVertex[i].x * m30
        accum += inVertex[i].y * m31
        accum += inVertex[i].z * m32
        outVertex[i].w = accum + m33
    }
}

// MARK: - OGL: point 3D transform array

@c @implementation
public func OGLPoint3D_TransformArray(_ inVertex: UnsafePointer<OGLPoint3D>!, _ matrix: UnsafePointer<OGLMatrix4x4>!, _ outVertex: UnsafeMutablePointer<OGLPoint3D>!, _ numVertices: Int) {
    var m = matrix.pointee
    let m00 = matValue(&m, M00); let m01 = matValue(&m, M01); let m02 = matValue(&m, M02); let m03 = matValue(&m, M03)
    let m10 = matValue(&m, M10); let m11 = matValue(&m, M11); let m12 = matValue(&m, M12); let m13 = matValue(&m, M13)
    let m20 = matValue(&m, M20); let m21 = matValue(&m, M21); let m22 = matValue(&m, M22); let m23 = matValue(&m, M23)

    for i in 0..<numVertices {
        let x = inVertex[i].x
        let y = inVertex[i].y
        let z = inVertex[i].z

        var accum = x * m00
        accum += y * m01
        accum += z * m02
        outVertex[i].x = accum + m03

        accum = x * m10
        accum += y * m11
        accum += z * m12
        outVertex[i].y = accum + m13

        accum = x * m20
        accum += y * m21
        accum += z * m22
        outVertex[i].z = accum + m23
    }
}

// MARK: - OGL: point 2D transform array

@c @implementation
public func OGLPoint2D_TransformArray(_ inVertex: UnsafePointer<OGLPoint2D>!, _ matrix: UnsafePointer<OGLMatrix3x3>!, _ outVertex: UnsafeMutablePointer<OGLPoint2D>!, _ numVertices: Int) {
    var m = matrix.pointee

    for i in 0..<numVertices {
        let x = inVertex[i].x
        let y = inVertex[i].y

        outVertex[i].x = (x * mat3Value(&m, N00)) + (y * mat3Value(&m, N01)) + mat3Value(&m, N02)
        outVertex[i].y = (x * mat3Value(&m, N10)) + (y * mat3Value(&m, N11)) + mat3Value(&m, N12)
    }
}

// MARK: -

// MARK: - OGL: point 3D distance to plane
//
// Returns a SIGNED distance!

@c @implementation
public func OGLPoint3D_DistanceToPlane(_ point: UnsafePointer<OGLPoint3D>!, _ plane: UnsafePointer<OGLPlaneEquation>!) -> Float {
    var normal = plane.pointee.normal
    var pointAsVector = OGLVector3D(x: point.pointee.x, y: point.pointee.y, z: point.pointee.z)
    var d = OGLVector3D_Dot(&normal, &pointAsVector)
    d += plane.pointee.constant

    return d
}

// MARK: - OGL: point 2D line distance

@c @implementation
public func OGLPoint2D_LineDistance(_ point: UnsafeMutablePointer<OGLPoint2D>!, _ p1x: Float, _ p1y: Float, _ p2x: Float, _ p2y: Float, _ t: UnsafeMutablePointer<Float>!) -> Float {
    let XJ = point.pointee.x
    let YJ = point.pointee.y

    let p1xJ = p1x - XJ
    let YKJ = p1y - YJ
    let XLK = p2x - p1x
    let YLK = p2y - p1y
    let DENOM = XLK * XLK + YLK * YLK

    if DENOM < Float(EPS) {
        t.pointee = 0
        return sqrt(p1xJ * p1xJ + YKJ * YKJ)
    } else {
        var t2 = -(p1xJ * XLK + YKJ * YLK) / DENOM
        t2 = min(max(t2, 0.0), 1.0)
        let XFAC = p1xJ + t2 * XLK
        let YFAC = YKJ + t2 * YLK

        t.pointee = t2
        return sqrt(XFAC * XFAC + YFAC * YFAC)
    }
}

// MARK: - OGL: bounding box transform

@c @implementation
public func OGLBoundingBox_Transform(_ inBox: UnsafeMutablePointer<OGLBoundingBox>!, _ m: UnsafeMutablePointer<OGLMatrix4x4>!, _ outBox: UnsafeMutablePointer<OGLBoundingBox>!) {
    var p = [OGLPoint3D](repeating: OGLPoint3D(), count: 8)
    var pp = [OGLPoint3D](repeating: OGLPoint3D(), count: 8)

    // TRANSFORM ALL 8 POINTS ON BBOX

    p[0].x = inBox.pointee.min.x // upper far left corner
    p[0].y = inBox.pointee.max.y
    p[0].y = inBox.pointee.min.z

    p[1].x = inBox.pointee.max.x // upper far right corner
    p[1].y = inBox.pointee.max.y
    p[1].z = inBox.pointee.min.z

    p[2].x = inBox.pointee.max.x // upper near right corner
    p[2].y = inBox.pointee.max.y
    p[2].z = inBox.pointee.max.z

    p[3].x = inBox.pointee.min.x // upper near left corner
    p[3].y = inBox.pointee.max.y
    p[3].z = inBox.pointee.max.z

    p[4].x = inBox.pointee.min.x // lower far left corner
    p[4].y = inBox.pointee.min.y
    p[4].y = inBox.pointee.min.z

    p[5].x = inBox.pointee.max.x // lower far right corner
    p[5].y = inBox.pointee.min.y
    p[5].z = inBox.pointee.min.z

    p[6].x = inBox.pointee.max.x // lower near right corner
    p[6].y = inBox.pointee.min.y
    p[6].z = inBox.pointee.max.z

    p[7].x = inBox.pointee.min.x // lower near left corner
    p[7].y = inBox.pointee.min.y
    p[7].z = inBox.pointee.max.z

    p.withUnsafeBufferPointer { pBuf in
        pp.withUnsafeMutableBufferPointer { ppBuf in
            OGLPoint3D_TransformArray(pBuf.baseAddress, m, ppBuf.baseAddress, 8)
        }
    }

    // FIND MIN/MAX

    var minX = pp[0].x; var maxX = pp[0].x
    var minY = pp[0].y; var maxY = pp[0].y
    var minZ = pp[0].z; var maxZ = pp[0].z

    for i in 1..<8 {
        if pp[i].x < minX { minX = pp[i].x } // min X
        if pp[i].x > maxX { maxX = pp[i].x } // max X

        if pp[i].y < minY { minY = pp[i].y } // min Y
        if pp[i].y > maxY { maxY = pp[i].y } // max Y

        if pp[i].z < minZ { minZ = pp[i].z } // min Z
        if pp[i].z > maxZ { maxZ = pp[i].z } // max Z
    }

    // SET NEW BBOX

    outBox.pointee.isEmpty = 0
    outBox.pointee.min.x = minX
    outBox.pointee.max.x = maxX
    outBox.pointee.min.y = minY
    outBox.pointee.max.y = maxY
    outBox.pointee.min.z = minZ
    outBox.pointee.max.z = maxZ
}

// MARK: -

// MARK: - Decay to zero

@c @implementation
public func DecayToZero(_ numberIn: Float, _ decay: Float) -> Float {
    var number = numberIn
    if number > 0.0 {
        number -= decay
        if number < 0.0 {
            number = 0.0
        }
    } else if number < 0.0 {
        number += decay
        if number > 0.0 {
            number = 0.0
        }
    }
    return number
}

// MARK: -

// MARK: - OGL: compute triangle plane equation

@c @implementation
public func OGL_ComputeTrianglePlaneEquation(_ trianglePoints: UnsafePointer<OGLPoint3D>!, _ planeEquation: UnsafeMutablePointer<OGLPlaneEquation>!) {
    // 1. Compute cross product of trianglePoints
    // 2. Normalize this vector for planeEquation.normal (sqrt)
    // 3. Compute planeEquation.constant:
    //		dot product of normal vector and one point of trianglePoints

    let p3 = trianglePoints[0]
    let p2 = trianglePoints[1]
    let p1 = trianglePoints[2]

    let v0x = p1.x - p2.x
    let v0y = p1.y - p2.y
    let v0z = p1.z - p2.z

    let v1x = p3.x - p2.x
    let v1y = p3.y - p2.y
    let v1z = p3.z - p2.z

    var nx = (v0y * v1z) - (v0z * v1y)
    var ny = (v0z * v1x) - (v0x * v1z)
    var nz = (v0x * v1y) - (v0y * v1x)

    do {
        let length = sqrt(nx * nx + ny * ny + nz * nz)

        if length < Float(EPS) {
            return
        } else {
            let oneOverLength = 1.0 / length
            nx *= oneOverLength
            ny *= oneOverLength
            nz *= oneOverLength
        }
    }

    planeEquation.pointee.normal.x = nx
    planeEquation.pointee.normal.y = ny
    planeEquation.pointee.normal.z = nz

    planeEquation.pointee.constant = -((nx * p1.x) + (ny * p1.y) + (nz * p1.z))
}

// MARK: -

// MARK: - Fast sin/cos/tan approximations
//
// #0 functions are fast, but less accurate
// #1 functions are still fast, but more accurate

// SIN

@c @implementation
public func FastSin0(_ fAngle: Double) -> Double {
    let fASqr = fAngle * fAngle
    var fResult = 7.61e-03
    fResult *= fASqr
    fResult -= 1.6605e-01
    fResult *= fASqr
    fResult += 1.0
    fResult *= fAngle
    return fResult
}

@c @implementation
public func FastSin1(_ fAngle: Double) -> Double {
    let fASqr = fAngle * fAngle
    var fResult = -2.39e-08
    fResult *= fASqr
    fResult += 2.7526e-06
    fResult *= fASqr
    fResult -= 1.98409e-04
    fResult *= fASqr
    fResult += 8.3333315e-03
    fResult *= fASqr
    fResult -= 1.666666664e-01
    fResult *= fASqr
    fResult += 1.0
    fResult *= fAngle
    return fResult
}

// COS

@c @implementation
public func FastCos0(_ fAngle: Double) -> Double {
    let fASqr = fAngle * fAngle
    var fResult = 3.705e-02
    fResult *= fASqr
    fResult -= 4.967e-01
    fResult *= fASqr
    fResult += 1.0
    return fResult
}

@c @implementation
public func FastCos1(_ fAngle: Double) -> Double {
    let fASqr = fAngle * fAngle
    var fResult = -2.605e-07
    fResult *= fASqr
    fResult += 2.47609e-05
    fResult *= fASqr
    fResult -= 1.3888397e-03
    fResult *= fASqr
    fResult += 4.16666418e-02
    fResult *= fASqr
    fResult -= 4.999999963e-01
    fResult *= fASqr
    fResult += 1.0
    return fResult
}

// TAN

@c @implementation
public func FastTan0(_ fAngle: Double) -> Double {
    let fASqr = fAngle * fAngle
    var fResult = 2.033e-01
    fResult *= fASqr
    fResult += 3.1755e-01
    fResult *= fASqr
    fResult += 1.0
    fResult *= fAngle
    return fResult
}

@c @implementation
public func FastTan1(_ fAngle: Double) -> Double {
    let fASqr = fAngle * fAngle
    var fResult = 9.5168091e-03
    fResult *= fASqr
    fResult += 2.900525e-03
    fResult *= fASqr
    fResult += 2.45650893e-02
    fResult *= fASqr
    fResult += 5.33740603e-02
    fResult *= fASqr
    fResult += 1.333923995e-01
    fResult *= fASqr
    fResult += 3.333314036e-01
    fResult *= fASqr
    fResult += 1.0
    fResult *= fAngle
    return fResult
}

@c @implementation
public func FastInvTan0(_ fValue: Double) -> Double {
    let fVSqr = fValue * fValue
    var fResult = 0.0208351
    fResult *= fVSqr
    fResult -= 0.085133
    fResult *= fVSqr
    fResult += 0.180141
    fResult *= fVSqr
    fResult -= 0.3302995
    fResult *= fVSqr
    fResult += 0.999866
    fResult *= fValue
    return fResult
}

@c @implementation
public func FastInvTan1(_ fValue: Double) -> Double {
    let fVSqr = fValue * fValue
    var fResult = 0.0028662257
    fResult *= fVSqr
    fResult -= 0.0161657367
    fResult *= fVSqr
    fResult += 0.0429096138
    fResult *= fVSqr
    fResult -= 0.0752896400
    fResult *= fVSqr
    fResult += 0.1065626393
    fResult *= fVSqr
    fResult -= 0.1420889944
    fResult *= fVSqr
    fResult += 0.1999355085
    fResult *= fVSqr
    fResult -= 0.3333314528
    fResult *= fVSqr
    fResult += 1.0
    fResult *= fValue
    return fResult
}

// MARK: -

// MARK: - Fast inverse square root

@c @implementation
public func FastInvSqrt(_ val: Double) -> Double {
    // __ppc__ is never defined for this build (arm64/x86_64 only).
    1.0 / sqrt(val)
}
