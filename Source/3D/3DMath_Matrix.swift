// 3DMath_Matrix.swift - Port of the matrix/vector-transform functions in 3DMath.c to Swift.
// (Second of several files splitting up 3DMath.c's large function set.)

// MARK: - Set lookat matrix

@c @implementation
public func SetLookAtMatrix(_ m: UnsafeMutablePointer<OGLMatrix4x4>!, _ upVector: UnsafePointer<OGLVector3D>!, _ from: UnsafePointer<OGLPoint3D>!, _ to: UnsafePointer<OGLPoint3D>!) {
    var lookAt = OGLVector3D()
    var theXAxis = OGLVector3D()

    // SET UP VECTOR

    setMatValue(&m.pointee, M01, upVector.pointee.x)
    setMatValue(&m.pointee, M11, upVector.pointee.y)
    setMatValue(&m.pointee, M21, upVector.pointee.z)

    // CALC THE X-AXIS VECTOR

    FastNormalizeVector(from.pointee.x - to.pointee.x, from.pointee.y - to.pointee.y, from.pointee.z - to.pointee.z, &lookAt) // calc temporary look-at vector

    theXAxis.x = upVector.pointee.y * lookAt.z - lookAt.y * upVector.pointee.z // calc cross product
    theXAxis.y = -(upVector.pointee.x * lookAt.z - lookAt.x * upVector.pointee.z)
    theXAxis.z = upVector.pointee.x * lookAt.y - lookAt.x * upVector.pointee.y
    theXAxis = theXAxis.normalized()

    setMatValue(&m.pointee, M00, theXAxis.x)
    setMatValue(&m.pointee, M10, theXAxis.y)
    setMatValue(&m.pointee, M20, theXAxis.z)

    do { // recompute a fixed up vector to ensure orthonormal
        let newUp = lookAt.cross(theXAxis)
        setMatValue(&m.pointee, M01, newUp.x)
        setMatValue(&m.pointee, M11, newUp.y)
        setMatValue(&m.pointee, M21, newUp.z)
    }

    // CALC LOOK-AT VECTOR
    //
    // We totally recompute this since the input "to" is not probably orthonormal to other axes.

    lookAt.x = -(upVector.pointee.y * theXAxis.z - theXAxis.y * upVector.pointee.z) // calc reversed cross product
    lookAt.y = (upVector.pointee.x * theXAxis.z - theXAxis.x * upVector.pointee.z)
    lookAt.z = -(upVector.pointee.x * theXAxis.y - theXAxis.x * upVector.pointee.y)

    setMatValue(&m.pointee, M02, lookAt.x)
    setMatValue(&m.pointee, M12, lookAt.y)
    setMatValue(&m.pointee, M22, lookAt.z)

    // SET OTHER THINGS

    setMatValue(&m.pointee, M30, 0)
    setMatValue(&m.pointee, M31, 0)
    setMatValue(&m.pointee, M32, 0)
    setMatValue(&m.pointee, M03, 0)
    setMatValue(&m.pointee, M13, 0)
    setMatValue(&m.pointee, M23, 0)
    setMatValue(&m.pointee, M33, 1)
}

// MARK: - Set lookat matrix and translate

@c @implementation
public func SetLookAtMatrixAndTranslate(_ m: UnsafeMutablePointer<OGLMatrix4x4>!, _ upVector: UnsafePointer<OGLVector3D>!, _ from: UnsafePointer<OGLPoint3D>!, _ to: UnsafePointer<OGLPoint3D>!) {
    var lookAt = OGLVector3D()
    var theXAxis = OGLVector3D()
    var newUp = OGLVector3D()

    // CALC LOOK-AT VECTOR

    FastNormalizeVector((from.pointee.x - to.pointee.x), (from.pointee.y - to.pointee.y), (from.pointee.z - to.pointee.z), &lookAt)
    setMatValue(&m.pointee, M02, lookAt.x)
    setMatValue(&m.pointee, M12, lookAt.y)
    setMatValue(&m.pointee, M22, lookAt.z)

    // CALC THE X-AXIS VECTOR

    theXAxis.x = upVector.pointee.y * lookAt.z - lookAt.y * upVector.pointee.z // calc cross product
    theXAxis.y = -(upVector.pointee.x * lookAt.z - lookAt.x * upVector.pointee.z)
    theXAxis.z = upVector.pointee.x * lookAt.y - lookAt.x * upVector.pointee.y
    theXAxis = theXAxis.normalized()

    setMatValue(&m.pointee, M00, theXAxis.x)
    setMatValue(&m.pointee, M10, theXAxis.y)
    setMatValue(&m.pointee, M20, theXAxis.z)

    // RE-CALC UP VECTOR

    // recompute a fixed up vector to ensure orthonormal
    newUp = lookAt.cross(theXAxis)
    setMatValue(&m.pointee, M01, newUp.x)
    setMatValue(&m.pointee, M11, newUp.y)
    setMatValue(&m.pointee, M21, newUp.z)

    // SET OTHER THINGS

    setMatValue(&m.pointee, M30, 0)
    setMatValue(&m.pointee, M31, 0)
    setMatValue(&m.pointee, M32, 0)

    setMatValue(&m.pointee, M03, from.pointee.x) // set translate
    setMatValue(&m.pointee, M13, from.pointee.y)
    setMatValue(&m.pointee, M23, from.pointee.z)
    setMatValue(&m.pointee, M33, 1)
}

// MARK: - Set alignment matrix
//
// Creates a matrix which will orient geometry to be aligned with the aim vector
//
// NOTE:  This will break if aim vector is straight up or down.

