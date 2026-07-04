// Bg3d.swift - Port of bg3d.c to Swift
//
// gBG3DContainerList/gBG3DGroupList/gNumObjectsInBG3DGroupList/
// gObjectGroupBBoxList/gObjectGroupBSphereList stay defined in bg3d.c and
// `extern`'d via game.h/BonesInternal.h: Items.c, Terrain.c, and Player.c
// (still unported), plus already-ported Bones.swift, read/write them
// directly. Swift accesses them through the Get*/Set* shims in
// ObjectsInternal.h/BonesInternal.h since Swift can't dynamically index a
// fixed-size (or 2D fixed-size) C array.
//
// Everything else here (gBG3D_* state, the group stack) was `static`
// (file-private) in C, so it moves into private Swift state instead.

private let BG3D_GROUP_STACK_SIZE = 50

private var gBG3D_GroupStackIndex: Int32 = 0
private var gBG3D_GroupStack = [UnsafeMutablePointer<MOGroupObject>?](repeating: nil, count: BG3D_GROUP_STACK_SIZE)
private var gBG3D_CurrentGroup: UnsafeMutablePointer<MOGroupObject>?

private var gBG3D_CurrentMaterialObj: UnsafeMutablePointer<MOMaterialObject>? // note: this variable contains an illegal ref to the object. The real ref is in the file container material list.
private var gBG3D_CurrentGeometryObj: UnsafeMutablePointer<MOVertexArrayObject>?

private var gBG3D_CurrentContainer: UnsafeMutablePointer<BG3DFileContainer>?

private var gImportBG3DVARType: Int16 = 0

private let kNoErr: OSErr = 0

// MARK: - fixed-array-field helpers (all struct fields, never unions)

@inline(__always) private func materialsBase(_ c: UnsafeMutablePointer<BG3DFileContainer>) -> UnsafeMutablePointer<UnsafeMutablePointer<MOMaterialObject>?> {
    UnsafeMutableRawPointer(c.pointer(to: \.materials)!).assumingMemoryBound(to: UnsafeMutablePointer<MOMaterialObject>?.self)
}

// Reads a whole trivial struct's worth of bytes from the file, matching the
// C idiom `count = sizeof(x); FSRead(refNum, &count, (Ptr)&x);`.
@discardableResult
private func fsReadStruct<T>(_ refNum: Int16, _ value: inout T) -> OSErr {
    var readSize = MemoryLayout<T>.size
    return withUnsafeMutablePointer(to: &value) {
        $0.withMemoryRebound(to: Int8.self, capacity: 1) {
            FSRead(refNum, &readSize, $0)
        }
    }
}

// MARK: - Init BG3D manager

func InitBG3DManager() {
    for i in 0..<Int(SwMAX_BG3D_GROUPS) {
        SetBG3DContainer(Int32(i), nil)
    }
}

// MARK: - Import BG3D
//
// NOTE: All BG3D models must be imported AFTER the draw context has been created,
// because all imported textures are named with OpenGL and loaded into OpenGL!
//
// varType == the Vertex Array Range group that we want to allocate the BG3D's vertex arrays with.
// If it is -1 then we don't want it in VAR memory.

func ImportBG3D(_ spec: UnsafeMutablePointer<FSSpec>, _ groupNum: Int32, _ varType: Int16) {
    gImportBG3DVARType = varType

    // INIT SOME VARIABLES
    gBG3D_CurrentMaterialObj = nil
    gBG3D_CurrentGeometryObj = nil
    gBG3D_GroupStackIndex = 0 // init the group stack
    initBG3DContainer()

    // OPEN THE FILE & READ
    var refNum: Int16 = 0
    if FSpOpenDF(spec, Int8(fsRdPerm.rawValue), &refNum) != kNoErr {
        SwFatal("ImportBG3D: FSpOpenDF failed")
    }

    readBG3DHeader(refNum)
    parseBG3DFile(refNum)

    // CLOSE FILE
    FSClose(refNum)

    // SETUP GROUP INFO
    //
    // A model "group" is a grouping of 3D models.

    let container = gBG3D_CurrentContainer!
    SetBG3DContainer(groupNum, container) // save container into list

    guard let rootRaw = container.pointee.root else { // point to root object in container
        SwFatal("ImportBG3D: header == nil")
        return
    }

    let header = rootRaw.assumingMemoryBound(to: MetaObjectHeader.self)
    if header.pointee.type != .group { // root should be a group
        SwFatal("ImportBG3D: root isnt a group!")
        return
    }

    // PARSE GROUP
    //
    // Create a list of all of the models inside this file & Calc bounding box

    let group = rootRaw.assumingMemoryBound(to: MOGroupObject.self)
    let numObjects = Int(group.numObjectsInGroup)

    for i in 0..<numObjects {
        let content = group.groupContent(at: i) // copy ILLEGAL ref to this object
        SetBG3DGroupObject(groupNum, Int32(i), content)

        var bbox = OGLBoundingBox()
        MO_CalcBoundingBox(content, &bbox, nil) // calc bounding box of this model
        SetObjectGroupBBox(groupNum, Int32(i), bbox)

        var bsphere: Float = 0
        MO_CalcBoundingSphere(content, &bsphere)
        SetObjectGroupBSphere(groupNum, Int32(i), bsphere)
    }

    SetNumObjectsInBG3DGroup(groupNum, Int32(numObjects))
}

