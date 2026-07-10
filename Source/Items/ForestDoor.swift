// ForestDoor.swift - Port of ForestDoor.c to Swift

private let damDoorScale: Float = 1.85
private let maxDamDoors = 64


@inline(__always) private func sparklesBase(_ n: UnsafeMutablePointer<ObjNode>) -> UnsafeMutablePointer<Int16> {
    UnsafeMutableRawPointer(n.pointer(to: \.Sparkles)!).assumingMemoryBound(to: Int16.self)
}

func InitForestDoors() {
    for i in 0..<maxDamDoors {
        gEngine.items.forestDoorOpen[i] = false
    }
}

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    @discardableResult
    func addForestDoor(x: Float, z: Float) -> UInt8 {
        let keyID = Int32(pointee.parm.0)
        let rot = Float(pointee.parm.1) * (Float.pi / 2)
        let type: Int32

        switch gEngine.game.levelNum {
        case Int16(LevelNum.adventure1.rawValue):
            type = Int32(LEVEL1_ObjType_ForestDoor_Wall)
        case Int16(LevelNum.adventure2.rawValue):
            type = Int32(LEVEL2_ObjType_ForestDoor_Wall)
        case Int16(LevelNum.adventure3.rawValue), Int16(LevelNum.race1.rawValue), Int16(LevelNum.flag1.rawValue):
            type = Int32(LEVEL3_ObjType_ForestDoor_Wall)
        default:
            SwFatal("AddForestDoor: no door here yet, call Brian!")
            return 0
        }

        // MAKE DAM WALL

        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(type)
        def.scale = damDoorScale
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY
        def.flags = 0
        def.slot = 176
        def.moveCall = cMoveForestDoor
        def.rot = rot

        let wall = MakeNewDisplayGroupObject(&def)!

        wall.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF

        wall.pointee.CType = UInt32(CTYPE_SOLIDTOENEMY | CTYPE_WEAPONTEST | CTYPE_PLAYERTEST)
        wall.pointee.CBits = UInt32(CBITS_ALLSOLID)
        CreateCollisionBoxFromBoundingBox_Rotated(wall, 1, 1)

        wall.pointee.TriggerCallback = DoTrig_MiscSmackableObject

        wall.pointee.Kind = keyID

        // MAKE DOOR

        def.group = UInt8(MODEL_GROUP_GLOBAL)
        def.type = UInt8(GLOBAL_ObjType_ForestDoor_Door)
        def.flags |= UInt32(STATUS_BIT_ROTZXY)
        def.coord.y = wall.pointee.Coord.y + damDoorScale * 70.0
        def.slot += 1
        def.moveCall = nil
        let door = MakeNewDisplayGroupObject(&def)!

        // SET COLLISION STUFF

        door.pointee.CType = UInt32(CTYPE_WEAPONTEST | CTYPE_PLAYERTEST)

        if gEngine.items.forestDoorOpen[Int(keyID)] { // see if door is open
            door.pointee.Rot.z = -Float.pi
            UpdateObjectTransforms(door)
        }

        wall.pointee.ChainNode = door
        door.pointee.ChainHead = wall

        // MAKE RING

        def.type = UInt8(GLOBAL_ObjType_ForestDoor_Ring)
        def.flags |= UInt32(STATUS_BIT_GLOW | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOFOG | STATUS_BIT_UVTRANSFORM)
        def.slot = Int16(SLOT_OF_DUMB - 1)
        let ring = MakeNewDisplayGroupObject(&def)!

        // SET COLLISION STUFF

        ring.pointee.CType = UInt32(CTYPE_WEAPONTEST | CTYPE_PLAYERTEST)

        door.pointee.ChainNode = ring
        ring.pointee.ChainHead = door

        return 1 // item was added
    }
}

private let cMoveForestDoor: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { wallOpt in
    guard let wall = wallOpt else { return }
    let fps = gEngine.framesPerSecondFrac
    let door = wall.pointee.ChainNode!
    let ring = door.pointee.ChainNode!

    // SEE IF GONE

    if TrackTerrainItem(wall) != 0 {
        DeleteObject(wall)
        return
    }

    // SEE IF OPEN DOOR

    if gEngine.items.forestDoorOpen[Int(wall.pointee.Kind)] {
        door.pointee.Rot.z -= fps

        if gEngine.game.levelNum != Int16(LevelNum.adventure3.rawValue) { // on level 3 we'll keep the door spinning
            if door.pointee.Rot.z < -Float.pi {
                door.pointee.Rot.z = -Float.pi
            }
        }

        UpdateObjectTransforms(door)
    }

    // UPDATE RING

    ring.pointee.BaseTransformMatrix = door.pointee.BaseTransformMatrix
    SetObjectTransformMatrix(ring)
    ring.pointee.ColorFilter.a = 0.7 + RandomFloat() * 0.3
    ring.pointee.TextureTransformU -= fps * 3.0
}