@c @implementation
public func SetAlignmentMatrix(_ m: UnsafeMutablePointer<OGLMatrix4x4>!, _ aim: UnsafePointer<OGLVector3D>!) {
    var theXAxis = OGLVector3D()
    var yAxis = OGLVector3D()
    let up = OGLVector3D(x: 0, y: 1, z: 0)

    // SET LOOK-AT VECTOR (Z-AXIS)

    setMatValue(&m.pointee, M02, -aim.pointee.x)
    setMatValue(&m.pointee, M12, -aim.pointee.y)
    setMatValue(&m.pointee, M22, -aim.pointee.z)

    // CALC X-AXIS

    let upVar = up
    let aimVar = aim.pointee
    theXAxis = aimVar.cross(upVar)
    setMatValue(&m.pointee, M00, theXAxis.x)
    setMatValue(&m.pointee, M10, theXAxis.y)
    setMatValue(&m.pointee, M20, theXAxis.z)

    // CALC Y-AXIS

    yAxis = theXAxis.cross(aimVar)
    setMatValue(&m.pointee, M01, yAxis.x)
    setMatValue(&m.pointee, M11, yAxis.y)
    setMatValue(&m.pointee, M21, yAxis.z)

    // SET OTHER THINGS

    setMatValue(&m.pointee, M30, 0)
    setMatValue(&m.pointee, M31, 0)
    setMatValue(&m.pointee, M32, 0)
    setMatValue(&m.pointee, M03, 0)
    setMatValue(&m.pointee, M13, 0)
    setMatValue(&m.pointee, M23, 0)
    setMatValue(&m.pointee, M33, 1)
}

// MARK: - Set alignment matrix with Z rot

@c @implementation
public func SetAlignmentMatrixWithZRot(_ m: UnsafeMutablePointer<OGLMatrix4x4>!, _ aim: UnsafePointer<OGLVector3D>!, _ rotZ: Float) {
    var rm = OGLMatrix4x4()

    // CALC THE ROT MATRIX

    rm.setRotateZ(rotZ)

    // CALC THE REGULAR MATRIX

    SetAlignmentMatrix(m, aim)

    // MULTIPLY TOGETHER

    m.pointee = rm.multiplied(by: m.pointee)
}

// MARK: -

// MARK: - OGLMatrix4x4 extension: converted from free C-ABI functions

extension OGLMatrix4x4 {
    // MARK: - Matrix4x4 transpose

    public func transposed() -> OGLMatrix4x4 {
        var result = OGLMatrix4x4()
        var src = self
        for row in 0..<4 {
            for column in 0..<4 {
                let a = Int32(column * 4 + row)
                let b = Int32(row * 4 + column)
                setMatValue(&result, a, matValue(&src, b))
            }
        }
        return result
    }

    // MARK: - GLMatrix4x4: SetScale

    public mutating func setScale(_ x: Float, _ y: Float, _ z: Float) {
        setMatValue(&self, M00, x)
        setMatValue(&self, M11, y)
        setMatValue(&self, M22, z)
        setMatValue(&self, M33, 1)

        setMatValue(&self, M01, 0)
        setMatValue(&self, M02, 0)
        setMatValue(&self, M03, 0)

        setMatValue(&self, M10, 0)
        setMatValue(&self, M12, 0)
        setMatValue(&self, M13, 0)

        setMatValue(&self, M20, 0)
        setMatValue(&self, M21, 0)
        setMatValue(&self, M23, 0)

        setMatValue(&self, M30, 0)
        setMatValue(&self, M31, 0)
        setMatValue(&self, M32, 0)
    }

    // MARK: - GLMatrix4x4: set rotate X

    public mutating func setRotateX(_ angle: Float) {
        let s = sin(angle)
        let c = cos(angle)

        setIdentity()

        setMatValue(&self, M11, c)
        setMatValue(&self, M12, -s)
        setMatValue(&self, M21, s)
        setMatValue(&self, M22, c)
    }

    // MARK: - GLMatrix4x4: set rotate Y

    public mutating func setRotateY(_ angle: Float) {
        let s = sin(angle)
        let c = cos(angle)

        setIdentity()

        setMatValue(&self, M00, c)
        setMatValue(&self, M02, s)
        setMatValue(&self, M20, -s)
        setMatValue(&self, M22, c)
    }

    // MARK: - GLMatrix4x4: set rotate Z

    public mutating func setRotateZ(_ angle: Float) {
        let s = sin(angle)
        let c = cos(angle)

        setIdentity()

        setMatValue(&self, M00, c)
        setMatValue(&self, M01, -s)
        setMatValue(&self, M10, s)
        setMatValue(&self, M11, c)
    }

    // MARK: - GL matrix 4x4: set rotate about point

    public mutating func setRotateAboutPoint(_ origin: OGLPoint3D, xAngle: Float, yAngle: Float, zAngle: Float) {
        var negTransM = OGLMatrix4x4()
        var rotM = OGLMatrix4x4()

        negTransM.setTranslate(-origin.x, -origin.y, -origin.z)
        setTranslate(origin.x, origin.y, origin.z)

        rotM.setRotateXYZ(xAngle, yAngle, zAngle)

        self = rotM.multiplied(by: self)
        self = negTransM.multiplied(by: self)
    }

    // MARK: - OGL matrix 4x4 multiply

    public func multiplied(by other: OGLMatrix4x4) -> OGLMatrix4x4 {
        var result = OGLMatrix4x4()
        var selfCopy = self
        var otherCopy = other
        withUnsafePointer(to: &selfCopy) { mA in
            withUnsafePointer(to: &otherCopy) { mB in
                withUnsafeMutablePointer(to: &result) { r in
                    oglMatrix4x4MultiplyFloat(mA, mB, r)
                }
            }
        }
        return result
    }

    // MARK: - Matrix4x4 set translate