// MARK: - Read BG3D header

private func readBG3DHeader(_ refNum: Int16) {
    var headerData = BG3DHeaderType()
    if fsReadStruct(refNum, &headerData) != kNoErr {
        SwFatal("ReadBG3DHeader: FSRead failed")
    }

    // VERIFY FILE
    let hs = headerData.headerString
    if hs.0 != 66 || hs.1 != 71 || hs.2 != 51 || hs.3 != 68 { // 'B' 'G' '3' 'D'
        SwFatal("ReadBG3DHeader: BG3D file has invalid header.")
    }
}

// MARK: - Parse BG3D file

private func parseBG3DFile(_ refNum: Int16) {
    var done = false

    repeat {
        // READ A TAG
        var tag: UInt32 = 0
        if fsReadStruct(refNum, &tag) != kNoErr {
            SwFatal("ParseBG3DFile: FSRead failed")
        }

        tag = SwizzleULong(&tag)

        // HANDLE THE TAG
        switch tag {
        case UInt32(BG3D_TAGTYPE_MATERIALFLAGS):
            readMaterialFlags(refNum)

        case UInt32(BG3D_TAGTYPE_MATERIALDIFFUSECOLOR):
            readMaterialDiffuseColor(refNum)

        case UInt32(BG3D_TAGTYPE_TEXTUREMAP):
            readMaterialTextureMap(refNum)

        case UInt32(BG3D_TAGTYPE_GROUPSTART):
            readGroup()

        case UInt32(BG3D_TAGTYPE_GROUPEND):
            endGroup()

        case UInt32(BG3D_TAGTYPE_GEOMETRY):
            let newObj = readNewGeometry(refNum)
            if let currentGroup = gBG3D_CurrentGroup { // add new geometry to current group
                UnsafeMutableRawPointer(currentGroup).append(newObj)
                MO_DisposeObjectReference(newObj) // nuke the extra reference
            }

        case UInt32(BG3D_TAGTYPE_VERTEXARRAY):
            readVertexArray(refNum)

        case UInt32(BG3D_TAGTYPE_NORMALARRAY):
            readNormalArray(refNum)

        case UInt32(BG3D_TAGTYPE_UVARRAY):
            readUVArray(refNum)

        case UInt32(BG3D_TAGTYPE_COLORARRAY):
            readVertexColorArray(refNum)

        case UInt32(BG3D_TAGTYPE_TRIANGLEARRAY):
            readTriangleArray(refNum)

        case UInt32(BG3D_TAGTYPE_BOUNDINGBOX):
            readBoundingBox(refNum)

        case UInt32(BG3D_TAGTYPE_JPEGTEXTURE):
            readMaterialJPEGTextureMap(refNum)

        case UInt32(BG3D_TAGTYPE_ENDFILE):
            done = true

        default:
            SwFatal("ParseBG3DFile: unrecognized tag")
        }
    } while !done
}

// MARK: - Read material flags
//
// Reading new material flags indicatest the start of a new material.

private func readMaterialFlags(_ refNum: Int16) {
    // READ FLAGS
    var flags: UInt32 = 0
    if fsReadStruct(refNum, &flags) != kNoErr {
        SwFatal("ReadMaterialFlags: FSRead failed")
    }

    flags = SwizzleULong(&flags)

    // INIT NEW MATERIAL DATA
    var data = MOMaterialData()
    data.flags = flags
    data.multiTextureMode = UInt16(MULTI_TEXTURE_MODE_REFLECTIONSPHERE)
    data.multiTextureCombine = UInt16(MULTI_TEXTURE_COMBINE_MODULATE)
    data.envMapNum = 0
    data.diffuseColor = OGLColorRGBA(r: 1, g: 1, b: 1, a: 1)
    data.numMipmaps = 0 // there are currently 0 textures assigned to this material

    // CREATE NEW MATERIAL OBJECT
    gBG3D_CurrentMaterialObj = MO_CreateNewObjectOfType(.material, 0, &data)?.assumingMemoryBound(to: MOMaterialObject.self)

    // ADD THIS MATERIAL TO THE FILE CONTAINER
    let container = gBG3D_CurrentContainer!
    let i = Int(container.pointee.numMaterials) // get index into file container's material list
    container.pointee.numMaterials += 1

    materialsBase(container)[i] = gBG3D_CurrentMaterialObj // stores the 1 reference here.
}

// MARK: - Read material diffuse color

