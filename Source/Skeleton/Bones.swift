// Bones.swift - Port of Bones.c to Swift
//
// The DecomposeVertexArrayGeometry "find matching point/normal, or add a
// new one" logic used `goto added_vert`/`goto added_norm` to jump past the
// insertion branch once a match was found. Swift has no goto; restructured
// using a found-index sentinel (-1 == not found) instead, which is the
// closest equivalent to the original control flow without introducing a
// real behavioral difference. #if defined(__ppc__) is dead code on this
// arm64-only build; dropped, matching the SKIPFLUFF/VERTEXARRAYRANGES
// precedent elsewhere in this port.

// Not declared in any header, not referenced from any other C file despite
// lacking `static` — private is safe here (same situation Enemy.swift's
// file-scoped statics were in).
private var gCurrentSkeleton: UnsafeMutablePointer<SkeletonDefType>?
private var gCurrentSkelObjData: UnsafeMutablePointer<SkeletonObjDataType>?
private var gMatrix = OGLMatrix4x4()
private var gBBox: UnsafeMutablePointer<OGLBoundingBox>?
private var gTransformedNormals: InlineArray<2000, OGLVector3D> = InlineArray(repeating: OGLVector3D())

// MARK: - Fixed-array-field helpers (all plain struct fields, never unions)

@inline(__always) private func numChildrenBase(_ skel: UnsafeMutablePointer<SkeletonDefType>) -> UnsafeMutablePointer<UInt8> {
    UnsafeMutableRawPointer(skel.pointer(to: \.numChildren)!).assumingMemoryBound(to: UInt8.self)
}
@inline(__always) private func childIndeciesBase(_ skel: UnsafeMutablePointer<SkeletonDefType>) -> UnsafeMutablePointer<UInt8> {
    UnsafeMutableRawPointer(skel.pointer(to: \.childIndecies)!).assumingMemoryBound(to: UInt8.self)
}
@inline(__always) private func decomposedTriMeshesBase(_ skel: UnsafeMutablePointer<SkeletonDefType>) -> UnsafeMutablePointer<MOVertexArrayData> {
    UnsafeMutableRawPointer(skel.pointer(to: \.decomposedTriMeshes)!).assumingMemoryBound(to: MOVertexArrayData.self)
}
@inline(__always) private func deformedMeshesBase(_ skelObjData: UnsafeMutablePointer<SkeletonObjDataType>) -> UnsafeMutablePointer<MOVertexArrayData> {
    UnsafeMutableRawPointer(skelObjData.pointer(to: \.deformedMeshes)!).assumingMemoryBound(to: MOVertexArrayData.self)
}
@inline(__always) private func jointTransformMatrixBase(_ skelObjData: UnsafeMutablePointer<SkeletonObjDataType>) -> UnsafeMutablePointer<OGLMatrix4x4> {
    UnsafeMutableRawPointer(skelObjData.pointer(to: \.jointTransformMatrix)!).assumingMemoryBound(to: OGLMatrix4x4.self)
}
private let kDeformedMeshesStride = Int(MAX_DECOMPOSED_TRIMESHES)

@inline(__always) private func whichTriMeshBase(_ p: UnsafeMutablePointer<DecomposedPointType>) -> UnsafeMutablePointer<UInt8> {
    UnsafeMutableRawPointer(p.pointer(to: \.whichTriMesh)!).assumingMemoryBound(to: UInt8.self)
}
@inline(__always) private func whichPointBase(_ p: UnsafeMutablePointer<DecomposedPointType>) -> UnsafeMutablePointer<Int16> {
    UnsafeMutableRawPointer(p.pointer(to: \.whichPoint)!).assumingMemoryBound(to: Int16.self)
}
@inline(__always) private func whichNormalBase(_ p: UnsafeMutablePointer<DecomposedPointType>) -> UnsafeMutablePointer<Int16> {
    UnsafeMutableRawPointer(p.pointer(to: \.whichNormal)!).assumingMemoryBound(to: Int16.self)
}

// INPUT: inSpec = spec of 3dmf file to load or nil to StdDialog it.
@c @implementation
public func LoadBonesReferenceModel(_ inSpec: UnsafeMutablePointer<FSSpec>!, _ skeleton: UnsafeMutablePointer<SkeletonDefType>!, _ skeletonType: Int32) {
    gCurrentSkeleton = skeleton

    let g = Int32(MODEL_GROUP_SKELETONBASE) + skeletonType // calc group # to store model into
    ImportBG3D(inSpec, g, -1) // load skeleton model (no VAR memory)

    let model = GetBG3DContainerRoot(g) // point to base group

    decomposeReferenceModel(model)
}

