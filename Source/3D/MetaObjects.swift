// MetaObjects.swift - Port of MetaObjects.c to Swift
//
// gGlobalTransparency/gGlobalColorFilter/gGlobalMaterialFlags/
// gMostRecentMaterial are native Swift storage now (converted
// 2026-07-07): nothing in any .c file touches them anymore.

var gGlobalTransparency: Float = 1
var gGlobalColorFilter = OGLColorRGB(r: 1, g: 1, b: 1)
var gGlobalMaterialFlags: UInt32 = 0
var gMostRecentMaterial: UnsafeMutablePointer<MOMaterialObject>?

@inline(__always) private func GAME_CLAMP(_ x: Float, _ lo: Float, _ hi: Float) -> Float {
    x < lo ? lo : (x > hi ? hi : x)
}

// OGL_CheckError() is a function-like macro (`OGL_CheckError_Impl(__FILE__, __LINE__)`),
// which Swift can't import as a callable symbol.
@inline(__always) private func OGL_CheckError() -> GLenum {
    OGL_CheckError_Impl(#file, Int32(#line))
}

private var gFirstMetaObject: UnsafeMutablePointer<MetaObjectHeader>?
private var gLastMetaObject: UnsafeMutablePointer<MetaObjectHeader>?
private var gNumMetaObjects = 0

// MARK: - Fixed-array-field helpers (all struct fields, never unions)

@inline(__always) private func groupContentsBase(_ groupData: UnsafeMutablePointer<MOGroupData>) -> UnsafeMutablePointer<MetaObjectPtr?> {
    UnsafeMutableRawPointer(groupData.pointer(to: \.groupContents)!).assumingMemoryBound(to: MetaObjectPtr?.self)
}

@inline(__always) private func materialsBase(_ data: UnsafeMutablePointer<MOVertexArrayData>) -> UnsafeMutablePointer<UnsafeMutablePointer<MOMaterialObject>?> {
    UnsafeMutableRawPointer(data.pointer(to: \.materials)!).assumingMemoryBound(to: UnsafeMutablePointer<MOMaterialObject>?.self)
}

@inline(__always) private func uvsBase(_ data: UnsafeMutablePointer<MOVertexArrayData>) -> UnsafeMutablePointer<UnsafeMutablePointer<OGLTextureCoord>?> {
    UnsafeMutableRawPointer(data.pointer(to: \.uvs)!).assumingMemoryBound(to: UnsafeMutablePointer<OGLTextureCoord>?.self)
}

@inline(__always) private func textureNameBase(_ data: UnsafeMutablePointer<MOMaterialData>) -> UnsafeMutablePointer<GLuint> {
    UnsafeMutableRawPointer(data.pointer(to: \.textureName)!).assumingMemoryBound(to: GLuint.self)
}

func MO_InitHandler() {
    gFirstMetaObject = nil // no meta object nodes yet
    gLastMetaObject = nil
    gNumMetaObjects = 0
}

// MARK: - Create

// INPUT:	type = type of mo to create
//			subType = subtype to create (optional)
//			data = pointer to any data needed to create the mo (optional)
func MO_CreateNewObjectOfType(_ type: MetaObjectType, _ subType: Int, _ data: UnsafeMutableRawPointer!) -> MetaObjectPtr! {
    // ALLOCATE EMPTY OBJECT

    guard let mo = allocateEmptyMetaObject(type, subType) else {
        return nil
    }

    // SET OBJECT INFO

    switch type {
    case .group:
        setMetaObjectToGroup(mo.assumingMemoryBound(to: MOGroupObject.self))

    case .geometry:
        setMetaObjectToGeometry(mo, subType, data)

    case .material:
        setMetaObjectToMaterial(mo.assumingMemoryBound(to: MOMaterialObject.self), data!.assumingMemoryBound(to: MOMaterialData.self))

    case .matrix:
        setMetaObjectToMatrix(mo.assumingMemoryBound(to: MOMatrixObject.self), data!.assumingMemoryBound(to: OGLMatrix4x4.self))

    case .picture:
        setMetaObjectToPicture(mo.assumingMemoryBound(to: MOPictureObject.self), data!.assumingMemoryBound(to: CChar.self))

    case .sprite:
        setMetaObjectToSprite(mo.assumingMemoryBound(to: MOSpriteObject.self), data!.assumingMemoryBound(to: MOSpriteSetupData.self))

    default:
        SwFatal("MO_CreateNewObjectOfType: object type not recognized")
    }

    return mo
}

// Allocates an empty meta object and connects it to the linked list.
private func allocateEmptyMetaObject(_ type: MetaObjectType, _ subType: Int) -> MetaObjectPtr? {
    let size: Int

    // DETERMINE SIZE OF DATA TO ALLOC

    switch type {
    case .group:
        size = MemoryLayout<MOGroupObject>.size

    case .geometry:
        switch subType {
        case Int(MO_GEOMETRY_SUBTYPE_VERTEXARRAY):
            size = MemoryLayout<MOVertexArrayObject>.size
        default:
            SwFatal("AllocateEmptyMetaObject: object subtype not recognized")
            return nil
        }

    case .material:
        size = MemoryLayout<MOMaterialObject>.size

    case .matrix:
        size = MemoryLayout<MOMatrixObject>.size

    case .picture:
        size = MemoryLayout<MOPictureObject>.size

    case .sprite:
        size = MemoryLayout<MOSpriteObject>.size

    default:
        SwFatal("AllocateEmptyMetaObject: object type not recognized")
        return nil
    }

    // ALLOC MEMORY FOR META OBJECT

    guard let raw = AllocPtrClear(size) else {
        SwFatal("AllocateEmptyMetaObject: AllocPtr failed!")
        return nil
    }
    let mo = raw.assumingMemoryBound(to: MetaObjectHeader.self)

    // INIT STRUCTURE

    mo.pointee.cookie = UInt32(MO_COOKIE)
    mo.pointee.type = type
    mo.pointee.subType = subType
    mo.pointee.data = nil
    mo.pointee.nextNode = nil
    mo.pointee.refCount = 1 // initial reference count is always 1
    mo.pointee.parentGroup = nil

    // ADD NODE TO LINKED LIST

    // SEE IF IS ONLY NODE

    if gFirstMetaObject == nil {
        if gLastMetaObject != nil {
            SwFatal("AllocateEmptyMetaObject: gFirstMetaObject & gLastMetaObject should be nil")
        }

        mo.pointee.prevNode = nil
        gFirstMetaObject = mo
        gLastMetaObject = mo
        gNumMetaObjects = 1
    }

    // ADD TO END OF LINKED LIST

    else {
        mo.pointee.prevNode = gLastMetaObject // point new prev to last
        gLastMetaObject!.pointee.nextNode = mo // point old last to new
        gLastMetaObject = mo // set new last
        gNumMetaObjects += 1
    }

    return raw
}

// INPUT:	mo = meta object which has already been allocated and added to linked list.
private func setMetaObjectToGroup(_ groupObj: UnsafeMutablePointer<MOGroupObject>) {
    // INIT THE DATA

    groupObj.pointee.objectData.numObjectsInGroup = 0
}

// INPUT:	mo = meta object which has already been allocated and added to linked list.
private func setMetaObjectToGeometry(_ mo: MetaObjectPtr, _ subType: Int, _ data: UnsafeMutableRawPointer!) {
    switch subType {
    case Int(MO_GEOMETRY_SUBTYPE_VERTEXARRAY):
        setMetaObjectToVertexArrayGeometry(mo.assumingMemoryBound(to: MOVertexArrayObject.self), data.assumingMemoryBound(to: MOVertexArrayData.self))
    default:
        SwFatal("SetMetaObjectToGeometry: unknown subType")
    }
}

// INPUT:	mo = meta object which has already been allocated and added to linked list.
//
// This takes the given input data and copies it.  It also boosts the ref count of
// any referenced items.
private func setMetaObjectToVertexArrayGeometry(_ geoObj: UnsafeMutablePointer<MOVertexArrayObject>, _ data: UnsafeMutablePointer<MOVertexArrayData>) {
    // INIT THE DATA

    geoObj.pointee.objectData = data.pointee // copy from input data

    // INCREASE MATERIAL REFERENCE COUNTS

    let materials = materialsBase(data)
    for i in 0..<Int(data.pointee.numMaterials) {
        if let mat = materials[i] { // make sure this material ref is valid
            _ = MO_GetNewReference(UnsafeMutableRawPointer(mat))
        }
    }
}

// INPUT:	mo = meta object which has already been allocated and added to linked list.
//
// This takes the given input data and copies it.
private func setMetaObjectToMaterial(_ matObj: UnsafeMutablePointer<MOMaterialObject>, _ inData: UnsafeMutablePointer<MOMaterialData>) {
    // COPY INPUT DATA

    matObj.pointee.objectData = inData.pointee
}

// INPUT:	mo = meta object which has already been allocated and added to linked list.
//
// This takes the given input data and copies it.
private func setMetaObjectToMatrix(_ matObj: UnsafeMutablePointer<MOMatrixObject>, _ inData: UnsafeMutablePointer<OGLMatrix4x4>) {
    // COPY INPUT DATA

    matObj.pointee.matrix = inData.pointee
}

// INPUT:	mo = meta object which has already been allocated and added to linked list.
//
// This takes the given input data and copies it.
private func setMetaObjectToPicture(_ pictObj: UnsafeMutablePointer<MOPictureObject>, _ path: UnsafePointer<CChar>) {
    var width: Int32 = 0
    var height: Int32 = 0

    // LOAD PICTURE FILE

    let textureName = OGL_TextureMap_LoadImageFile(path, &width, &height, nil)
    _ = OGL_CheckError()

    // CREATE A TEXTURE OBJECT

    var matData = MOMaterialData()
    matData.flags = UInt32(BG3D_MATERIALFLAG_TEXTURED | BG3D_MATERIALFLAG_CLAMP_U | BG3D_MATERIALFLAG_CLAMP_V)
    matData.diffuseColor = OGLColorRGBA(r: 1, g: 1, b: 1, a: 1)
    matData.numMipmaps = 1
    matData.width = UInt32(width)
    matData.height = UInt32(height)
    matData.textureName.0 = textureName
    pictObj.pointee.objectData.material = withUnsafeMutablePointer(to: &matData) { ptr in
        MO_CreateNewObjectOfType(.material, 0, UnsafeMutableRawPointer(ptr))
    }?.assumingMemoryBound(to: MOMaterialObject.self)
    _ = OGL_CheckError()
}

// INPUT:	mo = meta object which has already been allocated and added to linked list.
//
// This takes the given input data and copies it.
private func setMetaObjectToSprite(_ spriteObj: UnsafeMutablePointer<MOSpriteObject>, _ inData: UnsafeMutablePointer<MOSpriteSetupData>) {
    // CREATE MATERIAL OBJECT FROM FSSPEC

    SwGameAssert(inData.pointee.loadFile == 0)

    // GET MATERIAL FROM SPRITE LIST

    let group = Int(inData.pointee.group)
    let type = Int(inData.pointee.type)

    if inData.pointee.type >= GetNumSpritesInGroup(Int32(group)) { // make sure type is valid
        SwFatal("SetMetaObjectToSprite: illegal type")
    }

    let sprite = GetSpriteGroupPtr(Int32(group))! + type
    spriteObj.pointee.objectData.material = sprite.pointee.materialObject?.assumingMemoryBound(to: MOMaterialObject.self)
    _ = MO_GetNewReference(sprite.pointee.materialObject) // this is a new reference, so inc ref count

    spriteObj.pointee.objectData.width = Float(sprite.pointee.width) // get width and height of texture
    spriteObj.pointee.objectData.height = Float(sprite.pointee.height)
    spriteObj.pointee.objectData.aspectRatio = sprite.pointee.aspectRatio // get aspect ratio

    // SET SOME SPRITE OBJECT DATA

    spriteObj.pointee.objectData.drawCentered = inData.pointee.drawCentered

    spriteObj.pointee.objectData.scaleBasis = spriteObj.pointee.objectData.width / SPRITE_SCALE_BASIS_DENOMINATOR // calculate a scale basis to keep things scaled relative to texture size

    spriteObj.pointee.objectData.coord.x = -1.0 // assume upper left corner
    spriteObj.pointee.objectData.coord.y = 1.0
    spriteObj.pointee.objectData.coord.z = 0 // assume in front
    spriteObj.pointee.objectData.scaleX = 1.0 // scale is normal
    spriteObj.pointee.objectData.scaleY = 1.0
    spriteObj.pointee.objectData.rot = 0 // rot
}

// MARK: - Groups

// Attach new object to end of group
func MO_AppendToGroup(_ group: UnsafeMutablePointer<MOGroupObject>!, _ newObject: MetaObjectPtr!) {
    // VERIFY COOKIE

    if (group.pointee.objectHeader.cookie != UInt32(MO_COOKIE)) || (newObject.assumingMemoryBound(to: MetaObjectHeader.self).pointee.cookie != UInt32(MO_COOKIE)) {
        SwFatal("MO_AppendToGroup: cookie is invalid!")
    }

    let i = Int(group.pointee.objectData.numObjectsInGroup) // get index into group list
    group.pointee.objectData.numObjectsInGroup += 1
    if i >= Int(MO_MAX_ITEMS_IN_GROUP) {
        SwFatal("MO_AppendToGroup: too many objects in group!")
    }

    _ = MO_GetNewReference(newObject) // get new reference to object
    groupContentsBase(&group.pointee.objectData)[i] = newObject // save object reference in group
}

// Attach new object to START of group
func MO_AttachToGroupStart(_ group: UnsafeMutablePointer<MOGroupObject>!, _ newObject: MetaObjectPtr!) {
    // VERIFY COOKIE

    if (group.pointee.objectHeader.cookie != UInt32(MO_COOKIE)) || (newObject.assumingMemoryBound(to: MetaObjectHeader.self).pointee.cookie != UInt32(MO_COOKIE)) {
        SwFatal("MO_AttachToGroupStart: cookie is invalid!")
    }

    let i = Int(group.pointee.objectData.numObjectsInGroup) // get index into group list
    group.pointee.objectData.numObjectsInGroup += 1
    if i >= Int(MO_MAX_ITEMS_IN_GROUP) {
        SwFatal("MO_AttachToGroupStart: too many objects in group!")
    }

    _ = MO_GetNewReference(newObject) // get new reference to object

    // SHIFT ALL EXISTING OBJECTS UP

    let contents = groupContentsBase(&group.pointee.objectData)
    var j = i
    while j > 0 {
        contents[j] = contents[j - 1]
        j -= 1
    }

    contents[0] = newObject // save object ref into group
}

// MARK: - Draw

// This recursive function will draw any objects submitted and parses groups.
func MO_DrawObject(_ object: MetaObjectPtr!) {
    let objHead = object.assumingMemoryBound(to: MetaObjectHeader.self)

    // VERIFY COOKIE

    if objHead.pointee.cookie != UInt32(MO_COOKIE) {
        SwFatal("MO_DrawObject: cookie is invalid!")
    }

    // HANDLE TYPE

    switch objHead.pointee.type {
    case .geometry:
        switch objHead.pointee.subType {
        case Int(MO_GEOMETRY_SUBTYPE_VERTEXARRAY):
            let vObj = object.assumingMemoryBound(to: MOVertexArrayObject.self)
            MO_DrawGeometry_VertexArray(&vObj.pointee.objectData)
        default:
            SwFatal("MO_DrawObject: unknown sub-type!")
        }

    case .material:
        MO_DrawMaterial(object.assumingMemoryBound(to: MOMaterialObject.self))

    case .group:
        MO_DrawGroup(object.assumingMemoryBound(to: MOGroupObject.self))

    case .matrix:
        MO_DrawMatrix(object.assumingMemoryBound(to: MOMatrixObject.self))

    case .picture:
        MO_DrawPicture(object.assumingMemoryBound(to: MOPictureObject.self))

    case .sprite:
        MO_DrawSprite(object.assumingMemoryBound(to: MOSpriteObject.self))

    default:
        SwFatal("MO_DrawObject: unknown type!")
    }
}

func MO_DrawGroup(_ objectC: UnsafePointer<MOGroupObject>!) {
    let object = UnsafeMutablePointer(mutating: objectC)!

    // VERIFY OBJECT TYPE

    if object.pointee.objectHeader.type != .group {
        SwFatal("MO_DrawGroup: this isnt a group!")
    }

    // PUSH CURRENT STATE ON STATE STACK

    OGL_PushState()

    // PARSE GROUP

    let numChildren = Int(object.pointee.objectData.numObjectsInGroup) // get # objects in group
    let contents = groupContentsBase(&object.pointee.objectData)

    for i in 0..<numChildren {
        MO_DrawObject(contents[i])
    }

    // POP OLD STATE OFF OF STACK

    OGL_PopState()
}

func MO_DrawGeometry_VertexArray(_ dataC: UnsafePointer<MOVertexArrayData>!) {
    let data = UnsafeMutablePointer(mutating: dataC)!
    var useTexture = false
    var multiTexture = false
    var texGen = false

    // SETUP VERTEX ARRAY

    glEnableClientState(GLenum(GL_VERTEX_ARRAY)) // enable vertex arrays
    glVertexPointer(3, GLenum(GL_FLOAT), 0, data.pointee.points) // point to points array

    // SETUP VERTEX COLORS

    if data.pointee.colorsFloat != nil { // do we have float colors?
        glColorPointer(4, GLenum(GL_FLOAT), 0, data.pointee.colorsFloat)
        glEnableClientState(GLenum(GL_COLOR_ARRAY)) // enable color arrays
    } else {
        glDisableClientState(GLenum(GL_COLOR_ARRAY)) // no color data, so disable
    }

    if OGL_CheckError() != 0 {
        SwFatal("MO_DrawGeometry_VertexArray: color!")
    }

    // SEE IF ACTIVATE MATERIAL
    //
    // For now, I'm just looking at material #0.

    let materials = materialsBase(data)
    let uvs = uvsBase(data)

    goHere: if data.pointee.numMaterials < 0 { // if (-), then assume texture has been manually set
        useCurrent(data, uvs, &useTexture, &multiTexture, &texGen)
    } else if data.pointee.numMaterials > 0 { // are there any materials?
        // SEE IF DO PLAIN MULTI-TEXTURING FROM GEOMETRY
        //
        // If the geometry has 2+ textures assigned to is then this is what we'll use
        // for the multi-texturing.  Otherwise, we fall to the ENVMAP auto-generated
        // multi-texturing below.

        if data.pointee.numMaterials > 1 {
            useTexture = true
            multiTexture = true

            for i in 0..<Int(data.pointee.numMaterials) {
                OGL_ActiveTextureUnit(UInt32(GL_TEXTURE0) + UInt32(i)) // activate texture layer #i
                OGL_EnableTexture2D()

                glTexCoordPointer(2, GLenum(GL_FLOAT), 0, uvs[i]) // enable uv arrays
                glEnableClientState(GLenum(GL_TEXTURE_COORD_ARRAY))

                // SET COMBINE MODE FOR TEXTURE LAYER #2

                if i > 0 {
                    let multiTextureCombine = materials[0]!.pointee.objectData.multiTextureCombine
                    switch Int(multiTextureCombine) { // set combining info
                    case MULTI_TEXTURE_COMBINE_MODULATE:
                        glTexEnvi(GLenum(GL_TEXTURE_ENV), GLenum(GL_TEXTURE_ENV_MODE), GL_MODULATE)
                    case MULTI_TEXTURE_COMBINE_ADD:
                        glTexEnvi(GLenum(GL_TEXTURE_ENV), GLenum(GL_TEXTURE_ENV_MODE), GL_COMBINE)
                        glTexEnvi(GLenum(GL_TEXTURE_ENV), GLenum(GL_COMBINE_RGB), GL_ADD)
                        glTexEnvi(GLenum(GL_TEXTURE_ENV), GLenum(GL_COMBINE_ALPHA), GL_MODULATE)
                    case MULTI_TEXTURE_COMBINE_ADDALPHA:
                        glTexEnvi(GLenum(GL_TEXTURE_ENV), GLenum(GL_TEXTURE_ENV_MODE), GL_COMBINE)
                        glTexEnvi(GLenum(GL_TEXTURE_ENV), GLenum(GL_COMBINE_RGB), GL_ADD)
                        glTexEnvi(GLenum(GL_TEXTURE_ENV), GLenum(GL_COMBINE_ALPHA), GL_ADD)
                    default:
                        break
                    }
                }

                // SUBMIT MATERIAL FOR THIS TEXTURE UNIT

                MO_DrawMaterial(materials[i]) // submit material #n

                if i == 0 {
                    gMostRecentMaterial = nil // need duplicate submits to be okay
                }
            }

            break goHere
        }

        // MAYBE ONLY 1 MATERIAL IN GEOMETRY

        MO_DrawMaterial(materials[0]) // submit material #0 (also applies for multitexture layer 0)

        // IF TEXTURED, THEN ALSO ACTIVATE UV ARRAY

        useCurrent(data, uvs, &useTexture, &multiTexture, &texGen)
    } else {
        OGL_DisableTexture2D() // no materials, thus no texture, thus turn this off
    }

    // WE DONT HAVE ENOUGH INFO TO DO TEXTURES, SO DISABLE

    if !useTexture {
        glDisableClientState(GLenum(GL_TEXTURE_COORD_ARRAY))
        if OGL_CheckError() != 0 {
            SwFatal("MO_DrawGeometry_VertexArray: glDisableClientState(GL_TEXTURE_COORD_ARRAY)!")
        }
    }

    // SETUP VERTEX NORMALS
    //
    // We do this last because we need to know some things
    // before we can determine if normals are actually needed

    let needNormals: Bool
    if data.pointee.normals == nil { // see if we even have normals to pass
        needNormals = false
    } else {
        if gMyState_Lighting == 0 { // if no lighting, then probably don't need to pass normals
            needNormals = texGen // pass normals if doing texGen for sphere maps, etc.
        } else { // there's lighting, so pass the normals
            needNormals = true
        }
    }

    if needNormals {
        glNormalPointer(GLenum(GL_FLOAT), 0, data.pointee.normals)
        glEnableClientState(GLenum(GL_NORMAL_ARRAY)) // enable normal arrays
    } else {
        glDisableClientState(GLenum(GL_NORMAL_ARRAY)) // disable normal arrays
    }

    _ = OGL_CheckError()

    // DRAW IT

    if data.pointee.numTriangles != 0 {
        SwGameAssert(data.pointee.triangles != nil)
        glDrawElements(GLenum(GL_TRIANGLES), data.pointee.numTriangles * 3, GLenum(GL_UNSIGNED_INT), data.pointee.triangles)
        _ = OGL_CheckError()
    }

    gPolysThisFrame += data.pointee.numTriangles // inc poly counter

    // CLEANUP

    if multiTexture {
        OGL_ActiveTextureUnit(UInt32(GL_TEXTURE1)) // turn off textureing for multi-texture layer 2 since it isnt needed anymore
        OGL_DisableTexture2D()
        glDisable(UInt32(GL_TEXTURE_GEN_S))
        glDisable(UInt32(GL_TEXTURE_GEN_T))

        OGL_ActiveTextureUnit(UInt32(GL_TEXTURE0)) // make sure #0 is active when we leave
        glTexEnvi(GLenum(GL_TEXTURE_ENV), GLenum(GL_TEXTURE_ENV_MODE), GL_MODULATE)
        glDisable(UInt32(GL_TEXTURE_GEN_S))
        glDisable(UInt32(GL_TEXTURE_GEN_T))
    }
}

// IF TEXTURED, THEN ALSO ACTIVATE UV ARRAY (shared tail of both single- and use_current-material paths)
private func useCurrent(_ data: UnsafeMutablePointer<MOVertexArrayData>, _ uvs: UnsafeMutablePointer<UnsafeMutablePointer<OGLTextureCoord>?>, _ useTexture: inout Bool, _ multiTexture: inout Bool, _ texGen: inout Bool) {
    let materialFlags = gMostRecentMaterial!.pointee.objectData.flags // get material flags
    if materialFlags & UInt32(BG3D_MATERIALFLAG_TEXTURED) != 0 {
        if uvs[0] != nil {
            // SEE IF DO ENVMAP MULTI-TEXTURE
            //
            // We want to use reflection mapping or some other Environment mapping
            // and this uses multi-texturing.

            if materialFlags & UInt32(BG3D_MATERIALFLAG_MULTITEXTURE) != 0 {
                let multiTextureMode = gMostRecentMaterial!.pointee.objectData.multiTextureMode
                let multiTextureCombine = gMostRecentMaterial!.pointee.objectData.multiTextureCombine
                let envMapNum = gMostRecentMaterial!.pointee.objectData.envMapNum

                if envMapNum >= GetNumSpritesInGroup(Int32(SPRITE_GROUP_SPHEREMAPS)) {
                    SwFatal("MO_DrawGeometry_VertexArray: illegal envMapNum")
                }

                multiTexture = true

                switch Int(multiTextureMode) {
                // REFLECTION SPHERE

                case MULTI_TEXTURE_MODE_REFLECTIONSPHERE:
                    for i in 0..<2 {
                        OGL_ActiveTextureUnit(UInt32(GL_TEXTURE0) + UInt32(i)) // activate texture layer #i
                        OGL_EnableTexture2D()

                        if i == 0 {
                            glTexCoordPointer(2, GLenum(GL_FLOAT), 0, uvs[0]) // enable uv arrays
                            glTexEnvi(GLenum(GL_TEXTURE_ENV), GLenum(GL_TEXTURE_ENV_MODE), GL_MODULATE)
                            glEnableClientState(GLenum(GL_TEXTURE_COORD_ARRAY))
                        } else {
                            MO_DrawMaterial(GetSpriteGroupPtr(Int32(SPRITE_GROUP_SPHEREMAPS))![Int(envMapNum)].materialObject?.assumingMemoryBound(to: MOMaterialObject.self)) // activate reflection map texture

                            switch Int(multiTextureCombine) { // set combining info
                            case MULTI_TEXTURE_COMBINE_MODULATE:
                                glTexEnvi(GLenum(GL_TEXTURE_ENV), GLenum(GL_TEXTURE_ENV_MODE), GL_MODULATE)
                            case MULTI_TEXTURE_COMBINE_ADD:
                                glTexEnvi(GLenum(GL_TEXTURE_ENV), GLenum(GL_TEXTURE_ENV_MODE), GL_COMBINE)
                                glTexEnvi(GLenum(GL_TEXTURE_ENV), GLenum(GL_COMBINE_RGB), GL_ADD)
                                glTexEnvi(GLenum(GL_TEXTURE_ENV), GLenum(GL_COMBINE_ALPHA), GL_MODULATE)
                            case MULTI_TEXTURE_COMBINE_ADDALPHA: // note, when we do this gGlobalTransparency will have no effect
                                glTexEnvi(GLenum(GL_TEXTURE_ENV), GLenum(GL_TEXTURE_ENV_MODE), GL_COMBINE)
                                glTexEnvi(GLenum(GL_TEXTURE_ENV), GLenum(GL_COMBINE_RGB), GL_ADD)
                                glTexEnvi(GLenum(GL_TEXTURE_ENV), GLenum(GL_COMBINE_ALPHA), GL_ADD)
                            default:
                                break
                            }

                            glTexGeni(GLenum(GL_S), GLenum(GL_TEXTURE_GEN_MODE), GL_SPHERE_MAP) // activate reflection mapping
                            glTexGeni(GLenum(GL_T), GLenum(GL_TEXTURE_GEN_MODE), GL_SPHERE_MAP)
                            glEnable(UInt32(GL_TEXTURE_GEN_S))
                            glEnable(UInt32(GL_TEXTURE_GEN_T))
                            texGen = true
                        }
                    }
                default:
                    break
                }
            }

            // JUST 1 TEXTURE LAYER

            else {
                glTexCoordPointer(2, GLenum(GL_FLOAT), 0, uvs[0])
                glEnableClientState(GLenum(GL_TEXTURE_COORD_ARRAY)) // enable uv arrays
            }

            useTexture = true

            if OGL_CheckError() != 0 {
                SwFatal("MO_DrawGeometry_VertexArray: uv!")
            }
        }
    }
}

func MO_DrawMaterial(_ matObj: UnsafeMutablePointer<MOMaterialObject>!) {
    let matData = matObj.pointer(to: \.objectData)! // point to material data

    if matObj.pointee.objectHeader.cookie != UInt32(MO_COOKIE) { // verify cookie
        SwFatal("MO_DrawMaterial: bad cookie!")
    }

    // SEE IF TEXTURED MATERIAL

    let matFlags = matData.pointee.flags | gGlobalMaterialFlags // check flags of material & global

    if matFlags & UInt32(BG3D_MATERIALFLAG_TEXTURED) != 0 {
        // ACTIVATE MATERIAL

        let alreadySet = matObj == gMostRecentMaterial
        if alreadySet { // see if even need to bother resetting this
            OGL_EnableTexture2D() // just make sure textures are on
        } else {
            OGL_Texture_SetOpenGLTexture(matData.pointee.textureName.0) // set this texture active
        }

        // SET TEXTURE WRAPPING MODE

        // U

        if matFlags & UInt32(BG3D_MATERIALFLAG_CLAMP_U) != 0 { // we want to clamp the U
            if matData.pointee.flags & UInt32(BG3D_MATERIALFLAG_CLAMP_U_TRUE) == 0 { // see if clamping needs to be enabled
                glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), Float(GL_CLAMP_TO_EDGE)) // nope, so set clamping
                matData.pointee.flags |= UInt32(BG3D_MATERIALFLAG_CLAMP_U_TRUE) // and remember that we set it
            }
        } else { // we DONT want to clamp U
            if matData.pointee.flags & UInt32(BG3D_MATERIALFLAG_CLAMP_U_TRUE) != 0 { // see clamping is still enabled
                glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), Float(GL_REPEAT))
                matData.pointee.flags &= ~UInt32(BG3D_MATERIALFLAG_CLAMP_U_TRUE) // and remember that we cleared it
            }
        }

        // V

        if matFlags & UInt32(BG3D_MATERIALFLAG_CLAMP_V) != 0 { // we want to clamp the V
            if matData.pointee.flags & UInt32(BG3D_MATERIALFLAG_CLAMP_V_TRUE) == 0 { // see if clamping needs to be enabled
                glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), Float(GL_CLAMP_TO_EDGE)) // nope, so set clamping
                matData.pointee.flags |= UInt32(BG3D_MATERIALFLAG_CLAMP_V_TRUE) // and remember that we set it
            }
        } else { // we DONT want to clamp V
            if matData.pointee.flags & UInt32(BG3D_MATERIALFLAG_CLAMP_V_TRUE) != 0 { // see clamping is still enabled
                glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), Float(GL_REPEAT))
                matData.pointee.flags &= ~UInt32(BG3D_MATERIALFLAG_CLAMP_V_TRUE) // and remember that we cleared it
            }
        }
    } else {
        OGL_DisableTexture2D() // not textured, so disable textures
    }

    // COLORED MATERIAL

    let diffuseColor = matData.pointee.diffuseColor // point to diffuse color
    var diffColor2: OGLColorRGBA

    if gGlobalTransparency != 1.0 { // see if need to factor in global transparency
        diffColor2 = OGLColorRGBA()
        diffColor2.r = diffuseColor.r
        diffColor2.g = diffuseColor.g
        diffColor2.b = diffuseColor.b
        diffColor2.a = diffuseColor.a * gGlobalTransparency
    } else {
        diffColor2 = diffuseColor // copy to local so we can apply filter to it without munging original
    }

    // APPLY COLOR FILTER

    diffColor2.r *= gGlobalColorFilter.r
    diffColor2.g *= gGlobalColorFilter.g
    diffColor2.b *= gGlobalColorFilter.b

    OGL_SetColor4fv(&diffColor2) // set current diffuse color

    // SEE IF NEED TO ENABLE BLENDING

    if (diffColor2.a != 1.0) || (matFlags & UInt32(BG3D_MATERIALFLAG_ALWAYSBLEND) != 0) { // if has alpha, then we need blending on
        OGL_EnableBlend()
    } else {
        OGL_DisableBlend()
    }

    // SAVE THIS STUFF

    gMostRecentMaterial = matObj
}

