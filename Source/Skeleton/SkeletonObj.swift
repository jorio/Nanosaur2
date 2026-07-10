// SkeletonObj.swift - Port of SkeletonObj.c to Swift
//
// VERTEXARRAYRANGES is hardcoded to 0 in game.h, so the #if VERTEXARRAYRANGES
// blocks in the original C are dead code in every build this port targets
// (same reasoning as #if SKIPFLUFF elsewhere) — dropped here.

private var gLoadedSkeletonsList: InlineArray<7, UnsafeMutablePointer<SkeletonDefType>?> = InlineArray(repeating: nil)
private var gNumDecomposedTriMeshesInSkeleton: InlineArray<7, Int16> = InlineArray(repeating: 0)

func InitSkeletonManager() {
    CalcAccelerationSplineCurve() // calc accel curve

    for (i, _) in SkeletonType.allCases.enumerated() {
        gLoadedSkeletonsList[i] = nil
    }
}

func LoadASkeleton(_ num: UInt8) {
    if num >= UInt8(SkeletonType.allCases.count) {
        SwFatal("LoadASkeleton: MAX_SKELETON_TYPES exceeded!")
    }

    if gLoadedSkeletonsList[Int(num)] != nil { // check if already loaded
        SwFatal("LoadASkeleton:  skeleton already loaded!")
    }

    // LOAD THE SKELETON FILE

    let loaded = LoadSkeletonFile(Int16(num))!
    gLoadedSkeletonsList[Int(num)] = loaded

    gNumDecomposedTriMeshesInSkeleton[Int(num)] = Int16(loaded.pointee.numDecomposedTriMeshes) // keep easy access version of this value
}

// Disposes of all memory used by a skeleton file (from File.c)
func FreeSkeletonFile(_ skeletonType: UInt8) {
    if let skeleton = gLoadedSkeletonsList[Int(skeletonType)] { // make sure this really exists
        // (the local-copy-of-decomposed-trimeshes disposal loop was already
        // commented out in the original C)

        disposeSkeletonDefinitionMemory(skeleton) // free skeleton data
        gLoadedSkeletonsList[Int(skeletonType)] = nil
    }
}

// Free's all except for the input type (-1 == none to skip)
func FreeAllSkeletonFiles(_ skipMe: Int16) {
    for (i, _) in SkeletonType.allCases.enumerated() {
        if Int16(i) != skipMe {
            FreeSkeletonFile(UInt8(i))
        }
    }
}

// This routine simply initializes the blank object.
// The function CopySkeletonInfoToNewSkeleton actually attaches the specific skeleton
// file to this ObjNode.
func MakeNewSkeletonObject(_ newObjDef: UnsafeMutablePointer<NewObjectDefinitionType>!) -> UnsafeMutablePointer<ObjNode>! {
    let type = newObjDef.pointee.type

    // CREATE NEW OBJECT NODE

    newObjDef.pointee.genre = UInt8(SKELETON_GENRE)
    guard let newNode = MakeNewObject(newObjDef) else {
        return nil
    }

    // LOAD SKELETON FILE INTO OBJECT

    newNode.pointee.Skeleton = makeNewSkeletonBaseData(Int16(type)) // alloc & set skeleton data
    if newNode.pointee.Skeleton == nil {
        SwFatal("MakeNewSkeletonObject: MakeNewSkeletonBaseData == nil")
    }

    newNode.updateTransforms()

    // SET INITIAL DEFAULT POSITION

    SetSkeletonAnim(newNode.pointee.Skeleton, Int(newObjDef.pointee.animNum))
    UpdateSkeletonAnimation(newNode)
    UpdateSkinnedGeometry(newNode) // prime the trimesh

    newNode.calcRadiusFromBBox() // set correct bounding sphere

    newNode.pointee.VertexArrayMode = UInt8(VertexArrayRangeType.skeletons.rawValue)

    return newNode
}