private func decomposeReferenceModel(_ theModel: MetaObjectPtr?) {
    gCurrentSkeleton!.pointee.numDecomposedTriMeshes = 0
    gCurrentSkeleton!.pointee.numDecomposedPoints = 0
    gCurrentSkeleton!.pointee.numDecomposedNormals = 0

    // DO SUBRECURSIVE SCAN

    decompRefMoRecurse(theModel)
}

private func decompRefMoRecurse(_ inObj: MetaObjectPtr?) {
    guard let inObj else { return }
    let head = inObj.assumingMemoryBound(to: MetaObjectHeader.self) // convert to header ptr

    // SEE IF FOUND GEOMETRY

    if head.pointee.type == .geometry {
        if head.pointee.subType == MO_GEOMETRY_SUBTYPE_VERTEXARRAY {
            decomposeVertexArrayGeometry(inObj.assumingMemoryBound(to: MOVertexArrayObject.self))
        } else {
            SwFatal("DecompRefMo_Recurse: unknown geometry subtype")
        }
    }

    // SEE IF RECURSE SUB-GROUP

    else if head.pointee.type == .group {
        let groupObj = inObj.assumingMemoryBound(to: MOGroupObject.self)
        let groupData = groupObj.pointer(to: \.objectData)! // point to group data
        let groupContentsBase = UnsafeMutableRawPointer(groupData.pointer(to: \.groupContents)!).assumingMemoryBound(to: UnsafeMutableRawPointer?.self)

        for i in 0..<Int(groupData.pointee.numObjectsInGroup) { // scan all objects in group
            let subObj = groupContentsBase[i] // get illegal ref to object in group
            decompRefMoRecurse(subObj) // sub-recurse this object
        }
    }
}

private func decomposeVertexArrayGeometry(_ theTriMesh: UnsafeMutablePointer<MOVertexArrayObject>) {
    let skeleton = gCurrentSkeleton!

    let n = Int(skeleton.pointee.numDecomposedTriMeshes) // get index into list of trimeshes
    if n >= Int(MAX_DECOMPOSED_TRIMESHES) {
        SwFatal("DecomposeATriMesh: gNumDecomposedTriMeshes > MAX_DECOMPOSED_TRIMESHES")
    }

    // GET TRIMESH DATA

    let triMeshesBase = decomposedTriMeshesBase(skeleton)
    triMeshesBase[n] = theTriMesh.pointee.objectData // copy vertex array geometry data
                                                      // NOTE that this also creates
                                                      // new ILLEGAL refs to any material objects
    let data = triMeshesBase + n

    let numVertecies = Int(data.pointee.numPoints) // get # verts in trimesh
    let vertexList = data.pointee.points! // point to vert list
    let normalPtr = data.pointee.normals! // point to normals

    // EXTRACT VERTECIES & NORMALS

    for vertNum in 0..<numVertecies {
        var refNum = 0
        var pointNum = -1 // -1 == not found among existing points

        // SEE IF THIS POINT IS ALREADY IN DECOMPOSED LIST

        for pn in 0..<Int(skeleton.pointee.numDecomposedPoints) {
            let candidate = skeleton.pointee.decomposedPointList! + pn // point to this decomposed point

            if PointsAreCloseEnough(vertexList + vertNum, &candidate.pointee.realPoint) != 0 { // see if close enough to match
                // ADD ANOTHER REFERENCE

                refNum = Int(candidate.pointee.numRefs) // get # refs for this point
                if refNum >= Int(MAX_POINT_REFS) {
                    SwFatal("DecomposeATriMesh: MAX_POINT_REFS exceeded!")
                }

                whichTriMeshBase(candidate)[refNum] = UInt8(n) // set triMesh #
                whichPointBase(candidate)[refNum] = Int16(vertNum) // set point #
                candidate.pointee.numRefs += 1 // inc counter
                pointNum = pn
                break
            }
        }

        let decomposedPoint: UnsafeMutablePointer<DecomposedPointType>
        if pointNum >= 0 {
            decomposedPoint = skeleton.pointee.decomposedPointList! + pointNum
        } else {
            // IT'S A NEW POINT SO ADD TO LIST

            pointNum = Int(skeleton.pointee.numDecomposedPoints)
            if pointNum >= Int(MAX_DECOMPOSED_POINTS) {
                SwFatal("DecomposeATriMesh: MAX_DECOMPOSED_POINTS exceeded!")
            }

            refNum = 0 // it's the 1st entry (need refNum for below).

            decomposedPoint = skeleton.pointee.decomposedPointList! + pointNum // point to this decomposed point
            decomposedPoint.pointee.realPoint = vertexList[vertNum] // add new point to list
            whichTriMeshBase(decomposedPoint)[refNum] = UInt8(n) // set triMesh #
            whichPointBase(decomposedPoint)[refNum] = Int16(vertNum) // set point #
            decomposedPoint.pointee.numRefs = 1 // set # refs to 1

            skeleton.pointee.numDecomposedPoints += 1 // inc # decomposed points
        }

        // ADD THIS POINT'S NORMAL TO THE NORMALS LIST

        // SEE IF NORMAL ALREADY IN LIST

        var normalIndex = -1
        for i in 0..<Int(skeleton.pointee.numDecomposedNormals) {
            if VectorsAreCloseEnough(normalPtr + vertNum, &skeleton.pointee.decomposedNormalsList![i]) != 0 { // if already in list, then dont add it again
                normalIndex = i
                break
            }
        }

        if normalIndex < 0 {
            // ADD NEW NORMAL TO LIST

            let i = Int(skeleton.pointee.numDecomposedNormals) // get # decomposed normals already in list
            if i >= Int(MAX_DECOMPOSED_NORMALS) {
                SwFatal("DecomposeATriMesh: MAX_DECOMPOSED_NORMALS exceeded!")
            }

            skeleton.pointee.decomposedNormalsList![i] = normalPtr[vertNum] // add new normal to list
            skeleton.pointee.numDecomposedNormals += 1 // inc # decomposed normals
            normalIndex = i
        }

        // KEEP REF TO NORMAL IN POINT LIST

        whichNormalBase(decomposedPoint)[refNum] = Int16(normalIndex) // save index to normal
    }

    skeleton.pointee.numDecomposedTriMeshes += 1 // inc # of trimeshes in decomp list
}