func MO_DrawMatrix(_ matObj: UnsafePointer<MOMatrixObject>!) {
    // MULTIPLY CURRENT MATRIX BY THIS

    withUnsafePointer(to: matObj.pointee.matrix) {
        $0.withMemoryRebound(to: Float.self, capacity: 16) {
            glMultMatrixf($0)
        }
    }
}

func MO_DrawPicture(_ picObjC: UnsafePointer<MOPictureObject>!) {
    let picObj = UnsafeMutablePointer(mutating: picObjC)!
    let picData = picObj.pointer(to: \.objectData)!

    OGL_PushState()

    // SET STATE

    SetInfobarSpriteState(-5, 1)

    // CENTER VERTICALLY

    let width: Float = 640.0
    let height: Float = 480.0

    let x = -width / 2
    let y = -height / 2
    let z: Float = 0

    let currentAR = 1.0 / gCurrentPaneAspectRatio
    let targetAR: Float = 640.0 / 480.0

    var scale = currentAR / targetAR
    scale = GAME_CLAMP(scale, 1, 3)

    let yOffset = (scale - 1) * 0.333 // apply small offset to keep nano within frame

    glTranslatef(-x, -y + yOffset * height, 0)
    glScalef(scale, scale, 1)

    // ACTIVATE THE MATERIAL

    MO_DrawMaterial(picData.pointee.material) // submit material #0

    // DRAW QUAD

    glBegin(GLenum(GL_QUADS))
    glTexCoord2f(0, 1); glVertex3f(x, y + height, z)
    glTexCoord2f(1, 1); glVertex3f(x + width, y + height, z)
    glTexCoord2f(1, 0); glVertex3f(x + width, y, z)
    glTexCoord2f(0, 0); glVertex3f(x, y, z)
    glEnd()

    gPolysThisFrame += 2 // 2 more triangles

    // RESTORE STATE

    OGL_PopState()
}