    public mutating func setTranslate(_ x: Float, _ y: Float, _ z: Float) {
        setMatValue(&self, M03, x)
        setMatValue(&self, M13, y)
        setMatValue(&self, M23, z)

        setMatValue(&self, M00, 1)
        setMatValue(&self, M11, 1)
        setMatValue(&self, M22, 1)
        setMatValue(&self, M33, 1)

        setMatValue(&self, M01, 0)
        setMatValue(&self, M02, 0)
        setMatValue(&self, M10, 0)
        setMatValue(&self, M12, 0)
        setMatValue(&self, M20, 0)
        setMatValue(&self, M21, 0)
        setMatValue(&self, M30, 0)
        setMatValue(&self, M31, 0)
        setMatValue(&self, M32, 0)
    }

    // MARK: - Matrix 4x4: get frustum to window

    public mutating func setFrustumToWindow(pane: Int32) {
        var x: Int32 = 0
        var y: Int32 = 0
        var w: Int32 = 0
        var h: Int32 = 0

        OGL_GetCurrentViewport(&x, &y, &w, &h, UInt8(pane))

        let width = Float(w)
        let height = Float(h)

        setIdentity()

        setMatValue(&self, M00, width * 0.5)
        setMatValue(&self, M11, -height * 0.5)
        setMatValue(&self, M03, width * 0.5)
        setMatValue(&self, M13, height * 0.5)
    }

    // MARK: - Matrix 4x4 set identity

    public mutating func setIdentity() {
        setMatValue(&self, M00, 1)
        setMatValue(&self, M11, 1)
        setMatValue(&self, M22, 1)
        setMatValue(&self, M33, 1)

        setMatValue(&self, M01, 0)
        setMatValue(&self, M02, 0)
        setMatValue(&self, M03, 0)
        setMatValue(&self, M10, 0)
        setMatValue(&self, M12, 0)
        setMatValue(&self, M13, 0)
        setMatValue(&self, M20, 0)
        setMatValue(&self, M21, 0)
        setMatValue(&self, M23, 0)
        setMatValue(&self, M30, 0)
        setMatValue(&self, M31, 0)
        setMatValue(&self, M32, 0)
    }

    // MARK: - Set quick XYZ-rotation matrix
    //
    // Does a quick precomputation to calculate an XYZ rotation matrix

    public mutating func setRotateXYZ(_ rx: Float, _ ry: Float, _ rz: Float) {
        let sx = sin(rx)
        let sy = sin(ry)
        let sz = sin(rz)
        let cx = cos(rx)
        let cy = cos(ry)
        let cz = cos(rz)

        let sxsy = sx * sy
        let cxsy = cx * sy

        setMatValue(&self, M00, cy * cz); setMatValue(&self, M10, cy * sz); setMatValue(&self, M20, -sy); setMatValue(&self, M30, 0)
        setMatValue(&self, M01, (sxsy * cz) + (cx * -sz)); setMatValue(&self, M11, (sxsy * sz) + (cx * cz)); setMatValue(&self, M21, sx * cy); setMatValue(&self, M31, 0)
        setMatValue(&self, M02, (cxsy * cz) + (-sx * -sz)); setMatValue(&self, M12, (cxsy * sz) + (-sx * cz)); setMatValue(&self, M22, cx * cy); setMatValue(&self, M32, 0)
        setMatValue(&self, M03, 0); setMatValue(&self, M13, 0); setMatValue(&self, M23, 0); setMatValue(&self, M33, 1)
    }

    // MARK: - Set rotate about axis

    public mutating func setRotateAboutAxis(_ axis: OGLVector3D, angle: Float) {
        let ax = axis.x
        let ay = axis.y
        let az = axis.z
        let ax2 = ax * ax
        let ay2 = ay * ay
        let az2 = az * az

        let axy = ax * ay
        let axz = ax * az
        let ayz = ay * az

        let sine = sin(angle)
        let cosine = cos(angle)
        let t = 1.0 - cosine

        setIdentity()

        setMatValue(&self, M00, t * ax2 + cosine)
        setMatValue(&self, M10, t * axy + sine * az)
        setMatValue(&self, M20, t * axz - sine * ay)

        setMatValue(&self, M01, t * axy - sine * az)
        setMatValue(&self, M11, t * ay2 + cosine)
        setMatValue(&self, M21, t * ayz + sine * ax)

        setMatValue(&self, M02, t * axz + sine * ay)
        setMatValue(&self, M12, t * ayz - sine * ax)
        setMatValue(&self, M22, t * az2 + cosine)
    }

    // MARK: - OGL matrix 4x4: invert

