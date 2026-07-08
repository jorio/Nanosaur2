#if canImport(BG3DFile)
import BG3DFile
#endif
// Bg3d.swift - Port of bg3d.c to Swift
//
// gBG3DContainerList/gBG3DGroupList/gNumObjectsInBG3DGroupList/
// gObjectGroupBBoxList/gObjectGroupBSphereList are native Swift storage
// (converted 2026-07-07): nothing in any .c file touches them anymore
// (the header comment claiming Items.c/Terrain.c/Player.c still needed
// them via extern was stale - those are stub files now, all real logic
// already ported to Swift). The Get*/Set* accessor functions below keep
// the same names/signatures as the old C shims in ObjectsInternal.h/
// BonesInternal.h so none of their ~30 call sites elsewhere needed to
// change - only the implementation moved from C-array-indexing to
// native-Swift-array-indexing.
//
// Everything else here (gBG3D_* state, the group stack) was `static`
// (file-private) in C, so it moves into private Swift state instead.

private var gBG3DContainerList: [UnsafeMutablePointer<BG3DFileContainer>?] = Array(repeating: nil, count: Int(SwMAX_BG3D_GROUPS))
private var gBG3DGroupList: [[MetaObjectPtr?]] = Array(repeating: Array(repeating: nil, count: Int(MAX_OBJECTS_IN_GROUP)), count: Int(SwMAX_BG3D_GROUPS))
private var gNumObjectsInBG3DGroupList: [Int32] = Array(repeating: 0, count: Int(SwMAX_BG3D_GROUPS))
private var gObjectGroupBBoxList: [[OGLBoundingBox]] = Array(repeating: Array(repeating: OGLBoundingBox(), count: Int(MAX_OBJECTS_IN_GROUP)), count: Int(SwMAX_BG3D_GROUPS))
private var gObjectGroupBSphereList: [[Float]] = Array(repeating: Array(repeating: 0, count: Int(MAX_OBJECTS_IN_GROUP)), count: Int(SwMAX_BG3D_GROUPS))

func GetBG3DContainerRoot(_ group: Int32) -> MetaObjectPtr? { gBG3DContainerList[Int(group)]!.pointee.root }
func GetBG3DContainer(_ group: Int32) -> UnsafeMutablePointer<BG3DFileContainer>? { gBG3DContainerList[Int(group)] }
func SetBG3DContainer(_ group: Int32, _ value: UnsafeMutablePointer<BG3DFileContainer>?) { gBG3DContainerList[Int(group)] = value }
func GetNumObjectsInBG3DGroup(_ group: Int32) -> Int32 { gNumObjectsInBG3DGroupList[Int(group)] }
func SetNumObjectsInBG3DGroup(_ group: Int32, _ value: Int32) { gNumObjectsInBG3DGroupList[Int(group)] = value }
func GetBG3DGroupObject(_ group: Int32, _ type: Int32) -> MetaObjectPtr? { gBG3DGroupList[Int(group)][Int(type)] }
func SetBG3DGroupObject(_ group: Int32, _ type: Int32, _ value: MetaObjectPtr?) { gBG3DGroupList[Int(group)][Int(type)] = value }
func GetObjectGroupBBox(_ group: Int32, _ type: Int32) -> OGLBoundingBox { gObjectGroupBBoxList[Int(group)][Int(type)] }
func SetObjectGroupBBox(_ group: Int32, _ type: Int32, _ value: OGLBoundingBox) { gObjectGroupBBoxList[Int(group)][Int(type)] = value }
func GetObjectGroupBSphere(_ group: Int32, _ type: Int32) -> Float { gObjectGroupBSphereList[Int(group)][Int(type)] }
func SetObjectGroupBSphere(_ group: Int32, _ type: Int32, _ value: Float) { gObjectGroupBSphereList[Int(group)][Int(type)] = value }

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
//
// The file is read fully into memory and parsed up front by BG3DFile (a
// tested, standalone parser for the BG3D tag-stream format - see
// Sources/BG3DFile and Tests/BG3DFileTests, verified byte-for-byte against
// every real .bg3d asset in Data/Models and Data/Skeletons). This function
// then walks the already-parsed, already-byte-swapped chunks to build the
// same OpenGL/MetaObject state the original imperative FSRead-based reader
// did, one chunk at a time.