private func readMaterialDiffuseColor(_ refNum: Int16) {
    guard let matObj = gBG3D_CurrentMaterialObj else {
        SwFatal("ReadMaterialDiffuseColor: gBG3D_CurrentMaterialObj == nil")
        return
    }

    // READ COLOR VALUE
    var color = OGLColorRGBA()
    if fsReadStruct(refNum, &color) != kNoErr {
        SwFatal("ReadMaterialDiffuseColor: FSRead failed")
    }

    // ASSIGN COLOR TO CURRENT MATERIAL
    matObj.diffuseColor = OGLColorRGBA(
        r: SwizzleFloat(&color.r),
        g: SwizzleFloat(&color.g),
        b: SwizzleFloat(&color.b),
        a: SwizzleFloat(&color.a)
    )
}

// MARK: - Read material texture map
//
// NOTE: This may get called multiple times - once for each mipmap associated with the material.

private func readMaterialTextureMap(_ refNum: Int16) {
    // GET PTR TO CURRENT MATERIAL
    guard let matObj = gBG3D_CurrentMaterialObj else {
        SwFatal("ReadMaterialTextureMap: gBG3D_CurrentMaterialObj == nil")
        return
    }

    // READ TEXTURE HEADER
    var textureHeader = BG3DTextureHeader()
    fsReadStruct(refNum, &textureHeader) // read header

    textureHeader.width = SwizzleULong(&textureHeader.width)
    textureHeader.height = SwizzleULong(&textureHeader.height)
    textureHeader.srcPixelFormat = SwizzleLong(&textureHeader.srcPixelFormat)
    textureHeader.dstPixelFormat = SwizzleLong(&textureHeader.dstPixelFormat)
    textureHeader.bufferSize = SwizzleULong(&textureHeader.bufferSize)

    // COPY BASIC INFO
    SwGameAssert(matObj.numMipmaps < UInt32(MO_MAX_MIPMAPS)) // see if overflow

    if matObj.numMipmaps == 0 { // see if this is the first texture
        matObj.width = textureHeader.width
        matObj.height = textureHeader.height
    }

    // READ THE TEXTURE PIXELS
    var count = Int(textureHeader.bufferSize) // get size of buffer to load

    guard let texturePixels = AllocPtrClear(count) else { // alloc memory for buffer
        SwFatal("ReadMaterialTextureMap: AllocPtr failed")
        return
    }

    FSRead(refNum, &count, texturePixels.assumingMemoryBound(to: Int8.self)) // read pixel data

    // ASSIGN PIXELS TO CURRENT MATERIAL
    let i = Int(matObj.numMipmaps) // increment the mipmap count
    matObj.numMipmaps += 1

    let w = Int32(textureHeader.width)
    let h = Int32(textureHeader.height)

    // LOAD INTO OPENGL
    switch textureHeader.srcPixelFormat {
    // Source port note: most BG3Ds in Nanosaur 2 use JPEG textures;
    // the few that don't use JPEG always use GL_RGBA in practice.
    case GL_RGBA:
        matObj.setTextureName(OGL_TextureMap_Load(texturePixels, w, h, GL_RGBA, GL_RGBA, GLint(GL_UNSIGNED_BYTE)), at: i)

    // Just in case we want to import models from other games or whatever...
    case GL_UNSIGNED_SHORT_1_5_5_5_REV, // 16-bit packed pixel
         GL_UNSIGNED_INT_8_8_8_8_REV: // ARGB (standard Mac)
        // pass on format as dataType
        matObj.setTextureName(OGL_TextureMap_Load(texturePixels, w, h, GL_RGBA, GL_RGBA, textureHeader.srcPixelFormat), at: i)

    default:
        SwFatal("Unsupported BG3D srcPixelFormat")
    }

    // DISPOSE ORIGINAL PIXELS
    //
    // OpenGL now has its own copy of the texture, so we don't need ours anymore.
    SafeDisposePtr(texturePixels)
}

// MARK: - Read material JPEG texture map
//
// NOTE: This may get called multiple times - once for each mipmap associated with the material.