    public func inverted() -> OGLMatrix4x4 {
        var mt2 = OGLMatrix4x4()
        mt2.setIdentity()
        var mt1 = self // copy in matrix

        var failed = false

        outer: for i in 0..<4 {
            var val = matValue(&mt1, Int32((i << 2) + i))
            var ind = i

            let i4 = i + 4
            let i8 = i + 8
            let i12 = i + 12

            for j in (i + 1)..<4 {
                if abs(matValue(&mt1, Int32((i << 2) + j))) > abs(val) {
                    ind = j
                    val = matValue(&mt1, Int32((i << 2) + j))
                }
            }

            if ind != i {
                var val2 = matValue(&mt2, Int32(i))
                let tmp1 = matValue(&mt2, Int32(i))
                setMatValue(&mt2, Int32(i), matValue(&mt2, Int32(ind)))
                setMatValue(&mt2, Int32(ind), tmp1)

                val2 = matValue(&mt1, Int32(i))
                let tmp2 = matValue(&mt1, Int32(i))
                setMatValue(&mt1, Int32(i), matValue(&mt1, Int32(ind)))
                setMatValue(&mt1, Int32(ind), tmp2)
                _ = val2

                var indVar = ind + 4

                var t2 = matValue(&mt2, Int32(i4))
                setMatValue(&mt2, Int32(i4), matValue(&mt2, Int32(indVar)))
                setMatValue(&mt2, Int32(indVar), t2)

                t2 = matValue(&mt1, Int32(i4))
                setMatValue(&mt1, Int32(i4), matValue(&mt1, Int32(indVar)))
                setMatValue(&mt1, Int32(indVar), t2)

                indVar += 4

                t2 = matValue(&mt2, Int32(i8))
                setMatValue(&mt2, Int32(i8), matValue(&mt2, Int32(indVar)))
                setMatValue(&mt2, Int32(indVar), t2)

                t2 = matValue(&mt1, Int32(i8))
                setMatValue(&mt1, Int32(i8), matValue(&mt1, Int32(indVar)))
                setMatValue(&mt1, Int32(indVar), t2)

                indVar += 4

                t2 = matValue(&mt2, Int32(i12))
                setMatValue(&mt2, Int32(i12), matValue(&mt2, Int32(indVar)))
                setMatValue(&mt2, Int32(indVar), t2)

                t2 = matValue(&mt1, Int32(i12))
                setMatValue(&mt1, Int32(i12), matValue(&mt1, Int32(indVar)))
                setMatValue(&mt1, Int32(indVar), t2)
            }

            if val == 0.0 {
                failed = true
                break outer
            }

            let valInv = 1.0 / val

            setMatValue(&mt1, Int32(i), matValue(&mt1, Int32(i)) * valInv)
            setMatValue(&mt2, Int32(i), matValue(&mt2, Int32(i)) * valInv)

            setMatValue(&mt1, Int32(i4), matValue(&mt1, Int32(i4)) * valInv)
            setMatValue(&mt2, Int32(i4), matValue(&mt2, Int32(i4)) * valInv)

            setMatValue(&mt1, Int32(i8), matValue(&mt1, Int32(i8)) * valInv)
            setMatValue(&mt2, Int32(i8), matValue(&mt2, Int32(i8)) * valInv)

            setMatValue(&mt1, Int32(i12), matValue(&mt1, Int32(i12)) * valInv)
            setMatValue(&mt2, Int32(i12), matValue(&mt2, Int32(i12)) * valInv)

            if i != 0 {
                val = matValue(&mt1, Int32(i << 2))

                setMatValue(&mt1, 0, matValue(&mt1, 0) - matValue(&mt1, Int32(i)) * val)
                setMatValue(&mt2, 0, matValue(&mt2, 0) - matValue(&mt2, Int32(i)) * val)

                setMatValue(&mt1, 4, matValue(&mt1, 4) - matValue(&mt1, Int32(i4)) * val)
                setMatValue(&mt2, 4, matValue(&mt2, 4) - matValue(&mt2, Int32(i4)) * val)

                setMatValue(&mt1, 8, matValue(&mt1, 8) - matValue(&mt1, Int32(i8)) * val)
                setMatValue(&mt2, 8, matValue(&mt2, 8) - matValue(&mt2, Int32(i8)) * val)

                setMatValue(&mt1, 12, matValue(&mt1, 12) - matValue(&mt1, Int32(i12)) * val)
                setMatValue(&mt2, 12, matValue(&mt2, 12) - matValue(&mt2, Int32(i12)) * val)
            }

            if i != 1 {
                val = matValue(&mt1, Int32((i << 2) + 1))

                setMatValue(&mt1, 1, matValue(&mt1, 1) - matValue(&mt1, Int32(i)) * val)
                setMatValue(&mt2, 1, matValue(&mt2, 1) - matValue(&mt2, Int32(i)) * val)

                setMatValue(&mt1, 5, matValue(&mt1, 5) - matValue(&mt1, Int32(i4)) * val)
                setMatValue(&mt2, 5, matValue(&mt2, 5) - matValue(&mt2, Int32(i4)) * val)

                setMatValue(&mt1, 9, matValue(&mt1, 9) - matValue(&mt1, Int32(i8)) * val)
                setMatValue(&mt2, 9, matValue(&mt2, 9) - matValue(&mt2, Int32(i8)) * val)

                setMatValue(&mt1, 13, matValue(&mt1, 13) - matValue(&mt1, Int32(i12)) * val)
                setMatValue(&mt2, 13, matValue(&mt2, 13) - matValue(&mt2, Int32(i12)) * val)
            }

            if i != 2 {
                val = matValue(&mt1, Int32((i << 2) + 2))

                setMatValue(&mt1, 2, matValue(&mt1, 2) - matValue(&mt1, Int32(i)) * val)
                setMatValue(&mt2, 2, matValue(&mt2, 2) - matValue(&mt2, Int32(i)) * val)

                setMatValue(&mt1, 6, matValue(&mt1, 6) - matValue(&mt1, Int32(i4)) * val)
                setMatValue(&mt2, 6, matValue(&mt2, 6) - matValue(&mt2, Int32(i4)) * val)

                setMatValue(&mt1, 10, matValue(&mt1, 10) - matValue(&mt1, Int32(i8)) * val)
                setMatValue(&mt2, 10, matValue(&mt2, 10) - matValue(&mt2, Int32(i8)) * val)

                setMatValue(&mt1, 14, matValue(&mt1, 14) - matValue(&mt1, Int32(i12)) * val)
                setMatValue(&mt2, 14, matValue(&mt2, 14) - matValue(&mt2, Int32(i12)) * val)
            }

            if i != 3 {
                val = matValue(&mt1, Int32((i << 2) + 3))

                setMatValue(&mt1, 3, matValue(&mt1, 3) - matValue(&mt1, Int32(i)) * val)
                setMatValue(&mt2, 3, matValue(&mt2, 3) - matValue(&mt2, Int32(i)) * val)

                setMatValue(&mt1, 7, matValue(&mt1, 7) - matValue(&mt1, Int32(i4)) * val)
                setMatValue(&mt2, 7, matValue(&mt2, 7) - matValue(&mt2, Int32(i4)) * val)

                setMatValue(&mt1, 11, matValue(&mt1, 11) - matValue(&mt1, Int32(i8)) * val)
                setMatValue(&mt2, 11, matValue(&mt2, 11) - matValue(&mt2, Int32(i8)) * val)

                setMatValue(&mt1, 15, matValue(&mt1, 15) - matValue(&mt1, Int32(i12)) * val)
                setMatValue(&mt2, 15, matValue(&mt2, 15) - matValue(&mt2, Int32(i12)) * val)
            }
        }

        if failed {
            var result = OGLMatrix4x4()
            result.setIdentity() // error, so set result to identity
            return result
        } else {
            return mt2 // copy to result
        }
    }
}

