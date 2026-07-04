// Trees.swift - Port of Trees.c to Swift

private let treeBurnTime: Float = 15.0

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    // MARK: - Add birch tree

    @discardableResult
    func addBirchTree(x: Float, z: Float) -> UInt8 {
        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(Int32(LEVEL1_ObjType_Tree_Birch_HighRed) + Int32(pointee.parm.0))
        def.scale = 1.2 + RandomFloat() * 0.3
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY // GetTerrainY(x,z)
        def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
        def.slot = 501
        def.moveCall = MoveStaticObject
        def.rot = RandomFloat() * SwPI2

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF

        newObj.pointee.CType = UInt32(CTYPE_MISC | CTYPE_TRIGGER | CTYPE_WEAPONTEST)
        newObj.pointee.CBits = UInt32(CBITS_ALLSOLID)

        CreateCollisionBoxFromBoundingBox(newObj, 0.1, 1) // tree trunk collision box

        AddCollisionBoxToObject(newObj, newObj.pointee.TopOff * 0.9, newObj.pointee.TopOff * 0.45, // tree canopy collision box
                                 newObj.pointee.LeftOff * 3.3, newObj.pointee.RightOff * 3.3,
                                 newObj.pointee.FrontOff * 3.3, newObj.pointee.BackOff * 3.3)

        newObj.pointee.TriggerCallback = cDoTrigTree

        newObj.pointee.HitByWeaponHandler = cTreeHitByWeaponCallback

        return 1 // item was added
    }

    // MARK: - Add pine tree

    @discardableResult
    func addPineTree(x: Float, z: Float) -> UInt8 {
        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(Int32(LEVEL1_ObjType_Tree_Pine_HighDead) + Int32(pointee.parm.0))
        def.scale = 1.2 + RandomFloat() * 0.3
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY // GetTerrainY(x,z)
        def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
        def.slot = 588
        def.moveCall = MoveStaticObject
        def.rot = RandomFloat() * SwPI2

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF

        newObj.pointee.CType = UInt32(CTYPE_MISC | CTYPE_TRIGGER | CTYPE_WEAPONTEST)
        newObj.pointee.CBits = UInt32(CBITS_ALLSOLID)

        CreateCollisionBoxFromBoundingBox_Rotated(newObj, 0.12, 0.95) // tree trunk collision box

        AddCollisionBoxToObject(newObj, newObj.pointee.TopOff * 0.4, newObj.pointee.TopOff * 0.15, // tree canopy collision box
                                 newObj.pointee.LeftOff * 2.3, newObj.pointee.RightOff * 2.3,
                                 newObj.pointee.FrontOff * 2.3, newObj.pointee.BackOff * 2.3)

        newObj.pointee.TriggerCallback = cDoTrigTree

        newObj.pointee.HitByWeaponHandler = cTreeHitByWeaponCallback

        return 1 // item was added
    }

    // MARK: - Add fallen tree

    @discardableResult
    func addFallenTree(x: Float, z: Float) -> UInt8 {
        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(LEVEL1_ObjType_FallenTree)
        def.scale = 1.7
        def.coord.x = x
        def.coord.z = z
        def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
        def.slot = 511
        def.moveCall = MoveStaticObject
        def.rot = Float(pointee.parm.0) * (SwPI2 / 8)

        def.coord.y = GetMinTerrainY(x, z, Int16(def.group), Int16(def.type), 1.0)

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF

        newObj.pointee.CType = UInt32(CTYPE_MISC | CTYPE_TRIGGER)
        newObj.pointee.CBits = UInt32(CBITS_ALLSOLID)
        CreateCollisionBoxFromBoundingBox_Rotated(newObj, 0.3, 0.4)

        newObj.pointee.TriggerCallback = cDoTrigTree

        return 1 // item was added
    }

    // MARK: - Add tree stump

    @discardableResult
    func addTreeStump(x: Float, z: Float) -> UInt8 {
        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(LEVEL1_ObjType_TreeStump)
        def.scale = 1.3
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

        newObj.pointee.CType = UInt32(CTYPE_MISC | CTYPE_TRIGGER)
        newObj.pointee.CBits = UInt32(CBITS_ALLSOLID)
        CreateCollisionBoxFromBoundingBox_Rotated(newObj, 0.3, 1)

        newObj.pointee.TriggerCallback = cDoTrigTree

        return 1 // item was added
    }
}

// MARK: - Trigger callback: tree

