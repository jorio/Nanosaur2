// Shards.swift - Port of Shards.c to Swift

// Native Swift OptionSet - was `typedef enum SWIFT_FLAG_ENUM ShardMode {...}
// ShardMode;` in shards.h with zero C callers/globals (verified 2026-07-07),
// so it moved entirely off the C ABI; shards.h is now deleted.
struct ShardMode: OptionSet, Sendable {
    let rawValue: Int32

    static let upthrust = ShardMode(rawValue: 1)
    static let heavyGravity = ShardMode(rawValue: 1 << 1)
    static let bounce = ShardMode(rawValue: 1 << 2)
    static let fromOrigin = ShardMode(rawValue: 1 << 3)
}

private let maxShards = 2500

private struct ShardType {
    var isUsed = false
    var rot = OGLVector3D()
    var rotDelta = OGLVector3D()
    var coord = OGLPoint3D()
    var coordDelta = OGLPoint3D()
    var decaySpeed: Float = 0
    var scale: Float = 0
    var mode: ShardMode = []
    var matrix = OGLMatrix4x4()

    var points: InlineArray<3, OGLPoint3D> = InlineArray(repeating: OGLPoint3D())
    var uvs: InlineArray<3, OGLTextureCoord> = InlineArray(repeating: OGLTextureCoord())
    var material: UnsafeMutablePointer<MOMaterialObject>?
    var colorFilter = OGLColorRGBA()
    var glow: UInt32 = 0
}

/// Shard (exploding-geometry) state. Owned by GameEngine as `gEngine.shards`.
final class ShardSystem {
    fileprivate var numShards = 0
    fileprivate var pool: InlineArray<2500, ShardType> = InlineArray(repeating: ShardType())

    fileprivate var boomForce: Float = 0
    fileprivate var decaySpeed: Float = 0
    fileprivate var mode: ShardMode = []
    fileprivate var density = 0
    fileprivate var workMatrix = OGLMatrix4x4()
    fileprivate var srcObj: UnsafeMutablePointer<ObjNode>?
}

@inline(__always) private func deformedMeshesBase(_ skelObjData: UnsafeMutablePointer<SkeletonObjDataType>) -> UnsafeMutablePointer<MOVertexArrayData> {
    UnsafeMutableRawPointer(skelObjData.pointer(to: \.deformedMeshes)!).assumingMemoryBound(to: MOVertexArrayData.self)
}

@inline(__always) private func overrideTextureBase(_ skelObjData: UnsafeMutablePointer<SkeletonObjDataType>) -> UnsafeMutablePointer<UnsafeMutablePointer<MOMaterialObject>?> {
    UnsafeMutableRawPointer(skelObjData.pointer(to: \.overrideTexture)!).assumingMemoryBound(to: UnsafeMutablePointer<MOMaterialObject>?.self)
}

@inline(__always) private func vertexIndicesBase(_ triangle: UnsafeMutablePointer<MOTriangleIndecies>) -> UnsafeMutablePointer<GLuint> {
    UnsafeMutableRawPointer(triangle.pointer(to: \.vertexIndices)!).assumingMemoryBound(to: GLuint.self)
}

@inline(__always) private func vertexArrayUVsBase(_ data: UnsafeMutablePointer<MOVertexArrayData>) -> UnsafeMutablePointer<UnsafeMutablePointer<OGLTextureCoord>?> {
    UnsafeMutableRawPointer(data.pointer(to: \.uvs)!).assumingMemoryBound(to: UnsafeMutablePointer<OGLTextureCoord>?.self)
}

@inline(__always) private func vertexArrayMaterialsBase(_ data: UnsafeMutablePointer<MOVertexArrayData>) -> UnsafeMutablePointer<UnsafeMutablePointer<MOMaterialObject>?> {
    UnsafeMutableRawPointer(data.pointer(to: \.materials)!).assumingMemoryBound(to: UnsafeMutablePointer<MOMaterialObject>?.self)
}

@inline(__always) private func groupContentsBase(_ groupData: UnsafeMutablePointer<MOGroupData>) -> UnsafeMutablePointer<MetaObjectPtr?> {
    UnsafeMutableRawPointer(groupData.pointer(to: \.groupContents)!).assumingMemoryBound(to: MetaObjectPtr?.self)
}