// MARK: - OGL matrix 4x4 multiply float

private func oglMatrix4x4MultiplyFloat(_ mA: UnsafePointer<OGLMatrix4x4>!, _ mB: UnsafePointer<OGLMatrix4x4>!, _ result: UnsafeMutablePointer<OGLMatrix4x4>!) {
    var a = mA.pointee
    var b = mB.pointee

    let b00 = matValue(&b, M00); let b01 = matValue(&b, M10); let b02 = matValue(&b, M20); let b03 = matValue(&b, M30)
    let b10 = matValue(&b, M01); let b11 = matValue(&b, M11); let b12 = matValue(&b, M21); let b13 = matValue(&b, M31)
    let b20 = matValue(&b, M02); let b21 = matValue(&b, M12); let b22 = matValue(&b, M22); let b23 = matValue(&b, M32)
    let b30 = matValue(&b, M03); let b31 = matValue(&b, M13); let b32 = matValue(&b, M23); let b33 = matValue(&b, M33)

    var ax0 = matValue(&a, M00); var ax1 = matValue(&a, M10)
    var ax2 = matValue(&a, M20); var ax3 = matValue(&a, M30)

    var r = result.pointee
    setMatValue(&r, M00, ax0 * b00 + ax1 * b10 + ax2 * b20 + ax3 * b30)
    setMatValue(&r, M10, ax0 * b01 + ax1 * b11 + ax2 * b21 + ax3 * b31)
    setMatValue(&r, M20, ax0 * b02 + ax1 * b12 + ax2 * b22 + ax3 * b32)
    setMatValue(&r, M30, ax0 * b03 + ax1 * b13 + ax2 * b23 + ax3 * b33)

    ax0 = matValue(&a, M01); ax1 = matValue(&a, M11)
    ax2 = matValue(&a, M21); ax3 = matValue(&a, M31)

    setMatValue(&r, M01, ax0 * b00 + ax1 * b10 + ax2 * b20 + ax3 * b30)
    setMatValue(&r, M11, ax0 * b01 + ax1 * b11 + ax2 * b21 + ax3 * b31)
    setMatValue(&r, M21, ax0 * b02 + ax1 * b12 + ax2 * b22 + ax3 * b32)
    setMatValue(&r, M31, ax0 * b03 + ax1 * b13 + ax2 * b23 + ax3 * b33)

    ax0 = matValue(&a, M02); ax1 = matValue(&a, M12)
    ax2 = matValue(&a, M22); ax3 = matValue(&a, M32)

    setMatValue(&r, M02, ax0 * b00 + ax1 * b10 + ax2 * b20 + ax3 * b30)
    setMatValue(&r, M12, ax0 * b01 + ax1 * b11 + ax2 * b21 + ax3 * b31)
    setMatValue(&r, M22, ax0 * b02 + ax1 * b12 + ax2 * b22 + ax3 * b32)
    setMatValue(&r, M32, ax0 * b03 + ax1 * b13 + ax2 * b23 + ax3 * b33)

    ax0 = matValue(&a, M03); ax1 = matValue(&a, M13)
    ax2 = matValue(&a, M23); ax3 = matValue(&a, M33)

    setMatValue(&r, M03, ax0 * b00 + ax1 * b10 + ax2 * b20 + ax3 * b30)
    setMatValue(&r, M13, ax0 * b01 + ax1 * b11 + ax2 * b21 + ax3 * b31)
    setMatValue(&r, M23, ax0 * b02 + ax1 * b12 + ax2 * b22 + ax3 * b32)
    setMatValue(&r, M33, ax0 * b03 + ax1 * b13 + ax2 * b23 + ax3 * b33)

    result.pointee = r
}

// MARK: - Matrix3x3 set translate

@c @implementation
public func OGLMatrix3x3_SetTranslate(_ m: UnsafeMutablePointer<OGLMatrix3x3>!, _ x: Float, _ y: Float) {
    setMat3Value(&m.pointee, N02, x)
    setMat3Value(&m.pointee, N12, y)

    setMat3Value(&m.pointee, N00, 1)
    setMat3Value(&m.pointee, N11, 1)
    setMat3Value(&m.pointee, N22, 1)

    setMat3Value(&m.pointee, N01, 0)
    setMat3Value(&m.pointee, N02, 0)
    setMat3Value(&m.pointee, N10, 0)
    setMat3Value(&m.pointee, N12, 0)
    setMat3Value(&m.pointee, N20, 0)
    setMat3Value(&m.pointee, N21, 0)
}

// MARK: - OGL matrix3x3 set rotate about point

@c @implementation
public func OGLMatrix3x3_SetRotateAboutPoint(_ m: UnsafeMutablePointer<OGLMatrix3x3>!, _ origin: UnsafeMutablePointer<OGLPoint2D>!, _ angle: Double) {
    let sine = sin(angle)
    let cosine = cos(angle)

    OGLMatrix3x3_SetIdentity(m)

    setMat3Value(&m.pointee, N00, Float(cosine))
    setMat3Value(&m.pointee, N10, Float(sine))
    setMat3Value(&m.pointee, N01, Float(-sine))
    setMat3Value(&m.pointee, N11, Float(cosine))
    setMat3Value(&m.pointee, N02, Float(-(Double(origin.pointee.x) * cosine) + (Double(origin.pointee.y) * sine) + Double(origin.pointee.x)))
    setMat3Value(&m.pointee, N12, Float(-(Double(origin.pointee.x) * sine) - (Double(origin.pointee.y) * cosine) + Double(origin.pointee.y)))
    setMat3Value(&m.pointee, N22, 1.0)
}

