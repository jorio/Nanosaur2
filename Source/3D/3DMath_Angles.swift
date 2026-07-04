// 3DMath_Angles.swift - Port of the angle/turn-related functions in 3DMath.c to Swift.
// (First of several files splitting up 3DMath.c's large function set.)

// MARK: - Calc X angle from point to point
//
// Returns an unsigned result from 0 -> PI2

@c @implementation
public func CalcXAngleFromPointToPoint(_ oldRot: Float, _ from: UnsafePointer<OGLPoint3D>!, _ to: UnsafePointer<OGLPoint3D>!) -> Float {
    var aim = OGLVector3D()
    var flat = OGLVector3D()
    var cross = OGLVector3D()

    // CALC AIM VECTOR

    aim.x = to.pointee.x - from.pointee.x
    aim.y = to.pointee.y - from.pointee.y
    aim.z = to.pointee.z - from.pointee.z
    var aimNorm = OGLVector3D()
    OGLVector3D_Normalize(&aim, &aimNorm)
    aim = aimNorm

    if aim.x == 0.0 && aim.z == 0.0 { // verify vector
        return oldRot
    }

    if aim.y == 0.0 { // quick check to see if is flat
        return 0
    }

    // CALC A FLAT VECTOR

    flat.x = aim.x
    flat.z = aim.z
    flat.y = 0
    var flatNorm = OGLVector3D()
    OGLVector3D_Normalize(&flat, &flatNorm)
    flat = flatNorm

    // CALC ANGLE

    let dot = OGLVector3D_Dot(&aim, &flat)
    var angle = acos(dot)

    // NOW SEE IF WRAPPED PAST 180 DEGREES

    OGLVector3D_Cross(&aim, &flat, &cross) // get x-axis vector
    var crossNorm = OGLVector3D()
    OGLVector3D_Cross(&cross, &flat, &crossNorm) // get y-axis
    cross = crossNorm

    if cross.y < 0.0 {
        angle = SwPI2 - angle
    }

    return angle
}

// MARK: - Calc Y angle from point to point
//
// Returns an unsigned result from 0 -> PI2

@c @implementation
public func CalcYAngleFromPointToPoint(_ oldRot: Float, _ fromX: Float, _ fromZ: Float, _ toX: Float, _ toZ: Float) -> Float {
    let zax = OGLVector2D(x: 0, y: -1)
    var aim = OGLVector2D()

    // CALC AIM VECTOR

    aim.x = toX - fromX
    aim.y = toZ - fromZ
    FastNormalizeVector2D(aim.x, aim.y, &aim, 1)

    if aim.x == 0.0 && aim.y == 0.0 { // if bad vector then return old
        return oldRot
    }

    // CALC ANGLE

    var zaxVar = zax
    let dot = OGLVector2D_Dot(&zaxVar, &aim)
    var angle = acos(dot)

    // NOW SEE IF WRAPPED PAST 180 DEGREES

    let cross = OGLVector2D_Cross(&aim, &zaxVar)
    if cross < 0.0 {
        angle = SwPI2 - angle
    }

    return angle
}

// MARK: -

// MARK: - Turn object toward target
//
// INPUT:	theNode = object
//			from = from pt or uses theNode->Coord
//			x/z = target coords to aim towards
//			turnSpeed = turn speed, 0 == just return angle between
//
// OUTPUT:  remaining angle to target rot