private func readMaterialJPEGTextureMap(_ refNum: Int16) {
    // GET PTR TO CURRENT MATERIAL
    SwGameAssert(gBG3D_CurrentMaterialObj != nil)
    let matObj = gBG3D_CurrentMaterialObj!

    // READ TEXTURE HEADER
    var textureHeader = BG3DJPEGTextureHeader()
    fsReadStruct(refNum, &textureHeader) // read header

    textureHeader.width = SwizzleULong(&textureHeader.width)
    textureHeader.height = SwizzleULong(&textureHeader.height)
    textureHeader.bufferSize = SwizzleULong(&textureHeader.bufferSize)
    textureHeader.hasAlphaChannel = SwizzleULong(&textureHeader.hasAlphaChannel)

    let w = Int32(textureHeader.width) // get dimensions of the texture
    let h = Int32(textureHeader.height)
    let hasAlpha = textureHeader.hasAlphaChannel != 0 // see if we'll need to read in the alpha channel

    // COPY BASIC INFO
    SwGameAssert(matObj.numMipmaps < UInt32(MO_MAX_MIPMAPS)) // see if overflow

    if matObj.numMipmaps == 0 { // see if this is the first texture
        matObj.width = UInt32(w)
        matObj.height = UInt32(h)
    }

    // READ THE JPEG DATA
    var textureRGBA: Ptr!

    do {
        // ALLOC BUFFER FOR JPEG DATA
        var count = Int(textureHeader.bufferSize) // get size of JPEG buffer to load
        let jpegBuffer = AllocPtrClear(count)!.assumingMemoryBound(to: Int8.self) // alloc memory for buffer

        FSRead(refNum, &count, jpegBuffer) // read JPEG data (image desc + compressed data)

        // DECOMPRESS THE IMAGE
        textureRGBA = DecompressQTImage(jpegBuffer, Int32(textureHeader.bufferSize), w, h)
        SwGameAssert(textureRGBA != nil)

        SafeDisposePtr(jpegBuffer)
    }

    // READ IN ALPHA CHANNEL IF IT HAS ONE
    if hasAlpha {
        var count = Int(w * h)
        let alphaBuffer = AllocPtrClear(count)!.assumingMemoryBound(to: UInt8.self) // alloc buffer for alpha channel
        FSRead(refNum, &count, UnsafeMutableRawPointer(alphaBuffer).assumingMemoryBound(to: Int8.self)) // read alpha buffer

        let textureAlphaBase = (UnsafeMutableRawPointer(textureRGBA) + 3).assumingMemoryBound(to: UInt8.self)
        for p in 0..<count {
            textureAlphaBase[p * 4] = alphaBuffer[p]
        }

        SafeDisposePtr(alphaBuffer)
    }

    // ASSIGN PIXELS TO CURRENT MATERIAL
    let i = Int(matObj.numMipmaps) // increment the mipmap count
    matObj.numMipmaps += 1
    matObj.setTextureName(OGL_TextureMap_Load(textureRGBA, w, h, GL_RGBA, GL_RGBA, GLint(GL_UNSIGNED_BYTE)), at: i) // load GL texture
    SafeDisposePtr(textureRGBA)
}

// MARK: - Read group
//
// Called when GROUPSTART tag is found. There must be a matching GROUPEND tag later.

private func readGroup() {
    // CREATE NEW GROUP OBJECT
    guard let newGroupRaw = MO_CreateNewObjectOfType(.group, 0, nil) else {
        SwFatal("ReadGroup: MO_CreateNewObjectOfType failed")
        return
    }
    let newGroup = newGroupRaw.assumingMemoryBound(to: MOGroupObject.self)

    // PUSH ONTO GROUP STACK
    if gBG3D_GroupStackIndex >= Int32(BG3D_GROUP_STACK_SIZE - 1) {
        SwFatal("ReadGroup: gBG3D_GroupStackIndex overflow!")
    }

    // SEE IF THIS IS FIRST GROUP
    if gBG3D_CurrentGroup == nil { // no parent
        gBG3D_CurrentContainer!.pointee.root = newGroupRaw // set container's root to this group
    }
    // ADD TO PARENT GROUP
    else {
        gBG3D_GroupStack[Int(gBG3D_GroupStackIndex)] = gBG3D_CurrentGroup // push the old group onto group stack
        gBG3D_GroupStackIndex += 1
        UnsafeMutableRawPointer(gBG3D_CurrentGroup!).append(newGroupRaw) // add new group to existing group (which creates new ref)
        MO_DisposeObjectReference(newGroupRaw) // nuke the extra reference
    }

    gBG3D_CurrentGroup = newGroup // current group == this group
}

// MARK: - End group
//
// Signifies the end of a GROUPSTART tag group.

private func endGroup() {
    gBG3D_GroupStackIndex -= 1

    if gBG3D_GroupStackIndex < 0 { // must be something on group stack
        SwFatal("EndGroup: stack is empty!")
        return
    }

    gBG3D_CurrentGroup = gBG3D_GroupStack[Int(gBG3D_GroupStackIndex)] // get previous group off of stack
}

// MARK: - Read new geometry

private func readNewGeometry(_ refNum: Int16) -> MetaObjectPtr? {
    // READ GEOMETRY HEADER
    var geoHeader = BG3DGeometryHeader()
    fsReadStruct(refNum, &geoHeader) // read header

    geoHeader.type = SwizzleULong(&geoHeader.type)
    geoHeader.numMaterials = SwizzleLong(&geoHeader.numMaterials)
    geoHeader.layerMaterialNum.0 = SwizzleULong(&geoHeader.layerMaterialNum.0)
    geoHeader.layerMaterialNum.1 = SwizzleULong(&geoHeader.layerMaterialNum.1)
    geoHeader.flags = SwizzleULong(&geoHeader.flags)
    geoHeader.numPoints = SwizzleULong(&geoHeader.numPoints)
    geoHeader.numTriangles = SwizzleULong(&geoHeader.numTriangles)

    // CREATE NEW GEOMETRY OBJECT
    switch geoHeader.type {
    // VERTEX ELEMENTS
    case UInt32(BG3D_GEOMETRYTYPE_VERTEXELEMENTS):
        return readVertexElementsGeometry(&geoHeader)

    default:
        SwFatal("ReadNewGeometry: unknown geo type")
        return nil
    }
}

