// Turrets.swift - Port of Turrets.c to Swift

private let turretShootDist: Float = 3000.0

private let towerTurretScale: Float = 2.5

private var gTurretMuzzleTipOff = OGLPoint3D(x: -61, y: 0, z: -115)
private var gTurretMuzzleTipAim = OGLVector3D(x: 0, y: 0, z: -1)

// MARK: - Add tower turret

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    @discardableResult
    func addTowerTurret(x: Float, z: Float) -> UInt8 {
        let typeB: Int32
        let typeT: Int32
        let typeW: Int32
        let typeG: Int32

        switch gLevelNum {
        case Int16(LevelNum.adventure1.rawValue), Int16(LevelNum.flag2.rawValue), Int16(LevelNum.battle1.rawValue):
            typeB = Int32(LEVEL1_ObjType_TowerTurret_Base)
            typeT = Int32(LEVEL1_ObjType_TowerTurret_Turret)
            typeW = Int32(LEVEL1_ObjType_TowerTurret_Wheel)
            typeG = Int32(LEVEL1_ObjType_TowerTurret_Gun)

        case Int16(LevelNum.adventure2.rawValue), Int16(LevelNum.battle2.rawValue), Int16(LevelNum.race2.rawValue):
            typeB = Int32(LEVEL2_ObjType_TowerTurret_Base)
            typeT = Int32(LEVEL2_ObjType_TowerTurret_Turret)
            typeW = Int32(LEVEL2_ObjType_TowerTurret_Wheel)
            typeG = Int32(LEVEL2_ObjType_TowerTurret_Gun)

        case Int16(LevelNum.adventure3.rawValue), Int16(LevelNum.race1.rawValue), Int16(LevelNum.flag1.rawValue):
            typeB = Int32(LEVEL3_ObjType_TowerTurret_Base)
            typeT = Int32(LEVEL3_ObjType_TowerTurret_Turret)
            typeW = Int32(LEVEL3_ObjType_TowerTurret_Wheel)
            typeG = Int32(LEVEL3_ObjType_TowerTurret_Gun)

        default:
            SwFatal("AddTowerTurret: not here yet, call Brian!")
            return 0
        }

        // MAKE BASE

        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_LEVELSPECIFIC)
        def.type = UInt8(typeB)
        def.scale = towerTurretScale
        def.coord.x = x
        def.coord.z = z
        def.flags = gAutoFadeStatusBits
        def.slot = 331
        def.moveCall = cMoveTowerTurret
        def.rot = RandomFloat() * SwPI2
        def.coord.y = GetMinTerrainY(x, z, Int16(def.group), Int16(def.type), def.scale)

        let base = MakeNewDisplayGroupObject(&def)!

        base.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF

        base.pointee.CType = UInt32(CTYPE_MISC)
        base.pointee.CBits = UInt32(CBITS_ALLSOLID)
        CreateCollisionBoxFromBoundingBox(base, 1, 1)

        base.pointee.Health = 0.8

        // MAKE TURRET

        def.type = UInt8(typeT)
        def.slot += 1
        def.moveCall = nil
        let turret = MakeNewDisplayGroupObject(&def)!

        turret.pointee.CType = UInt32(CTYPE_WEAPONTEST | CTYPE_PLAYERTEST | CTYPE_AUTOTARGETWEAPON)
        turret.pointee.CBits = UInt32(CBITS_ALLSOLID)
        CreateCollisionBoxFromBoundingBox(turret, 1, 1)
        turret.pointee.HitByWeaponHandler = cTurretHitByWeaponCallback

        turret.pointee.HeatSeekHotSpotOff.x = 0
        turret.pointee.HeatSeekHotSpotOff.y = 300.0
        turret.pointee.HeatSeekHotSpotOff.z = 0

        base.pointee.ChainNode = turret
        turret.pointee.ChainHead = base

        // MAKE WHEEL

        def.type = UInt8(typeW)
        def.slot += 1
        def.flags |= UInt32(STATUS_BIT_ROTZXY)
        let wheel = MakeNewDisplayGroupObject(&def)!

        wheel.pointee.CType = UInt32(CTYPE_WEAPONTEST | CTYPE_PLAYERTEST | CTYPE_AUTOTARGETWEAPON)

        turret.pointee.ChainNode = wheel
        wheel.pointee.ChainHead = turret

        // MAKE GUN

        def.type = UInt8(typeG)
        def.flags = gAutoFadeStatusBits
        def.slot += 1
        let gun = MakeNewDisplayGroupObject(&def)!

        gun.pointee.CType = UInt32(CTYPE_WEAPONTEST | CTYPE_PLAYERTEST | CTYPE_AUTOTARGETWEAPON)

        wheel.pointee.ChainNode = gun
        gun.pointee.ChainHead = wheel

        // MAKE LENS

        def.group = UInt8(MODEL_GROUP_GLOBAL)
        def.type = UInt8(GLOBAL_ObjType_TowerTurret_Lens)
        def.slot = Int16(SLOT_OF_DUMB)
        def.flags |= UInt32(STATUS_BIT_GLOW)
        let lens = MakeNewDisplayGroupObject(&def)!

        gun.pointee.ChainNode = lens
        lens.pointee.ChainHead = gun

        return 1 // item was added
    }
}

