// File.swift - Port of File.c to Swift

private let SKELETON_FILE_VERS_NUM: Int16 = 0x0110 // v1.1

// PLAYFIELD HEADER
private struct PlayfieldHeaderType {
    var version = NumVersion()
    var numItems: Int32 = 0
    var mapWidth: Int32 = 0
    var mapHeight: Int32 = 0
    var tileSize: Float = 0
    var minY: Float = 0
    var maxY: Float = 0
    var numSplines: Int32 = 0
    var numFences: Int32 = 0
    var numUniqueSuperTiles: Int32 = 0
    var numWaterPatches: Int32 = 0
    var numCheckpoints: Int32 = 0
    var unused: (Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32) = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

// FENCE STRUCTURE IN FILE
//
// note: we copy this data into our own fence list
//		since the game uses a slightly different
//		data structure.
private struct FencePointType {
    var x: Int32 = 0
    var z: Int32 = 0
}

private struct FileFenceDefType {
    var type: UInt16 = 0 // type of fence
    var numNubs: Int16 = 0 // # nubs in fence
    var junk: Int32 = 0 // handle to nub list
    var bBox = Rect() // bounding box of fence area
}

// Resource FourCCs (Clang's macro-constant importer can't fold multi-char literals)
private let kResHedr: ResType = 0x48656472
private let kResBone: ResType = 0x426F6E65
private let kResBonP: ResType = 0x426F6E50
private let kResBonN: ResType = 0x426F6E4E
private let kResRelP: ResType = 0x52656C50
private let kResAnHd: ResType = 0x416E4864
private let kResEvnt: ResType = 0x45766E74
private let kResNumK: ResType = 0x4E756D4B
private let kResKeyF: ResType = 0x4B657946
private let kResSTgd: ResType = 0x53546764
private let kResYCrd: ResType = 0x59437264
private let kResItms: ResType = 0x49746D73
private let kResSpln: ResType = 0x53706C6E
private let kResSpPt: ResType = 0x53705074
private let kResSpIt: ResType = 0x53704974
private let kResFenc: ResType = 0x46656E63
private let kResFnNb: ResType = 0x466E4E62
private let kResLiqd: ResType = 0x4C697164
private let kResCkPt: ResType = 0x436B5074
private let kGameIDFourCC: OSType = 0x4E414E32 // 'NAN2'
private let kPrefFourCC: OSType = 0x50726566 // 'Pref'

// `noErr`/`badFileFormat` come from the named C enum `EErrors`, which doesn't
// import cleanly as a plain `OSErr` (Int16) constant in this context.
private let kNoErr: OSErr = 0
private let kBadFileFormat: OSErr = -208

// Handle is `Ptr* = char**`; `*hand` in C is the same as `hand.pointee` in Swift.
// This helper reinterprets that single-dereferenced data pointer as the given type.
@inline(__always) private func handleData<T>(_ hand: Handle, _ type: T.Type) -> UnsafeMutablePointer<T> {
    UnsafeMutableRawPointer(hand.pointee!).assumingMemoryBound(to: T.self)
}

private var gDiskShadowPrefs = PrefsType()

private var g3DTileSize: Float = 0
private var g3DMinY: Float = 0
private var g3DMaxY: Float = 0

// MARK: - Fixed-array-field helpers (all struct fields, never unions)

@inline(__always) private func waterNubListBase(_ water: UnsafeMutablePointer<WaterDefType>) -> UnsafeMutablePointer<OGLPoint2D> {
    UnsafeMutableRawPointer(water.pointer(to: \.nubList)!).assumingMemoryBound(to: OGLPoint2D.self)
}

@inline(__always) private func lineMarkerXBase(_ lm: UnsafeMutablePointer<LineMarkerDefType>) -> UnsafeMutablePointer<Float> {
    UnsafeMutableRawPointer(lm.pointer(to: \.x)!).assumingMemoryBound(to: Float.self)
}

@inline(__always) private func lineMarkerZBase(_ lm: UnsafeMutablePointer<LineMarkerDefType>) -> UnsafeMutablePointer<Float> {
    UnsafeMutableRawPointer(lm.pointer(to: \.z)!).assumingMemoryBound(to: Float.self)
}

// MARK: - Load Skeleton
//
// Loads a skeleton file & creates storage for it.
//
// NOTE: Skeleton types 0..NUM_CHARACTERS-1 are reserved for player character skeletons.
//		Skeleton types NUM_CHARACTERS and over are for other skeleton entities.
//
// OUTPUT:	Ptr to skeleton data
func LoadSkeletonFile(_ skeletonType: Int16) -> UnsafeMutablePointer<SkeletonDefType>! {
    let modelNames = ["nano", "wormhole", "raptor", "bonusworm", "brach", "worm", "ramphor"]

    SwGameAssert(skeletonType >= 0)
    SwGameAssert(Int(skeletonType) < SkeletonType.allCases.count)
    let modelName = modelNames[Int(skeletonType)]

    var fsSpecSkeleton = FSSpec()
    var fsSpecBG3D = FSSpec()

    var pathBuf = ":Skeletons:\(modelName).skeleton"
    _ = pathBuf.withCString { FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, $0, &fsSpecSkeleton) }

    pathBuf = ":Skeletons:\(modelName).bg3d"
    _ = pathBuf.withCString { FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, $0, &fsSpecBG3D) }

    // OPEN THE FILE'S REZ FORK

    let fRefNum = FSpOpenResFile(&fsSpecSkeleton, Int8(fsRdPerm.rawValue))
    SwGameAssert(fRefNum != -1)

    UseResFile(fRefNum)
    SwGameAssert(kNoErr == ResError())

    // ALLOC MEMORY FOR SKELETON INFO STRUCTURE

    let skeleton = AllocPtrClear(MemoryLayout<SkeletonDefType>.size)!.assumingMemoryBound(to: SkeletonDefType.self)

    // READ SKELETON RESOURCES

    readDataFromSkeletonFile(skeleton, &fsSpecBG3D, Int32(skeletonType))
    PrimeBoneData(skeleton)

    // CLOSE REZ FILE

    CloseResFile(fRefNum)

    return skeleton
}