// MARK: - OGL matrix3x3 set rotate

@c @implementation
public func OGLMatrix3x3_SetRotate(_ m: UnsafeMutablePointer<OGLMatrix3x3>!, _ angle: Double) {
    let sine = Float(sin(angle))
    let cosine = Float(cos(angle))

    OGLMatrix3x3_SetIdentity(m)

    setMat3Value(&m.pointee, N00, cosine)
    setMat3Value(&m.pointee, N10, sine)
    setMat3Value(&m.pointee, N01, -sine)
    setMat3Value(&m.pointee, N11, cosine)
}

// MARK: - OGL matrix 3x3 set identity

@c @implementation
public func OGLMatrix3x3_SetIdentity(_ m: UnsafeMutablePointer<OGLMatrix3x3>!) {
    setMat3Value(&m.pointee, N00, 1)
    setMat3Value(&m.pointee, N11, 1)
    setMat3Value(&m.pointee, N22, 1)

    setMat3Value(&m.pointee, N01, 0)
    setMat3Value(&m.pointee, N02, 0)
    setMat3Value(&m.pointee, N10, 0)
    setMat3Value(&m.pointee, N12, 0)
    setMat3Value(&m.pointee, N20, 0)
    setMat3Value(&m.pointee, N21, 0)
}

// MARK: - OGL matrix 3x3 multiply

@c @implementation
public func OGLMatrix3x3_Multiply(_ mA: UnsafePointer<OGLMatrix3x3>!, _ mB: UnsafePointer<OGLMatrix3x3>!, _ result: UnsafeMutablePointer<OGLMatrix3x3>!) {
    var a = mA.pointee
    var b = mB.pointee

    let b00 = mat3Value(&b, N00); let b01 = mat3Value(&b, N10); let b02 = mat3Value(&b, N20)
    let b10 = mat3Value(&b, N01); let b11 = mat3Value(&b, N11); let b12 = mat3Value(&b, N21)
    let b20 = mat3Value(&b, N02); let b21 = mat3Value(&b, N12); let b22 = mat3Value(&b, N22)

    var ax0 = mat3Value(&a, N00); var ax1 = mat3Value(&a, N10)
    var ax2 = mat3Value(&a, N20)

    var r = result.pointee
    setMat3Value(&r, N00, ax0 * b00 + ax1 * b10 + ax2 * b20)
    setMat3Value(&r, N10, ax0 * b01 + ax1 * b11 + ax2 * b21)
    setMat3Value(&r, N20, ax0 * b02 + ax1 * b12 + ax2 * b22)

    ax0 = mat3Value(&a, N01); ax1 = mat3Value(&a, N11)
    ax2 = mat3Value(&a, N21)

    setMat3Value(&r, N01, ax0 * b00 + ax1 * b10 + ax2 * b20)
    setMat3Value(&r, N11, ax0 * b01 + ax1 * b11 + ax2 * b21)
    setMat3Value(&r, N21, ax0 * b02 + ax1 * b12 + ax2 * b22)

    ax0 = mat3Value(&a, N02); ax1 = mat3Value(&a, N12)
    ax2 = mat3Value(&a, N22)

    setMat3Value(&r, N02, ax0 * b00 + ax1 * b10 + ax2 * b20)
    setMat3Value(&r, N12, ax0 * b01 + ax1 * b11 + ax2 * b21)
    setMat3Value(&r, N22, ax0 * b02 + ax1 * b12 + ax2 * b22)

    result.pointee = r
}

// MARK: - OGL: is bbox visible
//
// Transform all the vertices into homogenous co-ordinates, and do
// clip tests. Return true if visible, false if fully clipped.
//
// INPUT: localToWorld = optional local->world transform matrix to be applied if bbox is not in world coords

func OGL_IsBBoxVisible(_ bBox: UnsafePointer<OGLBoundingBox>!, _ localToWorld: UnsafeMutablePointer<OGLMatrix4x4>?) -> UInt8 {
    var m2 = OGLMatrix4x4()

    // SEE IF FACTOR IN A LOCAL->WORLD MATRIX

    var m: UnsafeMutablePointer<OGLMatrix4x4>
    if let localToWorld {
        m2 = localToWorld.pointee.multiplied(by: gWorldToFrustumMatrix)
        m = withUnsafeMutablePointer(to: &m2) { $0 }
    } else {
        m = withUnsafeMutablePointer(to: &gWorldToFrustumMatrix) { $0 }
    }

    // GET LOCAL->FRUSTUM MATRIX

    let m00 = matValue(&m.pointee, M00)
    let m01 = matValue(&m.pointee, M01)
    let m02 = matValue(&m.pointee, M02)
    let m03 = matValue(&m.pointee, M03)
    let m10 = matValue(&m.pointee, M10)
    let m11 = matValue(&m.pointee, M11)
    let m12 = matValue(&m.pointee, M12)
    let m13 = matValue(&m.pointee, M13)
    let m20 = matValue(&m.pointee, M20)
    let m21 = matValue(&m.pointee, M21)
    let m22 = matValue(&m.pointee, M22)
    let m23 = matValue(&m.pointee, M23)
    let m30 = matValue(&m.pointee, M30)
    let m31 = matValue(&m.pointee, M31)
    let m32 = matValue(&m.pointee, M32)
    let m33 = matValue(&m.pointee, M33)

    // TRANSFORM THE BOUNDING BOX

    let minX = bBox.pointee.min.x // load bbox into registers
    let minY = bBox.pointee.min.y
    let minZ = bBox.pointee.min.z
    let maxX = bBox.pointee.max.x
    let maxY = bBox.pointee.max.y
    let maxZ = bBox.pointee.max.z

    var clipCodeAND: UInt32 = ~0

    for i in 0..<8 {
        var lX: Float = 0
        var lY: Float = 0
        var lZ: Float = 0

        switch i { // load current bbox corner in IX,IY,IZ
        case 0: lX = minX; lY = minY; lZ = minZ
        case 1: lX = minX; lY = minY; lZ = maxZ
        case 2: lX = minX; lY = maxY; lZ = minZ
        case 3: lX = minX; lY = maxY; lZ = maxZ
        case 4: lX = maxX; lY = minY; lZ = minZ
        case 5: lX = maxX; lY = minY; lZ = maxZ
        case 6: lX = maxX; lY = maxY; lZ = minZ
        default: lX = maxX; lY = maxY; lZ = maxZ
        }

        let hW = lX * m30 + lY * m31 + lZ * m32 + m33
        let hY = lX * m10 + lY * m11 + lZ * m12 + m13
        let hZ = lX * m20 + lY * m21 + lZ * m22 + m23
        let hX = lX * m00 + lY * m01 + lZ * m02 + m03

        let minusHW = -hW

        var clipFlags: UInt32

        // CHECK Y

        if hY < minusHW {
            clipFlags = 0x8
        } else if hY > hW {
            clipFlags = 0x4
        } else {
            clipFlags = 0
        }

        // CHECK Z

        if hZ > hW {
            clipFlags |= 0x20
        } else if hZ < 0.0 {
            clipFlags |= 0x10
        }

        // CHECK X

        if hX < minusHW {
            clipFlags |= 0x2
        } else if hX > hW {
            clipFlags |= 0x1
        }

        clipCodeAND &= clipFlags
    }

    if clipCodeAND != 0 {
        return 0
    } else {
        return 1
    }
}

