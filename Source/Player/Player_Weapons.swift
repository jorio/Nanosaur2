// Player_Weapons.swift - Port of Player_Weapons.c to Swift

private let blasterBulletSpeed: Float = 4000.0
private let blasterAutoFireDelay: Float = 0.16

private let numShotsInCluster = 4
private let clusterBulletSpeed: Float = 2500.0

private let sonicScreamSpeed: Float = 1800.0

private let heatSeekerBulletMaxSpeed: Float = 2300.0
private let heatSeekerTurnSpeed: Float = 3.8 // smaller == more slide, larger = less slide
private let heatSeekerButtOff: Float = 50.0

private let clusterShotSingle: Int32 = 0
private let clusterShotFragment: Int32 = 1

private var gPlayerMuzzleTipAim = OGLVector3D(x: 0, y: 0, z: -1) // aim vector of root body matrix (not the gun joint!)

private let FULL_CHANNEL_VOLUME: UInt32 = 0x0100

// IsStereo is a parameterized C macro, which Swift can't import as a callable symbol.
private func isStereo() -> Bool { gGamePrefs.stereoGlassesMode != UInt8(StereoGlassesMode.off.rawValue) }

@inline(__always) private func weaponQuantityBase(_ p: UnsafeMutablePointer<PlayerInfoType>) -> UnsafeMutablePointer<Int16> {
    UnsafeMutableRawPointer(p.pointer(to: \.weaponQuantity)!).assumingMemoryBound(to: Int16.self)
}

@inline(__always) private func sparklesBase(_ n: UnsafeMutablePointer<ObjNode>) -> UnsafeMutablePointer<Int16> {
    UnsafeMutableRawPointer(n.pointer(to: \.Sparkles)!).assumingMemoryBound(to: Int16.self)
}

@inline(__always) private func crosshairCoordBase(_ p: UnsafeMutablePointer<PlayerInfoType>) -> UnsafeMutablePointer<OGLPoint3D> {
    UnsafeMutableRawPointer(p.pointer(to: \.crosshairCoord)!).assumingMemoryBound(to: OGLPoint3D.self)
}

// MARK: - Update player crosshairs

@c @implementation
public func UpdatePlayerCrosshairs(_ player: UnsafeMutablePointer<ObjNode>!) {
    let p = Int(player.pointee.PlayerNum)

    // DO RAY COLLISION AGAINST THE SCENE TO SEE WHAT THE CROSSHAIRS HIT

    // FIRST SEE IF RAY HITS ANY OBJNODES

    var ray = OGLRay()
    OGLVector3D_Transform(&gPlayerMuzzleTipAim, &player.pointee.BaseTransformMatrix, &ray.direction)

    var ctype = UInt32(CTYPE_AUTOTARGETWEAPON) // look for things which auto target the weapon
    ctype |= UInt32(CTYPE_PLAYER2) >> UInt32(p) // and also other players

    ray.origin = gCoord
    let hitNode = OGL_DoRayCollision_ObjNodes(&ray, UInt32(STATUS_BIT_HIDDEN) | (UInt32(STATUS_BIT_ISCULLED1) << UInt32(p)), ctype, nil, nil)

    let pi = GetPlayerInfoEntry(Int32(p))!
    if let hitNode {
        pi.pointee.crosshairTargetObj = hitNode
        pi.pointee.crosshairTargetCookie = hitNode.pointee.Cookie
    } else {
        pi.pointee.crosshairTargetObj = nil
    }

    // SET CROSSHAIR COORDS

    let f: Float = isStereo() ? 800.0 : 1000.0

    var coord = OGLPoint3D()
    coord.x = player.pointee.Coord.x + (ray.direction.x * f)
    coord.y = player.pointee.Coord.y + (ray.direction.y * f)
    coord.z = player.pointee.Coord.z + (ray.direction.z * f)

    let crosshairCoord = crosshairCoordBase(pi)
    for i in 0..<Int(NUM_CROSSHAIR_LEVELS) {
        crosshairCoord[i] = coord

        let dist: Float = isStereo() ? 500.0 : 5000.0

        coord.x += ray.direction.x * dist
        coord.y += ray.direction.y * dist
        coord.z += ray.direction.z * dist
    }
}

// MARK: - Player fire button pressed

// Called when player presses the Fire button
@c @implementation
public func PlayerFireButtonPressed(_ player: UnsafeMutablePointer<ObjNode>!, _ newFireButton: UInt8) {
    let playerNum = Int32(player.pointee.PlayerNum)
    let pi = GetPlayerInfoEntry(playerNum)!
    var didShoot = false

    let weaponType = pi.pointee.currentWeapon

    if weaponType == Int16(WeaponType.none.rawValue) { // bail if no weapon selected
        return
    }

    // SHOOT THE APPROPRIATE PROJECTILE

    SetAutoFireDelay(playerNum, GetAutoFireDelay(playerNum) - gFramesPerSecondFrac)

    switch weaponType {
    // BLASTER
    case Int16(WeaponType.blaster.rawValue):
        if GetAutoFireDelay(playerNum) <= 0.0 {
            ShootBlaster(player)
            SetAutoFireDelay(playerNum, GetAutoFireDelay(playerNum) + blasterAutoFireDelay)
            didShoot = true
        }

    // CLUSTER SHOT
    case Int16(WeaponType.clusterShot.rawValue):
        if newFireButton != 0 {
            ShootClusterShot(player)
            didShoot = true
        }

    // SONIC SCREAM
    case Int16(WeaponType.sonicScream.rawValue):
        if newFireButton != 0 {
            pi.pointee.weaponCharge = 0 // start it charging
        } else {
            pi.pointee.weaponCharge += gFramesPerSecondFrac * 0.5 // continue charging
            if pi.pointee.weaponCharge > 1.0 {
                pi.pointee.weaponCharge = 1.0
            }

            if pi.pointee.weaponChargeChannel == -1 { // update charging sfx
                pi.pointee.weaponChargeChannel = PlayEffect_Parms(Int16(EFFECT_WEAPONCHARGE), FULL_CHANNEL_VOLUME / 3, FULL_CHANNEL_VOLUME / 4, UInt(NORMAL_CHANNEL_RATE))
            }
        }

    // HEAT SEEKER
    case Int16(WeaponType.heatSeeker.rawValue):
        if newFireButton != 0 {
            ShootHeatSeeker(player)
            didShoot = true
        }

    // BOMB
    case Int16(WeaponType.bomb.rawValue):
        if newFireButton != 0 {
            ShootBomb(player)
            didShoot = true
        }

    default:
        break
    }

    // DEC THE QUANTITY

    if didShoot && (weaponType != Int16(WeaponType.sonicScream.rawValue)) {
        let quantity = weaponQuantityBase(pi)
        quantity[Int(weaponType)] -= 1 // dec bullet count
        if quantity[Int(weaponType)] <= 0 { // if we're out, try to select next weapon in inventory
            SelectNextWeapon(Int16(playerNum), 0, 1)
        }
    }
}

// MARK: - Player fire button released

// Called when player releases a previously pressed Fire button
//
// This is used by weapons which require a charge before firing.
@c @implementation
public func PlayerFireButtonReleased(_ player: UnsafeMutablePointer<ObjNode>!) {
    let playerNum = Int32(player.pointee.PlayerNum)
    let pi = GetPlayerInfoEntry(playerNum)!
    var didShoot = false

    let weaponType = pi.pointee.currentWeapon

    if weaponType == Int16(WeaponType.none.rawValue) { // bail if no weapon selected
        return
    }

    // SHOOT THE APPROPRIATE PROJECTILE

    switch weaponType {
    // SONIC SCREAM
    case Int16(WeaponType.sonicScream.rawValue):
        StopAChannel(&pi.pointee.weaponChargeChannel)

        if pi.pointee.weaponCharge > 0.3 { // see if sufficient charge to fire the weapon
            ShootSonicScream(player)
            didShoot = true
        }

    default:
        break
    }

    pi.pointee.weaponCharge = 0

    // DEC THE QUANTITY

    if didShoot {
        let quantity = weaponQuantityBase(pi)
        quantity[Int(weaponType)] -= 1 // dec bullet count
        if quantity[Int(weaponType)] <= 0 { // if we're out, try to select next weapon in inventory
            SelectNextWeapon(Int16(playerNum), 0, 1)
        }
    }
}