@inline(__always) private func matrixFloatBase(_ matrix: inout OGLMatrix4x4) -> UnsafeMutablePointer<Float> {
    withUnsafeMutablePointer(to: &matrix) {
        UnsafeMutableRawPointer($0).assumingMemoryBound(to: Float.self)
    }
}

func InitShardSystem() {
    gEngine.shards.numShards = 0

    for i in 0..<maxShards {
        gEngine.shards.pool[i].isUsed = false
    }

    // MAKE DUMMY OBJECT

    var def = NewObjectDefinitionType()
    def.genre = UInt8(CUSTOM_GENRE)
    def.slot = Int16(PARTICLE_SLOT - 1)
    def.scale = 1
    def.flags = UInt32(STATUS_BIT_DOUBLESIDED)
    def.moveCall = cMoveShards
    def.drawCall = cDrawShards
    MakeNewObject(&def)
}

private func findFreeShard() -> Int {
    if gEngine.shards.numShards >= maxShards {
        return -1
    }

    for i in 0..<maxShards {
        if !gEngine.shards.pool[i].isUsed {
            return i
        }
    }

    return -1
}

private func updateShardTransformMatrix(_ shard: inout ShardType) {
    var m1 = OGLMatrix4x4()
    var m2 = OGLMatrix4x4()

    // SET SCALE MATRIX

    shard.matrix.setScale(shard.scale, shard.scale, shard.scale)

    // NOW ROTATE IT

    m1.setRotateXYZ(shard.rot.x, shard.rot.y, shard.rot.z)
    m2 = shard.matrix.multiplied(by: m1)

    // NOW TRANSLATE IT

    m1.setTranslate(shard.coord.x, shard.coord.y, shard.coord.z)
    shard.matrix = m2.multiplied(by: m1)
}

func ExplodeGeometry(_ theNode: UnsafeMutablePointer<ObjNode>!, _ boomForce: Float, _ particleMode: ShardMode, _ particleDensity: Int, _ particleDecaySpeed: Float) {
    gEngine.shards.srcObj = theNode
    gEngine.shards.boomForce = boomForce
    gEngine.shards.mode = particleMode
    gEngine.shards.density = particleDensity
    gEngine.shards.decaySpeed = particleDecaySpeed
    gEngine.shards.workMatrix.setIdentity() // init to identity matrix

    // SKELETON

    if theNode.pointee.Genre == UInt32(SKELETON_GENRE) {
        let buffNum = Int(gGameViewInfoPtr!.pointee.frameCount & 1)
        let skeleton = theNode.pointee.Skeleton!
        let numMeshes = Int(skeleton.pointee.skeletonDefinition!.pointee.numDecomposedTriMeshes)
        let meshes = deformedMeshesBase(skeleton) + (buffNum * Int(MAX_DECOMPOSED_TRIMESHES))
        let overrideTextures = overrideTextureBase(skeleton)

        for i in 0..<numMeshes {
            explodeVertexArray(meshes + i, overrideTextures[i]) // explode each trimesh individually
        }
    }

    // DISPLAY GROUP

    else if theNode.pointee.Genre == UInt32(DISPLAY_GROUP_GENRE) {
        let theObject = theNode.pointee.BaseGroup
        explodeGeometryRecurse(theObject)
    }

    // SUBRECURSE CHAINS

    if let chainNode = theNode.pointee.ChainNode {
        ExplodeGeometry(chainNode, boomForce, particleMode, particleDensity, particleDecaySpeed)
    }
}