// Assume that the matrices are already set to identity
//
// Also, assume that the projection matrix is already the identity matrix.
func MO_DrawSprite(_ spriteObjC: UnsafePointer<MOSpriteObject>!) {
    let spriteObj = UnsafeMutablePointer(mutating: spriteObjC)!
    let spriteData = spriteObj.pointer(to: \.objectData)!
    var p = [OGLPoint2D](repeating: OGLPoint2D(), count: 4)

    let x = spriteData.pointee.coord.x
    let y = spriteData.pointee.coord.y

    let scaleX = spriteData.pointee.scaleX
    let scaleY = spriteData.pointee.scaleY

    // ACTIVATE THE MATERIAL

    let mo = spriteData.pointee.material
    MO_DrawMaterial(mo)

    let aspect = Float(mo!.pointee.objectData.height) / Float(mo!.pointee.objectData.width)

    // SET OFFSETS FOR CENTERED SPRITE

    if spriteData.pointee.drawCentered != 0 {
        let xoff = scaleX * 0.5
        let yoff = (scaleY * aspect) * 0.5

        p[0].x = -xoff; p[0].y = -yoff // set coords of quad
        p[1].x = xoff; p[1].y = -yoff
        p[2].x = xoff; p[2].y = yoff
        p[3].x = -xoff; p[3].y = yoff
    }

    // SET OFFSETS FOR NON-CENTERED SPRITE

    else {
        let xoff = scaleX
        let yoff = scaleY * aspect

        p[0].x = 0; p[0].y = 0 // set coords of quad
        p[1].x = xoff; p[1].y = 0
        p[2].x = xoff; p[2].y = yoff
        p[3].x = 0; p[3].y = yoff
    }

    // APPLY ROTATION IF ANY

    if spriteData.pointee.rot != 0.0 {
        var m = OGLMatrix3x3()
        OGLMatrix3x3_SetRotate(&m, Double(spriteData.pointee.rot))
        p.withUnsafeMutableBufferPointer { buf in
            OGLPoint2D_TransformArray(buf.baseAddress, &m, buf.baseAddress, 4)
        }
    }

    // DRAW IT

    glBegin(GLenum(GL_QUADS))

    glTexCoord2f(0, 0); glVertex2f(p[0].x + x, p[0].y + y)
    glTexCoord2f(1, 0); glVertex2f(p[1].x + x, p[1].y + y)
    glTexCoord2f(1, 1); glVertex2f(p[2].x + x, p[2].y + y)
    glTexCoord2f(0, 1); glVertex2f(p[3].x + x, p[3].y + y)

    glEnd()

    gPolysThisFrame += 2 // 2 more tris
}