// Allocates all of the sub-arrays for a skeleton file's definition data.
// ONLY called by ReadDataFromSkeletonFile in file.c.
//
// NOTE: skeleton has already been allocated by LoadSkeleton!!!
func AllocSkeletonDefinitionMemory(_ skeleton: UnsafeMutablePointer<SkeletonDefType>!) {
    let numJoints = Int(skeleton.pointee.NumBones) // get # joints in skeleton
    let numAnims = Int(skeleton.pointee.NumAnims) // get # anims in skeleton

    // ALLOC ANIM EVENTS LISTS

    skeleton.pointee.NumAnimEvents = AllocPtrClear(MemoryLayout<UInt8>.size * numAnims)!.assumingMemoryBound(to: UInt8.self) // array which holds # events for each anim
    skeleton.pointee.AnimEventsList = alloc2DArray(AnimEventType.self, rows: numAnims, cols: Int(MAX_ANIM_EVENTS))

    // ALLOC BONE INFO

    skeleton.pointee.Bones = AllocPtrClear(MemoryLayout<BoneDefinitionType>.size * numJoints)!.assumingMemoryBound(to: BoneDefinitionType.self)

    // ALLOC DECOMPOSED DATA

    skeleton.pointee.decomposedPointList = AllocPtrClear(MemoryLayout<DecomposedPointType>.size * Int(MAX_DECOMPOSED_POINTS))!.assumingMemoryBound(to: DecomposedPointType.self)
    skeleton.pointee.decomposedNormalsList = AllocPtrClear(MemoryLayout<OGLVector3D>.size * Int(MAX_DECOMPOSED_NORMALS))!.assumingMemoryBound(to: OGLVector3D.self)
}

// Disposes of all alloced memory (from above) used by a skeleton file definition.
private func disposeSkeletonDefinitionMemory(_ skeleton: UnsafeMutablePointer<SkeletonDefType>?) {
    guard let skeleton else {
        return
    }

    let numJoints = Int(skeleton.pointee.NumBones)

    // NUKE THE SKELETON BONE POINT & NORMAL INDEX ARRAYS

    for j in 0..<numJoints {
        if let pointList = skeleton.pointee.Bones![j].pointList {
            SafeDisposePtr(pointList)
        }
        if let normalList = skeleton.pointee.Bones![j].normalList {
            SafeDisposePtr(normalList)
        }
    }
    SafeDisposePtr(skeleton.pointee.Bones) // free bones array
    skeleton.pointee.Bones = nil

    // DISPOSE ANIM EVENTS LISTS

    SafeDisposePtr(skeleton.pointee.NumAnimEvents)

    free2DArray(skeleton.pointee.AnimEventsList)

    // DISPOSE JOINT INFO

    let jointKeyframesBase = UnsafeMutableRawPointer(skeleton.pointer(to: \.JointKeyframes)!).assumingMemoryBound(to: JointKeyFrameHeader.self)
    for j in 0..<numJoints {
        free2DArray(jointKeyframesBase[j].keyFrames) // dispose 2D array of keyframe data
        jointKeyframesBase[j].keyFrames = nil
    }

    // DISPOSE DECOMPOSED DATA ARRAYS
    //
    // (the trimesh-data disposal loop was already commented out in the original C)

    if let decomposedPointList = skeleton.pointee.decomposedPointList {
        SafeDisposePtr(decomposedPointList)
        skeleton.pointee.decomposedPointList = nil
    }

    if let decomposedNormalsList = skeleton.pointee.decomposedNormalsList {
        SafeDisposePtr(decomposedNormalsList)
        skeleton.pointee.decomposedNormalsList = nil
    }

    // DISPOSE OF MASTER DEFINITION BLOCK

    SafeDisposePtr(skeleton)
}