// Returns TRUE if want to handle hit as a solid
private let cDoTrigTree: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?) -> UInt8 = { theNodeOpt, triggerOpt in
    if PlayerSmackedIntoObject(theNodeOpt, triggerOpt, Int16(PlayerDeathType.explode.rawValue)) != 0 {
        return 0
    }
    return 1
}

// MARK: - Trigger callback: canopy

// Canopies don't cause any damage, just disorentation
//
// Returns TRUE if want to handle hit as a solid
private let cDoTrigCanopy: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?) -> UInt8 = { _, playerOpt in
    guard let player = playerOpt else { return 0 }

    if gGamePrefs.kiddieMode == 0 { // don't hurt in kiddie mode
        let p = Int32(player.pointee.PlayerNum)
        let pi = GetPlayerInfoEntry(p)!

        if pi.pointee.carriedObj == nil { // only if not carrying egg
            if pi.pointee.invincibilityTimer > 0.0 {
                return 0
            }

            PlayerLoseHealth(Int16(p), 0.2, UInt8(PlayerDeathType.deathDive.rawValue), &player.pointee.Coord, 1)
            PlayEffect3D(Int16(EFFECT_BODYHIT), &player.pointee.Coord)
            PlayRumbleEffect(Int16(EFFECT_BODYHIT), p)
            pi.pointee.invincibilityTimer = 0.6
        }
    }
    return 0
}

// MARK: -

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    // MARK: - Add small tree

    // Small trees can be hit w/o killing the player.
    @discardableResult
    func addSmallTree(x: Float, z: Float) -> UInt8 {
        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(LEVEL1_ObjType_SmallTree)
        def.scale = 1.0 + RandomFloat() * 0.2
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY
        def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
        def.slot = 620
        def.moveCall = MoveStaticObject
        def.rot = RandomFloat() * SwPI2

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF

        newObj.pointee.CType = UInt32(CTYPE_MISC | CTYPE_TRIGGER | CTYPE_WEAPONTEST)
        newObj.pointee.CBits = UInt32(CBITS_ALLSOLID)
        CreateCollisionBoxFromBoundingBox_Rotated(newObj, 0.3, 1)

        newObj.pointee.TriggerCallback = cDoTrigSmallTree

        return 1 // item was added
    }
}

// MARK: - Trigger callback: small tree

// Returns TRUE if want to handle hit as a solid
private let cDoTrigSmallTree: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?) -> UInt8 = { treeOpt, playerOpt in
    guard let tree = treeOpt, let player = playerOpt else { return 0 }

    DisorientPlayer(player)
    PlayEffect3D(Int16(EFFECT_BODYHIT), &player.pointee.Coord)
    PlayRumbleEffect(Int16(EFFECT_BODYHIT), Int32(player.pointee.PlayerNum))

    ExplodeGeometry(tree, 200, .fromOrigin, 1, 1.0)
    DeleteObject(tree)

    return 0
}

// MARK: -

// MARK: - Tree hit by weapon callback

// Returns true if object should stop bullet.
private let cTreeHitByWeaponCallback: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<OGLPoint3D>?, UnsafeMutablePointer<OGLVector3D>?) -> UInt8 = { _, treeOpt, hitCoord, _ in
    guard let tree = treeOpt else { return 1 }

    switch tree.pointee.Kind {
    // WEAPONS THAT WILL LIGHT TREE ON FIRE
    case Int32(WeaponType.blaster.rawValue), Int32(WeaponType.clusterShot.rawValue), Int32(WeaponType.bomb.rawValue), Int32(WeaponType.heatSeeker.rawValue):
        if (tree.pointee.Flag.0 == 0) && (hitCoord != nil) { // note:  make sure hitCoord is not nil
            if MyRandomLong() & 0x1 != 0 { // randomly decide if this ignites the tree
                tree.pointee.MoveCall = cMoveTreeBurning
                tree.pointee.ParticleTimer = 0
                tree.pointee.Flag.0 = 1 // TreeIsBurnt
                tree.pointee.SpecialF.0 = hitCoord!.pointee.y // TreeBurnY
                tree.pointee.Timer = treeBurnTime // burn for n seconds
            }
        }

    // WEAPONS THAT FURR THE TREE
    case Int32(WeaponType.sonicScream.rawValue):
        makeLeafConfetti(tree.pointee.Coord.x, gCoord.y, tree.pointee.Coord.z, Int16(PARTICLE_SObjType_Confetti_Birch), 200)

    default:
        break
    }

    return 1
}