// MARK: - Reference Counting

func MO_GetNewReference(_ mo: MetaObjectPtr!) -> MetaObjectPtr! {
    let h = mo.assumingMemoryBound(to: MetaObjectHeader.self)

    h.pointee.refCount += 1

    return mo
}

// NOTE:  	Groups and other objects are NOT sub-recursed.  When a group is de-referenced, only that group object is affected.
func MO_DisposeObjectReference(_ obj: MetaObjectPtr!) {
    guard let obj else {
        SwFatal("MO_DisposeObjectReference: obj == nil")
        return
    }
    let header = obj.assumingMemoryBound(to: MetaObjectHeader.self)

    if header.pointee.cookie != UInt32(MO_COOKIE) { // verify cookie
        SwFatal("MO_DisposeObjectReference: bad cookie!")
    }

    // DEC REFERENCE COUNT OF THIS OBJECT

    header.pointee.refCount -= 1 // dec ref count

    if header.pointee.refCount < 0 { // see if over did it
        SwFatal("MO_DisposeObjectReference: refcount < 0!")
    }

    if header.pointee.refCount == 0 { // see if we can DELETE this node
        // NO MORE REFERENCES, SO DELETE DATA

        switch header.pointee.type {
        case .group:
            disposeObjectGroup(obj.assumingMemoryBound(to: MOGroupObject.self))

        case .geometry:
            switch header.pointee.subType {
            case Int(MO_GEOMETRY_SUBTYPE_VERTEXARRAY):
                let vObj = obj.assumingMemoryBound(to: MOVertexArrayObject.self)
                MO_DeleteObjectInfo_Geometry_VertexArray(&vObj.pointee.objectData)
            default:
                SwFatal("MO_DisposeObject: unknown sub-type")
            }

        case .material:
            deleteObjectInfoMaterial(obj.assumingMemoryBound(to: MOMaterialObject.self))

        case .picture:
            deleteObjectInfoPicture(obj.assumingMemoryBound(to: MOPictureObject.self))

        case .sprite:
            disposeObjectSprite(obj.assumingMemoryBound(to: MOSpriteObject.self))

        default:
            break
        }

        // DELETE THE OBJECT NODE

        detachFromLinkedList(obj) // detach from linked list

        header.pointee.cookie = 0xdeadbeef // devalidate cookie
        SafeDisposePtr(obj) // free memory used by object
        return
    }
}

