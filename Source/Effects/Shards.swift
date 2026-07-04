// Shards.swift - Port of Shards.c to Swift

private let maxShards = 2500

private struct ShardType {
    var isUsed: UInt8 = 0
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

private var gNumShards = 0
private var gShards: InlineArray<2500, ShardType> = InlineArray(repeating: ShardType())

private var gBoomForce: Float = 0
private var gShardDecaySpeed: Float = 0
private var gShardMode: ShardMode = []
private var gShardDensity = 0
private var gWorkMatrix = OGLMatrix4x4()
private var gShardSrcObj: UnsafeMutablePointer<ObjNode>?

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

@c @implementation
public func InitShardSystem() {
    gNumShards = 0

    for i in 0..<maxShards {
        gShards[i].isUsed = 0
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
    if gNumShards >= maxShards {
        return -1
    }

    for i in 0..<maxShards {
        if gShards[i].isUsed == 0 {
            return i
        }
    }

    return -1
}

private func updateShardTransformMatrix(_ shard: inout ShardType) {
    var m1 = OGLMatrix4x4()
    var m2 = OGLMatrix4x4()

    // SET SCALE MATRIX

    OGLMatrix4x4_SetScale(&shard.matrix, shard.scale, shard.scale, shard.scale)

    // NOW ROTATE IT

    OGLMatrix4x4_SetRotate_XYZ(&m1, shard.rot.x, shard.rot.y, shard.rot.z)
    OGLMatrix4x4_Multiply(&shard.matrix, &m1, &m2)

    // NOW TRANSLATE IT

    OGLMatrix4x4_SetTranslate(&m1, shard.coord.x, shard.coord.y, shard.coord.z)
    OGLMatrix4x4_Multiply(&m2, &m1, &shard.matrix)
}

@c @implementation
public func ExplodeGeometry(_ theNode: UnsafeMutablePointer<ObjNode>!, _ boomForce: Float, _ particleMode: ShardMode, _ particleDensity: Int, _ particleDecaySpeed: Float) {
    gShardSrcObj = theNode
    gBoomForce = boomForce
    gShardMode = particleMode
    gShardDensity = particleDensity
    gShardDecaySpeed = particleDecaySpeed
    OGLMatrix4x4_SetIdentity(&gWorkMatrix) // init to identity matrix

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
        let stashMatrix = gWorkMatrix // push matrix

        let numChildren = Int(groupData.pointee.numObjectsInGroup) // get # objects in group
        let contents = groupContentsBase(groupData)
        for i in 0..<numChildren { // scan all objects in group
            explodeGeometryRecurse(contents[i]) // sub-recurse this object
        }

        gWorkMatrix = stashMatrix // pop matrix

    case .matrix:
        let matObj = obj.assumingMemoryBound(to: MOMatrixObject.self)
        let transform = matObj.pointer(to: \.matrix)! // point to matrix
        var currentMatrix = gWorkMatrix
        var multipliedMatrix = OGLMatrix4x4()
        OGLMatrix4x4_Multiply(transform, &currentMatrix, &multipliedMatrix) // multiply it in
        gWorkMatrix = multipliedMatrix

    default:
        break
    }
}

private func explodeVertexArray(_ data: UnsafeMutablePointer<MOVertexArrayData>, _ overrideTexture: UnsafeMutablePointer<MOMaterialObject>?) {
    var centerPt = OGLPoint3D(x: 0, y: 0, z: 0)
    var origin = OGLPoint3D()
    let boomForce = gBoomForce
    let shardSrcObj = gShardSrcObj!

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

        gShards[i].points[0] = data.pointee.points![ind0] // get coords of 3 points
        gShards[i].points[1] = data.pointee.points![ind1]
        gShards[i].points[2] = data.pointee.points![ind2]

        gShards[i].points[0] = gShards[i].points[0].transformed(by: gWorkMatrix) // transform points
        gShards[i].points[1] = gShards[i].points[1].transformed(by: gWorkMatrix)
        gShards[i].points[2] = gShards[i].points[2].transformed(by: gWorkMatrix)

        centerPt.x = (gShards[i].points[0].x + gShards[i].points[1].x + gShards[i].points[2].x) * 0.3333 // calc center of polygon
        centerPt.y = (gShards[i].points[0].y + gShards[i].points[1].y + gShards[i].points[2].y) * 0.3333
        centerPt.z = (gShards[i].points[0].z + gShards[i].points[1].z + gShards[i].points[2].z) * 0.3333

        gShards[i].points[0].x -= centerPt.x // offset coords to be around center
        gShards[i].points[0].y -= centerPt.y
        gShards[i].points[0].z -= centerPt.z
        gShards[i].points[1].x -= centerPt.x
        gShards[i].points[1].y -= centerPt.y
        gShards[i].points[1].z -= centerPt.z
        gShards[i].points[2].x -= centerPt.x
        gShards[i].points[2].y -= centerPt.y
        gShards[i].points[2].z -= centerPt.z

        // DO VERTEX UV'S

        let uvPtr = vertexArrayUVsBase(data)[0]
        if let uvPtr { // see if also has UV (texture layer 0 only!)
            gShards[i].uvs[0] = uvPtr[ind0] // get vertex u/v's
            gShards[i].uvs[1] = uvPtr[ind1]
            gShards[i].uvs[2] = uvPtr[ind2]
        }

        // DO MATERIAL INFO

        if let overrideTexture {
            gShards[i].material = overrideTexture
        } else {
            if data.pointee.numMaterials > 0 {
                gShards[i].material = vertexArrayMaterialsBase(data)[0] // keep material ptr
            } else {
                gShards[i].material = nil
            }
        }

        gShards[i].colorFilter = shardSrcObj.pointee.ColorFilter // keep color
        gShards[i].glow = shardSrcObj.pointee.StatusBits & UInt32(STATUS_BIT_GLOW)

        // SET PHYSICS STUFF

        gShards[i].coord = centerPt
        gShards[i].rot.x = 0
        gShards[i].rot.y = 0
        gShards[i].rot.z = 0
        gShards[i].scale = 1.0

        if gShardMode.contains(.fromOrigin) { // see if random deltas or from origin
            var v = OGLVector3D()

            v.x = centerPt.x - origin.x // calc vector from object's origin
            v.y = centerPt.y - origin.y
            v.z = centerPt.z - origin.z
            FastNormalizeVector(v.x, v.y, v.z, &v)

            gShards[i].coordDelta.x = v.x * boomForce
            gShards[i].coordDelta.y = v.y * boomForce
            gShards[i].coordDelta.z = v.z * boomForce
        } else {
            gShards[i].coordDelta.x = RandomFloat2() * boomForce
            gShards[i].coordDelta.y = RandomFloat2() * boomForce
            gShards[i].coordDelta.z = RandomFloat2() * boomForce
        }

        if gShardMode.contains(.upthrust) {
            gShards[i].coordDelta.y += 1.5 * gBoomForce
        }

        gShards[i].rotDelta.x = RandomFloat2() * (boomForce * 0.008) // random rotation deltas
        gShards[i].rotDelta.y = RandomFloat2() * (boomForce * 0.008)
        gShards[i].rotDelta.z = RandomFloat2() * (boomForce * 0.008)

        gShards[i].decaySpeed = gShardDecaySpeed
        gShards[i].mode = gShardMode

        // SET INITIAL XFORM MATRIX

        updateShardTransformMatrix(&gShards[i])

        // SET VALID & INC COUNTER

        gShards[i].isUsed = 1
        gNumShards += 1

        t += gShardDensity
    }
}

