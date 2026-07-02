// QuadMesh.swift - Port of QuadMesh.c to Swift

@c @implementation
public func ReallocateQuadMesh(_ mesh: UnsafeMutablePointer<MOVertexArrayData>, _ numQuads: Int32) {
    if mesh.pointee.points != nil {
        SafeDisposePtr(UnsafeMutableRawPointer(mesh.pointee.points))
        mesh.pointee.points = nil
        mesh.pointee.pointCapacity = 0
        mesh.pointee.numPoints = 0
    }

    if mesh.pointee.uvs.0 != nil {
        SafeDisposePtr(UnsafeMutableRawPointer(mesh.pointee.uvs.0))
        mesh.pointee.uvs.0 = nil
    }

    if mesh.pointee.triangles != nil {
        SafeDisposePtr(UnsafeMutableRawPointer(mesh.pointee.triangles))
        mesh.pointee.triangles = nil
        mesh.pointee.triangleCapacity = 0
        mesh.pointee.numTriangles = 0
    }

    let numPoints = numQuads * 4
    let numTriangles = numQuads * 2

    if numQuads != 0 {
        mesh.pointee.numMaterials = 1
        mesh.pointee.points = AllocPtrClear(MemoryLayout<OGLPoint3D>.size * Int(numPoints))!.assumingMemoryBound(to: OGLPoint3D.self)
        mesh.pointee.uvs.0 = AllocPtrClear(MemoryLayout<OGLTextureCoord>.size * Int(numPoints))!.assumingMemoryBound(to: OGLTextureCoord.self)
        mesh.pointee.triangles = AllocPtrClear(MemoryLayout<MOTriangleIndecies>.size * Int(numTriangles))!.assumingMemoryBound(to: MOTriangleIndecies.self)

        mesh.pointee.pointCapacity = numPoints
        mesh.pointee.triangleCapacity = numTriangles

        // Prep triangle-vertex assignments, which never change
        var t: Int32 = 0
        var p: Int32 = 0
        while p < numPoints {
            mesh.pointee.triangles[Int(t + 0)].vertexIndices.0 = UInt32(p + 0)
            mesh.pointee.triangles[Int(t + 0)].vertexIndices.1 = UInt32(p + 1)
            mesh.pointee.triangles[Int(t + 0)].vertexIndices.2 = UInt32(p + 2)
            mesh.pointee.triangles[Int(t + 1)].vertexIndices.0 = UInt32(p + 2)
            mesh.pointee.triangles[Int(t + 1)].vertexIndices.1 = UInt32(p + 3)
            mesh.pointee.triangles[Int(t + 1)].vertexIndices.2 = UInt32(p + 0)
            p += 4; t += 2
        }
    }
}

@c @implementation
public func GetQuadMeshWithin(_ theNode: UnsafeMutablePointer<ObjNode>) -> UnsafeMutablePointer<MOVertexArrayData> {
    SwGameAssert(theNode.pointee.Genre == UInt8(TEXTMESH_GENRE) || theNode.pointee.Genre == UInt8(QUADMESH_GENRE))
    SwGameAssert(theNode.pointee.BaseGroup != nil)
    SwGameAssert(theNode.pointee.BaseGroup!.pointee.objectData.numObjectsInGroup >= 2)

    let metaObjectHeader = theNode.pointee.BaseGroup!.pointee.objectData.groupContents.1!
    let vertexObject = UnsafeMutableRawPointer(metaObjectHeader).assumingMemoryBound(to: MOVertexArrayObject.self)

    SwGameAssert(metaObjectHeader.pointee.type == .geometry)
    SwGameAssert(metaObjectHeader.pointee.subType == MO_GEOMETRY_SUBTYPE_VERTEXARRAY)

    return vertexObject.pointer(to: \.objectData)!
}

@c @implementation
public func MakeQuadMeshObject(_ newObjDef: UnsafeMutablePointer<NewObjectDefinitionType>, _ quadCapacity: Int32, _ material: UnsafeMutablePointer<MOMaterialObject>?) -> UnsafeMutablePointer<ObjNode> {
    // If no material was given, make a blank material
    var ownMaterial = false
    var material = material
    if material == nil {
        var matData = MOMaterialData()
        matData.flags = 0 // not textured
        matData.numMipmaps = 0
        matData.diffuseColor = OGLColorRGBA(r: 1, g: 1, b: 1, a: 1)
        material = MO_CreateNewObjectOfType(.material, 0, &matData)!.assumingMemoryBound(to: MOMaterialObject.self)
        ownMaterial = true
    }

    if newObjDef.pointee.genre == UInt8(ILLEGAL_GENRE) {
        newObjDef.pointee.genre = UInt8(QUADMESH_GENRE) // Force genre to QUADMESH
    }

    // Create object
    let textNode = MakeNewObject(newObjDef)!

    // Create mesh
    var mesh = MOVertexArrayData()
    mesh.VARtype = -1
    mesh.numMaterials = 1
    mesh.materials = (material, nil)
    ReallocateQuadMesh(&mesh, quadCapacity)
    let meshMO = MO_CreateNewObjectOfType(.geometry, MO_GEOMETRY_SUBTYPE_VERTEXARRAY, &mesh)

    // Attach color mesh
    CreateBaseGroup(textNode)
    AttachGeometryToDisplayGroupObject(textNode, meshMO)

    // Dispose of extra reference to mesh
    MO_DisposeObjectReference(meshMO)

    // Dispose of extra reference to material that we've created
    if ownMaterial {
        MO_DisposeObjectReference(UnsafeMutableRawPointer(material))
        material = nil
    }

    UpdateObjectTransforms(textNode)

    return textNode
}
