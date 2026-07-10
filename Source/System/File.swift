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

// SAVE GAME
// Native Swift struct - was `typedef struct {...} SaveGameType;` in file.h.
// Zero C callers/globals reference it (see project memory), so it moved
// entirely off the C ABI. Also used by MainMenu.swift/Menu.swift.
struct SaveGameType {
    var timestamp: UInt64 = 0
    var level: UInt8 = 0
    var numLives: UInt8 = 0
    var weaponQuantity: InlineArray<5, UInt16> = InlineArray(repeating: 0) // must match NUM_WEAPON_TYPES
    var health: Float = 0
    var jetpackFuel: Float = 0
    var shieldPower: Float = 0
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

// Resource FourCCs
private let kResHedr: ResType = fourCC("Hedr")
private let kResBone: ResType = fourCC("Bone")
private let kResBonP: ResType = fourCC("BonP")
private let kResBonN: ResType = fourCC("BonN")
private let kResRelP: ResType = fourCC("RelP")
private let kResAnHd: ResType = fourCC("AnHd")
private let kResEvnt: ResType = fourCC("Evnt")
private let kResNumK: ResType = fourCC("NumK")
private let kResKeyF: ResType = fourCC("KeyF")
private let kResSTgd: ResType = fourCC("STgd")
private let kResYCrd: ResType = fourCC("YCrd")
private let kResItms: ResType = fourCC("Itms")
private let kResSpln: ResType = fourCC("Spln")
private let kResSpPt: ResType = fourCC("SpPt")
private let kResSpIt: ResType = fourCC("SpIt")
private let kResFenc: ResType = fourCC("Fenc")
private let kResFnNb: ResType = fourCC("FnNb")
private let kResLiqd: ResType = fourCC("Liqd")
private let kResCkPt: ResType = fourCC("CkPt")
private let kGameIDFourCC: OSType = fourCC("NAN2")
private let kPrefFourCC: OSType = fourCC("Pref")

// `noErr`/`badFileFormat` come from the named C enum `EErrors`, which doesn't
// import cleanly as a plain `OSErr` (Int16) constant in this context.
private let kNoErr: OSErr = 0
private let kBadFileFormat: OSErr = -208

// MARK: - Resource-fork reading (ResourceFile, not Pomme's Resource Manager)
//
// Skeleton/playfield files store their tagged chunks ('Bone', 'Hedr', 'Item',
// 'Spln', etc.) in a real classic-Mac resource fork, saved to disk as an
// AppleDouble-wrapped ".rsrc" companion file (e.g. raptor.skeleton.rsrc,
// battle1.ter.rsrc). This used to go through Pomme's GetResource/
// FSpOpenResFile/Handle-based Resource Manager emulation; now it's read via
// Sources/ResourceFile (a tested, standalone parser - see
// Tests/ResourceFileTests) instead, to reduce this project's dependency on
// Pomme. Only the resource-reading path changes: SwFSMakeFSSpec/SwFSpOpenDF/
// SwFSRead/SwFSClose (plain file I/O, see FileSystem.swift) are unchanged.

// Appends ".rsrc" to `spec`'s filename and resolves the sibling FSSpec in the
// same directory - the on-disk convention for a resource-fork companion file.
private func rsrcCompanionSpec(of spec: UnsafeMutablePointer<FSSpec>) -> FSSpec {
    let cNamePtr = UnsafeMutableRawPointer(spec.pointer(to: \.cName)!).assumingMemoryBound(to: Int8.self)
    let filename = String(cString: cNamePtr) + ".rsrc"

    var rsrcSpec = FSSpec()
    _ = SwFSMakeFSSpec(spec.pointee.vRefNum, spec.pointee.parID, filename, &rsrcSpec)
    return rsrcSpec
}

// Plain data-fork read of an already-resolved FSSpec (same SwFSpOpenDF/
// SwGetEOF/SwFSRead/SwFSClose pattern already used elsewhere in this
// codebase, e.g. ImportBG3D in Bg3d.swift).
func readWholeFile(_ spec: UnsafeMutablePointer<FSSpec>) -> [UInt8]? {
    var refNum: Int16 = 0
    guard SwFSpOpenDF(spec, Int8(fsRdPerm.rawValue), &refNum) == kNoErr else {
        return nil
    }
    defer { SwFSClose(refNum) }

    var fileLength = 0
    SwGetEOF(refNum, &fileLength)

    var fileBytes = [UInt8](repeating: 0, count: fileLength)
    let readErr: OSErr = fileBytes.withUnsafeMutableBytes { buf in
        var readBytes = fileLength
        return SwFSRead(refNum, &readBytes, buf.baseAddress!.assumingMemoryBound(to: Int8.self))
    }
    guard readErr == kNoErr else { return nil }

    return fileBytes
}

private func loadResourceFork(sibling spec: UnsafeMutablePointer<FSSpec>) -> ResourceFile? {
    var rsrcSpec = rsrcCompanionSpec(of: spec)
    guard let bytes = readWholeFile(&rsrcSpec) else { return nil }
    return try? ResourceFile(parsing: bytes)
}

// Equivalent of GetResource(type,id) + HLock + handleData(hand, T.self): a
// fresh AllocPtr'd copy of the resource's raw bytes, reinterpreted as T.
// Dispose with SafeDisposePtr (in place of the old ReleaseResource call).
private func loadResource<T>(_ resourceFile: ResourceFile, _ type: ResType, _ id: Int16, as: T.Type) -> UnsafeMutablePointer<T>? {
    guard let bytes = resourceFile.resource(type: type, id: id) else { return nil }
    guard let ptr = AllocPtr(max(bytes.count, 1)) else { return nil }
    bytes.withUnsafeBytes { raw in
        ptr.copyMemory(from: raw.baseAddress!, byteCount: bytes.count)
    }
    return ptr.assumingMemoryBound(to: T.self)
}

// Equivalent of GetHandleSize(hand) for a resource loaded via loadResource above.
private func resourceByteCount(_ resourceFile: ResourceFile, _ type: ResType, _ id: Int16) -> Int {
    resourceFile.resource(type: type, id: id)?.count ?? 0
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
    _ = SwFSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, pathBuf, &fsSpecSkeleton)

