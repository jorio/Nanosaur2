// Water.swift - Port of Water.c to Swift
//
// gNumWaterPatches, gNumWaterDrawn, gWaterListHandle, gWaterList,
// gWaterTriMeshData[], and gWaterBBox[] stay defined in Water.c and
// `extern`'d via game.h/WaterInternal.h: Pick.c, OGL_Support.c, Terrain.c,
// Player_Terrain.c, and EnemyInternal.h (still unported) read/write them
// directly by name. Everything else (gWaterInitY, gWaterVertexArrays,
// gWaterUVs, the ripple list, and the lookup tables) was `static`
// (file-private) in C, so it moves into private Swift state instead.
//
// VERTEXARRAYRANGES is hardcoded to 0 in game.h, so the
// `#if VERTEXARRAYRANGES` / AssignVertexArrayRangeMemory block in the
// original PrimeTerrainWater was dead code - it's omitted here, and the
// water vertex data (points/triangles/uvs) is just kept in flat allocated
// buffers instead of replicating the exact WaterVertexArraysType layout.

private let MAX_WATER = 60
private let MAX_NUBS_IN_WATER = 80
private let MAX_RIPPLES = 100

// MARK: - Water vertex data (flat buffers, [MAX_WATER][MAX_NUBS_IN_WATER*2])

@inline(__always) private func waterIdx(_ f: Int, _ i: Int) -> Int {
    f * (MAX_NUBS_IN_WATER * 2) + i
}

private let gWaterPointsBuf = AllocPtrClear(MemoryLayout<OGLPoint3D>.size * MAX_WATER * MAX_NUBS_IN_WATER * 2)!.assumingMemoryBound(to: OGLPoint3D.self)
private let gWaterTrianglesBuf = AllocPtrClear(MemoryLayout<MOTriangleIndecies>.size * MAX_WATER * MAX_NUBS_IN_WATER * 2)!.assumingMemoryBound(to: MOTriangleIndecies.self)
private let gWaterUvs1Buf = AllocPtrClear(MemoryLayout<OGLTextureCoord>.size * MAX_WATER * MAX_NUBS_IN_WATER * 2)!.assumingMemoryBound(to: OGLTextureCoord.self)
private let gWaterUvs2Buf = AllocPtrClear(MemoryLayout<OGLTextureCoord>.size * MAX_WATER * MAX_NUBS_IN_WATER * 2)!.assumingMemoryBound(to: OGLTextureCoord.self)

private var gWaterInitY = [Float](repeating: 0, count: MAX_WATER)

// UV'S FOR WATER TYPES ([2] is for the two layers we can have)
private var gWaterUVs: [[OGLTextureCoord]] = Array(repeating: Array(repeating: OGLTextureCoord(), count: 2), count: Int(NUM_WATER_TYPES))

// RIPPLES
private var gNumRipples = 0
private var gRippleEventObj: UnsafeMutablePointer<ObjNode>?

private struct RippleRecord {
    var isUsed = false
    var coord = OGLPoint3D()
    var alpha: Float = 0
    var fadeRate: Float = 0
    var scale: Float = 0
    var scaleSpeed: Float = 0
}

private var gRippleList = [RippleRecord](repeating: RippleRecord(), count: MAX_RIPPLES)

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

private let gWaterGlow: [Bool] = Array(repeating: false, count: Int(NUM_WATER_TYPES))

private let gWaterFixedYCoord: [Float] = [
    400.0, // #0 swimming pool
]

// MARK: - fixed-array-field helpers (all struct fields, never unions)

@inline(__always) private func nubListBase(_ w: UnsafeMutablePointer<WaterDefType>) -> UnsafeMutablePointer<OGLPoint2D> {
    UnsafeMutableRawPointer(w.pointer(to: \.nubList)!).assumingMemoryBound(to: OGLPoint2D.self)
}

// MARK: - Dispose water

@c @implementation
public func DisposeWater() {
    guard let handle = gWaterListHandle else {
        return
    }

    DisposeWaterListHandle(handle)
    gWaterListHandle = nil
    gWaterList = nil
    gNumWaterPatches = 0
}

// MARK: - Prime water
//
// Called during terrain prime function to initialize

