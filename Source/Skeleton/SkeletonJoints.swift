// SkeletonJoints.swift - Port of SkeletonJoints.c (formerly Skeleton2.c) to Swift

private let M00: Int32 = 0
private let M11: Int32 = 5
private let M22: Int32 = 10
private let M03: Int32 = 12
private let M13: Int32 = 13
private let M23: Int32 = 14

// Mirrors the C function-local `static OGLMatrix4x4 matrix2` in
// UpdateJointTransforms: only M00/M11/M22/M03/M13/M23 are ever written, so
// the other entries permanently keep their initial values (0, except M33=1).
private var gScaleTranslateMatrix: OGLMatrix4x4 = {
    var m = OGLMatrix4x4()
    setMatValue(&m, 15, 1) // M33
    return m
}()

// Updates ALL of the transforms in a joint's transform group based on the theNode->Skeleton->JointCurrentPosition
//
// INPUT: jointNum = joint # to rotate
@c @implementation
public func UpdateJointTransforms(_ skeleton: UnsafeMutablePointer<SkeletonObjDataType>!, _ jointNum: Int) {
    let jointMatricesBase = UnsafeMutableRawPointer(skeleton.pointer(to: \.jointTransformMatrix)!).assumingMemoryBound(to: OGLMatrix4x4.self)
    let destMatPtr = jointMatricesBase + jointNum // get ptr to joint's xform matrix

    let jointPosBase = UnsafeMutableRawPointer(skeleton.pointer(to: \.JointCurrentPosition)!).assumingMemoryBound(to: JointKeyframeType.self)
    let kfPtr = jointPosBase + jointNum // get ptr to keyframe

    if kfPtr.pointee.scale.x != 1.0 || kfPtr.pointee.scale.y != 1.0 || kfPtr.pointee.scale.z != 1.0 { // SEE IF CAN IGNORE SCALE
        // ROTATE IT
        var matrix1 = OGLMatrix4x4()
        OGLMatrix4x4_SetRotate_XYZ(&matrix1, kfPtr.pointee.rotation.x, kfPtr.pointee.rotation.y, kfPtr.pointee.rotation.z) // set matrix for x/y/z rot

        // SCALE & TRANSLATE
        setMatValue(&gScaleTranslateMatrix, M00, kfPtr.pointee.scale.x)
        setMatValue(&gScaleTranslateMatrix, M11, kfPtr.pointee.scale.y)
        setMatValue(&gScaleTranslateMatrix, M22, kfPtr.pointee.scale.z)
        setMatValue(&gScaleTranslateMatrix, M03, kfPtr.pointee.coord.x)
        setMatValue(&gScaleTranslateMatrix, M13, kfPtr.pointee.coord.y)
        setMatValue(&gScaleTranslateMatrix, M23, kfPtr.pointee.coord.z)

        OGLMatrix4x4_Multiply(&matrix1, &gScaleTranslateMatrix, destMatPtr)
    } else {
        // ROTATE IT
        OGLMatrix4x4_SetRotate_XYZ(destMatPtr, kfPtr.pointee.rotation.x, kfPtr.pointee.rotation.y, kfPtr.pointee.rotation.z) // set matrix for x/y/z rot

        // NOW TRANSLATE IT
        setMatValue(&destMatPtr.pointee, M03, kfPtr.pointee.coord.x)
        setMatValue(&destMatPtr.pointee, M13, kfPtr.pointee.coord.y)
        setMatValue(&destMatPtr.pointee, M23, kfPtr.pointee.coord.z)
    }
}

// Returns the 3-space coord of the given joint.
@c @implementation
public func FindCoordOfJoint(_ theNode: UnsafeMutablePointer<ObjNode>!, _ jointNum: Int, _ outPoint: UnsafeMutablePointer<OGLPoint3D>!) {
    var matrix = OGLMatrix4x4()
    var point3D = OGLPoint3D(x: 0, y: 0, z: 0) // use joint's origin @ 0,0,0

    FindJointFullMatrix(theNode, jointNum, &matrix) // calc matrix
    OGLPoint3D_Transform(&point3D, &matrix, outPoint) // apply matrix to origin @ 0,0,0 to get new 3-space coords
}

// Returns the 3-space coord of a point on the given joint.
//
// Essentially the same as FindCoordOfJoint except that rather than
// using 0,0,0 as the applied point, it takes the input point which
// is an offset from the origin of the joint. Thus, the returned point
// is "on" the joint rather than the exact coord of the hinge.
@c @implementation
public func FindCoordOnJoint(_ theNode: UnsafeMutablePointer<ObjNode>!, _ jointNum: Int, _ inPoint: UnsafePointer<OGLPoint3D>!, _ outPoint: UnsafeMutablePointer<OGLPoint3D>!) {
    var matrix = OGLMatrix4x4()

    FindJointFullMatrix(theNode, jointNum, &matrix) // calc matrix
    OGLPoint3D_Transform(inPoint, &matrix, outPoint) // apply matrix to origin @ 0,0,0 to get new 3-space coords
}