// Current rez file is set to the file.
private func readDataFromSkeletonFile(_ skeleton: UnsafeMutablePointer<SkeletonDefType>, _ fsSpecBG3D: UnsafeMutablePointer<FSSpec>, _ skeletonType: Int32) {
    // READ HEADER RESOURCE

    guard let handHedr = GetResource(kResHedr, 1000) else {
        SwFatal("ReadDataFromSkeletonFile: Error reading header resource!")
        return
    }
    let headerPtr = handleData(handHedr, SkeletonFile_Header_Type.self)
    let version = SwizzleShort(&headerPtr.pointee.version)
    if version != SKELETON_FILE_VERS_NUM {
        SwFatal("Skeleton file has wrong version #")
    }

    let numAnims = Int(SwizzleShort(&headerPtr.pointee.numAnims)) // get # anims in skeleton
    skeleton.pointee.NumAnims = UInt8(numAnims)
    let numJoints = Int(SwizzleShort(&headerPtr.pointee.numJoints)) // get # joints in skeleton
    skeleton.pointee.NumBones = UInt8(numJoints)
    ReleaseResource(handHedr)

    if numJoints > Int(MAX_JOINTS) { // check for overload
        SwFatal("ReadDataFromSkeletonFile: numJoints > MAX_JOINTS")
    }

    // ALLOCATE MEMORY FOR SKELETON DATA

    AllocSkeletonDefinitionMemory(skeleton)

    // LOAD THE REFERENCE GEOMETRY
    //
    // Source port change: original game used to resolve path to BG3D via alias resource within skeleton rez fork.
    // Instead, we're forcing the BG3D's filename (sans extension) to match the skeleton's.
    LoadBonesReferenceModel(fsSpecBG3D, skeleton, skeletonType)

    // READ BONE DEFINITION RESOURCES

    for i in 0..<numJoints {
        // READ BONE DATA

        guard let handBone = GetResource(kResBone, 1000 + Int16(i)) else {
            SwFatal("Error reading Bone resource!")
            return
        }
        HLock(handBone)
        let bonePtr = handleData(handBone, File_BoneDefinitionType.self)

        // COPY BONE DATA INTO ARRAY

        skeleton.pointee.Bones![i].parentBone = Int(SwizzleLong(&bonePtr.pointee.parentBone)) // index to previous bone
        skeleton.pointee.Bones![i].coord.x = SwizzleFloat(&bonePtr.pointee.coord.x) // absolute coord (not relative to parent!)
        skeleton.pointee.Bones![i].coord.y = SwizzleFloat(&bonePtr.pointee.coord.y)
        skeleton.pointee.Bones![i].coord.z = SwizzleFloat(&bonePtr.pointee.coord.z)
        skeleton.pointee.Bones![i].numPointsAttachedToBone = SwizzleUShort(&bonePtr.pointee.numPointsAttachedToBone) // # vertices/points that this bone has
        skeleton.pointee.Bones![i].numNormalsAttachedToBone = SwizzleUShort(&bonePtr.pointee.numNormalsAttachedToBone) // # vertex normals this bone has
        ReleaseResource(handBone)

        // ALLOC THE POINT & NORMALS SUB-ARRAYS

        skeleton.pointee.Bones![i].pointList = AllocPtrClear(MemoryLayout<UInt16>.size * Int(skeleton.pointee.Bones![i].numPointsAttachedToBone))?.assumingMemoryBound(to: UInt16.self)
        if skeleton.pointee.Bones![i].pointList == nil {
            SwFatal("ReadDataFromSkeletonFile: AllocPtr/pointList failed!")
        }

        skeleton.pointee.Bones![i].normalList = AllocPtrClear(MemoryLayout<UInt16>.size * Int(skeleton.pointee.Bones![i].numNormalsAttachedToBone))?.assumingMemoryBound(to: UInt16.self)
        if skeleton.pointee.Bones![i].normalList == nil {
            SwFatal("ReadDataFromSkeletonFile: AllocPtr/normalList failed!")
        }

        // READ POINT INDEX ARRAY

        guard let handBonP = GetResource(kResBonP, 1000 + Int16(i)) else {
            SwFatal("Error reading BonP resource!")
            return
        }
        HLock(handBonP)
        var indexPtr = handleData(handBonP, UInt16.self)

        // COPY POINT INDEX ARRAY INTO BONE STRUCT

        for j in 0..<Int(skeleton.pointee.Bones![i].numPointsAttachedToBone) {
            skeleton.pointee.Bones![i].pointList![j] = SwizzleUShort(indexPtr + j)
        }
        ReleaseResource(handBonP)

        // READ NORMAL INDEX ARRAY

        guard let handBonN = GetResource(kResBonN, 1000 + Int16(i)) else {
            SwFatal("Error reading BonN resource!")
            return
        }
        HLock(handBonN)
        indexPtr = handleData(handBonN, UInt16.self)

        // COPY NORMAL INDEX ARRAY INTO BONE STRUCT

        for j in 0..<Int(skeleton.pointee.Bones![i].numNormalsAttachedToBone) {
            skeleton.pointee.Bones![i].normalList![j] = SwizzleUShort(indexPtr + j)
        }
        ReleaseResource(handBonN)
    }

    // READ POINT RELATIVE OFFSETS
    //
    // The "relative point offsets" are the only things
    // which do not get rebuilt in the ModelDecompose function.
    // We need to restore these manually.

    guard let handRelP = GetResource(kResRelP, 1000) else {
        SwFatal("Error reading RelP resource!")
        return
    }
    HLock(handRelP)
    let pointPtr = handleData(handRelP, OGLPoint3D.self)

    let numRelPoints = Int(GetHandleSize(handRelP)) / MemoryLayout<OGLPoint3D>.size
    if numRelPoints != Int(skeleton.pointee.numDecomposedPoints) {
        SwFatal("# of points in Reference Model has changed!")
    } else {
        for i in 0..<Int(skeleton.pointee.numDecomposedPoints) {
            skeleton.pointee.decomposedPointList![i].boneRelPoint.x = SwizzleFloat(&(pointPtr + i).pointee.x)
            skeleton.pointee.decomposedPointList![i].boneRelPoint.y = SwizzleFloat(&(pointPtr + i).pointee.y)
            skeleton.pointee.decomposedPointList![i].boneRelPoint.z = SwizzleFloat(&(pointPtr + i).pointee.z)
        }
    }
    ReleaseResource(handRelP)

    // READ ANIM INFO

    for i in 0..<numAnims {
        // READ ANIM HEADER

        guard let handAnHd = GetResource(kResAnHd, 1000 + Int16(i)) else {
            SwFatal("Error getting anim header resource")
            return
        }
        HLock(handAnHd)
        let animHeaderPtr = handleData(handAnHd, SkeletonFile_AnimHeader_Type.self)

        skeleton.pointee.NumAnimEvents![i] = UInt8(SwizzleShort(&animHeaderPtr.pointee.numAnimEvents)) // copy # anim events in anim
        ReleaseResource(handAnHd)

        // READ ANIM-EVENT DATA

        guard let handEvnt = GetResource(kResEvnt, 1000 + Int16(i)) else {
            SwFatal("Error reading anim-event data resource!")
            return
        }
        var animEventPtr = handleData(handEvnt, AnimEventType.self)
        for j in 0..<Int(skeleton.pointee.NumAnimEvents![i]) {
            skeleton.pointee.AnimEventsList![i]![j] = animEventPtr.pointee // copy whole thing
            skeleton.pointee.AnimEventsList![i]![j].time = SwizzleShort(&skeleton.pointee.AnimEventsList![i]![j].time) // then swizzle the 16-bit short value
            animEventPtr += 1
        }
        ReleaseResource(handEvnt)

        // READ # KEYFRAMES PER JOINT IN EACH ANIM

        guard let handNumK = GetResource(kResNumK, 1000 + Int16(i)) else { // read array of #'s for this anim
            SwFatal("Error reading # keyframes/joint resource!")
            return
        }
        let numKPtr = handleData(handNumK, Int8.self)
        for j in 0..<numJoints {
            numKeyFramesBase(jointKeyframesBase(skeleton) + j)[i] = (numKPtr + j).pointee
        }
        ReleaseResource(handNumK)
    }

    for j in 0..<numJoints {
        // ALLOC 2D ARRAY FOR KEYFRAMES

        let keyFrames = alloc2DArray(JointKeyframeType.self, rows: numAnims, cols: Int(MAX_KEYFRAMES))
        jointKeyframesBase(skeleton)[j].keyFrames = keyFrames

        if jointKeyframesBase(skeleton)[j].keyFrames == nil || jointKeyframesBase(skeleton)[j].keyFrames![0] == nil {
            SwFatal("ReadDataFromSkeletonFile: Error allocating Keyframe Array.")
        }

        // READ THIS JOINT'S KF'S FOR EACH ANIM

        for i in 0..<numAnims {
            let numKeyframes = Int(numKeyFramesBase(jointKeyframesBase(skeleton) + j)[i]) // get actual # of keyframes for this joint
            if numKeyframes > Int(MAX_KEYFRAMES) {
                SwFatal("Error: numKeyframes > MAX_KEYFRAMES")
            }

            // READ A JOINT KEYFRAME

            guard let handKeyF = GetResource(kResKeyF, 1000 + Int16(i * 100 + j)) else {
                SwFatal("Error reading joint keyframes resource!")
                return
            }
            var keyFramePtr = handleData(handKeyF, JointKeyframeType.self)
            for k in 0..<numKeyframes { // copy this joint's keyframes for this anim
                jointKeyframesBase(skeleton)[j].keyFrames![i]![k].tick = SwizzleLong(&keyFramePtr.pointee.tick)
                jointKeyframesBase(skeleton)[j].keyFrames![i]![k].accelerationMode = SwizzleLong(&keyFramePtr.pointee.accelerationMode)
                jointKeyframesBase(skeleton)[j].keyFrames![i]![k].coord.x = SwizzleFloat(&keyFramePtr.pointee.coord.x)
                jointKeyframesBase(skeleton)[j].keyFrames![i]![k].coord.y = SwizzleFloat(&keyFramePtr.pointee.coord.y)
                jointKeyframesBase(skeleton)[j].keyFrames![i]![k].coord.z = SwizzleFloat(&keyFramePtr.pointee.coord.z)
                jointKeyframesBase(skeleton)[j].keyFrames![i]![k].rotation.x = SwizzleFloat(&keyFramePtr.pointee.rotation.x)
                jointKeyframesBase(skeleton)[j].keyFrames![i]![k].rotation.y = SwizzleFloat(&keyFramePtr.pointee.rotation.y)
                jointKeyframesBase(skeleton)[j].keyFrames![i]![k].rotation.z = SwizzleFloat(&keyFramePtr.pointee.rotation.z)
                jointKeyframesBase(skeleton)[j].keyFrames![i]![k].scale.x = SwizzleFloat(&keyFramePtr.pointee.scale.x)
                jointKeyframesBase(skeleton)[j].keyFrames![i]![k].scale.y = SwizzleFloat(&keyFramePtr.pointee.scale.y)
                jointKeyframesBase(skeleton)[j].keyFrames![i]![k].scale.z = SwizzleFloat(&keyFramePtr.pointee.scale.z)

                keyFramePtr += 1
            }
            ReleaseResource(handKeyF)
        }
    }
}

