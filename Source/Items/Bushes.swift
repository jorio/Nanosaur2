// Bushes.swift - Port of Bushes.c to Swift
//
// AddGrass/AddFern/etc. had zero remaining C callers (only referenced from
// items.h's declarations and Terrain2.swift's gTerrainItemAddRoutines table),
// so they're plain TerrainItemEntryType-pointer methods instead of
// @c @implementation free functions matching a C header signature.
// Terrain2.swift's dispatch table still needs @convention(c) closures (its
// element type is shared with dozens of still-free-function Add* routines),
// so each method there gets a thin cAddX wrapper, same pattern already
// established for cAddCrystal.

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    @discardableResult
    func addGrass(x: Float, z: Float) -> UInt8 {
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
            type = Int32(LEVEL1_ObjType_Grass) + Int32(pointee.parm.0)
        case Int16(LevelNum.adventure2.rawValue), Int16(LevelNum.race2.rawValue), Int16(LevelNum.battle2.rawValue):
            type = Int32(LEVEL2_ObjType_Grass) + Int32(pointee.parm.0)
        case Int16(LevelNum.adventure3.rawValue), Int16(LevelNum.race1.rawValue), Int16(LevelNum.flag1.rawValue):
            type = Int32(LEVEL3_ObjType_Grass_Single) + Int32(pointee.parm.0)
        default:
            return 0
        }
        def.type = UInt8(type)

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF

        newObj.pointee.CType = UInt32(CTYPE_TRIGGER)
        newObj.pointee.CBits = 0
        CreateCollisionBoxFromBoundingBox_Rotated(newObj, 0.7, 0.3)

        newObj.pointee.TriggerCallback = cDoTrigGrass

        return 1 // item was added
    }

    @discardableResult
    func addFern(x: Float, z: Float) -> UInt8 {
        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(Int32(LEVEL1_ObjType_LowFern) + Int32(pointee.parm.0))
        def.scale = 1.4 + RandomFloat2() * 0.3
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY
        def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
        def.slot = 264
        def.moveCall = MoveStaticObject
        def.rot = RandomFloat() * SwPI2

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF (disabled in the original C source)

        return 1 // item was added
    }

    @discardableResult
    func addBerryBush(x: Float, z: Float) -> UInt8 {
        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(Int32(LEVEL1_ObjType_LowBerryBush) + Int32(pointee.parm.0))
        def.scale = 2.0 + RandomFloat2() * 0.3
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY
        def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
        def.slot = 491
        def.moveCall = MoveStaticObject
        def.rot = RandomFloat() * SwPI2

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF

        newObj.pointee.CType = UInt32(CTYPE_MISC | CTYPE_TRIGGER | CTYPE_WEAPONTEST)
        newObj.pointee.CBits = UInt32(CBITS_ALLSOLID)
        CreateCollisionBoxFromBoundingBox(newObj, 0.4, 0.3)

        newObj.pointee.TriggerCallback = DoTrig_MiscSmackableObject

        return 1 // item was added
    }

    @discardableResult
    func addCatTail(x: Float, z: Float) -> UInt8 {
        let randomRot = pointee.parm.3 & 1 != 0

        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(Int32(LEVEL1_ObjType_SmallCattail) + Int32(pointee.parm.0))
        def.scale = 1.4 + RandomFloat2() * 0.3
        def.rot = randomRot ? (RandomFloat() * SwPI2) : (Float(pointee.parm.1) * (SwPI2 / 8.0))
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY
        def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
        def.slot = 821
        def.moveCall = MoveStaticObject

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF (disabled in the original C source)

        return 1 // item was added
    }

    @discardableResult
    func addDesertBush(x: Float, z: Float) -> UInt8 {
        if pointee.parm.0 > 3 {
            SwFatal("addDesertBush: illegal subtype")
        }

        let halfSizeFlag = pointee.parm.3 & 1 != 0 // bit 0 is the half-size flag

        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(Int32(LEVEL2_ObjType_Bush1) + Int32(pointee.parm.0))
        def.scale = halfSizeFlag ? (1.0 + RandomFloat2() * 0.15) : (2.0 + RandomFloat2() * 0.3)
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY
        def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
        def.slot = 491
        def.moveCall = MoveStaticObject
        def.rot = RandomFloat() * SwPI2

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF

        newObj.pointee.Damage = 0.25

        newObj.pointee.CType = UInt32(CTYPE_MISC | CTYPE_TRIGGER | CTYPE_WEAPONTEST)
        newObj.pointee.CBits = UInt32(CBITS_ALLSOLID)
        CreateCollisionBoxFromBoundingBox_Rotated(newObj, 0.4, 0.6)

        newObj.pointee.TriggerCallback = cDoTrigDesertBush

        return 1 // item was added
    }

    @discardableResult
    func addCactus(x: Float, z: Float) -> UInt8 {
        if pointee.parm.0 > 2 {
            SwFatal("addCactus: illegal subtype")
        }

        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(Int32(LEVEL2_ObjType_Cactus_Low) + Int32(pointee.parm.0))
        def.scale = 2.0 + RandomFloat2() * 0.3
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY
        def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
        def.slot = 491
        def.moveCall = MoveStaticObject
        def.rot = RandomFloat() * SwPI2

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

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

    @discardableResult
    func addPalmBush(x: Float, z: Float) -> UInt8 {
        if pointee.parm.0 > 2 {
            SwFatal("addPalmBush: illegal subtype")
        }

        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(Int32(LEVEL2_ObjType_PalmBush1) + Int32(pointee.parm.0))
        def.scale = 2.0 + RandomFloat2() * 0.3
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY
        def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
        def.slot = 491
        def.moveCall = MoveStaticObject
        def.rot = RandomFloat() * SwPI2

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF

        newObj.pointee.CType = UInt32(CTYPE_MISC | CTYPE_TRIGGER | CTYPE_WEAPONTEST)
        newObj.pointee.CBits = UInt32(CBITS_ALLSOLID)
        CreateCollisionBoxFromBoundingBox_Rotated(newObj, 0.5, 0.6)

        newObj.pointee.Damage = 0.5
        newObj.pointee.TriggerCallback = cDoTrigDesertBush

        return 1 // item was added
    }

    @discardableResult
    func addGeckoPlant(x: Float, z: Float) -> UInt8 {
        if pointee.parm.0 > 2 {
            SwFatal("addGeckoPlant: illegal subtype")
        }

        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(Int32(LEVEL3_ObjType_GeckoPlant_Small) + Int32(pointee.parm.0))
        def.scale = 2.0 + RandomFloat2() * 1.0
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY
        def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
        def.slot = 60
        def.moveCall = MoveStaticObject
        def.rot = RandomFloat() * SwPI2

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

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

    @discardableResult
    func addSproutPlant(x: Float, z: Float) -> UInt8 {
        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(LEVEL3_ObjType_SproutPlant)
        def.scale = 2.5 + RandomFloat2() * 0.3
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY
        def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
        def.slot = 40
        def.moveCall = MoveStaticObject
        def.rot = RandomFloat() * SwPI2

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF (disabled in the original C source)

        return 1 // item was added
    }

    @discardableResult
    func addIvy(x: Float, z: Float) -> UInt8 {
        let type = Int32(pointee.parm.0)
        let color = pointee.parm.1

        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8((color == 0) ? (Int32(LEVEL3_ObjType_PurpleIvy_Small) + type) : (Int32(LEVEL3_ObjType_RedIvy_Small) + type))
        def.scale = 2.0 + RandomFloat2() * 0.3
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY
        def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
        def.slot = 30
        def.moveCall = MoveStaticObject
        def.rot = RandomFloat() * SwPI2

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF (disabled in the original C source)

        return 1 // item was added
    }
}

// Returns TRUE if want to handle hit as a solid
private let cDoTrigGrass: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?) -> UInt8 = { _, playerOpt in
    let player = playerOpt!

    if GetPlayerInfoEntry(Int32(player.pointee.PlayerNum)).pointee.carriedObj == nil { // only disorient if not carrying egg
        DisorientPlayer(player)
    }

    return 0
}

// Returns TRUE if want to handle hit as a solid
private let cDoTrigDesertBush: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?) -> UInt8 = { treeOpt, playerOpt in
    let tree = treeOpt!
    let player = playerOpt!
    let p = player.pointee.PlayerNum

    if GetPlayerInfoEntry(Int32(p)).pointee.invincibilityTimer > 0.0 {
        return 0
    }

    if gGamePrefs.kiddieMode == 0 { // don't hurt in kiddie mode
        if MyRandomLong() & 1 != 0 {
            _ = PlayerLoseHealth(Int16(p), tree.pointee.Damage, UInt8(PlayerDeathType.deathDive.rawValue), nil, 1)
        } else {
            _ = PlayerLoseHealth(Int16(p), tree.pointee.Damage, UInt8(PlayerDeathType.explode.rawValue), nil, 1)
        }
    }

    GetPlayerInfoEntry(Int32(p)).pointee.invincibilityTimer = 0.5

    PlayEffect3D(Int16(EFFECT_BODYHIT), &player.pointee.Coord)
    PlayRumbleEffect(Int16(EFFECT_BODYHIT), Int32(p))

    return 0
}
