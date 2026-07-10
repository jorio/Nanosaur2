// Water.swift - Port of Water.c to Swift
//
// gEngine.water.numPatches, gEngine.water.numDrawn, gEngine.water.listHandle, gEngine.water.list,
// gWaterTriMeshData[], and gWaterBBox[] are native Swift storage now
// (converted 2026-07-07): nothing in any .c file touches them anymore -
// the old comment claiming Pick.c/OGL_Support.c/Terrain.c/Player_Terrain.c
// still needed them was stale. gWaterTriMeshData/gWaterBBox were fixed-size
// C arrays exposed via GetWaterTriMeshDataEntry (WaterInternal.h) and
// GetWaterBBoxEntry (EnemyInternal.h); both are now permanent, never-freed
// UnsafeMutablePointer buffers (same idiom as Terrain.swift's
// GetSuperTileMemoryEntry etc.), with the accessor functions reimplemented
// in plain Swift under the same names/signatures so their call sites in
// Pick.swift/Player_Terrain.swift/Enemy.swift didn't need to change.
// Everything else (gEngine.water.initY, gWaterVertexArrays, gEngine.water.uvs, the ripple
// list, and the lookup tables) was `static` (file-private) in C, so it
// stays private Swift state.
//
// VERTEXARRAYRANGES is hardcoded to 0 in game.h, so the
// `#if VERTEXARRAYRANGES` / AssignVertexArrayRangeMemory block in the
// original PrimeTerrainWater was dead code - it's omitted here, and the
// water vertex data (points/triangles/uvs) is just kept in flat allocated
// buffers instead of replicating the exact WaterVertexArraysType layout.

private let MAX_WATER = 60
private let MAX_NUBS_IN_WATER = 80
private let MAX_RIPPLES = 100

@inline(__always) private func waterIdx(_ f: Int, _ i: Int) -> Int {
    f * (MAX_NUBS_IN_WATER * 2) + i
}

/// Water/ripple state. Owned by GameEngine as `gEngine.water`.
final class WaterSystem {
    var numPatches: Int = 0
    var numDrawn: Int16 = 0
    var listHandle: UnsafeMutablePointer<UnsafeMutablePointer<WaterDefType>?>!
    var list: UnsafeMutablePointer<WaterDefType>!

    fileprivate let triMeshDataBuf: UnsafeMutablePointer<MOVertexArrayData> = {
        let buf = UnsafeMutablePointer<MOVertexArrayData>.allocate(capacity: 60)
        buf.initialize(repeating: MOVertexArrayData(), count: 60)
        return buf
    }()

    fileprivate let bboxBuf: UnsafeMutablePointer<OGLBoundingBox> = {
        let buf = UnsafeMutablePointer<OGLBoundingBox>.allocate(capacity: 60)
        buf.initialize(repeating: OGLBoundingBox(), count: 60)
        return buf
    }()

    // Water vertex data (flat buffers, [MAX_WATER][MAX_NUBS_IN_WATER*2])
    fileprivate let pointsBuf = AllocPtrClear(MemoryLayout<OGLPoint3D>.size * MAX_WATER * MAX_NUBS_IN_WATER * 2)!.assumingMemoryBound(to: OGLPoint3D.self)
    fileprivate let trianglesBuf = AllocPtrClear(MemoryLayout<MOTriangleIndecies>.size * MAX_WATER * MAX_NUBS_IN_WATER * 2)!.assumingMemoryBound(to: MOTriangleIndecies.self)
    fileprivate let uvs1Buf = AllocPtrClear(MemoryLayout<OGLTextureCoord>.size * MAX_WATER * MAX_NUBS_IN_WATER * 2)!.assumingMemoryBound(to: OGLTextureCoord.self)
    fileprivate let uvs2Buf = AllocPtrClear(MemoryLayout<OGLTextureCoord>.size * MAX_WATER * MAX_NUBS_IN_WATER * 2)!.assumingMemoryBound(to: OGLTextureCoord.self)

    fileprivate var initY = [Float](repeating: 0, count: MAX_WATER)

    // UV'S FOR WATER TYPES ([2] is for the two layers we can have)
    fileprivate var uvs: [[OGLTextureCoord]] = Array(repeating: Array(repeating: OGLTextureCoord(), count: 2), count: WaterType.allCases.count)