// MARK: - Move tower turret

private var aimOff = OGLPoint3D(x: 0, y: 0, z: -150)
private var wheelOff = OGLPoint3D(x: 31.837, y: 282.548, z: 0)
private var gunOff = OGLPoint3D(x: 0, y: 283.141, z: 0)

private let cMoveTowerTurret: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { baseOpt in
    guard let base = baseOpt else { return }
    let turret = base.pointee.ChainNode!
    let wheel = turret.pointee.ChainNode!
    let gun = wheel.pointee.ChainNode!
    let lens = gun.pointee.ChainNode!
    let fps = gFramesPerSecondFrac
    var shootNow = false

    // SEE IF GONE

    if TrackTerrainItem(base) != 0 {
        DeleteObject(base)
        return
    }

    // UPDATE TURRET

    if gGamePrefs.kiddieMode == 0 {
        gun.pointee.SpecialF.0 -= fps // ShootTimer

        var playerNum: Int16 = 0
        let dist = CalcDistanceToClosestPlayer(&turret.pointee.Coord, &playerNum) // calc dist to player

        let shootDist: Float = (gLevelNum == Int16(LevelNum.adventure1.rawValue)) ? (turretShootDist * 2 / 3) : turretShootDist // make this easier on level 1

        if dist < (shootDist * 1.2) { // see if player is close enough for turret to aim
            let player = GetPlayerInfoEntry(Int32(playerNum)).pointee.objNode!
            var aimPt = aimOff.transformed(by: player.pointee.BaseTransformMatrix) // calc pt in front of player to aim ag
            var muzzleCoord = gTurretMuzzleTipOff.transformed(by: gun.pointee.BaseTransformMatrix) // calc coord of muzzle for more accurate rotation next
            let angle = turret.turnTowardTarget(from: &muzzleCoord, toX: aimPt.x, toZ: aimPt.z, turnSpeed: Float.pi / 2, useOffsets: 0, crossOut: nil) // turn turret on y-axis

            turret.updateTransforms()

            // IF AIMED CLOSE, THEN ALSO AIM GUN

            if angle < (Float.pi / 4) {
                let angle2 = gun.turnTowardTargetOnX(from: &gun.pointee.Coord, to: &aimPt, turnSpeed: Float.pi / 2)
                if angle2 < (Float.pi / 3) {
                    if dist < shootDist { // see if player close enough to shoot at
                        if gun.pointee.SpecialF.0 <= 0.0 {
                            shootNow = true // shoot after updating gun below
                        }
                    }
                }
            }
        }

        // OUT OF RANGE OF PLAYER, SO JUST SPIN
        else {
            turret.pointee.Rot.y += fps
            turret.updateTransforms()
        }
    } else {
        turret.pointee.Rot.y += fps
        turret.updateTransforms()
    }

    // UPDATE LENS

    lens.pointee.BaseTransformMatrix = turret.pointee.BaseTransformMatrix // match with turret
    SetObjectTransformMatrix(lens)

    // UPDATE WHEEL

    wheel.pointee.Coord = wheelOff.transformed(by: turret.pointee.BaseTransformMatrix)
    wheel.pointee.Rot.z += fps * SwPI2
    wheel.pointee.Rot.y = turret.pointee.Rot.y
    wheel.updateTransforms()

    // UPDATE GUN

    gun.pointee.Coord = gunOff.transformed(by: turret.pointee.BaseTransformMatrix)
    gun.pointee.Rot.y = turret.pointee.Rot.y

    gun.updateTransforms()

    if shootNow {
        shootTurretGun(gun)
    }

    // UPDATE MUZZLE SPARKLE

    let i = sparklesBase(gun)[0] // get sparkle index
    if i != -1 {
        let sparkle = GetSparkleSlot(Int32(i))!
        sparkle.pointee.color.a -= fps * 4.0 // fade out
        if sparkle.pointee.color.a <= 0.0 {
            DeleteSparkle(i)
            sparklesBase(gun)[0] = -1
        }
    }
}

