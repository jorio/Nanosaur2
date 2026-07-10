// Particles.swift - Port of Particles.c to Swift
//
// gNewParticleGroupDef is native Swift storage now (converted 2026-07-07):
// nothing in any .c file touches it anymore (LaserOrbs.c/Turrets.c/Mines.c,
// its only real C users, are all deleted). gParticleGroups and
// gNumActiveParticleGroups were plain (non-extern) globals only ever
// touched from this file, so they stay private Swift storage.
// gGravitoidDistBuffer (a big fixed 2D float array) is likewise file-local
// only, so it becomes a plain Swift 2D array.

var gNewParticleGroupDef = NewParticleGroupDefType()

private let fireBlastRadius: Float = gTerrainPolygonSize * 1.5 // unused by any ported call site yet, kept for parity

private let fireTimer: Float = 0.05
private let smokeTimer: Float = 0.07

private var gParticleGroups = InlineArray<80, UnsafeMutablePointer<ParticleGroupType>?>(repeating: nil)

private extension UnsafeMutablePointer where Pointee == ParticleGroupType {
    var isInPurgeQueue: Bool {
        get { pointee.inPurgeQueue != 0 }
        nonmutating set { pointee.inPurgeQueue = newValue ? 1 : 0 }
    }

    var particleType: ParticleType? {
        ParticleType(rawValue: Int32(pointee.type))
    }
}

// Not private: NewParticleGroup callers across Items/Player/Enemies/Effects
// fill in gNewParticleGroupDef (or a local groupDef) with this.
extension NewParticleGroupDefType {
    var particleType: ParticleType {
        get { ParticleType(rawValue: Int32(type)) ?? .fallingSparks }
        set { type = UInt8(newValue.rawValue) }
    }
}
private var gGravitoidDistBuffer = Array(repeating: Array(repeating: Float(0), count: Int(MAX_PARTICLES)), count: Int(MAX_PARTICLES))
private var gNumActiveParticleGroups: Int16 = 0

// MARK: - fixed-array-field helpers (all struct fields, never unions)

@inline(__always) private func isUsedBase(_ g: UnsafeMutablePointer<ParticleGroupType>) -> UnsafeMutablePointer<UInt8> {
    UnsafeMutableRawPointer(g.pointer(to: \.isUsed)!).assumingMemoryBound(to: UInt8.self)
}

@inline(__always) private func alphaBase(_ g: UnsafeMutablePointer<ParticleGroupType>) -> UnsafeMutablePointer<Float> {
    UnsafeMutableRawPointer(g.pointer(to: \.alpha)!).assumingMemoryBound(to: Float.self)
}

@inline(__always) private func scaleBase(_ g: UnsafeMutablePointer<ParticleGroupType>) -> UnsafeMutablePointer<Float> {
    UnsafeMutableRawPointer(g.pointer(to: \.scale)!).assumingMemoryBound(to: Float.self)
}

@inline(__always) private func rotZBase(_ g: UnsafeMutablePointer<ParticleGroupType>) -> UnsafeMutablePointer<Float> {
    UnsafeMutableRawPointer(g.pointer(to: \.rotZ)!).assumingMemoryBound(to: Float.self)
}

@inline(__always) private func rotDZBase(_ g: UnsafeMutablePointer<ParticleGroupType>) -> UnsafeMutablePointer<Float> {
    UnsafeMutableRawPointer(g.pointer(to: \.rotDZ)!).assumingMemoryBound(to: Float.self)
}

@inline(__always) private func coordBase(_ g: UnsafeMutablePointer<ParticleGroupType>) -> UnsafeMutablePointer<OGLPoint3D> {
    UnsafeMutableRawPointer(g.pointer(to: \.coord)!).assumingMemoryBound(to: OGLPoint3D.self)
}

@inline(__always) private func deltaBase(_ g: UnsafeMutablePointer<ParticleGroupType>) -> UnsafeMutablePointer<OGLVector3D> {
    UnsafeMutableRawPointer(g.pointer(to: \.delta)!).assumingMemoryBound(to: OGLVector3D.self)
}

// geometryObj[2][MAX_PLAYERS] - flat index = buffNum * MAX_PLAYERS + playerNum
@inline(__always) private func geometryObjBase(_ g: UnsafeMutablePointer<ParticleGroupType>) -> UnsafeMutablePointer<UnsafeMutablePointer<MOVertexArrayObject>?> {
    UnsafeMutableRawPointer(g.pointer(to: \.geometryObj)!).assumingMemoryBound(to: UnsafeMutablePointer<MOVertexArrayObject>?.self)
}

@inline(__always) private func geometryObj(_ g: UnsafeMutablePointer<ParticleGroupType>, _ buffNum: Int, _ playerNum: Int) -> UnsafeMutablePointer<MOVertexArrayObject>? {
    geometryObjBase(g)[buffNum * Int(MAX_PLAYERS) + playerNum]
}

@inline(__always) private func setGeometryObj(_ g: UnsafeMutablePointer<ParticleGroupType>, _ buffNum: Int, _ playerNum: Int, _ value: UnsafeMutablePointer<MOVertexArrayObject>?) {
    geometryObjBase(g)[buffNum * Int(MAX_PLAYERS) + playerNum] = value
}

// MARK: - Init particle system

func InitParticleSystem() {
    // INIT GROUP ARRAY

    for i in 0..<Int(MAX_PARTICLE_GROUPS) {
        gParticleGroups[i] = nil
    }

    gNumActiveParticleGroups = 0

    // LOAD SPRITES

    SwGameAssert(GetNumSpritesInGroup(Int32(SPRITE_GROUP_PARTICLES)) == Int32(PARTICLE_SObjType_COUNT))

    // CREATE DUMMY CUSTOM OBJECT TO CAUSE PARTICLE DRAWING AT THE DESIRED TIME
    //
    // The particles need to be drawn after the fences object, but before any sprite or font objects.

    var def = NewObjectDefinitionType()
    def.genre = UInt8(CUSTOM_GENRE)
    def.slot = Int16(PARTICLE_SLOT)
    def.scale = 1
    def.flags = UInt32(STATUS_BIT_DOUBLESIDED | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOZWRITES | STATUS_BIT_NOFOG | STATUS_BIT_GLOW)
    def.moveCall = cMoveParticleGroups
    def.drawCall = cDrawParticleGroups

    let obj = MakeNewObject(&def)!
    obj.pointee.VertexArrayMode = UInt8(VertexArrayRangeType.particles1.rawValue)
}

// MARK: - Dispose particle system

func DisposeParticleSystem() {
    DeleteAllParticleGroups()
}

// MARK: - Delete all particle groups

func DeleteAllParticleGroups() {
    for i in 0..<Int(MAX_PARTICLE_GROUPS) {
        deleteParticleGroup(i)
    }

    purgePendingParticleGroups(true) // force it to purge immediately!
}

// MARK: - Delete particle group

// With vertex arrays ranges we've got to be careful.  We cannot immediately delete the data
// and allow it to be re-allocated since it might still be in use by the GPU.
//
// Therefore, we actually put the particle group into a purge queue so that there's time for the
// GPU to finish with it.
private func deleteParticleGroup(_ groupNum: Int) {
    if let group = gParticleGroups[groupNum] {
        group.isInPurgeQueue = true
        group.pointee.purgeTimer = 2
    }
}

// MARK: - Purge pending particle groups

// Checks all deleted particle groups to see if they're ok to be purged now (see above).
private func purgePendingParticleGroups(_ forcePurgeNow: Bool) {
    for g in 0..<Int(MAX_PARTICLE_GROUPS) {
        guard let group = gParticleGroups[g] else { // does this pg exist?
            continue
        }

        if group.isInPurgeQueue { // is it in the purge queue?
            group.pointee.purgeTimer -= 1

            if forcePurgeNow || (group.pointee.purgeTimer <= 0) { // time to purge?
                // NUKE GEOMETRY DATA

                for i in 0..<Int(gNumPlayers) {
                    MO_DisposeObjectReference(UnsafeMutableRawPointer(geometryObj(group, 0, i)))
                    MO_DisposeObjectReference(UnsafeMutableRawPointer(geometryObj(group, 1, i)))
                }

                // NUKE GROUP ITSELF

                SafeDisposePtr(group)
                gParticleGroups[g] = nil

                gNumActiveParticleGroups -= 1
            }
        }
    }
}

// MARK: - New particle group

