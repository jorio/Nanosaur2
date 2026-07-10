// Mines.swift - Port of Mines.c to Swift

private let airMineScale: Float = 1.2

// MARK: - Add air mine

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    @discardableResult
    func addAirMine(x: Float, z: Float) -> UInt8 {
        let typeB: Int32
        let typeM: Int32
        let typeC: Int32
        var chainOff: Float = 0

        var h = Int(pointee.parm.0)
        if h != 0 {
            h = 10 - h
            if h < 0 {
                h = 0
            }
        }

        switch gLevelNum {
        case Int16(LevelNum.adventure1.rawValue), Int16(LevelNum.flag2.rawValue), Int16(LevelNum.battle1.rawValue):
            typeB = Int32(LEVEL1_ObjType_AirMine_Base)
            typeM = Int32(LEVEL1_ObjType_AirMine_Mine)
            typeC = Int32(LEVEL1_ObjType_AirMine_Chain)
            if h == 0 {
                chainOff = RandomFloat() * (600.0 * airMineScale)
            } else {
                chainOff = Float(h) * (800.0 / 10.0)
            }

        case Int16(LevelNum.adventure2.rawValue):
            typeB = Int32(LEVEL2_ObjType_AirMine_Base)
            typeM = Int32(LEVEL2_ObjType_AirMine_Mine)
            typeC = Int32(LEVEL2_ObjType_AirMine_Chain)
            if h == 0 {
                chainOff = RandomFloat() * (1400.0 * airMineScale)
            } else {
                chainOff = Float(h) * (2300.0 / 10.0)
            }

        case Int16(LevelNum.adventure3.rawValue), Int16(LevelNum.race1.rawValue), Int16(LevelNum.flag1.rawValue):
            typeB = Int32(LEVEL3_ObjType_AirMine_Base)
            typeM = Int32(LEVEL3_ObjType_AirMine_Mine)
            typeC = Int32(LEVEL3_ObjType_AirMine_Chain)
            if h == 0 {
                chainOff = RandomFloat() * (1400.0 * airMineScale)
            } else {
                chainOff = Float(h) * (2300.0 / 10.0)
            }

        default:
            SwFatal("AddAirMine: no mines here yet, call Brian!")
            return 0
        }

        // MAKE BASE

        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(typeB)
        def.scale = airMineScale
        def.coord.x = x
        def.coord.z = z
        def.flags = gAutoFadeStatusBits
        def.slot = Int16(SLOT_OF_DUMB) - 200
        def.moveCall = cMoveAirMine
        def.rot = 0

        def.coord.y = GetMinTerrainY(x, z, Int16(def.group), Int16(def.type), def.scale)

        let base = MakeNewDisplayGroupObject(&def)!

        base.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF

        base.pointee.CType = UInt32(CTYPE_MISC)
        base.pointee.CBits = UInt32(CBITS_ALLSOLID)
        CreateCollisionBoxFromBoundingBox(base, 1, 1)

        // MAKE CHAIN

        def.type = UInt8(typeC)
        def.coord.y -= chainOff
        def.slot += 1
        def.moveCall = nil
        def.rot = RandomFloat() * SwPI2
        def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_CLIPALPHA6 | STATUS_BIT_DOUBLESIDED)
        let chain = MakeNewDisplayGroupObject(&def)!

        chain.pointee.SpecialF.0 = RandomFloat() * SwPI2 // WobbleX

        base.pointee.ChainNode = chain
        chain.pointee.ChainHead = base

        // MAKE MINE

        def.type = UInt8(typeM)
        def.slot += 1
        def.flags = gAutoFadeStatusBits
        let mine = MakeNewDisplayGroupObject(&def)!

        // SET COLLISION STUFF

        mine.pointee.Damage = 1.0

        mine.pointee.CType = UInt32(CTYPE_MISC | CTYPE_WEAPONTEST | CTYPE_TRIGGER)
        mine.pointee.CBits = UInt32(CBITS_ALLSOLID)
        CreateCollisionBoxFromBoundingBox(mine, 0.5, 0.9)

        mine.pointee.TriggerCallback = cDoTrig_AirMine
        mine.pointee.HitByWeaponHandler = cAirMineHitByWeaponCallback

        chain.pointee.ChainNode = mine
        mine.pointee.ChainHead = chain

        // CALL THE MOVE FUNCTION ONCE TO ALIGN ALL THE PARTS

        cMoveAirMine(base)

        return 1 // item was added
    }
}

// MARK: - Move air mine