// MARK: - Move tree: burning

private let cMoveTreeBurning: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }
    let fps = gFramesPerSecondFrac

    if TrackTerrainItem(theNode) != 0 { // just check to see if it's gone
        DeleteObject(theNode)
        return
    }

    // SEE IF DONE BURNING

    theNode.pointee.Timer -= fps
    if theNode.pointee.Timer <= 0.0 {
        return
    }

    theNode.getInfo()

    // MOVE BURN LINE DOWN TO BOTTOM

    theNode.pointee.SpecialF.0 -= fps * 30.0 // TreeBurnY
    if theNode.pointee.SpecialF.0 < (gCoord.y + 100.0) {
        theNode.pointee.SpecialF.0 = gCoord.y + 100.0
    }

    // BURN TREE COLOR

    var c = theNode.pointee.ColorFilter.r
    c -= 0.1 * fps
    if c < 0.3 {
        c = 0.3
    }

    theNode.pointee.ColorFilter.r = c
    theNode.pointee.ColorFilter.g = c
    theNode.pointee.ColorFilter.b = c

    // APPLY BURN TO CHAINS

    var chain = theNode.pointee.ChainNode
    while let chainNode = chain {
        chainNode.pointee.ColorFilter = theNode.pointee.ColorFilter
        chain = chainNode.pointee.ChainNode
    }

    // UPDATE SPARKLE TRAIL

    theNode.pointee.ParticleTimer -= fps
    if theNode.pointee.ParticleTimer <= 0.0 {
        theNode.pointee.ParticleTimer += 0.04 // reset timer

        var particleGroup = theNode.pointee.ParticleGroup
        let magicNum = theNode.pointee.ParticleMagicNum

        if (particleGroup == -1) || (VerifyParticleGroupMagicNum(particleGroup, magicNum) == 0) {
            let newMagicNum = MyRandomLong()
            theNode.pointee.ParticleMagicNum = newMagicNum

            var groupDef = NewParticleGroupDefType()
            groupDef.magicNum = newMagicNum
            groupDef.type = UInt8(ParticleType.fallingSparks.rawValue)
            groupDef.flags = UInt32(PARTICLE_FLAGS_DONTCHECKGROUND)
            groupDef.gravity = -200
            groupDef.magnetism = 0
            groupDef.baseScale = 40.0
            groupDef.decayRate = 0
            groupDef.fadeRate = 0.6
            groupDef.particleTextureNum = UInt8(PARTICLE_SObjType_Fire)
            groupDef.srcBlend = GL_SRC_ALPHA
            groupDef.dstBlend = GL_ONE
            particleGroup = NewParticleGroup(&groupDef)
            theNode.pointee.ParticleGroup = particleGroup
        }

        if particleGroup != -1 {
            for _ in 0..<3 {
                var p = OGLPoint3D()
                p.x = gCoord.x + RandomFloat2() * 25.0
                p.y = theNode.pointee.SpecialF.0 + RandomFloat2() * 15.0 // TreeBurnY
                p.z = gCoord.z + RandomFloat2() * 25.0

                var d = OGLVector3D()
                d.x = 0
                d.y = 400 + RandomFloat2() * 30.0
                d.z = 0

                var newParticleDef = NewParticleDefType()
                newParticleDef.groupNum = particleGroup
                newParticleDef.scale = RandomFloat() + 1.0
                newParticleDef.rotZ = RandomFloat() * SwPI2
                newParticleDef.rotDZ = RandomFloat2()
                newParticleDef.alpha = 1.0

                let stop: Bool = withUnsafeMutablePointer(to: &p) { pPtr in
                    withUnsafeMutablePointer(to: &d) { dPtr in
                        newParticleDef.where = pPtr
                        newParticleDef.delta = dPtr
                        return AddParticleToGroup(&newParticleDef) != 0
                    }
                }
                if stop {
                    theNode.pointee.ParticleGroup = -1
                    break
                }
            }
        }
    }
}

// MARK: - Make leaf confetti