// INPUT:	type 	=	group type to create
//
// OUTPUT:	group ID#
func NewParticleGroup(_ def: UnsafeMutablePointer<NewParticleGroupDefType>!) -> Int16 {
    // SCAN FOR A FREE GROUP

    for i in 0..<Int(MAX_PARTICLE_GROUPS) {
        if gParticleGroups[i] == nil {
            // ALLOCATE NEW GROUP

            guard let group = AllocPtrClear(MemoryLayout<ParticleGroupType>.size)?.assumingMemoryBound(to: ParticleGroupType.self) else {
                return -1 // out of memory
            }
            gParticleGroups[i] = group

            // INITIALIZE THE GROUP

            group.pointee.type = def.pointee.type // set type
            let isUsed = isUsedBase(group)
            for p in 0..<Int(MAX_PARTICLES) { // mark all unused
                isUsed[p] = 0
            }

            group.isInPurgeQueue = false

            group.pointee.flags = def.pointee.flags
            group.pointee.gravity = def.pointee.gravity
            group.pointee.magnetism = def.pointee.magnetism
            group.pointee.baseScale = def.pointee.baseScale
            group.pointee.decayRate = def.pointee.decayRate
            group.pointee.fadeRate = def.pointee.fadeRate
            group.pointee.magicNum = def.pointee.magicNum
            group.pointee.particleTextureNum = def.pointee.particleTextureNum

            group.pointee.srcBlend = def.pointee.srcBlend
            group.pointee.dstBlend = def.pointee.dstBlend

            group.pointee.visibleForPlayer1 = true
            group.pointee.visibleForPlayer2 = true

            // INIT THE GROUP'S GEOMETRY
            //
            // We create 4 separate vertex arrary objects because we double buffer this, once for each player.
            // This way we can modify one VAR while the GPU is still drawing the other VAR.
            // Doing this should be more efficient than using OpenGL Fences because we won't
            // have to wait for the previous frame to complete drawing before we can modify
            // this frame's particle geometry.

            for b in 0..<2 {
                for playerNum in 0..<Int(gNumPlayers) {
                    // SET THE DATA

                    var vertexArrayData = MOVertexArrayData()

                    let varType = Int16(VertexArrayRangeType.particles1.rawValue) + Int16(b)
                    vertexArrayData.VARtype = varType

                    vertexArrayData.numMaterials = 1
                    vertexArrayData.materials.0 = GetSpriteGroupPtr(Int32(SPRITE_GROUP_PARTICLES))![Int(def.pointee.particleTextureNum)].materialObject?.assumingMemoryBound(to: MOMaterialObject.self) // set illegal ref because it is made legit below

                    vertexArrayData.numPoints = 0
                    vertexArrayData.numTriangles = 0
                    let points = OGL_AllocVertexArrayMemory(Int(MemoryLayout<OGLPoint3D>.size * Int(MAX_PARTICLES) * 4), UInt8(varType))!.assumingMemoryBound(to: OGLPoint3D.self)
                    vertexArrayData.points = points
                    vertexArrayData.normals = nil
                    let uv = OGL_AllocVertexArrayMemory(Int(MemoryLayout<OGLTextureCoord>.size * Int(MAX_PARTICLES) * 4), UInt8(varType))!.assumingMemoryBound(to: OGLTextureCoord.self)
                    vertexArrayData.uvs.0 = uv
                    vertexArrayData.colorsFloat = OGL_AllocVertexArrayMemory(Int(MemoryLayout<OGLColorRGBA>.size * Int(MAX_PARTICLES) * 4), UInt8(varType))!.assumingMemoryBound(to: OGLColorRGBA.self)
                    let t = OGL_AllocVertexArrayMemory(Int(MemoryLayout<MOTriangleIndecies>.size * Int(MAX_PARTICLES) * 2), UInt8(varType))!.assumingMemoryBound(to: MOTriangleIndecies.self)
                    vertexArrayData.triangles = t

                    // INIT UV ARRAYS

                    var j = 0
                    while j < (Int(MAX_PARTICLES) * 4) {
                        uv[j + 0] = OGLTextureCoord(u: 0, v: 0) // upper left
                        uv[j + 1] = OGLTextureCoord(u: 0, v: 1) // lower left
                        uv[j + 2] = OGLTextureCoord(u: 1, v: 1) // lower right
                        uv[j + 3] = OGLTextureCoord(u: 1, v: 0) // upper right
                        j += 4
                    }

                    // INIT TRIANGLE ARRAYS

                    j = 0
                    var k = 0
                    while j < (Int(MAX_PARTICLES) * 2) {
                        t[j].vertexIndices.0 = UInt32(k) // triangle A
                        t[j].vertexIndices.1 = UInt32(k + 1)
                        t[j].vertexIndices.2 = UInt32(k + 2)

                        t[j + 1].vertexIndices.0 = UInt32(k) // triangle B
                        t[j + 1].vertexIndices.1 = UInt32(k + 2)
                        t[j + 1].vertexIndices.2 = UInt32(k + 3)

                        j += 2
                        k += 4
                    }

                    // CREATE NEW GEOMETRY OBJECT

                    let newGeoObj = MO_CreateNewObjectOfType(.geometry, Int(MO_GEOMETRY_SUBTYPE_VERTEXARRAY), &vertexArrayData)?.assumingMemoryBound(to: MOVertexArrayObject.self)
                    setGeometryObj(group, b, playerNum, newGeoObj)
                }
            }

            gNumActiveParticleGroups += 1

            return Int16(i)
        }
    }

    // NOTHING FREE

    // DoFatalAlert("NewParticleGroup: no free groups!");
    return -1
}

// MARK: - Add particle to group

// Returns true if particle group was invalid or is full.
func AddParticleToGroup(_ def: UnsafePointer<NewParticleDefType>!) -> UInt8 {
    let group = Int(def.pointee.groupNum)

    SwGameAssertMessage(group >= 0 && group < Int(MAX_PARTICLE_GROUPS), "Illegal group #")

    guard let g = gParticleGroups[group] else {
        return 1
    }

    // SCAN FOR FREE SLOT

    let isUsed = isUsedBase(g)
    var p = -1
    for i in 0..<Int(MAX_PARTICLES) {
        if isUsed[i] == 0 {
            p = i
            break
        }
    }

    // NO FREE SLOTS

    guard p >= 0 else {
        return 1
    }

    // INIT PARAMETERS

    alphaBase(g)[p] = def.pointee.alpha
    scaleBase(g)[p] = def.pointee.scale
    coordBase(g)[p] = def.pointee.where.pointee
    deltaBase(g)[p] = def.pointee.delta.pointee
    rotZBase(g)[p] = def.pointee.rotZ
    rotDZBase(g)[p] = def.pointee.rotDZ
    isUsed[p] = 1

    return 0
}

// MARK: - Set which panes to draw the particle group in

func SetParticleGroupVisiblePanes(_ group: Int16, _ visibleForPlayer1: Bool, _ visibleForPlayer2: Bool) {
    SwGameAssertMessage(group >= 0 && group < Int16(MAX_PARTICLE_GROUPS), "Illegal group #")

    if let g = gParticleGroups[Int(group)] {
        g.pointee.visibleForPlayer1 = visibleForPlayer1
        g.pointee.visibleForPlayer2 = visibleForPlayer2
    }
}

// MARK: - Move particle groups

