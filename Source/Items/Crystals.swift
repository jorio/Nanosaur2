// Crystals.swift - Port of Crystals.c to Swift

private let NORMAL_CHANNEL_RATE: UInt32 = 0x10000

private let cCrystalHitByWeaponCallback: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<OGLPoint3D>?, UnsafeMutablePointer<OGLVector3D>?) -> UInt8 = { _, crystal, _, _ in
    // Returns true if object should stop bullet.
    guard let crystal else { return 1 }
    let base = crystal.pointee.ChainHead!

    PlayEffect_Parms3D(Int16(EFFECT_CRYSTALSHATTER), &crystal.pointee.Coord, NORMAL_CHANNEL_RATE + (MyRandomLong() & 0x3fff), 2.0)

    // MAKE SPARKS

    gEngine.particles.newGroupDef.magicNum = 0
    gEngine.particles.newGroupDef.particleType = .fallingSparks
    gEngine.particles.newGroupDef.flags = UInt32(PARTICLE_FLAGS_DONTCHECKGROUND)
    gEngine.particles.newGroupDef.gravity = 500
    gEngine.particles.newGroupDef.magnetism = 0
    gEngine.particles.newGroupDef.baseScale = 15
    gEngine.particles.newGroupDef.decayRate = 0.5
    gEngine.particles.newGroupDef.fadeRate = 1.0
    gEngine.particles.newGroupDef.particleTextureNum = UInt8(PARTICLE_SObjType_BlueSpark)
    gEngine.particles.newGroupDef.srcBlend = Int32(GL_SRC_ALPHA)
    gEngine.particles.newGroupDef.dstBlend = Int32(GL_ONE)
    let pg = NewParticleGroup(&gEngine.particles.newGroupDef)
    if pg != -1 {
        let x = base.pointee.Coord.x
        let y = base.pointee.Coord.y
        let z = base.pointee.Coord.z

        for _ in 0..<220 {
            var d = OGLVector3D(x: 0, y: 0, z: 0)
            d.x = RandomFloat2() * 800.0
            d.y = RandomFloat2() * 500.0
            d.z = RandomFloat2() * 800.0

            var pt = OGLPoint3D(x: 0, y: 0, z: 0)
            pt.x = x + d.x * 0.05
            pt.y = y + RandomFloat() * 150.0
            pt.z = z + d.z * 0.05

            withUnsafeMutablePointer(to: &pt) { ptPtr in
                withUnsafeMutablePointer(to: &d) { dPtr in
                    var newParticleDef = NewParticleDefType()
                    newParticleDef.groupNum = pg
                    newParticleDef.`where` = ptPtr
                    newParticleDef.delta = dPtr
                    newParticleDef.scale = RandomFloat() + 1.0
                    newParticleDef.rotZ = 0
                    newParticleDef.rotDZ = 0
                    newParticleDef.alpha = 1.0 + (RandomFloat() * 0.3)
                    _ = AddParticleToGroup(&newParticleDef)
                }
            }
        }
    }

    // FRAGMENT

    ExplodeGeometry(crystal, 600, .fromOrigin, 1, 1.0)

    // SHOCKWAVE

    var def = NewObjectDefinitionType()
    def.group = UInt8(MODEL_GROUP_WEAPONS)
    def.type = UInt8(WEAPONS_ObjType_BombShockwave)
    def.coord = base.pointee.Coord
    def.flags = UInt32(STATUS_BIT_NOZWRITES | STATUS_BIT_NOFOG | STATUS_BIT_NOLIGHTING)
    def.slot = Int16(SLOT_OF_DUMB + 40)
    def.moveCall = cMoveCrystalShockwave
    def.rot = 0
    def.scale = 1.0

    let newObj = MakeNewDisplayGroupObject(&def)!

    newObj.pointee.ColorFilter.a = 0.8
    newObj.pointee.Damage = 0.8

    // DELETE

    base.pointee.ChainNode = nil // separate crystal from base

    base.pointee.TerrainItemPtr!.pointee.flags |= UInt16(ITEM_FLAGS_USER1) // set flag so next time the crystal won't be created

    DeleteObject(crystal)

    return 1
}

private let cMoveCrystalShockwave: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNode in
    guard let theNode else { return }
    let fps = gFramesPerSecondFrac

    // FADE

    theNode.pointee.ColorFilter.a -= fps * 1.4
    if theNode.pointee.ColorFilter.a <= 0.0 {
        DeleteObject(theNode)
        return
    }

    theNode.pointee.Scale.z += fps * 220.0
    theNode.pointee.Scale.y = theNode.pointee.Scale.z
    theNode.pointee.Scale.x = theNode.pointee.Scale.z

    UpdateObjectTransforms(theNode)

    CauseBombShockwaveDamage(theNode, UInt32(CTYPE_PLAYER1 | CTYPE_PLAYER2 | CTYPE_ENEMY | CTYPE_WEAPONTEST))
}

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    @discardableResult
    func addCrystal(x: Float, z: Float) -> UInt8 {
        if pointee.parm.0 > 2 {
            SwFatal("AddCrystal: illegal subtype")
        }

        // MAKE BASE

        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(LEVEL2_ObjType_Crystal1Base) + pointee.parm.0
        def.scale = 1.5 + RandomFloat2() * 0.5
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY
        def.flags = gAutoFadeStatusBits
        def.slot = Int16(SLOT_OF_DUMB - 50)
        def.moveCall = MoveStaticObject
        def.rot = RandomFloat() * SwPI2

        let base = MakeNewDisplayGroupObject(&def)!

        base.pointee.TerrainItemPtr = self // keep ptr to item list

        RotateOnTerrain(base, -2, nil) // keep flat on terrain
        SetObjectTransformMatrix(base)

        if (pointee.flags & UInt16(ITEM_FLAGS_USER1)) == 0 { // did we blow up the crystal previously?
            // MAKE CRYSTAL

            def.type = UInt8(LEVEL2_ObjType_Crystal1) + pointee.parm.0
            def.slot = Int16(SLOT_OF_DUMB - 3)
            def.moveCall = nil
            let crystal = MakeNewDisplayGroupObject(&def)!

            // SET COLLISION STUFF

            crystal.pointee.CType = UInt32(CTYPE_SOLIDTOENEMY | CTYPE_PLAYERTEST | CTYPE_WEAPONTEST | CTYPE_MISC)
            crystal.pointee.CBits = UInt32(CBITS_ALLSOLID)
            CalcObjectBoxFromNode(crystal)

            crystal.pointee.HitByWeaponHandler = cCrystalHitByWeaponCallback

            crystal.pointee.HeatSeekHotSpotOff.x = 0
            crystal.pointee.HeatSeekHotSpotOff.y = 50.0
            crystal.pointee.HeatSeekHotSpotOff.z = 0

            crystal.pointee.BaseTransformMatrix = base.pointee.BaseTransformMatrix
            SetObjectTransformMatrix(crystal)

            base.pointee.ChainNode = crystal
            crystal.pointee.ChainHead = base
        }

        return 1 // item was added
    }
}