private func makeLeafConfetti(_ x: Float, _ y: Float, _ z: Float, _ texture: Int16, _ quantity: Int) {
    gNewConfettiGroupDef.magicNum = 0
    gNewConfettiGroupDef.flags = UInt32(PARTICLE_FLAGS_BOUNCE)
    gNewConfettiGroupDef.gravity = 250
    gNewConfettiGroupDef.baseScale = 20.0
    gNewConfettiGroupDef.decayRate = 0
    gNewConfettiGroupDef.fadeRate = 1.0
    gNewConfettiGroupDef.confettiTextureNum = UInt8(texture)

    let pg = NewConfettiGroup(&gNewConfettiGroupDef)
    if pg != -1 {
        for _ in 0..<quantity {
            var pt = OGLPoint3D()
            pt.x = x + RandomFloat2() * 60.0
            pt.y = y + RandomFloat2() * 300.0
            pt.z = z + RandomFloat2() * 60.0

            var v = OGLVector3D()
            v.x = pt.x - x
            v.y = pt.y - y
            v.z = pt.z - z
            FastNormalizeVector(v.x, v.y, v.z, &v)

            var delta = OGLVector3D()
            delta.x = v.x * 200.0
            delta.y = v.y * 200.0
            delta.z = v.z * 200.0

            var newConfettiDef = NewConfettiDefType()
            newConfettiDef.groupNum = pg
            newConfettiDef.scale = 1.0 + RandomFloat() * 0.5
            newConfettiDef.rot.x = RandomFloat() * SwPI2
            newConfettiDef.rot.y = RandomFloat() * SwPI2
            newConfettiDef.rot.z = RandomFloat() * SwPI2
            newConfettiDef.deltaRot.x = RandomFloat2() * 5.0
            newConfettiDef.deltaRot.y = RandomFloat2() * 5.0
            newConfettiDef.deltaRot.z = RandomFloat2() * 5.0
            newConfettiDef.alpha = Float(FULL_ALPHA)
            newConfettiDef.fadeDelay = 0.5 + RandomFloat()

            let stop: Bool = withUnsafeMutablePointer(to: &pt) { ptPtr in
                withUnsafeMutablePointer(to: &delta) { deltaPtr in
                    newConfettiDef.where = ptPtr
                    newConfettiDef.delta = deltaPtr
                    return AddConfettiToGroup(&newConfettiDef) != 0
                }
            }
            if stop {
                break
            }
        }
    }
}