    // RIPPLES
    fileprivate var numRipples = 0
    fileprivate var rippleEventObj: UnsafeMutablePointer<ObjNode>?
    fileprivate var rippleList: InlineArray<100, RippleRecord> = InlineArray(repeating: RippleRecord())
}

func GetWaterTriMeshDataEntry(_ i: Int32) -> UnsafeMutablePointer<MOVertexArrayData> {
    gEngine.water.triMeshDataBuf + Int(i)
}

func GetWaterBBoxEntry(_ i: Int32) -> UnsafeMutablePointer<OGLBoundingBox>! {
    gEngine.water.bboxBuf + Int(i)
}

private struct RippleRecord {
    var isUsed = false
    var coord = OGLPoint3D()
    var alpha: Float = 0
    var fadeRate: Float = 0
    var scale: Float = 0
    var scaleSpeed: Float = 0
}

// MARK: - Tables

private let gWaterTextureType: [Int] = [
    GLOBAL_SObjType_GreenWater, // green water
    GLOBAL_SObjType_BlueWater, // blue water
    GLOBAL_SObjType_LavaWater, // lava water
    GLOBAL_SObjType_LavaWater, // lava water 0
    GLOBAL_SObjType_LavaWater, // lava water 1
    GLOBAL_SObjType_LavaWater, // lava water 2
    GLOBAL_SObjType_LavaWater, // lava water 3
    GLOBAL_SObjType_LavaWater, // lava water 4
    GLOBAL_SObjType_LavaWater, // lava water 5
    GLOBAL_SObjType_LavaWater, // lava water 6
    GLOBAL_SObjType_LavaWater, // lava water 7
]

private let gWaterTransparency: [Float] = [
    0.8, // green water
    0.6, // blue water
    1.0, // lava water
    1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, // lava water 0-7
]

private let gWaterGlow: [Bool] = Array(repeating: false, count: WaterType.allCases.count)

private let gWaterFixedYCoord: [Float] = [
    400.0, // #0 swimming pool
]

// MARK: - fixed-array-field helpers (all struct fields, never unions)

@inline(__always) private func nubListBase(_ w: UnsafeMutablePointer<WaterDefType>) -> UnsafeMutablePointer<OGLPoint2D> {
    UnsafeMutableRawPointer(w.pointer(to: \.nubList)!).assumingMemoryBound(to: OGLPoint2D.self)
}

// MARK: - Dispose water

func DisposeWater() {
    guard let handle = gEngine.water.listHandle else {
        return
    }

    DisposeWaterListHandle(handle)
    gEngine.water.listHandle = nil
    gEngine.water.list = nil
    gEngine.water.numPatches = 0
}

// MARK: - Prime water
//
// Called during terrain prime function to initialize