@c @implementation
public func PrimeTerrainWater() {
    initRipples()

    if gNumWaterPatches > MAX_WATER {
        SwFatal("PrimeTerrainWater: gNumWaterPatches > MAX_WATER")
    }

    // INIT UVS
    for i in 0..<Int(NUM_WATER_TYPES) {
        gWaterUVs[i][0].u = 0; gWaterUVs[i][0].v = 0
        gWaterUVs[i][1].u = 0; gWaterUVs[i][1].v = 0
    }

    // ADJUST TO GAME COORDINATES
    for f in 0..<Int(gNumWaterPatches) {
        let water = gWaterList! + f
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
            nubs[i].x *= gMapToUnitValue
            nubs[i].y *= gMapToUnitValue
        }

        // CREATE VERTEX ARRAY

        // FIND HARD-WIRED Y
        var y: Float
        if water.pointee.flags & UInt32(WATER_FLAG_FIXEDHEIGHT) != 0 {
            y = gWaterFixedYCoord[Int(water.pointee.height)]
        }
        // FIND Y @ HOT SPOT
        else {
            water.pointee.hotSpotX *= gMapToUnitValue
            water.pointee.hotSpotZ *= gMapToUnitValue

            y = GetTerrainY(water.pointee.hotSpotX, water.pointee.hotSpotZ)
        }

        gWaterInitY[f] = y // save water's y coord

        for i in 0..<numNubs {
            gWaterPointsBuf[waterIdx(f, i)].x = nubs[i].x
            gWaterPointsBuf[waterIdx(f, i)].y = y
            gWaterPointsBuf[waterIdx(f, i)].z = nubs[i].y
        }

        // APPEND THE CENTER POINT TO THE POINT LIST
        var centerX: Float = 0, centerZ: Float = 0 // calc average of points
        for i in 0..<numNubs {
            centerX += gWaterPointsBuf[waterIdx(f, i)].x
            centerZ += gWaterPointsBuf[waterIdx(f, i)].z
        }
        centerX /= Float(numNubs)
        centerZ /= Float(numNubs)

        gWaterPointsBuf[waterIdx(f, numNubs)].x = centerX
        gWaterPointsBuf[waterIdx(f, numNubs)].z = centerZ
        gWaterPointsBuf[waterIdx(f, numNubs)].y = y
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
    obj.pointee.VertexArrayMode = UInt8(VERTEX_ARRAY_RANGE_TYPE_USER_WATER)

    // (VERTEXARRAYRANGES is 0 - AssignVertexArrayRangeMemory block omitted, see file header comment)
}

// MARK: - Make water geometry