@inline(__always) private func sparklesBase(_ n: UnsafeMutablePointer<ObjNode>) -> UnsafeMutablePointer<Int16> {
    UnsafeMutableRawPointer(n.pointer(to: \.Sparkles)!).assumingMemoryBound(to: Int16.self)
}

// MARK: -

// MARK: - Turret hit by weapon callback

// Returns true if object should stop bullet.
private let cTurretHitByWeaponCallback: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<OGLPoint3D>?, UnsafeMutablePointer<OGLVector3D>?) -> UInt8 = { bullet, theNodeOpt, _, _ in
    var theNode = theNodeOpt!

    // FIND BASE OBJECT

    while let chainHead = theNode.pointee.ChainHead {
        theNode = chainHead
    }

    // CAUSE DAMAGE

    theNode.pointee.Health -= bullet!.pointee.Damage
    if theNode.pointee.Health <= 0.0 {
        explodeTurret(theNode)
    }

    return 1
}

// MARK: - Explode turret

private func explodeTurret(_ base: UnsafeMutablePointer<ObjNode>) {
    var node: UnsafeMutablePointer<ObjNode>? = base

    PlayEffect_Parms3D(Int16(EFFECT_TURRETEXPLOSION), &base.pointee.Coord, UInt32(NORMAL_CHANNEL_RATE), 2.0)

    // DO SHARD EXPLOSION FOR ALL GEOMETRY

    repeat {
        ExplodeGeometry(node, 240.0 + RandomFloat() * 50.0, .fromOrigin, 1, 0.6)

        node = node!.pointee.ChainNode // next obj in chain
    } while node != nil

    // MAKE FIREBALL

    let x = base.pointee.Coord.x
    let y = base.pointee.Coord.y
    let z = base.pointee.Coord.z

    gNewParticleGroupDef.magicNum = 0
    gNewParticleGroupDef.type = UInt8(ParticleType.fallingSparks.rawValue)
    gNewParticleGroupDef.flags = UInt32(PARTICLE_FLAGS_DONTCHECKGROUND)
    gNewParticleGroupDef.gravity = -50
    gNewParticleGroupDef.magnetism = 0
    gNewParticleGroupDef.baseScale = 18
    gNewParticleGroupDef.decayRate = -4.0
    gNewParticleGroupDef.fadeRate = 0.7
    gNewParticleGroupDef.particleTextureNum = UInt8(PARTICLE_SObjType_Fire)
    gNewParticleGroupDef.srcBlend = GL_SRC_ALPHA
    gNewParticleGroupDef.dstBlend = GL_ONE
    var pg = NewParticleGroup(&gNewParticleGroupDef)
    if pg != -1 {
        for _ in 0..<150 {
            var d = OGLVector3D()
            d.y = RandomFloat2() * 100.0
            d.x = RandomFloat2() * 100.0
            d.z = RandomFloat2() * 100.0

            var pt = OGLPoint3D()
            pt.x = x + d.x * 0.2
            pt.y = y + RandomFloat() * (towerTurretScale * 400.0)
            pt.z = z + d.z * 0.2

            var newParticleDef = NewParticleDefType()
            newParticleDef.groupNum = pg
            newParticleDef.scale = RandomFloat() + 1.0
            newParticleDef.rotZ = RandomFloat() * SwPI2
            newParticleDef.rotDZ = RandomFloat2() * 8.0
            newParticleDef.alpha = 1.0 - (RandomFloat() * 0.3)

            withUnsafeMutablePointer(to: &pt) { ptPtr in
                withUnsafeMutablePointer(to: &d) { dPtr in
                    newParticleDef.where = ptPtr
                    newParticleDef.delta = dPtr
                    AddParticleToGroup(&newParticleDef)
                }
            }
        }
    }

    // MAKE SPARKS

    gNewParticleGroupDef.magicNum = 0
    gNewParticleGroupDef.type = UInt8(ParticleType.fallingSparks.rawValue)
    gNewParticleGroupDef.flags = UInt32(PARTICLE_FLAGS_DONTCHECKGROUND)
    gNewParticleGroupDef.gravity = 100
    gNewParticleGroupDef.magnetism = 0
    gNewParticleGroupDef.baseScale = 15
    gNewParticleGroupDef.decayRate = 0.2
    gNewParticleGroupDef.fadeRate = 0.5
    gNewParticleGroupDef.particleTextureNum = UInt8(PARTICLE_SObjType_WhiteSpark4)
    gNewParticleGroupDef.srcBlend = GL_SRC_ALPHA
    gNewParticleGroupDef.dstBlend = GL_ONE
    pg = NewParticleGroup(&gNewParticleGroupDef)
    if pg != -1 {
        for _ in 0..<200 {
            let q = RandomFloat() * SwPI2
            var d = OGLVector3D()
            d.x = sin(q) * 600.0
            d.y = RandomFloat() * 80.0
            d.z = cos(q) * 600.0

            var pt = OGLPoint3D()
            pt.x = x + d.x * 0.05
            pt.y = y + (towerTurretScale * 220.0)
            pt.z = z + d.z * 0.05

            var newParticleDef = NewParticleDefType()
            newParticleDef.groupNum = pg
            newParticleDef.scale = RandomFloat() + 1.0
            newParticleDef.rotZ = 0
            newParticleDef.rotDZ = 0
            newParticleDef.alpha = 1.0 + (RandomFloat() * 0.3)

            withUnsafeMutablePointer(to: &pt) { ptPtr in
                withUnsafeMutablePointer(to: &d) { dPtr in
                    newParticleDef.where = ptPtr
                    newParticleDef.delta = dPtr
                    AddParticleToGroup(&newParticleDef)
                }
            }
        }
    }

    // DELETE THE ENTIRE TURRET HIERARCHY

    base.pointee.TerrainItemPtr = nil // dont ever come back
    DeleteObject(base)
}