private let cMoveParticleGroups: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }
    let fps = gFramesPerSecondFrac

    // FIRST UPDATE THE PURGE QUEUE

    purgePendingParticleGroups(false)

    // GET VAR BUFFER & UPDATE PARTICLES

    let buffNum = Int(gGameViewInfoPtr!.pointee.frameCount & 1) // which VAR buffer to use?

    let varMode = UInt8(VertexArrayRangeType.particles1.rawValue) + UInt8(buffNum) // update the VAR range info
    theNode.pointee.VertexArrayMode = varMode

    for i in 0..<Int(MAX_PARTICLE_GROUPS) {
        guard let group = gParticleGroups[i] else { continue }

        if group.isInPurgeQueue { // is this particle group pending purging?
            continue
        }

        OGL_SetVertexArrayRangeDirty(Int16(varMode)) // VAR is being updated

        let baseScale = group.pointee.baseScale // get base scale
        let oneOverBaseScaleSquared = 1.0 / (baseScale * baseScale)
        let gravity = group.pointee.gravity // get gravity
        let decayRate = group.pointee.decayRate // get decay rate
        let fadeRate = group.pointee.fadeRate // get fade rate
        let magnetism = group.pointee.magnetism // get magnetism
        let flags = group.pointee.flags

        let isUsed = isUsedBase(group)
        let coord = coordBase(group)
        let delta = deltaBase(group)
        let rotZ = rotZBase(group)
        let rotDZ = rotDZBase(group)
        let scale = scaleBase(group)
        let alpha = alphaBase(group)

        var n = 0 // init counter
        for p in 0..<Int(MAX_PARTICLES) {
            if isUsed[p] == 0 { // make sure this particle is used
                continue
            }

            n += 1 // inc counter

            // ADD GRAVITY

            delta[p].y -= gravity * fps // add gravity

            // DO ROTATION

            rotZ[p] += rotDZ[p] * fps

            switch group.particleType {
            // FALLING SPARKS
            case .fallingSparks:
                coord[p].x += delta[p].x * fps // move it
                coord[p].y += delta[p].y * fps
                coord[p].z += delta[p].z * fps

            // GRAVITOIDS
            //
            // Every particle has gravity pull on other particle
            case .gravitoids:
                for j in stride(from: Int(MAX_PARTICLES) - 1, through: 0, by: -1) {
                    if p == j { // dont check against self
                        continue
                    }
                    if isUsed[j] == 0 { // make sure this particle is used
                        continue
                    }

                    let x = coord[j].x
                    let y = coord[j].y
                    let z = coord[j].z

                    // calc 1/(dist2)

                    var dist: Float
                    if i < j { // see if calc or get from buffer
                        var temp = coord[p].x - x // dx squared
                        dist = temp * temp
                        temp = coord[p].y - y // dy squared
                        dist += temp * temp
                        temp = coord[p].z - z // dz squared
                        dist += temp * temp

                        dist = dist.squareRoot() // 1/dist2
                        if dist != 0.0 {
                            dist = 1.0 / (dist * dist)
                        }

                        if dist > oneOverBaseScaleSquared { // adjust if closer than radius
                            dist = oneOverBaseScaleSquared
                        }

                        gGravitoidDistBuffer[i][j] = dist // remember it
                    } else {
                        dist = gGravitoidDistBuffer[j][i] // use from buffer
                    }

                    // calc vector to particle

                    var v = OGLVector3D()
                    if dist != 0.0 {
                        let vx = x - coord[p].x
                        let vy = y - coord[p].y
                        let vz = z - coord[p].z
                        FastNormalizeVector(vx, vy, vz, &v)
                    } else {
                        v.x = 0
                        v.y = 0
                        v.z = 0
                    }

                    delta[p].x += v.x * (dist * magnetism * fps) // apply gravity to particle
                    delta[p].y += v.y * (dist * magnetism * fps)
                    delta[p].z += v.z * (dist * magnetism * fps)
                }

                coord[p].x += delta[p].x * fps // move it
                coord[p].y += delta[p].y * fps
                coord[p].z += delta[p].z * fps

            default:
                break
            }

            // SEE IF HAS MAX Y

            if flags & UInt32(PARTICLE_FLAGS_HASMAXY) != 0 {
                if coord[p].y > group.pointee.maxY {
                    isUsed[p] = 0
                }
            }

            // SEE IF BOUNCE

            if flags & UInt32(PARTICLE_FLAGS_DONTCHECKGROUND) == 0 {
                let y = GetTerrainY(coord[p].x, coord[p].z) + 10.0 // get terrain coord at particle x/z

                if flags & UInt32(PARTICLE_FLAGS_BOUNCE) != 0 {
                    if delta[p].y < 0.0 { // if moving down, see if hit floor
                        if coord[p].y < y {
                            coord[p].y = y
                            delta[p].y *= -0.4

                            delta[p].x += gRecentTerrainNormal.x * 300.0 // reflect off of surface
                            delta[p].z += gRecentTerrainNormal.z * 300.0

                            if flags & UInt32(PARTICLE_FLAGS_DISPERSEIFBOUNCE) != 0 { // see if disperse on impact
                                delta[p].y *= 0.4
                                delta[p].x *= 5.0
                                delta[p].z *= 5.0
                            }
                        }
                    }
                }

                // SEE IF GONE
                else {
                    if coord[p].y < y { // if hit floor then nuke particle
                        isUsed[p] = 0
                    }
                }
            }

            // DO SCALE

            scale[p] -= decayRate * fps // shrink it
            if scale[p] <= 0.0 { // see if gone
                isUsed[p] = 0
            }

            // DO FADE

            alpha[p] -= fadeRate * fps // fade it
            if alpha[p] <= 0.0 { // see if gone
                isUsed[p] = 0
            }
        }

        // SEE IF GROUP WAS EMPTY, THEN DELETE

        if n == 0 {
            deleteParticleGroup(i)
        }
    }

    // UPDATE ALL PARTICLE GROUPS GEOMETRY

    updateParticleGroupsGeometry()
}

// MARK: - Update particle groups geometry

private func updateParticleGroupsGeometry() {
    var v = [OGLPoint3D](repeating: OGLPoint3D(), count: 4)

    let buffNum = Int(gGameViewInfoPtr!.pointee.frameCount & 1) // which VAR buffer to use?

    v[0].z = 0 // init z's to 0
    v[1].z = 0
    v[2].z = 0
    v[3].z = 0

    // BUILD GEOMETRY FOR EACH PLAYER'S PANE

    for paneNum in 0..<Int(gNumPlayers) {
        // GET CAMERA INFO FOR THIS PANE

        let camCoords = cameraPlacementsBase()[paneNum].cameraLocation

        // UPDATE EACH PARTICLE GROUP

        for g in 0..<Int(MAX_PARTICLE_GROUPS) {
            guard let group = gParticleGroups[g] else { continue }

            if group.isInPurgeQueue { // skip if it's in the purge queue
                continue
            }

            let allAim = group.pointee.flags & UInt32(PARTICLE_FLAGS_ALLAIM)

            let geoData = geometryObj(group, buffNum, paneNum)! // get pointer to geometry object data
            let vertexColors = geoData.colorsFloat! // get pointer to vertex color array
            let baseScale = group.pointee.baseScale // get base scale

            // ADD ALL PARTICLES TO TRIMESH

            var minX: Float = 100_000_000, minY: Float = 100_000_000, minZ: Float = 100_000_000 // init bbox
            var maxX = -minX, maxY = -minY, maxZ = -minZ

            var n = 0
            let isUsed = isUsedBase(group)
            let coord = coordBase(group)
            let rotZ = rotZBase(group)
            let scaleArr = scaleBase(group)
            let alpha = alphaBase(group)
            let points = geoData.points!

            // Rotation/scale submatrix is only recomputed for the 1st particle (or if allAim);
            // subsequent particles reuse it and just patch in the translation. Must be declared
            // outside the loop so it persists across iterations - matching the original C, which
            // relied on an uninitialized stack local implicitly keeping its value between iterations.
            var m = OGLMatrix4x4()

            for p in 0..<Int(MAX_PARTICLES) {
                if isUsed[p] == 0 { // make sure this particle is used
                    continue
                }

                // CREATE VERTEX DATA

                let scale = scaleArr[p] * baseScale

                v[0].x = -scale
                v[0].y = scale

                v[1].x = -scale
                v[1].y = -scale

                v[2].x = scale
                v[2].y = -scale

                v[3].x = scale
                v[3].y = scale

                // TRANSFORM THIS PARTICLE'S VERTICES & ADD TO TRIMESH

                if (n == 0) || (allAim != 0) { // only set the look-at matrix for the 1st particle unless we want to force it for all (optimization technique)
                    let up = OGLVector3D(x: 0, y: 1, z: 0)
                    withUnsafePointer(to: up) { upPtr in
                        withUnsafePointer(to: camCoords) { camPtr in
                            SetLookAtMatrixAndTranslate(&m, upPtr, &coord[p], camPtr) // aim at camera & translate
                        }
                    }
                } else {
                    m.value.12 = coord[p].x // update just the translate
                    m.value.13 = coord[p].y
                    m.value.14 = coord[p].z
                }

                let rot = rotZ[p] // get z rotation
                if rot != 0.0 { // see if need to apply rotation matrix
                    var rm = OGLMatrix4x4()

                    rm.setRotateZ(rot)
                    var rmResult = OGLMatrix4x4()
                    rmResult = rm.multiplied(by: m)
                    rm = rmResult
                    v.withUnsafeMutableBufferPointer { vBuf in
                        OGLPoint3D.transformArray(vBuf.baseAddress, by: rm, into: points + n * 4, count: 4) // transform w/ rot
                    }
                } else {
                    v.withUnsafeMutableBufferPointer { vBuf in
                        OGLPoint3D.transformArray(vBuf.baseAddress, by: m, into: points + n * 4, count: 4) // transform no-rot
                    }
                }

                // UPDATE BBOX

                for i in 0..<4 {
                    let j = n * 4 + i

                    if points[j].x < minX { minX = points[j].x }
                    if points[j].x > maxX { maxX = points[j].x }
                    if points[j].y < minY { minY = points[j].y }
                    if points[j].y > maxY { maxY = points[j].y }
                    if points[j].z < minZ { minZ = points[j].z }
                    if points[j].z > maxZ { maxZ = points[j].z }
                }

                // UPDATE COLOR/TRANSPARENCY

                let temp = n * 4
                for i in temp..<(temp + 4) {
                    vertexColors[i].r = 1.0
                    vertexColors[i].g = 1.0
                    vertexColors[i].b = 1.0
                    vertexColors[i].a = alpha[p] // set transparency alpha
                }

                n += 1 // inc particle count
            }

            if n == 0 { // if no particles, then skip
                continue
            }

            // UPDATE FINAL VALUES

            geoData.numTriangles = Int32(n * 2)
            geoData.numPoints = Int32(n * 4)

            // SET BBOX FOR CULLING DURING DRAW

            group.pointee.bbox.min.x = minX // build bbox for culling test
            group.pointee.bbox.min.y = minY
            group.pointee.bbox.min.z = minZ
            group.pointee.bbox.max.x = maxX
            group.pointee.bbox.max.y = maxY
            group.pointee.bbox.max.z = maxZ

            // group.pointee.isCulled[paneNum] = !OGL_IsBBoxVisible(&bbox, nil)
        }
    } // for paneNum
}