func PrimeTerrainWater() {
    initRipples()

    if gEngine.water.numPatches > MAX_WATER {
        SwFatal("PrimeTerrainWater: gEngine.water.numPatches > MAX_WATER")
    }

    // INIT UVS
    for (i, _) in WaterType.allCases.enumerated() {
        gEngine.water.uvs[i][0].u = 0; gEngine.water.uvs[i][0].v = 0
        gEngine.water.uvs[i][1].u = 0; gEngine.water.uvs[i][1].v = 0
    }

    // ADJUST TO GAME COORDINATES
    for f in 0..<Int(gEngine.water.numPatches) {
        let water = gEngine.water.list! + f
        let nubs = nubListBase(water) // point to nub list
        var numNubs = Int(water.pointee.numNubs) // get # nubs in water

        if numNubs == 1 {
            SwFatal("PrimeTerrainWater: numNubs == 1")
        }

        if numNubs > MAX_NUBS_IN_WATER {
            SwFatal("PrimeTerrainWater: numNubs > MAX_NUBS_IN_WATER")
        }

        // IF FIRST AND LAST NUBS ARE SAME, THEN ELIMINATE LAST
        if nubs[0].x == nubs[numNubs - 1].x && nubs[0].y == nubs[numNubs - 1].y {
            numNubs -= 1
            water.pointee.numNubs = Int16(numNubs)
        }

        // CONVERT TO WORLD COORDS
        for i in 0..<numNubs {
            nubs[i].x *= gEngine.terrain.mapToUnitValue
            nubs[i].y *= gEngine.terrain.mapToUnitValue
        }

        // CREATE VERTEX ARRAY

        // FIND HARD-WIRED Y
        var y: Float
        if water.pointee.flags & UInt32(WATER_FLAG_FIXEDHEIGHT) != 0 {
            y = gWaterFixedYCoord[Int(water.pointee.height)]
        }
        // FIND Y @ HOT SPOT
        else {
            water.pointee.hotSpotX *= gEngine.terrain.mapToUnitValue
            water.pointee.hotSpotZ *= gEngine.terrain.mapToUnitValue

            y = GetTerrainY(water.pointee.hotSpotX, water.pointee.hotSpotZ)
        }

        gEngine.water.initY[f] = y // save water's y coord

        for i in 0..<numNubs {
            gEngine.water.pointsBuf[waterIdx(f, i)].x = nubs[i].x
            gEngine.water.pointsBuf[waterIdx(f, i)].y = y
            gEngine.water.pointsBuf[waterIdx(f, i)].z = nubs[i].y
        }

        // APPEND THE CENTER POINT TO THE POINT LIST
        var centerX: Float = 0, centerZ: Float = 0 // calc average of points
        for i in 0..<numNubs {
            centerX += gEngine.water.pointsBuf[waterIdx(f, i)].x
            centerZ += gEngine.water.pointsBuf[waterIdx(f, i)].z
        }
        centerX /= Float(numNubs)
        centerZ /= Float(numNubs)

        gEngine.water.pointsBuf[waterIdx(f, numNubs)].x = centerX
        gEngine.water.pointsBuf[waterIdx(f, numNubs)].z = centerZ
        gEngine.water.pointsBuf[waterIdx(f, numNubs)].y = y
    }

    // MAKE WATER GEOMETRY
    makeWaterGeometry()

    // CREATE DUMMY CUSTOM OBJECT TO CAUSE WATER DRAWING AT THE DESIRED TIME
    var def = NewObjectDefinitionType()
    def.genre = UInt8(CUSTOM_GENRE)
    def.slot = Int16(WATER_SLOT)
    def.moveCall = cMoveWater
    def.drawCall = cDrawWater
    def.flags = UInt32(STATUS_BIT_DOUBLESIDED | STATUS_BIT_NOLIGHTING | STATUS_BIT_DONTCULL)
    def.scale = 1

    let obj = MakeNewObject(&def)!
    obj.pointee.VertexArrayMode = UInt8(VertexArrayRangeType.userWater.rawValue)

    // (VERTEXARRAYRANGES is 0 - AssignVertexArrayRangeMemory block omitted, see file header comment)
}

// MARK: - Make water geometry