private func detachFromLinkedList(_ obj: MetaObjectPtr) {
    let header = obj.assumingMemoryBound(to: MetaObjectHeader.self)

    // VERIFY COOKIE

    if header.pointee.cookie != UInt32(MO_COOKIE) {
        SwFatal("MO_DetachFromLinkedList: cookie is invalid!")
    }

    let prev = header.pointee.prevNode
    let next = header.pointee.nextNode

    // SEE IF WAS 1ST NODE IN LIST

    if prev == nil {
        gFirstMetaObject = next
        if gFirstMetaObject != nil {
            gFirstMetaObject!.pointee.prevNode = nil
        }
    }

    // SEE IF WAS LAST NODE IN LIST

    if next == nil {
        gLastMetaObject = prev
        if gLastMetaObject != nil {
            gLastMetaObject!.pointee.nextNode = nil
        }
    }

    // SOMEWHERE IN THE MIDDLE

    else if prev != nil {
        prev!.pointee.nextNode = next
        next!.pointee.prevNode = prev
    }

    gNumMetaObjects -= 1

    if gNumMetaObjects < 0 {
        SwFatal("MO_DetachFromLinkedList: counter mismatch")
    }

    if gNumMetaObjects == 0 {
        if (prev != nil) || (next != nil) { // if all gone, then prev & next should be nil
            SwFatal("MO_DetachFromLinkedList: prev/next should be nil!")
        }

        if gFirstMetaObject != nil {
            SwFatal("MO_DetachFromLinkedList: gFirstMetaObject should be nil!")
        }

        if gLastMetaObject != nil {
            SwFatal("MO_DetachFromLinkedList: gLastMetaObject should be nil!")
        }
    }
}