@c @implementation
public func TurnObjectTowardTarget(_ theNode: UnsafeMutablePointer<ObjNode>!, _ from: UnsafePointer<OGLPoint3D>?, _ toXIn: Float, _ toZIn: Float, _ turnSpeedIn: Float, _ useOffsets: UInt8, _ crossOut: UnsafeMutablePointer<Float>?) -> Float {
    var toX = toXIn
    var toZ = toZIn
    var turnSpeed = turnSpeedIn
    var aimVec = OGLVector2D()
    var targetVec = OGLVector2D()

    // CALC FROM/TO COORDS

    if useOffsets != 0 {
        toX += theNode.pointee.TargetOff.x // offset coord
        toZ += theNode.pointee.TargetOff.z
    }

    let fromX: Float
    let fromZ: Float
    if let from {
        fromX = from.pointee.x
        fromZ = from.pointee.z
    } else {
        fromX = theNode.pointee.Coord.x
        fromZ = theNode.pointee.Coord.z
    }

    // CALC ANGLE BETWEEN AIM AND TARGET

    let r = theNode.pointee.Rot.y // get normalized vector in direction of current aim
    aimVec.x = -sin(r)
    aimVec.y = -cos(r)

    targetVec.x = toX - fromX // get normalized vector to target object
    targetVec.y = toZ - fromZ
    var targetVecNorm = OGLVector2D()
    OGLVector2D_Normalize(&targetVec, &targetVecNorm) // do ACCURATE normalize to avoid jitter!!!
    targetVec = targetVecNorm
    if targetVec.x == 0.0 && targetVec.y == 0.0 {
        return 0
    }

    let angle = acos(OGLVector2D_Dot(&aimVec, &targetVec)) // dot == angle to turn
    let cross = OGLVector2D_Cross(&aimVec, &targetVec) // sign of cross tells us which way to turn

    // DO THE TURN

    if turnSpeed != 0.0 {
        turnSpeed *= gFramesPerSecondFrac // calc amount to turn this frame

        if turnSpeed > abs(angle) { // make sure we dont exceed how far we want to go
            turnSpeed = abs(angle)
        }

        if cross > 0.0 { // see which direction
            turnSpeed = -turnSpeed
        }

        theNode.pointee.Rot.y += turnSpeed // turn it!
    }

    if let crossOut {
        crossOut.pointee = cross // pass back cross product
    }

    return angle - abs(turnSpeed) // return angular distance to target
}

// MARK: - Turn object toward target 2D

@c @implementation
public func TurnObjectTowardTarget2D(_ theNode: UnsafeMutablePointer<ObjNode>!, _ fromX: Float, _ fromY: Float, _ toX: Float, _ toY: Float, _ turnSpeedIn: Float) -> Float {
    var turnSpeed = turnSpeedIn
    var aimVec = OGLVector2D()
    var targetVec = OGLVector2D()

    // CALC ANGLE BETWEEN AIM AND TARGET

    let r = theNode.pointee.Rot.y // get normalized vector in direction of current aim
    aimVec.x = sin(r)
    aimVec.y = -cos(r)

    targetVec.x = toX - fromX // get normalized vector to target object
    targetVec.y = toY - fromY
    var targetVecNorm = OGLVector2D()
    OGLVector2D_Normalize(&targetVec, &targetVecNorm) // do ACCURATE normalize to avoid jitter!!!
    targetVec = targetVecNorm
    if targetVec.x == 0.0 && targetVec.y == 0.0 {
        return 0
    }

    let angle = acos(OGLVector2D_Dot(&aimVec, &targetVec)) // dot == angle to turn
    let cross = OGLVector2D_Cross(&aimVec, &targetVec) // sign of cross tells us which way to turn

    // DO THE TURN

    if turnSpeed != 0.0 {
        turnSpeed *= gFramesPerSecondFrac // calc amount to turn this frame

        if turnSpeed > abs(angle) { // make sure we dont exceed how far we want to go
            turnSpeed = abs(angle)
        }

        if cross < 0.0 { // see which direction
            turnSpeed = -turnSpeed
        }

        theNode.pointee.Rot.y += turnSpeed // turn it!
    }
    return angle - abs(turnSpeed) // return angular distance to target
}

// MARK: - Turn object toward player
//
// INPUT:	theNode = object
//			from = from pt or uses theNode->Coord
//			turnSpeed = turn speed, 0 == just return angle between
//
// OUTPUT:  remaining angle to target rot