// MARK: -

// MARK: - Shoot turret gun

private func shootTurretGun(_ gun: UnsafeMutablePointer<ObjNode>) {
    gun.pointee.SpecialF.0 = 0.3 // ShootTimer: reset delay

    // MAKE MUZZLE FLASH

    if sparklesBase(gun)[0] != -1 { // see if delete existing sparkle
        DeleteSparkle(sparklesBase(gun)[0])
        sparklesBase(gun)[0] = -1
    }

    var i = GetFreeSparkle(gun) // make new sparkle
    sparklesBase(gun)[0] = i
    if i != -1 {
        let sparkle = GetSparkleSlot(Int32(i))!
        sparkle.pointee.flags = UInt32(SPARKLE_FLAG_TRANSFORMWITHOWNER | SPARKLE_FLAG_OMNIDIRECTIONAL)
        sparkle.pointee.where = gTurretMuzzleTipOff

        sparkle.pointee.color.r = 1
        sparkle.pointee.color.g = 1
        sparkle.pointee.color.b = 1
        sparkle.pointee.color.a = 1

        sparkle.pointee.scale = 200.0
        sparkle.pointee.separation = 10.0

        sparkle.pointee.textureNum = Int16(PARTICLE_SObjType_YellowGlint)
    }

    // CREATE WEAPON OBJECT

    // CALC COORD & VECTOR OF MUZZLE

    let muzzleCoord = gTurretMuzzleTipOff.transformed(by: gun.pointee.BaseTransformMatrix)
    var muzzleVector = gTurretMuzzleTipAim.transformed(by: gun.pointee.BaseTransformMatrix)

    // MAKE OBJECT

    var def = NewObjectDefinitionType()
    def.group = UInt8(MODEL_GROUP_GLOBAL)
    def.type = UInt8(GLOBAL_ObjType_TowerTurret_TurretBullet)
    def.coord = muzzleCoord
    def.flags = UInt32(STATUS_BIT_USEALIGNMENTMATRIX | STATUS_BIT_GLOW | STATUS_BIT_NOZWRITES | STATUS_BIT_NOFOG | STATUS_BIT_DOUBLESIDED | STATUS_BIT_NOTEXTUREWRAP)
    def.slot = Int16(SLOT_OF_DUMB) - 1
    def.moveCall = cMoveTurretBullet
    def.rot = 0
    def.scale = 3

    let newObj = MakeNewDisplayGroupObject(&def)!

    newObj.pointee.Kind = Int32(WeaponType.blaster.rawValue)

    newObj.pointee.ColorFilter.a = 0.99 // do this just to turn on transparency so it'll glow

    newObj.pointee.Delta.x = muzzleVector.x * 3000.0
    newObj.pointee.Delta.y = muzzleVector.y * 3000.0
    newObj.pointee.Delta.z = muzzleVector.z * 3000.0

    newObj.pointee.Health = 1.0

    newObj.pointee.Damage = 0.08

    // SET THE ALIGNMENT MATRIX

    SetAlignmentMatrix(&newObj.pointee.AlignmentMatrix, &muzzleVector)

    PlayEffect3D(Int16(EFFECT_TURRETFIRE), &newObj.pointee.Coord)

    // MAKE SPARKLE FOR HEAD

    i = GetFreeSparkle(newObj) // make new sparkle
    sparklesBase(newObj)[0] = i
    if i != -1 {
        let sparkleOff = OGLPoint3D(x: 0, y: 0, z: -15)
        let sparkle = GetSparkleSlot(Int32(i))!

        sparkle.pointee.flags = UInt32(SPARKLE_FLAG_OMNIDIRECTIONAL | SPARKLE_FLAG_TRANSFORMWITHOWNER)
        sparkle.pointee.where = sparkleOff

        sparkle.pointee.color.r = 1
        sparkle.pointee.color.g = 1
        sparkle.pointee.color.b = 1
        sparkle.pointee.color.a = 1

        sparkle.pointee.scale = 350.0
        sparkle.pointee.separation = 10.0

        sparkle.pointee.textureNum = Int16(PARTICLE_SObjType_GreenGlint)
    }
}