// Decrement the references of all objects in the group.
private func disposeObjectGroup(_ group: UnsafeMutablePointer<MOGroupObject>) {
    let n = Int(group.pointee.objectData.numObjectsInGroup) // get # objects in group
    let contents = groupContentsBase(&group.pointee.objectData)

    for i in 0..<n {
        MO_DisposeObjectReference(contents[i]) // dispose of this object's ref
    }
}

// Decrement reference to the material used in this sprite
private func disposeObjectSprite(_ obj: UnsafeMutablePointer<MOSpriteObject>) {
    MO_DisposeObjectReference(obj.pointee.objectData.material.map { UnsafeMutableRawPointer($0) })
}

// Assumes the contents (the materials) have already been dereferenced!
func MO_DeleteObjectInfo_Geometry_VertexArray(_ data: UnsafeMutablePointer<MOVertexArrayData>!) {
    let varType = data.pointee.VARtype
    let usingVAR = varType != -1 // were these arrays stored in VAR memory?

    // DEREFERENCE ANY MATERIALS

    let n = Int(data.pointee.numMaterials)
    let materials = materialsBase(data)
    for i in 0..<n {
        MO_DisposeObjectReference(materials[i].map { UnsafeMutableRawPointer($0) }) // dispose of this object's ref
    }

    // DISPOSE OF VARIOUS ARRAYS

    if data.pointee.points != nil {
        if usingVAR {
            OGL_FreeVertexArrayMemory(data.pointee.points, UInt8(varType))
        } else {
            SafeDisposePtr(data.pointee.points)
        }
        data.pointee.points = nil
    }

    if data.pointee.normals != nil {
        if usingVAR {
            OGL_FreeVertexArrayMemory(data.pointee.normals, UInt8(varType))
        } else {
            SafeDisposePtr(data.pointee.normals)
        }
        data.pointee.normals = nil
    }

    let uvs = uvsBase(data)
    if uvs[0] != nil {
        if usingVAR {
            OGL_FreeVertexArrayMemory(uvs[0], UInt8(varType))
        } else {
            SafeDisposePtr(uvs[0])
        }
        uvs[0] = nil

        if data.pointee.numMaterials == 2 { // see if also nuke secondary uv list
            if uvs[1] != nil {
                if usingVAR {
                    OGL_FreeVertexArrayMemory(uvs[1], UInt8(varType))
                } else {
                    SafeDisposePtr(uvs[1])
                }

                uvs[1] = nil
            }
        }
    }

    if data.pointee.colorsFloat != nil {
        if usingVAR {
            OGL_FreeVertexArrayMemory(data.pointee.colorsFloat, UInt8(varType))
        } else {
            SafeDisposePtr(data.pointee.colorsFloat)
        }
        data.pointee.colorsFloat = nil
    }

    if data.pointee.triangles != nil {
        if usingVAR {
            OGL_FreeVertexArrayMemory(data.pointee.triangles, UInt8(varType))
        } else {
            SafeDisposePtr(data.pointee.triangles)
        }
        data.pointee.triangles = nil
    }
}