private func makeWaterGeometry() {
    for f in 0..<Int(gNumWaterPatches) {
        // GET WATER INFO
        let water = gWaterList! + f // point to this water
        let numNubs = Int(water.pointee.numNubs) // get # nubs in water (note: this is the # from the file, not including the extra center point we added earlier!)
        if numNubs < 3 {
            SwFatal("MakeWaterGeometry: numNubs < 3")
        }
        let type = Int(water.pointee.type) // get water type

        // SET VERTEX ARRAY HEADER
        let tri = GetWaterTriMeshDataEntry(Int32(f))
        tri.pointee.VARtype = Int16(VERTEX_ARRAY_RANGE_TYPE_USER_WATER)
        tri.pointee.points = gWaterPointsBuf + waterIdx(f, 0)
        tri.pointee.triangles = gWaterTrianglesBuf + waterIdx(f, 0)
        tri.pointee.uvs.0 = gWaterUvs1Buf + waterIdx(f, 0)
        tri.pointee.uvs.1 = gWaterUvs2Buf + waterIdx(f, 0)
        tri.pointee.normals = nil
        tri.pointee.colorsFloat = nil
        tri.pointee.numPoints = Int32(numNubs + 1) // +1 is to include the extra center point
        tri.pointee.numTriangles = Int32(numNubs)

        // BUILD TRIANGLE INFO
        for i in 0..<Int(tri.pointee.numTriangles) {
            let idx = waterIdx(f, i)
            gWaterTrianglesBuf[idx].vertexIndices.0 = UInt32(numNubs) // vertex 0 is always the radial center that we appended to the end of the list
            gWaterTrianglesBuf[idx].vertexIndices.1 = UInt32(i)
            gWaterTrianglesBuf[idx].vertexIndices.2 = UInt32(i + 1)

            if gWaterTrianglesBuf[idx].vertexIndices.2 == UInt32(numNubs) { // check for wrap back
                gWaterTrianglesBuf[idx].vertexIndices.2 = 0
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
            let x = gWaterPointsBuf[waterIdx(f, i)].x
            let y = gWaterPointsBuf[waterIdx(f, i)].y
            let z = gWaterPointsBuf[waterIdx(f, i)].z

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
            let x = gWaterPointsBuf[waterIdx(f, i)].x
            let z = gWaterPointsBuf[waterIdx(f, i)].z

            gWaterUvs1Buf[waterIdx(f, i)].u = x * 0.0005
            gWaterUvs1Buf[waterIdx(f, i)].v = z * 0.0005
            gWaterUvs2Buf[waterIdx(f, i)].u = x * 0.0004
            gWaterUvs2Buf[waterIdx(f, i)].v = z * 0.0004
        }
    }
}

// MARK: - Move water

private let cMoveWater: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { _ in
    moveWater()
}

private func moveWater() {
    let fps = gFramesPerSecondFrac

    for i in 0..<Int(NUM_WATER_TYPES) {
        switch i {
        case Int(WATER_TYPE_GREEN), Int(WATER_TYPE_BLUE):
            gWaterUVs[i][0].u += 0.02 * fps
            gWaterUVs[i][0].v += 0.02 * fps

            gWaterUVs[i][1].u -= 0.015 * fps
            gWaterUVs[i][1].v += 0.025 * fps

        case Int(WATER_TYPE_LAVA):
            gWaterUVs[i][0].u += 0.08 * fps
            gWaterUVs[i][0].v += 0.03 * fps

            gWaterUVs[i][1].u -= 0.06 * fps
            gWaterUVs[i][1].v += 0.05 * fps

        case Int(WATER_TYPE_LAVA_DIR0):
            gWaterUVs[i][0].v += 0.02 * fps
            gWaterUVs[i][1].v += 0.03 * fps

        case Int(WATER_TYPE_LAVA_DIR4):
            gWaterUVs[i][0].v -= 0.02 * fps
            gWaterUVs[i][1].v -= 0.03 * fps

        case Int(WATER_TYPE_LAVA_DIR2):
            gWaterUVs[i][0].u -= 0.02 * fps
            gWaterUVs[i][1].u -= 0.03 * fps

        case Int(WATER_TYPE_LAVA_DIR6):
            gWaterUVs[i][0].u += 0.02 * fps
            gWaterUVs[i][1].u += 0.03 * fps

        case Int(WATER_TYPE_LAVA_DIR1):
            gWaterUVs[i][0].u -= 0.02 * fps
            gWaterUVs[i][0].v += 0.02 * fps
            gWaterUVs[i][1].u -= 0.03 * fps
            gWaterUVs[i][1].v += 0.03 * fps

        case Int(WATER_TYPE_LAVA_DIR3):
            gWaterUVs[i][0].u -= 0.02 * fps
            gWaterUVs[i][0].v -= 0.02 * fps
            gWaterUVs[i][1].u -= 0.03 * fps
            gWaterUVs[i][1].v -= 0.03 * fps

        case Int(WATER_TYPE_LAVA_DIR5):
            gWaterUVs[i][0].u += 0.02 * fps
            gWaterUVs[i][0].v -= 0.02 * fps
            gWaterUVs[i][1].u += 0.03 * fps
            gWaterUVs[i][1].v -= 0.03 * fps

        case Int(WATER_TYPE_LAVA_DIR7):
            gWaterUVs[i][0].u += 0.02 * fps
            gWaterUVs[i][0].v += 0.02 * fps
            gWaterUVs[i][1].u += 0.03 * fps
            gWaterUVs[i][1].v += 0.03 * fps

        default:
            break
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
    gNumWaterDrawn = 0

    for f in 0..<Int(gNumWaterPatches) {
        let waterType = Int(gWaterList![f].type)

        // DO BBOX CULLING
        if OGL_IsBBoxVisible(GetWaterBBoxEntry(Int32(f)), nil) != 0 {
            gGlobalTransparency = gWaterTransparency[waterType]

            if gWaterGlow[waterType] { // set glow
                OGL_BlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE))
            } else {
                OGL_BlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
            }

            // SET TEXTURE SCROLL FOR BOTH TEXTURE LAYERS
            if waterType != prevType { // only update UV's if this is a different water type than the last loop
                glMatrixMode(GLenum(GL_TEXTURE)) // set texture matrix
                OGL_ActiveTextureUnit(UInt32(GL_TEXTURE0))
                glLoadIdentity()
                glTranslatef(gWaterUVs[waterType][0].u, gWaterUVs[waterType][0].v, 0)
                OGL_ActiveTextureUnit(UInt32(GL_TEXTURE1))
                glLoadIdentity()
                glTranslatef(gWaterUVs[waterType][1].u, gWaterUVs[waterType][1].v, 0)
                glMatrixMode(GLenum(GL_MODELVIEW))
                OGL_ActiveTextureUnit(UInt32(GL_TEXTURE0))
            }

            // DRAW IT
            MO_DrawGeometry_VertexArray(GetWaterTriMeshDataEntry(Int32(f)))
            gNumWaterDrawn += 1

            prevType = waterType
        }
    }

    // CLEANUP
    gGlobalTransparency = 1.0
    OGL_BlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))

    // RESTORE ALL TEXTURE MATRICES
    glMatrixMode(GLenum(GL_TEXTURE)) // set texture matrix
    for i in 0..<2 {
        OGL_ActiveTextureUnit(UInt32(GL_TEXTURE0) + UInt32(i))
        glLoadIdentity()
    }
    glMatrixMode(GLenum(GL_MODELVIEW))
    OGL_ActiveTextureUnit(UInt32(GL_TEXTURE0))
}

