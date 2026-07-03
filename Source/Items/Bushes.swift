// Bushes.swift - Port of Bushes.c to Swift

@c @implementation
public func AddGrass(_ itemPtr: UnsafeMutablePointer<TerrainItemEntryType>!, _ x: Float, _ z: Float) -> UInt8 {
    var def = NewObjectDefinitionType()
    def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
    def.scale = 2.0 + RandomFloat2() * 0.3
    def.coord.x = x
    def.coord.z = z
    def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
    def.slot = 876
    def.moveCall = MoveStaticObject
    def.rot = RandomFloat() * SwPI2

    def.coord.y = GetMinTerrainY(x, z, Int16(def.group), Int16(def.type), 1.0)

    let type: Int32
    switch gLevelNum {
    case Int16(LevelNum.adventure1.rawValue), Int16(LevelNum.flag2.rawValue), Int16(LevelNum.battle1.rawValue):
        type = Int32(LEVEL1_ObjType_Grass) + Int32(itemPtr.pointee.parm.0)
    case Int16(LevelNum.adventure2.rawValue), Int16(LevelNum.race2.rawValue), Int16(LevelNum.battle2.rawValue):
        type = Int32(LEVEL2_ObjType_Grass) + Int32(itemPtr.pointee.parm.0)
    case Int16(LevelNum.adventure3.rawValue), Int16(LevelNum.race1.rawValue), Int16(LevelNum.flag1.rawValue):
        type = Int32(LEVEL3_ObjType_Grass_Single) + Int32(itemPtr.pointee.parm.0)
    default:
        return 0
    }
    def.type = UInt8(type)

    let newObj = MakeNewDisplayGroupObject(&def)!

    newObj.pointee.TerrainItemPtr = itemPtr // keep ptr to item list

    // SET COLLISION STUFF

    newObj.pointee.CType = UInt32(CTYPE_TRIGGER)
    newObj.pointee.CBits = 0
    CreateCollisionBoxFromBoundingBox_Rotated(newObj, 0.7, 0.3)

    newObj.pointee.TriggerCallback = cDoTrigGrass

    return 1 // item was added
}

// Returns TRUE if want to handle hit as a solid
private let cDoTrigGrass: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?) -> UInt8 = { _, playerOpt in
    let player = playerOpt!

    if GetPlayerInfoEntry(Int32(player.pointee.PlayerNum))!.pointee.carriedObj == nil { // only disorient if not carrying egg
        DisorientPlayer(player)
    }

    return 0
}

// MARK: - Fern

@c @implementation
public func AddFern(_ itemPtr: UnsafeMutablePointer<TerrainItemEntryType>!, _ x: Float, _ z: Float) -> UInt8 {
    var def = NewObjectDefinitionType()
    def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
    def.type = UInt8(Int32(LEVEL1_ObjType_LowFern) + Int32(itemPtr.pointee.parm.0))
    def.scale = 1.4 + RandomFloat2() * 0.3
    def.coord.x = x
    def.coord.z = z
    def.coord.y = itemPtr.pointee.terrainY
    def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
    def.slot = 264
    def.moveCall = MoveStaticObject
    def.rot = RandomFloat() * SwPI2

    let newObj = MakeNewDisplayGroupObject(&def)!

    newObj.pointee.TerrainItemPtr = itemPtr // keep ptr to item list

    // SET COLLISION STUFF (disabled in the original C source)

    return 1 // item was added
}

// MARK: - Berry Bush

@c @implementation
public func AddBerryBush(_ itemPtr: UnsafeMutablePointer<TerrainItemEntryType>!, _ x: Float, _ z: Float) -> UInt8 {
    var def = NewObjectDefinitionType()
    def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
    def.type = UInt8(Int32(LEVEL1_ObjType_LowBerryBush) + Int32(itemPtr.pointee.parm.0))
    def.scale = 2.0 + RandomFloat2() * 0.3
    def.coord.x = x
    def.coord.z = z
    def.coord.y = itemPtr.pointee.terrainY
    def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
    def.slot = 491
    def.moveCall = MoveStaticObject
    def.rot = RandomFloat() * SwPI2

    let newObj = MakeNewDisplayGroupObject(&def)!

    newObj.pointee.TerrainItemPtr = itemPtr // keep ptr to item list

    // SET COLLISION STUFF

    newObj.pointee.CType = UInt32(CTYPE_MISC | CTYPE_TRIGGER | CTYPE_WEAPONTEST)
    newObj.pointee.CBits = UInt32(CBITS_ALLSOLID)
    CreateCollisionBoxFromBoundingBox(newObj, 0.4, 0.3)

    newObj.pointee.TriggerCallback = DoTrig_MiscSmackableObject

    return 1 // item was added
}

// MARK: - Cattail