// Same as above except that it finds the coordinate on the skeleton structure
// at the EXACT moment that the Flag event occurred.
@c @implementation
public func FindCoordOnJointAtFlagEvent(_ theNode: UnsafeMutablePointer<ObjNode>!, _ jointNum: Int, _ inPoint: UnsafePointer<OGLPoint3D>!, _ outPoint: UnsafeMutablePointer<OGLPoint3D>!) {
    var matrix = OGLMatrix4x4()
    var time: Int16 = 0

    // GET THE TIME OF THE 1ST FLAG EVENT

    let skeleton = theNode.pointee.Skeleton!
    let animNum = skeleton.pointee.AnimNum

    let skeletonDef = skeleton.pointee.skeletonDefinition!
    let numEvents = skeletonDef.pointee.NumAnimEvents![Int(animNum)]

    var i: UInt8 = 0
    while i < numEvents {
        let event = skeletonDef.pointee.AnimEventsList![Int(animNum)]![Int(i)]
        if event.type == UInt8(ANIMEVENT_TYPE_SETFLAG) {
            time = event.time
            break
        }
        i += 1
    }

    // TEMPORARILY SET THE TIME TO THE TIME OF THE FLAG EVENT

    let oldTime = skeleton.pointee.CurrentAnimTime // remember what time it is
    skeleton.pointee.CurrentAnimTime = Float(time) // set to time of flag event
    GetModelCurrentPosition(skeleton) // reset all of the matrices

    // CALC THE COORD

    FindJointFullMatrix(theNode, jointNum, &matrix) // calc matrix
    OGLPoint3D_Transform(inPoint, &matrix, outPoint) // apply matrix to origin @ 0,0,0 to get new 3-space coords

    // SET THINGS BACK TO NORMAL

    skeleton.pointee.CurrentAnimTime = oldTime
    GetModelCurrentPosition(skeleton) // reset all of the matrices to original positions
}

@c @implementation
public func FindJointMatrixAtFlagEvent(_ theNode: UnsafeMutablePointer<ObjNode>!, _ jointNum: Int, _ flagNum: UInt8, _ m: UnsafeMutablePointer<OGLMatrix4x4>!) {
    var time: Int16 = 0

    // GET THE TIME OF THE 1ST FLAG EVENT

    let skeleton = theNode.pointee.Skeleton!
    let skelDef = skeleton.pointee.skeletonDefinition!
    let numEvents = skelDef.pointee.NumAnimEvents![Int(skeleton.pointee.AnimNum)]

    var i: UInt8 = 0
    while i < numEvents {
        let event = skelDef.pointee.AnimEventsList![Int(skeleton.pointee.AnimNum)]![Int(i)]
        if event.type == UInt8(ANIMEVENT_TYPE_SETFLAG) { // is setflag?
            if event.value == flagNum { // is for flag #n?
                time = event.time
                break
            }
        }
        i += 1
    }

    // TEMPORARILY SET THE TIME TO THE TIME OF THE FLAG EVENT

    let oldTime = skeleton.pointee.CurrentAnimTime // remember what time it is
    skeleton.pointee.CurrentAnimTime = Float(time) // set to time of flag event
    GetModelCurrentPosition(skeleton) // reset all of the matrices

    // CALC THE COORD

    FindJointFullMatrix(theNode, jointNum, m) // calc matrix

    // SET THINGS BACK TO NORMAL

    skeleton.pointee.CurrentAnimTime = oldTime
    GetModelCurrentPosition(skeleton) // reset all of the matrices to original positions
}

// Returns an accumulated matrix for a joint's coordinates.
@c @implementation
public func FindJointFullMatrix(_ theNode: UnsafeMutablePointer<ObjNode>!, _ jointNum: Int, _ outMatrix: UnsafeMutablePointer<OGLMatrix4x4>!) {
    var jointNum = jointNum

    // ACCUMULATE A MATRIX DOWN THE CHAIN

    let initialJointsBase = UnsafeMutableRawPointer(theNode.pointee.Skeleton!.pointer(to: \.jointTransformMatrix)!).assumingMemoryBound(to: OGLMatrix4x4.self)
    outMatrix.pointee = initialJointsBase[jointNum] // init matrix

    let skeletonPtr = theNode.pointee.Skeleton // point to skeleton
    guard let skeletonPtr else { // if nothing, then return coord matrix
        OGLMatrix4x4_SetTranslate(outMatrix, theNode.pointee.Coord.x, theNode.pointee.Coord.y, theNode.pointee.Coord.z)
        return
    }

    let skeletonDefPtr = skeletonPtr.pointee.skeletonDefinition! // point to skeleton defintion

    if jointNum >= Int(skeletonDefPtr.pointee.NumBones) || jointNum < 0 { // check for illegal joints
        SwFatal("FindJointFullMatrix: illegal jointNum!")
    }

    let bonePtr = skeletonDefPtr.pointee.Bones! // point to bones list

    while bonePtr[jointNum].parentBone != Int(NO_PREVIOUS_JOINT) {
        jointNum = Int(bonePtr[jointNum].parentBone)

        let jointsBase = UnsafeMutableRawPointer(skeletonPtr.pointer(to: \.jointTransformMatrix)!).assumingMemoryBound(to: OGLMatrix4x4.self)
        OGLMatrix4x4_Multiply(outMatrix, jointsBase + jointNum, outMatrix)
    }

    // ALSO FACTOR IN THE BASE MATRIX
    //
    // Caller should make sure this is up to date!

    OGLMatrix4x4_Multiply(outMatrix, theNode.pointer(to: \.BaseTransformMatrix)!, outMatrix)
}