// MARK: - Move turret bullet

private let cMoveTurretBullet: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }
    let fps = gFramesPerSecondFrac

    // SEE IF GONE

    theNode.pointee.Health -= fps
    if theNode.pointee.Health <= 0.0 {
        DeleteObject(theNode)
        return
    }

    theNode.getInfo()

    // MOVE IT

    gCoord.x += gDelta.x * fps
    gCoord.y += gDelta.y * fps
    gCoord.z += gDelta.z * fps

    // SEE IF HIT ANYTHING

    if doTurretBlastCollisionDetection(theNode) {
        return
    }

    theNode.update()
}

// MARK: - Do turret blast collision detection

// Returns TRUE if blaster bullet was deleted.
@discardableResult
private func doTurretBlastCollisionDetection(_ theNode: UnsafeMutablePointer<ObjNode>) -> Bool {
    var hitPt = OGLPoint3D()
    var hitNormal = OGLVector3D()
    var hitObj: UnsafeMutablePointer<ObjNode>?

    // CREATE LINE SEGMENT TO DO COLLISION WITH

    var lineSegment = OGLLineSegment()
    lineSegment.p1 = theNode.pointee.OldCoord // from old coord

    lineSegment.p2.x = gCoord.x + theNode.pointee.MotionVector.x * 50.0 // to new coord (in front of center)
    lineSegment.p2.y = gCoord.y + theNode.pointee.MotionVector.y * 50.0
    lineSegment.p2.z = gCoord.z + theNode.pointee.MotionVector.z * 50.0

    // SEE IF LINE SEGMENT HITS ANY GEOMETRY

    var cType = UInt32(CTYPE_MISC | CTYPE_FENCE | CTYPE_TERRAIN | CTYPE_PLAYER1 | CTYPE_PLAYER2) // set CTYPE mask to find what we're looking for

    let hit = withUnsafeMutablePointer(to: &hitObj) { hitObjPtr in
        withUnsafeMutablePointer(to: &cType) { cTypePtr in
            HandleLineSegmentCollision(&lineSegment, hitObjPtr, &hitPt, &hitNormal, cTypePtr, 1)
        }
    } != 0

    if hit {
        // DID WE HIT AN OBJNODE?

        if let hitObj, let handler = hitObj.pointee.HitByWeaponHandler { // see if there is a handler for this object
            _ = handler(theNode, hitObj, &hitPt, &hitNormal) // call the handler
        }

        // EXPLODE THE BULLET

        if cType == UInt32(CTYPE_TERRAIN) {
            doTurretBlastImpactTerrainEffect(&hitPt, &hitNormal) // do special terrain impact
        } else {
            doTurretBlastImpactObjectEffect(&hitPt, &hitNormal) // do special object impact
        }

        DeleteObject(theNode)
        return true
    }

    return false
}

