// Confetti.swift - Port of Confetti.c to Swift
//
// gEngine.confetti.newGroupDef is native Swift storage now (converted 2026-07-07):
// nothing in any .c file touches it anymore (Trees.c/Player.c, its only
// real C users, are both deleted). gEngine.confetti.groups/gEngine.confetti.numActiveGroups
// were plain (non-extern) globals only ever touched from this file, so
// they stay a private Swift array.

/// Confetti-group state. Owned by GameEngine as `gEngine.confetti`.
final class ConfettiSystem {
    var newGroupDef = NewConfettiGroupDefType()
    fileprivate var groups = InlineArray<50, UnsafeMutablePointer<ConfettiGroupType>?>(repeating: nil)
    fileprivate var numActiveGroups: Int16 = 0
}


// MARK: - fixed-array-field helpers (all struct fields, never unions)

@inline(__always) private func isUsedBase(_ g: UnsafeMutablePointer<ConfettiGroupType>) -> UnsafeMutablePointer<UInt8> {
    UnsafeMutableRawPointer(g.pointer(to: \.isUsed)!).assumingMemoryBound(to: UInt8.self)
}

@inline(__always) private func fadeDelayBase(_ g: UnsafeMutablePointer<ConfettiGroupType>) -> UnsafeMutablePointer<Float> {
    UnsafeMutableRawPointer(g.pointer(to: \.fadeDelay)!).assumingMemoryBound(to: Float.self)
}

@inline(__always) private func alphaBase(_ g: UnsafeMutablePointer<ConfettiGroupType>) -> UnsafeMutablePointer<Float> {
    UnsafeMutableRawPointer(g.pointer(to: \.alpha)!).assumingMemoryBound(to: Float.self)
}

@inline(__always) private func scaleBase(_ g: UnsafeMutablePointer<ConfettiGroupType>) -> UnsafeMutablePointer<Float> {
    UnsafeMutableRawPointer(g.pointer(to: \.scale)!).assumingMemoryBound(to: Float.self)
}

@inline(__always) private func rotBase(_ g: UnsafeMutablePointer<ConfettiGroupType>) -> UnsafeMutablePointer<OGLVector3D> {
    UnsafeMutableRawPointer(g.pointer(to: \.rot)!).assumingMemoryBound(to: OGLVector3D.self)
}

@inline(__always) private func deltaRotBase(_ g: UnsafeMutablePointer<ConfettiGroupType>) -> UnsafeMutablePointer<OGLVector3D> {
    UnsafeMutableRawPointer(g.pointer(to: \.deltaRot)!).assumingMemoryBound(to: OGLVector3D.self)
}

@inline(__always) private func coordBase(_ g: UnsafeMutablePointer<ConfettiGroupType>) -> UnsafeMutablePointer<OGLPoint3D> {
    UnsafeMutableRawPointer(g.pointer(to: \.coord)!).assumingMemoryBound(to: OGLPoint3D.self)
}

@inline(__always) private func deltaBase(_ g: UnsafeMutablePointer<ConfettiGroupType>) -> UnsafeMutablePointer<OGLVector3D> {
    UnsafeMutableRawPointer(g.pointer(to: \.delta)!).assumingMemoryBound(to: OGLVector3D.self)
}

// MARK: - Init

func InitConfettiManager() {
    // INIT GROUP ARRAY
    for i in 0..<Int(MAX_CONFETTI_GROUPS) {
        gEngine.confetti.groups[i] = nil
    }

    gEngine.confetti.numActiveGroups = 0

    // CREATE DUMMY CUSTOM OBJECT TO CAUSE CONFETTI DRAWING AT THE DESIRED TIME
    //
    // The confettis need to be drawn after the fences object, but before any sprite or font objects.

    var def = NewObjectDefinitionType()
    def.genre = UInt8(CUSTOM_GENRE)
    def.slot = Int16(CONFETTI_SLOT)
    def.scale = 1
    def.flags = UInt32(STATUS_BIT_DOUBLESIDED | STATUS_BIT_DONTCULL)
    def.moveCall = cMoveConfettiGroups
    def.drawCall = cDrawConfettiGroups

    MakeNewObject(&def)
}

