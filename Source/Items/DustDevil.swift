// DustDevil.swift - Port of DustDevil.c to Swift
//
// VERTEXARRAYRANGES is hardcoded off in game.h, so the VAR-assignment block
// in InitDustDevilMemory is dead code and dropped.

private let maxDevils = 20

private let numDevilSegments = 14
private let numRibs = numDevilSegments + 1
private let numPointsPerRib = 20 // remember that 1st and last point overlap
private let numPointsPerSegment = numPointsPerRib * 2 // each segment has 2 ribs (top & bottom)
private let numPointsPerDevil = numDevilSegments * numPointsPerSegment

private let numTrianglesPerSegment = numPointsPerSegment - 2
private let numTrianglesPerDevil = numTrianglesPerSegment * numDevilSegments

private var gNumDustDevils: Int16 = 0

private var gDustDevilIsUsed = [Bool](repeating: false, count: maxDevils)
private var gDustDevilObjects: [UnsafeMutablePointer<ObjNode>?] = Array(repeating: nil, count: maxDevils)

// Flat, stable-address, double-buffered vertex array storage:
// layout is [buffer(2)][point/triangle within one devil mesh].
private let gDustDevilTrianglesStorage = UnsafeMutablePointer<MOTriangleIndecies>.allocate(capacity: 2 * numTrianglesPerDevil)
private let gDustDevilPointsStorage = UnsafeMutablePointer<OGLPoint3D>.allocate(capacity: 2 * numPointsPerDevil)
private let gDustDevilNormalsStorage = UnsafeMutablePointer<OGLVector3D>.allocate(capacity: 2 * numPointsPerDevil)
private let gDustDevilUVsStorage = UnsafeMutablePointer<OGLTextureCoord>.allocate(capacity: 2 * numPointsPerDevil)

@inline(__always) private func dustDevilTrianglesBase(_ b: Int) -> UnsafeMutablePointer<MOTriangleIndecies> {
    gDustDevilTrianglesStorage + b * numTrianglesPerDevil
}
@inline(__always) private func dustDevilPointsBase(_ b: Int) -> UnsafeMutablePointer<OGLPoint3D> {
    gDustDevilPointsStorage + b * numPointsPerDevil
}
@inline(__always) private func dustDevilNormalsBase(_ b: Int) -> UnsafeMutablePointer<OGLVector3D> {
    gDustDevilNormalsStorage + b * numPointsPerDevil
}
@inline(__always) private func dustDevilUVsBase(_ b: Int) -> UnsafeMutablePointer<OGLTextureCoord> {
    gDustDevilUVsStorage + b * numPointsPerDevil
}

private var gDustDevilMeshes = [MOVertexArrayData](repeating: MOVertexArrayData(), count: 2)

// gRibOffset[seg][j], flattened: index = seg * numPointsPerRib + j
private var gRibOffset = [OGLPoint3D](repeating: OGLPoint3D(), count: numRibs * numPointsPerRib)

// MARK: - Init dust devil memory