// MARK: - Do turret blast impact terrain effect

private func doTurretBlastImpactTerrainEffect(_ impactPt: UnsafePointer<OGLPoint3D>!, _ surfaceNormal: UnsafePointer<OGLVector3D>!) {
    var coord = impactPt.pointee

    // CREATE NEW PARTICLE GROUP

    gNewParticleGroupDef.magicNum = 0
    gNewParticleGroupDef.type = UInt8(ParticleType.fallingSparks.rawValue)
    gNewParticleGroupDef.flags = UInt32(PARTICLE_FLAGS_BOUNCE)
    gNewParticleGroupDef.gravity = 1000
    gNewParticleGroupDef.magnetism = 0
    gNewParticleGroupDef.baseScale = 15.0
    gNewParticleGroupDef.decayRate = -1.7
    gNewParticleGroupDef.fadeRate = 0.6
    gNewParticleGroupDef.particleTextureNum = UInt8(PARTICLE_SObjType_RedSpark)
    gNewParticleGroupDef.srcBlend = GL_SRC_ALPHA
    gNewParticleGroupDef.dstBlend = GL_ONE

    let pg = NewParticleGroup(&gNewParticleGroupDef)
    if pg != -1 {
        for _ in 0..<130 {
            // CALC NEW VECTOR IN CONE OF AIM

            let zrot = RandomFloat2() * 0.15
            let yrot = RandomFloat2() * 0.15
            var m = OGLMatrix4x4()
            m.setRotateXYZ(0, yrot, zrot)
            let v = surfaceNormal.pointee.transformed(by: m)

            let speed = 30.0 + RandomFloat() * 900.0
            var delta = OGLVector3D()
            delta.x = v.x * speed
            delta.y = v.y * speed
            delta.z = v.z * speed

            var newParticleDef = NewParticleDefType()
            newParticleDef.groupNum = pg
            newParticleDef.scale = 1.0 + RandomFloat() * 1.5
            newParticleDef.rotZ = RandomFloat() * SwPI2
            newParticleDef.rotDZ = RandomFloat() * 11.0
            newParticleDef.alpha = Float(FULL_ALPHA) - RandomFloat() * 0.5

            let stop: Bool = withUnsafeMutablePointer(to: &coord) { coordPtr in
                withUnsafeMutablePointer(to: &delta) { deltaPtr in
                    newParticleDef.where = coordPtr
                    newParticleDef.delta = deltaPtr
                    return AddParticleToGroup(&newParticleDef) != 0
                }
            }
            if stop {
                break
            }
        }
    }

    PlayEffect3D(Int16(EFFECT_IMPACTSIZZLE), &gCoord)
}