// MARK: -

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    // MARK: - Add bent pine tree

    @discardableResult
    func addBentPineTree(x: Float, z: Float) -> UInt8 {
        let rot = Float(pointee.parm.1) * (SwPI2 / 8.0)

        // MAKE TRUNK

        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(Int32(LEVEL1_ObjType_BentPine1_Trunk) + Int32(pointee.parm.0))
        def.scale = 1.2 + RandomFloat2() * 0.2
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY
        def.flags = gAutoFadeStatusBits
        def.slot = 444
        def.moveCall = MoveStaticObject
        def.rot = rot

        let trunk = MakeNewDisplayGroupObject(&def)!

        trunk.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF

        trunk.pointee.CType = UInt32(CTYPE_SOLIDTOENEMY | CTYPE_PLAYERTEST | CTYPE_WEAPONTEST)
        trunk.pointee.CBits = UInt32(CBITS_ALLSOLID)
        CreateCollisionBoxFromBoundingBox_Rotated(trunk, 1, 1)

        // MAKE LEAVES

        def.type = UInt8(Int32(LEVEL1_ObjType_BentPine1_Leaves) + Int32(pointee.parm.0))
        def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
        def.slot = Int16(SLOT_OF_DUMB)
        def.moveCall = nil
        let leaves = MakeNewDisplayGroupObject(&def)!

        trunk.pointee.ChainNode = leaves

        return 1 // item was added
    }

    // MARK: - Add desert tree

    @discardableResult
    func addDesertTree(x: Float, z: Float) -> UInt8 {
        let type = Int(pointee.parm.0)
        let rot = Int(pointee.parm.1)

        if pointee.parm.0 > 4 {
            SwFatal("addDesertTree: illegal subtype")
        }

        // MAKE SOLID TRUNK

        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(Int32(LEVEL2_ObjType_Tree1) + Int32(type))
        def.scale = 1.2 + RandomFloat() * 0.3
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY
        def.rot = (rot == 0) ? (RandomFloat() * SwPI2) : (Float(rot - 1) * (SwPI2 / 8.0))
        def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
        def.slot = 501
        def.moveCall = MoveStaticObject

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF

        newObj.pointee.CType = UInt32(CTYPE_MISC | CTYPE_WEAPONTEST | CTYPE_PLAYERTEST)
        newObj.pointee.CBits = UInt32(CBITS_ALLSOLID)

        CreateCollisionBoxFromBoundingBox(newObj, 0.3, 1) // tree trunk collision box

        if type != 0 { // tree #0 is too bent to burn!
            newObj.pointee.HitByWeaponHandler = cTreeHitByWeaponCallback
        }

        // MAKE NON-SOLID CANOPY

        def.type = UInt8(Int32(LEVEL2_ObjType_Tree1_Canopy) + Int32(type))
        def.slot += 1
        def.moveCall = nil
        let canopy = MakeNewDisplayGroupObject(&def)!

        // SET COLLISION STUFF

        canopy.pointee.CType = UInt32(CTYPE_WEAPONTEST | CTYPE_PLAYERTEST)
        canopy.pointee.CBits = 0
        canopy.pointee.TriggerCallback = cDoTrigCanopy

        newObj.pointee.ChainNode = canopy

        return 1 // item was added
    }

    // MARK: - Add palm tree

    @discardableResult
    func addPalmTree(x: Float, z: Float) -> UInt8 {
        let type = Int(pointee.parm.0)
        let rot = Int(pointee.parm.1)

        // MAKE SOLID TRUNK

        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(Int32(LEVEL2_ObjType_PalmTree1) + Int32(type))
        def.scale = 1.2 + RandomFloat() * 0.3
        def.rot = (rot == 0) ? (RandomFloat() * SwPI2) : (Float(rot - 1) * (SwPI2 / 8.0))
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY
        def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
        def.slot = 501
        def.moveCall = MoveStaticObject

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF

        newObj.pointee.CType = UInt32(CTYPE_SOLIDTOENEMY | CTYPE_WEAPONTEST | CTYPE_PLAYERTEST)
        newObj.pointee.CBits = UInt32(CBITS_ALLSOLID)

        CreateCollisionBoxFromBoundingBox(newObj, 0.3, 1) // tree trunk collision box

        if type != 2 { // don't allow the bent trees to burn
            newObj.pointee.HitByWeaponHandler = cTreeHitByWeaponCallback
        }

        // MAKE NON-SOLID CANOPY

        def.type = UInt8(Int32(LEVEL2_ObjType_PalmTree1_Canopy) + Int32(type))
        def.slot += 1
        def.moveCall = nil
        let canopy = MakeNewDisplayGroupObject(&def)!

        // SET COLLISION STUFF

        canopy.pointee.CType = UInt32(CTYPE_WEAPONTEST | CTYPE_PLAYERTEST)
        canopy.pointee.CBits = 0
        canopy.pointee.TriggerCallback = cDoTrigCanopy

        newObj.pointee.ChainNode = canopy

        return 1 // item was added
    }

    // MARK: - Add burnt desert tree

    @discardableResult
    func addBurntDesertTree(x: Float, z: Float) -> UInt8 {
        let type = Int(pointee.parm.0)

        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(Int32(LEVEL2_ObjType_BurntTree1) + Int32(type))
        def.scale = 1.2 + RandomFloat() * 0.3
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY
        def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
        def.slot = 501
        def.moveCall = MoveStaticObject
        def.rot = RandomFloat() * SwPI2

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF

        newObj.pointee.CType = UInt32(CTYPE_MISC | CTYPE_WEAPONTEST | CTYPE_TRIGGER)
        newObj.pointee.CBits = UInt32(CBITS_ALLSOLID)

        CreateCollisionBoxFromBoundingBox(newObj, 0.3, 0.95) // tree trunk collision box

        newObj.pointee.TriggerCallback = cDoTrigTree

        return 1 // item was added
    }
}