@c @implementation
public func TurnObjectTowardPlayer(_ playerNum: Int16, _ theNode: UnsafeMutablePointer<ObjNode>!, _ from: UnsafePointer<OGLPoint3D>?, _ turnSpeedIn: Float, _ thresholdAngle: Float, _ turnDirection: UnsafeMutablePointer<Float>!) -> Float {
    var turnSpeed = turnSpeedIn
    var aimVec = OGLVector2D()
    var targetVec = OGLVector2D()

    // CALC FROM/TO COORDS

    let fromX: Float
    let fromZ: Float
    if let from {
        fromX = from.pointee.x
        fromZ = from.pointee.z
    } else {
        fromX = theNode.pointee.Coord.x
        fromZ = theNode.pointee.Coord.z
    }

    // CALC ANGLE BETWEEN AIM AND TARGET

    let r = theNode.pointee.Rot.y // get normalized vector in direction of current aim
    aimVec.x = -sin(r)
    aimVec.y = -cos(r)

    let pi = GetPlayerInfoEntry(Int32(playerNum))!
    targetVec.x = pi.pointee.coord.x - fromX // get normalized vector to target object
    targetVec.y = pi.pointee.coord.z - fromZ
    var targetVecNorm = OGLVector2D()
    OGLVector2D_Normalize(&targetVec, &targetVecNorm) // do ACCURATE normalize to avoid jitter!!!
    targetVec = targetVecNorm
    if targetVec.x == 0.0 && targetVec.y == 0.0 {
        turnDirection.pointee = 0
        return 0
    }

    let angle = acos(OGLVector2D_Dot(&aimVec, &targetVec)) // dot == angle to turn
    if angle <= thresholdAngle { // see if in threshold
        turnDirection.pointee = 0
        return angle
    }

    let cross = OGLVector2D_Cross(&aimVec, &targetVec) // sign of cross tells us which way to turn

    // DO THE TURN

    if turnSpeed != 0.0 {
        turnSpeed *= gFramesPerSecondFrac // calc amount to turn this frame

        if turnSpeed > abs(angle) { // make sure we dont exceed how far we want to go
            turnSpeed = abs(angle)
        }

        if cross > 0.0 { // see which direction
            turnSpeed = -turnSpeed
        }

        theNode.pointee.Rot.y += turnSpeed // turn it!
    }

    turnDirection.pointee = cross
    return angle - abs(turnSpeed) // return angular distance to target
}

// MARK: - Turn object toward target on X
//
// same as above except rotates on X axis to pitch object up/down toward target

@c @implementation
public func TurnObjectTowardTargetOnX(_ theNode: UnsafeMutablePointer<ObjNode>!, _ from: UnsafePointer<OGLPoint3D>!, _ to: UnsafePointer<OGLPoint3D>!, _ turnSpeedIn: Float) -> Float {
    var turnSpeed = turnSpeedIn
    var targetVecFlat = OGLVector3D()
    var targetVec = OGLVector3D()
    var cross = OGLVector3D()

    // CALC ANGLE BETWEEN AIM AND TARGET

    targetVec.x = to.pointee.x - from.pointee.x // calc vector to target
    targetVec.y = to.pointee.y - from.pointee.y
    targetVec.z = to.pointee.z - from.pointee.z
    var targetVecNorm = OGLVector3D()
    OGLVector3D_Normalize(&targetVec, &targetVecNorm) // do ACCURATE normalize to avoid jitter!!!
    targetVec = targetVecNorm

    if targetVec.x == 0.0 && targetVec.y == 0.0 {
        return 0
    }

    targetVecFlat.x = targetVec.x // x/z plane aim vector
    targetVecFlat.z = targetVec.z
    targetVecFlat.y = sin(theNode.pointee.Rot.x)
    var targetVecFlatNorm = OGLVector3D()
    OGLVector3D_Normalize(&targetVecFlat, &targetVecFlatNorm)
    targetVecFlat = targetVecFlatNorm

    let angle = acos(OGLVector3D_Dot(&targetVecFlat, &targetVec)) // calc angle between them
    OGLVector3D_Cross(&targetVecFlat, &targetVec, &cross) // calc perpendicular vector
    var crossNorm2 = OGLVector3D()
    OGLVector3D_Cross(&cross, &targetVecFlat, &crossNorm2) // calc another vector who's y will tell us direction to rotate
    cross = crossNorm2

    // DO THE TURN

    if turnSpeed != 0.0 {
        turnSpeed *= gFramesPerSecondFrac // calc amount to turn this frame

        if turnSpeed > angle { // make sure we dont exceed how far we want to go
            turnSpeed = angle
        }

        if cross.y < 0.0 { // see which direction
            turnSpeed = -turnSpeed
        }

        theNode.pointee.Rot.x += turnSpeed // turn it!
    }
    return angle - abs(turnSpeed) // return angular distance to target
}