@inline(__always) private func cameraPlacementsBase() -> UnsafeMutablePointer<OGLCameraPlacement> {
    UnsafeMutableRawPointer(gGameViewInfoPtr!.pointer(to: \.cameraPlacement)!).assumingMemoryBound(to: OGLCameraPlacement.self)
}

// MARK: - Draw particle groups

private let cDrawParticleGroups: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { _ in
    let paneNum = Int(gCurrentSplitScreenPane)

    // DRAW SOME OTHER GOODIES WHILE WE'RE HERE

    DrawSparkles() // draw light sparkles

    // SETUP ENVIRONTMENT

    OGL_PushState()
    OGL_EnableBlend()
    OGL_SetColor4f(1, 1, 1, 1) // full white & alpha to start with

    let buffNum = Int(gGameViewInfoPtr!.pointee.frameCount & 1) // which VAR buffer to use?

    for g in 0..<Int(MAX_PARTICLE_GROUPS) {
        guard let pg = gParticleGroups[g] else { // skip if not allocated
            continue
        }

        if pg.isInPurgeQueue // skip if it's in the purge queue
            || OGL_IsBBoxVisible(&pg.pointee.bbox, nil) == 0 // skip if culled
            || (paneNum == 0 && !pg.pointee.visibleForPlayer1) // skip if hidden for this pane
            || (paneNum == 1 && !pg.pointee.visibleForPlayer2) { // skip if hidden for this pane
            continue
        }

        // DRAW IT

        let src = GLenum(pg.pointee.srcBlend)
        let dst = GLenum(pg.pointee.dstBlend)
        OGL_BlendFunc(src, dst) // set blending mode

        MO_DrawObject(UnsafeMutableRawPointer(geometryObj(pg, buffNum, paneNum))) // draw geometry
    }

    // RESTORE MODES

    OGL_PopState()
    OGL_SetColor4f(1, 1, 1, 1) // reset this
}

// MARK: -

// MARK: - Verify particle group magic num

func VerifyParticleGroupMagicNum(_ group: Int16, _ magicNum: UInt32) -> UInt8 {
    guard let g = gParticleGroups[Int(group)] else {
        return 0
    }

    if g.pointee.magicNum != magicNum {
        return 0
    }

    return 1
}

// MARK: - Particle hit object

// INPUT:	inFlags = flags to check particle types against
func ParticleHitObject(_ theNode: UnsafeMutablePointer<ObjNode>!, _ inFlags: UInt16) -> UInt8 {
    for i in 0..<Int(MAX_PARTICLE_GROUPS) {
        guard let group = gParticleGroups[i] else { // see if group active
            continue
        }

        if inFlags != 0 { // see if check flags
            let flags = group.pointee.flags
            if UInt32(inFlags) & flags == 0 {
                continue
            }
        }

        let isUsed = isUsedBase(group)
        let alpha = alphaBase(group)
        let coord = coordBase(group)

        for p in 0..<Int(MAX_PARTICLES) {
            if isUsed[p] == 0 { // make sure this particle is used
                continue
            }

            if alpha[p] < 0.4 { // if particle is too decayed, then skip
                continue
            }

            if DoSimpleBoxCollisionAgainstObject(coord[p].y + 40.0, coord[p].y - 40.0,
                                                  coord[p].x - 40.0, coord[p].x + 40.0,
                                                  coord[p].z + 40.0, coord[p].z - 40.0,
                                                  theNode) != 0 {
                return 1
            }
        }
    }
    return 0
}

// MARK: -

// MARK: - Make puff

func MakePuff(_ numPuffs: Int16, _ where_: UnsafeMutablePointer<OGLPoint3D>!, _ scale: Float, _ texNum: Int16, _ src: Int32, _ dst: Int32, _ decayRate: Float) {
    // white sparks

    gNewParticleGroupDef.magicNum = 0
    gNewParticleGroupDef.particleType = .fallingSparks
    gNewParticleGroupDef.flags = UInt32(PARTICLE_FLAGS_BOUNCE | PARTICLE_FLAGS_ALLAIM)
    gNewParticleGroupDef.gravity = -80
    gNewParticleGroupDef.magnetism = 0
    gNewParticleGroupDef.baseScale = scale
    gNewParticleGroupDef.decayRate = -1.6
    gNewParticleGroupDef.fadeRate = decayRate
    gNewParticleGroupDef.particleTextureNum = UInt8(texNum)
    gNewParticleGroupDef.srcBlend = src
    gNewParticleGroupDef.dstBlend = dst

    let pg = NewParticleGroup(&gNewParticleGroupDef)
    if pg != -1 {
        let x = where_.pointee.x
        let y = where_.pointee.y
        let z = where_.pointee.z

        for _ in 0..<numPuffs {
            var pt = OGLPoint3D()
            pt.x = x + RandomFloat2() * (2.0 * scale)
            pt.y = y + RandomFloat() * 2.0 * scale
            pt.z = z + RandomFloat2() * (2.0 * scale)

            var delta = OGLVector3D()
            delta.x = RandomFloat2() * (3.0 * scale)
            delta.y = RandomFloat() * (2.0 * scale)
            delta.z = RandomFloat2() * (3.0 * scale)

            var newParticleDef = NewParticleDefType()
            newParticleDef.groupNum = pg
            newParticleDef.scale = 1.0 + RandomFloat2() * 0.2
            newParticleDef.rotZ = RandomFloat() * SwPI2
            newParticleDef.rotDZ = RandomFloat2() * 4.0
            newParticleDef.alpha = Float(FULL_ALPHA)

            withUnsafeMutablePointer(to: &pt) { ptPtr in
                withUnsafeMutablePointer(to: &delta) { deltaPtr in
                    newParticleDef.where = ptPtr
                    newParticleDef.delta = deltaPtr
                    AddParticleToGroup(&newParticleDef)
                }
            }
        }
    }
}

// MARK: - Make spark explosion

func MakeSparkExplosion(_ coord: UnsafePointer<OGLPoint3D>!, _ force: Float, _ scale: Float, _ sparkTexture: Int16, _ quantityLimit: Int16, _ fadeRate: Float) {
    let x = coord.pointee.x
    let y = coord.pointee.y
    let z = coord.pointee.z

    var n = Int(force * 0.3)

    if quantityLimit != 0 {
        if n > Int(quantityLimit) {
            n = Int(quantityLimit)
        }
    }

    // white sparks

    gNewParticleGroupDef.magicNum = 0
    gNewParticleGroupDef.particleType = .fallingSparks
    gNewParticleGroupDef.flags = UInt32(PARTICLE_FLAGS_BOUNCE)
    gNewParticleGroupDef.gravity = 200
    gNewParticleGroupDef.magnetism = 0
    gNewParticleGroupDef.baseScale = 15.0 * scale
    gNewParticleGroupDef.decayRate = 0
    gNewParticleGroupDef.fadeRate = fadeRate
    gNewParticleGroupDef.particleTextureNum = UInt8(sparkTexture)
    gNewParticleGroupDef.srcBlend = GL_SRC_ALPHA
    gNewParticleGroupDef.dstBlend = GL_ONE

    let pg = NewParticleGroup(&gNewParticleGroupDef)
    if pg != -1 {
        for _ in 0..<n {
            var pt = OGLPoint3D()
            pt.x = x + RandomFloat2() * (30.0 * scale)
            pt.y = y + RandomFloat2() * (30.0 * scale)
            pt.z = z + RandomFloat2() * (30.0 * scale)

            var v = OGLVector3D()
            v.x = pt.x - x
            v.y = pt.y - y
            v.z = pt.z - z
            FastNormalizeVector(v.x, v.y, v.z, &v)

            var delta = OGLVector3D()
            delta.x = v.x * (force * scale)
            delta.y = v.y * (force * scale)
            delta.z = v.z * (force * scale)

            var newParticleDef = NewParticleDefType()
            newParticleDef.groupNum = pg
            newParticleDef.scale = 1.0 + RandomFloat() * 0.5
            newParticleDef.rotZ = 0
            newParticleDef.rotDZ = 0
            newParticleDef.alpha = Float(FULL_ALPHA)

            let stop: Bool = withUnsafeMutablePointer(to: &pt) { ptPtr in
                withUnsafeMutablePointer(to: &delta) { deltaPtr in
                    newParticleDef.where = ptPtr
                    newParticleDef.delta = deltaPtr
                    return AddParticleToGroup(&newParticleDef) != 0
                }
            }
            if stop {
                break
            }
        }
    }
}