private let cMoveShards: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { _ in
    if gNumShards == 0 { // quick check if any particles at all
        return
    }

    let fps = gFramesPerSecondFrac

    for i in 0..<maxShards {
        if gShards[i].isUsed == 0 {
            continue
        }

        // ROTATE IT

        gShards[i].rot.x += gShards[i].rotDelta.x * fps
        gShards[i].rot.y += gShards[i].rotDelta.y * fps
        gShards[i].rot.z += gShards[i].rotDelta.z * fps

        // MOVE IT

        if gShards[i].mode.contains(.heavyGravity) {
            gShards[i].coordDelta.y -= fps * 1000.0 // gravity
        } else {
            gShards[i].coordDelta.y -= fps * 300.0 // gravity
        }

        gShards[i].coord.x += gShards[i].coordDelta.x * fps
        gShards[i].coord.y += gShards[i].coordDelta.y * fps
        gShards[i].coord.z += gShards[i].coordDelta.z * fps
        let x = gShards[i].coord.x
        let y = gShards[i].coord.y
        let z = gShards[i].coord.z

        // SEE IF BOUNCE

        let ty = GetTerrainY(x, z) // get terrain height here
        if y <= ty {
            if gShards[i].mode.contains(.bounce) {
                gShards[i].coord.y = ty
                gShards[i].coordDelta.y *= -0.5
                gShards[i].coordDelta.x *= 0.9
                gShards[i].coordDelta.z *= 0.9
            } else {
                gShards[i].isUsed = 0
                gNumShards -= 1
                continue
            }
        }

        // SCALE IT

        gShards[i].scale -= gShards[i].decaySpeed * fps
        if gShards[i].scale <= 0.0 {
            // DEACTIVATE THIS PARTICLE

            gShards[i].isUsed = 0
            gNumShards -= 1
            continue
        }

        // UPDATE TRANSFORM MATRIX

        updateShardTransformMatrix(&gShards[i])
    }
}