private func deleteObjectInfoMaterial(_ obj: UnsafeMutablePointer<MOMaterialObject>) {
    let data = obj.pointer(to: \.objectData)!

    // DISPOSE OF TEXTURE NAMES

    if data.pointee.numMipmaps > 0 {
        glDeleteTextures(GLsizei(data.pointee.numMipmaps), textureNameBase(data))
    }
}

private func deleteObjectInfoPicture(_ obj: UnsafeMutablePointer<MOPictureObject>) {
    let data = obj.pointer(to: \.objectData)!

    // DEREFERENCE THE MATERIALS

    MO_DisposeObjectReference(data.pointee.material.map { UnsafeMutableRawPointer($0) })
    data.pointee.material = nil
}

// MARK: - Duplicate

// Duplicates all of the data associated with a VertexArray definition.
// varType determines how we want to handle the new arrays.  If varType == -1 then we just
// allocate them in regular RAM.  Otherwise, we're using Vertex Array Range memory.
func MO_DuplicateVertexArrayData(_ inData: UnsafeMutablePointer<MOVertexArrayData>!, _ outData: UnsafeMutablePointer<MOVertexArrayData>!, _ varType: Int16) {
    let usingVAR = varType != -1

    // GET NEW REFERENCES TO MATERIALS

    outData.pointee.VARtype = varType // set new data's VAR type

    let n = Int(inData.pointee.numMaterials)
    outData.pointee.numMaterials = inData.pointee.numMaterials

    let inMaterials = materialsBase(inData)
    let outMaterials = materialsBase(outData)
    for i in 0..<n {
        _ = MO_GetNewReference(inMaterials[i].map { UnsafeMutableRawPointer($0) })
        outMaterials[i] = inMaterials[i]
    }

    // DUPLICATE THE ARRAYS

    // POINTS

    let numPoints = Int(inData.pointee.numPoints)
    outData.pointee.numPoints = inData.pointee.numPoints
    var s = numPoints * MemoryLayout<OGLPoint3D>.size

    if inData.pointee.points != nil {
        if usingVAR {
            outData.pointee.points = OGL_AllocVertexArrayMemory(s, UInt8(varType))?.assumingMemoryBound(to: OGLPoint3D.self)
        } else {
            outData.pointee.points = AllocPtr(s)?.assumingMemoryBound(to: OGLPoint3D.self)
        }

        SwBlockMove(inData.pointee.points, outData.pointee.points, s)
    } else {
        outData.pointee.points = nil
    }

    // NORMALS

    s = numPoints * MemoryLayout<OGLVector3D>.size

    if inData.pointee.normals != nil {
        if usingVAR {
            outData.pointee.normals = OGL_AllocVertexArrayMemory(s, UInt8(varType))?.assumingMemoryBound(to: OGLVector3D.self)
        } else {
            outData.pointee.normals = AllocPtr(s)?.assumingMemoryBound(to: OGLVector3D.self)
        }

        SwBlockMove(inData.pointee.normals, outData.pointee.normals, s)
    } else {
        outData.pointee.normals = nil
    }

    // UVS

    s = numPoints * MemoryLayout<OGLTextureCoord>.size

    let inUvs = uvsBase(inData)
    let outUvs = uvsBase(outData)

    if inUvs[0] != nil {
        if usingVAR {
            outUvs[0] = OGL_AllocVertexArrayMemory(s, UInt8(varType))?.assumingMemoryBound(to: OGLTextureCoord.self)
        } else {
            outUvs[0] = AllocPtr(s)?.assumingMemoryBound(to: OGLTextureCoord.self)
        }

        SwBlockMove(inUvs[0], outUvs[0], s)
    } else {
        outUvs[0] = nil
    }

    // COLORS FLOAT

    s = numPoints * MemoryLayout<OGLColorRGBA>.size

    if inData.pointee.colorsFloat != nil {
        if usingVAR {
            outData.pointee.colorsFloat = OGL_AllocVertexArrayMemory(s, UInt8(varType))?.assumingMemoryBound(to: OGLColorRGBA.self)
        } else {
            outData.pointee.colorsFloat = AllocPtr(s)?.assumingMemoryBound(to: OGLColorRGBA.self)
        }

        SwBlockMove(inData.pointee.colorsFloat, outData.pointee.colorsFloat, s)
    } else {
        outData.pointee.colorsFloat = nil
    }

    // TRIANGLES

    let numTriangles = Int(inData.pointee.numTriangles)
    outData.pointee.numTriangles = inData.pointee.numTriangles
    s = numTriangles * MemoryLayout<GLint>.size * 3

    if inData.pointee.triangles != nil {
        if usingVAR {
            outData.pointee.triangles = OGL_AllocVertexArrayMemory(s, UInt8(varType))?.assumingMemoryBound(to: MOTriangleIndecies.self)
        } else {
            outData.pointee.triangles = AllocPtr(s)?.assumingMemoryBound(to: MOTriangleIndecies.self)
        }

        SwBlockMove(inData.pointee.triangles, outData.pointee.triangles, s)
    } else {
        outData.pointee.triangles = nil
    }
}

// MARK: - Bounding Box / Sphere

// INPUT:
//			m = transform matrix to apply to verts or nil.
func MO_CalcBoundingBox(_ object: MetaObjectPtr!, _ bBox: UnsafeMutablePointer<OGLBoundingBox>!, _ m: UnsafeMutablePointer<OGLMatrix4x4>!) {
    // INIT BBOX TO BOGUS VALUES

    bBox.pointee.min.x = 100000000
    bBox.pointee.min.y = 100000000
    bBox.pointee.min.z = 100000000

    bBox.pointee.max.x = -bBox.pointee.min.x
    bBox.pointee.max.y = -bBox.pointee.min.x
    bBox.pointee.max.z = -bBox.pointee.min.x

    bBox.pointee.isEmpty = 0

    // RECURSIVELY CALC BBOX

    calcBoundingBoxRecurse(object, bBox, m)
}

private var tpoints = [OGLPoint3D](repeating: OGLPoint3D(), count: 1000)