// MARK: - Select next weapon

// Scans thru our weapon inventory starting at the current weapon, looking for another weapon
// which we have inventory for.
@c @implementation
public func SelectNextWeapon(_ playerNum: Int16, _ allowSonicScream: UInt8, _ delta: Int32) {
    let pi = GetPlayerInfoEntry(Int32(playerNum))!
    let numWeaponTypes = Int32(WeaponType.allCases.count)

    pi.pointee.weaponCharge = 0 // make sure not charging

    var startWeapon = Int32(pi.pointee.currentWeapon) // get currently selected weapon
    if startWeapon == Int32(WeaponType.none.rawValue) { // if nothing was selected then just start as though we had the first weapon type
        startWeapon = 0
    }

    // SCAN FOR ANOTHER WEAPON

    var i = startWeapon

    while true { // scan until we've looped back to where we started
        i += delta // try next weapon slot
        i = PositiveModulo(i, UInt32(numWeaponTypes)) // loop back to front of list?

        if i == startWeapon { // did we loop to where we started?
            if i == Int32(WeaponType.sonicScream.rawValue) { // if already SS, then bail
                return
            }

            i = Int32(WeaponType.sonicScream.rawValue) // must be out of everything, so default to sonic scream
            StopAChannel(&pi.pointee.weaponChargeChannel) // make sure to stop this
            PlayEffect_Parms(Int16(EFFECT_CHANGEWEAPON), FULL_CHANNEL_VOLUME / 2, FULL_CHANNEL_VOLUME / 2, UInt(NORMAL_CHANNEL_RATE))
            pi.pointee.currentWeapon = Int16(i)
            return
        }

        if allowSonicScream == 0 // see if skip sonic scream
            && i == Int32(WeaponType.sonicScream.rawValue) {
            continue
        }

        if weaponQuantityBase(pi)[Int(i)] > 0 { // do we have any of this weapon type?
            StopAChannel(&pi.pointee.weaponChargeChannel) // make sure to stop this
            PlayEffect_Parms(Int16(EFFECT_CHANGEWEAPON), FULL_CHANNEL_VOLUME / 2, FULL_CHANNEL_VOLUME / 2, UInt(NORMAL_CHANNEL_RATE))
            pi.pointee.currentWeapon = Int16(i)
            return
        }
    }
}

// MARK: - Shoot blaster

private func ShootBlaster(_ player: UnsafeMutablePointer<ObjNode>!) {
    var where_ = OGLPoint3D()
    var aim = OGLVector3D()

    CalcPlayerGunMuzzleInfo(player, &where_, &aim)

    // CREATE WEAPON OBJECT

    var def = NewObjectDefinitionType()
    def.group = UInt8(MODEL_GROUP_WEAPONS)
    def.type = UInt8(WEAPONS_ObjType_BlasterBullet)
    def.coord = where_
    def.flags = UInt32(STATUS_BIT_USEALIGNMENTMATRIX | STATUS_BIT_GLOW | STATUS_BIT_NOZWRITES | STATUS_BIT_NOFOG | STATUS_BIT_DOUBLESIDED | STATUS_BIT_NOTEXTUREWRAP | STATUS_BIT_NOLIGHTING)
    def.slot = Int16(WATER_SLOT + 1)
    def.moveCall = cMoveBlasterBullet
    def.rot = 0
    def.scale = 4

    let newObj = MakeNewDisplayGroupObject(&def)!

    newObj.pointee.Kind = Int32(WeaponType.blaster.rawValue)
    newObj.pointee.PlayerNum = player.pointee.PlayerNum // remember which player shot this

    newObj.pointee.ColorFilter.a = 0.99 // do this just to turn on transparency so it'll glow

    newObj.pointee.Delta.x = aim.x * blasterBulletSpeed
    newObj.pointee.Delta.y = aim.y * blasterBulletSpeed
    newObj.pointee.Delta.z = aim.z * blasterBulletSpeed

    newObj.pointee.Health = 2.0

    if gVSMode == .none {
        newObj.pointee.Damage = 0.2
    } else {
        newObj.pointee.Damage = 0.35 // more damage in 2P modes
    }

    // SET COLLISION

    newObj.pointee.CType = UInt32(CTYPE_HURTME)
    newObj.pointee.CBits = 0
    CreateCollisionBoxFromBoundingBox_Maximized(newObj, 1.0)

    // SET THE ALIGNMENT MATRIX

    SetAlignmentMatrix(&newObj.pointee.AlignmentMatrix, &aim)

    // PLAY SFX

    PlayEffect_Parms3D(Int16(EFFECT_STUNGUN), &where_, UInt32(NORMAL_CHANNEL_RATE), 0.7)
    PlayRumbleEffect(Int16(EFFECT_STUNGUN), Int32(player.pointee.PlayerNum))

    // MAKE SPARKLE FOR HEAD

    let i = GetFreeSparkle(newObj)
    sparklesBase(newObj)[0] = i
    if i != -1 {
        var sparkleOff = OGLPoint3D(x: 0, y: 0, z: -12)
        let sparkle = GetSparkleSlot(Int32(i))!

        sparkle.pointee.flags = UInt32(SPARKLE_FLAG_OMNIDIRECTIONAL | SPARKLE_FLAG_TRANSFORMWITHOWNER)
        sparkle.pointee.where = sparkleOff

        sparkle.pointee.color.r = 1
        sparkle.pointee.color.g = 1
        sparkle.pointee.color.b = 1
        sparkle.pointee.color.a = 1

        sparkle.pointee.scale = 100.0
        sparkle.pointee.separation = 10.0

        sparkle.pointee.textureNum = Int16(PARTICLE_SObjType_RedGlint)
        _ = sparkleOff
        sparkleOff = OGLPoint3D()
    }
}

// MARK: - Move blaster bullet

private let cMoveBlasterBullet: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
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

    if DoBlasterCollisionDetection(theNode) {
        return
    }

    theNode.update()
}

// MARK: - Do blaster collision detection

// Returns TRUE if blaster bullet was deleted.
@discardableResult
private func DoBlasterCollisionDetection(_ theNode: UnsafeMutablePointer<ObjNode>!) -> Bool {
    var hitPt = OGLPoint3D()
    var hitNormal = OGLVector3D()
    var hitObj: UnsafeMutablePointer<ObjNode>?

    // SEE IF LINE SEGMENT HITS ANY GEOMETRY

    // CREATE LINE SEGMENT TO DO COLLISION WITH

    var lineSegment = OGLLineSegment()
    lineSegment.p1 = theNode.pointee.OldCoord // from old coord

    lineSegment.p2.x = gCoord.x + theNode.pointee.MotionVector.x * 40.0 // to new coord (in front of center)
    lineSegment.p2.y = gCoord.y + theNode.pointee.MotionVector.y * 40.0
    lineSegment.p2.z = gCoord.z + theNode.pointee.MotionVector.z * 40.0

    var cType = UInt32(CTYPE_WEAPONTEST | CTYPE_FENCE | CTYPE_TERRAIN | CTYPE_WATER) // set CTYPE mask to find what we're looking for
    cType |= UInt32(CTYPE_PLAYER2) >> UInt32(theNode.pointee.PlayerNum) // also set to check hits on other player

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

        if cType == UInt32(CTYPE_WATER) {
            CreateMultipleNewRipples(hitPt.x, hitPt.z, 10.0, 40.0, 0.5, 3)
        }

        if cType == UInt32(CTYPE_TERRAIN) {
            DoBlasterImpactTerrainEffect(&hitPt, &hitNormal) // do special terrain impact
        } else {
            DoBlasterImpactObjectEffect(&hitPt, &hitNormal) // do special object impact
        }

        DeleteObject(theNode)
        return true
    }

    return false
}

// MARK: - Do blaster impact terrain effect