// MARK: - Make steam

func MakeSteam(_ theNode: UnsafeMutablePointer<ObjNode>!, _ x: Float, _ y: Float, _ z: Float) {
    let fps = gFramesPerSecondFrac
    let scale: Float = 1.8

    // MAKE SMOKE

    theNode.pointee.ParticleTimer -= fps // see if add smoke
    if theNode.pointee.ParticleTimer <= 0.0 {
        theNode.pointee.ParticleTimer += 0.05 // reset timer

        var particleGroup = theNode.pointee.ParticleGroup
        let magicNum = theNode.pointee.ParticleMagicNum

        if (particleGroup == -1) || (VerifyParticleGroupMagicNum(particleGroup, magicNum) == 0) {
            let newMagicNum = MyRandomLong()
            theNode.pointee.ParticleMagicNum = newMagicNum

            var groupDef = NewParticleGroupDefType()
            groupDef.magicNum = newMagicNum
            groupDef.particleType = .fallingSparks
            groupDef.flags = UInt32(PARTICLE_FLAGS_DONTCHECKGROUND)
            groupDef.gravity = 0
            groupDef.magnetism = 0
            groupDef.baseScale = 20.0 * scale
            groupDef.decayRate = -0.2
            groupDef.fadeRate = 0.2
            groupDef.particleTextureNum = UInt8(PARTICLE_SObjType_GreySmoke)
            groupDef.srcBlend = GL_SRC_ALPHA
            groupDef.dstBlend = GL_ONE_MINUS_SRC_ALPHA
            particleGroup = NewParticleGroup(&groupDef)
            theNode.pointee.ParticleGroup = particleGroup
        }

        if particleGroup != -1 {
            for _ in 0..<2 {
                var p = OGLPoint3D()
                p.x = x + RandomFloat2() * (40.0 * scale)
                p.y = y + RandomFloat() * (50.0 * scale)
                p.z = z + RandomFloat2() * (40.0 * scale)

                var d = OGLVector3D()
                d.x = RandomFloat2() * (20.0 * scale)
                d.y = 150.0 + RandomFloat() * (40.0 * scale)
                d.z = RandomFloat2() * (20.0 * scale)

                var newParticleDef = NewParticleDefType()
                newParticleDef.groupNum = particleGroup
                newParticleDef.scale = RandomFloat() + 1.0
                newParticleDef.rotZ = RandomFloat() * SwPI2
                newParticleDef.rotDZ = RandomFloat2()
                newParticleDef.alpha = 0.7

                let stop: Bool = withUnsafeMutablePointer(to: &p) { pPtr in
                    withUnsafeMutablePointer(to: &d) { dPtr in
                        newParticleDef.where = pPtr
                        newParticleDef.delta = dPtr
                        return AddParticleToGroup(&newParticleDef) != 0
                    }
                }
                if stop {
                    theNode.pointee.ParticleGroup = -1
                    break
                }
            }
        }
    }
}

// MARK: -

// MARK: - Make bomb explosion

func MakeBombExplosion(_ x: Float, _ z: Float, _ delta: UnsafeMutablePointer<OGLVector3D>!) {
    var where_ = OGLPoint3D()
    where_.x = x
    where_.z = z
    where_.y = GetTerrainY(x, z)

    // FIRST MAKE SPARKS

    gNewParticleGroupDef.magicNum = 0
    gNewParticleGroupDef.particleType = .fallingSparks
    gNewParticleGroupDef.flags = UInt32(PARTICLE_FLAGS_BOUNCE)
    gNewParticleGroupDef.gravity = 900
    gNewParticleGroupDef.magnetism = 0
    gNewParticleGroupDef.baseScale = 190
    gNewParticleGroupDef.decayRate = 0.4
    gNewParticleGroupDef.fadeRate = 0.7
    gNewParticleGroupDef.particleTextureNum = UInt8(PARTICLE_SObjType_WhiteSpark3)
    gNewParticleGroupDef.srcBlend = GL_SRC_ALPHA
    gNewParticleGroupDef.dstBlend = GL_ONE
    let pg = NewParticleGroup(&gNewParticleGroupDef)
    if pg != -1 {
        let px = where_.x
        let py = where_.y
        let pz = where_.z
        let dx = delta.pointee.x * 0.2
        let dz = delta.pointee.z * 0.2

        for _ in 0..<20 {
            var pt = OGLPoint3D()
            pt.x = px + (RandomFloat() - 0.5) * 200.0
            pt.y = py + RandomFloat() * 60.0
            pt.z = pz + (RandomFloat() - 0.5) * 200.0

            var d = OGLVector3D()
            d.y = RandomFloat() * 1500.0
            d.x = (RandomFloat() - 0.5) * d.y * 3.0 + dx
            d.z = (RandomFloat() - 0.5) * d.y * 3.0 + dz

            var newParticleDef = NewParticleDefType()
            newParticleDef.groupNum = pg
            newParticleDef.scale = RandomFloat() + 1.5
            newParticleDef.rotZ = 0
            newParticleDef.rotDZ = 0
            newParticleDef.alpha = Float(FULL_ALPHA) + (RandomFloat() * 0.3)

            withUnsafeMutablePointer(to: &pt) { ptPtr in
                withUnsafeMutablePointer(to: &d) { dPtr in
                    newParticleDef.where = ptPtr
                    newParticleDef.delta = dPtr
                    AddParticleToGroup(&newParticleDef)
                }
            }
        }
    }
}

// MARK: -

// MARK: - Make splash

func MakeSplash(_ where_: UnsafeMutablePointer<OGLPoint3D>!, _ scale: Float) {
    let x = where_.pointee.x
    let z = where_.pointee.z
    var pt = OGLPoint3D()
    pt.y = where_.pointee.y

    gNewParticleGroupDef.magicNum = 0
    gNewParticleGroupDef.particleType = .fallingSparks
    gNewParticleGroupDef.flags = UInt32(PARTICLE_FLAGS_ALLAIM)
    gNewParticleGroupDef.gravity = 400
    gNewParticleGroupDef.magnetism = 0
    gNewParticleGroupDef.baseScale = 15.0 * scale
    gNewParticleGroupDef.decayRate = -0.6
    gNewParticleGroupDef.fadeRate = 0.8
    gNewParticleGroupDef.particleTextureNum = UInt8(PARTICLE_SObjType_Splash)
    gNewParticleGroupDef.srcBlend = GL_SRC_ALPHA
    gNewParticleGroupDef.dstBlend = GL_ONE

    let pg = NewParticleGroup(&gNewParticleGroupDef)
    if pg != -1 {
        for _ in 0..<30 {
            pt.x = x + RandomFloat2() * (30.0 * scale)
            pt.z = z + RandomFloat2() * (30.0 * scale)

            var delta = OGLVector3D()
            delta.x = RandomFloat2() * (200.0 * scale)
            delta.y = RandomFloat() * (150.0 * scale)
            delta.z = RandomFloat2() * (200.0 * scale)

            var newParticleDef = NewParticleDefType()
            newParticleDef.groupNum = pg
            newParticleDef.scale = RandomFloat() + 1.0
            newParticleDef.rotZ = 0
            newParticleDef.rotDZ = RandomFloat2() * SwPI2
            newParticleDef.alpha = Float(FULL_ALPHA)

            withUnsafeMutablePointer(to: &pt) { ptPtr in
                withUnsafeMutablePointer(to: &delta) { deltaPtr in
                    newParticleDef.where = ptPtr
                    newParticleDef.delta = deltaPtr
                    AddParticleToGroup(&newParticleDef)
                }
            }
        }
    }

    // MAKE RIPPLE

    CreateNewRipple(where_, 25.0, 150.0, 0.5)

    // PLAY SPLASH SOUND

    PlayEffect_Parms3D(Int16(EFFECT_SPLASH), where_, UInt32(NORMAL_CHANNEL_RATE), 1.5)
}

// MARK: - Spray water