func InitDustDevilMemory() {
    gNumDustDevils = 0 // none build yet

    for d in 0..<maxDevils {
        gDustDevilIsUsed[d] = false // this one is available
    }

    // MAKE DUMMY OBJECT
    //
    // This dummy object is used to determine when in the event queue we
    // went to draw all the dirt devils.

    var def = NewObjectDefinitionType()
    def.genre = UInt8(CUSTOM_GENRE)
    def.slot = Int16(PARTICLE_SLOT) - 1
    def.moveCall = nil
    def.drawCall = cDrawDustDevils
    def.flags = UInt32(STATUS_BIT_DONTCULL | STATUS_BIT_NOZWRITES)
    def.scale = 1
    _ = MakeNewObject(&def)

    // CREATE RIB OFFSET TABLES

    var ribNormals = [OGLVector3D](repeating: OGLVector3D(), count: numRibs * numPointsPerRib)

    var scale: Float = 200.0

    for seg in 0..<numRibs {
        var rot: Float = 0
        for j in 0..<numPointsPerRib {
            let idx = seg * numPointsPerRib + j

            ribNormals[idx].x = -sin(rot)
            ribNormals[idx].z = cos(rot)
            ribNormals[idx].y = 0

            gRibOffset[idx].x = ribNormals[idx].x * scale
            gRibOffset[idx].z = ribNormals[idx].z * scale
            gRibOffset[idx].y = Float(seg) * 250.0

            rot += SwPI2 / Float(numPointsPerRib - 1)
        }

        scale *= 1.23
    }

    for b in 0..<2 { // make geometry for each double-buffer
        // INIT TRIMESH STRUCT

        gDustDevilMeshes[b].VARtype = -1

        gDustDevilMeshes[b].numMaterials = -1
        gDustDevilMeshes[b].materials.0 = nil

        gDustDevilMeshes[b].numPoints = Int32(numPointsPerDevil)
        gDustDevilMeshes[b].numTriangles = Int32(numTrianglesPerDevil)

        gDustDevilMeshes[b].points = dustDevilPointsBase(b)
        gDustDevilMeshes[b].triangles = dustDevilTrianglesBase(b)
        gDustDevilMeshes[b].normals = dustDevilNormalsBase(b)
        gDustDevilMeshes[b].uvs.0 = dustDevilUVsBase(b)
        gDustDevilMeshes[b].colorsFloat = nil

        // INIT UV ARRAY

        do {
            var v: Float = 0
            var i = 0
            for _ in 0..<numDevilSegments {
                var u: Float = 0
                for j in 0..<numPointsPerRib {
                    let q = i + j

                    dustDevilUVsBase(b)[q].u = u // bottom rib
                    dustDevilUVsBase(b)[q + numPointsPerRib].u = u // top rib

                    dustDevilUVsBase(b)[q].v = 1 - v
                    dustDevilUVsBase(b)[q + numPointsPerRib].v = 1 - (v + 1.0 / Float(numDevilSegments))

                    u += 1.0 / Float(numPointsPerRib - 1)
                }

                i += numPointsPerSegment

                v += 1.0 / Float(numDevilSegments)
            }
        }

        // INIT POINTS

        var ribPtIndex = 0
        for i in 0..<numDevilSegments {
            // SET LOWER RIB POINTS

            for j in 0..<numPointsPerRib {
                dustDevilPointsBase(b)[ribPtIndex] = gRibOffset[i * numPointsPerRib + j]
                ribPtIndex += 1
            }

            // SET UPPER RIB POINTS

            for j in 0..<numPointsPerRib {
                dustDevilPointsBase(b)[ribPtIndex] = gRibOffset[(i + 1) * numPointsPerRib + j]
                ribPtIndex += 1
            }
        }

        // INIT NORMALS

        var normalIndex = 0
        for i in 0..<numDevilSegments {
            // SET LOWER RIB POINTS

            for j in 0..<numPointsPerRib {
                dustDevilNormalsBase(b)[normalIndex] = ribNormals[i * numPointsPerRib + j]
                normalIndex += 1
            }

            // SET UPPER RIB POINTS

            for j in 0..<numPointsPerRib {
                dustDevilNormalsBase(b)[normalIndex] = ribNormals[(i + 1) * numPointsPerRib + j]
                normalIndex += 1
            }
        }

        // INIT TRIANGLES

        var triIndex = 0
        for seg in 0..<numDevilSegments {
            let pointNum = seg * numPointsPerSegment

            for j in 0..<(numPointsPerRib - 1) {
                let j2 = j + 1

                dustDevilTrianglesBase(b)[triIndex].vertexIndices.0 = UInt32(pointNum + j)
                dustDevilTrianglesBase(b)[triIndex].vertexIndices.1 = UInt32(pointNum + j + numPointsPerRib)
                dustDevilTrianglesBase(b)[triIndex].vertexIndices.2 = UInt32(pointNum + j2)
                triIndex += 1

                dustDevilTrianglesBase(b)[triIndex].vertexIndices.0 = UInt32(pointNum + j2)
                dustDevilTrianglesBase(b)[triIndex].vertexIndices.1 = UInt32(pointNum + j + numPointsPerRib)
                dustDevilTrianglesBase(b)[triIndex].vertexIndices.2 = UInt32(pointNum + j2 + numPointsPerRib)
                triIndex += 1
            }
        }
    } // for b
}

// MARK: - Update dust devil UV animation
//
// We directly modify the UVS in the mesh, but since this is double buffered for VAR, we
// need to modify this buffer's UV's based on the other buffer's UV's.  So, we read from the
// old to modify the new.