private func makeWaterGeometry() {
    for f in 0..<Int(gEngine.water.numPatches) {
        // GET WATER INFO
        let water = gEngine.water.list! + f // point to this water
        let numNubs = Int(water.pointee.numNubs) // get # nubs in water (note: this is the # from the file, not including the extra center point we added earlier!)
        if numNubs < 3 {
            SwFatal("MakeWaterGeometry: numNubs < 3")
        }
        let type = Int(water.pointee.type) // get water type

        // SET VERTEX ARRAY HEADER
        let tri = GetWaterTriMeshDataEntry(Int32(f))
        tri.pointee.VARtype = Int16(VertexArrayRangeType.userWater.rawValue)
        tri.pointee.points = gEngine.water.pointsBuf + waterIdx(f, 0)
        tri.pointee.triangles = gEngine.water.trianglesBuf + waterIdx(f, 0)
        tri.pointee.uvs.0 = gEngine.water.uvs1Buf + waterIdx(f, 0)
        tri.pointee.uvs.1 = gEngine.water.uvs2Buf + waterIdx(f, 0)
        tri.pointee.normals = nil
        tri.pointee.colorsFloat = nil
        tri.pointee.numPoints = Int32(numNubs + 1) // +1 is to include the extra center point
        tri.pointee.numTriangles = Int32(numNubs)

        // BUILD TRIANGLE INFO
        for i in 0..<Int(tri.pointee.numTriangles) {
            let idx = waterIdx(f, i)
            gEngine.water.trianglesBuf[idx].vertexIndices.0 = UInt32(numNubs) // vertex 0 is always the radial center that we appended to the end of the list
            gEngine.water.trianglesBuf[idx].vertexIndices.1 = UInt32(i)
            gEngine.water.trianglesBuf[idx].vertexIndices.2 = UInt32(i + 1)

            if gEngine.water.trianglesBuf[idx].vertexIndices.2 == UInt32(numNubs) { // check for wrap back
                gEngine.water.trianglesBuf[idx].vertexIndices.2 = 0
            }
        }

        // SET TEXTURE
        let mat = GetSpriteGroupPtr(Int32(SPRITE_GROUP_GLOBAL))![Int(gWaterTextureType[type])].materialObject!.assumingMemoryBound(to: MOMaterialObject.self) // get material obj

        tri.pointee.numMaterials = 2
        tri.pointee.materials.0 = mat // set illegal ref to material
        tri.pointee.materials.1 = mat

        mat.flags |= UInt32(BG3D_MATERIALFLAG_MULTITEXTURE) // set flags for multi-texture
        mat.multiTextureCombine = UInt16(MULTI_TEXTURE_COMBINE_MODULATE) // set combining mode

        // CALC BBOX
        var maxX: Float = -1_000_000, maxY: Float = -1_000_000, maxZ: Float = -1_000_000 // build new bboxes while we do this
        var minX = -maxX, minY = -maxY, minZ = -maxZ

        for i in 0..<numNubs {
            // GET COORDS
            let x = gEngine.water.pointsBuf[waterIdx(f, i)].x
            let y = gEngine.water.pointsBuf[waterIdx(f, i)].y
            let z = gEngine.water.pointsBuf[waterIdx(f, i)].z

            // CHECK BBOX
            if x < minX { minX = x } // find min/max bounds for bbox
            if x > maxX { maxX = x }
            if z < minZ { minZ = z }
            if z > maxZ { maxZ = z }
            if y < minY { minY = y }
            if y > maxY { maxY = y }
        }

        // SET CALCULATED BBOX
        let bboxPtr = GetWaterBBoxEntry(Int32(f))!
        bboxPtr.pointee.min.x = minX
        bboxPtr.pointee.max.x = maxX
        bboxPtr.pointee.min.y = minY
        bboxPtr.pointee.max.y = maxY
        bboxPtr.pointee.min.z = minZ
        bboxPtr.pointee.max.z = maxZ
        bboxPtr.pointee.isEmpty = 0

        // BUILD UV's
        for i in 0...numNubs {
            let x = gEngine.water.pointsBuf[waterIdx(f, i)].x
            let z = gEngine.water.pointsBuf[waterIdx(f, i)].z

            gEngine.water.uvs1Buf[waterIdx(f, i)].u = x * 0.0005
            gEngine.water.uvs1Buf[waterIdx(f, i)].v = z * 0.0005
            gEngine.water.uvs2Buf[waterIdx(f, i)].u = x * 0.0004
            gEngine.water.uvs2Buf[waterIdx(f, i)].v = z * 0.0004
        }
    }
}

// MARK: - Move water

private let cMoveWater: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { _ in
    moveWater()
}