private func explodeGeometryRecurse(_ obj: MetaObjectPtr?) {
    guard let obj else { return }

    let objHead = obj.assumingMemoryBound(to: MetaObjectHeader.self)

    // VERIFY COOKIE

    if objHead.pointee.cookie != MO_COOKIE {
        SwFatal("ExplodeGeometry_Recurse: cookie is invalid!")
    }

    // HANDLE TYPE

    switch objHead.pointee.type {
    case .geometry:
        switch Int32(objHead.pointee.subType) {
        case Int32(MO_GEOMETRY_SUBTYPE_VERTEXARRAY):
            let vaData = obj.assumingMemoryBound(to: MOVertexArrayObject.self).pointer(to: \.objectData)!
            explodeVertexArray(vaData, nil)

        default:
            SwFatal("ExplodeGeometry_Recurse: unknown sub-type!")
        }

    case .material:
        break

    case .group:
        let groupObj = obj.assumingMemoryBound(to: MOGroupObject.self)
        let groupData = groupObj.pointer(to: \.objectData)!
        let stashMatrix = gEngine.shards.workMatrix // push matrix

        let numChildren = Int(groupData.pointee.numObjectsInGroup) // get # objects in group
        let contents = groupContentsBase(groupData)
        for i in 0..<numChildren { // scan all objects in group
            explodeGeometryRecurse(contents[i]) // sub-recurse this object
        }

        gEngine.shards.workMatrix = stashMatrix // pop matrix

    case .matrix:
        let matObj = obj.assumingMemoryBound(to: MOMatrixObject.self)
        let transform = matObj.pointer(to: \.matrix)! // point to matrix
        var currentMatrix = gEngine.shards.workMatrix
        var multipliedMatrix = OGLMatrix4x4()
        multipliedMatrix = transform.pointee.multiplied(by: currentMatrix) // multiply it in
        gEngine.shards.workMatrix = multipliedMatrix

    default:
        break
    }
}