private let cDrawShards: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { _ in
    if gNumShards == 0 { // quick check if any particles at all
        return
    }

    // SET STATE

    glLightModeli(GLenum(GL_LIGHT_MODEL_TWO_SIDE), GL_TRUE)

    for i in 0..<maxShards {
        if gShards[i].isUsed != 0 {
            // SUBMIT MATERIAL

            gGlobalColorFilter.r = gShards[i].colorFilter.r
            gGlobalColorFilter.g = gShards[i].colorFilter.g
            gGlobalColorFilter.b = gShards[i].colorFilter.b
            gGlobalTransparency = gShards[i].colorFilter.a

            if gShards[i].glow != 0 {
                OGL_BlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE))
            } else {
                OGL_BlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
            }

            if let material = gShards[i].material {
                MO_DrawMaterial(material)
            }

            // SET MATRIX

            glPushMatrix()
            glMultMatrixf(matrixFloatBase(&gShards[i].matrix))

            // DRAW THE TRIANGLE

            glBegin(GLenum(GL_TRIANGLES))
            glTexCoord2f(gShards[i].uvs[0].u, gShards[i].uvs[0].v); glVertex3f(gShards[i].points[0].x, gShards[i].points[0].y, gShards[i].points[0].z)
            glTexCoord2f(gShards[i].uvs[1].u, gShards[i].uvs[1].v); glVertex3f(gShards[i].points[1].x, gShards[i].points[1].y, gShards[i].points[1].z)
            glTexCoord2f(gShards[i].uvs[2].u, gShards[i].uvs[2].v); glVertex3f(gShards[i].points[2].x, gShards[i].points[2].y, gShards[i].points[2].z)
            glEnd()

            glPopMatrix()
        }
    }

    // CLEANUP

    gGlobalColorFilter.r = 1
    gGlobalColorFilter.g = 1
    gGlobalColorFilter.b = 1
    gGlobalTransparency = 1
    OGL_BlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
    glLightModeli(GLenum(GL_LIGHT_MODEL_TWO_SIDE), GL_FALSE)
}