// MARK: -

// MARK: - Create from-to rotation matrix
//
// Creates the rotation matrix that transforms v1 to v2.  The two vectors need not be normalized.
// The matrix rotates about v2xv1, by the angle between them.  If the vectors are opposing
// then rotation is done about some vector that is orthogonal to both.

@c @implementation
public func OGLCreateFromToRotationMatrix(_ matrix4x4: UnsafeMutablePointer<OGLMatrix4x4>!, _ v1: UnsafePointer<OGLVector3D>!, _ v2: UnsafePointer<OGLVector3D>!) {
    var axis = OGLVector3D()
    var orth = OGLVector3D()
    var proj = OGLVector3D()

    let zero: Float = 0.0
    let one: Float = 1.0
    let two: Float = 2.0

    // Determine the axis and the rotation angle

    let v1Var = v1.pointee
    let v2Var = v2.pointee
    axis = v2Var.cross(v1Var)

    var cosTheta = v2Var.dot(v1Var)
    var sinTheta = axis.dot(axis)

    if sinTheta <= Float(EPS) {
        // Vectors are either opposing or equal

        if cosTheta < zero {
            // Vectors are opposing

            axis = v2Var.normalized()

            var x = abs(axis.x)
            orth.x = one
            orth.y = zero
            orth.z = zero

            let y = abs(axis.y)
            if x > y {
                x = y
                orth.x = zero
                orth.y = one
                orth.z = zero
            }

            let z = abs(axis.z)
            if x > z {
                orth.x = zero
                orth.y = zero
                orth.z = one
            }

            let scale = axis.dot(orth)
            proj.x = axis.x * scale
            proj.y = axis.y * scale
            proj.z = axis.z * scale

            axis.x = orth.x - proj.x
            axis.y = orth.y - proj.y
            axis.z = orth.z - proj.z
            axis = axis.normalized()

            let ax = axis.x
            let ay = axis.y
            let az = axis.z

            setMatValue(&matrix4x4.pointee, M00, two * ax * ax - one)
            setMatValue(&matrix4x4.pointee, M10, two * ax * ay)
            setMatValue(&matrix4x4.pointee, M20, two * ax * az)
            setMatValue(&matrix4x4.pointee, M30, zero)

            setMatValue(&matrix4x4.pointee, M01, two * ax * ay)
            setMatValue(&matrix4x4.pointee, M11, two * ay * ay - one)
            setMatValue(&matrix4x4.pointee, M21, two * ay * az)
            setMatValue(&matrix4x4.pointee, M31, zero)

            setMatValue(&matrix4x4.pointee, M02, two * ax * az)
            setMatValue(&matrix4x4.pointee, M12, two * ay * az)
            setMatValue(&matrix4x4.pointee, M22, two * az * az - one)
            setMatValue(&matrix4x4.pointee, M32, zero)

            setMatValue(&matrix4x4.pointee, M03, zero)
            setMatValue(&matrix4x4.pointee, M13, zero)
            setMatValue(&matrix4x4.pointee, M23, zero)
            setMatValue(&matrix4x4.pointee, M33, one)
        } else {
            // Vectors are equal
            matrix4x4.pointee.setIdentity()
        }
    } else {
        let versTheta = 1.0 - cosTheta
        sinTheta = sqrt(sinTheta)

        var scale = one / sinTheta
        axis.x *= scale
        axis.y *= scale
        axis.z *= scale

        scale = one / v2Var.dot(v2Var)
        cosTheta *= scale
        sinTheta *= scale

        let x = axis.x
        let y = axis.y
        let z = axis.z

        // Diagonal terms
        setMatValue(&matrix4x4.pointee, M00, versTheta * (x * x) + cosTheta)
        setMatValue(&matrix4x4.pointee, M11, versTheta * (y * y) + cosTheta)
        setMatValue(&matrix4x4.pointee, M22, versTheta * (z * z) + cosTheta)

        // Skew terms
        var q1 = versTheta * x * y
        var q2 = sinTheta * z
        setMatValue(&matrix4x4.pointee, M10, q1 - q2)
        setMatValue(&matrix4x4.pointee, M01, q1 + q2)

        q1 = versTheta * x * z
        q2 = sinTheta * y
        setMatValue(&matrix4x4.pointee, M20, q1 + q2)
        setMatValue(&matrix4x4.pointee, M02, q1 - q2)

        q1 = versTheta * y * z
        q2 = sinTheta * x
        setMatValue(&matrix4x4.pointee, M21, q1 - q2)
        setMatValue(&matrix4x4.pointee, M12, q1 + q2)

        // 4x4 border around 3x3
        setMatValue(&matrix4x4.pointee, M30, zero)
        setMatValue(&matrix4x4.pointee, M31, zero)
        setMatValue(&matrix4x4.pointee, M32, zero)
        setMatValue(&matrix4x4.pointee, M03, zero)
        setMatValue(&matrix4x4.pointee, M13, zero)
        setMatValue(&matrix4x4.pointee, M23, zero)
        setMatValue(&matrix4x4.pointee, M33, one)
    }
}