// Allocates & inits the Skeleton data for an ObjNode.
private func makeNewSkeletonBaseData(_ skeletonNum: Int16) -> UnsafeMutablePointer<SkeletonObjDataType>! {
    guard let skeletonDefPtr = gLoadedSkeletonsList[Int(skeletonNum)] else { // get ptr to source skeleton definition info
        SwFatal("MakeNewSkeletonBaseData: Skeleton data isn't loaded!")
        return nil
    }

    // ALLOC MEMORY FOR NEW SKELETON OBJECT DATA STRUCTURE

    let skeletonData = AllocPtrClear(MemoryLayout<SkeletonObjDataType>.size)!.assumingMemoryBound(to: SkeletonObjDataType.self)

    // INIT NEW SKELETON

    skeletonData.pointee.skeletonDefinition = skeletonDefPtr // point to source skeletal data
    skeletonData.pointee.AnimSpeed = 1.0
    skeletonData.jointsAreGlobal = false

    let overrideTextureBase = UnsafeMutableRawPointer(skeletonData.pointer(to: \.overrideTexture)!).assumingMemoryBound(to: UnsafeMutablePointer<MOMaterialObject>?.self)
    for i in 0..<Int(MAX_DECOMPOSED_TRIMESHES) {
        overrideTextureBase[i] = nil // assume no override texture.. yet.
    }

    // MAKE COPY OF TRIMESHES FOR LOCAL USE
    //
    // Each ObjNode's Skeleton Def will have it's own triMesh copies
    // of the actual skeleton's geometry.  There are 2 copies because we
    // double-buffer it for VAR.  These local copies are what
    // we can modify to perform deformation animation on.

    let numDecomp = Int(gNumDecomposedTriMeshesInSkeleton[Int(skeletonNum)]) // how many trimeshes in this skeleton's geometry?

    let srcTriMeshesBase = UnsafeMutableRawPointer(skeletonDefPtr.pointer(to: \.decomposedTriMeshes)!).assumingMemoryBound(to: MOVertexArrayData.self)
    let deformedMeshesBase = UnsafeMutableRawPointer(skeletonData.pointer(to: \.deformedMeshes)!).assumingMemoryBound(to: MOVertexArrayData.self)
    let deformedMeshesStride = Int(MAX_DECOMPOSED_TRIMESHES)

    for i in 0..<numDecomp {
        MO_DuplicateVertexArrayData(srcTriMeshesBase + i, deformedMeshesBase + (0 * deformedMeshesStride + i), Int16(VertexArrayRangeType.skeletons.rawValue))
        MO_DuplicateVertexArrayData(srcTriMeshesBase + i, deformedMeshesBase + (1 * deformedMeshesStride + i), Int16(VertexArrayRangeType.skeletons.rawValue) + 1)
    }

    return skeletonData
}

func FreeSkeletonBaseData(_ skeletonData: UnsafeMutablePointer<SkeletonObjDataType>!, _ skeletonType: Int16) {
    // FREE OUR LOCAL COPY OF THE SKELETON'S TRIMESH

    let numDecomp = Int(gNumDecomposedTriMeshesInSkeleton[Int(skeletonType)]) // how many trimeshes in this skeleton's geometry?

    let deformedMeshesBase = UnsafeMutableRawPointer(skeletonData.pointer(to: \.deformedMeshes)!).assumingMemoryBound(to: MOVertexArrayData.self)
    let deformedMeshesStride = Int(MAX_DECOMPOSED_TRIMESHES)

    for i in 0..<numDecomp {
        MO_DeleteObjectInfo_Geometry_VertexArray(deformedMeshesBase + (0 * deformedMeshesStride + i)) // free both double-buffers
        MO_DeleteObjectInfo_Geometry_VertexArray(deformedMeshesBase + (1 * deformedMeshesStride + i))
    }

    // FREE THE SKELETON DATA STRUCT

    SafeDisposePtr(skeletonData)
}

func DrawSkeleton(_ theNode: UnsafeMutablePointer<ObjNode>!) {
    let buffNum = Int(gGameViewInfoPtr!.pointee.frameCount & 1)

    let skelType = Int(theNode.pointee.Type)
    let numTriMeshes = Int(gNumDecomposedTriMeshesInSkeleton[skelType]) // get # trimeshes to draw

    let skeleton = theNode.pointee.Skeleton!
    let overrideTextureBase = UnsafeMutableRawPointer(skeleton.pointer(to: \.overrideTexture)!).assumingMemoryBound(to: UnsafeMutablePointer<MOMaterialObject>?.self)
    let deformedMeshesBase = UnsafeMutableRawPointer(skeleton.pointer(to: \.deformedMeshes)!).assumingMemoryBound(to: MOVertexArrayData.self)
    let deformedMeshesStride = Int(MAX_DECOMPOSED_TRIMESHES)

    for i in 0..<numTriMeshes { // submit each trimesh of it
        let triMesh = deformedMeshesBase + (buffNum * deformedMeshesStride + i) // point to triMesh

        let overrideTexture = overrideTextureBase[i] // get any override texture ref (illegal ref)
        var oldTexture: UnsafeMutablePointer<MOMaterialObject>?
        if let overrideTexture { // set override texture
            if triMesh.pointee.numMaterials > 0 {
                oldTexture = triMesh.pointee.materials.0 // get the real texture for this mesh
                triMesh.pointee.materials.0 = overrideTexture // set the override texture (temporarily)
            }
        }

        // SUBMIT IT

        MO_DrawGeometry_VertexArray(triMesh)

        if overrideTexture != nil, let oldTexture { // see if need to set texture back to normal
            triMesh.pointee.materials.0 = oldTexture
        }
    }
}