func UpdateDustDevilUVAnimation() {
    let fps = gFramesPerSecondFrac

    if gNumDustDevils > 0 { // only bother if there are dirt devils around
        let buffNum = Int(gGameViewInfoPtr!.pointee.frameCount & 1) // which VAR buffer to use?

        var n: Float = 4.0 // uv scroll speed for bottom segment

        for i in 0..<numDevilSegments {
            let uvs = dustDevilUVsBase(buffNum) + i * numPointsPerSegment // point to this segment's UV's
            let uvs2 = dustDevilUVsBase(buffNum ^ 1) + i * numPointsPerSegment

            for p in 0..<numPointsPerSegment {
                uvs[p].u = uvs2[p].u + n * fps
            }

            n *= 0.70 // next segment will scroll a little slower
        }
    }
}

// MARK: -

// MARK: - Add dust devil

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    @discardableResult
    func addDustDevil(x: Float, z: Float) -> UInt8 {
        guard let newObj = makeDustDevil(x, z) else {
            return 0
        }

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list
        newObj.pointee.MoveCall = cMoveDustDevil

        return 1 // item was added
    }
}

// MARK: - Make dust devil

private func makeDustDevil(_ x: Float, _ z: Float) -> UnsafeMutablePointer<ObjNode>? {
    // FIND FREE SLOT

    let devilNum = findFreeDustDevilSlot()
    if devilNum == -1 {
        return nil
    }

    // MAKE CUSTOM OBJECT

    var def = NewObjectDefinitionType()
    def.genre = UInt8(CUSTOM_GENRE)
    def.slot = Int16(PARTICLE_SLOT) - 1
    def.moveCall = nil
    def.coord.x = x
    def.coord.z = z
    def.coord.y = GetTerrainY(x, z)
    def.flags = UInt32(STATUS_BIT_DONTCULL | STATUS_BIT_HIDDEN)
    def.scale = 1

    let newObj = MakeNewObject(&def)!

    newObj.pointee.Mode = Int32(devilNum)

    gNumDustDevils += 1

    gDustDevilObjects[devilNum] = newObj

    return newObj
}

// MARK: - Find free dust devil slot

private func findFreeDustDevilSlot() -> Int {
    for i in 0..<maxDevils {
        if !gDustDevilIsUsed[i] {
            gDustDevilIsUsed[i] = true
            return i
        }
    }

    return -1
}

// MARK: - Draw dust devils

private let cDrawDustDevils: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { _ in
    if gNumDustDevils == 0 {
        return
    }

    let buffNum = Int(gGameViewInfoPtr!.pointee.frameCount & 1) // which VAR buffer to use?

    // DRAW EACH ACTIVE DUST DEVIL

    gGlobalMaterialFlags = UInt32(BG3D_MATERIALFLAG_CLAMP_V)

    for d in 0..<maxDevils {
        if !gDustDevilIsUsed[d] { // is this one used?
            continue
        }

        let theNode = gDustDevilObjects[d]! // get ptr to this devil's objNode

        gEngine.renderer.pushMatrix()

        MO_DrawMaterial(GetSpriteGroupPtr(Int32(SPRITE_GROUP_LEVELSPECIFIC))![Int(LEVEL2_SObjType_DustDevil)].materialObject?.assumingMemoryBound(to: MOMaterialObject.self)) // activate material

        // TRANSLATE

        var m = OGLMatrix4x4()
        m.setTranslate(theNode.pointee.Coord.x, theNode.pointee.Coord.y, theNode.pointee.Coord.z)
        gEngine.renderer.multMatrix(&m.value.0)

        // SCALE DOWN AND DRAW INNER SHELL

        if !gGamePrefs.isLowRenderQuality {
            gEngine.renderer.pushMatrix()
            OGL_SetColor4f(1, 1, 1, 0.5)

            m.setScale(0.8, 1, 0.8)
            gEngine.renderer.multMatrix(&m.value.0)

            m.setRotateY(Float.pi)
            gEngine.renderer.multMatrix(&m.value.0)

            MO_DrawGeometry_VertexArray(&gDustDevilMeshes[buffNum])

            OGL_SetColor4f(1, 1, 1, 1)
            gEngine.renderer.popMatrix()
        }

        // DRAW OUTER SHELL

        MO_DrawGeometry_VertexArray(&gDustDevilMeshes[buffNum])

        gEngine.renderer.popMatrix()
    }

    gGlobalMaterialFlags = 0
}

// MARK: -

// MARK: - Move dust devil