@inline(__always) private func jointKeyframesBase(_ skeleton: UnsafeMutablePointer<SkeletonDefType>) -> UnsafeMutablePointer<JointKeyFrameHeader> {
    UnsafeMutableRawPointer(skeleton.pointer(to: \.JointKeyframes)!).assumingMemoryBound(to: JointKeyFrameHeader.self)
}

@inline(__always) private func numKeyFramesBase(_ header: UnsafeMutablePointer<JointKeyFrameHeader>) -> UnsafeMutablePointer<Int8> {
    UnsafeMutableRawPointer(header.pointer(to: \.numKeyFrames)!).assumingMemoryBound(to: Int8.self)
}

// MARK: - Prefs

@c @implementation
public func LoadPrefs() -> OSErr {
    InitDefaultPrefs()

    let iErr = withUnsafeMutablePointer(to: &gGamePrefs) {
        $0.withMemoryRebound(to: Int8.self, capacity: MemoryLayout<PrefsType>.size) {
            LoadUserDataFile(PREFS_FILENAME, PREFS_MAGIC, MemoryLayout<PrefsType>.size, $0)
        }
    }

    gDiskShadowPrefs = gGamePrefs

    return iErr
}

@c @implementation
public func SavePrefs() -> OSErr {
    var matches = false
    withUnsafeBytes(of: gDiskShadowPrefs) { a in
        withUnsafeBytes(of: gGamePrefs) { b in
            matches = memcmp(a.baseAddress, b.baseAddress, MemoryLayout<PrefsType>.size) == 0
        }
    }
    if matches {
        return kNoErr
    }

    gDiskShadowPrefs = gGamePrefs

    return withUnsafeMutablePointer(to: &gGamePrefs) {
        $0.withMemoryRebound(to: Int8.self, capacity: MemoryLayout<PrefsType>.size) {
            SaveUserDataFile(PREFS_FILENAME, PREFS_MAGIC, MemoryLayout<PrefsType>.size, $0)
        }
    }
}

// MARK: - Load Playfield

func LoadPlayfield(_ specPtr: UnsafeMutablePointer<FSSpec>!) {
    gDisableHiccupTimer = 1

    // READ PLAYFIELD RESOURCES

    readDataFromPlayfieldFile(specPtr)

    // DO ADDITIONAL SETUP

    CreateSuperTileMemoryList() // allocate memory for the supertile geometry
    CalculateSplitModeMatrix() // precalc the tile split mode matrix
    InitSuperTileGrid() // init the supertile state grid

    BuildTerrainItemList() // build list of items & find player start coords

    // CAST ITEM SHADOWS

    DoItemShadowCasting()
}