func DeleteAllConfettiGroups() {
    for i in 0..<Int(MAX_CONFETTI_GROUPS) {
        deleteConfettiGroup(i)
    }
}

private func deleteConfettiGroup(_ groupNum: Int) {
    if let group = gEngine.confetti.groups[groupNum] {
        // NUKE GEOMETRY DATA
        MO_DisposeObjectReference(UnsafeMutableRawPointer(group.pointee.geometryObj))

        // NUKE GROUP ITSELF
        SafeDisposePtr(group)
        gEngine.confetti.groups[groupNum] = nil

        gEngine.confetti.numActiveGroups -= 1
    }
}

// MARK: - New confetti group

// INPUT: def -> group type to create
// OUTPUT: group ID#
func NewConfettiGroup(_ def: UnsafeMutablePointer<NewConfettiGroupDefType>) -> Int16 {
    // SCAN FOR A FREE GROUP
    for i in 0..<Int(MAX_CONFETTI_GROUPS) {
        if gEngine.confetti.groups[i] == nil {
            // ALLOCATE NEW GROUP
            guard let group = AllocPtrClear(MemoryLayout<ConfettiGroupType>.size)?.assumingMemoryBound(to: ConfettiGroupType.self) else {
                return -1 // out of memory
            }
            gEngine.confetti.groups[i] = group

            // INITIALIZE THE GROUP
            let isUsed = isUsedBase(group)
            for p in 0..<Int(MAX_CONFETTIS) { // mark all unused
                isUsed[p] = 0
            }

            group.pointee.flags = def.pointee.flags
            group.pointee.gravity = def.pointee.gravity
            group.pointee.baseScale = def.pointee.baseScale
            group.pointee.decayRate = def.pointee.decayRate
            group.pointee.fadeRate = def.pointee.fadeRate
            group.pointee.magicNum = def.pointee.magicNum
            group.pointee.confettiTextureNum = def.pointee.confettiTextureNum

            // INIT THE GROUP'S GEOMETRY

            // SET THE DATA
            var vertexArrayData = MOVertexArrayData()

            vertexArrayData.VARtype = -1

            vertexArrayData.numMaterials = 1
            vertexArrayData.materials.0 = GetSpriteGroupPtr(Int32(SPRITE_GROUP_PARTICLES))![Int(def.pointee.confettiTextureNum)].materialObject?.assumingMemoryBound(to: MOMaterialObject.self) // set illegal ref because it is made legit below

            vertexArrayData.numPoints = 0
            vertexArrayData.numTriangles = 0
            let points = AllocPtrClear(MemoryLayout<OGLPoint3D>.size * Int(MAX_CONFETTIS) * 4)!.assumingMemoryBound(to: OGLPoint3D.self)
            vertexArrayData.points = points
            vertexArrayData.normals = nil
            let uvs = AllocPtrClear(MemoryLayout<OGLTextureCoord>.size * Int(MAX_CONFETTIS) * 4)!.assumingMemoryBound(to: OGLTextureCoord.self)
            vertexArrayData.uvs.0 = uvs
            vertexArrayData.colorsFloat = AllocPtrClear(MemoryLayout<OGLColorRGBA>.size * Int(MAX_CONFETTIS) * 4)!.assumingMemoryBound(to: OGLColorRGBA.self)
            let triangles = AllocPtrClear(MemoryLayout<MOTriangleIndecies>.size * Int(MAX_CONFETTIS) * 2)!.assumingMemoryBound(to: MOTriangleIndecies.self)
            vertexArrayData.triangles = triangles

            // INIT UV ARRAYS
            var j = 0
            while j < Int(MAX_CONFETTIS) * 4 {
                uvs[j].u = 0 // upper left
                uvs[j].v = 1
                uvs[j + 1].u = 0 // lower left
                uvs[j + 1].v = 0
                uvs[j + 2].u = 1 // lower right
                uvs[j + 2].v = 0
                uvs[j + 3].u = 1 // upper right
                uvs[j + 3].v = 1
                j += 4
            }

            // INIT TRIANGLE ARRAYS
            j = 0
            var k = 0
            while j < Int(MAX_CONFETTIS) * 2 {
                triangles[j].vertexIndices.0 = UInt32(k) // triangle A
                triangles[j].vertexIndices.1 = UInt32(k + 1)
                triangles[j].vertexIndices.2 = UInt32(k + 2)

                triangles[j + 1].vertexIndices.0 = UInt32(k) // triangle B
                triangles[j + 1].vertexIndices.1 = UInt32(k + 2)
                triangles[j + 1].vertexIndices.2 = UInt32(k + 3)

                j += 2
                k += 4
            }

            // CREATE NEW GEOMETRY OBJECT
            group.pointee.geometryObj = MO_CreateNewObjectOfType(.geometry, Int(MO_GEOMETRY_SUBTYPE_VERTEXARRAY), &vertexArrayData)?.assumingMemoryBound(to: MOVertexArrayObject.self)

            gEngine.confetti.numActiveGroups += 1

            return Int16(i)
        }
    }

    // NOTHING FREE
    // DoFatalAlert("NewConfettiGroup: no free groups!");
    return -1
}