// MARK: - Turn point toward point
//
// NOTE: turnSpeed is already multipled by gFramesPerSecondFrac

@c @implementation
public func TurnPointTowardPoint(_ rotY: UnsafeMutablePointer<Float>!, _ from: UnsafeMutablePointer<OGLPoint3D>!, _ toX: Float, _ toZ: Float, _ turnSpeedIn: Float) -> Float {
    var turnSpeed = turnSpeedIn
    var aimVec = OGLVector2D()
    var targetVec = OGLVector2D()

    let fromX = from.pointee.x
    let fromZ = from.pointee.z

    // CALC ANGLE BETWEEN AIM AND TARGET

    aimVec.x = -sin(rotY.pointee)
    aimVec.y = -cos(rotY.pointee)

    targetVec.x = toX - fromX // get normalized vector to target object
    targetVec.y = toZ - fromZ
    var targetVecNorm = OGLVector2D()
    OGLVector2D_Normalize(&targetVec, &targetVecNorm) // do ACCURATE normalize to avoid jitter!!!
    targetVec = targetVecNorm
    if targetVec.x == 0.0 && targetVec.y == 0.0 {
        return 0
    }

    let angle = acos(OGLVector2D_Dot(&aimVec, &targetVec)) // dot == angle to turn
    let cross = OGLVector2D_Cross(&aimVec, &targetVec) // sign of cross tells us which way to turn

    // DO THE TURN

    if turnSpeed != 0.0 {
        // turnSpeed *= gFramesPerSecondFrac // calc amount to turn this frame

        if turnSpeed > angle { // make sure we dont exceed how far we want to go
            turnSpeed = angle
        }

        if cross > 0.0 { // see which direction
            turnSpeed = -turnSpeed
        }

        rotY.pointee += turnSpeed // turn it!
    }
    return angle - abs(turnSpeed) // return angular distance to target
}

// MARK: -

// MARK: - Calc point on object
//
// Uses the input ObjNode's BaseTransformMatrix to transform the input point.

@c @implementation
public func CalcPointOnObject(_ theNode: UnsafePointer<ObjNode>!, _ inPt: UnsafePointer<OGLPoint3D>!, _ outPt: UnsafeMutablePointer<OGLPoint3D>!) {
    var m = theNode.pointee.BaseTransformMatrix
    var inPtVar = inPt.pointee
    OGLPoint3D_Transform(&inPtVar, &m, outPt)
}

// MARK: - Vectors are close enough

@c @implementation
public func VectorsAreCloseEnough(_ v1: UnsafePointer<OGLVector3D>!, _ v2: UnsafePointer<OGLVector3D>!) -> UInt8 {
    if abs(v1.pointee.x - v2.pointee.x) < 0.02 { // WARNING: If change, must change in BioOreoPro also!!
        if abs(v1.pointee.y - v2.pointee.y) < 0.02 {
            if abs(v1.pointee.z - v2.pointee.z) < 0.02 {
                return 1
            }
        }
    }

    return 0
}

// MARK: - Points are close enough

@c @implementation
public func PointsAreCloseEnough(_ v1: UnsafePointer<OGLPoint3D>!, _ v2: UnsafePointer<OGLPoint3D>!) -> UInt8 {
    if abs(v1.pointee.x - v2.pointee.x) < 0.0001 { // WARNING: If change, must change in BioOreoPro also!!
        if abs(v1.pointee.y - v2.pointee.y) < 0.0001 {
            if abs(v1.pointee.z - v2.pointee.z) < 0.0001 {
                return 1
            }
        }
    }

    return 0
}