// MARK: - Forest Door Key

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    @discardableResult
    func addForestDoorKey(x: Float, z: Float) -> UInt8 {
        let keyID = Int32(pointee.parm.0)
        let rot = Float(pointee.parm.1) * (Float.pi * 2 / 8)
        let keyDestroyed = pointee.flags & UInt16(ITEM_FLAGS_USER1) != 0

        // MAKE KEY HOLDER

        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_GLOBAL)
        def.type = UInt8(GLOBAL_ObjType_ForestDoor_KeyHolder)
        def.scale = damDoorScale
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY
        def.flags = gEngine.game.autoFadeStatusBits
        def.slot = 209
        def.moveCall = cMoveForestDoorKey
        def.rot = rot

        let keyHolder = MakeNewDisplayGroupObject(&def)!

        keyHolder.pointee.TerrainItemPtr = self // keep ptr to item list

        keyHolder.pointee.Kind = keyID

        // SET COLLISION STUFF

        keyHolder.pointee.CType = UInt32(CTYPE_MISC | CTYPE_WEAPONTEST | CTYPE_PLAYERTEST)
        keyHolder.pointee.CBits = UInt32(CBITS_ALLSOLID)
        CreateCollisionBoxFromBoundingBox(keyHolder, 1, 1)

        keyHolder.pointee.TriggerCallback = doTrigForestDoorKey
        keyHolder.pointee.HitByWeaponHandler = cForestDoorKeyHitByWeaponCallback

        keyHolder.pointee.HeatSeekHotSpotOff.y = 220.0

        keyHolder.pointee.Health = 0.3

        // MAKE KEY

        if !keyDestroyed { // was the key already destroyed?
            keyHolder.pointee.CType |= UInt32(CTYPE_AUTOTARGETWEAPON) // make keyholder auto-target

            def.type = UInt8(GLOBAL_ObjType_ForestDoor_Key)
            def.slot += 1
            def.moveCall = nil
            let key = MakeNewDisplayGroupObject(&def)!

            // SET COLLISION STUFF

            key.pointee.CType = UInt32(CTYPE_WEAPONTEST | CTYPE_AUTOTARGETWEAPON)

            key.pointee.HitByWeaponHandler = cForestDoorKeyHitByWeaponCallback

            key.pointee.HeatSeekHotSpotOff.y = 220.0

            keyHolder.pointee.ChainNode = key
            key.pointee.ChainHead = keyHolder

            // MAKE SPARKLES

            var sparkleRot: Float = 0
            for j in 0..<3 {
                let i = GetFreeSparkle(key)
                sparklesBase(key)[j] = i
                if i != -1 {
                    let sparkle = GetSparkleSlot(Int32(i))!
                    sparkle.pointee.flags = UInt32(SPARKLE_FLAG_OMNIDIRECTIONAL | SPARKLE_FLAG_FLICKER | SPARKLE_FLAG_TRANSFORMWITHOWNER)
                    sparkle.pointee.where.x = sin(sparkleRot) * 20.0
                    sparkle.pointee.where.y = 190.0
                    sparkle.pointee.where.z = cos(sparkleRot) * 20.0

                    sparkle.pointee.color.r = 1
                    sparkle.pointee.color.g = 1
                    sparkle.pointee.color.b = 1
                    sparkle.pointee.color.a = 1

                    sparkle.pointee.scale = 60.0
                    sparkle.pointee.separation = 50

                    sparkle.pointee.textureNum = Int16(PARTICLE_SObjType_RedGlint)

                    sparkleRot += Float.pi * 2 * 0.333
                }
            }
        }

        return 1 // item was added
    }
}

private let cMoveForestDoorKey: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { keyHolderOpt in
    guard let keyHolder = keyHolderOpt else { return }
    let key = keyHolder.pointee.ChainNode

    if TrackTerrainItem(keyHolder) != 0 { // just check to see if it's gone
        DeleteObject(keyHolder)
        return
    }

    // SPIN THE KEY

    if let key {
        key.pointee.Rot.y += gEngine.framesPerSecondFrac * 2.0
        UpdateObjectTransforms(key)
    }
}