// Returns true if confetti group was invalid or is full.
func AddConfettiToGroup(_ def: UnsafeMutablePointer<NewConfettiDefType>) -> UInt8 {
    let group = Int(def.pointee.groupNum)

    if group < 0 || group >= Int(MAX_CONFETTI_GROUPS) {
        SwFatal("AddConfettiToGroup: illegal group #")
    }

    guard let g = gEngine.confetti.groups[group] else {
        return 1
    }

    // SCAN FOR FREE SLOT
    let isUsed = isUsedBase(g)
    var p = -1
    for i in 0..<Int(MAX_CONFETTIS) {
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
    fadeDelayBase(g)[p] = def.pointee.fadeDelay
    alphaBase(g)[p] = def.pointee.alpha
    scaleBase(g)[p] = def.pointee.scale
    coordBase(g)[p] = def.pointee.where.pointee
    deltaBase(g)[p] = def.pointee.delta.pointee
    rotBase(g)[p] = def.pointee.rot
    deltaRotBase(g)[p] = def.pointee.deltaRot
    isUsed[p] = 1

    return 0
}

// MARK: - Move confetti groups

private let cMoveConfettiGroups: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { _ in
    moveConfettiGroups()
}

private func moveConfettiGroups() {
    let fps = gEngine.framesPerSecondFrac

    for i in 0..<Int(MAX_CONFETTI_GROUPS) {
        guard let g = gEngine.confetti.groups[i] else {
            continue
        }

        let gravity = g.pointee.gravity // get gravity
        let decayRate = g.pointee.decayRate // get decay rate
        let fadeRate = g.pointee.fadeRate // get fade rate
        let flags = g.pointee.flags

        let isUsed = isUsedBase(g)
        let coord = coordBase(g)
        let delta = deltaBase(g)
        let rot = rotBase(g)
        let deltaRot = deltaRotBase(g)
        let scale = scaleBase(g)
        let fadeDelay = fadeDelayBase(g)
        let alpha = alphaBase(g)

        var n = 0 // init counter
        for p in 0..<Int(MAX_CONFETTIS) {
            if isUsed[p] == 0 { // make sure this confetti is used
                continue
            }

            n += 1 // inc counter

            // ADD GRAVITY
            delta[p].y -= gravity * fps // add gravity

            // DO ROTATION & MOTION
            rot[p].x += deltaRot[p].x * fps
            rot[p].y += deltaRot[p].y * fps
            rot[p].z += deltaRot[p].z * fps

            coord[p].x += delta[p].x * fps // move it
            coord[p].y += delta[p].y * fps
            coord[p].z += delta[p].z * fps

            // SEE IF BOUNCE
            if flags & UInt32(PARTICLE_FLAGS_DONTCHECKGROUND) == 0 {
                var y = GetTerrainY(coord[p].x, coord[p].z) // get terrain coord at confetti x/z
                if y == ILLEGAL_TERRAIN_Y { // bounce for Win screen
                    y = 0
                }
                y += 10

                if flags & UInt32(PARTICLE_FLAGS_BOUNCE) != 0 {
                    if delta[p].y < 0 { // if moving down, see if hit floor
                        if coord[p].y < y {
                            coord[p].y = y
                            delta[p].y *= -0.4

                            delta[p].x += gEngine.terrain.recentTerrainNormal.x * 300 // reflect off of surface
                            delta[p].z += gEngine.terrain.recentTerrainNormal.z * 300

                            if flags & UInt32(PARTICLE_FLAGS_DISPERSEIFBOUNCE) != 0 { // see if disperse on impact
                                delta[p].y *= 0.4
                                delta[p].x *= 5
                                delta[p].z *= 5
                            }
                        }
                    }
                }
                // SEE IF GONE
                else {
                    if coord[p].y < y { // if hit floor then nuke confetti
                        isUsed[p] = 0
                    }
                }
            }

            // DO SCALE
            scale[p] -= decayRate * fps // shrink it
            if scale[p] <= 0 { // see if gone
                isUsed[p] = 0
            }

            // DO FADE
            fadeDelay[p] -= fps
            if fadeDelay[p] <= 0 {
                alpha[p] -= fadeRate * fps // fade it
                if alpha[p] <= 0 { // see if gone
                    isUsed[p] = 0
                }
            }
        }

        // SEE IF GROUP WAS EMPTY, THEN DELETE
        if n == 0 {
            deleteConfettiGroup(i)
        }
    }
}

// MARK: - Draw confetti groups

private let cDrawConfettiGroups: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { _ in
    drawConfettiGroups()
}

private func drawConfettiGroups() {
    var v = (OGLPoint3D(), OGLPoint3D(), OGLPoint3D(), OGLPoint3D())
    v.0.z = 0 // init z's to 0
    v.1.z = 0
    v.2.z = 0
    v.3.z = 0

    // SETUP ENVIRONTMENT
    OGL_PushState()
    gEngine.renderer.setTwoSidedLighting(true)

    OGL_SetColor4f(1, 1, 1, 1) // full white & alpha to start with

    for g in 0..<Int(MAX_CONFETTI_GROUPS) {
        guard let group = gEngine.confetti.groups[g] else {
            continue
        }

        guard let geoData = group.pointee.geometryObj else {
            continue
        }

        let vertexColors = geoData.colorsFloat! // get pointer to vertex color array
        let baseScale = group.pointee.baseScale // get base scale

        let scaleArr = scaleBase(group)
        let rot = rotBase(group)
        let coord = coordBase(group)

        // ADD ALL CONFETTIS TO TRIMESH
        var minX: Float = 100_000_000, minY: Float = 100_000_000, minZ: Float = 100_000_000 // init bbox
        var maxX = -minX, maxY = -minY, maxZ = -minZ

        var n = 0
        let isUsed = isUsedBase(group)
        let points = geoData.points!

        for p in 0..<Int(MAX_CONFETTIS) {
            if isUsed[p] == 0 { // make sure this confetti is used
                continue
            }

            // SET VERTEX COORDS
            let scale = scaleArr[p] * baseScale

            v.0.x = -scale
            v.0.y = scale

            v.1.x = -scale
            v.1.y = -scale

            v.2.x = scale
            v.2.y = -scale

            v.3.x = scale
            v.3.y = scale

            // TRANSFORM THIS CONFETTI'S VERTICES & ADD TO TRIMESH
            var m = OGLMatrix4x4()
            m.setRotateXYZ(rot[p].x, rot[p].y, rot[p].z)
            setMatValue(&m, M03, coord[p].x) // set translate
            setMatValue(&m, M13, coord[p].y)
            setMatValue(&m, M23, coord[p].z)
            withUnsafeMutablePointer(to: &v) {
                $0.withMemoryRebound(to: OGLPoint3D.self, capacity: 4) { vPtr in
                    OGLPoint3D.transformArray(vPtr, by: m, into: points + n * 4, count: 4) // transform
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
                vertexColors[i].r = 1
                vertexColors[i].g = 1
                vertexColors[i].b = 1
                vertexColors[i].a = alphaBase(group)[p] // set transparency alpha
            }

            n += 1 // inc confetti count
        }

        if n == 0 { // if no confettis, then skip
            continue
        }

        // UPDATE FINAL VALUES
        geoData.numTriangles = Int32(n * 2)
        geoData.numPoints = Int32(n * 4)

        var shouldDraw = true

        if geoData.numPoints >= 20 { // if small then just skip cull test
            var bbox = OGLBoundingBox() // build bbox for culling test
            bbox.min.x = minX
            bbox.min.y = minY
            bbox.min.z = minZ
            bbox.max.x = maxX
            bbox.max.y = maxY
            bbox.max.z = maxZ

            shouldDraw = OGL_IsBBoxVisible(&bbox, nil) != 0 // do cull test on it
        }

        if shouldDraw {
            // DRAW IT
            MO_DrawObject(UnsafeMutableRawPointer(group.pointee.geometryObj)) // draw geometry
        }
    }

    // RESTORE MODES
    OGL_PopState()
    OGL_SetColor4f(1, 1, 1, 1) // reset this
    gEngine.renderer.setTwoSidedLighting(false)
}

// MARK: - Verify

func VerifyConfettiGroupMagicNum(_ group: Int16, _ magicNum: UInt32) -> UInt8 {
    guard let g = gEngine.confetti.groups[Int(group)] else {
        return 0
    }

    return g.pointee.magicNum == magicNum ? 1 : 0
}

// MARK: - Make confetti explosion

func MakeConfettiExplosion(_ x: Float, _ y: Float, _ z: Float, _ force: Float, _ scale: Float, _ texture: Int16, _ quantity: Int16) {
    let radius = 1.0 * scale

    gEngine.confetti.newGroupDef.magicNum = 0
    gEngine.confetti.newGroupDef.flags = UInt32(PARTICLE_FLAGS_BOUNCE)
    gEngine.confetti.newGroupDef.gravity = 250
    gEngine.confetti.newGroupDef.baseScale = 4.5 * scale
    gEngine.confetti.newGroupDef.decayRate = 0
    gEngine.confetti.newGroupDef.fadeRate = 1.0
    gEngine.confetti.newGroupDef.confettiTextureNum = UInt8(texture)

    let pg = NewConfettiGroup(&gEngine.confetti.newGroupDef)
    if pg != -1 {
        for _ in 0..<quantity {
            var pt = OGLPoint3D()
            pt.x = x + RandomFloat2() * radius
            pt.y = y + RandomFloat2() * radius
            pt.z = z + RandomFloat2() * radius

            var v = OGLVector3D()
            v.x = pt.x - x
            v.y = pt.y - y
            v.z = pt.z - z
            FastNormalizeVector(v.x, v.y, v.z, &v)

            var delta = OGLVector3D()
            delta.x = v.x * (force * scale)
            delta.y = v.y * (force * scale)
            delta.z = v.z * (force * scale)

            var newConfettiDef = NewConfettiDefType()
            newConfettiDef.groupNum = pg
            newConfettiDef.scale = 1.0 + RandomFloat() * 0.5
            newConfettiDef.rot.x = RandomFloat() * SwPI2
            newConfettiDef.rot.y = RandomFloat() * SwPI2
            newConfettiDef.rot.z = RandomFloat() * SwPI2
            newConfettiDef.deltaRot.x = RandomFloat2() * 5.0
            newConfettiDef.deltaRot.y = RandomFloat2() * 5.0
            newConfettiDef.deltaRot.z = RandomFloat2() * 5.0
            newConfettiDef.alpha = Float(FULL_ALPHA)
            newConfettiDef.fadeDelay = 0.5 + RandomFloat()

            let stop: Bool = withUnsafeMutablePointer(to: &pt) { ptPtr in
                withUnsafeMutablePointer(to: &delta) { deltaPtr in
                    newConfettiDef.where = ptPtr
                    newConfettiDef.delta = deltaPtr
                    return AddConfettiToGroup(&newConfettiDef) != 0
                }
            }
            if stop {
                break
            }
        }
    }
}