@c @implementation
public func AddCatTail(_ itemPtr: UnsafeMutablePointer<TerrainItemEntryType>!, _ x: Float, _ z: Float) -> UInt8 {
    let randomRot = itemPtr.pointee.parm.3 & 1 != 0

    var def = NewObjectDefinitionType()
    def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
    def.type = UInt8(Int32(LEVEL1_ObjType_SmallCattail) + Int32(itemPtr.pointee.parm.0))
    def.scale = 1.4 + RandomFloat2() * 0.3
    def.rot = randomRot ? (RandomFloat() * SwPI2) : (Float(itemPtr.pointee.parm.1) * (SwPI2 / 8.0))
    def.coord.x = x
    def.coord.z = z
    def.coord.y = itemPtr.pointee.terrainY
    def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
    def.slot = 821
    def.moveCall = MoveStaticObject

    let newObj = MakeNewDisplayGroupObject(&def)!

    newObj.pointee.TerrainItemPtr = itemPtr // keep ptr to item list

    // SET COLLISION STUFF (disabled in the original C source)

    return 1 // item was added
}

// MARK: - Desert Bush

@c @implementation
public func AddDesertBush(_ itemPtr: UnsafeMutablePointer<TerrainItemEntryType>!, _ x: Float, _ z: Float) -> UInt8 {
    if itemPtr.pointee.parm.0 > 3 {
        SwFatal("AddDesertBush: illegal subtype")
    }

    let halfSizeFlag = itemPtr.pointee.parm.3 & 1 != 0 // bit 0 is the half-size flag

    var def = NewObjectDefinitionType()
    def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
    def.type = UInt8(Int32(LEVEL2_ObjType_Bush1) + Int32(itemPtr.pointee.parm.0))
    def.scale = halfSizeFlag ? (1.0 + RandomFloat2() * 0.15) : (2.0 + RandomFloat2() * 0.3)
    def.coord.x = x
    def.coord.z = z
    def.coord.y = itemPtr.pointee.terrainY
    def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
    def.slot = 491
    def.moveCall = MoveStaticObject
    def.rot = RandomFloat() * SwPI2

    let newObj = MakeNewDisplayGroupObject(&def)!

    newObj.pointee.TerrainItemPtr = itemPtr // keep ptr to item list

    // SET COLLISION STUFF

    newObj.pointee.Damage = 0.25

    newObj.pointee.CType = UInt32(CTYPE_MISC | CTYPE_TRIGGER | CTYPE_WEAPONTEST)
    newObj.pointee.CBits = UInt32(CBITS_ALLSOLID)
    CreateCollisionBoxFromBoundingBox_Rotated(newObj, 0.4, 0.6)

    newObj.pointee.TriggerCallback = cDoTrigDesertBush

    return 1 // item was added
}

// Returns TRUE if want to handle hit as a solid
private let cDoTrigDesertBush: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?) -> UInt8 = { treeOpt, playerOpt in
    let tree = treeOpt!
    let player = playerOpt!
    let p = player.pointee.PlayerNum

    if GetPlayerInfoEntry(Int32(p))!.pointee.invincibilityTimer > 0.0 {
        return 0
    }

    if gGamePrefs.kiddieMode == 0 { // don't hurt in kiddie mode
        if MyRandomLong() & 1 != 0 {
            _ = PlayerLoseHealth(Int16(p), tree.pointee.Damage, UInt8(PlayerDeathType.deathDive.rawValue), nil, 1)
        } else {
            _ = PlayerLoseHealth(Int16(p), tree.pointee.Damage, UInt8(PlayerDeathType.explode.rawValue), nil, 1)
        }
    }

    GetPlayerInfoEntry(Int32(p))!.pointee.invincibilityTimer = 0.5

    PlayEffect3D(Int16(EFFECT_BODYHIT), &player.pointee.Coord)
    PlayRumbleEffect(Int16(EFFECT_BODYHIT), Int32(p))

    return 0
}

// MARK: - Cactus

@c @implementation
public func AddCactus(_ itemPtr: UnsafeMutablePointer<TerrainItemEntryType>!, _ x: Float, _ z: Float) -> UInt8 {
    if itemPtr.pointee.parm.0 > 2 {
        SwFatal("AddCactus: illegal subtype")
    }

    var def = NewObjectDefinitionType()
    def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
    def.type = UInt8(Int32(LEVEL2_ObjType_Cactus_Low) + Int32(itemPtr.pointee.parm.0))
    def.scale = 2.0 + RandomFloat2() * 0.3
    def.coord.x = x
    def.coord.z = z
    def.coord.y = itemPtr.pointee.terrainY
    def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
    def.slot = 491
    def.moveCall = MoveStaticObject
    def.rot = RandomFloat() * SwPI2

    let newObj = MakeNewDisplayGroupObject(&def)!

    newObj.pointee.TerrainItemPtr = itemPtr // keep ptr to item list

    RotateOnTerrain(newObj, -2, nil) // keep flat on terrain
    SetObjectTransformMatrix(newObj)

    // SET COLLISION STUFF

    newObj.pointee.CType = UInt32(CTYPE_MISC | CTYPE_TRIGGER | CTYPE_WEAPONTEST)
    newObj.pointee.CBits = UInt32(CBITS_ALLSOLID)
    CreateCollisionBoxFromBoundingBox_Rotated(newObj, 0.8, 0.8)

    newObj.pointee.Damage = 0.8

    newObj.pointee.TriggerCallback = DoTrig_MiscSmackableObject

    return 1 // item was added
}