func SprayWater(_ theNode: UnsafeMutablePointer<ObjNode>!, _ x: Float, _ y: Float, _ z: Float) {
    let fps = gFramesPerSecondFrac

    theNode.pointee.ParticleTimer -= fps // see if time to spew water
    if theNode.pointee.ParticleTimer <= 0.0 {
        theNode.pointee.ParticleTimer += 0.05

        var particleGroup = theNode.pointee.Special.5 // SmokeParticleGroup
        let magicNum = UInt32(theNode.pointee.Special.4) // SmokeParticleMagic

        if (particleGroup == -1) || (VerifyParticleGroupMagicNum(Int16(particleGroup), magicNum) == 0) {
            let newMagicNum = MyRandomLong()
            theNode.pointee.Special.4 = Int(newMagicNum) // SmokeParticleMagic

            gNewParticleGroupDef.magicNum = newMagicNum
            gNewParticleGroupDef.particleType = .fallingSparks
            gNewParticleGroupDef.flags = 0
            gNewParticleGroupDef.gravity = 800
            gNewParticleGroupDef.magnetism = 0
            gNewParticleGroupDef.baseScale = 10
            gNewParticleGroupDef.decayRate = -1.7
            gNewParticleGroupDef.fadeRate = 1.5
            gNewParticleGroupDef.particleTextureNum = UInt8(PARTICLE_SObjType_Splash)
            gNewParticleGroupDef.srcBlend = GL_SRC_ALPHA
            gNewParticleGroupDef.dstBlend = GL_ONE
            particleGroup = Int(NewParticleGroup(&gNewParticleGroupDef))
            theNode.pointee.Special.5 = particleGroup // SmokeParticleGroup
        }

        // ADD PARTICLE TO GROUP

        if particleGroup != -1 {
            for _ in 0..<6 {
                var delta = OGLVector3D()
                delta.x = theNode.pointee.MotionVector.x * 200.0
                delta.y = theNode.pointee.MotionVector.y * 200.0
                delta.z = theNode.pointee.MotionVector.z * 200.0

                delta.x += RandomFloat2() * 40.0 // spray delta
                delta.z += RandomFloat2() * 40.0
                delta.y = 200.0 + RandomFloat() * 200.0

                var pt = OGLPoint3D()
                pt.x = x + RandomFloat2() * 20.0 // random noise to coord
                pt.y = y
                pt.z = z + RandomFloat2() * 20.0

                var newParticleDef = NewParticleDefType()
                newParticleDef.groupNum = Int16(particleGroup)
                newParticleDef.scale = 1.0 + RandomFloat() * 0.5
                newParticleDef.rotZ = 0
                newParticleDef.rotDZ = 0
                newParticleDef.alpha = Float(FULL_ALPHA)

                let stop: Bool = withUnsafeMutablePointer(to: &pt) { ptPtr in
                    withUnsafeMutablePointer(to: &delta) { deltaPtr in
                        newParticleDef.where = ptPtr
                        newParticleDef.delta = deltaPtr
                        return AddParticleToGroup(&newParticleDef) != 0
                    }
                }
                if stop {
                    break
                }
            }
        }
    }
}

// MARK: -

// MARK: - Burn fire

func BurnFire(_ theNode: UnsafeMutablePointer<ObjNode>!, _ x: Float, _ y: Float, _ z: Float, _ doSmoke: UInt8, _ particleType: Int16, _ scale: Float, _ moreFlags: UInt32) {
    let fps = gFramesPerSecondFrac

    // MAKE SMOKE

    if doSmoke != 0 && (gFramesPerSecond > 20.0) { // only do smoke if running at good frame rate
        theNode.pointee.SpecialF.4 -= fps // SmokeTimer: see if add smoke
        if theNode.pointee.SpecialF.4 <= 0.0 {
            theNode.pointee.SpecialF.4 += smokeTimer // reset timer

            var particleGroup = Int16(theNode.pointee.Special.5) // SmokeParticleGroup
            let magicNum = UInt32(theNode.pointee.Special.4) // SmokeParticleMagic

            if (particleGroup == -1) || (VerifyParticleGroupMagicNum(particleGroup, magicNum) == 0) {
                let newMagicNum = MyRandomLong()
                theNode.pointee.Special.4 = Int(newMagicNum) // SmokeParticleMagic

                var groupDef = NewParticleGroupDefType()
                groupDef.magicNum = newMagicNum
                groupDef.particleType = .fallingSparks
                groupDef.flags = UInt32(PARTICLE_FLAGS_DONTCHECKGROUND) | moreFlags
                groupDef.gravity = 0
                groupDef.magnetism = 0
                groupDef.baseScale = 20.0 * scale
                groupDef.decayRate = -0.2
                groupDef.fadeRate = 0.2
                groupDef.particleTextureNum = UInt8(PARTICLE_SObjType_BlackSmoke)
                groupDef.srcBlend = GL_SRC_ALPHA
                groupDef.dstBlend = GL_ONE_MINUS_SRC_ALPHA
                particleGroup = NewParticleGroup(&groupDef)
                theNode.pointee.Special.5 = Int(particleGroup) // SmokeParticleGroup
            }

            if particleGroup != -1 {
                for _ in 0..<3 {
                    var p = OGLPoint3D()
                    p.x = x + RandomFloat2() * (40.0 * scale)
                    p.y = y + 200.0 + RandomFloat() * (50.0 * scale)
                    p.z = z + RandomFloat2() * (40.0 * scale)

                    var d = OGLVector3D()
                    d.x = RandomFloat2() * (20.0 * scale)
                    d.y = 150.0 + RandomFloat() * (40.0 * scale)
                    d.z = RandomFloat2() * (20.0 * scale)

                    var newParticleDef = NewParticleDefType()
                    newParticleDef.groupNum = particleGroup
                    newParticleDef.scale = RandomFloat() + 1.0
                    newParticleDef.rotZ = RandomFloat() * SwPI2
                    newParticleDef.rotDZ = RandomFloat2()
                    newParticleDef.alpha = 0.7

                    let stop: Bool = withUnsafeMutablePointer(to: &p) { pPtr in
                        withUnsafeMutablePointer(to: &d) { dPtr in
                            newParticleDef.where = pPtr
                            newParticleDef.delta = dPtr
                            return AddParticleToGroup(&newParticleDef) != 0
                        }
                    }
                    if stop {
                        theNode.pointee.Special.5 = -1 // SmokeParticleGroup
                        break
                    }
                }
            }
        }
    }

    // MAKE FIRE

    theNode.pointee.SpecialF.5 -= fps // FireTimer: see if add fire
    if theNode.pointee.SpecialF.5 <= 0.0 {
        theNode.pointee.SpecialF.5 += fireTimer // reset timer

        var particleGroup = theNode.pointee.ParticleGroup
        let magicNum = theNode.pointee.ParticleMagicNum

        if (particleGroup == -1) || (VerifyParticleGroupMagicNum(particleGroup, magicNum) == 0) {
            let newMagicNum = MyRandomLong()
            theNode.pointee.ParticleMagicNum = newMagicNum

            var groupDef = NewParticleGroupDefType()
            groupDef.magicNum = newMagicNum
            groupDef.particleType = .fallingSparks
            groupDef.flags = UInt32(PARTICLE_FLAGS_DONTCHECKGROUND) | moreFlags
            groupDef.gravity = -200
            groupDef.magnetism = 0
            groupDef.baseScale = 30.0 * scale
            groupDef.decayRate = 0
            groupDef.fadeRate = 0.8
            groupDef.particleTextureNum = UInt8(particleType)
            groupDef.srcBlend = GL_SRC_ALPHA
            groupDef.dstBlend = GL_ONE
            particleGroup = NewParticleGroup(&groupDef)
            theNode.pointee.ParticleGroup = particleGroup
        }

        if particleGroup != -1 {
            for _ in 0..<3 {
                var p = OGLPoint3D()
                p.x = x + RandomFloat2() * (30.0 * scale)
                p.y = y + RandomFloat() * (50.0 * scale)
                p.z = z + RandomFloat2() * (30.0 * scale)

                var d = OGLVector3D()
                d.x = RandomFloat2() * (50.0 * scale)
                d.y = 50.0 + RandomFloat() * (60.0 * scale)
                d.z = RandomFloat2() * (50.0 * scale)

                var newParticleDef = NewParticleDefType()
                newParticleDef.groupNum = particleGroup
                newParticleDef.scale = RandomFloat() + 1.0
                newParticleDef.rotZ = RandomFloat() * SwPI2
                newParticleDef.rotDZ = RandomFloat2()
                newParticleDef.alpha = 1.0

                let stop: Bool = withUnsafeMutablePointer(to: &p) { pPtr in
                    withUnsafeMutablePointer(to: &d) { dPtr in
                        newParticleDef.where = pPtr
                        newParticleDef.delta = dPtr
                        return AddParticleToGroup(&newParticleDef) != 0
                    }
                }
                if stop {
                    theNode.pointee.ParticleGroup = -1
                    break
                }
            }
        }
    }
}

// MARK: -

// MARK: - Make fire explosion