private func calcBoundingBoxRecurse(_ object: MetaObjectPtr, _ bBox: UnsafeMutablePointer<OGLBoundingBox>, _ m: UnsafeMutablePointer<OGLMatrix4x4>?) {
    let objHead = object.assumingMemoryBound(to: MetaObjectHeader.self)

    // VERIFY COOKIE

    if objHead.pointee.cookie != UInt32(MO_COOKIE) {
        SwFatal("MO_CalcBoundingBox_Recurse: cookie is invalid!")
    }

    switch objHead.pointee.type {
    // CALC BBOX OF GEOMETRY

    case .geometry:
        switch objHead.pointee.subType {
        case Int(MO_GEOMETRY_SUBTYPE_VERTEXARRAY):
            let vObj = object.assumingMemoryBound(to: MOVertexArrayObject.self)
            let geoData = vObj.pointer(to: \.objectData)!
            let numPoints = Int(geoData.pointee.numPoints)

            // TRANSFORM POINTS

            if let m {
                if numPoints > 1000 { // make sure not overflowing buffer
                    SwFatal("MO_CalcBoundingBox_Recurse: buffer overflow!")
                    return
                }

                tpoints.withUnsafeMutableBufferPointer { buf in
                    OGLPoint3D.transformArray(geoData.pointee.points, by: m.pointee, into: buf.baseAddress, count: numPoints)
                }
                for i in 0..<numPoints {
                    let x = tpoints[i].x
                    let y = tpoints[i].y
                    let z = tpoints[i].z

                    if x < bBox.pointee.min.x { bBox.pointee.min.x = x }
                    if x > bBox.pointee.max.x { bBox.pointee.max.x = x }

                    if y < bBox.pointee.min.y { bBox.pointee.min.y = y }
                    if y > bBox.pointee.max.y { bBox.pointee.max.y = y }

                    if z < bBox.pointee.min.z { bBox.pointee.min.z = z }
                    if z > bBox.pointee.max.z { bBox.pointee.max.z = z }
                }
            }

            // NO TRANSFORM, USE RAW DATA

            else {
                for i in 0..<numPoints {
                    let x = geoData.pointee.points![i].x
                    let y = geoData.pointee.points![i].y
                    let z = geoData.pointee.points![i].z

                    if x < bBox.pointee.min.x { bBox.pointee.min.x = x }
                    if x > bBox.pointee.max.x { bBox.pointee.max.x = x }

                    if y < bBox.pointee.min.y { bBox.pointee.min.y = y }
                    if y > bBox.pointee.max.y { bBox.pointee.max.y = y }

                    if z < bBox.pointee.min.z { bBox.pointee.min.z = z }
                    if z > bBox.pointee.max.z { bBox.pointee.max.z = z }
                }
            }

        default:
            SwFatal("MO_CalcBoundingBox_Recurse: unknown sub-type!")
        }

    // RECURSE THRU GROUP

    case .group:
        let groupObject = object.assumingMemoryBound(to: MOGroupObject.self)
        let numChildren = Int(groupObject.pointee.objectData.numObjectsInGroup)
        let contents = groupContentsBase(&groupObject.pointee.objectData)
        for i in 0..<numChildren {
            calcBoundingBoxRecurse(contents[i]!, bBox, m)
        }

    // MATRIX

    case .matrix:
        SwFatal("MO_CalcBoundingBox_Recurse: why is there a matrix here?")

    default:
        break
    }
}

func MO_CalcBoundingSphere(_ object: MetaObjectPtr!, _ bSphere: UnsafeMutablePointer<Float>!) {
    bSphere.pointee = 0

    // RECURSIVELY CALC SPHERE

    calcBoundingSphereRecurse(object, bSphere)
}

private func calcBoundingSphereRecurse(_ object: MetaObjectPtr, _ bSphere: UnsafeMutablePointer<Float>) {
    let objHead = object.assumingMemoryBound(to: MetaObjectHeader.self)

    // VERIFY COOKIE

    if objHead.pointee.cookie != UInt32(MO_COOKIE) {
        SwFatal("MO_CalcBoundingSphere_Recurse: cookie is invalid!")
    }

    switch objHead.pointee.type {
    // CALC BBOX OF GEOMETRY

    case .geometry:
        switch objHead.pointee.subType {
        case Int(MO_GEOMETRY_SUBTYPE_VERTEXARRAY):
            let vObj = object.assumingMemoryBound(to: MOVertexArrayObject.self)
            let geoData = vObj.pointer(to: \.objectData)!
            let numPoints = Int(geoData.pointee.numPoints)

            for i in 0..<numPoints {
                let point = geoData.pointee.points![i]
                let d = OGLVector3D(x: point.x, y: point.y, z: point.z).length // calc this radius
                if d > bSphere.pointee { // is this the best?
                    bSphere.pointee = d
                }
            }

        default:
            SwFatal("MO_CalcBoundingSphere_Recurse: unknown sub-type!")
        }

    // RECURSE THRU GROUP

    case .group:
        let groupObject = object.assumingMemoryBound(to: MOGroupObject.self)
        let numChildren = Int(groupObject.pointee.objectData.numObjectsInGroup)
        let contents = groupContentsBase(&groupObject.pointee.objectData)
        for i in 0..<numChildren {
            calcBoundingSphereRecurse(contents[i]!, bSphere)
        }

    // MATRIX

    case .matrix:
        SwFatal("MO_CalcBoundingSphere_Recurse: why is there a matrix here?")

    default:
        break
    }
}

// MARK: - UV Offsetting

func MO_Object_OffsetUVs(_ object: MetaObjectPtr!, _ du: Float, _ dv: Float) {
    let objHead = object.assumingMemoryBound(to: MetaObjectHeader.self)

    // VERIFY COOKIE

    if objHead.pointee.cookie != UInt32(MO_COOKIE) {
        SwFatal("MO_Group_OffsetUVs: cookie is invalid!")
    }

    // HANDLE IT

    switch objHead.pointee.type {
    case .geometry:
        MO_VertexArray_OffsetUVs(object, du, dv)

    case .group:
        let group = object.assumingMemoryBound(to: MOGroupObject.self)
        let data = group.pointer(to: \.objectData)!

        // PARSE OBJECTS IN GROUP

        let contents = groupContentsBase(data)
        for i in 0..<Int(data.pointee.numObjectsInGroup) {
            switch contents[i]!.assumingMemoryBound(to: MetaObjectHeader.self).pointee.type {
            case .geometry:
                MO_VertexArray_OffsetUVs(contents[i], du, dv)

            case .group:
                MO_Object_OffsetUVs(contents[i], du, dv) // recurse this sub-group

            default:
                break
            }
        }

    default:
        SwFatal("MO_Group_OffsetUVs: object type is not supported.")
    }
}

func MO_VertexArray_OffsetUVs(_ object: MetaObjectPtr!, _ du: Float, _ dv: Float) {
    let objHead = object.assumingMemoryBound(to: MetaObjectHeader.self)

    // VERIFY COOKIE

    if objHead.pointee.cookie != UInt32(MO_COOKIE) {
        SwFatal("MO_VertexArray_OffsetUVs: cookie is invalid!")
    }

    // MAKE SURE IT IS A VERTEX ARRAY

    if (objHead.pointee.type != .geometry) || (objHead.pointee.subType != Int(MO_GEOMETRY_SUBTYPE_VERTEXARRAY)) {
        SwFatal("MO_VertexArray_OffsetUVs: object is not a Vertex Array!")
    }

    let vObj = object.assumingMemoryBound(to: MOVertexArrayObject.self)
    let data = vObj.pointer(to: \.objectData)! // point to data

    guard let uvPtr = uvsBase(data)[0] else { // point to uv list
        return
    }

    let numPoints = Int(data.pointee.numPoints) // get # points

    // OFFSET THE UV'S

    for i in 0..<numPoints {
        uvPtr[i].u += du
        uvPtr[i].v += dv
    }

    // THIS UPDATE WILL CAUSE US TO UPDATE THE VAR IF IT'S USED

    OGL_SetVertexArrayRangeDirty(data.pointee.VARtype)
}