    pathBuf = ":Skeletons:\(modelName).bg3d"
    _ = SwFSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, pathBuf, &fsSpecBG3D)

    // OPEN THE FILE'S REZ FORK

    guard let resourceFile = loadResourceFork(sibling: &fsSpecSkeleton) else {
        SwFatal("LoadSkeletonFile: couldn't read skeleton resource fork")
        return nil
    }

    // ALLOC MEMORY FOR SKELETON INFO STRUCTURE

    let skeleton = AllocPtrClear(MemoryLayout<SkeletonDefType>.size)!.assumingMemoryBound(to: SkeletonDefType.self)

    // READ SKELETON RESOURCES

    readDataFromSkeletonFile(resourceFile, skeleton, &fsSpecBG3D, Int32(skeletonType))
    PrimeBoneData(skeleton)

    return skeleton
}

private func readDataFromSkeletonFile(_ resourceFile: ResourceFile, _ skeleton: UnsafeMutablePointer<SkeletonDefType>, _ fsSpecBG3D: UnsafeMutablePointer<FSSpec>, _ skeletonType: Int32) {
    // READ HEADER RESOURCE

    guard let headerPtr = loadResource(resourceFile, kResHedr, 1000, as: SkeletonFile_Header_Type.self) else {
        SwFatal("ReadDataFromSkeletonFile: Error reading header resource!")
        return
    }
    let version = SwizzleShort(&headerPtr.pointee.version)
    if version != SKELETON_FILE_VERS_NUM {
        SwFatal("Skeleton file has wrong version #")
    }

    let numAnims = Int(SwizzleShort(&headerPtr.pointee.numAnims)) // get # anims in skeleton
    skeleton.pointee.NumAnims = UInt8(numAnims)
    let numJoints = Int(SwizzleShort(&headerPtr.pointee.numJoints)) // get # joints in skeleton
    skeleton.pointee.NumBones = UInt8(numJoints)
    SafeDisposePtr(headerPtr)

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

        guard let bonePtr = loadResource(resourceFile, kResBone, 1000 + Int16(i), as: File_BoneDefinitionType.self) else {
            SwFatal("Error reading Bone resource!")
            return
        }

        // COPY BONE DATA INTO ARRAY

        skeleton.pointee.Bones![i].parentBone = Int(SwizzleLong(&bonePtr.pointee.parentBone)) // index to previous bone
        skeleton.pointee.Bones![i].coord.x = SwizzleFloat(&bonePtr.pointee.coord.x) // absolute coord (not relative to parent!)
        skeleton.pointee.Bones![i].coord.y = SwizzleFloat(&bonePtr.pointee.coord.y)
        skeleton.pointee.Bones![i].coord.z = SwizzleFloat(&bonePtr.pointee.coord.z)
        skeleton.pointee.Bones![i].numPointsAttachedToBone = SwizzleUShort(&bonePtr.pointee.numPointsAttachedToBone) // # vertices/points that this bone has
        skeleton.pointee.Bones![i].numNormalsAttachedToBone = SwizzleUShort(&bonePtr.pointee.numNormalsAttachedToBone) // # vertex normals this bone has
        SafeDisposePtr(bonePtr)

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

        guard let bonPPtr = loadResource(resourceFile, kResBonP, 1000 + Int16(i), as: UInt16.self) else {
            SwFatal("Error reading BonP resource!")
            return
        }

        // COPY POINT INDEX ARRAY INTO BONE STRUCT

        for j in 0..<Int(skeleton.pointee.Bones![i].numPointsAttachedToBone) {
            skeleton.pointee.Bones![i].pointList![j] = SwizzleUShort(bonPPtr + j)
        }
        SafeDisposePtr(bonPPtr)

        // READ NORMAL INDEX ARRAY

        guard let bonNPtr = loadResource(resourceFile, kResBonN, 1000 + Int16(i), as: UInt16.self) else {
            SwFatal("Error reading BonN resource!")
            return
        }

        // COPY NORMAL INDEX ARRAY INTO BONE STRUCT

        for j in 0..<Int(skeleton.pointee.Bones![i].numNormalsAttachedToBone) {
            skeleton.pointee.Bones![i].normalList![j] = SwizzleUShort(bonNPtr + j)
        }
        SafeDisposePtr(bonNPtr)
    }

    // READ POINT RELATIVE OFFSETS
    //
    // The "relative point offsets" are the only things
    // which do not get rebuilt in the ModelDecompose function.
    // We need to restore these manually.

    guard let pointPtr = loadResource(resourceFile, kResRelP, 1000, as: OGLPoint3D.self) else {
        SwFatal("Error reading RelP resource!")
        return
    }

    let numRelPoints = resourceByteCount(resourceFile, kResRelP, 1000) / MemoryLayout<OGLPoint3D>.size
    if numRelPoints != Int(skeleton.pointee.numDecomposedPoints) {
        SwFatal("# of points in Reference Model has changed!")
    } else {
        for i in 0..<Int(skeleton.pointee.numDecomposedPoints) {
            skeleton.pointee.decomposedPointList![i].boneRelPoint.x = SwizzleFloat(&(pointPtr + i).pointee.x)
            skeleton.pointee.decomposedPointList![i].boneRelPoint.y = SwizzleFloat(&(pointPtr + i).pointee.y)
            skeleton.pointee.decomposedPointList![i].boneRelPoint.z = SwizzleFloat(&(pointPtr + i).pointee.z)
        }
    }
    SafeDisposePtr(pointPtr)

    // READ ANIM INFO

    for i in 0..<numAnims {
        // READ ANIM HEADER

        guard let animHeaderPtr = loadResource(resourceFile, kResAnHd, 1000 + Int16(i), as: SkeletonFile_AnimHeader_Type.self) else {
            SwFatal("Error getting anim header resource")
            return
        }

        skeleton.pointee.NumAnimEvents![i] = UInt8(SwizzleShort(&animHeaderPtr.pointee.numAnimEvents)) // copy # anim events in anim
        SafeDisposePtr(animHeaderPtr)

        // READ ANIM-EVENT DATA

        guard let animEventPtr0 = loadResource(resourceFile, kResEvnt, 1000 + Int16(i), as: AnimEventType.self) else {
            SwFatal("Error reading anim-event data resource!")
            return
        }
        var animEventPtr = animEventPtr0
        for j in 0..<Int(skeleton.pointee.NumAnimEvents![i]) {
            skeleton.pointee.AnimEventsList![i]![j] = animEventPtr.pointee // copy whole thing
            skeleton.pointee.AnimEventsList![i]![j].time = SwizzleShort(&skeleton.pointee.AnimEventsList![i]![j].time) // then swizzle the 16-bit short value
            animEventPtr += 1
        }
        SafeDisposePtr(animEventPtr0)

        // READ # KEYFRAMES PER JOINT IN EACH ANIM

        guard let numKPtr = loadResource(resourceFile, kResNumK, 1000 + Int16(i), as: Int8.self) else { // read array of #'s for this anim
            SwFatal("Error reading # keyframes/joint resource!")
            return
        }
        for j in 0..<numJoints {
            numKeyFramesBase(jointKeyframesBase(skeleton) + j)[i] = (numKPtr + j).pointee
        }
        SafeDisposePtr(numKPtr)
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

            guard let keyFramePtr0 = loadResource(resourceFile, kResKeyF, 1000 + Int16(i * 100 + j), as: JointKeyframeType.self) else {
                SwFatal("Error reading joint keyframes resource!")
                return
            }
            var keyFramePtr = keyFramePtr0
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
            SafeDisposePtr(keyFramePtr0)
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

func SavePrefs() -> OSErr {
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
    gEngine.terrain.disableHiccupTimer = 1

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

    guard let resourceFile = loadResourceFork(sibling: specPtr) else {
        SwFatal("LoadPlayfield: couldn't read playfield resource fork.  You seem to have a corrupt or missing file.  Please reinstall the game.")
        return
    }

    // READ HEADER RESOURCE

    guard let header = loadResource(resourceFile, kResHedr, 1000, as: PlayfieldHeaderType.self) else {
        SwAlert("ReadDataFromPlayfieldFile: Error reading header resource!")
        return
    }

    gEngine.terrain.numTerrainItems = SwizzleLong(&header.pointee.numItems)
    gEngine.terrain.tileWidth = Int(SwizzleLong(&header.pointee.mapWidth))
    gEngine.terrain.tileDepth = Int(SwizzleLong(&header.pointee.mapHeight))
    g3DTileSize = SwizzleFloat(&header.pointee.tileSize)
    g3DMinY = SwizzleFloat(&header.pointee.minY)
    g3DMaxY = SwizzleFloat(&header.pointee.maxY)
    gEngine.splines.numSplines = Int(SwizzleLong(&header.pointee.numSplines))
    gEngine.fences.numFences = Int(SwizzleLong(&header.pointee.numFences))
    gEngine.water.numPatches = Int(SwizzleLong(&header.pointee.numWaterPatches))
    gEngine.terrain.numUniqueSuperTiles = Int(SwizzleLong(&header.pointee.numUniqueSuperTiles))
    gEngine.terrain.numLineMarkers = SwizzleLong(&header.pointee.numCheckpoints)

    SafeDisposePtr(header)

    if gEngine.terrain.tileWidth % Int(SUPERTILE_SIZE) != 0 { // terrain must be non-fractional number of supertiles in w/h
        SwFatal("ReadDataFromPlayfieldFile: terrain width not a supertile multiple")
    }
    if gEngine.terrain.tileDepth % Int(SUPERTILE_SIZE) != 0 {
        SwFatal("ReadDataFromPlayfieldFile: terrain depth not a supertile multiple")
    }

    // CALC SOME GLOBALS HERE

    gEngine.terrain.tileWidth = (gEngine.terrain.tileWidth / Int(SUPERTILE_SIZE)) * Int(SUPERTILE_SIZE) // round size down to nearest supertile multiple
    gEngine.terrain.tileDepth = (gEngine.terrain.tileDepth / Int(SUPERTILE_SIZE)) * Int(SUPERTILE_SIZE)
    gEngine.terrain.unitWidth = Int(Float(gEngine.terrain.tileWidth) * gEngine.terrain.polygonSize) // calc world unit dimensions of terrain
    gEngine.terrain.unitDepth = Int(Float(gEngine.terrain.tileDepth) * gEngine.terrain.polygonSize)
    gEngine.terrain.numSuperTilesDeep = gEngine.terrain.tileDepth / Int(SUPERTILE_SIZE) // calc size in supertiles
    gEngine.terrain.numSuperTilesWide = gEngine.terrain.tileWidth / Int(SUPERTILE_SIZE)

    // SUPERTILE RELATED RESOURCES

    // READ SUPERTILE GRID MATRIX

    if gEngine.terrain.superTileTextureGrid != nil { // free old array
        free2DArray(gEngine.terrain.superTileTextureGrid)
    }
    gEngine.terrain.superTileTextureGrid = alloc2DArray(Int16.self, rows: Int(gEngine.terrain.numSuperTilesDeep), cols: Int(gEngine.terrain.numSuperTilesWide))

    if let handSTgd = loadResource(resourceFile, kResSTgd, 1000, as: Int16.self) { // load grid from rez
        var src = handSTgd

        for row in 0..<Int(gEngine.terrain.numSuperTilesDeep) {
            for col in 0..<Int(gEngine.terrain.numSuperTilesWide) {
                let stId = SwizzleShort(src)
                src += 1
                gEngine.terrain.superTileTextureGrid[row]![col] = stId
            }
        }

        SafeDisposePtr(handSTgd)
    } else {
        SwFatal("ReadDataFromPlayfieldFile: Error reading supertile rez resource!")
    }

    // READ HEIGHT DATA MATRIX

    let yScale = gEngine.terrain.polygonSize / g3DTileSize // need to scale original geometry units to game units

    gEngine.terrain.mapYCoords = alloc2DArray(Float.self, rows: Int(gEngine.terrain.tileDepth) + 1, cols: Int(gEngine.terrain.tileWidth) + 1) // alloc 2D array for map
    gEngine.terrain.mapYCoordsOriginal = alloc2DArray(Float.self, rows: Int(gEngine.terrain.tileDepth) + 1, cols: Int(gEngine.terrain.tileWidth) + 1) // and the copy of it

    if let handYCrd = loadResource(resourceFile, kResYCrd, 1000, as: Float.self) {
        var src = handYCrd
        for row in 0...Int(gEngine.terrain.tileDepth) {
            for col in 0...Int(gEngine.terrain.tileWidth) {
                let v = SwizzleFloat(src) * yScale
                src += 1
                gEngine.terrain.mapYCoordsOriginal[row]![col] = v
                gEngine.terrain.mapYCoords[row]![col] = v
            }
        }
        SafeDisposePtr(handYCrd)
    } else {
        SwAlert("ReadDataFromPlayfieldFile: Error reading height data resource!")
    }

    // ITEM RELATED RESOURCES

    // READ ITEM LIST

    guard let rezItems = loadResource(resourceFile, kResItms, 1000, as: File_TerrainItemEntryType.self) else {
        SwFatal("ReadDataFromPlayfieldFile: Error reading itemlist resource!")
        return
    }
    do {
        // COPY INTO OUR STRUCT

        gEngine.terrain.masterItemList = AllocPtrClear(MemoryLayout<TerrainItemEntryType>.size * Int(gEngine.terrain.numTerrainItems))?.assumingMemoryBound(to: TerrainItemEntryType.self) // alloc array of items

        for i in 0..<Int(gEngine.terrain.numTerrainItems) {
            gEngine.terrain.masterItemList[i].x = UInt32(Float(SwizzleULong(&rezItems[i].x)) * gEngine.terrain.mapToUnitValue) // convert coordinates
            gEngine.terrain.masterItemList[i].y = UInt32(Float(SwizzleULong(&rezItems[i].y)) * gEngine.terrain.mapToUnitValue)

            gEngine.terrain.masterItemList[i].type = SwizzleUShort(&rezItems[i].type)
            gEngine.terrain.masterItemList[i].parm.0 = rezItems[i].parm.0
            gEngine.terrain.masterItemList[i].parm.1 = rezItems[i].parm.1
            gEngine.terrain.masterItemList[i].parm.2 = rezItems[i].parm.2
            gEngine.terrain.masterItemList[i].parm.3 = rezItems[i].parm.3
            gEngine.terrain.masterItemList[i].flags = SwizzleUShort(&rezItems[i].flags)
        }

        SafeDisposePtr(rezItems) // nuke the rez
    }

    // SPLINE RELATED RESOURCES

    // READ SPLINE LIST

    if let splinePtr = loadResource(resourceFile, kResSpln, 1000, as: File_SplineDefType.self) {
        gEngine.splines.splineList = AllocPtrClear(MemoryLayout<SplineDefType>.size * gEngine.splines.numSplines)?.assumingMemoryBound(to: SplineDefType.self) // allocate memory for spline data

        for i in 0..<gEngine.splines.numSplines {
            gEngine.splines.splineList[i].numNubs = SwizzleShort(&splinePtr[i].numNubs)
            gEngine.splines.splineList[i].numPoints = SwizzleLong(&splinePtr[i].numPoints)
            gEngine.splines.splineList[i].numItems = SwizzleShort(&splinePtr[i].numItems)

            gEngine.splines.splineList[i].bBox.top = SwizzleShort(&splinePtr[i].bBox.top)
            gEngine.splines.splineList[i].bBox.bottom = SwizzleShort(&splinePtr[i].bBox.bottom)
            gEngine.splines.splineList[i].bBox.left = SwizzleShort(&splinePtr[i].bBox.left)
            gEngine.splines.splineList[i].bBox.right = SwizzleShort(&splinePtr[i].bBox.right)
        }

        SafeDisposePtr(splinePtr) // nuke the rez
    } else {
        gEngine.splines.numSplines = 0
        gEngine.splines.splineList = nil
    }

    // READ SPLINE POINT LIST

    for i in 0..<gEngine.splines.numSplines {
        let spline = gEngine.splines.splineList + i // point to Nth spline

        if let ptList = loadResource(resourceFile, kResSpPt, 1000 + Int16(i), as: SplinePointType.self) { // read this point list
            spline.pointee.pointList = AllocPtrClear(MemoryLayout<SplinePointType>.size * Int(spline.pointee.numPoints))?.assumingMemoryBound(to: SplinePointType.self) // alloc memory for point list

            for j in 0..<Int(spline.pointee.numPoints) { // swizzle
                spline.pointee.pointList[j].x = SwizzleFloat(&ptList[j].x)
                spline.pointee.pointList[j].z = SwizzleFloat(&ptList[j].z)
            }
            SafeDisposePtr(ptList) // nuke the rez
        } else {
            SwFatal("ReadDataFromPlayfieldFile: cant get spline points rez")
        }
    }

    // READ SPLINE ITEM LIST

    for i in 0..<gEngine.splines.numSplines {
        let spline = gEngine.splines.splineList + i // point to Nth spline

        if let itemList = loadResource(resourceFile, kResSpIt, 1000 + Int16(i), as: SplineItemType.self) {
            SwGameAssert(resourceByteCount(resourceFile, kResSpIt, 1000 + Int16(i)) == Int(MemoryLayout<SplineItemType>.size) * Int(spline.pointee.numItems))

            spline.pointee.itemList = AllocPtrClear(MemoryLayout<SplineItemType>.size * Int(spline.pointee.numItems))?.assumingMemoryBound(to: SplineItemType.self) // alloc memory for item list

            for j in 0..<Int(spline.pointee.numItems) { // swizzle
                spline.pointee.itemList[j].parm = itemList[j].parm

                spline.pointee.itemList[j].placement = SwizzleFloat(&itemList[j].placement)
                spline.pointee.itemList[j].type = SwizzleUShort(&itemList[j].type)
                spline.pointee.itemList[j].flags = SwizzleUShort(&itemList[j].flags)
            }
            SafeDisposePtr(itemList) // nuke the rez
        } else {
            SwFatal("ReadDataFromPlayfieldFile: cant get spline items rez")
        }
    }

    // FENCE RELATED RESOURCES

    // READ FENCE LIST

    if let inData = loadResource(resourceFile, kResFenc, 1000, as: FileFenceDefType.self) {
        gEngine.fences.fenceList = AllocPtrClear(MemoryLayout<FenceDefType>.size * Int(gEngine.fences.numFences))?.assumingMemoryBound(to: FenceDefType.self) // alloc new ptr for fence data
        if gEngine.fences.fenceList == nil {
            SwFatal("ReadDataFromPlayfieldFile: AllocPtr failed")
        }

        for i in 0..<Int(gEngine.fences.numFences) { // copy data from rez to new list
            gEngine.fences.fenceList[i].type = SwizzleUShort(&inData[i].type)
            gEngine.fences.fenceList[i].numNubs = SwizzleShort(&inData[i].numNubs)
            gEngine.fences.fenceList[i].nubList = nil
            gEngine.fences.fenceList[i].sectionVectors = nil
        }
        SafeDisposePtr(inData)
    } else {
        gEngine.fences.numFences = 0
    }

    // READ FENCE NUB LIST

    for i in 0..<Int(gEngine.fences.numFences) {
        guard let fileFencePoints = loadResource(resourceFile, kResFnNb, 1000 + Int16(i), as: FencePointType.self) else { // get rez
            SwFatal("ReadDataFromPlayfieldFile: cant get fence nub rez")
            return
        }

        gEngine.fences.fenceList[i].nubList = AllocPtrClear(MemoryLayout<FenceDefType>.size * Int(gEngine.fences.fenceList[i].numNubs))?.assumingMemoryBound(to: OGLPoint3D.self) // alloc new ptr for nub array
        if gEngine.fences.fenceList[i].nubList == nil {
            SwFatal("ReadDataFromPlayfieldFile: AllocPtr failed")
        }

        for j in 0..<Int(gEngine.fences.fenceList[i].numNubs) { // convert x,z to x,y,z
            gEngine.fences.fenceList[i].nubList[j].x = Float(SwizzleLong(&fileFencePoints[j].x))
            gEngine.fences.fenceList[i].nubList[j].z = Float(SwizzleLong(&fileFencePoints[j].z))
            gEngine.fences.fenceList[i].nubList[j].y = 0
        }
        SafeDisposePtr(fileFencePoints)
    }

    // WATER RELATED RESOURCES

    // READ WATER LIST
    //
    // gEngine.water.listHandle keeps this resource's data alive for the whole
    // level's lifetime (not just this function), so instead of the
    // temporary loadResource()/SafeDisposePtr() pair used elsewhere in this
    // function, it gets its own permanent AllocPtrClear'd handle-shaped
    // allocation (double indirection, matching gEngine.water.listHandle's type) -
    // disposed later via DisposeWaterListHandle (WaterInternal.h), which
    // now calls SafeDisposePtr twice instead of Pomme's DisposeHandle.

    if let waterData = loadResource(resourceFile, kResLiqd, 1000, as: WaterDefType.self) {
        let handlePtr = AllocPtrClear(MemoryLayout<UnsafeMutablePointer<WaterDefType>?>.size)!.assumingMemoryBound(to: UnsafeMutablePointer<WaterDefType>?.self)
        handlePtr.pointee = waterData
        gEngine.water.listHandle = handlePtr
        gEngine.water.list = waterData

        for i in 0..<Int(gEngine.water.numPatches) { // swizzle
            gEngine.water.list[i].type = SwizzleUShort(&gEngine.water.list[i].type)
            gEngine.water.list[i].flags = SwizzleULong(&gEngine.water.list[i].flags)
            gEngine.water.list[i].height = SwizzleLong(&gEngine.water.list[i].height)
            gEngine.water.list[i].numNubs = SwizzleShort(&gEngine.water.list[i].numNubs)

            gEngine.water.list[i].hotSpotX = SwizzleFloat(&gEngine.water.list[i].hotSpotX)
            gEngine.water.list[i].hotSpotZ = SwizzleFloat(&gEngine.water.list[i].hotSpotZ)

            gEngine.water.list[i].bBox.top = SwizzleShort(&gEngine.water.list[i].bBox.top)
            gEngine.water.list[i].bBox.bottom = SwizzleShort(&gEngine.water.list[i].bBox.bottom)
            gEngine.water.list[i].bBox.left = SwizzleShort(&gEngine.water.list[i].bBox.left)
            gEngine.water.list[i].bBox.right = SwizzleShort(&gEngine.water.list[i].bBox.right)

            let nubs = waterNubListBase(gEngine.water.list + i)
            for j in 0..<Int(gEngine.water.list[i].numNubs) {
                nubs[j].x = SwizzleFloat(&nubs[j].x)
                nubs[j].y = SwizzleFloat(&nubs[j].y)
            }
        }
    } else {
        gEngine.water.numPatches = 0
    }

    // LINE MARKER RESOURCES

    if gEngine.terrain.numLineMarkers > 0 {
        if gEngine.terrain.numLineMarkers > Int32(MAX_LINEMARKERS) {
            SwFatal("ReadDataFromPlayfieldFile: gEngine.terrain.numLineMarkers > MAX_LINEMARKERS")
        }

        // READ CHECKPOINT LIST

        if let handCkPt = loadResource(resourceFile, kResCkPt, 1000, as: Int8.self) {
            SwBlockMove(handCkPt, GetLineMarkerPtr(0), resourceByteCount(resourceFile, kResCkPt, 1000))
            SafeDisposePtr(handCkPt)

            // CONVERT COORDINATES

            for i in 0..<Int(gEngine.terrain.numLineMarkers) {
                let lm = GetLineMarkerPtr(Int32(i))

                lm.pointee.infoBits = SwizzleShort(&lm.pointee.infoBits) // swizzle data
                let lmX = lineMarkerXBase(lm)
                let lmZ = lineMarkerZBase(lm)
                lmX[0] = SwizzleFloat(lmX)
                lmX[1] = SwizzleFloat(lmX + 1)
                lmZ[0] = SwizzleFloat(lmZ)
                lmZ[1] = SwizzleFloat(lmZ + 1)

                lmX[0] *= gEngine.terrain.mapToUnitValue
                lmZ[0] *= gEngine.terrain.mapToUnitValue
                lmX[1] *= gEngine.terrain.mapToUnitValue
                lmZ[1] *= gEngine.terrain.mapToUnitValue
            }
        } else {
            gEngine.terrain.numLineMarkers = 0
        }
    }

    // READ SUPERTILE IMAGE DATA FROM DATA FORK

    // OPEN THE DATA FORK

    var dataForkRefNum: Int16 = 0
    if SwFSpOpenDF(specPtr, Int8(fsRdPerm.rawValue), &dataForkRefNum) != kNoErr {
        SwFatal("ReadDataFromPlayfieldFile: FSpOpenDF failed!")
    }

    // HQ_TERRAIN is enabled for this build (see game.h) - assemble seamless textures.

    SwGameAssertMessage(gEngine.terrain.superTilePixelBuffers == nil, "gEngine.terrain.superTilePixelBuffers already allocated!")
    gEngine.terrain.superTilePixelBuffers = AllocPtrClear(MemoryLayout<Ptr?>.size * Int(gEngine.terrain.numUniqueSuperTiles))?.assumingMemoryBound(to: Ptr?.self)

    let seamlessTextureCanvas = AllocPtrClear(4 * (Int(SUPERTILE_TEXMAP_SIZE) + 2) * (Int(SUPERTILE_TEXMAP_SIZE) + 2))!.assumingMemoryBound(to: Int8.self)

    for row in 0..<(Int(gEngine.terrain.numSuperTilesDeep) + 4) { // go 4 rows beyond terrain height so all 3 passes can run to completion
        // We could do the three passes below separately, but weaving them in a single for loop
        // lets us keep memory pressure low while assembling the seamless textures.

        let rowPass1 = row // 1st pass: load JPEG images
        let rowPass2 = row - 2 // 2nd pass: assemble seamless textures (2 rows behind, b/c need data from 1 row below + 1 column across)
        let rowPass3 = row - 4 // 3rd pass: free up memory (4 rows behind)

        for col in 0..<Int(gEngine.terrain.numSuperTilesWide) {
            // 1st pass: load JPEG textures
            if 0 <= rowPass1 && rowPass1 < Int(gEngine.terrain.numSuperTilesDeep) {
                let stId = gEngine.terrain.superTileTextureGrid[rowPass1]![col]
                if stId >= 0 {
                    gEngine.terrain.superTilePixelBuffers[Int(stId)] = LoadSuperTilePixelBuffer(dataForkRefNum)

                    // Update loading screen here
                    DrawLoading(Float(stId) / Float(gEngine.terrain.numUniqueSuperTiles))
                }
            }

            // 2nd pass: assemble seamless textures
            if 0 <= rowPass2 && rowPass2 < Int(gEngine.terrain.numSuperTilesDeep) {
                let stId = gEngine.terrain.superTileTextureGrid[rowPass2]![col]
                if stId >= 0 {
                    AssembleSeamlessSuperTileTexture(Int32(rowPass2), Int32(col), seamlessTextureCanvas)
                    GetSuperTileTextureObjectSlot(Int32(stId))!.pointee = LoadSuperTileTexture(seamlessTextureCanvas, 2 + Int32(SUPERTILE_TEXMAP_SIZE))
                }
            }

            // 3rd pass: free up pixel buffers from rows that we won't need to look at again
            if 0 <= rowPass3 && rowPass3 < Int(gEngine.terrain.numSuperTilesDeep) {
                let stId = gEngine.terrain.superTileTextureGrid[rowPass3]![col]
                if stId >= 0 {
                    SafeDisposePtr(gEngine.terrain.superTilePixelBuffers[Int(stId)])
                    gEngine.terrain.superTilePixelBuffers[Int(stId)] = nil
                }
            }
        }
    }

    SafeDisposePtr(seamlessTextureCanvas)

    // Check that we have all the textures we need and that we freed all temporary images
    for i in 0..<Int(gEngine.terrain.numUniqueSuperTiles) {
        SwGameAssertMessage(GetSuperTileTextureObjectSlot(Int32(i))!.pointee != nil, "2nd pass incomplete: not all textures were loaded")
        SwGameAssertMessage(gEngine.terrain.superTilePixelBuffers[i] == nil, "3rd pass incomplete: not all buffers were freed")
    }

    SafeDisposePtr(gEngine.terrain.superTilePixelBuffers)
    gEngine.terrain.superTilePixelBuffers = nil

    DrawLoading(1.0)

    // CLOSE THE FILE

    SwFSClose(dataForkRefNum)
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
            SwFSRead(fRefNum, &readSize, $0)
        }
    }
    SwGameAssert(iErr1 == 0)

    dataSize = SwizzleLong(&dataSize)

    // ALLOCATE JPEG BUFFER

    let jpegBuffer = AllocPtrClear(Int(dataSize))!.assumingMemoryBound(to: Int8.self)

    // READ THE IMAGE DESC DATA + THE COMPRESSED IMAGE DATA

    size = dataSize
    readSize = Int(size)
    let iErr2 = SwFSRead(fRefNum, &readSize, jpegBuffer)
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
    if row < 0 || row > Int(gEngine.terrain.numSuperTilesDeep) - 1 // row out of bounds
        || col < 0 || col > Int(gEngine.terrain.numSuperTilesWide) - 1 { // column out of bounds
        return nil
    }

    let superTileId = gEngine.terrain.superTileTextureGrid[row]![col]

    if superTileId < 0 { // blank texture
        return nil
    }

    let image = gEngine.terrain.superTilePixelBuffers[Int(superTileId)]
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
    saveData.numLives = UInt8(GetPlayerInfoEntry(0).pointee.numFreeLives)
    saveData.health = GetPlayerInfoEntry(0).pointee.health
    saveData.jetpackFuel = GetPlayerInfoEntry(0).pointee.jetpackFuel
    saveData.shieldPower = GetPlayerInfoEntry(0).pointee.shieldPower

    for (i, _) in WeaponType.allCases.enumerated() {
        weaponQuantityBase(&saveData)[i] = UInt16(bitPattern: playerWeaponQuantityBase(GetPlayerInfoEntry(0))[i])
    }

    // SAVE IT TO DISK

    return withUnsafeMutablePointer(to: &saveData) { dataPtr in
        dataPtr.withMemoryRebound(to: Int8.self, capacity: MemoryLayout<SaveGameType>.size) { rawPtr in
            kNoErr == SaveUserDataFile(path, SAVEGAME_MAGIC, MemoryLayout<SaveGameType>.size, rawPtr) ? 1 : 0
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

    let ok: Bool = withUnsafeMutablePointer(to: &scratch) { scratchPtr in
        scratchPtr.withMemoryRebound(to: Int8.self, capacity: MemoryLayout<SaveGameType>.size) { rawPtr in
            kNoErr == LoadUserDataFile(path, SAVEGAME_MAGIC, MemoryLayout<SaveGameType>.size, rawPtr)
        }
    }

    if !ok {
        return 0
    }

    outData.pointee = scratch
    return 1
}

func DeleteSavedGame(_ fileSlot: Int32) -> UInt8 {
    let path = "File\(Character(UnicodeScalar(UInt8(65 + fileSlot))))"

    let iErr = DeleteUserDataFile(path)

    return iErr == kNoErr ? 1 : 0
}

func UseSaveGame(_ saveData: UnsafePointer<SaveGameType>!) {
    gLevelNum = Int16(saveData.pointee.level)
    GetPlayerInfoEntry(0).pointee.numFreeLives = Int16(saveData.pointee.numLives)
    GetPlayerInfoEntry(0).pointee.health = saveData.pointee.health
    GetPlayerInfoEntry(0).pointee.jetpackFuel = saveData.pointee.jetpackFuel
    GetPlayerInfoEntry(0).pointee.shieldPower = saveData.pointee.shieldPower

    let saveWeapons = UnsafeMutablePointer(mutating: saveData).map { weaponQuantityBase($0) }!
    let playerWeapons = playerWeaponQuantityBase(GetPlayerInfoEntry(0))
    for (i, _) in WeaponType.allCases.enumerated() {
        playerWeapons[i] = Int16(bitPattern: saveWeapons[i])
    }
}

// MARK: - User Data Files

func InitPrefsFolder(_ createIt: UInt8) -> OSErr {
    var createdDirID: Int = 0

    let iErr = SwFindFolder(Int16(kOnSystemDisk), OSType(kPreferencesFolderType), 0, &gPrefsFolderVRefNum, &gPrefsFolderDirID) // locate the folder
    if iErr != kNoErr {
        SwAlert("Warning: Cannot locate the Preferences folder.")
    }

    if createIt != 0 {
        return SwDirCreate(gPrefsFolderVRefNum, gPrefsFolderDirID, PREFS_FOLDER_NAME, &createdDirID) // make folder in there
    }

    return iErr
}

private func makeFSSpecForUserDataFile(_ filename: String, _ spec: UnsafeMutablePointer<FSSpec>) -> OSErr {
    let path = ":\(PREFS_FOLDER_NAME_SWIFT):\(filename)"
    return SwFSMakeFSSpec(gPrefsFolderVRefNum, gPrefsFolderDirID, path, spec)
}

private let PREFS_FOLDER_NAME_SWIFT = "Nanosaur2"

// Load struct from user file in prefs folder
func LoadUserDataFile(_ filename: String, _ magic: String, _ payloadLength: Int, _ payloadPtr: Ptr!) -> OSErr {
    var file = FSSpec()
    let magicBytes = Array(magic.utf8CString)
    let magicLength = magicBytes.count // including null-terminator
    var fileMagic = [Int8](repeating: 0, count: 64)

    SwGameAssert(magicLength < 64)

    // INIT PREFS FOLDER FSSPEC FIRST

    _ = InitPrefsFolder(0)

    // READ FILE

    _ = makeFSSpecForUserDataFile(filename, &file)
    var refNum: Int16 = 0
    var iErr = SwFSpOpenDF(&file, Int8(fsRdPerm.rawValue), &refNum)
    if iErr != kNoErr {
        return iErr
    }

    // CHECK FILE LENGTH

    var eof: Int = 0
    SwGetEOF(refNum, &eof)

    if eof != magicLength + payloadLength {
        SwLog("File '\(filename)' appears to be corrupt!")
        SwFSClose(refNum)
        return kBadFileFormat
    }

    // READ HEADER

    var count = magicLength
    iErr = fileMagic.withUnsafeMutableBufferPointer { SwFSRead(refNum, &count, $0.baseAddress) }
    if iErr != kNoErr || count != magicLength || !fileMagic.prefix(magicLength - 1).elementsEqual(magicBytes.prefix(magicLength - 1)) {
        SwLog("File '\(filename)' appears to be corrupt!")
        SwFSClose(refNum)
        return kBadFileFormat
    }

    // READ PAYLOAD

    let payloadCopy = AllocPtrClear(payloadLength)!.assumingMemoryBound(to: Int8.self)

    count = payloadLength
    iErr = SwFSRead(refNum, &count, payloadCopy)
    if iErr != kNoErr || count != payloadLength {
        SwLog("File '\(filename)' appears to be corrupt!")
        SafeDisposePtr(payloadCopy)
        SwFSClose(refNum)
        return kBadFileFormat
    }

    // COMMIT PAYLOAD AND FINISH

    SwBlockMove(payloadCopy, payloadPtr, payloadLength)

    SafeDisposePtr(payloadCopy)
    SwFSClose(refNum)
    return kNoErr
}

// Save struct to user file in prefs folder
func SaveUserDataFile(_ filename: String, _ magic: String, _ payloadLength: Int, _ payloadPtr: Ptr!) -> OSErr {
    var file = FSSpec()

    _ = InitPrefsFolder(1)

    // CREATE BLANK FILE

    _ = makeFSSpecForUserDataFile(filename, &file)
    SwFSpDelete(&file) // delete any existing file
    var iErr = SwFSpCreate(&file, kGameIDFourCC, kPrefFourCC, -1) // smSystemScript
    if iErr != kNoErr {
        return iErr
    }

    // OPEN FILE

    var refNum: Int16 = 0
    iErr = SwFSpOpenDF(&file, Int8(fsRdWrPerm.rawValue), &refNum)
    if iErr != kNoErr {
        SwFSpDelete(&file)
        return iErr
    }

    // WRITE MAGIC

    var magicBytes = Array(magic.utf8CString) // including null-terminator
    var count = magicBytes.count
    iErr = magicBytes.withUnsafeMutableBufferPointer { SwFSWrite(refNum, &count, $0.baseAddress) }
    if iErr != kNoErr {
        SwFSClose(refNum)
        return iErr
    }

    // WRITE DATA

    count = payloadLength
    iErr = SwFSWrite(refNum, &count, payloadPtr)
    SwFSClose(refNum)

    SwLog("Wrote \(filename)")

    return iErr
}

func DeleteUserDataFile(_ filename: String) -> OSErr {
    var file = FSSpec()

    _ = InitPrefsFolder(1)
    var iErr = makeFSSpecForUserDataFile(filename, &file)
    if iErr == kNoErr {
        iErr = SwFSpDelete(&file)
    }
    return iErr
}

// Use SafeDisposePtr when done.
func LoadDataFile(_ path: String, _ outLength: UnsafeMutablePointer<Int>!) -> Ptr! {
    var spec = FSSpec()

    let err = SwFSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, path, &spec)
    if err != kNoErr {
        return nil
    }

    var refNum: Int16 = 0
    let openErr = SwFSpOpenDF(&spec, Int8(fsRdPerm.rawValue), &refNum)
    SwGameAssertMessage(openErr == 0, path)

    // Get number of bytes until EOF
    var fileLength = 0
    SwGetEOF(refNum, &fileLength)

    // Prep data buffer
    // Alloc 1 extra byte so LoadTextFile can return a null-terminated C string!
    let data = AllocPtrClear(fileLength + 1)!.assumingMemoryBound(to: Int8.self)

    // Read file into data buffer
    var readBytes = fileLength
    let readErr = SwFSRead(refNum, &readBytes, data)
    SwGameAssertMessage(readErr == kNoErr, path)
    SwFSClose(refNum)

    SwGameAssertMessage(fileLength == readBytes, path)

    if let outLength {
        outLength.pointee = fileLength
    }

    return data
}

// Use SafeDisposePtr when done.
func LoadTextFile(_ spec: String, _ outLength: UnsafeMutablePointer<Int>!) -> UnsafeMutablePointer<CChar>! {
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