// MARK: -

// MARK: - Fill projection matrix
//
// Result equivalent to matrix produced by gluPerspective
// Unlike the GLU version, fov is in RADIANS, not degrees!

@c @implementation
public func OGL_SetGluPerspectiveMatrix(_ m: UnsafeMutablePointer<OGLMatrix4x4>!, _ fov: Float, _ aspect: Float, _ hither: Float, _ yon: Float) {
    let cotan = 1.0 / tanf(fov / 2.0)
    let depth = hither - yon

    setMatValue(&m.pointee, M00, cotan / aspect); setMatValue(&m.pointee, M01, 0); setMatValue(&m.pointee, M02, 0); setMatValue(&m.pointee, M03, 0)
    setMatValue(&m.pointee, M10, 0); setMatValue(&m.pointee, M11, cotan); setMatValue(&m.pointee, M12, 0); setMatValue(&m.pointee, M13, 0)
    setMatValue(&m.pointee, M20, 0); setMatValue(&m.pointee, M21, 0); setMatValue(&m.pointee, M22, (yon + hither) / depth); setMatValue(&m.pointee, M23, 2 * yon * hither / depth)
    setMatValue(&m.pointee, M30, 0); setMatValue(&m.pointee, M31, 0); setMatValue(&m.pointee, M32, -1); setMatValue(&m.pointee, M33, 0)
}

// MARK: - Fill lookat matrix
//
// Result equivalent to matrix produced by gluLookAt

@c @implementation
public func OGL_SetGluLookAtMatrix(_ m: UnsafeMutablePointer<OGLMatrix4x4>!, _ eye: UnsafePointer<OGLPoint3D>!, _ target: UnsafePointer<OGLPoint3D>!, _ upDir: UnsafePointer<OGLVector3D>!) {
    // Forward = target - eye
    var fwd = OGLVector3D()
    fwd.x = target.pointee.x - eye.pointee.x
    fwd.y = target.pointee.y - eye.pointee.y
    fwd.z = target.pointee.z - eye.pointee.z
    fwd = fwd.normalized()

    // Side = forward x up
    var side = OGLVector3D()
    var upDirVar = upDir.pointee
    OGLVector3D_Cross_NoPin(&fwd, &upDirVar, &side)
    side = side.normalized()

    // Recompute up as: up = side x forward
    var up = OGLVector3D()
    OGLVector3D_Cross_NoPin(&side, &fwd, &up)

    // Premultiply by translation to eye position
    var eyeVec = OGLVector3D(x: eye.pointee.x, y: eye.pointee.y, z: eye.pointee.z)
    let tx = OGLVector3D_Dot_NoPin(&side, &eyeVec)
    let ty = OGLVector3D_Dot_NoPin(&up, &eyeVec)
    let tz = OGLVector3D_Dot_NoPin(&fwd, &eyeVec)

    setMatValue(&m.pointee, M00, side.x); setMatValue(&m.pointee, M01, side.y); setMatValue(&m.pointee, M02, side.z); setMatValue(&m.pointee, M03, -tx)
    setMatValue(&m.pointee, M10, up.x); setMatValue(&m.pointee, M11, up.y); setMatValue(&m.pointee, M12, up.z); setMatValue(&m.pointee, M13, -ty)
    setMatValue(&m.pointee, M20, -fwd.x); setMatValue(&m.pointee, M21, -fwd.y); setMatValue(&m.pointee, M22, -fwd.z); setMatValue(&m.pointee, M23, tz)
    setMatValue(&m.pointee, M30, 0); setMatValue(&m.pointee, M31, 0); setMatValue(&m.pointee, M32, 0); setMatValue(&m.pointee, M33, 1)
}

// MARK: - Unproject
//
// Result equivalent to point produced by gluUnProject

@c @implementation
public func OGL_GluUnProject(_ winPt: UnsafePointer<OGLPoint3D>!, _ modelview: UnsafePointer<OGLMatrix4x4>!, _ projection: UnsafePointer<OGLMatrix4x4>!, _ vpOffset: UnsafePointer<OGLPoint2D>!, _ vpSize: UnsafePointer<OGLVector2D>!, _ objPt: UnsafeMutablePointer<OGLPoint3D>!) {
    var m = OGLMatrix4x4()
    var inPt = OGLPoint3D()

    m = modelview.pointee.multiplied(by: projection.pointee)
    m = m.inverted()

    inPt = winPt.pointee

    // Map x and y from window coordinates
    inPt.x = (inPt.x - vpOffset.pointee.x) / vpSize.pointee.x
    inPt.y = (inPt.y - vpOffset.pointee.y) / vpSize.pointee.y

    // Map to range -1 to 1
    inPt.x = inPt.x * 2 - 1
    inPt.y = inPt.y * 2 - 1
    inPt.z = inPt.z * 2 - 1

    objPt.pointee = inPt.transformed(by: m)
}
