// Sprites.swift - Port of Sprites.c to Swift

private func LoadSpriteFromDualImage(_ path: String) -> SpriteType {
    // LOAD TEXTURE FROM IMAGE FILE

    var width: Int32 = 0
    var height: Int32 = 0
    var hasAlpha: Int32 = 0
    let textureName = OGL_TextureMap_LoadImageFile(path, &width, &height, &hasAlpha)
    SwGameAssert(textureName != 0)

    // SET UP MATERIAL

    var matData = MOMaterialData()
    matData.flags = UInt32(BG3D_MATERIALFLAG_TEXTURED) | (hasAlpha != 0 ? UInt32(BG3D_MATERIALFLAG_ALWAYSBLEND) : 0)
    matData.diffuseColor = OGLColorRGBA(r: 1, g: 1, b: 1, a: 1)
    matData.width = UInt32(width)
    matData.height = UInt32(height)
    matData.numMipmaps = 1
    matData.textureName = (textureName, 0, 0, 0, 0, 0)

    var sprite = SpriteType()
    sprite.width = Int32(matData.width)
    sprite.height = Int32(matData.height)
    sprite.aspectRatio = Float(matData.height) / Float(matData.height)
    sprite.materialObject = MO_CreateNewObjectOfType(.MO_TYPE_MATERIAL, 0, &matData)
    return sprite
}

@c @implementation
public func InitSpriteManager() {
    for i in 0..<Int32(MAX_SPRITE_GROUPS) {
        SetSpriteGroupList(i, nil)
        SetNumSpritesInGroup(i, 0)
    }
}

@c @implementation
public func DisposeAllSpriteGroups() {
    for i in 0..<Int32(MAX_SPRITE_GROUPS) {
        if GetSpriteGroupList(i) != nil {
            DisposeSpriteGroup(i)
        }
    }
}

@c @implementation
public func DisposeSpriteGroup(_ groupNum: Int32) {
    let n = GetNumSpritesInGroup(groupNum) // get # sprites in this group
    if n == 0 || GetSpriteGroupList(groupNum) == nil {
        return
    }

    // DISPOSE OF ALL LOADED OPENGL TEXTURENAMES

    let group = GetSpriteGroupList(groupNum)!
    for i in 0..<Int(n) {
        MO_DisposeObjectReference(group[i].materialObject)
    }

    // DISPOSE OF GROUP'S ARRAY

    SafeDisposePtr(group)
    SetSpriteGroupList(groupNum, nil)
    SetNumSpritesInGroup(groupNum, 0)
}

// Not declared in any header — only used within this file.
private func AllocSpriteGroup(_ groupNum: Int32, _ capacity: Int32) {
    SwGameAssertMessage(GetSpriteGroupList(groupNum) == nil, "Sprite group already allocated")
    SwGameAssert(GetNumSpritesInGroup(groupNum) == 0)

    SetNumSpritesInGroup(groupNum, capacity)

    let newGroup = AllocPtrClear(MemoryLayout<SpriteType>.size * Int(capacity))!.assumingMemoryBound(to: SpriteType.self)
    SetSpriteGroupList(groupNum, newGroup)
    SwGameAssert(GetSpriteGroupList(groupNum) != nil)
}

@c @implementation
public func LoadSpriteGroupFromFile(_ groupNum: Int32, _ path: UnsafePointer<CChar>, _ flags: Int32) {
    AllocSpriteGroup(groupNum, 1)
    GetSpriteGroupList(groupNum)![0] = LoadSpriteFromDualImage(String(cString: path))
    SwGameAssert(GetSpriteGroupList(groupNum)![0].materialObject != nil)
}

@c @implementation
public func LoadSpriteGroupFromSeries(_ groupNum: Int32, _ numSprites: Int32, _ seriesName: UnsafePointer<CChar>) {
    AllocSpriteGroup(groupNum, numSprites)

    let seriesNameStr = String(cString: seriesName)
    let group = GetSpriteGroupList(groupNum)!
    for i in 0..<GetNumSpritesInGroup(groupNum) {
        var numStr = String(i)
        while numStr.count < 3 { numStr = "0" + numStr }
        let path = ":Sprites:\(seriesNameStr):\(seriesNameStr)\(numStr)"
        group[Int(i)] = LoadSpriteFromDualImage(path)
        SwGameAssert(group[Int(i)].materialObject != nil)
    }
}