private func readDataFromPlayfieldFile(_ specPtr: UnsafeMutablePointer<FSSpec>) {
    // OPEN THE REZ-FORK

    let fRefNum = FSpOpenResFile(specPtr, Int8(fsRdPerm.rawValue))
    if fRefNum == -1 {
        SwFatal("LoadPlayfield: FSpOpenResFile failed.  You seem to have a corrupt or missing file.  Please reinstall the game.")
    }
    UseResFile(fRefNum)

    // READ HEADER RESOURCE

    guard let handHedr = GetResource(kResHedr, 1000) else {
        SwAlert("ReadDataFromPlayfieldFile: Error reading header resource!")
        return
    }

    let header = handleData(handHedr, PlayfieldHeaderType.self)
    gNumTerrainItems = SwizzleLong(&header.pointee.numItems)
    gTerrainTileWidth = Int(SwizzleLong(&header.pointee.mapWidth))
    gTerrainTileDepth = Int(SwizzleLong(&header.pointee.mapHeight))
    g3DTileSize = SwizzleFloat(&header.pointee.tileSize)
    g3DMinY = SwizzleFloat(&header.pointee.minY)
    g3DMaxY = SwizzleFloat(&header.pointee.maxY)
    gNumSplines = Int(SwizzleLong(&header.pointee.numSplines))
    gNumFences = Int(SwizzleLong(&header.pointee.numFences))
    gNumWaterPatches = Int(SwizzleLong(&header.pointee.numWaterPatches))
    gNumUniqueSuperTiles = Int(SwizzleLong(&header.pointee.numUniqueSuperTiles))
    gNumLineMarkers = SwizzleLong(&header.pointee.numCheckpoints)

    ReleaseResource(handHedr)

    if gTerrainTileWidth % Int(SUPERTILE_SIZE) != 0 { // terrain must be non-fractional number of supertiles in w/h
        SwFatal("ReadDataFromPlayfieldFile: terrain width not a supertile multiple")
    }
    if gTerrainTileDepth % Int(SUPERTILE_SIZE) != 0 {
        SwFatal("ReadDataFromPlayfieldFile: terrain depth not a supertile multiple")
    }

    // CALC SOME GLOBALS HERE

    gTerrainTileWidth = (gTerrainTileWidth / Int(SUPERTILE_SIZE)) * Int(SUPERTILE_SIZE) // round size down to nearest supertile multiple
    gTerrainTileDepth = (gTerrainTileDepth / Int(SUPERTILE_SIZE)) * Int(SUPERTILE_SIZE)
    gTerrainUnitWidth = Int(Float(gTerrainTileWidth) * gTerrainPolygonSize) // calc world unit dimensions of terrain
    gTerrainUnitDepth = Int(Float(gTerrainTileDepth) * gTerrainPolygonSize)
    gNumSuperTilesDeep = gTerrainTileDepth / Int(SUPERTILE_SIZE) // calc size in supertiles
    gNumSuperTilesWide = gTerrainTileWidth / Int(SUPERTILE_SIZE)

    // SUPERTILE RELATED RESOURCES

    // READ SUPERTILE GRID MATRIX

    if gSuperTileTextureGrid != nil { // free old array
        free2DArray(gSuperTileTextureGrid)
    }
    gSuperTileTextureGrid = alloc2DArray(Int16.self, rows: Int(gNumSuperTilesDeep), cols: Int(gNumSuperTilesWide))

    if let handSTgd = GetResource(kResSTgd, 1000) { // load grid from rez
        var src = handleData(handSTgd, Int16.self)

        for row in 0..<Int(gNumSuperTilesDeep) {
            for col in 0..<Int(gNumSuperTilesWide) {
                let stId = SwizzleShort(src)
                src += 1
                gSuperTileTextureGrid[row]![col] = stId
            }
        }

        ReleaseResource(handSTgd)
    } else {
        SwFatal("ReadDataFromPlayfieldFile: Error reading supertile rez resource!")
    }

    // READ HEIGHT DATA MATRIX

    let yScale = gTerrainPolygonSize / g3DTileSize // need to scale original geometry units to game units

    gMapYCoords = alloc2DArray(Float.self, rows: Int(gTerrainTileDepth) + 1, cols: Int(gTerrainTileWidth) + 1) // alloc 2D array for map
    gMapYCoordsOriginal = alloc2DArray(Float.self, rows: Int(gTerrainTileDepth) + 1, cols: Int(gTerrainTileWidth) + 1) // and the copy of it

    if let handYCrd = GetResource(kResYCrd, 1000) {
        var src = handleData(handYCrd, Float.self)
        for row in 0...Int(gTerrainTileDepth) {
            for col in 0...Int(gTerrainTileWidth) {
                let v = SwizzleFloat(src) * yScale
                src += 1
                gMapYCoordsOriginal[row]![col] = v
                gMapYCoords[row]![col] = v
            }
        }
        ReleaseResource(handYCrd)
    } else {
        SwAlert("ReadDataFromPlayfieldFile: Error reading height data resource!")
    }

    // ITEM RELATED RESOURCES

    // READ ITEM LIST

    guard let handItms = GetResource(kResItms, 1000) else {
        SwFatal("ReadDataFromPlayfieldFile: Error reading itemlist resource!")
        return
    }
    do {
        HLock(handItms)
        let rezItems = handleData(handItms, File_TerrainItemEntryType.self)

        // COPY INTO OUR STRUCT

        gMasterItemList = AllocPtrClear(MemoryLayout<TerrainItemEntryType>.size * Int(gNumTerrainItems))?.assumingMemoryBound(to: TerrainItemEntryType.self) // alloc array of items

        for i in 0..<Int(gNumTerrainItems) {
            gMasterItemList[i].x = UInt32(Float(SwizzleULong(&rezItems[i].x)) * gMapToUnitValue) // convert coordinates
            gMasterItemList[i].y = UInt32(Float(SwizzleULong(&rezItems[i].y)) * gMapToUnitValue)

            gMasterItemList[i].type = SwizzleUShort(&rezItems[i].type)
            gMasterItemList[i].parm.0 = rezItems[i].parm.0
            gMasterItemList[i].parm.1 = rezItems[i].parm.1
            gMasterItemList[i].parm.2 = rezItems[i].parm.2
            gMasterItemList[i].parm.3 = rezItems[i].parm.3
            gMasterItemList[i].flags = SwizzleUShort(&rezItems[i].flags)
        }

        ReleaseResource(handItms) // nuke the rez
    }

    // SPLINE RELATED RESOURCES

    // READ SPLINE LIST

    if let handSpln = GetResource(kResSpln, 1000) {
        let splinePtr = handleData(handSpln, File_SplineDefType.self)

        gSplineList = AllocPtrClear(MemoryLayout<SplineDefType>.size * gNumSplines)?.assumingMemoryBound(to: SplineDefType.self) // allocate memory for spline data

        for i in 0..<gNumSplines {
            gSplineList[i].numNubs = SwizzleShort(&splinePtr[i].numNubs)
            gSplineList[i].numPoints = SwizzleLong(&splinePtr[i].numPoints)
            gSplineList[i].numItems = SwizzleShort(&splinePtr[i].numItems)

            gSplineList[i].bBox.top = SwizzleShort(&splinePtr[i].bBox.top)
            gSplineList[i].bBox.bottom = SwizzleShort(&splinePtr[i].bBox.bottom)
            gSplineList[i].bBox.left = SwizzleShort(&splinePtr[i].bBox.left)
            gSplineList[i].bBox.right = SwizzleShort(&splinePtr[i].bBox.right)
        }

        ReleaseResource(handSpln) // nuke the rez
    } else {
        gNumSplines = 0
        gSplineList = nil
    }

    // READ SPLINE POINT LIST

    for i in 0..<gNumSplines {
        let spline = gSplineList + i // point to Nth spline

        if let handSpPt = GetResource(kResSpPt, 1000 + Int16(i)) { // read this point list
            let ptList = handleData(handSpPt, SplinePointType.self)

            spline.pointee.pointList = AllocPtrClear(MemoryLayout<SplinePointType>.size * Int(spline.pointee.numPoints))?.assumingMemoryBound(to: SplinePointType.self) // alloc memory for point list

            for j in 0..<Int(spline.pointee.numPoints) { // swizzle
                spline.pointee.pointList[j].x = SwizzleFloat(&ptList[j].x)
                spline.pointee.pointList[j].z = SwizzleFloat(&ptList[j].z)
            }
            ReleaseResource(handSpPt) // nuke the rez
        } else {
            SwFatal("ReadDataFromPlayfieldFile: cant get spline points rez")
        }
    }

    // READ SPLINE ITEM LIST

    for i in 0..<gNumSplines {
        let spline = gSplineList + i // point to Nth spline

        if let handSpIt = GetResource(kResSpIt, 1000 + Int16(i)) {
            SwGameAssert(GetHandleSize(handSpIt) == Int(MemoryLayout<SplineItemType>.size) * Int(spline.pointee.numItems))

            let itemList = handleData(handSpIt, SplineItemType.self)

            spline.pointee.itemList = AllocPtrClear(MemoryLayout<SplineItemType>.size * Int(spline.pointee.numItems))?.assumingMemoryBound(to: SplineItemType.self) // alloc memory for item list

            for j in 0..<Int(spline.pointee.numItems) { // swizzle
                spline.pointee.itemList[j].parm = itemList[j].parm

                spline.pointee.itemList[j].placement = SwizzleFloat(&itemList[j].placement)
                spline.pointee.itemList[j].type = SwizzleUShort(&itemList[j].type)
                spline.pointee.itemList[j].flags = SwizzleUShort(&itemList[j].flags)
            }
            ReleaseResource(handSpIt) // nuke the rez
        } else {
            SwFatal("ReadDataFromPlayfieldFile: cant get spline items rez")
        }
    }

    // FENCE RELATED RESOURCES

    // READ FENCE LIST

    if let handFenc = GetResource(kResFenc, 1000) {
        gFenceList = AllocPtrClear(MemoryLayout<FenceDefType>.size * Int(gNumFences))?.assumingMemoryBound(to: FenceDefType.self) // alloc new ptr for fence data
        if gFenceList == nil {
            SwFatal("ReadDataFromPlayfieldFile: AllocPtr failed")
        }

        let inData = handleData(handFenc, FileFenceDefType.self) // get ptr to input fence list

        for i in 0..<Int(gNumFences) { // copy data from rez to new list
            gFenceList[i].type = SwizzleUShort(&inData[i].type)
            gFenceList[i].numNubs = SwizzleShort(&inData[i].numNubs)
            gFenceList[i].nubList = nil
            gFenceList[i].sectionVectors = nil
        }
        ReleaseResource(handFenc)
    } else {
        gNumFences = 0
    }

    // READ FENCE NUB LIST

    for i in 0..<Int(gNumFences) {
        guard let handFnNb = GetResource(kResFnNb, 1000 + Int16(i)) else { // get rez
            SwFatal("ReadDataFromPlayfieldFile: cant get fence nub rez")
            return
        }
        HLock(handFnNb)

        let fileFencePoints = handleData(handFnNb, FencePointType.self)

        gFenceList[i].nubList = AllocPtrClear(MemoryLayout<FenceDefType>.size * Int(gFenceList[i].numNubs))?.assumingMemoryBound(to: OGLPoint3D.self) // alloc new ptr for nub array
        if gFenceList[i].nubList == nil {
            SwFatal("ReadDataFromPlayfieldFile: AllocPtr failed")
        }

        for j in 0..<Int(gFenceList[i].numNubs) { // convert x,z to x,y,z
            gFenceList[i].nubList[j].x = Float(SwizzleLong(&fileFencePoints[j].x))
            gFenceList[i].nubList[j].z = Float(SwizzleLong(&fileFencePoints[j].z))
            gFenceList[i].nubList[j].y = 0
        }
        ReleaseResource(handFnNb)
    }

    // WATER RELATED RESOURCES

    // READ WATER LIST

    if let handLiqd = GetResource(kResLiqd, 1000) {
        DetachResource(handLiqd)
        HLockHi(handLiqd)
        gWaterListHandle = handLiqd.withMemoryRebound(to: UnsafeMutablePointer<WaterDefType>?.self, capacity: 1) { $0 }
        gWaterList = gWaterListHandle!.pointee

        for i in 0..<Int(gNumWaterPatches) { // swizzle
            gWaterList[i].type = SwizzleUShort(&gWaterList[i].type)
            gWaterList[i].flags = SwizzleULong(&gWaterList[i].flags)
            gWaterList[i].height = SwizzleLong(&gWaterList[i].height)
            gWaterList[i].numNubs = SwizzleShort(&gWaterList[i].numNubs)

            gWaterList[i].hotSpotX = SwizzleFloat(&gWaterList[i].hotSpotX)
            gWaterList[i].hotSpotZ = SwizzleFloat(&gWaterList[i].hotSpotZ)

            gWaterList[i].bBox.top = SwizzleShort(&gWaterList[i].bBox.top)
            gWaterList[i].bBox.bottom = SwizzleShort(&gWaterList[i].bBox.bottom)
            gWaterList[i].bBox.left = SwizzleShort(&gWaterList[i].bBox.left)
            gWaterList[i].bBox.right = SwizzleShort(&gWaterList[i].bBox.right)

            let nubs = waterNubListBase(gWaterList + i)
            for j in 0..<Int(gWaterList[i].numNubs) {
                nubs[j].x = SwizzleFloat(&nubs[j].x)
                nubs[j].y = SwizzleFloat(&nubs[j].y)
            }
        }
    } else {
        gNumWaterPatches = 0
    }

    // LINE MARKER RESOURCES

    if gNumLineMarkers > 0 {
        if gNumLineMarkers > Int32(MAX_LINEMARKERS) {
            SwFatal("ReadDataFromPlayfieldFile: gNumLineMarkers > MAX_LINEMARKERS")
        }

        // READ CHECKPOINT LIST

        if let handCkPt = GetResource(kResCkPt, 1000) {
            HLock(handCkPt)
            BlockMove(handCkPt.pointee, GetLineMarkerPtr(0), GetHandleSize(handCkPt))
            ReleaseResource(handCkPt)

            // CONVERT COORDINATES

            for i in 0..<Int(gNumLineMarkers) {
                let lm = GetLineMarkerPtr(Int32(i))

                lm.pointee.infoBits = SwizzleShort(&lm.pointee.infoBits) // swizzle data
                let lmX = lineMarkerXBase(lm)
                let lmZ = lineMarkerZBase(lm)
                lmX[0] = SwizzleFloat(lmX)
                lmX[1] = SwizzleFloat(lmX + 1)
                lmZ[0] = SwizzleFloat(lmZ)
                lmZ[1] = SwizzleFloat(lmZ + 1)

                lmX[0] *= gMapToUnitValue
                lmZ[0] *= gMapToUnitValue
                lmX[1] *= gMapToUnitValue
                lmZ[1] *= gMapToUnitValue
            }
        } else {
            gNumLineMarkers = 0
        }
    }

    // CLOSE REZ FILE

    CloseResFile(fRefNum)

    // READ SUPERTILE IMAGE DATA FROM DATA FORK

    // OPEN THE DATA FORK

    var dataForkRefNum: Int16 = 0
    if FSpOpenDF(specPtr, Int8(fsRdPerm.rawValue), &dataForkRefNum) != kNoErr {
        SwFatal("ReadDataFromPlayfieldFile: FSpOpenDF failed!")
    }

    // HQ_TERRAIN is enabled for this build (see game.h) - assemble seamless textures.

    SwGameAssertMessage(gSuperTilePixelBuffers == nil, "gSuperTilePixelBuffers already allocated!")
    gSuperTilePixelBuffers = AllocPtrClear(MemoryLayout<Ptr?>.size * Int(gNumUniqueSuperTiles))?.assumingMemoryBound(to: Ptr?.self)

    let seamlessTextureCanvas = AllocPtrClear(4 * (Int(SUPERTILE_TEXMAP_SIZE) + 2) * (Int(SUPERTILE_TEXMAP_SIZE) + 2))!.assumingMemoryBound(to: Int8.self)

    for row in 0..<(Int(gNumSuperTilesDeep) + 4) { // go 4 rows beyond terrain height so all 3 passes can run to completion
        // We could do the three passes below separately, but weaving them in a single for loop
        // lets us keep memory pressure low while assembling the seamless textures.

        let rowPass1 = row // 1st pass: load JPEG images
        let rowPass2 = row - 2 // 2nd pass: assemble seamless textures (2 rows behind, b/c need data from 1 row below + 1 column across)
        let rowPass3 = row - 4 // 3rd pass: free up memory (4 rows behind)

        for col in 0..<Int(gNumSuperTilesWide) {
            // 1st pass: load JPEG textures
            if 0 <= rowPass1 && rowPass1 < Int(gNumSuperTilesDeep) {
                let stId = gSuperTileTextureGrid[rowPass1]![col]
                if stId >= 0 {
                    gSuperTilePixelBuffers[Int(stId)] = LoadSuperTilePixelBuffer(dataForkRefNum)

                    // Update loading screen here
                    DrawLoading(Float(stId) / Float(gNumUniqueSuperTiles))
                }
            }

            // 2nd pass: assemble seamless textures
            if 0 <= rowPass2 && rowPass2 < Int(gNumSuperTilesDeep) {
                let stId = gSuperTileTextureGrid[rowPass2]![col]
                if stId >= 0 {
                    AssembleSeamlessSuperTileTexture(Int32(rowPass2), Int32(col), seamlessTextureCanvas)
                    GetSuperTileTextureObjectSlot(Int32(stId))!.pointee = LoadSuperTileTexture(seamlessTextureCanvas, 2 + Int32(SUPERTILE_TEXMAP_SIZE))
                }
            }

            // 3rd pass: free up pixel buffers from rows that we won't need to look at again
            if 0 <= rowPass3 && rowPass3 < Int(gNumSuperTilesDeep) {
                let stId = gSuperTileTextureGrid[rowPass3]![col]
                if stId >= 0 {
                    SafeDisposePtr(gSuperTilePixelBuffers[Int(stId)])
                    gSuperTilePixelBuffers[Int(stId)] = nil
                }
            }
        }
    }

    SafeDisposePtr(seamlessTextureCanvas)

    // Check that we have all the textures we need and that we freed all temporary images
    for i in 0..<Int(gNumUniqueSuperTiles) {
        SwGameAssertMessage(GetSuperTileTextureObjectSlot(Int32(i))!.pointee != nil, "2nd pass incomplete: not all textures were loaded")
        SwGameAssertMessage(gSuperTilePixelBuffers[i] == nil, "3rd pass incomplete: not all buffers were freed")
    }

    SafeDisposePtr(gSuperTilePixelBuffers)
    gSuperTilePixelBuffers = nil

    DrawLoading(1.0)

    // CLOSE THE FILE

    FSClose(dataForkRefNum)
}