func ImportBG3D(_ spec: UnsafeMutablePointer<FSSpec>, _ groupNum: Int32, _ varType: Int16) {
    gImportBG3DVARType = varType

    // INIT SOME VARIABLES
    gBG3D_CurrentMaterialObj = nil
    gBG3D_CurrentGeometryObj = nil
    gBG3D_GroupStackIndex = 0 // init the group stack
    initBG3DContainer()

    // OPEN THE FILE & READ IT ALL INTO MEMORY
    var refNum: Int16 = 0
    if SwFSpOpenDF(spec, Int8(fsRdPerm.rawValue), &refNum) != kNoErr {
        SwFatal("ImportBG3D: FSpOpenDF failed")
    }

    var fileLength = 0
    SwGetEOF(refNum, &fileLength)

    var fileBytes = [UInt8](repeating: 0, count: fileLength)
    let readErr: OSErr = fileBytes.withUnsafeMutableBytes { buf in
        var readBytes = fileLength
        return SwFSRead(refNum, &readBytes, buf.baseAddress!.assumingMemoryBound(to: Int8.self))
    }
    SwFSClose(refNum)

    if readErr != kNoErr {
        SwFatal("ImportBG3D: FSRead failed")
    }

    // PARSE THE WHOLE FILE

    guard let file = try? BG3DFile(parsing: fileBytes) else {
        SwFatal("ImportBG3D: BG3DFile parsing failed")
        return
    }

    // WALK THE PARSED CHUNKS

    for chunk in file.chunks {
        switch chunk {
        case .materialFlags(let flags):
            readMaterialFlags(flags)

        case .materialDiffuseColor(let color):
            readMaterialDiffuseColor(color)

        case .textureMap(let header, let pixels):
            readMaterialTextureMap(header, pixels)

        case .jpegTexture(let header, let jpegData, let alphaChannel):
            readMaterialJPEGTextureMap(header, jpegData, alphaChannel)

        case .groupStart:
            readGroup()

        case .groupEnd:
            endGroup()

        case .geometry(let geoHeader):
            let newObj = readNewGeometry(geoHeader)
            if let currentGroup = gBG3D_CurrentGroup { // add new geometry to current group
                UnsafeMutableRawPointer(currentGroup).append(newObj)
                MO_DisposeObjectReference(newObj) // nuke the extra reference
            }

        case .vertexArray(let points):
            readVertexArray(points)

        case .normalArray(let normals):
            readNormalArray(normals)

        case .uvArray(let uvs):
            readUVArray(uvs)

        case .colorArray(let colors):
            readVertexColorArray(colors)

        case .triangleArray(let triangles):
            readTriangleArray(triangles)

        case .boundingBox(let bbox):
            readBoundingBox(bbox)
        }
    }

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

// MARK: - Read material flags
//
// Reading new material flags indicatest the start of a new material.

private func readMaterialFlags(_ flags: UInt32) {
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

private func readMaterialDiffuseColor(_ color: BG3DColorRGBA) {
    guard let matObj = gBG3D_CurrentMaterialObj else {
        SwFatal("ReadMaterialDiffuseColor: gBG3D_CurrentMaterialObj == nil")
        return
    }

    // ASSIGN COLOR TO CURRENT MATERIAL
    matObj.diffuseColor = OGLColorRGBA(r: color.r, g: color.g, b: color.b, a: color.a)
}

// MARK: - Read material texture map
//
// NOTE: This may get called multiple times - once for each mipmap associated with the material.

private func readMaterialTextureMap(_ header: BG3DTextureHeader, _ pixels: [UInt8]) {
    // GET PTR TO CURRENT MATERIAL
    guard let matObj = gBG3D_CurrentMaterialObj else {
        SwFatal("ReadMaterialTextureMap: gBG3D_CurrentMaterialObj == nil")
        return
    }

    // COPY BASIC INFO
    SwGameAssert(matObj.numMipmaps < UInt32(MO_MAX_MIPMAPS)) // see if overflow

    if matObj.numMipmaps == 0 { // see if this is the first texture
        matObj.width = header.width
        matObj.height = header.height
    }

    // ASSIGN PIXELS TO CURRENT MATERIAL
    let i = Int(matObj.numMipmaps) // increment the mipmap count
    matObj.numMipmaps += 1

    let w = Int32(header.width)
    let h = Int32(header.height)

    // LOAD INTO OPENGL
    var mutablePixels = pixels
    mutablePixels.withUnsafeMutableBytes { pixelsBuf in
        switch header.srcPixelFormat {
        // Source port note: most BG3Ds in Nanosaur 2 use JPEG textures;
        // the few that don't use JPEG always use GL_RGBA in practice.
        case GL_RGBA:
            matObj.setTextureName(OGL_TextureMap_Load(pixelsBuf.baseAddress, w, h, GL_RGBA, GL_RGBA, GLint(GL_UNSIGNED_BYTE)), at: i)

        // Just in case we want to import models from other games or whatever...
        case GL_UNSIGNED_SHORT_1_5_5_5_REV, // 16-bit packed pixel
             GL_UNSIGNED_INT_8_8_8_8_REV: // ARGB (standard Mac)
            // pass on format as dataType
            matObj.setTextureName(OGL_TextureMap_Load(pixelsBuf.baseAddress, w, h, GL_RGBA, GL_RGBA, header.srcPixelFormat), at: i)

        default:
            SwFatal("Unsupported BG3D srcPixelFormat")
        }
    }
}

// MARK: - Read material JPEG texture map
//
// NOTE: This may get called multiple times - once for each mipmap associated with the material.

private func readMaterialJPEGTextureMap(_ header: BG3DJPEGTextureHeader, _ jpegData: [UInt8], _ alphaChannel: [UInt8]?) {
    // GET PTR TO CURRENT MATERIAL
    SwGameAssert(gBG3D_CurrentMaterialObj != nil)
    let matObj = gBG3D_CurrentMaterialObj!

    let w = Int32(header.width) // get dimensions of the texture
    let h = Int32(header.height)

    // COPY BASIC INFO
    SwGameAssert(matObj.numMipmaps < UInt32(MO_MAX_MIPMAPS)) // see if overflow

    if matObj.numMipmaps == 0 { // see if this is the first texture
        matObj.width = UInt32(w)
        matObj.height = UInt32(h)
    }

    // DECOMPRESS THE IMAGE
    var mutableJpegData = jpegData
    let textureRGBA: Ptr! = mutableJpegData.withUnsafeMutableBytes { jpegBuf in
        DecompressQTImage(jpegBuf.baseAddress?.assumingMemoryBound(to: CChar.self), Int32(header.bufferSize), w, h)
    }
    SwGameAssert(textureRGBA != nil)

    // COPY IN ALPHA CHANNEL IF IT HAS ONE
    if let alphaChannel {
        let textureAlphaBase = (UnsafeMutableRawPointer(textureRGBA) + 3).assumingMemoryBound(to: UInt8.self)
        for p in 0..<alphaChannel.count {
            textureAlphaBase[p * 4] = alphaChannel[p]
        }
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

private func readNewGeometry(_ header: BG3DGeometryHeader) -> MetaObjectPtr? {
    switch BG3DGeometryType(rawValue: header.type) {
    // VERTEX ELEMENTS
    case .vertexElements:
        return readVertexElementsGeometry(header)

    default:
        SwFatal("ReadNewGeometry: unknown geo type")
        return nil
    }
}

// MARK: - Read vertex elements geometry

private func readVertexElementsGeometry(_ header: BG3DGeometryHeader) -> MetaObjectPtr? {
    // SETUP DATA
    var vertexArrayData = MOVertexArrayData()

    vertexArrayData.VARtype = gImportBG3DVARType // which Vertex Array Range are we loading this into?

    vertexArrayData.numMaterials = Int16(header.numMaterials)
    vertexArrayData.numPoints = Int32(header.numPoints)
    vertexArrayData.numTriangles = Int32(header.numTriangles)
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
        vertexArrayData.materials.0 = materials[Int(header.layerMaterialNum.0)]
    }
    if vertexArrayData.numMaterials >= 2 {
        vertexArrayData.materials.1 = materials[Int(header.layerMaterialNum.1)]
    }

    // CREATE THE NEW GEO OBJECT
    gBG3D_CurrentGeometryObj = MO_CreateNewObjectOfType(.geometry, Int(MO_GEOMETRY_SUBTYPE_VERTEXARRAY), &vertexArrayData)?.assumingMemoryBound(to: MOVertexArrayObject.self)

    return UnsafeMutableRawPointer(gBG3D_CurrentGeometryObj)
}

// MARK: - Read vertex array

private func readVertexArray(_ points: [BG3DPoint3D]) {
    let data = gBG3D_CurrentGeometryObj!.pointer(to: \.objectData)! // point to geometry data
    if data.pointee.points != nil { // see if points already assigned
        SwFatal("ReadVertexArray: points already assigned!")
    }

    let numPoints = points.count
    let byteCount = MemoryLayout<OGLPoint3D>.size * numPoints // calc size of data to allocate

    let pointList: UnsafeMutablePointer<OGLPoint3D>
    if gImportBG3DVARType == -1 {
        pointList = AllocPtrClear(byteCount)!.assumingMemoryBound(to: OGLPoint3D.self)
    } else {
        pointList = OGL_AllocVertexArrayMemory(byteCount, UInt8(gImportBG3DVARType))!.assumingMemoryBound(to: OGLPoint3D.self) // alloc vertex array range buffer
    }

    for i in 0..<numPoints {
        pointList[i] = OGLPoint3D(x: points[i].x, y: points[i].y, z: points[i].z)
    }

    data.pointee.points = pointList // assign point array to geometry header
}

// MARK: - Read normal array

private func readNormalArray(_ normals: [BG3DPoint3D]) {
    let data = gBG3D_CurrentGeometryObj!.pointer(to: \.objectData)! // point to geometry data
    let numPoints = normals.count
    let byteCount = MemoryLayout<OGLVector3D>.size * numPoints // calc size of data to allocate

    let normalList: UnsafeMutablePointer<OGLVector3D>
    if gImportBG3DVARType == -1 {
        normalList = AllocPtrClear(byteCount)!.assumingMemoryBound(to: OGLVector3D.self)
    } else {
        normalList = OGL_AllocVertexArrayMemory(byteCount, UInt8(gImportBG3DVARType))!.assumingMemoryBound(to: OGLVector3D.self) // alloc vertex array range buffer
    }

    for i in 0..<numPoints {
        normalList[i] = OGLVector3D(x: normals[i].x, y: normals[i].y, z: normals[i].z)
    }

    data.pointee.normals = normalList // assign normal array to geometry header
}

// MARK: - Read UV array

private func readUVArray(_ uvs: [BG3DTextureCoord]) {
    let data = gBG3D_CurrentGeometryObj!.pointer(to: \.objectData)! // point to geometry data
    let numPoints = uvs.count
    let byteCount = MemoryLayout<OGLTextureCoord>.size * numPoints // calc size of data to allocate

    let uvList: UnsafeMutablePointer<OGLTextureCoord>
    if gImportBG3DVARType == -1 {
        uvList = AllocPtrClear(byteCount)!.assumingMemoryBound(to: OGLTextureCoord.self)
    } else {
        uvList = OGL_AllocVertexArrayMemory(byteCount, UInt8(gImportBG3DVARType))!.assumingMemoryBound(to: OGLTextureCoord.self) // alloc vertex array range buffer
    }

    for i in 0..<numPoints {
        uvList[i] = OGLTextureCoord(u: uvs[i].u, v: uvs[i].v)
    }

    data.pointee.uvs.0 = uvList // assign uv array to geometry header
}

// MARK: - Read vertex color array
//
// NOTE: The color data in the BG3D file is always stored as Byte values since it's more compact.

private func readVertexColorArray(_ colors: [BG3DColorRGBAByte]) {
    let data = gBG3D_CurrentGeometryObj!.pointer(to: \.objectData)! // point to geometry data
    let numPoints = colors.count

    // CREATE COLOR ARRAY IN FLOAT FORMAT
    let colorsF: UnsafeMutablePointer<OGLColorRGBA>
    let byteCount = MemoryLayout<OGLColorRGBA>.size * numPoints
    if gImportBG3DVARType == -1 {
        colorsF = AllocPtrClear(byteCount)!.assumingMemoryBound(to: OGLColorRGBA.self)
    } else {
        colorsF = OGL_AllocVertexArrayMemory(byteCount, UInt8(gImportBG3DVARType))!.assumingMemoryBound(to: OGLColorRGBA.self) // alloc vertex array range buffer
    }

    data.pointee.colorsFloat = colorsF // assign color array to geometry header

    for i in 0..<numPoints { // convert bytes to floats
        colorsF[i].r = Float(colors[i].r) / 255.0
        colorsF[i].g = Float(colors[i].g) / 255.0
        colorsF[i].b = Float(colors[i].b) / 255.0
        colorsF[i].a = Float(colors[i].a) / 255.0
    }
}

// MARK: - Read triangle array

private func readTriangleArray(_ triangles: [BG3DTriangle]) {
    let data = gBG3D_CurrentGeometryObj!.pointer(to: \.objectData)! // point to geometry data
    let numTriangles = triangles.count
    let byteCount = MemoryLayout<MOTriangleIndecies>.size * numTriangles // calc size of data to allocate

    let triList: UnsafeMutablePointer<MOTriangleIndecies>
    if gImportBG3DVARType == -1 {
        triList = AllocPtrClear(byteCount)!.assumingMemoryBound(to: MOTriangleIndecies.self)
    } else {
        triList = OGL_AllocVertexArrayMemory(byteCount, UInt8(gImportBG3DVARType))!.assumingMemoryBound(to: MOTriangleIndecies.self) // alloc vertex array range buffer
    }

    for i in 0..<numTriangles {
        triList[i].vertexIndices = triangles[i].vertexIndices
    }

    data.pointee.triangles = triList // assign triangle array to geometry header
}

// MARK: - Read bounding box

private func readBoundingBox(_ bbox: BG3DBoundingBox) {
    let data = gBG3D_CurrentGeometryObj!.pointer(to: \.objectData)! // point to geometry data

    data.pointee.bBox.min = OGLPoint3D(x: bbox.min.x, y: bbox.min.y, z: bbox.min.z)
    data.pointee.bBox.max = OGLPoint3D(x: bbox.max.x, y: bbox.max.y, z: bbox.max.z)
    data.pointee.bBox.isEmpty = bbox.isEmpty ? 1 : 0
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