func MakeFireExplosion(_ where_: UnsafeMutablePointer<OGLPoint3D>!) {
    // FIRST MAKE FLAMES

    gNewParticleGroupDef.magicNum = 0
    gNewParticleGroupDef.particleType = .fallingSparks
    gNewParticleGroupDef.flags = UInt32(PARTICLE_FLAGS_BOUNCE)
    gNewParticleGroupDef.gravity = -120
    gNewParticleGroupDef.magnetism = 0
    gNewParticleGroupDef.baseScale = 18
    gNewParticleGroupDef.decayRate = -1.0
    gNewParticleGroupDef.fadeRate = 1.0
    gNewParticleGroupDef.particleTextureNum = UInt8(PARTICLE_SObjType_Fire)
    gNewParticleGroupDef.srcBlend = GL_SRC_ALPHA
    gNewParticleGroupDef.dstBlend = GL_ONE
    let pg = NewParticleGroup(&gNewParticleGroupDef)
    if pg != -1 {
        let x = where_.pointee.x
        let y = where_.pointee.y
        let z = where_.pointee.z

        for _ in 0..<150 {
            var pt = OGLPoint3D()
            pt.x = x + RandomFloat2() * 20.0
            pt.y = y + RandomFloat2() * 20.0
            pt.z = z + RandomFloat2() * 20.0

            var d = OGLVector3D()
            d.y = RandomFloat2() * 300.0
            d.x = RandomFloat2() * 350.0
            d.z = RandomFloat2() * 350.0

            var newParticleDef = NewParticleDefType()
            newParticleDef.groupNum = pg
            newParticleDef.scale = RandomFloat() + 1.0
            newParticleDef.rotZ = 0
            newParticleDef.rotDZ = RandomFloat2() * 10.0
            newParticleDef.alpha = Float(FULL_ALPHA) + (RandomFloat() * 0.3)

            withUnsafeMutablePointer(to: &pt) { ptPtr in
                withUnsafeMutablePointer(to: &d) { dPtr in
                    newParticleDef.where = ptPtr
                    newParticleDef.delta = dPtr
                    AddParticleToGroup(&newParticleDef)
                }
            }
        }
    }
}

// MARK: -

// MARK: - Add smoker

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    @discardableResult
    func addSmoker(x: Float, z: Float) -> UInt8 {
        let newObj = MakeSmoker(x, z, Int32(pointee.parm.0))!
        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        return 1
    }
}

// MARK: - Make smoker

func MakeSmoker(_ x: Float, _ z: Float, _ kind: Int32) -> UnsafeMutablePointer<ObjNode>? {
    var def = NewObjectDefinitionType()
    def.genre = UInt8(EVENT_GENRE)
    def.coord.x = x
    def.coord.z = z
    def.coord.y = FindHighestCollisionAtXZ(x, z, UInt32(CTYPE_TERRAIN | CTYPE_WATER))
    def.flags = UInt32(STATUS_BIT_DONTCULL)
    def.slot = Int16(SLOT_OF_DUMB + 10)
    def.moveCall = cMoveSmoker
    def.scale = 1

    let newObj = MakeNewObject(&def)!
    newObj.pointee.Kind = kind // save smoke kind
    return newObj
}

// MARK: - Move smoker

private let smokerTextures: [Int] = [
    PARTICLE_SObjType_BlackSmoke,
    PARTICLE_SObjType_GreySmoke,
    PARTICLE_SObjType_RedFumes,
    PARTICLE_SObjType_GreenFumes,
]

private let smokerGlow: [Bool] = [false, false, true, true]

private let cMoveSmoker: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }
    let fps = gFramesPerSecondFrac

    // SEE IF OUT OF RANGE

    if TrackTerrainItem(theNode) != 0 { // just check to see if it's gone
        DeleteObject(theNode)
        return
    }

    theNode.pointee.Coord.y = GetTerrainY(theNode.pointee.Coord.x, theNode.pointee.Coord.z) // make sure on ground (for when volcanos grow over it)

    // MAKE SMOKE

    theNode.pointee.Timer -= fps // see if add smoke
    if theNode.pointee.Timer <= 0.0 {
        theNode.pointee.Timer += 0.06 // reset timer

        let smokeType = Int(theNode.pointee.Kind)
        let t = smokerTextures[smokeType] // get texture #

        var particleGroup = theNode.pointee.ParticleGroup
        let magicNum = theNode.pointee.ParticleMagicNum

        if (particleGroup == -1) || (VerifyParticleGroupMagicNum(particleGroup, magicNum) == 0) {
            let newMagicNum = MyRandomLong()
            theNode.pointee.ParticleMagicNum = newMagicNum

            var groupDef = NewParticleGroupDefType()
            groupDef.magicNum = newMagicNum
            groupDef.particleType = .fallingSparks
            groupDef.flags = UInt32(PARTICLE_FLAGS_DONTCHECKGROUND)
            groupDef.gravity = 100
            groupDef.magnetism = 0
            groupDef.baseScale = 25
            groupDef.decayRate = -0.7
            groupDef.fadeRate = 0.3
            groupDef.particleTextureNum = UInt8(t)
            groupDef.srcBlend = GL_SRC_ALPHA
            groupDef.dstBlend = smokerGlow[smokeType] ? GL_ONE : GL_ONE_MINUS_SRC_ALPHA
            particleGroup = NewParticleGroup(&groupDef)
            theNode.pointee.ParticleGroup = particleGroup
        }

        if particleGroup != -1 {
            let x = theNode.pointee.Coord.x
            let y = theNode.pointee.Coord.y
            let z = theNode.pointee.Coord.z

            for _ in 0..<2 {
                var p = OGLPoint3D()
                p.x = x + RandomFloat2() * 50.0
                p.y = y + RandomFloat() * 10.0
                p.z = z + RandomFloat2() * 50.0

                var d = OGLVector3D()
                d.x = RandomFloat2() * 80.0
                d.y = 300.0 + RandomFloat() * 75.0
                d.z = RandomFloat2() * 80.0

                var newParticleDef = NewParticleDefType()
                newParticleDef.groupNum = particleGroup
                newParticleDef.scale = RandomFloat() + 1.0
                newParticleDef.rotZ = RandomFloat() * SwPI2
                newParticleDef.rotDZ = RandomFloat2() * 1.2
                newParticleDef.alpha = 0.8

                let stop: Bool = withUnsafeMutablePointer(to: &p) { pPtr in
                    withUnsafeMutablePointer(to: &d) { dPtr in
                        newParticleDef.where = pPtr
                        newParticleDef.delta = dPtr
                        return AddParticleToGroup(&newParticleDef) != 0
                    }
                }
                if stop {
                    theNode.pointee.ParticleGroup = -1
                    break
                }
            }
        }
    }
}

// MARK: -

// MARK: - Do player ground scrape

func DoPlayerGroundScrape(_ player: UnsafeMutablePointer<ObjNode>!, _ playerNum: Int16) {
    let fps = gFramesPerSecondFrac
    let pi = GetPlayerInfoEntry(Int32(playerNum))

    pi.pointee.dirtParticleTimer -= fps // see if add bubbles
    if pi.pointee.dirtParticleTimer <= 0.0 {
        pi.pointee.dirtParticleTimer += 0.04 // reset timer

        var particleGroup = Int16(pi.pointee.dirtParticleGroup)
        let magicNum = pi.pointee.dirtParticleMagicNum

        if (particleGroup == -1) || (VerifyParticleGroupMagicNum(particleGroup, magicNum) == 0) {
            let newMagicNum = MyRandomLong()
            pi.pointee.dirtParticleMagicNum = newMagicNum

            var groupDef = NewParticleGroupDefType()
            groupDef.magicNum = newMagicNum
            groupDef.particleType = .fallingSparks
            groupDef.flags = UInt32(PARTICLE_FLAGS_BOUNCE | PARTICLE_FLAGS_ALLAIM)
            groupDef.gravity = 1000
            groupDef.magnetism = 0
            groupDef.baseScale = 10
            groupDef.decayRate = -2.0
            groupDef.fadeRate = 1.0
            groupDef.particleTextureNum = UInt8(PARTICLE_SObjType_CokeSpray)
            groupDef.srcBlend = GL_SRC_ALPHA
            groupDef.dstBlend = GL_ONE_MINUS_SRC_ALPHA
            particleGroup = NewParticleGroup(&groupDef)
            pi.pointee.dirtParticleGroup = particleGroup
        }

        if particleGroup != -1 {
            let x = gCoord.x
            let z = gCoord.z
            let y = GetTerrainY(x, z) + 10.0

            for _ in 0..<3 {
                var d = OGLVector3D()
                d.x = RandomFloat2() * 90.0
                d.y = RandomFloat() * 400.0
                d.z = RandomFloat2() * 90.0

                var p = OGLPoint3D()
                p.x = x + RandomFloat2() * 5.0
                p.y = y + RandomFloat() * 5.0
                p.z = z + RandomFloat2() * 5.0

                var newParticleDef = NewParticleDefType()
                newParticleDef.groupNum = particleGroup
                newParticleDef.scale = 1.0 + RandomFloat() * 0.5
                newParticleDef.rotZ = RandomFloat() * SwPI2
                newParticleDef.rotDZ = RandomFloat2() * 10.0
                newParticleDef.alpha = 0.4 + RandomFloat() * 0.2

                let stop: Bool = withUnsafeMutablePointer(to: &p) { pPtr in
                    withUnsafeMutablePointer(to: &d) { dPtr in
                        newParticleDef.where = pPtr
                        newParticleDef.delta = dPtr
                        return AddParticleToGroup(&newParticleDef) != 0
                    }
                }
                if stop {
                    pi.pointee.dirtParticleGroup = -1
                    break
                }
            }
        }
    }
}