private let mineOff = OGLPoint3D(x: 0, y: 1000, z: 0)
private let mineOff2 = OGLPoint3D(x: 0, y: 2000, z: 0)
private let lightOff = OGLPoint3D(x: 0, y: 1100, z: 0)
private let lightOff2 = OGLPoint3D(x: 0, y: 2100, z: 0)

private let cMoveAirMine: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { baseOpt in
    let base = baseOpt!
    let chain = base.pointee.ChainNode!
    let mine = chain.pointee.ChainNode!
    var origin = OGLPoint3D()
    var m = OGLMatrix4x4()
    var m2 = OGLMatrix4x4()

    // SEE IF GONE

    if TrackTerrainItem(base) != 0 {
        DeleteObject(base)
        return
    }

    // MAKE CHAIN WOBBLE

    chain.pointee.SpecialF.0 += gFramesPerSecondFrac * 1.1 // WobbleX
    chain.pointee.Rot.x = sin(chain.pointee.SpecialF.0) * 0.15

    // CALC MATRIX TO ROTATE CHAIN AROUND THE HING POINT

    origin.x = base.pointee.Coord.x // set coord to swivel about
    origin.y = base.pointee.Coord.y + (40.0 * airMineScale)
    origin.z = base.pointee.Coord.z

    m.setRotateAboutPoint(origin, xAngle: chain.pointee.Rot.x, yAngle: chain.pointee.Rot.y, zAngle: 0)

    m2.setScale(chain.pointee.Scale.x, chain.pointee.Scale.y, chain.pointee.Scale.z)
    setMatValue(&m2, M03, chain.pointee.Coord.x)
    setMatValue(&m2, M13, chain.pointee.Coord.y)
    setMatValue(&m2, M23, chain.pointee.Coord.z)

    chain.pointee.BaseTransformMatrix = m2.multiplied(by: m)

    SetObjectTransformMatrix(chain)

    // PUT MINE ON END OF CHAIN

    mine.pointee.Rot.x = chain.pointee.Rot.x // match x rot

    let mineOffVar: OGLPoint3D
    switch gLevelNum {
    case Int16(LevelNum.adventure1.rawValue), Int16(LevelNum.flag2.rawValue), Int16(LevelNum.battle1.rawValue):
        mineOffVar = mineOff // calc coord of mine @ end of chain

    default:
        mineOffVar = mineOff2
    }
    mine.pointee.Coord = mineOffVar.transformed(by: chain.pointee.BaseTransformMatrix)

    mine.updateTransforms()
    CalcObjectBoxFromNode(mine)

    // UPDATE LIGHT ON MINE

    // CALC COORD OF LIGHT

    let lightOffVar: OGLPoint3D
    switch gLevelNum {
    case Int16(LevelNum.adventure1.rawValue), Int16(LevelNum.flag2.rawValue), Int16(LevelNum.battle1.rawValue):
        lightOffVar = lightOff

    default:
        lightOffVar = lightOff2
    }
    origin = lightOffVar.transformed(by: chain.pointee.BaseTransformMatrix)

    // MAKE NEW SPARKLE

    if sparklesBase(mine)[0] == -1 {
        let i = GetFreeSparkle(mine) // make new sparkle
        sparklesBase(mine)[0] = i
        if i != -1 {
            let sparkle = GetSparkleSlot(Int32(i))!
            sparkle.pointee.flags = UInt32(SPARKLE_FLAG_OMNIDIRECTIONAL | SPARKLE_FLAG_FLICKER)
            sparkle.pointee.where = origin

            sparkle.pointee.color.r = 1
            sparkle.pointee.color.g = 1
            sparkle.pointee.color.b = 1
            sparkle.pointee.color.a = 1

            sparkle.pointee.scale = 100.0
            sparkle.pointee.separation = 300.0

            sparkle.pointee.textureNum = Int16(PARTICLE_SObjType_RedGlint)
        }
    }

    // UPDATE EXISTING SPARKLE

    else {
        let i = sparklesBase(mine)[0]
        GetSparkleSlot(Int32(i))!.pointee.where = origin
    }
}

@inline(__always) private func sparklesBase(_ n: UnsafeMutablePointer<ObjNode>) -> UnsafeMutablePointer<Int16> {
    UnsafeMutableRawPointer(n.pointer(to: \.Sparkles)!).assumingMemoryBound(to: Int16.self)
}

// MARK: -

// MARK: - Trigger callback: air mine