private func DoBlasterImpactTerrainEffect(_ impactPt: UnsafePointer<OGLPoint3D>!, _ surfaceNormal: UnsafePointer<OGLVector3D>!) {
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
            OGLMatrix4x4_SetRotate_XYZ(&m, 0, yrot, zrot)
            var v = OGLVector3D()
            OGLVector3D_Transform(surfaceNormal, &m, &v)

            let speed = 70.0 + RandomFloat() * 900.0
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

    PlayEffect_Parms3D(Int16(EFFECT_IMPACTSIZZLE), &gCoord, UInt32(NORMAL_CHANNEL_RATE), 0.8)
}

// MARK: - Do blaster impact object effect

private func DoBlasterImpactObjectEffect(_ impactPt: UnsafePointer<OGLPoint3D>!, _ surfaceNormal: UnsafePointer<OGLVector3D>!) {
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
            OGLMatrix4x4_SetRotate_XYZ(&m, 0, yrot, zrot)
            var v = OGLVector3D()
            OGLVector3D_Transform(surfaceNormal, &m, &v)

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

    PlayEffect_Parms3D(Int16(EFFECT_IMPACTSIZZLE), &gCoord, UInt32(NORMAL_CHANNEL_RATE), 0.8)
}

// MARK: - Shoot cluster shot

private func ShootClusterShot(_ player: UnsafeMutablePointer<ObjNode>!) {
    var where_ = OGLPoint3D()
    var aim = OGLVector3D()

    CalcPlayerGunMuzzleInfo(player, &where_, &aim)

    // CREATE BULLET OBJECT

    var def = NewObjectDefinitionType()
    def.group = UInt8(MODEL_GROUP_WEAPONS)
    def.type = UInt8(WEAPONS_ObjType_ClusterBullet)
    def.coord = where_
    def.flags = 0
    def.slot = 628
    def.moveCall = cMoveClusterBullet
    def.rot = RandomFloat() * SwPI2
    def.scale = 0.9

    let newObj = MakeNewDisplayGroupObject(&def)!

    newObj.pointee.Kind = Int32(WeaponType.clusterShot.rawValue)
    newObj.pointee.PlayerNum = player.pointee.PlayerNum // remember which player shot this

    newObj.pointee.Mode = clusterShotSingle
    newObj.pointee.Timer = 0.6

    newObj.pointee.Delta.x = aim.x * clusterBulletSpeed
    newObj.pointee.Delta.y = aim.y * clusterBulletSpeed
    newObj.pointee.Delta.z = aim.z * clusterBulletSpeed

    newObj.pointee.Health = 1.3 + RandomFloat() * 0.2
    newObj.pointee.Damage = 0.1 * Float(numShotsInCluster) // the single one has as much power as all of the clusters combined

    newObj.pointee.Rot.x = RandomFloat2() * SwPI2
    newObj.pointee.Rot.z = RandomFloat2() * SwPI2
    newObj.pointee.DeltaRot.x = RandomFloat2() * 10.0
    newObj.pointee.DeltaRot.y = RandomFloat2() * 20.0

    // SET COLLISION

    newObj.pointee.CType = UInt32(CTYPE_HURTME)
    newObj.pointee.CBits = 0
    CreateCollisionBoxFromBoundingBox_Maximized(newObj, 1.0)

    _ = AttachShadowToObject(newObj, .circular, 1, 1, 0)

    PlayEffect_Parms3D(Int16(EFFECT_FLARESHOOT), &where_, UInt32(NORMAL_CHANNEL_RATE), 0.7)
    PlayRumbleEffect(Int16(EFFECT_FLARESHOOT), Int32(player.pointee.PlayerNum))
}

// MARK: - Fragment cluster shot

// Breaks the single cluster shot into several fragments.
private func FragmentClusterShot(_ parentShot: UnsafeMutablePointer<ObjNode>!) {
    for _ in 0..<numShotsInCluster {
        // CREATE BULLET OBJECT

        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_WEAPONS)
        def.type = UInt8(WEAPONS_ObjType_ClusterBullet)
        def.coord = parentShot.pointee.Coord
        def.flags = 0
        def.slot = 628
        def.moveCall = cMoveClusterBullet
        def.rot = RandomFloat() * SwPI2
        def.scale = 0.9

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.Kind = Int32(WeaponType.clusterShot.rawValue)
        newObj.pointee.PlayerNum = parentShot.pointee.PlayerNum // remember which player shot this

        newObj.pointee.Mode = clusterShotFragment

        // CALC NEW VECTOR IN CONE OF AIM

        var aim = OGLVector3D()
        FastNormalizeVector(gDelta.x, gDelta.y, gDelta.z, &aim)

        let zrot = RandomFloat2() * 0.4
        let yrot = RandomFloat2() * 0.4
        var m = OGLMatrix4x4()
        OGLMatrix4x4_SetRotate_XYZ(&m, 0, yrot, zrot)
        var v = OGLVector3D()
        OGLVector3D_Transform(&aim, &m, &v)

        newObj.pointee.Delta.x = v.x * clusterBulletSpeed
        newObj.pointee.Delta.y = v.y * clusterBulletSpeed
        newObj.pointee.Delta.z = v.z * clusterBulletSpeed

        newObj.pointee.Health = 1.9 + RandomFloat() * 0.2
        newObj.pointee.Damage = 0.34

        newObj.pointee.Rot.x = RandomFloat2() * SwPI2
        newObj.pointee.Rot.z = RandomFloat2() * SwPI2
        newObj.pointee.DeltaRot.x = RandomFloat2() * 10.0
        newObj.pointee.DeltaRot.y = RandomFloat2() * 20.0

        // SET COLLISION

        newObj.pointee.CType = UInt32(CTYPE_HURTME)
        newObj.pointee.CBits = 0
        CreateCollisionBoxFromBoundingBox_Maximized(newObj, 1.0)

        _ = AttachShadowToObject(newObj, .circular, 1, 1, 0)
    }

    PlayEffect_Parms3D(Int16(EFFECT_FLARESHOOT), &parentShot.pointee.Coord, UInt32(NORMAL_CHANNEL_RATE) * 3 / 2, 0.7)
}

// MARK: - Move cluster bullet