// MARK: - Read vertex elements geometry

private func readVertexElementsGeometry(_ header: UnsafeMutablePointer<BG3DGeometryHeader>) -> MetaObjectPtr? {
    // SETUP DATA
    var vertexArrayData = MOVertexArrayData()

    vertexArrayData.VARtype = gImportBG3DVARType // which Vertex Array Range are we loading this into?

    vertexArrayData.numMaterials = Int16(header.pointee.numMaterials)
    vertexArrayData.numPoints = Int32(header.pointee.numPoints)
    vertexArrayData.numTriangles = Int32(header.pointee.numTriangles)
    vertexArrayData.points = nil // these arrays havnt been read in yet
    vertexArrayData.normals = nil

    vertexArrayData.uvs.0 = nil
    vertexArrayData.uvs.1 = nil

    vertexArrayData.colorsFloat = nil
    vertexArrayData.triangles = nil

    vertexArrayData.bBox.isEmpty = 1 // no bounding box assigned yet
    vertexArrayData.bBox.min.x = 0
    vertexArrayData.bBox.min.y = 0
    vertexArrayData.bBox.min.z = 0
    vertexArrayData.bBox.max.x = 0
    vertexArrayData.bBox.max.y = 0
    vertexArrayData.bBox.max.z = 0

    // SETUP MATERIAL LIST
    //
    // These start as illegal references. The ref count is incremented during the Object Creation function.
    let container = gBG3D_CurrentContainer!
    let materials = materialsBase(container)

    if vertexArrayData.numMaterials >= 1 {
        vertexArrayData.materials.0 = materials[Int(header.pointee.layerMaterialNum.0)]
    }
    if vertexArrayData.numMaterials >= 2 {
        vertexArrayData.materials.1 = materials[Int(header.pointee.layerMaterialNum.1)]
    }

    // CREATE THE NEW GEO OBJECT
    gBG3D_CurrentGeometryObj = MO_CreateNewObjectOfType(.geometry, Int(MO_GEOMETRY_SUBTYPE_VERTEXARRAY), &vertexArrayData)?.assumingMemoryBound(to: MOVertexArrayObject.self)

    return UnsafeMutableRawPointer(gBG3D_CurrentGeometryObj)
}

// MARK: - Read vertex array

private func readVertexArray(_ refNum: Int16) {
    let data = gBG3D_CurrentGeometryObj!.pointer(to: \.objectData)! // point to geometry data
    if data.pointee.points != nil { // see if points already assigned
        SwFatal("ReadVertexArray: points already assigned!")
    }

    let numPoints = Int(data.pointee.numPoints) // get # points to expect to read
    var count = MemoryLayout<OGLPoint3D>.size * numPoints // calc size of data to read

    let pointList: UnsafeMutablePointer<OGLPoint3D>
    if gImportBG3DVARType == -1 {
        pointList = AllocPtrClear(count)!.assumingMemoryBound(to: OGLPoint3D.self)
    } else {
        pointList = OGL_AllocVertexArrayMemory(count, UInt8(gImportBG3DVARType))!.assumingMemoryBound(to: OGLPoint3D.self) // alloc vertex array range buffer
    }

    FSRead(refNum, &count, UnsafeMutableRawPointer(pointList).assumingMemoryBound(to: Int8.self)) // read the data

    for i in 0..<numPoints { // swizzle
        pointList[i].x = SwizzleFloat(&pointList[i].x)
        pointList[i].y = SwizzleFloat(&pointList[i].y)
        pointList[i].z = SwizzleFloat(&pointList[i].z)
    }

    data.pointee.points = pointList // assign point array to geometry header
}

// MARK: - Read normal array

private func readNormalArray(_ refNum: Int16) {
    let data = gBG3D_CurrentGeometryObj!.pointer(to: \.objectData)! // point to geometry data
    let numPoints = Int(data.pointee.numPoints) // get # normals to expect to read

    var count = MemoryLayout<OGLVector3D>.size * numPoints // calc size of data to read

    let normalList: UnsafeMutablePointer<OGLVector3D>
    if gImportBG3DVARType == -1 {
        normalList = AllocPtrClear(count)!.assumingMemoryBound(to: OGLVector3D.self)
    } else {
        normalList = OGL_AllocVertexArrayMemory(count, UInt8(gImportBG3DVARType))!.assumingMemoryBound(to: OGLVector3D.self) // alloc vertex array range buffer
    }

    FSRead(refNum, &count, UnsafeMutableRawPointer(normalList).assumingMemoryBound(to: Int8.self)) // read the data

    for i in 0..<numPoints { // swizzle
        normalList[i].x = SwizzleFloat(&normalList[i].x)
        normalList[i].y = SwizzleFloat(&normalList[i].y)
        normalList[i].z = SwizzleFloat(&normalList[i].z)
    }

    data.pointee.normals = normalList // assign normal array to geometry header
}