private func moveWater() {
    let fps = gEngine.framesPerSecondFrac

    for (i, waterType) in WaterType.allCases.enumerated() {
        switch waterType {
        case .green, .blue:
            gEngine.water.uvs[i][0].u += 0.02 * fps
            gEngine.water.uvs[i][0].v += 0.02 * fps

            gEngine.water.uvs[i][1].u -= 0.015 * fps
            gEngine.water.uvs[i][1].v += 0.025 * fps

        case .lava:
            gEngine.water.uvs[i][0].u += 0.08 * fps
            gEngine.water.uvs[i][0].v += 0.03 * fps

            gEngine.water.uvs[i][1].u -= 0.06 * fps
            gEngine.water.uvs[i][1].v += 0.05 * fps

        case .lavaDir0:
            gEngine.water.uvs[i][0].v += 0.02 * fps
            gEngine.water.uvs[i][1].v += 0.03 * fps

        case .lavaDir4:
            gEngine.water.uvs[i][0].v -= 0.02 * fps
            gEngine.water.uvs[i][1].v -= 0.03 * fps

        case .lavaDir2:
            gEngine.water.uvs[i][0].u -= 0.02 * fps
            gEngine.water.uvs[i][1].u -= 0.03 * fps

        case .lavaDir6:
            gEngine.water.uvs[i][0].u += 0.02 * fps
            gEngine.water.uvs[i][1].u += 0.03 * fps

        case .lavaDir1:
            gEngine.water.uvs[i][0].u -= 0.02 * fps
            gEngine.water.uvs[i][0].v += 0.02 * fps
            gEngine.water.uvs[i][1].u -= 0.03 * fps
            gEngine.water.uvs[i][1].v += 0.03 * fps

        case .lavaDir3:
            gEngine.water.uvs[i][0].u -= 0.02 * fps
            gEngine.water.uvs[i][0].v -= 0.02 * fps
            gEngine.water.uvs[i][1].u -= 0.03 * fps
            gEngine.water.uvs[i][1].v -= 0.03 * fps

        case .lavaDir5:
            gEngine.water.uvs[i][0].u += 0.02 * fps
            gEngine.water.uvs[i][0].v -= 0.02 * fps
            gEngine.water.uvs[i][1].u += 0.03 * fps
            gEngine.water.uvs[i][1].v -= 0.03 * fps

        case .lavaDir7:
            gEngine.water.uvs[i][0].u += 0.02 * fps
            gEngine.water.uvs[i][0].v += 0.02 * fps
            gEngine.water.uvs[i][1].u += 0.03 * fps
            gEngine.water.uvs[i][1].v += 0.03 * fps

        }
    }
}

// MARK: - Draw water

private let cDrawWater: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { _ in
    drawWater()
}

private func drawWater() {
    var prevType = -1

    // DRAW EACH WATER
    gEngine.water.numDrawn = 0

    for f in 0..<Int(gEngine.water.numPatches) {
        let waterType = Int(gEngine.water.list![f].type)

        // DO BBOX CULLING
        if OGL_IsBBoxVisible(GetWaterBBoxEntry(Int32(f)), nil) != 0 {
            gEngine.metaObjects.globalTransparency = gWaterTransparency[waterType]

            if gWaterGlow[waterType] { // set glow
                OGL_BlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE))
            } else {
                OGL_BlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
            }

            // SET TEXTURE SCROLL FOR BOTH TEXTURE LAYERS
            if waterType != prevType { // only update UV's if this is a different water type than the last loop
                gEngine.renderer.matrixMode(.texture) // set texture matrix
                OGL_ActiveTextureUnit(UInt32(GL_TEXTURE0))
                gEngine.renderer.loadIdentity()
                gEngine.renderer.translate(gEngine.water.uvs[waterType][0].u, gEngine.water.uvs[waterType][0].v, 0)
                OGL_ActiveTextureUnit(UInt32(GL_TEXTURE1))
                gEngine.renderer.loadIdentity()
                gEngine.renderer.translate(gEngine.water.uvs[waterType][1].u, gEngine.water.uvs[waterType][1].v, 0)
                gEngine.renderer.matrixMode(.modelview)
                OGL_ActiveTextureUnit(UInt32(GL_TEXTURE0))
            }

            // DRAW IT
            MO_DrawGeometry_VertexArray(GetWaterTriMeshDataEntry(Int32(f)))
            gEngine.water.numDrawn += 1

            prevType = waterType
        }
    }

    // CLEANUP
    gEngine.metaObjects.globalTransparency = 1.0
    OGL_BlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))

    // RESTORE ALL TEXTURE MATRICES
    gEngine.renderer.matrixMode(.texture) // set texture matrix
    for i in 0..<2 {
        OGL_ActiveTextureUnit(UInt32(GL_TEXTURE0) + UInt32(i))
        gEngine.renderer.loadIdentity()
    }
    gEngine.renderer.matrixMode(.modelview)
    OGL_ActiveTextureUnit(UInt32(GL_TEXTURE0))
}

// MARK: - Do water collision detect

func DoWaterCollisionDetect(_ theNode: UnsafeMutablePointer<ObjNode>, _ x: Float, _ y: Float, _ z: Float, _ patchNum: UnsafeMutablePointer<Int32>?) -> UInt8 {
    for i in 0..<Int(gEngine.water.numPatches) {
        // QUICK CHECK TO SEE IF IS IN BBOX
        let bbox = GetWaterBBoxEntry(Int32(i))!.pointee

        if x < bbox.min.x || x > bbox.max.x || z < bbox.min.z || z > bbox.max.z || y > bbox.max.y {
            continue
        }

        // WE FOUND A HIT
        theNode.setStatus(STATUS_BIT_UNDERWATER)
        patchNum?.pointee = Int32(i)
        return 1
    }

    // NOT IN WATER
    theNode.clearStatus(STATUS_BIT_UNDERWATER)
    patchNum?.pointee = 0
    return 0
}