private let cMoveClusterBullet: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }
    let fps = gFramesPerSecondFrac

    // SEE IF GONE

    theNode.pointee.Health -= fps
    if theNode.pointee.Health <= 0.0 {
        DeleteObject(theNode)
        return
    }

    theNode.getInfo()

    // SEE IF FRAGMENT

    if theNode.pointee.Mode == clusterShotSingle {
        theNode.pointee.Timer -= fps
        if theNode.pointee.Timer <= 0.0 {
            FragmentClusterShot(theNode)
            DeleteObject(theNode)
            return
        }
    }

    theNode.pointee.Rot.x += theNode.pointee.DeltaRot.x * fps
    theNode.pointee.Rot.y += theNode.pointee.DeltaRot.y * fps

    // MOVE IT

    gDelta.y -= 500.0 * fps // gravity

    gCoord.x += gDelta.x * fps
    gCoord.y += gDelta.y * fps
    gCoord.z += gDelta.z * fps

    // SEE IF HIT ANYTHING

    if DoBlasterCollisionDetection(theNode) {
        return
    }

    theNode.update()

    // UPDATE SPARKLE TRAIL

    theNode.pointee.ParticleTimer -= fps
    if theNode.pointee.ParticleTimer <= 0.0 {
        theNode.pointee.ParticleTimer += 0.02 // reset timer

        var particleGroup = theNode.pointee.ParticleGroup
        let magicNum = theNode.pointee.ParticleMagicNum

        if (particleGroup == -1) || (VerifyParticleGroupMagicNum(particleGroup, magicNum) == 0) {
            let newMagicNum = MyRandomLong()
            theNode.pointee.ParticleMagicNum = newMagicNum

            var groupDef = NewParticleGroupDefType()
            groupDef.magicNum = newMagicNum
            groupDef.type = UInt8(ParticleType.fallingSparks.rawValue)
            groupDef.flags = UInt32(PARTICLE_FLAGS_DONTCHECKGROUND | PARTICLE_FLAGS_ALLAIM)
            groupDef.gravity = 50
            groupDef.magnetism = 0
            groupDef.baseScale = 8
            groupDef.decayRate = 0
            groupDef.fadeRate = 0.5
            groupDef.particleTextureNum = UInt8(PARTICLE_SObjType_GreenFumes)
            groupDef.srcBlend = GL_SRC_ALPHA
            groupDef.dstBlend = GL_ONE
            particleGroup = NewParticleGroup(&groupDef)
            theNode.pointee.ParticleGroup = particleGroup
        }

        if particleGroup != -1 {
            for _ in 0..<2 {
                var d = OGLVector3D()
                d.x = (gDelta.x * 0.1) + RandomFloat2() * 20.0
                d.y = (gDelta.y * 0.1) + RandomFloat2() * 20.0
                d.z = (gDelta.z * 0.1) + RandomFloat2() * 20.0

                var newParticleDef = NewParticleDefType()
                newParticleDef.groupNum = particleGroup
                newParticleDef.scale = RandomFloat() + 1.0
                newParticleDef.rotZ = RandomFloat() * SwPI2
                newParticleDef.rotDZ = RandomFloat2() * 5.0
                newParticleDef.alpha = 0.5 + RandomFloat() * 0.2

                let stop: Bool = withUnsafeMutablePointer(to: &gCoord) { coordPtr in
                    withUnsafeMutablePointer(to: &d) { dPtr in
                        newParticleDef.where = coordPtr
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

// MARK: - Shoot heat seeker

private func ShootHeatSeeker(_ player: UnsafeMutablePointer<ObjNode>!) {
    var where_ = OGLPoint3D()
    var aim = OGLVector3D()
    let playerNum = player.pointee.PlayerNum

    CalcPlayerGunMuzzleInfo(player, &where_, &aim)

    // CREATE BULLET OBJECT

    var def = NewObjectDefinitionType()
    def.group = UInt8(MODEL_GROUP_WEAPONS)
    def.type = UInt8(WEAPONS_ObjType_HeatSeekerBullet)
    def.coord = where_
    def.flags = UInt32(STATUS_BIT_USEALIGNMENTMATRIX)
    def.slot = Int16(PLAYER_SLOT + 100)
    def.moveCall = cMoveHeatSeekerBullet
    def.rot = 0
    def.scale = 0.7

    let newObj = MakeNewDisplayGroupObject(&def)!

    newObj.pointee.Kind = Int32(WeaponType.heatSeeker.rawValue)
    newObj.pointee.PlayerNum = playerNum // remember which player shot this

    let speed = player.pointee.Speed + 300.0
    newObj.pointee.Speed = speed

    newObj.pointee.Delta.x = aim.x * speed
    newObj.pointee.Delta.y = aim.y * speed
    newObj.pointee.Delta.z = aim.z * speed

    newObj.pointee.MotionVector = aim

    newObj.pointee.Health = 4.0
    if gVSMode == .none {
        newObj.pointee.Damage = 0.8
    } else {
        newObj.pointee.Damage = 0.4 // less damage in 2P mode
    }

    // SET COLLISION

    newObj.pointee.CType = UInt32(CTYPE_HURTME)
    newObj.pointee.CBits = 0
    CreateCollisionBoxFromBoundingBox_Maximized(newObj, 1.0)

    // SET AUTO-TARGETING

    let pi = GetPlayerInfoEntry(Int32(playerNum))!
    let targetObj = pi.pointee.crosshairTargetObj // get object which crosshairs are targeting now
    if let targetObj {
        if pi.pointee.crosshairTargetCookie != targetObj.pointee.Cookie { // make sure cookie still matches
            newObj.pointee.Flag.0 = 0 // BulletTargetLocked
        } else {
            newObj.pointee.Flag.0 = 1 // BulletTargetLocked
            newObj.pointee.SpecialPtr.0 = UnsafeMutableRawPointer(targetObj) // BulletTargetObj
            newObj.pointee.Special.1 = Int(targetObj.pointee.Cookie) // BulletTargetCookie
        }
    } else {
        // NOTHING HAS BEEN AUTO-TARGETED
        newObj.pointee.Flag.0 = 0 // BulletTargetLocked
    }

    // SET THE ALIGNMENT MATRIX

    SetAlignmentMatrix(&newObj.pointee.AlignmentMatrix, &aim)

    _ = AttachShadowToObject(newObj, .circular, 2, 2, 0)

    // MAKE SPARKLE FOR FLAME

    let i = GetFreeSparkle(newObj)
    sparklesBase(newObj)[0] = i
    if i != -1 {
        var sparkleOff = OGLPoint3D(x: 0, y: 0, z: heatSeekerButtOff)
        let sparkle = GetSparkleSlot(Int32(i))!

        sparkle.pointee.flags = UInt32(SPARKLE_FLAG_OMNIDIRECTIONAL | SPARKLE_FLAG_FLICKER | SPARKLE_FLAG_TRANSFORMWITHOWNER)
        sparkle.pointee.where = sparkleOff

        sparkle.pointee.color.r = 1
        sparkle.pointee.color.g = 1
        sparkle.pointee.color.b = 1
        sparkle.pointee.color.a = 1

        sparkle.pointee.scale = 100.0
        sparkle.pointee.separation = 20.0

        sparkle.pointee.textureNum = Int16(PARTICLE_SObjType_WhiteSpark4)
        _ = sparkleOff
        sparkleOff = OGLPoint3D()
    }

    PlayEffect_Parms3D(Int16(EFFECT_LAUNCHMISSILE), &where_, UInt32(NORMAL_CHANNEL_RATE), 0.8)
    PlayRumbleEffect(Int16(EFFECT_LAUNCHMISSILE), Int32(playerNum))
}

// MARK: - Move heat seeker bullet

private let cMoveHeatSeekerBullet: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }
    let fps = gFramesPerSecondFrac

    // SEE IF GONE

    theNode.pointee.Health -= fps
    if theNode.pointee.Health <= 0.0 {
        DeleteObject(theNode)
        return
    }

    theNode.getInfo()

    // UPDATE AUTO-TARGETING

    // SEE IF NEED TO LOOK FOR TARGET

    if theNode.pointee.Flag.0 == 0 { // BulletTargetLocked
        FindBulletTarget(theNode)
    } else {
        // VERIFY EXISTING TARGET

        let target = theNode.pointee.SpecialPtr.0!.assumingMemoryBound(to: ObjNode.self) // BulletTargetObj

        if UInt32(theNode.pointee.Special.1) != target.pointee.Cookie { // verify that it's the same object
            theNode.pointee.Flag.0 = 0 // BulletTargetLocked
        } else {
            // UPDATE AIM TO TARGET

            var targetPt = OGLPoint3D()
            OGLPoint3D_Transform(&target.pointee.HeatSeekHotSpotOff, &target.pointee.BaseTransformMatrix, &targetPt) // calc coord of hotspot we're shooting for

            var v = OGLVector3D()
            OGLPoint3D_Subtract(&targetPt, &gCoord, &v) // calc vector from bullet to target
            FastNormalizeVector(v.x, v.y, v.z, &v)

            OGLVector3D_MoveToVector(&theNode.pointee.MotionVector, &v, &theNode.pointee.MotionVector, heatSeekerTurnSpeed * fps)
        }
    }

    // UPDATE DELTAS

    theNode.pointee.Speed += fps * 1000.0 // accelerate bullet
    if theNode.pointee.Speed > heatSeekerBulletMaxSpeed {
        theNode.pointee.Speed = heatSeekerBulletMaxSpeed
    }

    gDelta.x = theNode.pointee.MotionVector.x * theNode.pointee.Speed
    gDelta.y = theNode.pointee.MotionVector.y * theNode.pointee.Speed
    gDelta.z = theNode.pointee.MotionVector.z * theNode.pointee.Speed

    // MOVE IT

    gCoord.x += gDelta.x * fps
    gCoord.y += gDelta.y * fps
    gCoord.z += gDelta.z * fps

    // SEE IF HIT ANYTHING

    if DoHeatSeekerCollisionDetection(theNode) {
        return
    }

    // UPDATE

    SetAlignmentMatrix(&theNode.pointee.AlignmentMatrix, &theNode.pointee.MotionVector)

    theNode.update()

    // UPDATE SMOKE TRAIL

    theNode.pointee.ParticleTimer -= fps
    if theNode.pointee.ParticleTimer <= 0.0 {
        theNode.pointee.ParticleTimer += 0.015 // reset timer

        let buttOff = OGLPoint3D(x: 0, y: 0, z: heatSeekerButtOff)
        var buttPt = OGLPoint3D()
        withUnsafePointer(to: buttOff) { buttOffPtr in
            OGLPoint3D_Transform(buttOffPtr, &theNode.pointee.BaseTransformMatrix, &buttPt) // calc butt coord where smoke comes from
        }

        var particleGroup = theNode.pointee.ParticleGroup
        let magicNum = theNode.pointee.ParticleMagicNum

        if (particleGroup == -1) || (VerifyParticleGroupMagicNum(particleGroup, magicNum) == 0) {
            let newMagicNum = MyRandomLong()
            theNode.pointee.ParticleMagicNum = newMagicNum

            var groupDef = NewParticleGroupDefType()
            groupDef.magicNum = newMagicNum
            groupDef.type = UInt8(ParticleType.fallingSparks.rawValue)
            groupDef.flags = UInt32(PARTICLE_FLAGS_DONTCHECKGROUND | PARTICLE_FLAGS_ALLAIM)
            groupDef.gravity = 0
            groupDef.magnetism = 0
            groupDef.baseScale = 9
            groupDef.decayRate = -0.5
            groupDef.fadeRate = 0.3
            groupDef.particleTextureNum = UInt8(PARTICLE_SObjType_GreySmoke)
            groupDef.srcBlend = GL_SRC_ALPHA
            groupDef.dstBlend = GL_ONE_MINUS_SRC_ALPHA
            particleGroup = NewParticleGroup(&groupDef)
            theNode.pointee.ParticleGroup = particleGroup
        }

        if particleGroup != -1 {
            for _ in 0..<2 {
                var d = OGLVector3D()
                d.x = RandomFloat2() * 10.0
                d.y = RandomFloat2() * 10.0
                d.z = RandomFloat2() * 10.0

                var p = OGLPoint3D()
                p.x = buttPt.x + d.x * 0.6
                p.y = buttPt.y + d.y * 0.6
                p.z = buttPt.z + d.z * 0.6

                var newParticleDef = NewParticleDefType()
                newParticleDef.groupNum = particleGroup
                newParticleDef.scale = 1.0 + RandomFloat() * 0.5
                newParticleDef.rotZ = RandomFloat() * SwPI2
                newParticleDef.rotDZ = RandomFloat2() * 3.0
                newParticleDef.alpha = 0.4 + RandomFloat() * 0.1

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

    // UPDATE EFFECT

    if theNode.pointee.EffectChannel == -1 {
        theNode.pointee.EffectChannel = PlayEffect_Parms3D(Int16(EFFECT_MISSILEENGINE), &gCoord, UInt32(NORMAL_CHANNEL_RATE), 1.0)
    } else {
        Update3DSoundChannel(Int16(EFFECT_MISSILEENGINE), &theNode.pointee.EffectChannel, &gCoord)
    }
}

// MARK: - Find bullet target

private func FindBulletTarget(_ bullet: UnsafeMutablePointer<ObjNode>!) {
    var best: UnsafeMutablePointer<ObjNode>?
    var minDist: Float = 10_000_000
    let playerNum = bullet.pointee.PlayerNum // who shot this?

    var ctype = UInt32(CTYPE_AUTOTARGETWEAPON) // look for things that auto-target
    ctype |= UInt32(CTYPE_PLAYER2) >> UInt32(playerNum) // also target the other player

    var thisNodePtr = gFirstNodePtr

    while true {
        guard let thisNode = thisNodePtr else { break }

        if thisNode.pointee.Slot >= UInt16(SLOT_OF_DUMB) { // see if reach end of usable list
            break
        }

        if thisNode.pointee.CType & ctype != 0 {
            // IS THIS BEST DIST

            let d = OGLPoint3D_Distance(&gCoord, &thisNode.pointee.Coord)
            if d < minDist {
                // IS GOOD ANGLE

                var v = OGLVector3D()
                OGLPoint3D_Subtract(&thisNode.pointee.Coord, &gCoord, &v) // calc vector to target
                FastNormalizeVector(v.x, v.y, v.z, &v)

                let angle = acos(OGLVector3D_Dot(&v, &bullet.pointee.MotionVector)) // calc angle to target

                if angle < (Float.pi / 6) {
                    minDist = d
                    best = thisNode
                }
            }
        }
        thisNodePtr = thisNode.pointee.NextNode // next node
    }

    if let best {
        bullet.pointee.Flag.0 = 1 // BulletTargetLocked
        bullet.pointee.SpecialPtr.0 = UnsafeMutableRawPointer(best) // BulletTargetObj
        bullet.pointee.Special.1 = Int(best.pointee.Cookie) // BulletTargetCookie
    } else {
        bullet.pointee.Flag.0 = 0 // BulletTargetLocked
    }
}

// MARK: - Do heat seeker collision detection

// Returns TRUE if bullet was deleted.
@discardableResult
private func DoHeatSeekerCollisionDetection(_ theNode: UnsafeMutablePointer<ObjNode>!) -> Bool {
    var hitPt = OGLPoint3D()
    var hitNormal = OGLVector3D()
    var hitObj: UnsafeMutablePointer<ObjNode>?

    // SEE IF LINE SEGMENT HITS ANY GEOMETRY

    var d = OGLVector3D()
    FastNormalizeVector(gDelta.x, gDelta.y, gDelta.z, &d) // get normalized delta

    // CREATE LINE SEGMENT TO DO COLLISION WITH

    var lineSegment = OGLLineSegment()
    lineSegment.p1 = theNode.pointee.OldCoord // from old coord

    lineSegment.p2.x = gCoord.x + d.x * 50.0 // to new coord (slightly in front)
    lineSegment.p2.y = gCoord.y + d.y * 50.0
    lineSegment.p2.z = gCoord.z + d.z * 50.0

    var cType = UInt32(CTYPE_WEAPONTEST | CTYPE_FENCE | CTYPE_TERRAIN | CTYPE_WATER) // set CTYPE mask to find what we're looking for
    cType |= UInt32(CTYPE_PLAYER2) >> UInt32(theNode.pointee.PlayerNum) // also set to check hits on other player

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

        if cType == UInt32(CTYPE_WATER) {
            CreateMultipleNewRipples(hitPt.x, hitPt.z, 10.0, 40.0, 0.5, 3)
        }

        DoHeatSeekerImpactEffect(&hitPt)

        DeleteObject(theNode)

        return true
    }

    return false
}

// MARK: - Do heat seeker impact effect

private func DoHeatSeekerImpactEffect(_ where_: UnsafeMutablePointer<OGLPoint3D>!) {
    let x = where_.pointee.x
    let y = where_.pointee.y
    let z = where_.pointee.z

    // FIRST MAKE SPARKS

    gNewParticleGroupDef.magicNum = 0
    gNewParticleGroupDef.type = UInt8(ParticleType.fallingSparks.rawValue)
    gNewParticleGroupDef.flags = UInt32(PARTICLE_FLAGS_DONTCHECKGROUND)
    gNewParticleGroupDef.gravity = 1000
    gNewParticleGroupDef.magnetism = 0
    gNewParticleGroupDef.baseScale = 15
    gNewParticleGroupDef.decayRate = 0.8
    gNewParticleGroupDef.fadeRate = 0.8
    gNewParticleGroupDef.particleTextureNum = UInt8(PARTICLE_SObjType_RedSpark)
    gNewParticleGroupDef.srcBlend = GL_SRC_ALPHA
    gNewParticleGroupDef.dstBlend = GL_ONE
    var pg = NewParticleGroup(&gNewParticleGroupDef)
    if pg != -1 {
        for _ in 0..<50 {
            var pt = OGLPoint3D()
            pt.x = x + RandomFloat2() * 20.0
            pt.y = y + RandomFloat2() * 20.0
            pt.z = z + RandomFloat2() * 20.0

            var d = OGLVector3D()
            d.x = RandomFloat2() * 700.0
            d.y = RandomFloat2() * 700.0
            d.z = RandomFloat2() * 700.0

            var newParticleDef = NewParticleDefType()
            newParticleDef.groupNum = pg
            newParticleDef.scale = RandomFloat() + 1.0
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

    // MAKE FLAMES

    gNewParticleGroupDef.magicNum = 0
    gNewParticleGroupDef.type = UInt8(ParticleType.fallingSparks.rawValue)
    gNewParticleGroupDef.flags = UInt32(PARTICLE_FLAGS_DONTCHECKGROUND)
    gNewParticleGroupDef.gravity = 0
    gNewParticleGroupDef.magnetism = 0
    gNewParticleGroupDef.baseScale = 20
    gNewParticleGroupDef.decayRate = -7.0
    gNewParticleGroupDef.fadeRate = 1.0
    gNewParticleGroupDef.particleTextureNum = UInt8(PARTICLE_SObjType_Fire)
    gNewParticleGroupDef.srcBlend = GL_SRC_ALPHA
    gNewParticleGroupDef.dstBlend = GL_ONE
    pg = NewParticleGroup(&gNewParticleGroupDef)
    if pg != -1 {
        for _ in 0..<60 {
            var pt = OGLPoint3D()
            pt.x = x + RandomFloat2() * 20.0
            pt.y = y + RandomFloat2() * 20.0
            pt.z = z + RandomFloat2() * 20.0

            var d = OGLVector3D()
            d.y = RandomFloat2() * 270.0
            d.x = RandomFloat2() * 270.0
            d.z = RandomFloat2() * 270.0

            var newParticleDef = NewParticleDefType()
            newParticleDef.groupNum = pg
            newParticleDef.scale = RandomFloat() + 1.0
            newParticleDef.rotZ = RandomFloat() * SwPI2
            newParticleDef.rotDZ = RandomFloat2() * 6.0
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

    // MAKE SHOCKWAVE

    let sw = MakeBombShockwave(where_)!
    sw.pointee.ColorFilter.r = 0.3
    sw.pointee.ColorFilter.g = 0.3
    sw.pointee.ColorFilter.a = 0.6
    sw.pointee.StatusBits |= UInt32(STATUS_BIT_GLOW)

    PlayEffect_Parms3D(Int16(EFFECT_TURRETEXPLOSION), where_, UInt32(NORMAL_CHANNEL_RATE) * 3 / 2, 0.7)
}

// MARK: - Shoot sonic scream

private func ShootSonicScream(_ player: UnsafeMutablePointer<ObjNode>!) {
    var where_ = OGLPoint3D()
    let offPt = OGLPoint3D(x: 0, y: 0, z: -10)
    let p = player.pointee.PlayerNum

    // CALC MOUTH INFO

    withUnsafePointer(to: offPt) { offPtPtr in
        FindCoordOnJoint(player, Int(PlayerJoint.head.rawValue), offPtPtr, &where_)
    }
    let aim = player.pointee.MotionVector

    // CREATE BULLET OBJECT

    var def = NewObjectDefinitionType()
    def.genre = UInt8(EVENT_GENRE)
    def.slot = Int16(SLOT_OF_DUMB + 10)
    def.coord = where_
    def.moveCall = cMoveSonicScream
    def.flags = 0
    def.scale = 1

    let newObj = MakeNewObject(&def)!

    newObj.pointee.Kind = Int32(WeaponType.sonicScream.rawValue)
    newObj.pointee.PlayerNum = p // remember which player shot this

    newObj.pointee.BoundingSphereRadius = 100 // set the bounding sphere for fence collisions

    let pi = GetPlayerInfoEntry(Int32(p))!

    newObj.pointee.Delta.x = aim.x * sonicScreamSpeed
    newObj.pointee.Delta.y = aim.y * sonicScreamSpeed
    newObj.pointee.Delta.z = aim.z * sonicScreamSpeed

    newObj.pointee.Health = pi.pointee.weaponCharge + 0.5 // set life to charge
    newObj.pointee.Damage = pi.pointee.weaponCharge // set damage to weapon charge

    newObj.pointee.SpecialF.0 = 1.0 // SonicHeadScale

    // SET COLLISION
    //
    // Nothing collides against this, instead the bullet collides against stuff
    // during its move function.

    AddCollisionBoxToObject(newObj, 100, -100, -100, 100, 100, -100)

    PlayEffect_Parms3D(Int16(EFFECT_SONICSCREAM), &where_, UInt32(NORMAL_CHANNEL_RATE), 0.9)
}

// MARK: - Move sonic scream

private let cMoveSonicScream: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
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

    if DoSonicScreamCollisionDetection(theNode) {
        return
    }

    theNode.update()

    // UPDATE ECHO TRAIL

    theNode.pointee.ParticleTimer -= fps
    if theNode.pointee.ParticleTimer <= 0.0 {
        theNode.pointee.ParticleTimer += 0.09 // reset timer

        theNode.pointee.SpecialF.0 *= 1.1 // SonicHeadScale: scale up the head

        var particleGroup = theNode.pointee.ParticleGroup
        let magicNum = theNode.pointee.ParticleMagicNum

        if (particleGroup == -1) || (VerifyParticleGroupMagicNum(particleGroup, magicNum) == 0) {
            let newMagicNum = MyRandomLong()
            theNode.pointee.ParticleMagicNum = newMagicNum

            var groupDef = NewParticleGroupDefType()
            groupDef.magicNum = newMagicNum
            groupDef.type = UInt8(ParticleType.fallingSparks.rawValue)
            groupDef.flags = UInt32(PARTICLE_FLAGS_DONTCHECKGROUND | PARTICLE_FLAGS_ALLAIM)
            groupDef.gravity = 50
            groupDef.magnetism = 0
            groupDef.baseScale = 15
            groupDef.decayRate = -theNode.pointee.SpecialF.0 * 10.0
            groupDef.fadeRate = 0.9
            groupDef.particleTextureNum = UInt8(PARTICLE_SObjType_Bubble)
            groupDef.srcBlend = GL_SRC_ALPHA
            groupDef.dstBlend = GL_ONE_MINUS_SRC_ALPHA // GL_ONE
            particleGroup = NewParticleGroup(&groupDef)
            theNode.pointee.ParticleGroup = particleGroup
        }

        if particleGroup != -1 {
            var d = OGLVector3D()
            d.x = gDelta.x * 0.25
            d.y = gDelta.y * 0.25
            d.z = gDelta.z * 0.25

            var newParticleDef = NewParticleDefType()
            newParticleDef.groupNum = particleGroup
            newParticleDef.scale = theNode.pointee.SpecialF.0
            newParticleDef.rotZ = 0 // RandomFloat() * SwPI2
            newParticleDef.rotDZ = 0.1 // theNode.pointee.SpecialF.0 * 6.0
            newParticleDef.alpha = 1

            let stop: Bool = withUnsafeMutablePointer(to: &gCoord) { coordPtr in
                withUnsafeMutablePointer(to: &d) { dPtr in
                    newParticleDef.where = coordPtr
                    newParticleDef.delta = dPtr
                    return AddParticleToGroup(&newParticleDef) != 0
                }
            }
            if stop {
                theNode.pointee.ParticleGroup = -1
            }
        }

        // FORCE FEEDBACK

        Rumble(0, 1, 25, Int32(theNode.pointee.PlayerNum))
    }
}

// MARK: - Do sonic scream collision detection

// Returns true if impacted anything and was deleted.
@discardableResult
private func DoSonicScreamCollisionDetection(_ bullet: UnsafeMutablePointer<ObjNode>!) -> Bool {
    // SEE IF HIT ANY OBJNODES

    // WHAT DO WE WANT TO HIT?

    var ctype = UInt32(CTYPE_MISC | CTYPE_ENEMY | CTYPE_WEAPONTEST)
    ctype |= UInt32(CTYPE_PLAYER2) >> UInt32(bullet.pointee.PlayerNum)

    // DOES THIS TOUCH ANYTHING?

    let box = bullet.pointee.CollisionBoxes.0
    let numHits = DoSimpleBoxCollision(box.top, box.bottom, box.left, box.right, box.front, box.back, ctype)

    func killBullet() -> Bool {
        DeleteObject(bullet)
        return true
    }

    if numHits > 0 {
        // WE HIT SOMETHING

        for i in 0..<Int(numHits) {
            if let hitObj = GetCollisionListEntry(Int32(i))!.pointee.objectPtr {
                if let handler = hitObj.pointee.HitByWeaponHandler { // see if there is a handler for this object
                    _ = handler(bullet, hitObj, nil, nil) // call the handler
                }
            }
        }

        // DELETE THE BULLET
        return killBullet()
    }

    // SEE IF HIT TERRAIN

    if gCoord.y < GetTerrainY(gCoord.x, gCoord.z) {
        return killBullet()
    }

    // SEE IF HIT FENCE

    if DoFenceCollision(bullet) != 0 {
        return killBullet()
    }

    return false
}

// MARK: - Shoot bomb

private func ShootBomb(_ player: UnsafeMutablePointer<ObjNode>!) {
    var where_ = OGLPoint3D()
    var aim = OGLVector3D()
    let playerNum = player.pointee.PlayerNum

    CalcPlayerGunMuzzleInfo(player, &where_, &aim)

    // CREATE BOMB OBJECT

    var def = NewObjectDefinitionType()
    def.group = UInt8(MODEL_GROUP_WEAPONS)
    def.type = UInt8(WEAPONS_ObjType_Bomb)
    def.coord = where_
    def.flags = 0
    def.slot = Int16(PLAYER_SLOT + 100)
    def.moveCall = cMovePlayerBomb
    def.rot = player.pointee.Rot.y
    def.scale = 0.3

    let newObj = MakeNewDisplayGroupObject(&def)!

    newObj.pointee.Kind = Int32(WeaponType.bomb.rawValue)
    newObj.pointee.PlayerNum = playerNum // remember which player shot this

    newObj.pointee.Rot.x = player.pointee.Rot.x
    newObj.updateTransforms()

    let speed = player.pointee.Speed + 200.0

    newObj.pointee.Delta.x = aim.x * speed
    newObj.pointee.Delta.y = aim.y * speed
    newObj.pointee.Delta.z = aim.z * speed

    newObj.pointee.Damage = 1.0

    // SET COLLISION

    newObj.pointee.CType = UInt32(CTYPE_HURTME)
    newObj.pointee.CBits = 0
    CreateCollisionBoxFromBoundingBox_Maximized(newObj, 1.0)

    _ = AttachShadowToObject(newObj, .circular, 2, 2, 0)

    PlayEffect_Parms3D(Int16(EFFECT_BOMBDROP), &where_, UInt32(NORMAL_CHANNEL_RATE), 0.8)
    PlayRumbleEffect(Int16(EFFECT_BOMBDROP), Int32(playerNum))
}

// MARK: - Move player bomb

private let cMovePlayerBomb: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }
    let fps = gFramesPerSecondFrac

    theNode.getInfo()

    // MOVE IT

    gDelta.y -= 800.0 * fps // gravity

    ApplyFrictionToDeltasXZ(500, &gDelta) // air friction

    gCoord.x += gDelta.x * fps
    gCoord.y += gDelta.y * fps
    gCoord.z += gDelta.z * fps

    theNode.pointee.Rot.x -= fps * 1.1 // tilt down
    if theNode.pointee.Rot.x < (-Float.pi / 2) {
        theNode.pointee.Rot.x = -Float.pi / 2
    }

    // SEE IF HIT ANYTHING

    if DoBombCollisionDetection(theNode) {
        return
    }

    // UPDATE

    theNode.update()

    LeaveBombTrail(theNode)
}

// MARK: - Leave bomb trail

private func LeaveBombTrail(_ theNode: UnsafeMutablePointer<ObjNode>!) {
    let fps = gFramesPerSecondFrac

    theNode.pointee.ParticleTimer -= fps // see if add smoke
    if theNode.pointee.ParticleTimer <= 0.0 {
        theNode.pointee.ParticleTimer += 0.03 // reset timer

        var particleGroup = theNode.pointee.ParticleGroup
        let magicNum = theNode.pointee.ParticleMagicNum

        if (particleGroup == -1) || (VerifyParticleGroupMagicNum(particleGroup, magicNum) == 0) {
            let newMagicNum = MyRandomLong()
            theNode.pointee.ParticleMagicNum = newMagicNum

            var groupDef = NewParticleGroupDefType()
            groupDef.magicNum = newMagicNum
            groupDef.type = UInt8(ParticleType.fallingSparks.rawValue)
            groupDef.flags = UInt32(PARTICLE_FLAGS_DONTCHECKGROUND | PARTICLE_FLAGS_ALLAIM)
            groupDef.gravity = 0
            groupDef.magnetism = 0
            groupDef.baseScale = 10.0
            groupDef.decayRate = 1.0
            groupDef.fadeRate = 1.0
            groupDef.particleTextureNum = UInt8(PARTICLE_SObjType_WhiteSpark)
            groupDef.srcBlend = GL_SRC_ALPHA
            groupDef.dstBlend = GL_ONE
            particleGroup = NewParticleGroup(&groupDef)
            theNode.pointee.ParticleGroup = particleGroup
        }

        if particleGroup != -1 {
            let x = gCoord.x
            let y = gCoord.y
            let z = gCoord.z

            for _ in 0..<2 {
                var p = OGLPoint3D()
                p.x = x + RandomFloat2() * 5.0
                p.y = y + RandomFloat2() * 5.0
                p.z = z + RandomFloat2() * 5.0

                var d = OGLVector3D()
                d.x = RandomFloat2() * 20.0
                d.y = RandomFloat2() * 20.0
                d.z = RandomFloat2() * 20.0

                var newParticleDef = NewParticleDefType()
                newParticleDef.groupNum = particleGroup
                newParticleDef.scale = 1.0
                newParticleDef.rotZ = 0
                newParticleDef.rotDZ = 0
                newParticleDef.alpha = 0.7

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

// MARK: - Do bomb collision detection

// Returns TRUE if bomb bullet was deleted.
@discardableResult
private func DoBombCollisionDetection(_ theNode: UnsafeMutablePointer<ObjNode>!) -> Bool {
    var hitPt = OGLPoint3D()
    var hitNormal = OGLVector3D()
    var hitObj: UnsafeMutablePointer<ObjNode>?

    // SEE IF LINE SEGMENT HITS ANY GEOMETRY

    var d = OGLVector3D()
    FastNormalizeVector(gDelta.x, gDelta.y, gDelta.z, &d) // get normalized delta

    // CREATE LINE SEGMENT TO DO COLLISION WITH

    var lineSegment = OGLLineSegment()
    lineSegment.p1 = theNode.pointee.OldCoord // from old coord

    lineSegment.p2.x = gCoord.x + d.x * 40.0 // to new coord (slightly in front)
    lineSegment.p2.y = gCoord.y + d.y * 40.0
    lineSegment.p2.z = gCoord.z + d.z * 40.0

    var cType = UInt32(CTYPE_WEAPONTEST | CTYPE_FENCE | CTYPE_TERRAIN | CTYPE_WATER) // set CTYPE mask to find what we're looking for
    cType |= UInt32(CTYPE_PLAYER2) >> UInt32(theNode.pointee.PlayerNum) // also set to check hits on other player

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

        if cType == UInt32(CTYPE_WATER) {
            CreateMultipleNewRipples(hitPt.x, hitPt.z, 10.0, 40.0, 0.5, 3)
        }

        DoBombImpactEffect(&hitPt)

        DeleteObject(theNode)

        return true
    }

    return false
}

// MARK: - Do bomb impact effect

private func DoBombImpactEffect(_ where_: UnsafeMutablePointer<OGLPoint3D>!) {
    let x = where_.pointee.x
    let y = where_.pointee.y
    let z = where_.pointee.z

    // FIRST MAKE SPARKS

    gNewParticleGroupDef.magicNum = 0
    gNewParticleGroupDef.type = UInt8(ParticleType.fallingSparks.rawValue)
    gNewParticleGroupDef.flags = UInt32(PARTICLE_FLAGS_ALLAIM | PARTICLE_FLAGS_DONTCHECKGROUND)
    gNewParticleGroupDef.gravity = 1200
    gNewParticleGroupDef.magnetism = 0
    gNewParticleGroupDef.baseScale = 10
    gNewParticleGroupDef.decayRate = 0.8
    gNewParticleGroupDef.fadeRate = 1.2
    gNewParticleGroupDef.particleTextureNum = UInt8(PARTICLE_SObjType_YellowGlint)
    gNewParticleGroupDef.srcBlend = GL_SRC_ALPHA
    gNewParticleGroupDef.dstBlend = GL_ONE
    var pg = NewParticleGroup(&gNewParticleGroupDef)
    if pg != -1 {
        for _ in 0..<30 {
            var pt = OGLPoint3D()
            pt.x = x + RandomFloat2() * 20.0
            pt.y = y + RandomFloat() * 20.0
            pt.z = z + RandomFloat2() * 20.0

            var d = OGLVector3D()
            d.x = RandomFloat2() * 700.0
            d.y = RandomFloat() * 900.0
            d.z = RandomFloat2() * 700.0

            var newParticleDef = NewParticleDefType()
            newParticleDef.groupNum = pg
            newParticleDef.scale = RandomFloat() + 1.0
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

    // MAKE FLAMES

    gNewParticleGroupDef.magicNum = 0
    gNewParticleGroupDef.type = UInt8(ParticleType.fallingSparks.rawValue)
    gNewParticleGroupDef.flags = UInt32(PARTICLE_FLAGS_ALLAIM | PARTICLE_FLAGS_DONTCHECKGROUND)
    gNewParticleGroupDef.gravity = 0
    gNewParticleGroupDef.magnetism = 0
    gNewParticleGroupDef.baseScale = 20
    gNewParticleGroupDef.decayRate = -7.0
    gNewParticleGroupDef.fadeRate = 1.0
    gNewParticleGroupDef.particleTextureNum = UInt8(PARTICLE_SObjType_Fire)
    gNewParticleGroupDef.srcBlend = GL_SRC_ALPHA
    gNewParticleGroupDef.dstBlend = GL_ONE
    pg = NewParticleGroup(&gNewParticleGroupDef)
    if pg != -1 {
        for _ in 0..<70 {
            var pt = OGLPoint3D()
            pt.x = x + RandomFloat2() * 20.0
            pt.y = y + RandomFloat() * 20.0
            pt.z = z + RandomFloat2() * 20.0

            var d = OGLVector3D()
            d.y = RandomFloat2() * 100.0
            d.x = RandomFloat2() * 270.0
            d.z = RandomFloat2() * 270.0

            var newParticleDef = NewParticleDefType()
            newParticleDef.groupNum = pg
            newParticleDef.scale = RandomFloat() + 1.0
            newParticleDef.rotZ = RandomFloat() * SwPI2
            newParticleDef.rotDZ = RandomFloat2() * 7.0
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

    // MAKE SHOCKWAVE

    _ = MakeBombShockwave(where_)

    PlayEffect_Parms3D(Int16(EFFECT_TURRETEXPLOSION), where_, UInt32(NORMAL_CHANNEL_RATE) * 3 / 2, 0.7)
}

// MARK: - Make bomb shockwave

private func MakeBombShockwave(_ where_: UnsafePointer<OGLPoint3D>!) -> UnsafeMutablePointer<ObjNode>? {
    var def = NewObjectDefinitionType()
    def.group = UInt8(MODEL_GROUP_WEAPONS)
    def.type = UInt8(WEAPONS_ObjType_BombShockwave)
    def.coord = where_.pointee
    def.flags = UInt32(STATUS_BIT_NOZWRITES | STATUS_BIT_NOFOG | STATUS_BIT_NOLIGHTING)
    def.slot = Int16(SLOT_OF_DUMB + 40)
    def.moveCall = cMoveBombShockwave
    def.rot = 0
    def.scale = 1.0

    let newObj = MakeNewDisplayGroupObject(&def)!
    newObj.pointee.ColorFilter.a = 0.8
    newObj.pointee.Damage = 1.0
    return newObj
}

// MARK: - Move bomb shockwave

private let cMoveBombShockwave: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }
    let fps = gFramesPerSecondFrac

    // FADE

    theNode.pointee.ColorFilter.a -= fps * 2.0
    if theNode.pointee.ColorFilter.a <= 0.0 {
        DeleteObject(theNode)
        return
    }

    theNode.pointee.Scale.z += fps * 140.0
    theNode.pointee.Scale.x = theNode.pointee.Scale.z
    theNode.pointee.Scale.y = theNode.pointee.Scale.z

    theNode.updateTransforms()

    CauseBombShockwaveDamage(theNode, UInt32(CTYPE_ENEMY | CTYPE_PLAYER1 | CTYPE_PLAYER2 | CTYPE_WEAPONTEST))
}

// MARK: - Cause bomb shockwave damage

@c @implementation
public func CauseBombShockwaveDamage(_ wave: UnsafeMutablePointer<ObjNode>!, _ ctype: UInt32) {
    let radius = wave.pointee.Scale.x * 10.0 // calc radius of sphere

    let oldDamage = wave.pointee.Damage // remember original damager factor
    wave.pointee.Damage *= gFramesPerSecondFrac // set temporary damage

    let x = wave.pointee.Coord.x
    let y = wave.pointee.Coord.y
    let z = wave.pointee.Coord.z

    // SCAN THRU NODES FOR TARGETS

    var thisNodePtr = gFirstNodePtr
    while true {
        guard let thisNode = thisNodePtr else { break }

        if thisNode.pointee.Slot >= UInt16(SLOT_OF_DUMB) { // see if reach end of usable list
            break
        }

        if thisNode.pointee.CType & ctype != 0 { // is this something we'd care about?
            // SEE IF OBJECT IS INSIDE SHOCKWAVE RADIUS

            let d = CalcDistance3D(x, y, z, thisNode.pointee.Coord.x, thisNode.pointee.Coord.y, thisNode.pointee.Coord.z)
            if d < radius {
                if let handler = thisNode.pointee.HitByWeaponHandler {
                    _ = handler(wave, thisNode, nil, nil)
                }
            }
        }
        thisNodePtr = thisNode.pointee.NextNode // next node
    }

    wave.pointee.Damage = oldDamage
}

// MARK: - Calc player gun muzzle info

private func CalcPlayerGunMuzzleInfo(_ player: UnsafeMutablePointer<ObjNode>!, _ muzzleCoord: UnsafeMutablePointer<OGLPoint3D>!, _ muzzleVector: UnsafeMutablePointer<OGLVector3D>!) {
    let muzzleTipOff_Left = OGLPoint3D(x: -15, y: 14, z: -17) // offsets from armpit joints to the gun muzzles
    let muzzleTipOff_Right = OGLPoint3D(x: 15, y: 14, z: -17)

    let p = Int32(player.pointee.PlayerNum)
    let pi = GetPlayerInfoEntry(p)!
    pi.pointee.turretSide ^= 1 // toggle turret side

    // LEFT

    if pi.pointee.turretSide != 0 {
        withUnsafePointer(to: muzzleTipOff_Left) { OGLPoint3D_Transform($0, &player.pointee.BaseTransformMatrix, muzzleCoord) }
        OGLVector3D_Transform(&gPlayerMuzzleTipAim, &player.pointee.BaseTransformMatrix, muzzleVector)
    }

    // RIGHT

    else {
        withUnsafePointer(to: muzzleTipOff_Right) { OGLPoint3D_Transform($0, &player.pointee.BaseTransformMatrix, muzzleCoord) }
        OGLVector3D_Transform(&gPlayerMuzzleTipAim, &player.pointee.BaseTransformMatrix, muzzleVector)
    }

    // MAKE THIS MUZZLE'S SPARKLE GLOW BRIGHTER

    if let jetpack = player.pointee.ChainNode {
        let i = sparklesBase(jetpack)[Int(pi.pointee.turretSide)]
        if i != -1 {
            let sparkle = GetSparkleSlot(Int32(i))!
            sparkle.pointee.color.a = 1.0
            sparkle.pointee.scale = 50
        }
    }
}