// MARK: - Read UV array

private func readUVArray(_ refNum: Int16) {
    let data = gBG3D_CurrentGeometryObj!.pointer(to: \.objectData)! // point to geometry data
    let numPoints = Int(data.pointee.numPoints) // get # uv's to expect to read

    var count = MemoryLayout<OGLTextureCoord>.size * numPoints // calc size of data to read

    let uvList: UnsafeMutablePointer<OGLTextureCoord>
    if gImportBG3DVARType == -1 {
        uvList = AllocPtrClear(count)!.assumingMemoryBound(to: OGLTextureCoord.self)
    } else {
        uvList = OGL_AllocVertexArrayMemory(count, UInt8(gImportBG3DVARType))!.assumingMemoryBound(to: OGLTextureCoord.self) // alloc vertex array range buffer
    }

    FSRead(refNum, &count, UnsafeMutableRawPointer(uvList).assumingMemoryBound(to: Int8.self)) // read the data

    for i in 0..<numPoints { // swizzle
        uvList[i].u = SwizzleFloat(&uvList[i].u)
        uvList[i].v = SwizzleFloat(&uvList[i].v)
    }

    data.pointee.uvs.0 = uvList // assign uv array to geometry header
}

// MARK: - Read vertex color array
//
// NOTE: The color data in the BG3D file is always stored as Byte values since it's more compact.

private func readVertexColorArray(_ refNum: Int16) {
    let data = gBG3D_CurrentGeometryObj!.pointer(to: \.objectData)! // point to geometry data
    let numPoints = Int(data.pointee.numPoints) // get # colors to expect to read

    var count = MemoryLayout<OGLColorRGBA_Byte>.size * numPoints // calc size of data to read
    let colorList = AllocPtrClear(count)!.assumingMemoryBound(to: OGLColorRGBA_Byte.self) // alloc buffer to read into
    FSRead(refNum, &count, UnsafeMutableRawPointer(colorList).assumingMemoryBound(to: Int8.self)) // read the data

    // NOW CREATE COLOR ARRAY IN FLOAT FORMAT
    let colorsF: UnsafeMutablePointer<OGLColorRGBA>
    if gImportBG3DVARType == -1 {
        colorsF = AllocPtrClear(MemoryLayout<OGLColorRGBA>.size * numPoints)!.assumingMemoryBound(to: OGLColorRGBA.self)
    } else {
        colorsF = OGL_AllocVertexArrayMemory(MemoryLayout<OGLColorRGBA>.size * numPoints, UInt8(gImportBG3DVARType))!.assumingMemoryBound(to: OGLColorRGBA.self) // alloc vertex array range buffer
    }

    data.pointee.colorsFloat = colorsF // assign color array to geometry header

    for i in 0..<numPoints { // copy & convert bytes to floats
        colorsF[i].r = Float(colorList[i].r) / 255.0
        colorsF[i].g = Float(colorList[i].g) / 255.0
        colorsF[i].b = Float(colorList[i].b) / 255.0
        colorsF[i].a = Float(colorList[i].a) / 255.0
    }

    SafeDisposePtr(colorList) // free the Byte color data we read in
}

// MARK: - Read triangle array

private func readTriangleArray(_ refNum: Int16) {
    let data = gBG3D_CurrentGeometryObj!.pointer(to: \.objectData)! // point to geometry data
    let numTriangles = Int(data.pointee.numTriangles) // get # triangles expect to read

    var count = MemoryLayout<MOTriangleIndecies>.size * numTriangles // calc size of data to read

    let triList: UnsafeMutablePointer<MOTriangleIndecies>
    if gImportBG3DVARType == -1 {
        triList = AllocPtrClear(count)!.assumingMemoryBound(to: MOTriangleIndecies.self)
    } else {
        triList = OGL_AllocVertexArrayMemory(count, UInt8(gImportBG3DVARType))!.assumingMemoryBound(to: MOTriangleIndecies.self) // alloc vertex array range buffer
    }

    FSRead(refNum, &count, UnsafeMutableRawPointer(triList).assumingMemoryBound(to: Int8.self)) // read the data

    for i in 0..<numTriangles { // swizzle
        triList[i].vertexIndices.0 = SwizzleULong(&triList[i].vertexIndices.0)
        triList[i].vertexIndices.1 = SwizzleULong(&triList[i].vertexIndices.1)
        triList[i].vertexIndices.2 = SwizzleULong(&triList[i].vertexIndices.2)
    }

    data.pointee.triangles = triList // assign triangle array to geometry header
}