// Returns TRUE if want to handle hit as a solid
private let cDoTrig_AirMine: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?) -> UInt8 = { mineOpt, playerOpt in
    let mine = mineOpt!
    let player = playerOpt!
    let playerNum = player.pointee.PlayerNum

    let pi = GetPlayerInfoEntry(Int32(playerNum))

    // DOES PLAYER HAVE SHIELD?

    if pi.pointee.shieldPower > 0.0 {
        HitPlayerShield(Int16(playerNum), MAX_SHIELD_POWER, 2.5, 1) // completely drain shield
    }

    // NO SHIELD, SO KABOOM

    else if !gGamePrefs.isKiddieMode { // dont hurt in kiddie mode
        _ = PlayerSmackedIntoObject(player, mine, .deathDive)
    }

    explodeAirMine(mine)

    return 0
}

// MARK: - Air mine hit by weapon callback

// Returns true if object should stop bullet.
private let cAirMineHitByWeaponCallback: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<OGLPoint3D>?, UnsafeMutablePointer<OGLVector3D>?) -> UInt8 = { _, mineOpt, _, _ in
    explodeAirMine(mineOpt!)

    return 1
}

// MARK: - Explode air mine

private func explodeAirMine(_ mine: UnsafeMutablePointer<ObjNode>) {
    let chain = mine.pointee.ChainHead!
    let base = chain.pointee.ChainHead!

    // FIRST MAKE SPARKS

    gEngine.particles.newGroupDef.magicNum = 0
    gEngine.particles.newGroupDef.particleType = .fallingSparks
    gEngine.particles.newGroupDef.flags = UInt32(PARTICLE_FLAGS_BOUNCE)
    gEngine.particles.newGroupDef.gravity = 900
    gEngine.particles.newGroupDef.magnetism = 0
    gEngine.particles.newGroupDef.baseScale = 10
    gEngine.particles.newGroupDef.decayRate = 0.4
    gEngine.particles.newGroupDef.fadeRate = 0.7
    gEngine.particles.newGroupDef.particleTextureNum = UInt8(PARTICLE_SObjType_BlueSpark)
    gEngine.particles.newGroupDef.srcBlend = GL_SRC_ALPHA
    gEngine.particles.newGroupDef.dstBlend = GL_ONE
    let pg = NewParticleGroup(&gEngine.particles.newGroupDef)
    if pg != -1 {
        let x = mine.pointee.Coord.x
        let y = mine.pointee.Coord.y
        let z = mine.pointee.Coord.z

        for _ in 0..<70 {
            var d = OGLVector3D()
            d.x = RandomFloat2() * 800.0
            d.y = RandomFloat2() * 800.0
            d.z = RandomFloat2() * 800.0

            var pt = OGLPoint3D()
            pt.x = x + d.x * 0.05
            pt.y = y + d.y * 0.05
            pt.z = z + d.z * 0.05

            var newParticleDef = NewParticleDefType()
            newParticleDef.groupNum = pg
            newParticleDef.scale = RandomFloat() + 1.5
            newParticleDef.rotZ = 0
            newParticleDef.rotDZ = 0
            newParticleDef.alpha = Float(FULL_ALPHA) + (RandomFloat() * 0.3)

            withUnsafeMutablePointer(to: &pt) { ptPtr in
                withUnsafeMutablePointer(to: &d) { dPtr in
                    newParticleDef.where = ptPtr
                    newParticleDef.delta = dPtr
                    AddParticleToGroup(&newParticleDef)
                }
            }
        }
    }

    // MAKE FLARE BALLS

    for _ in 0..<10 {
        var def = NewObjectDefinitionType()
        def.genre = UInt8(CUSTOM_GENRE)
        def.slot = Int16(SLOT_OF_DUMB) + 20
        def.moveCall = cMoveAirMineFlareBall
        def.flags = UInt32(STATUS_BIT_DONTCULL)
        def.scale = 1

        let flare = MakeNewObject(&def)!

        // SET RANDOM TRAJECTORY

        let dx = RandomFloat2()
        let dy = RandomFloat2() + 0.5
        let dz = RandomFloat2()

        FastNormalizeVector(dx, dy, dz, &flare.pointee.Delta)

        // AND COORD

        flare.pointee.Coord.x = mine.pointee.Coord.x + flare.pointee.Delta.x * 50.0
        flare.pointee.Coord.y = mine.pointee.Coord.y + flare.pointee.Delta.y * 50.0
        flare.pointee.Coord.z = mine.pointee.Coord.z + flare.pointee.Delta.z * 50.0

        flare.pointee.Delta.x *= 800.0
        flare.pointee.Delta.y *= 800.0
        flare.pointee.Delta.z *= 800.0

        flare.pointee.Health = 1.2 + RandomFloat() * 0.3

        // MAKE NEW SPARKLE

        let i = GetFreeSparkle(flare)
        sparklesBase(flare)[0] = i
        if i != -1 {
            let sparkle = GetSparkleSlot(Int32(i))!
            sparkle.pointee.flags = UInt32(SPARKLE_FLAG_OMNIDIRECTIONAL)
            sparkle.pointee.where = mine.pointee.Coord

            sparkle.pointee.color.r = 1
            sparkle.pointee.color.g = 1
            sparkle.pointee.color.b = 1
            sparkle.pointee.color.a = 1

            sparkle.pointee.scale = 120.0
            sparkle.pointee.separation = 0.0

            sparkle.pointee.textureNum = Int16(PARTICLE_SObjType_YellowGlint)
        }
    }

    // EXPLODE GEOMETRY

    ExplodeGeometry(mine, 600, .fromOrigin, 1, 1.0)

    PlayEffect3D(Int16(EFFECT_MINEEXPLODE), &gEngine.objects.coord)

    // DELETE MINE & CLEANUP LINKAGES

    base.pointee.TerrainItemPtr = nil // don't come back

    DeleteObject(mine)
    DeleteObject(chain)

    base.pointee.ChainNode = nil

    base.pointee.MoveCall = MoveStaticObject
}