// Updates all of the points in the local trimesh data to coordinate with the
// current joint transforms.
@c @implementation
public func UpdateSkinnedGeometry(_ theNode: UnsafeMutablePointer<ObjNode>!) {
    guard let currentSkelObjData = theNode.pointee.Skeleton else {
        return
    }
    gCurrentSkelObjData = currentSkelObjData

    guard let skeletonDef = currentSkelObjData.pointee.skeletonDefinition else {
        SwFatal("UpdateSkinnedGeometry: gCurrentSkeleton is invalid!")
        return
    }
    gCurrentSkeleton = skeletonDef

    // TOGGLE VERTEX ARRAY DOUBLE-BUFFER

    theNode.pointee.VertexArrayMode = UInt8(Int32(VertexArrayRangeType.skeletons.rawValue) + Int32(gGameViewInfoPtr!.pointee.frameCount & 1))

    // INIT BBOX
    //
    // For skeletons, we want to build a world-space Bounding Box.
    // This makes our LineSegment->triangle collision functions faster
    // since we don't have to do our lineseg->sphere tests.  The
    // lineseg->bbox test is faster and more accurate.

    let bbox = theNode.pointer(to: \.WorldBBox)! // point objnode's world-space bbox
    gBBox = bbox

    bbox.pointee.min.x = 10_000_000
    bbox.pointee.min.y = 10_000_000
    bbox.pointee.min.z = 10_000_000
    bbox.pointee.max.x = -bbox.pointee.min.x // init bounding box calc
    bbox.pointee.max.y = -bbox.pointee.min.y
    bbox.pointee.max.z = -bbox.pointee.min.z

    if Int32(skeletonDef.pointee.Bones![0].parentBone) != Int32(NO_PREVIOUS_JOINT) {
        SwFatal("UpdateSkinnedGeometry: joint 0 isnt base - fix code Brian!")
    }

    let skelType = theNode.pointee.Type

    // DO RECURSION TO BUILD IT

    if currentSkelObjData.pointee.JointsAreGlobal != 0 {
        OGLMatrix4x4_SetIdentity(&gMatrix)
    } else {
        gMatrix = theNode.pointee.BaseTransformMatrix
    }

    // CALL RECURSION

    updateSkinnedGeometryRecurse(0, Int16(skelType)) // start @ base

    // ALSO CALC LOCAL BBOX
    //
    // We need the local-space bbox for cull tests

    theNode.pointee.LocalBBox.min.x = bbox.pointee.min.x - theNode.pointee.Coord.x
    theNode.pointee.LocalBBox.max.x = bbox.pointee.max.x - theNode.pointee.Coord.x
    theNode.pointee.LocalBBox.min.y = bbox.pointee.min.y - theNode.pointee.Coord.y
    theNode.pointee.LocalBBox.max.y = bbox.pointee.max.y - theNode.pointee.Coord.y
    theNode.pointee.LocalBBox.min.z = bbox.pointee.min.z - theNode.pointee.Coord.z
    theNode.pointee.LocalBBox.max.z = bbox.pointee.max.z - theNode.pointee.Coord.z

    bbox.pointee.isEmpty = 0
    theNode.pointee.LocalBBox.isEmpty = 0
}