// MARK: - Read bounding box

private func readBoundingBox(_ refNum: Int16) {
    let data = gBG3D_CurrentGeometryObj!.pointer(to: \.objectData)! // point to geometry data
    let bboxPtr = data.pointer(to: \.bBox)!

    var count = MemoryLayout<OGLBoundingBox>.size // calc size of data to read
    _ = bboxPtr.withMemoryRebound(to: Int8.self, capacity: 1) {
        FSRead(refNum, &count, $0) // read the bbox data directly into geometry header
    }

    data.pointee.bBox.min.x = SwizzleFloat(&data.pointee.bBox.min.x)
    data.pointee.bBox.min.y = SwizzleFloat(&data.pointee.bBox.min.y)
    data.pointee.bBox.min.z = SwizzleFloat(&data.pointee.bBox.min.z)

    data.pointee.bBox.max.x = SwizzleFloat(&data.pointee.bBox.max.x)
    data.pointee.bBox.max.y = SwizzleFloat(&data.pointee.bBox.max.y)
    data.pointee.bBox.max.z = SwizzleFloat(&data.pointee.bBox.max.z)
}

// MARK: - Init BG3D container
//
// The container is just a header that tracks all of the crap we read from a BG3D file.

private func initBG3DContainer() {
    guard let container = AllocPtrClear(MemoryLayout<BG3DFileContainer>.size)?.assumingMemoryBound(to: BG3DFileContainer.self) else {
        SwFatal("InitBG3DContainer: AllocPtr failed!")
        return
    }

    gBG3D_CurrentContainer = container
    container.pointee.numMaterials = 0 // no materials yet

    // CREATE NEW GROUP OBJECT
    guard let rootGroup = MO_CreateNewObjectOfType(.group, 0, nil) else {
        SwFatal("InitBG3DContainer: MO_CreateNewObjectOfType failed")
        return
    }

    container.pointee.root = rootGroup // root is an empty group
    gBG3D_CurrentGroup = rootGroup.assumingMemoryBound(to: MOGroupObject.self)
}

// MARK: - Dispose all BG3D containers

func DisposeAllBG3DContainers() {
    for i in 0..<Int(SwMAX_BG3D_GROUPS) {
        if GetBG3DContainer(Int32(i)) != nil {
            DisposeBG3DContainer(Int32(i))
        }
    }
}

// MARK: - Dispose BG3D

func DisposeBG3DContainer(_ groupNum: Int32) {
    guard let file = GetBG3DContainer(groupNum) else { // point to this file's container object; see if already gone
        return
    }

    // DISPOSE OF ALL MATERIALS
    let materials = materialsBase(file)
    for i in 0..<Int(file.pointee.numMaterials) {
        MO_DisposeObjectReference(UnsafeMutableRawPointer(materials[i]))
    }

    // DISPOSE OF ROOT OBJECT/GROUP
    MO_DisposeObjectReference(file.pointee.root)

    // FREE THE CONTAINER'S MEMORY
    SafeDisposePtr(file)
    SetBG3DContainer(groupNum, nil) // its gone
}

// MARK: - BG3D: Set container material flags
//
// Sets the material flags for this object's vertex array
//
// geometryNum, -1 == all

func BG3D_SetContainerMaterialFlags(_ group: Int16, _ type: Int16, _ geometryNum: Int16, _ flags: UInt32) {
    func applyFlags(_ vaObj: UnsafeMutablePointer<MOVertexArrayObject>) {
        let n = vaObj.numMaterials
        if n <= 0 { // make sure there are materials
            SwFatal("BG3D_SetContainerMaterialFlags:  no materials!")
            return
        }

        let mat = vaObj.material(at: 0)! // get pointer to material
        mat.flags |= flags // set flags
    }

    guard let moRaw = GetBG3DGroupObject(Int32(group), Int32(type)) else { // point to this model
        return
    }

    // GROUP OBJECT
    if moRaw.type == .group { // see if need to go into group
        let groupObj = moRaw.assumingMemoryBound(to: MOGroupObject.self)

        if Int(geometryNum) >= Int(groupObj.numObjectsInGroup) { // make sure # is valid
            SwFatal("BG3D_SetContainerMaterialFlags: geometryNum out of range")
            return
        }

        // POINT TO 1ST GEOMETRY IN THE GROUP
        if geometryNum == -1 { // if -1 then assign to all textures for this model
            for i in 0..<Int(groupObj.numObjectsInGroup) {
                guard let childRaw = groupObj.groupContent(at: i) else {
                    continue
                }

                if childRaw.type != .geometry || childRaw.subType != Int(MO_GEOMETRY_SUBTYPE_VERTEXARRAY) {
                    SwFatal("BG3D_SetContainerMaterialFlags:  object isnt a vertex array")
                    continue
                }

                applyFlags(childRaw.assumingMemoryBound(to: MOVertexArrayObject.self))
            }
        } else {
            guard let childRaw = groupObj.groupContent(at: Int(geometryNum)) else { // point to the desired geometry #
                return
            }
            applyFlags(childRaw.assumingMemoryBound(to: MOVertexArrayObject.self))
        }
    }
    // NOT A GROUP, SO ASSUME GEOMETRY
    else {
        applyFlags(moRaw.assumingMemoryBound(to: MOVertexArrayObject.self))
    }
}