// MARK: - Supertile Textures

func LoadSuperTilePixelBuffer(_ fRefNum: Int16) -> Ptr! {
    let texSize = Int(SUPERTILE_TEXMAP_SIZE)

    // READ THE SIZE OF THE NEXT COMPRESSED SUPERTILE TEXTURE

    var dataSize: Int32 = 0

    var size = Int32(MemoryLayout<Int32>.size)
    var readSize = Int(size)
    let iErr1: OSErr = withUnsafeMutablePointer(to: &dataSize) {
        $0.withMemoryRebound(to: Int8.self, capacity: 4) {
            FSRead(fRefNum, &readSize, $0)
        }
    }
    SwGameAssert(iErr1 == 0)

    dataSize = SwizzleLong(&dataSize)

    // ALLOCATE JPEG BUFFER

    let jpegBuffer = AllocPtrClear(Int(dataSize))!.assumingMemoryBound(to: Int8.self)

    // READ THE IMAGE DESC DATA + THE COMPRESSED IMAGE DATA

    size = dataSize
    readSize = Int(size)
    let iErr2 = FSRead(fRefNum, &readSize, jpegBuffer)
    SwGameAssert(iErr2 == 0)

    // DECOMPRESS THE IMAGE

    let textureBuffer = DecompressQTImage(jpegBuffer, Int32(dataSize), Int32(texSize), Int32(texSize))!

    SafeDisposePtr(jpegBuffer)

    // FLIP IT VERTICALLY
    //
    // Texture pixel rows are stored bottom-up in the .ter file.
    // We could just flip the V's, but it's easier to reason
    // about top-down images when we're stitching together the
    // seamless textures.

    let rowBytes = texSize * 4
    let topRowPixelsCopy = AllocPtrClear(rowBytes)!.assumingMemoryBound(to: Int8.self)

    var topRow = 0
    var bottomRow = texSize - 1
    while topRow < bottomRow {
        let topRowPixels = textureBuffer + topRow * rowBytes
        let bottomRowPixels = textureBuffer + bottomRow * rowBytes

        memcpy(topRowPixelsCopy, topRowPixels, rowBytes)
        memcpy(topRowPixels, bottomRowPixels, rowBytes)
        memcpy(bottomRowPixels, topRowPixelsCopy, rowBytes)

        topRow += 1
        bottomRow -= 1
    }

    SafeDisposePtr(topRowPixelsCopy)

    return textureBuffer
}