private func explodeVertexArray(_ data: UnsafeMutablePointer<MOVertexArrayData>, _ overrideTexture: UnsafeMutablePointer<MOMaterialObject>?) {
    var centerPt = OGLPoint3D(x: 0, y: 0, z: 0)
    var origin = OGLPoint3D()
    let boomForce = gEngine.shards.boomForce
    let shardSrcObj = gEngine.shards.srcObj!

    origin.x = shardSrcObj.pointee.Coord.x + (shardSrcObj.pointee.LocalBBox.max.x + shardSrcObj.pointee.LocalBBox.min.x) * 0.5 // set origin to center of object's bbox
    origin.y = shardSrcObj.pointee.Coord.y + (shardSrcObj.pointee.LocalBBox.max.y + shardSrcObj.pointee.LocalBBox.min.y) * 0.5
    origin.z = shardSrcObj.pointee.Coord.z + (shardSrcObj.pointee.LocalBBox.max.z + shardSrcObj.pointee.LocalBBox.min.z) * 0.5

    // SCAN THRU ALL TRIANGLES

    var t = 0
    while t < Int(data.pointee.numTriangles) { // scan thru all triangles
        // GET FREE PARTICLE INDEX

        let i = findFreeShard()
        if i == -1 { // see if all out
            break
        }

        // DO POINTS

        let triangle = data.pointee.triangles! + t
        let indices = vertexIndicesBase(triangle)
        let ind0 = Int(indices[0]) // get indices of 3 points
        let ind1 = Int(indices[1])
        let ind2 = Int(indices[2])

        gEngine.shards.pool[i].points[0] = data.pointee.points![ind0] // get coords of 3 points
        gEngine.shards.pool[i].points[1] = data.pointee.points![ind1]
        gEngine.shards.pool[i].points[2] = data.pointee.points![ind2]

        gEngine.shards.pool[i].points[0] = gEngine.shards.pool[i].points[0].transformed(by: gEngine.shards.workMatrix) // transform points
        gEngine.shards.pool[i].points[1] = gEngine.shards.pool[i].points[1].transformed(by: gEngine.shards.workMatrix)
        gEngine.shards.pool[i].points[2] = gEngine.shards.pool[i].points[2].transformed(by: gEngine.shards.workMatrix)

        centerPt.x = (gEngine.shards.pool[i].points[0].x + gEngine.shards.pool[i].points[1].x + gEngine.shards.pool[i].points[2].x) * 0.3333 // calc center of polygon
        centerPt.y = (gEngine.shards.pool[i].points[0].y + gEngine.shards.pool[i].points[1].y + gEngine.shards.pool[i].points[2].y) * 0.3333
        centerPt.z = (gEngine.shards.pool[i].points[0].z + gEngine.shards.pool[i].points[1].z + gEngine.shards.pool[i].points[2].z) * 0.3333

        gEngine.shards.pool[i].points[0].x -= centerPt.x // offset coords to be around center
        gEngine.shards.pool[i].points[0].y -= centerPt.y
        gEngine.shards.pool[i].points[0].z -= centerPt.z
        gEngine.shards.pool[i].points[1].x -= centerPt.x
        gEngine.shards.pool[i].points[1].y -= centerPt.y
        gEngine.shards.pool[i].points[1].z -= centerPt.z
        gEngine.shards.pool[i].points[2].x -= centerPt.x
        gEngine.shards.pool[i].points[2].y -= centerPt.y
        gEngine.shards.pool[i].points[2].z -= centerPt.z

        // DO VERTEX UV'S

        let uvPtr = vertexArrayUVsBase(data)[0]
        if let uvPtr { // see if also has UV (texture layer 0 only!)
            gEngine.shards.pool[i].uvs[0] = uvPtr[ind0] // get vertex u/v's
            gEngine.shards.pool[i].uvs[1] = uvPtr[ind1]
            gEngine.shards.pool[i].uvs[2] = uvPtr[ind2]
        }

        // DO MATERIAL INFO

        if let overrideTexture {
            gEngine.shards.pool[i].material = overrideTexture
        } else {
            if data.pointee.numMaterials > 0 {
                gEngine.shards.pool[i].material = vertexArrayMaterialsBase(data)[0] // keep material ptr
            } else {
                gEngine.shards.pool[i].material = nil
            }
        }

        gEngine.shards.pool[i].colorFilter = shardSrcObj.pointee.ColorFilter // keep color
        gEngine.shards.pool[i].glow = shardSrcObj.pointee.StatusBits & UInt32(STATUS_BIT_GLOW)

        // SET PHYSICS STUFF

        gEngine.shards.pool[i].coord = centerPt
        gEngine.shards.pool[i].rot.x = 0
        gEngine.shards.pool[i].rot.y = 0
        gEngine.shards.pool[i].rot.z = 0
        gEngine.shards.pool[i].scale = 1.0

        if gEngine.shards.mode.contains(.fromOrigin) { // see if random deltas or from origin
            var v = OGLVector3D()

            v.x = centerPt.x - origin.x // calc vector from object's origin
            v.y = centerPt.y - origin.y
            v.z = centerPt.z - origin.z
            FastNormalizeVector(v.x, v.y, v.z, &v)

            gEngine.shards.pool[i].coordDelta.x = v.x * boomForce
            gEngine.shards.pool[i].coordDelta.y = v.y * boomForce
            gEngine.shards.pool[i].coordDelta.z = v.z * boomForce
        } else {
            gEngine.shards.pool[i].coordDelta.x = RandomFloat2() * boomForce
            gEngine.shards.pool[i].coordDelta.y = RandomFloat2() * boomForce
            gEngine.shards.pool[i].coordDelta.z = RandomFloat2() * boomForce
        }

        if gEngine.shards.mode.contains(.upthrust) {
            gEngine.shards.pool[i].coordDelta.y += 1.5 * gEngine.shards.boomForce
        }

        gEngine.shards.pool[i].rotDelta.x = RandomFloat2() * (boomForce * 0.008) // random rotation deltas
        gEngine.shards.pool[i].rotDelta.y = RandomFloat2() * (boomForce * 0.008)
        gEngine.shards.pool[i].rotDelta.z = RandomFloat2() * (boomForce * 0.008)

        gEngine.shards.pool[i].decaySpeed = gEngine.shards.decaySpeed
        gEngine.shards.pool[i].mode = gEngine.shards.mode

        // SET INITIAL XFORM MATRIX

        updateShardTransformMatrix(&gEngine.shards.pool[i])

        // SET VALID & INC COUNTER

        gEngine.shards.pool[i].isUsed = true
        gEngine.shards.numShards += 1

        t += gEngine.shards.density
    }
}