// MARK: -

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    // MARK: - Add hydra tree

    @discardableResult
    func addHydraTree(x: Float, z: Float) -> UInt8 {
        let type = Int(pointee.parm.0)

        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(Int32(LEVEL3_ObjType_HydraTree_Small) + Int32(type))
        def.scale = 1.5 + RandomFloat() * 0.5
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY
        def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
        def.slot = 501
        def.moveCall = MoveStaticObject
        def.rot = RandomFloat() * SwPI2

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF

        newObj.pointee.CType = UInt32(CTYPE_MISC | CTYPE_WEAPONTEST | CTYPE_TRIGGER)
        newObj.pointee.CBits = UInt32(CBITS_ALLSOLID)

        newObj.pointee.TriggerCallback = cDoTrigTree

        CreateCollisionBoxFromBoundingBox(newObj, 0.1, 0.7) // tree trunk collision box

        return 1 // item was added
    }

    // MARK: - Add odd tree

    @discardableResult
    func addOddTree(x: Float, z: Float) -> UInt8 {
        let type = Int(pointee.parm.0)

        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(Int32(LEVEL3_ObjType_OddTree_Small) + Int32(type))
        def.scale = 1.3 + RandomFloat() * 0.3
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY
        def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6)
        def.slot = 501
        def.moveCall = MoveStaticObject
        def.rot = RandomFloat() * SwPI2

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF

        newObj.pointee.CType = UInt32(CTYPE_MISC | CTYPE_WEAPONTEST | CTYPE_TRIGGER)
        newObj.pointee.CBits = UInt32(CBITS_ALLSOLID)

        newObj.pointee.Damage = 0.9
        newObj.pointee.TriggerCallback = cDoTrigFallenSwampTree

        CreateCollisionBoxFromBoundingBox(newObj, 0.25, 0.9) // tree trunk collision box

        return 1 // item was added
    }

    // MARK: - Add swamp fallen tree

    @discardableResult
    func addSwampFallenTree(x: Float, z: Float) -> UInt8 {
        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(Int32(LEVEL3_ObjType_FallenTree1) + Int32(pointee.parm.0))
        def.scale = 1.2 + RandomFloat2() * 0.2
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY
        def.flags = gAutoFadeStatusBits
        def.slot = 444
        def.moveCall = MoveStaticObject

        if pointee.parm.1 > 0 {
            def.rot = Float(Int(pointee.parm.1) - 1) * (SwPI2 / 8.0)
        } else {
            def.rot = RandomFloat() * SwPI2
        }

        let trunk = MakeNewDisplayGroupObject(&def)!

        trunk.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF

        trunk.pointee.Damage = 0.25

        trunk.pointee.CType = UInt32(CTYPE_SOLIDTOENEMY | CTYPE_PLAYERTEST | CTYPE_WEAPONTEST)
        trunk.pointee.CBits = UInt32(CBITS_ALLSOLID)
        CreateCollisionBoxFromBoundingBox_Rotated(trunk, 1, 1)

        trunk.pointee.TriggerCallback = cDoTrigFallenSwampTree

        return 1 // item was added
    }
}

// MARK: - Trigger callback: fallen swamp tree

// Returns TRUE if want to handle hit as a solid
private let cDoTrigFallenSwampTree: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?) -> UInt8 = { treeOpt, playerOpt in
    guard let tree = treeOpt, let player = playerOpt else { return 0 }
    let p = Int32(player.pointee.PlayerNum)
    let pi = GetPlayerInfoEntry(p)!

    if pi.pointee.invincibilityTimer > 0.0 {
        return 0
    }

    if gGamePrefs.kiddieMode == 0 { // don't hurt in kiddie mode
        if MyRandomLong() & 1 != 0 {
            PlayerLoseHealth(Int16(p), tree.pointee.Damage, UInt8(PlayerDeathType.deathDive.rawValue), nil, 1)
        } else {
            PlayerLoseHealth(Int16(p), tree.pointee.Damage, UInt8(PlayerDeathType.explode.rawValue), nil, 1)
        }
    }

    pi.pointee.invincibilityTimer = 0.5

    PlayEffect3D(Int16(EFFECT_BODYHIT), &player.pointee.Coord)
    PlayRumbleEffect(Int16(EFFECT_BODYHIT), p)

    return 0
}

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    // MARK: - Add swamp tree stump

    @discardableResult
    func addSwampStump(x: Float, z: Float) -> UInt8 {
        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(Int32(LEVEL3_ObjType_Stump1) + Int32(pointee.parm.0))
        def.scale = 1.3
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY
        def.flags = gAutoFadeStatusBits
        def.slot = 380
        def.moveCall = MoveStaticObject
        def.rot = RandomFloat() * SwPI2

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF

        newObj.pointee.CType = UInt32(CTYPE_MISC | CTYPE_PLAYERTEST | CTYPE_WEAPONTEST)
        newObj.pointee.CBits = UInt32(CBITS_ALLSOLID)
        CreateCollisionBoxFromBoundingBox_Rotated(newObj, 0.8, 0.9)

        newObj.pointee.TriggerCallback = cDoTrigTree

        return 1 // item was added
    }
}