private func blit32(_ src: UnsafePointer<Int8>?, _ srcWidth: Int, _ srcHeight: Int, _ srcRectX: Int, _ srcRectY: Int, _ srcRectWidth: Int, _ srcRectHeight: Int, _ dst: UnsafeMutablePointer<Int8>, _ dstWidth: Int, _ dstHeight: Int, _ dstRectX: Int, _ dstRectY: Int) {
    guard var src else { return }

    let bpp = 4

    src += bpp * (srcRectX + srcWidth * srcRectY)
    var dst = dst + bpp * (dstRectX + dstWidth * dstRectY)

    for _ in 0..<srcRectHeight {
        memcpy(dst, src, bpp * srcRectWidth)
        src += bpp * srcWidth
        dst += bpp * dstWidth
    }
}

private func getSuperTileImage(_ row: Int, _ col: Int) -> UnsafePointer<Int8>? {
    if row < 0 || row > Int(gNumSuperTilesDeep) - 1 // row out of bounds
        || col < 0 || col > Int(gNumSuperTilesWide) - 1 { // column out of bounds
        return nil
    }

    let superTileId = gSuperTileTextureGrid[row]![col]

    if superTileId < 0 { // blank texture
        return nil
    }

    let image = gSuperTilePixelBuffers[Int(superTileId)]
    SwGameAssert(image != nil)

    return image.map { UnsafePointer($0) }
}

func AssembleSeamlessSuperTileTexture(_ row: Int32, _ col: Int32, _ canvas: Ptr!) {
    SwGameAssert(getSuperTileImage(Int(row), Int(col)) != nil) // make sure we're not trying to do assemble a blank texture

    let tw = Int(SUPERTILE_TEXMAP_SIZE) // supertile width & height
    let th = Int(SUPERTILE_TEXMAP_SIZE)
    let cw = tw + 2 // canvas width & height
    let ch = th + 2

    // Clear canvas to black
    memset(canvas, 0, cw * ch * 4) // *4 => 32-bit RBGA

    // Blit supertile image to middle of canvas
    blit32(getSuperTileImage(Int(row), Int(col)), tw, th, 0, 0, tw, th, canvas, cw, ch, 1, 1)

    // Stitch edges from neighboring supertiles on each side
    //     srcBuf                           sW  sH    sX    sY  rW  rH  dstBuf  dW  dH    dX    dY
    blit32(getSuperTileImage(Int(row) - 1, Int(col)), tw, th, 0, th - 1, tw, 1, canvas, cw, ch, 1, 0)
    blit32(getSuperTileImage(Int(row) + 1, Int(col)), tw, th, 0, 0, tw, 1, canvas, cw, ch, 1, ch - 1)
    blit32(getSuperTileImage(Int(row), Int(col) - 1), tw, th, tw - 1, 0, 1, th, canvas, cw, ch, 0, 1)
    blit32(getSuperTileImage(Int(row), Int(col) + 1), tw, th, 0, 0, 1, th, canvas, cw, ch, cw - 1, 1)

    // Copy 1px corners from diagonal neighbors
    //     srcBuf                           sW  sH    sX    sY  rW  rH  dstBuf  dW  dH    dX    dY
    blit32(getSuperTileImage(Int(row) - 1, Int(col) + 1), tw, th, 0, th - 1, 1, 1, canvas, cw, ch, cw - 1, 0)
    blit32(getSuperTileImage(Int(row) - 1, Int(col) - 1), tw, th, tw - 1, th - 1, 1, 1, canvas, cw, ch, 0, 0)
    blit32(getSuperTileImage(Int(row) + 1, Int(col) - 1), tw, th, tw - 1, 0, 1, 1, canvas, cw, ch, 0, ch - 1)
    blit32(getSuperTileImage(Int(row) + 1, Int(col) + 1), tw, th, 0, 0, 1, 1, canvas, cw, ch, cw - 1, ch - 1)
}

func LoadSuperTileTexture(_ textureBuffer: Ptr!, _ texSize: Int32) -> UnsafeMutablePointer<MOMaterialObject>! {
    // LOAD GL TEXTURE

    let textureName = OGL_TextureMap_Load(textureBuffer, texSize, texSize, Int32(GL_RGBA), Int32(GL_RGBA), Int32(GL_UNSIGNED_BYTE))

    // CREATE MATERIAL OBJECT

    var matData = MOMaterialData()
    matData.flags = UInt32(BG3D_MATERIALFLAG_CLAMP_U | BG3D_MATERIALFLAG_CLAMP_V | BG3D_MATERIALFLAG_TEXTURED)
    matData.multiTextureMode = UInt16(MULTI_TEXTURE_MODE_REFLECTIONSPHERE)
    matData.multiTextureCombine = UInt16(MULTI_TEXTURE_COMBINE_ADD)
    matData.diffuseColor = OGLColorRGBA(r: 1, g: 1, b: 1, a: 1)
    matData.numMipmaps = 1 // 1 texture
    matData.width = UInt32(texSize)
    matData.height = UInt32(texSize)
    matData.textureName.0 = textureName

    return withUnsafeMutablePointer(to: &matData) { ptr in
        MO_CreateNewObjectOfType(.material, 0, UnsafeMutableRawPointer(ptr)) // create the new object
    }?.assumingMemoryBound(to: MOMaterialObject.self)
}

// MARK: - Save Game