// MARK: - Palm Bush

@c @implementation
public func AddPalmBush(_ itemPtr: UnsafeMutablePointer<TerrainItemEntryType>!, _ x: Float, _ z: Float) -> UInt8 {
    if itemPtr.pointee.parm.0 > 2 {
        SwFatal("AddPalmBush: illegal subtype")
    }

    var def = NewObjectDefinitionType()
    def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
    def.type = UInt8(Int32(LEVEL2_ObjType_PalmBush1) + Int32(itemPtr.pointee.parm.0))
    def.scale = 2.0 + RandomFloat2() * 0.3
    def.coord.x = x
    def.coord.z = z
    def.coord.y = itemPtr.pointee.terrainY
    def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
    def.slot = 491
    def.moveCall = MoveStaticObject
    def.rot = RandomFloat() * SwPI2

    let newObj = MakeNewDisplayGroupObject(&def)!

    newObj.pointee.TerrainItemPtr = itemPtr // keep ptr to item list

    // SET COLLISION STUFF

    newObj.pointee.CType = UInt32(CTYPE_MISC | CTYPE_TRIGGER | CTYPE_WEAPONTEST)
    newObj.pointee.CBits = UInt32(CBITS_ALLSOLID)
    CreateCollisionBoxFromBoundingBox_Rotated(newObj, 0.5, 0.6)

    newObj.pointee.Damage = 0.5
    newObj.pointee.TriggerCallback = cDoTrigDesertBush

    return 1 // item was added
}

// MARK: - Gecko Plant

@c @implementation
public func AddGeckoPlant(_ itemPtr: UnsafeMutablePointer<TerrainItemEntryType>!, _ x: Float, _ z: Float) -> UInt8 {
    if itemPtr.pointee.parm.0 > 2 {
        SwFatal("AddGeckoPlant: illegal subtype")
    }

    var def = NewObjectDefinitionType()
    def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
    def.type = UInt8(Int32(LEVEL3_ObjType_GeckoPlant_Small) + Int32(itemPtr.pointee.parm.0))
    def.scale = 2.0 + RandomFloat2() * 1.0
    def.coord.x = x
    def.coord.z = z
    def.coord.y = itemPtr.pointee.terrainY
    def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
    def.slot = 60
    def.moveCall = MoveStaticObject
    def.rot = RandomFloat() * SwPI2

    let newObj = MakeNewDisplayGroupObject(&def)!

    newObj.pointee.TerrainItemPtr = itemPtr // keep ptr to item list

    RotateOnTerrain(newObj, -2, nil) // keep flat on terrain
    SetObjectTransformMatrix(newObj)

    // SET COLLISION STUFF

    newObj.pointee.CType = UInt32(CTYPE_MISC | CTYPE_TRIGGER | CTYPE_WEAPONTEST)
    newObj.pointee.CBits = UInt32(CBITS_ALLSOLID)
    CreateCollisionBoxFromBoundingBox_Rotated(newObj, 0.5, 0.5)

    newObj.pointee.Damage = 0.6

    newObj.pointee.TriggerCallback = cDoTrigDesertBush

    return 1 // item was added
}

// MARK: - Sprout Plant

@c @implementation
public func AddSproutPlant(_ itemPtr: UnsafeMutablePointer<TerrainItemEntryType>!, _ x: Float, _ z: Float) -> UInt8 {
    var def = NewObjectDefinitionType()
    def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
    def.type = UInt8(LEVEL3_ObjType_SproutPlant)
    def.scale = 2.5 + RandomFloat2() * 0.3
    def.coord.x = x
    def.coord.z = z
    def.coord.y = itemPtr.pointee.terrainY
    def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
    def.slot = 40
    def.moveCall = MoveStaticObject
    def.rot = RandomFloat() * SwPI2

    let newObj = MakeNewDisplayGroupObject(&def)!

    newObj.pointee.TerrainItemPtr = itemPtr // keep ptr to item list

    // SET COLLISION STUFF (disabled in the original C source)

    return 1 // item was added
}

// MARK: - Ivy

@c @implementation
public func AddIvy(_ itemPtr: UnsafeMutablePointer<TerrainItemEntryType>!, _ x: Float, _ z: Float) -> UInt8 {
    let type = Int32(itemPtr.pointee.parm.0)
    let color = itemPtr.pointee.parm.1

    var def = NewObjectDefinitionType()
    def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
    def.type = UInt8((color == 0) ? (Int32(LEVEL3_ObjType_PurpleIvy_Small) + type) : (Int32(LEVEL3_ObjType_RedIvy_Small) + type))
    def.scale = 2.0 + RandomFloat2() * 0.3
    def.coord.x = x
    def.coord.z = z
    def.coord.y = itemPtr.pointee.terrainY
    def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
    def.slot = 30
    def.moveCall = MoveStaticObject
    def.rot = RandomFloat() * SwPI2

    let newObj = MakeNewDisplayGroupObject(&def)!

    newObj.pointee.TerrainItemPtr = itemPtr // keep ptr to item list

    // SET COLLISION STUFF (disabled in the original C source)

    return 1 // item was added
}