// MARK: - Do turret blast impact object effect

private func doTurretBlastImpactObjectEffect(_ impactPt: UnsafePointer<OGLPoint3D>!, _ surfaceNormal: UnsafePointer<OGLVector3D>!) {
    var coord = impactPt.pointee

    // CREATE NEW PARTICLE GROUP

    gNewParticleGroupDef.magicNum = 0
    gNewParticleGroupDef.type = UInt8(ParticleType.fallingSparks.rawValue)
    gNewParticleGroupDef.flags = UInt32(PARTICLE_FLAGS_BOUNCE | PARTICLE_FLAGS_ALLAIM)
    gNewParticleGroupDef.gravity = 100
    gNewParticleGroupDef.magnetism = 0
    gNewParticleGroupDef.baseScale = 10.0
    gNewParticleGroupDef.decayRate = -1.2
    gNewParticleGroupDef.fadeRate = 0.9
    gNewParticleGroupDef.particleTextureNum = UInt8(PARTICLE_SObjType_RedSpark)
    gNewParticleGroupDef.srcBlend = GL_SRC_ALPHA
    gNewParticleGroupDef.dstBlend = GL_ONE

    let pg = NewParticleGroup(&gNewParticleGroupDef)
    if pg != -1 {
        for _ in 0..<50 {
            // CALC NEW VECTOR IN CONE OF AIM

            let zrot = RandomFloat2() * 0.15
            let yrot = RandomFloat2() * 0.15
            var m = OGLMatrix4x4()
            m.setRotateXYZ(0, yrot, zrot)
            let v = surfaceNormal.pointee.transformed(by: m)

            let speed = 30.0 + RandomFloat() * 300.0
            var delta = OGLVector3D()
            delta.x = v.x * speed
            delta.y = v.y * speed
            delta.z = v.z * speed

            var newParticleDef = NewParticleDefType()
            newParticleDef.groupNum = pg
            newParticleDef.scale = 1.0 + RandomFloat() * 1.5
            newParticleDef.rotZ = RandomFloat() * SwPI2
            newParticleDef.rotDZ = RandomFloat() * 11.0
            newParticleDef.alpha = Float(FULL_ALPHA) - RandomFloat() * 0.5

            let stop: Bool = withUnsafeMutablePointer(to: &coord) { coordPtr in
                withUnsafeMutablePointer(to: &delta) { deltaPtr in
                    newParticleDef.where = coordPtr
                    newParticleDef.delta = deltaPtr
                    return AddParticleToGroup(&newParticleDef) != 0
                }
            }
            if stop {
                break
            }
        }
    }

    PlayEffect3D(Int16(EFFECT_IMPACTSIZZLE), &gCoord)
}