private let cMoveDustDevil: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    let theNode = theNodeOpt!
    let devilNum = Int(theNode.pointee.Mode)

    if TrackTerrainItem(theNode) != 0 { // just check to see if it's gone
        gDustDevilIsUsed[devilNum] = false
        gNumDustDevils -= 1
        DeleteObject(theNode)
        return
    }

    makeDustDevilDust(theNode)

    seeIfDustDevilHitsPlayer(theNode)

    // UPDATE EFFECT

    if theNode.pointee.EffectChannel == -1 {
        theNode.pointee.EffectChannel = PlayEffect_Parms3D(Int16(EFFECT_DUSTDEVIL), &theNode.pointee.Coord, UInt32(NORMAL_CHANNEL_RATE) + (MyRandomLong() & 0x1FFF), 1.0)
    } else {
        Update3DSoundChannel(Int16(EFFECT_DUSTDEVIL), &theNode.pointee.EffectChannel, &theNode.pointee.Coord)
    }
}

// MARK: - Make dust devil dust

private func makeDustDevilDust(_ theNode: UnsafeMutablePointer<ObjNode>) {
    let fps = gFramesPerSecondFrac

    theNode.getInfo()

    // MAKE DUST

    theNode.pointee.ParticleTimer -= fps // see if add smoke
    if theNode.pointee.ParticleTimer <= 0.0 {
        theNode.pointee.ParticleTimer += 0.08 // reset timer

        var particleGroup = theNode.pointee.ParticleGroup
        let magicNum = theNode.pointee.ParticleMagicNum

        if particleGroup == -1 || VerifyParticleGroupMagicNum(particleGroup, magicNum) == 0 {
            let newMagicNum = MyRandomLong() // generate a random magic num
            theNode.pointee.ParticleMagicNum = newMagicNum

            gNewParticleGroupDef.magicNum = newMagicNum
            gNewParticleGroupDef.particleType = .fallingSparks
            gNewParticleGroupDef.flags = UInt32(PARTICLE_FLAGS_DONTCHECKGROUND)
            gNewParticleGroupDef.gravity = 10
            gNewParticleGroupDef.magnetism = 0
            gNewParticleGroupDef.baseScale = 35.0
            gNewParticleGroupDef.decayRate = -8.0
            gNewParticleGroupDef.fadeRate = 0.25
            gNewParticleGroupDef.particleTextureNum = UInt8(PARTICLE_SObjType_GasCloud)
            gNewParticleGroupDef.srcBlend = GL_SRC_ALPHA
            gNewParticleGroupDef.dstBlend = GL_ONE_MINUS_SRC_ALPHA
            particleGroup = NewParticleGroup(&gNewParticleGroupDef)
            theNode.pointee.ParticleGroup = particleGroup
        }

        if particleGroup != -1 {
            let x = gEngine.objects.coord.x
            let y = gEngine.objects.coord.y
            let z = gEngine.objects.coord.z

            for _ in 0..<2 {
                var p = OGLPoint3D()
                var d = OGLVector3D()

                p.x = x + RandomFloat2() * 190.0
                p.y = y + RandomFloat() * 30.0
                p.z = z + RandomFloat2() * 190.0

                d.x = p.x - x
                d.y = p.y - y
                d.z = p.z - z
                FastNormalizeVector(d.x, d.y, d.z, &d)

                d.x *= 250.0
                d.y *= 250.0
                d.z *= 250.0

                var newParticleDef = NewParticleDefType()
                newParticleDef.groupNum = particleGroup
                newParticleDef.scale = RandomFloat() + 1.0
                newParticleDef.rotZ = RandomFloat() * SwPI2
                newParticleDef.rotDZ = RandomFloat2() * 2.0
                newParticleDef.alpha = 0.6

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

// MARK: - Prime dust devil

func PrimeDustDevil(_ splineNum: Int, _ itemPtr: UnsafeMutablePointer<SplineItemType>!) -> UInt8 {
    // GET SPLINE INFO

    let placement = itemPtr.pointee.placement
    var x: Float = 0
    var z: Float = 0
    GetCoordOnSpline(gSplineList + splineNum, placement, &x, &z)

    // MAKE IT

    let newObj = makeDustDevil(x, z)!

    // SET BETTER INFO

    newObj.setStatus(STATUS_BIT_ONSPLINE)
    newObj.pointee.SplineItemPtr = itemPtr
    newObj.pointee.SplineNum = UInt8(splineNum)
    newObj.pointee.SplinePlacement = placement
    newObj.pointee.SplineMoveCall = cMoveDustDevilOnSpline // set move call

    // ADD SPLINE OBJECT TO SPLINE OBJECT LIST

    DetachObject(newObj, 1) // detach this object from the linked list
    AddToSplineObjectList(newObj, 1)

    return 1
}

// MARK: - Move dust devil on spline

private let cMoveDustDevilOnSpline: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    let theNode = theNodeOpt!

    let isInRange = IsSplineItemOnActiveTerrain(theNode) != 0 // update its visibility

    // MOVE ALONG THE SPLINE

    IncreaseSplineIndex(theNode, 65)
    GetObjectCoordOnSpline(theNode)

    // UPDATE STUFF IF IN RANGE

    if isInRange {
        theNode.pointee.Rot.y = CalcYAngleFromPointToPoint(theNode.pointee.Rot.y, theNode.pointee.OldCoord.x, theNode.pointee.OldCoord.z, // calc y rot aim
                                                            theNode.pointee.Coord.x, theNode.pointee.Coord.z)

        theNode.pointee.Coord.y = GetTerrainY(theNode.pointee.Coord.x, theNode.pointee.Coord.z) - theNode.pointee.BottomOff // calc y coord

        makeDustDevilDust(theNode)
        seeIfDustDevilHitsPlayer(theNode)

        // UPDATE EFFECT

        if theNode.pointee.EffectChannel == -1 {
            theNode.pointee.EffectChannel = PlayEffect_Parms3D(Int16(EFFECT_DUSTDEVIL), &theNode.pointee.Coord, UInt32(NORMAL_CHANNEL_RATE) - (MyRandomLong() & 0x1FFF), 2.0)
        } else {
            Update3DSoundChannel(Int16(EFFECT_DUSTDEVIL), &theNode.pointee.EffectChannel, &theNode.pointee.Coord)
        }
    }
}

// MARK: -

// MARK: - See if dust devil hits player

private func seeIfDustDevilHitsPlayer(_ devil: UnsafeMutablePointer<ObjNode>) {
    for p in 0..<Int(gEngine.player.numPlayers) {
        // SEE IF WE CARE ABOUT THIS PLAYER

        if GetPlayerIsDead(Int32(p)) != 0 { // skip dead players
            continue
        }

        let player = GetPlayerInfoEntry(Int32(p)).pointee.objNode! // get player ObjNode

        let animNum = PlayerAnim(rawValue: UInt32(player.pointee.Skeleton!.pointee.AnimNum))
        if animNum == .deathDive ||
            animNum == .appearWormhole ||
            animNum == .enterWormhole ||
            animNum == .dustDevil {
            continue
        }

        // SEE IF PLAYER IS IN RANGE OF DUST DEVIL

        let playerX = player.pointee.Coord.x
        let playerY = player.pointee.Coord.y
        let playerZ = player.pointee.Coord.z
        let distXZ = CalcDistance(playerX, playerZ, devil.pointee.Coord.x, devil.pointee.Coord.z) // calc XZ dist to center of dust devil

        // SCAN ONE RIB AT A TIME

        for r in 0..<numRibs {
            let ribY = gRibOffset[r * numPointsPerRib].y + devil.pointee.Coord.y // calc y coord of rib

            if playerY > ribY { // is player above this rib?
                let radius = gRibOffset[r * numPointsPerRib].z + 50.0 // get radius of rib from first point's z offset (plus a tweak factor)

                if distXZ < radius { // is player within this rib's radius?
                    // IT'S A HIT

                    putPlayerInDirtDevil(player, devil, distXZ)
                }
            }
        }
    }
}

// MARK: - Put player in dust devil

private func putPlayerInDirtDevil(_ player: UnsafeMutablePointer<ObjNode>, _ dustDevil: UnsafeMutablePointer<ObjNode>, _ radius: Float) {
    let p = player.pointee.PlayerNum

    DropEgg_NoWormhole(Int16(p))
    JetpackOff(Int16(p))

    MorphToSkeletonAnim(player.pointee.Skeleton, .dustDevil, 3.0)

    player.pointee.Timer = 4.0 // set duration of time in dust devil

    let pi = GetPlayerInfoEntry(Int32(p))
    pi.pointee.dustDevilObj = dustDevil
    pi.pointee.dustDevilRotSpeed = 0

    pi.pointee.dustDevilRot = CalcYAngleFromPointToPoint(0, dustDevil.pointee.Coord.x, dustDevil.pointee.Coord.z,
                                                          player.pointee.Coord.x, player.pointee.Coord.z)

    pi.pointee.radiusFromDustDevil = radius

    pi.pointee.ejectedFromDustDevil = 0
}