// MARK: - Do water collision detect

@c @implementation
public func DoWaterCollisionDetect(_ theNode: UnsafeMutablePointer<ObjNode>, _ x: Float, _ y: Float, _ z: Float, _ patchNum: UnsafeMutablePointer<Int32>?) -> UInt8 {
    for i in 0..<Int(gNumWaterPatches) {
        // QUICK CHECK TO SEE IF IS IN BBOX
        let bbox = GetWaterBBoxEntry(Int32(i))!.pointee

        if x < bbox.min.x || x > bbox.max.x || z < bbox.min.z || z > bbox.max.z || y > bbox.max.y {
            continue
        }

        // WE FOUND A HIT
        theNode.pointee.StatusBits |= UInt32(STATUS_BIT_UNDERWATER)
        patchNum?.pointee = Int32(i)
        return 1
    }

    // NOT IN WATER
    theNode.pointee.StatusBits &= ~UInt32(STATUS_BIT_UNDERWATER)
    patchNum?.pointee = 0
    return 0
}

// MARK: - Is XZ over water
//
// Returns true if x/z coords are over a water bbox

@c @implementation
public func IsXZOverWater(_ x: Float, _ z: Float) -> UInt8 {
    for i in 0..<Int(gNumWaterPatches) {
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

@c @implementation
public func GetWaterY(_ x: Float, _ z: Float, _ y: UnsafeMutablePointer<Float>) -> UInt8 {
    for i in 0..<Int(gNumWaterPatches) {
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
    gNumRipples = 0
    gRippleEventObj = nil

    for i in 0..<MAX_RIPPLES {
        gRippleList[i].isUsed = false
    }
}

@c @implementation
public func CreateNewRipple(_ where_: UnsafePointer<OGLPoint3D>, _ baseScale: Float, _ scaleSpeed: Float, _ fadeRate: Float) {
    let x = where_.pointee.x
    var y = where_.pointee.y
    let z = where_.pointee.z

    // GET Y COORD FOR WATER
    // if (!GetWaterY(x, z, &y2)) return; // bail if not actually on water

    y += 0.5 // raise ripple off water

    // CREATE RIPPLE EVENT OBJECT
    if gRippleEventObj == nil {
        var def = NewObjectDefinitionType()
        def.genre = UInt8(EVENT_GENRE)
        def.flags = UInt32(STATUS_BIT_DOUBLESIDED | STATUS_BIT_NOZWRITES | STATUS_BIT_NOLIGHTING | STATUS_BIT_GLOW | STATUS_BIT_NOFOG)
        def.slot = Int16(SLOT_OF_DUMB + 1)
        def.scale = 1
        def.moveCall = cMoveRippleEvent
        def.drawCall = cDrawRipples
        gRippleEventObj = MakeNewObject(&def)
    }

    // ADD TO RIPPLE LIST

    // SCAN FOR FREE RIPPLE SLOT
    guard let slot = (0..<MAX_RIPPLES).first(where: { !gRippleList[$0].isUsed }) else {
        return // no free slots
    }

    gRippleList[slot].isUsed = true
    gRippleList[slot].coord.x = x
    gRippleList[slot].coord.y = y
    gRippleList[slot].coord.z = z

    gRippleList[slot].scale = baseScale + RandomFloat() * 30.0
    gRippleList[slot].scaleSpeed = scaleSpeed
    gRippleList[slot].alpha = 0.999 - (RandomFloat() * 0.2)
    gRippleList[slot].fadeRate = fadeRate

    gNumRipples += 1
}

@c @implementation
public func CreateMultipleNewRipples(_ x: Float, _ z: Float, _ baseScale: Float, _ scaleSpeed: Float, _ fadeRate: Float, _ numRipples: Int16) {
    // GET Y COORD FOR WATER
    var y2: Float = 0
    guard GetWaterY(x, z, &y2) != 0 else {
        return // bail if not actually on water
    }

    let y = y2 + 0.5 // raise ripple off water

    // CREATE RIPPLE EVENT OBJECT
    if gRippleEventObj == nil {
        var def = NewObjectDefinitionType()
        def.genre = UInt8(EVENT_GENRE)
        def.flags = UInt32(STATUS_BIT_DOUBLESIDED | STATUS_BIT_NOZWRITES | STATUS_BIT_NOLIGHTING | STATUS_BIT_GLOW | STATUS_BIT_NOFOG)
        def.slot = Int16(SLOT_OF_DUMB + 11)
        def.scale = 1
        def.moveCall = cMoveRippleEvent
        def.drawCall = cDrawRipples
        gRippleEventObj = MakeNewObject(&def)
    }

    // ADD TO RIPPLES LIST
    for _ in 0..<numRipples {
        // SCAN FOR FREE RIPPLE SLOT
        guard let slot = (0..<MAX_RIPPLES).first(where: { !gRippleList[$0].isUsed }) else {
            return // no free slots
        }

        gRippleList[slot].isUsed = true
        gRippleList[slot].coord.x = x
        gRippleList[slot].coord.y = y
        gRippleList[slot].coord.z = z

        gRippleList[slot].scale = baseScale + RandomFloat() * baseScale * 2.0
        gRippleList[slot].scaleSpeed = scaleSpeed + RandomFloat() * scaleSpeed * 3.0
        gRippleList[slot].alpha = 0.999 - (RandomFloat() * 0.3)
        gRippleList[slot].fadeRate = fadeRate

        gNumRipples += 1
    }
}

private let cMoveRippleEvent: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNode in
    moveRippleEvent(theNode!)
}

private func moveRippleEvent(_ theNode: UnsafeMutablePointer<ObjNode>) {
    let fps = gFramesPerSecondFrac

    for i in 0..<MAX_RIPPLES {
        if !gRippleList[i].isUsed { // see if this ripple slot active
            continue
        }

        gRippleList[i].scale += fps * gRippleList[i].scaleSpeed
        gRippleList[i].alpha -= fps * gRippleList[i].fadeRate
        if gRippleList[i].alpha <= 0 { // see if done
            gRippleList[i].isUsed = false // kill this slot
            gNumRipples -= 1
        }
    }

    if gNumRipples <= 0 { // see if all done
        DeleteObject(theNode)
        gRippleEventObj = nil
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
        if !gRippleList[i].isUsed { // see if this ripple slot active
            continue
        }

        let x = gRippleList[i].coord.x // get coord
        let y = gRippleList[i].coord.y
        let z = gRippleList[i].coord.z

        let s = gRippleList[i].scale // get scale
        OGL_SetColor4f(1, 1, 1, gRippleList[i].alpha) // get/set alpha

        glBegin(GLenum(GL_QUADS))
        glTexCoord2f(0, 0); glVertex3f(x - s, y, z - s)
        glTexCoord2f(1, 0); glVertex3f(x + s, y, z - s)
        glTexCoord2f(1, 1); glVertex3f(x + s, y, z + s)
        glTexCoord2f(0, 1); glVertex3f(x - s, y, z + s)
        glEnd()
    }

    OGL_SetColor4f(1, 1, 1, 1)
    gGlobalTransparency = 1.0
}