// Returns true if saving was successful
func SaveGame(_ fileSlot: Int32) -> UInt8 {
    let path = "File\(Character(UnicodeScalar(UInt8(65 + fileSlot))))"

    // GET TIMESTAMP

    var timestampNanoseconds: SDL_Time = 0
    SDL_GetCurrentTime(&timestampNanoseconds)

    // CREATE SAVE GAME DATA

    var saveData = SaveGameType()
    saveData.timestamp = UInt64(Double(timestampNanoseconds) / 1e9)
    saveData.level = UInt8(gLevelNum) // save @ beginning of next level
    saveData.numLives = UInt8(GetPlayerInfoEntry(0)!.pointee.numFreeLives)
    saveData.health = GetPlayerInfoEntry(0)!.pointee.health
    saveData.jetpackFuel = GetPlayerInfoEntry(0)!.pointee.jetpackFuel
    saveData.shieldPower = GetPlayerInfoEntry(0)!.pointee.shieldPower

    for (i, _) in WeaponType.allCases.enumerated() {
        weaponQuantityBase(&saveData)[i] = UInt16(bitPattern: playerWeaponQuantityBase(GetPlayerInfoEntry(0)!)[i])
    }

    // SAVE IT TO DISK

    return path.withCString { pathC in
        withUnsafeMutablePointer(to: &saveData) { dataPtr in
            dataPtr.withMemoryRebound(to: Int8.self, capacity: MemoryLayout<SaveGameType>.size) { rawPtr in
                kNoErr == SaveUserDataFile(pathC, SAVEGAME_MAGIC, MemoryLayout<SaveGameType>.size, rawPtr) ? 1 : 0
            }
        }
    }
}

@inline(__always) private func weaponQuantityBase(_ save: UnsafeMutablePointer<SaveGameType>) -> UnsafeMutablePointer<UInt16> {
    UnsafeMutableRawPointer(save.pointer(to: \.weaponQuantity)!).assumingMemoryBound(to: UInt16.self)
}

@inline(__always) private func playerWeaponQuantityBase(_ p: UnsafeMutablePointer<PlayerInfoType>) -> UnsafeMutablePointer<Int16> {
    UnsafeMutableRawPointer(p.pointer(to: \.weaponQuantity)!).assumingMemoryBound(to: Int16.self)
}

func LoadSavedGame(_ fileSlot: Int32, _ outData: UnsafeMutablePointer<SaveGameType>!) -> UInt8 {
    let path = "File\(Character(UnicodeScalar(UInt8(65 + fileSlot))))"

    var scratch = SaveGameType()

    let ok: Bool = path.withCString { pathC in
        withUnsafeMutablePointer(to: &scratch) { scratchPtr in
            scratchPtr.withMemoryRebound(to: Int8.self, capacity: MemoryLayout<SaveGameType>.size) { rawPtr in
                kNoErr == LoadUserDataFile(pathC, SAVEGAME_MAGIC, MemoryLayout<SaveGameType>.size, rawPtr)
            }
        }
    }

    if !ok {
        return 0
    }

    outData.pointee = scratch
    return 1
}

@c @implementation
public func DeleteSavedGame(_ fileSlot: Int32) -> UInt8 {
    let path = "File\(Character(UnicodeScalar(UInt8(65 + fileSlot))))"

    let iErr = path.withCString { DeleteUserDataFile($0) }

    return iErr == kNoErr ? 1 : 0
}

func UseSaveGame(_ saveData: UnsafePointer<SaveGameType>!) {
    gLevelNum = Int16(saveData.pointee.level)
    GetPlayerInfoEntry(0)!.pointee.numFreeLives = Int16(saveData.pointee.numLives)
    GetPlayerInfoEntry(0)!.pointee.health = saveData.pointee.health
    GetPlayerInfoEntry(0)!.pointee.jetpackFuel = saveData.pointee.jetpackFuel
    GetPlayerInfoEntry(0)!.pointee.shieldPower = saveData.pointee.shieldPower

    let saveWeapons = UnsafeMutablePointer(mutating: saveData).map { weaponQuantityBase($0) }!
    let playerWeapons = playerWeaponQuantityBase(GetPlayerInfoEntry(0)!)
    for (i, _) in WeaponType.allCases.enumerated() {
        playerWeapons[i] = Int16(bitPattern: saveWeapons[i])
    }
}

// MARK: - User Data Files

func InitPrefsFolder(_ createIt: UInt8) -> OSErr {
    var createdDirID: Int = 0

    let iErr = FindFolder(Int16(kOnSystemDisk), OSType(kPreferencesFolderType), 0, &gPrefsFolderVRefNum, &gPrefsFolderDirID) // locate the folder
    if iErr != kNoErr {
        SwAlert("Warning: Cannot locate the Preferences folder.")
    }

    if createIt != 0 {
        return DirCreate(gPrefsFolderVRefNum, gPrefsFolderDirID, PREFS_FOLDER_NAME, &createdDirID) // make folder in there
    }

    return iErr
}

private func makeFSSpecForUserDataFile(_ filename: String, _ spec: UnsafeMutablePointer<FSSpec>) -> OSErr {
    let path = ":\(PREFS_FOLDER_NAME_SWIFT):\(filename)"
    return path.withCString { FSMakeFSSpec(gPrefsFolderVRefNum, gPrefsFolderDirID, $0, spec) }
}

private let PREFS_FOLDER_NAME_SWIFT = "Nanosaur2"

// Load struct from user file in prefs folder
func LoadUserDataFile(_ filename: UnsafePointer<CChar>!, _ magic: UnsafePointer<CChar>!, _ payloadLength: Int, _ payloadPtr: Ptr!) -> OSErr {
    var file = FSSpec()
    let magicLength = Int(strlen(magic)) + 1 // including null-terminator
    var fileMagic = [Int8](repeating: 0, count: 64)

    SwGameAssert(magicLength < 64)

    // INIT PREFS FOLDER FSSPEC FIRST

    _ = InitPrefsFolder(0)

    // READ FILE

    _ = makeFSSpecForUserDataFile(String(cString: filename), &file)
    var refNum: Int16 = 0
    var iErr = FSpOpenDF(&file, Int8(fsRdPerm.rawValue), &refNum)
    if iErr != kNoErr {
        return iErr
    }

    // CHECK FILE LENGTH

    var eof: Int = 0
    GetEOF(refNum, &eof)

    if eof != magicLength + payloadLength {
        SwLog("File '\(String(cString: filename))' appears to be corrupt!")
        FSClose(refNum)
        return kBadFileFormat
    }

    // READ HEADER

    var count = magicLength
    iErr = fileMagic.withUnsafeMutableBufferPointer { FSRead(refNum, &count, $0.baseAddress) }
    if iErr != kNoErr || count != magicLength || strncmp(magic, fileMagic, magicLength - 1) != 0 {
        SwLog("File '\(String(cString: filename))' appears to be corrupt!")
        FSClose(refNum)
        return kBadFileFormat
    }

    // READ PAYLOAD

    let payloadCopy = AllocPtrClear(payloadLength)!.assumingMemoryBound(to: Int8.self)

    count = payloadLength
    iErr = FSRead(refNum, &count, payloadCopy)
    if iErr != kNoErr || count != payloadLength {
        SwLog("File '\(String(cString: filename))' appears to be corrupt!")
        SafeDisposePtr(payloadCopy)
        FSClose(refNum)
        return kBadFileFormat
    }

    // COMMIT PAYLOAD AND FINISH

    BlockMove(payloadCopy, payloadPtr, payloadLength)

    SafeDisposePtr(payloadCopy)
    FSClose(refNum)
    return kNoErr
}