// Returns TRUE if want to handle hit as a solid
private let doTrigForestDoorKey: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?) -> UInt8 = { theNodeOpt, playerOpt in
    let theNode = theNodeOpt!
    let player = playerOpt!

    destroyForestDoorKey(theNode)

    _ = PlayerSmackedIntoObject(player, theNode, .explode)

    return 1
}

// Returns true if object should stop bullet.
private let cForestDoorKeyHitByWeaponCallback: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<OGLPoint3D>?, UnsafeMutablePointer<OGLVector3D>?) -> UInt8 = { bullet, theNodeOpt, _, _ in
    var theNode = theNodeOpt!

    if let chainHead = theNode.pointee.ChainHead { // make sure we're pointing to the key holder, not the key
        theNode = chainHead
    }

    theNode.pointee.Health -= bullet!.pointee.Damage
    if theNode.pointee.Health <= 0.0 {
        destroyForestDoorKey(theNode)
    }

    return 1
}

private func destroyForestDoorKey(_ keyHolder: UnsafeMutablePointer<ObjNode>) {
    guard let key = keyHolder.pointee.ChainNode else { // make sure there's a key in there
        return
    }

    gEngine.items.forestDoorOpen[Int(keyHolder.pointee.Kind)] = true

    PlayEffect3D(Int16(EFFECT_TURRETEXPLOSION), &keyHolder.pointee.Coord)

    // MAKE SURE KEY DOESNT COME BACK

    keyHolder.pointee.TerrainItemPtr!.pointee.flags |= UInt16(ITEM_FLAGS_USER1)
    keyHolder.pointee.CType &= ~UInt32(CTYPE_AUTOTARGETWEAPON) // don't auto-target anymore

    // MAKE SPARK EXPLOSION

    let x = key.pointee.Coord.x
    let z = key.pointee.Coord.z
    let y = key.pointee.Coord.y + (250.0 * damDoorScale)

    gEngine.particles.newGroupDef.magicNum = 0
    gEngine.particles.newGroupDef.particleType = .fallingSparks
    gEngine.particles.newGroupDef.flags = UInt32(PARTICLE_FLAGS_BOUNCE)
    gEngine.particles.newGroupDef.gravity = 300
    gEngine.particles.newGroupDef.magnetism = 0
    gEngine.particles.newGroupDef.baseScale = 20.0
    gEngine.particles.newGroupDef.decayRate = 0
    gEngine.particles.newGroupDef.fadeRate = 0.5
    gEngine.particles.newGroupDef.particleTextureNum = UInt8(PARTICLE_SObjType_RedSpark)
    gEngine.particles.newGroupDef.srcBlend = Int32(GL_SRC_ALPHA)
    gEngine.particles.newGroupDef.dstBlend = Int32(GL_ONE)

    let pg = NewParticleGroup(&gEngine.particles.newGroupDef)
    if pg != -1 {
        for _ in 0..<200 {
            var pt = OGLPoint3D()
            pt.x = x + RandomFloat2() * 50.0
            pt.y = y + RandomFloat2() * 30.0
            pt.z = z + RandomFloat2() * 50.0

            var v = OGLVector3D()
            v.x = pt.x - x
            v.y = pt.y - y
            v.z = pt.z - z
            FastNormalizeVector(v.x, v.y, v.z, &v)

            let f: Float = 200.0 + RandomFloat() * 300.0

            var delta = OGLVector3D()
            delta.x = v.x * f
            delta.y = v.y * f
            delta.z = v.z * f

            let added: UInt8 = withUnsafeMutablePointer(to: &pt) { ptPtr in
                withUnsafeMutablePointer(to: &delta) { deltaPtr in
                    var newParticleDef = NewParticleDefType()
                    newParticleDef.groupNum = pg
                    newParticleDef.`where` = ptPtr
                    newParticleDef.delta = deltaPtr
                    newParticleDef.scale = 1.0 + RandomFloat() * 0.5
                    newParticleDef.rotZ = 0
                    newParticleDef.rotDZ = 0
                    newParticleDef.alpha = 0.8 + RandomFloat() * 0.2
                    return AddParticleToGroup(&newParticleDef)
                }
            }
            if added != 0 {
                break
            }
        }
    }

    DeleteObject(key)

    keyHolder.pointee.ChainNode = nil
}