// MARK: - Is XZ over water
//
// Returns true if x/z coords are over a water bbox

func IsXZOverWater(_ x: Float, _ z: Float) -> UInt8 {
    for i in 0..<Int(gEngine.water.numPatches) {
        // QUICK CHECK TO SEE IF IS IN BBOX
        let bbox = GetWaterBBoxEntry(Int32(i))!.pointee

        if x > bbox.min.x && x < bbox.max.x && z > bbox.min.z && z < bbox.max.z {
            return 1
        }
    }

    return 0
}

// MARK: - Get water Y
//
// returns TRUE if over water.

func GetWaterY(_ x: Float, _ z: Float, _ y: UnsafeMutablePointer<Float>) -> UInt8 {
    for i in 0..<Int(gEngine.water.numPatches) {
        // QUICK CHECK TO SEE IF IS IN BBOX
        let bbox = GetWaterBBoxEntry(Int32(i))!.pointee

        if x < bbox.min.x || x > bbox.max.x || z < bbox.min.z || z > bbox.max.z {
            continue
        }

        // WE FOUND A HIT
        y.pointee = bbox.max.y // return y
        return 1
    }

    // NOT IN WATER
    y.pointee = 0
    return 0
}

// MARK: - Ripple

private func initRipples() {
    gEngine.water.numRipples = 0
    gEngine.water.rippleEventObj = nil

    for i in 0..<MAX_RIPPLES {
        gEngine.water.rippleList[i].isUsed = false
    }
}

func CreateNewRipple(_ where_: UnsafePointer<OGLPoint3D>, _ baseScale: Float, _ scaleSpeed: Float, _ fadeRate: Float) {
    let x = where_.pointee.x
    var y = where_.pointee.y
    let z = where_.pointee.z

    // GET Y COORD FOR WATER
    // if (!GetWaterY(x, z, &y2)) return; // bail if not actually on water

    y += 0.5 // raise ripple off water

    // CREATE RIPPLE EVENT OBJECT
    if gEngine.water.rippleEventObj == nil {
        var def = NewObjectDefinitionType()
        def.genre = UInt8(EVENT_GENRE)
        def.flags = UInt32(STATUS_BIT_DOUBLESIDED | STATUS_BIT_NOZWRITES | STATUS_BIT_NOLIGHTING | STATUS_BIT_GLOW | STATUS_BIT_NOFOG)
        def.slot = Int16(SLOT_OF_DUMB + 1)
        def.scale = 1
        def.moveCall = cMoveRippleEvent
        def.drawCall = cDrawRipples
        gEngine.water.rippleEventObj = MakeNewObject(&def)
    }

    // ADD TO RIPPLE LIST

    // SCAN FOR FREE RIPPLE SLOT
    guard let slot = (0..<MAX_RIPPLES).first(where: { !gEngine.water.rippleList[$0].isUsed }) else {
        return // no free slots
    }

    gEngine.water.rippleList[slot].isUsed = true
    gEngine.water.rippleList[slot].coord.x = x
    gEngine.water.rippleList[slot].coord.y = y
    gEngine.water.rippleList[slot].coord.z = z

    gEngine.water.rippleList[slot].scale = baseScale + RandomFloat() * 30.0
    gEngine.water.rippleList[slot].scaleSpeed = scaleSpeed
    gEngine.water.rippleList[slot].alpha = 0.999 - (RandomFloat() * 0.2)
    gEngine.water.rippleList[slot].fadeRate = fadeRate

    gEngine.water.numRipples += 1
}