@c @implementation
public func LoadSpriteGroupFromFiles(_ groupNum: Int32, _ numSprites: Int32, _ spritePaths: UnsafeMutablePointer<UnsafePointer<CChar>>) {
    AllocSpriteGroup(groupNum, numSprites)

    let group = GetSpriteGroupList(groupNum)!
    for i in 0..<GetNumSpritesInGroup(groupNum) {
        group[Int(i)] = LoadSpriteFromDualImage(String(cString: spritePaths[Int(i)]))
        SwGameAssert(group[Int(i)].materialObject != nil)
    }
}

@c @implementation
public func MakeSpriteObject(_ newObjDef: UnsafeMutablePointer<NewObjectDefinitionType>, _ drawCentered: UInt8) -> UnsafeMutablePointer<ObjNode>? {
    // ERROR CHECK

    if Int32(newObjDef.pointee.type) >= GetNumSpritesInGroup(Int32(newObjDef.pointee.group)) {
        SwFatal("MakeSpriteObject: illegal type")
    }

    // MAKE OBJNODE

    newObjDef.pointee.genre = UInt8(SPRITE_GENRE)
    newObjDef.pointee.flags |= UInt32(STATUS_BIT_DOUBLESIDED) | UInt32(STATUS_BIT_NOZBUFFER) | UInt32(STATUS_BIT_NOLIGHTING) | UInt32(STATUS_BIT_NOTEXTUREWRAP)

    guard let newObj = MakeNewObject(newObjDef) else {
        return nil
    }

    // MAKE SPRITE META-OBJECT

    var spriteData = MOSpriteSetupData()
    spriteData.loadFile = 0 // these sprites are already loaded into gSpriteList
    spriteData.group = Int16(newObjDef.pointee.group) // set group
    spriteData.type = Int16(newObjDef.pointee.type) // set group subtype
    spriteData.drawCentered = drawCentered

    guard let spriteMORaw = MO_CreateNewObjectOfType(.MO_TYPE_SPRITE, 0, &spriteData) else {
        SwFatal("MakeSpriteObject: MO_CreateNewObjectOfType failed!")
        return nil
    }
    let spriteMO = spriteMORaw.assumingMemoryBound(to: MOSpriteObject.self)

    // SET SPRITE MO INFO

    spriteMO.pointee.objectData.scaleY = newObj.pointee.Scale.x
    spriteMO.pointee.objectData.scaleX = newObj.pointee.Scale.x
    spriteMO.pointee.objectData.coord = newObj.pointee.Coord

    // ATTACH META OBJECT TO OBJNODE

    newObj.pointee.SpriteMO = spriteMO

    return newObj
}

// Set the blending flag for all sprites in the group.
@c @implementation
public func BlendAllSpritesInGroup(_ group: Int16) {
    let n = GetNumSpritesInGroup(Int32(group)) // get # sprites in this group
    if n == 0 || GetSpriteGroupList(Int32(group)) == nil {
        SwFatal("BlendAllSpritesInGroup: this group is empty")
    }

    let list = GetSpriteGroupList(Int32(group))!
    for i in 0..<Int(n) {
        guard let m = list[i].materialObject else {
            SwFatal("BlendAllSpritesInGroup: material == nil")
            return
        }
        let material = m.assumingMemoryBound(to: MOMaterialObject.self)
        material.pointee.objectData.flags |= UInt32(BG3D_MATERIALFLAG_ALWAYSBLEND) // set flag
    }
}

// Set the blending flag for 1 sprite in the group.
@c @implementation
public func BlendASprite(_ group: Int32, _ type: Int32) {
    if type >= GetNumSpritesInGroup(group) {
        SwFatal("BlendASprite: illegal type")
    }

    guard let m = GetSpriteGroupList(group)![Int(type)].materialObject else {
        SwFatal("BlendASprite: material == nil")
        return
    }
    let material = m.assumingMemoryBound(to: MOMaterialObject.self)
    material.pointee.objectData.flags |= UInt32(BG3D_MATERIALFLAG_ALWAYSBLEND) // set flag
}