private let cMoveShards: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { _ in
    if gEngine.shards.numShards == 0 { // quick check if any particles at all
        return
    }

    let fps = gFramesPerSecondFrac

    for i in 0..<maxShards {
        if !gEngine.shards.pool[i].isUsed {
            continue
        }

        // ROTATE IT

        gEngine.shards.pool[i].rot.x += gEngine.shards.pool[i].rotDelta.x * fps
        gEngine.shards.pool[i].rot.y += gEngine.shards.pool[i].rotDelta.y * fps
        gEngine.shards.pool[i].rot.z += gEngine.shards.pool[i].rotDelta.z * fps

        // MOVE IT

        if gEngine.shards.pool[i].mode.contains(.heavyGravity) {
            gEngine.shards.pool[i].coordDelta.y -= fps * 1000.0 // gravity
        } else {
            gEngine.shards.pool[i].coordDelta.y -= fps * 300.0 // gravity
        }

        gEngine.shards.pool[i].coord.x += gEngine.shards.pool[i].coordDelta.x * fps
        gEngine.shards.pool[i].coord.y += gEngine.shards.pool[i].coordDelta.y * fps
        gEngine.shards.pool[i].coord.z += gEngine.shards.pool[i].coordDelta.z * fps
        let x = gEngine.shards.pool[i].coord.x
        let y = gEngine.shards.pool[i].coord.y
        let z = gEngine.shards.pool[i].coord.z

        // SEE IF BOUNCE

        let ty = GetTerrainY(x, z) // get terrain height here
        if y <= ty {
            if gEngine.shards.pool[i].mode.contains(.bounce) {
                gEngine.shards.pool[i].coord.y = ty
                gEngine.shards.pool[i].coordDelta.y *= -0.5
                gEngine.shards.pool[i].coordDelta.x *= 0.9
                gEngine.shards.pool[i].coordDelta.z *= 0.9
            } else {
                gEngine.shards.pool[i].isUsed = false
                gEngine.shards.numShards -= 1
                continue
            }
        }

        // SCALE IT

        gEngine.shards.pool[i].scale -= gEngine.shards.pool[i].decaySpeed * fps
        if gEngine.shards.pool[i].scale <= 0.0 {
            // DEACTIVATE THIS PARTICLE

            gEngine.shards.pool[i].isUsed = false
            gEngine.shards.numShards -= 1
            continue
        }

        // UPDATE TRANSFORM MATRIX

        updateShardTransformMatrix(&gEngine.shards.pool[i])
    }
}

private let cDrawShards: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { _ in
    if gEngine.shards.numShards == 0 { // quick check if any particles at all
        return
    }

    // SET STATE

    gEngine.renderer.setTwoSidedLighting(true)

    for i in 0..<maxShards {
        if gEngine.shards.pool[i].isUsed {
            // SUBMIT MATERIAL

            gEngine.metaObjects.globalColorFilter.r = gEngine.shards.pool[i].colorFilter.r
            gEngine.metaObjects.globalColorFilter.g = gEngine.shards.pool[i].colorFilter.g
            gEngine.metaObjects.globalColorFilter.b = gEngine.shards.pool[i].colorFilter.b
            gEngine.metaObjects.globalTransparency = gEngine.shards.pool[i].colorFilter.a

            if gEngine.shards.pool[i].glow != 0 {
                OGL_BlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE))
            } else {
                OGL_BlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
            }

            if let material = gEngine.shards.pool[i].material {
                MO_DrawMaterial(material)
            }

            // SET MATRIX

            gEngine.renderer.pushMatrix()
            gEngine.renderer.multMatrix(matrixFloatBase(&gEngine.shards.pool[i].matrix))

            // DRAW THE TRIANGLE

            gEngine.renderer.beginImmediate(.triangles)
            gEngine.renderer.texCoord2f(gEngine.shards.pool[i].uvs[0].u, gEngine.shards.pool[i].uvs[0].v); gEngine.renderer.vertex3f(gEngine.shards.pool[i].points[0].x, gEngine.shards.pool[i].points[0].y, gEngine.shards.pool[i].points[0].z)
            gEngine.renderer.texCoord2f(gEngine.shards.pool[i].uvs[1].u, gEngine.shards.pool[i].uvs[1].v); gEngine.renderer.vertex3f(gEngine.shards.pool[i].points[1].x, gEngine.shards.pool[i].points[1].y, gEngine.shards.pool[i].points[1].z)
            gEngine.renderer.texCoord2f(gEngine.shards.pool[i].uvs[2].u, gEngine.shards.pool[i].uvs[2].v); gEngine.renderer.vertex3f(gEngine.shards.pool[i].points[2].x, gEngine.shards.pool[i].points[2].y, gEngine.shards.pool[i].points[2].z)
            gEngine.renderer.endImmediate()

            gEngine.renderer.popMatrix()
        }
    }

    // CLEANUP

    gEngine.metaObjects.globalColorFilter.r = 1
    gEngine.metaObjects.globalColorFilter.g = 1
    gEngine.metaObjects.globalColorFilter.b = 1
    gEngine.metaObjects.globalTransparency = 1
    OGL_BlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
    gEngine.renderer.setTwoSidedLighting(false)
}