func CreateMultipleNewRipples(_ x: Float, _ z: Float, _ baseScale: Float, _ scaleSpeed: Float, _ fadeRate: Float, _ numRipples: Int16) {
    // GET Y COORD FOR WATER
    var y2: Float = 0
    guard GetWaterY(x, z, &y2) != 0 else {
        return // bail if not actually on water
    }

    let y = y2 + 0.5 // raise ripple off water

    // CREATE RIPPLE EVENT OBJECT
    if gEngine.water.rippleEventObj == nil {
        var def = NewObjectDefinitionType()
        def.genre = UInt8(EVENT_GENRE)
        def.flags = UInt32(STATUS_BIT_DOUBLESIDED | STATUS_BIT_NOZWRITES | STATUS_BIT_NOLIGHTING | STATUS_BIT_GLOW | STATUS_BIT_NOFOG)
        def.slot = Int16(SLOT_OF_DUMB + 11)
        def.scale = 1
        def.moveCall = cMoveRippleEvent
        def.drawCall = cDrawRipples
        gEngine.water.rippleEventObj = MakeNewObject(&def)
    }

    // ADD TO RIPPLES LIST
    for _ in 0..<numRipples {
        // SCAN FOR FREE RIPPLE SLOT
        guard let slot = (0..<MAX_RIPPLES).first(where: { !gEngine.water.rippleList[$0].isUsed }) else {
            return // no free slots
        }

        gEngine.water.rippleList[slot].isUsed = true
        gEngine.water.rippleList[slot].coord.x = x
        gEngine.water.rippleList[slot].coord.y = y
        gEngine.water.rippleList[slot].coord.z = z

        gEngine.water.rippleList[slot].scale = baseScale + RandomFloat() * baseScale * 2.0
        gEngine.water.rippleList[slot].scaleSpeed = scaleSpeed + RandomFloat() * scaleSpeed * 3.0
        gEngine.water.rippleList[slot].alpha = 0.999 - (RandomFloat() * 0.3)
        gEngine.water.rippleList[slot].fadeRate = fadeRate

        gEngine.water.numRipples += 1
    }
}

private let cMoveRippleEvent: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNode in
    moveRippleEvent(theNode!)
}

private func moveRippleEvent(_ theNode: UnsafeMutablePointer<ObjNode>) {
    let fps = gEngine.framesPerSecondFrac

    for i in 0..<MAX_RIPPLES {
        if !gEngine.water.rippleList[i].isUsed { // see if this ripple slot active
            continue
        }

        gEngine.water.rippleList[i].scale += fps * gEngine.water.rippleList[i].scaleSpeed
        gEngine.water.rippleList[i].alpha -= fps * gEngine.water.rippleList[i].fadeRate
        if gEngine.water.rippleList[i].alpha <= 0 { // see if done
            gEngine.water.rippleList[i].isUsed = false // kill this slot
            gEngine.water.numRipples -= 1
        }
    }

    if gEngine.water.numRipples <= 0 { // see if all done
        DeleteObject(theNode)
        gEngine.water.rippleEventObj = nil
    }
}

private let cDrawRipples: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { _ in
    drawRipples()
}

private func drawRipples() {
    // ACTIVATE MATERIAL
    MO_DrawMaterial(GetSpriteGroupPtr(Int32(SPRITE_GROUP_GLOBAL))![Int(GLOBAL_SObjType_WaterRipple)].materialObject?.assumingMemoryBound(to: MOMaterialObject.self))

    // DRAW EACH RIPPLE
    for i in 0..<MAX_RIPPLES {
        if !gEngine.water.rippleList[i].isUsed { // see if this ripple slot active
            continue
        }

        let x = gEngine.water.rippleList[i].coord.x // get coord
        let y = gEngine.water.rippleList[i].coord.y
        let z = gEngine.water.rippleList[i].coord.z

        let s = gEngine.water.rippleList[i].scale // get scale
        OGL_SetColor4f(1, 1, 1, gEngine.water.rippleList[i].alpha) // get/set alpha

        gEngine.renderer.beginImmediate(.quads)
        gEngine.renderer.texCoord2f(0, 0); gEngine.renderer.vertex3f(x - s, y, z - s)
        gEngine.renderer.texCoord2f(1, 0); gEngine.renderer.vertex3f(x + s, y, z - s)
        gEngine.renderer.texCoord2f(1, 1); gEngine.renderer.vertex3f(x + s, y, z + s)
        gEngine.renderer.texCoord2f(0, 1); gEngine.renderer.vertex3f(x - s, y, z + s)
        gEngine.renderer.endImmediate()
    }

    OGL_SetColor4f(1, 1, 1, 1)
    gEngine.metaObjects.globalTransparency = 1.0
}