// Save struct to user file in prefs folder
func SaveUserDataFile(_ filename: UnsafePointer<CChar>!, _ magic: UnsafePointer<CChar>!, _ payloadLength: Int, _ payloadPtr: Ptr!) -> OSErr {
    var file = FSSpec()

    _ = InitPrefsFolder(1)

    // CREATE BLANK FILE

    _ = makeFSSpecForUserDataFile(String(cString: filename), &file)
    FSpDelete(&file) // delete any existing file
    var iErr = FSpCreate(&file, kGameIDFourCC, kPrefFourCC, -1) // smSystemScript
    if iErr != kNoErr {
        return iErr
    }

    // OPEN FILE

    var refNum: Int16 = 0
    iErr = FSpOpenDF(&file, Int8(fsRdWrPerm.rawValue), &refNum)
    if iErr != kNoErr {
        FSpDelete(&file)
        return iErr
    }

    // WRITE MAGIC

    var count = Int(strlen(magic)) + 1
    iErr = FSWrite(refNum, &count, UnsafeMutablePointer(mutating: magic))
    if iErr != kNoErr {
        FSClose(refNum)
        return iErr
    }

    // WRITE DATA

    count = payloadLength
    iErr = FSWrite(refNum, &count, payloadPtr)
    FSClose(refNum)

    SwLog("Wrote \(String(cString: filename))")

    return iErr
}

func DeleteUserDataFile(_ filename: UnsafePointer<CChar>!) -> OSErr {
    var file = FSSpec()

    _ = InitPrefsFolder(1)
    var iErr = makeFSSpecForUserDataFile(String(cString: filename), &file)
    if iErr == kNoErr {
        iErr = FSpDelete(&file)
    }
    return iErr
}

// Resolves an engine-relative colon-path (e.g. ":Models:global.bg3d") to an
// FSSpec rooted at the game's Data folder (gDataSpec). Every direct-FSSpec
// caller in the game (Bg3d.swift/Sound.swift/LevelIntro.swift/LoadLevel.swift/
// OGL_Support.swift), not just LoadDataFile below, goes through this instead
// of duplicating the FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ...)
// call, so a future alternate File.swift (e.g. a 3DS RomFS-backed one) only
// needs to change this one function's root, not every call site - even
// though most of those callers still stream the file themselves via
// FSpOpenDF/refNum (BG3D/audio parsing) rather than going through
// LoadDataFile's whole-buffer read.
@discardableResult
func ResolveDataFileSpec(_ path: UnsafePointer<CChar>!, _ outSpec: UnsafeMutablePointer<FSSpec>!) -> OSErr {
    FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, path, outSpec)
}

// String overload: FSMakeFSSpec's C import lets Swift bridge a String to its
// UnsafePointer<CChar> parameter implicitly at the call site, but that magic
// doesn't extend to a plain Swift function like the one above, so callers
// with a String path (LevelIntro.swift/LoadLevel.swift/OGL_Support.swift)
// need this instead of manually reaching for withCString each time.
@discardableResult
func ResolveDataFileSpec(_ path: String, _ outSpec: UnsafeMutablePointer<FSSpec>!) -> OSErr {
    path.withCString { ResolveDataFileSpec($0, outSpec) }
}

// Use SafeDisposePtr when done.
func LoadDataFile(_ path: UnsafePointer<CChar>!, _ outLength: UnsafeMutablePointer<Int>!) -> Ptr! {
    var spec = FSSpec()

    let err = ResolveDataFileSpec(path, &spec)
    if err != kNoErr {
        return nil
    }

    var refNum: Int16 = 0
    let openErr = FSpOpenDF(&spec, Int8(fsRdPerm.rawValue), &refNum)
    SwGameAssertMessage(openErr == 0, path)

    // Get number of bytes until EOF
    var fileLength = 0
    GetEOF(refNum, &fileLength)

    // Prep data buffer
    // Alloc 1 extra byte so LoadTextFile can return a null-terminated C string!
    let data = AllocPtrClear(fileLength + 1)!.assumingMemoryBound(to: Int8.self)

    // Read file into data buffer
    var readBytes = fileLength
    let readErr = FSRead(refNum, &readBytes, data)
    SwGameAssertMessage(readErr == kNoErr, path)
    FSClose(refNum)

    SwGameAssertMessage(fileLength == readBytes, path)

    if let outLength {
        outLength.pointee = fileLength
    }

    return data
}

// Use SafeDisposePtr when done.
func LoadTextFile(_ spec: UnsafePointer<CChar>!, _ outLength: UnsafeMutablePointer<Int>!) -> UnsafeMutablePointer<CChar>! {
    LoadDataFile(spec, outLength)
}

// MARK: - CSV

// Call this function repeatedly to iterate over cells in a CSV table.
// THIS FUNCTION MODIFIES THE INPUT BUFFER!
func CSVIterator(_ csvCursor: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>!, _ eolOut: UnsafeMutablePointer<Bool>!) -> UnsafeMutablePointer<CChar>! {
    let kCSVStateStop = 0
    let kCSVStateWithinQuotedString = 1
    let kCSVStateWithinUnquotedString = 2
    let kCSVStateAwaitingSeparator = 3

    let SEPARATOR: Int8 = 44 // ','
    let QUOTE_DELIMITER: Int8 = 34 // '"'

    SwGameAssert(csvCursor != nil)
    SwGameAssert(csvCursor.pointee != nil)

    var reader = UnsafePointer(csvCursor.pointee!)
    var writer = csvCursor.pointee! // we'll write over the column as we read it
    var columnStart: UnsafeMutablePointer<CChar>? = writer
    var eol = false

    if reader.pointee == 0 {
        columnStart = nil // signify nothing more to read
        eol = true

        writer.pointee = 0 // terminate string
        csvCursor.pointee = nil
        eolOut.pointee = eol
        return columnStart
    }

    var state: Int

    if reader.pointee == QUOTE_DELIMITER {
        state = kCSVStateWithinQuotedString
        reader += 1
    } else {
        state = kCSVStateWithinUnquotedString
    }

    while reader.pointee != 0 && state != kCSVStateStop {
        if reader[0] == 13 && reader[1] == 10 { // "\r\n"
            // windows CRLF -- skip the \r; we'll look at the \n later
            reader += 1
            continue
        }

        switch state {
        case kCSVStateWithinQuotedString:
            if reader.pointee == QUOTE_DELIMITER {
                state = kCSVStateAwaitingSeparator
            } else {
                writer.pointee = reader.pointee
                writer += 1
            }

        case kCSVStateWithinUnquotedString:
            if reader.pointee == SEPARATOR {
                state = kCSVStateStop
            } else if reader.pointee == 10 { // '\n'
                eol = true
                state = kCSVStateStop
            } else {
                writer.pointee = reader.pointee
                writer += 1
            }

        case kCSVStateAwaitingSeparator:
            if reader.pointee == SEPARATOR {
                state = kCSVStateStop
            } else if reader.pointee == 10 { // '\n'
                eol = true
                state = kCSVStateStop
            } else {
                SwGameAssertMessage(false, "unexpected token in CSV file")
            }

        default:
            break
        }

        reader += 1
    }

    writer.pointee = 0 // terminate string

    SwGameAssertMessage(reader >= UnsafePointer(writer), "writer went past reader!!!")

    csvCursor.pointee = UnsafeMutablePointer(mutating: reader)
    eolOut.pointee = eol
    return columnStart
}

// MARK: - QuickTime Image Decompression

// Caller is responsible for freeing the pointer!
func DecompressQTImage(_ data: UnsafePointer<CChar>!, _ dataSize: Int32, _ w: Int32, _ h: Int32) -> Ptr! {
    // The beginning of the buffer is an ImageDescription record.
    // The first int is an offset to the actual data.
    var offsetSrc = data.withMemoryRebound(to: Int32.self, capacity: 1) { $0.pointee }
    let offset = SwizzleLong(&offsetSrc)
    let payloadSize = dataSize - offset
    let payload = data + Int(offset)

    var actualW: Int32 = 0
    var actualH: Int32 = 0
    let pixelData = payload.withMemoryRebound(to: UInt8.self, capacity: Int(payloadSize)) {
        stbi_load_from_memory($0, payloadSize, &actualW, &actualH, nil, 4)
    }
    SwGameAssert(pixelData != nil)
    SwGameAssert(actualW == w)
    SwGameAssert(actualH == h)

    return pixelData.map { UnsafeMutableRawPointer($0).assumingMemoryBound(to: Int8.self) }
}