private func updateSkinnedGeometryRecurse(_ joint: Int16, _ skelType: Int16) {
    let currentSkelObjData = gCurrentSkelObjData!
    let currentSkeleton = gCurrentSkeleton!
    let bbox = gBBox!

    let buffNum = Int(gGameViewInfoPtr!.pointee.frameCount & 1)

    let localTriMeshes = deformedMeshesBase(currentSkelObjData) + (buffNum * kDeformedMeshesStride) // get ptr to skeleton's triMeshes

    var minX = bbox.pointee.min.x // calc local bbox with registers for speed
    var minY = bbox.pointee.min.y
    var minZ = bbox.pointee.min.z
    var maxX = bbox.pointee.max.x
    var maxY = bbox.pointee.max.y
    var maxZ = bbox.pointee.max.z

    // FACTOR IN THIS JOINT'S MATRIX

    let matPtr: UnsafeMutablePointer<OGLMatrix4x4>
    let jointMatricesBase = jointTransformMatrixBase(currentSkelObjData)
    if currentSkelObjData.pointee.JointsAreGlobal != 0 {
        matPtr = jointMatricesBase + Int(joint)
    } else {
        let jointMat = jointMatricesBase + Int(joint)
        matPtr = withUnsafeMutablePointer(to: &gMatrix) { $0 }
        OGLMatrix4x4_Multiply(jointMat, matPtr, matPtr)
    }

    // LOAD THE MATRIX INTO REGISTERS
    //
    // note:  we load the bottom row later when we need it for point transforms.

    let m00 = matValue(&matPtr.pointee, M00); let m01 = matValue(&matPtr.pointee, Int32(M10)); let m02 = matValue(&matPtr.pointee, Int32(M20))
    let m10 = matValue(&matPtr.pointee, Int32(M01)); let m11 = matValue(&matPtr.pointee, M11); let m12 = matValue(&matPtr.pointee, Int32(M21))
    let m20 = matValue(&matPtr.pointee, Int32(M02)); let m21 = matValue(&matPtr.pointee, Int32(M12)); let m22 = matValue(&matPtr.pointee, M22)

    // TRANSFORM THE NORMALS

    // APPLY MATRIX TO EACH NORMAL VECTOR

    let bonePtr = currentSkeleton.pointee.Bones! + Int(joint) // point to bone def
    let numNormals = Int(bonePtr.pointee.numNormalsAttachedToBone) // get # normals attached to this bone
    let normalIndexList = bonePtr.pointee.normalList! // get ptr to list of normal indecies
    let decomposedNormalsList = currentSkeleton.pointee.decomposedNormalsList! // get ptr to actual normals

    for p in 0..<numNormals {
        let i = Int(normalIndexList[p]) // get index to normal in gDecomposedNormalsList

        let x = decomposedNormalsList[i].x // get xyz of normal
        let y = decomposedNormalsList[i].y
        let z = decomposedNormalsList[i].z

        gTransformedNormals[i].x = (m00 * x) + (m10 * y) + (m20 * z) // transform the normal
        gTransformedNormals[i].y = (m01 * x) + (m11 * y) + (m21 * z)
        gTransformedNormals[i].z = (m02 * x) + (m12 * y) + (m22 * z)
    }

    // APPLY TRANSFORMED VECTORS TO ALL REFERENCES

    let numPoints = Int(bonePtr.pointee.numPointsAttachedToBone) // get # points attached to this bone
    let pointIndexList = bonePtr.pointee.pointList! // get ptr to list of point indecies
    let decomposedPointList = currentSkeleton.pointee.decomposedPointList! // get ptr to actual points

    for p in 0..<numPoints {
        let i = Int(pointIndexList[p]) // get index to point in gDecomposedPointList
        let decomposedPt = decomposedPointList + i

        let numRefs = Int(decomposedPt.pointee.numRefs) // get # times this point is referenced
        for r in 0..<numRefs {
            let triMeshNum = Int(whichTriMeshBase(decomposedPt)[r]) // get triMesh # that uses this point
            let p2 = Int(whichPointBase(decomposedPt)[r]) // get point # in the triMesh
            let n = Int(whichNormalBase(decomposedPt)[r]) // get index into gDecomposedNormalsList

            let normalAttribs = localTriMeshes[triMeshNum].normals! // point to normals list
            normalAttribs[p2] = gTransformedNormals[n] // copy transformed normal into triMesh
        }
    }

    // TRANSFORM THE POINTS

    // LOAD THE REMAINING MATRIX VALUES

    let m30 = matValue(&matPtr.pointee, M03); let m31 = matValue(&matPtr.pointee, M13); let m32 = matValue(&matPtr.pointee, M23)

    for p in 0..<numPoints {
        let i = Int(bonePtr.pointee.pointList![p]) // get index to point in gDecomposedPointList

        let decomposedPt = decomposedPointList + i

        let x = decomposedPt.pointee.boneRelPoint.x // get xyz of point
        let y = decomposedPt.pointee.boneRelPoint.y
        let z = decomposedPt.pointee.boneRelPoint.z

        // TRANSFORM

        let newX = (m00 * x) + (m10 * y) + (m20 * z) + m30 // transform x value
        let newY = (m01 * x) + (m11 * y) + (m21 * z) + m31 // transform y
        let newZ = (m02 * x) + (m12 * y) + (m22 * z) + m32 // transform z

        // TRANSFORM & UPDATE BBOX

        if newX < minX { minX = newX } // update bbox X
        if newX > maxX { maxX = newX }

        if newY < minY { minY = newY } // update bbox Y
        if newY > maxY { maxY = newY }

        if newZ > maxZ { maxZ = newZ } // update bbox Z
        if newZ < minZ { minZ = newZ }

        // APPLY NEW POINT TO ALL REFERENCES

        let numRefs = Int(decomposedPt.pointee.numRefs) // get # times this point is referenced
        for r in 0..<numRefs {
            let triMeshNum = Int(whichTriMeshBase(decomposedPt)[r])
            let p2 = Int(whichPointBase(decomposedPt)[r])

            localTriMeshes[triMeshNum].points![p2].x = newX
            localTriMeshes[triMeshNum].points![p2].y = newY
            localTriMeshes[triMeshNum].points![p2].z = newZ
        }
    }

    // UPDATE GLOBAL BBOX

    bbox.pointee.min.x = minX
    bbox.pointee.min.y = minY
    bbox.pointee.min.z = minZ
    bbox.pointee.max.x = maxX
    bbox.pointee.max.y = maxY
    bbox.pointee.max.z = maxZ

    // RECURSE THRU ALL CHILDREN

    let numChildren = Int(numChildrenBase(currentSkeleton)[Int(joint)]) // get # children
    let childIdxBase = childIndeciesBase(currentSkeleton)
    for c in 0..<numChildren {
        let oldM = gMatrix // push matrix
        updateSkinnedGeometryRecurse(Int16(childIdxBase[Int(joint) * Int(MAX_CHILDREN) + c]), skelType)
        gMatrix = oldM // pop matrix
    }

    OGL_SetVertexArrayRangeDirty(Int16(VertexArrayRangeType.skeletons.rawValue) + Int16(buffNum)) // remember to update VAR
}

// After a skeleton file is loaded, this will calc some other needed things.
@c @implementation
public func PrimeBoneData(_ skeleton: UnsafeMutablePointer<SkeletonDefType>!) {
    if skeleton.pointee.NumBones == 0 {
        SwFatal("PrimeBoneData: # = 0??")
    }

    // SET THE FORWARD LINKS

    let numChildBase = numChildrenBase(skeleton)
    let childIdxBase = childIndeciesBase(skeleton)

    for b in 0..<Int(skeleton.pointee.NumBones) {
        numChildBase[b] = 0 // init child counter

        for i in 0..<Int(skeleton.pointee.NumBones) { // look for a child
            if Int(skeleton.pointee.Bones![i].parentBone) == b { // is this "i" a child of "b"?
                let j = Int(numChildBase[b]) // get # children
                if j >= Int(MAX_CHILDREN) {
                    SwFatal("CreateSkeletonFromBones: MAX_CHILDREN exceeded!")
                }

                childIdxBase[b * Int(MAX_CHILDREN) + j] = UInt8(i) // set index to child

                numChildBase[b] += 1 // inc # children
            }
        }
    }
}