// MARK: -

// MARK: - Add flame

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    @discardableResult
    func addFlame(x: Float, z: Float) -> UInt8 {
        // MAKE CUSTOM OBJECT

        var def = NewObjectDefinitionType()
        def.genre = UInt8(CUSTOM_GENRE)
        def.slot = Int16(WATER_SLOT + 1)
        def.coord.x = x
        def.coord.z = z
        def.coord.y = FindHighestCollisionAtXZ(x, z, UInt32(CTYPE_TERRAIN | CTYPE_WATER))
        def.scale = 1.0 + RandomFloat() * 0.8
        def.flags = UInt32(STATUS_BIT_DOUBLESIDED | STATUS_BIT_GLOW | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOZWRITES | STATUS_BIT_DONTCULL | STATUS_BIT_NOTEXTUREWRAP)
        def.moveCall = cMoveFlame
        def.drawCall = cDrawFlame

        let newObj = MakeNewObject(&def)!
        newObj.pointee.TerrainItemPtr = self // keep ptr to item list
        newObj.pointee.Special.0 = Int(RandomRange(0, 10)) // FlameFrame: start on random frame
        newObj.pointee.SpecialF.0 = 20.0 + RandomFloat() * 2.0 // FlameSpeed: set anim speed
        newObj.pointee.Timer = 0

        return 1 // item was added
    }
}

// MARK: - Move flame

private let cMoveFlame: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }

    if TrackTerrainItem(theNode) != 0 { // just check to see if it's gone
        DeleteObject(theNode)
        return
    }

    // NEXT FRAME

    theNode.pointee.Timer -= theNode.pointee.SpecialF.0 * gFramesPerSecondFrac // FlameSpeed
    if theNode.pointee.Timer <= 0.0 {
        theNode.pointee.Timer += 1.0
        theNode.pointee.Special.0 += 1 // FlameFrame
        if theNode.pointee.Special.0 > 10 {
            theNode.pointee.Special.0 = 0
        }
    }
}

// MARK: - Draw flame

private let cDrawFlame: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }
    let up = OGLVector3D(x: 0, y: 1, z: 0)
    var frame = [OGLPoint3D](repeating: OGLPoint3D(), count: 4)
    let paneNum = Int(gCurrentSplitScreenPane)

    let s = theNode.pointee.Scale.x

    frame[0].x = -100.0 * s
    frame[0].y = 200.0 * s
    frame[0].z = 0

    frame[1].x = 100.0 * s
    frame[1].y = 200.0 * s
    frame[1].z = 0

    frame[2].x = 100.0 * s
    frame[2].y = 0
    frame[2].z = 0

    frame[3].x = -100.0 * s
    frame[3].y = 0
    frame[3].z = 0

    // CALC VERTEX COORDS

    var m = OGLMatrix4x4()
    let camLoc = cameraPlacementsBase()[paneNum].cameraLocation
    withUnsafePointer(to: up) { upPtr in
        withUnsafePointer(to: camLoc) { camPtr in
            SetLookAtMatrixAndTranslate(&m, upPtr, &theNode.pointee.Coord, camPtr) // aim at camera & translate
        }
    }
    frame.withUnsafeMutableBufferPointer { frameBuf in
        OGLPoint3D.transformArray(frameBuf.baseAddress, by: m, into: frameBuf.baseAddress, count: 4)
    }

    // SUBMIT TEXTURE

    gGlobalColorFilter.r = 1.0
    gGlobalColorFilter.g = 0.8
    gGlobalColorFilter.b = 0.8

    let flameFrame = Int(theNode.pointee.Special.0)
    let mo = GetSpriteGroupPtr(Int32(SPRITE_GROUP_PARTICLES))![Int(PARTICLE_SObjType_Flame0) + flameFrame].materialObject!.assumingMemoryBound(to: MOMaterialObject.self)
    MO_DrawMaterial(mo)

    // DRAW QUAD

    gRenderBackend.beginImmediate(.quads)
    gRenderBackend.texCoord2f(0, 0); gRenderBackend.vertex3f(frame[0].x, frame[0].y, frame[0].z)
    gRenderBackend.texCoord2f(0.99, 0); gRenderBackend.vertex3f(frame[1].x, frame[1].y, frame[1].z)
    gRenderBackend.texCoord2f(0.99, 0.99); gRenderBackend.vertex3f(frame[2].x, frame[2].y, frame[2].z)
    gRenderBackend.texCoord2f(0, 0.99); gRenderBackend.vertex3f(frame[3].x, frame[3].y, frame[3].z)
    gRenderBackend.endImmediate()

    gGlobalColorFilter.r = 1
    gGlobalColorFilter.g = 1
    gGlobalColorFilter.b = 1
}

// MARK: -

// MARK: - Make fire ring

func MakeFireRing(_ x: Float, _ y: Float, _ z: Float) -> UnsafeMutablePointer<ObjNode>? {
    // MAKE CUSTOM OBJECT

    var def = NewObjectDefinitionType()
    def.genre = UInt8(CUSTOM_GENRE)
    def.slot = Int16(PARTICLE_SLOT + 2)
    def.coord = OGLPoint3D(x: x, y: y, z: z)
    def.scale = 100.0
    def.flags = UInt32(STATUS_BIT_DOUBLESIDED | STATUS_BIT_GLOW | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOZWRITES | STATUS_BIT_DONTCULL | STATUS_BIT_NOTEXTUREWRAP)
    def.moveCall = cMoveFireRing
    def.drawCall = cDrawFireRing

    let newObj = MakeNewObject(&def)!
    newObj.pointee.ColorFilter.a = 1.5
    return newObj // item was added
}

// MARK: - Move fire ring

private let cMoveFireRing: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }
    let fps = gFramesPerSecondFrac

    theNode.pointee.ColorFilter.a -= fps * 2.0
    if theNode.pointee.ColorFilter.a <= 0.0 {
        DeleteObject(theNode)
        return
    }

    theNode.pointee.Scale.z += fps * 1500.0
    theNode.pointee.Scale.x = theNode.pointee.Scale.z
    theNode.pointee.Scale.y = theNode.pointee.Scale.z

    // theNode.pointee.Rot.y = RandomFloat() * SwPI2
}

// MARK: - Draw fire ring

private let cDrawFireRing: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }
    var verts = [OGLPoint3D](repeating: OGLPoint3D(), count: 4)

    let x = theNode.pointee.Coord.x
    let y = theNode.pointee.Coord.y
    let z = theNode.pointee.Coord.z

    let s = theNode.pointee.Scale.x

    verts[0].x = x - s
    verts[0].y = y
    verts[0].z = z + s

    verts[1].x = x - s
    verts[1].y = y
    verts[1].z = z - s

    verts[2].x = x + s
    verts[2].y = y
    verts[2].z = z - s

    verts[3].x = x + s
    verts[3].y = y
    verts[3].z = z + s

    // SUBMIT TEXTURE

    gGlobalTransparency = theNode.pointee.ColorFilter.a

    let mo = GetSpriteGroupPtr(Int32(SPRITE_GROUP_PARTICLES))![Int(PARTICLE_SObjType_FireRing)].materialObject!.assumingMemoryBound(to: MOMaterialObject.self)
    MO_DrawMaterial(mo)

    // DRAW QUAD

    gRenderBackend.beginImmediate(.quads)
    gRenderBackend.texCoord2f(0, 0.99); gRenderBackend.vertex3f(verts[0].x, verts[0].y, verts[0].z)
    gRenderBackend.texCoord2f(0.99, 0.99); gRenderBackend.vertex3f(verts[1].x, verts[1].y, verts[1].z)
    gRenderBackend.texCoord2f(0.99, 0); gRenderBackend.vertex3f(verts[2].x, verts[2].y, verts[2].z)
    gRenderBackend.texCoord2f(0, 0); gRenderBackend.vertex3f(verts[3].x, verts[3].y, verts[3].z)
    gRenderBackend.endImmediate()

    gGlobalTransparency = 1.0
}