// MARK: - Move air mine flare ball

private let cMoveAirMineFlareBall: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { flareOpt in
    let flare = flareOpt!
    let fps = gFramesPerSecondFrac

    flare.pointee.Health -= fps
    if flare.pointee.Health <= 0.0 {
        DeleteObject(flare)
        return
    }

    flare.getInfo()

    gEngine.objects.delta.y -= 500.0 * fps

    gEngine.objects.coord.x += gEngine.objects.delta.x * fps
    gEngine.objects.coord.y += gEngine.objects.delta.y * fps
    gEngine.objects.coord.z += gEngine.objects.delta.z * fps

    let i = sparklesBase(flare)[0]
    if i != -1 {
        GetSparkleSlot(Int32(i))!.pointee.where = gEngine.objects.coord
    }

    flare.pointee.Delta = gEngine.objects.delta
    flare.pointee.Coord = gEngine.objects.coord

    // UpdateObject(flare)

    // UPDATE SPARKLE TRAIL

    flare.pointee.ParticleTimer -= fps
    if flare.pointee.ParticleTimer <= 0.0 {
        flare.pointee.ParticleTimer += 0.03 // reset timer

        var particleGroup = flare.pointee.ParticleGroup
        let magicNum = flare.pointee.ParticleMagicNum

        if particleGroup == -1 || VerifyParticleGroupMagicNum(particleGroup, magicNum) == 0 {
            let newMagicNum = MyRandomLong() // generate a random magic num
            flare.pointee.ParticleMagicNum = newMagicNum

            gEngine.particles.newGroupDef.magicNum = newMagicNum
            gEngine.particles.newGroupDef.particleType = .fallingSparks
            gEngine.particles.newGroupDef.flags = UInt32(PARTICLE_FLAGS_DONTCHECKGROUND)
            gEngine.particles.newGroupDef.gravity = -200
            gEngine.particles.newGroupDef.magnetism = 0
            gEngine.particles.newGroupDef.baseScale = 10.0
            gEngine.particles.newGroupDef.decayRate = 0
            gEngine.particles.newGroupDef.fadeRate = 0.6
            gEngine.particles.newGroupDef.particleTextureNum = UInt8(PARTICLE_SObjType_RedSpark)
            gEngine.particles.newGroupDef.srcBlend = GL_SRC_ALPHA
            gEngine.particles.newGroupDef.dstBlend = GL_ONE
            particleGroup = NewParticleGroup(&gEngine.particles.newGroupDef)
            flare.pointee.ParticleGroup = particleGroup
        }

        if particleGroup != -1 {
            for _ in 0..<4 {
                var d = OGLVector3D()
                d.x = RandomFloat2() * 30.0
                d.y = RandomFloat2() * 30.0
                d.z = RandomFloat2() * 30.0

                var p = gEngine.objects.coord

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
                    flare.pointee.ParticleGroup = -1
                    break
                }
            }
        }
    }
}