// MARK: - BG3D: Sphere map geometry material
//
// Set the appropriate flags on a geometry's matrial to be a sphere map

func BG3D_SphereMapGeomteryMaterial(_ group: Int16, _ type: Int16, _ geometryNum: Int16, _ combineMode: UInt16, _ envMapNum: UInt16) {
    guard let moRaw = GetBG3DGroupObject(Int32(group), Int32(type)) else { // point to this object
        return
    }

    // GROUP OBJECT
    if moRaw.type == .group { // see if need to go into group
        let groupObj = moRaw.assumingMemoryBound(to: MOGroupObject.self)

        if Int(geometryNum) >= Int(groupObj.numObjectsInGroup) { // make sure # is valid
            SwFatal("BG3D_SphereMapGeomteryMaterial: geometryNum out of range")
            return
        }

        // POINT TO 1ST GEOMETRY IN THE GROUP
        if geometryNum == -1 { // if -1 then assign to all textures for this model
            for i in 0..<Int(groupObj.numObjectsInGroup) {
                guard let childRaw = groupObj.groupContent(at: i) else {
                    continue
                }
                SetSphereMapInfoOnVertexArrayObject(childRaw.assumingMemoryBound(to: MOVertexArrayObject.self), combineMode, envMapNum)
            }
        } else {
            guard let childRaw = groupObj.groupContent(at: Int(geometryNum)) else { // point to the desired geometry #
                return
            }
            SetSphereMapInfoOnVertexArrayObject(childRaw.assumingMemoryBound(to: MOVertexArrayObject.self), combineMode, envMapNum)
        }
    }
    // NOT A GROUP, SO ASSUME GEOMETRY
    else {
        SetSphereMapInfoOnVertexArrayObject(moRaw.assumingMemoryBound(to: MOVertexArrayObject.self), combineMode, envMapNum)
    }
}

// MARK: - Set sphere map info on vertex array object

func SetSphereMapInfoOnVertexArrayObject(_ mo: UnsafeMutablePointer<MOVertexArrayObject>, _ combineMode: UInt16, _ envMapNum: UInt16) {
    let moRaw = UnsafeMutableRawPointer(mo)
    if moRaw.type != .geometry || moRaw.subType != Int(MO_GEOMETRY_SUBTYPE_VERTEXARRAY) {
        SwFatal("SetSphereMapInfo:  object isnt a vertex array")
        return
    }

    guard let mat = mo.material(at: 0) else { // get pointer to material
        return
    }
    mat.flags |= UInt32(BG3D_MATERIALFLAG_MULTITEXTURE) // set flags for multi-texture

    mat.multiTextureMode = UInt16(MULTI_TEXTURE_MODE_REFLECTIONSPHERE) // set type of multi-texturing
    mat.multiTextureCombine = combineMode // set combining mode
    mat.envMapNum = envMapNum // set sphere map texture # to use
}

// MARK: - Set sphere map info on vertex array data

func SetSphereMapInfoOnVertexArrayData(_ va: UnsafeMutablePointer<MOVertexArrayData>, _ combineMode: UInt16, _ envMapNum: UInt16) {
    guard let mat = va.pointee.materials.0 else { // get pointer to material
        return
    }
    mat.flags |= UInt32(BG3D_MATERIALFLAG_MULTITEXTURE) // set flags for multi-texture

    mat.multiTextureMode = UInt16(MULTI_TEXTURE_MODE_REFLECTIONSPHERE) // set type of multi-texturing
    mat.multiTextureCombine = combineMode // set combining mode
    mat.envMapNum = envMapNum // set sphere map texture # to use
}

// MARK: - Set sphere map info on material object

func SetSphereMapInfoOnMaterialObject(_ mat: UnsafeMutablePointer<MOMaterialObject>, _ combineMode: UInt16, _ envMapNum: UInt16) {
    if UnsafeMutableRawPointer(mat).type != .material {
        SwFatal("SetSphereMapInfoOnMaterialObject:  object isnt a material")
        return
    }

    mat.flags |= UInt32(BG3D_MATERIALFLAG_MULTITEXTURE) // set flags for multi-texture

    mat.multiTextureMode = UInt16(MULTI_TEXTURE_MODE_REFLECTIONSPHERE) // set type of multi-texturing
    mat.multiTextureCombine = combineMode // set combining mode
    mat.envMapNum = envMapNum // set sphere map texture # to use
}
