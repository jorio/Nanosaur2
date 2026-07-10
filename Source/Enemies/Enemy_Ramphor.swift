// Enemy_Ramphor.swift - Port of Enemy_Ramphor.c to Swift

private let ramphorScale: Float = 2.2

private let ramphorWobbleDiff: Float = 270.0

private let blockDist: Float = 1000.0

private let ramphorHealth: Float = 0.8
private let ramphorDamage: Float = 0.4

// MARK: - Anims

private let ramphorAnimFlap = 0
private let ramphorAnimCoast = 1
private let ramphorAnimDisoriented = 2
private let ramphorAnimDeath = 3
private let ramphorAnimBlock = 4

private let ramphorJointnumButt = 3
private let ramphorJointnumTailtip = 31

func PrimeEnemy_Ramphor(_ splineNum: Int, _ itemPtr: UnsafeMutablePointer<SplineItemType>!) -> UInt8 {
    let height = Int32(itemPtr.pointee.parm.0)
    let speed = Int32(itemPtr.pointee.parm.1)

    // GET SPLINE INFO

    let placement = itemPtr.pointee.placement
    var x: Float = 0
    var z: Float = 0
    GetCoordOnSpline(gSplineList + splineNum, placement, &x, &z)

    // MAKE RAMPHOR

    let newObj = makeRamphor(x, z, Int16(ramphorAnimFlap), height)!

    // SET SPLINE INFO

    newObj.pointee.SpecialF.2 = 180 + Float(speed) * 30 // SplineSpeed

    newObj.setStatus(STATUS_BIT_ONSPLINE)
    newObj.pointee.SplineItemPtr = itemPtr
    newObj.pointee.SplineNum = UInt8(splineNum)
    newObj.pointee.SplinePlacement = placement
    newObj.pointee.SplineMoveCall = cMoveRamphorOnSpline // set move call

    newObj.pointee.Coord.y -= newObj.pointee.BottomOff

    // ADD SPLINE OBJECT TO SPLINE OBJECT LIST

    DetachObject(newObj, 1) // detach this object from the linked list
    AddToSplineObjectList(newObj, 1)

    return 1
}

private func makeRamphor(_ x: Float, _ z: Float, _ animNum: Int16, _ height: Int32) -> UnsafeMutablePointer<ObjNode>? {
    // MAKE SKELETON ENEMY

    let newObj = MakeEnemySkeleton(UInt8(SkeletonType.ramphor.rawValue), animNum, x, z, ramphorScale, 0, nil)!

    newObj.pointee.SpecialF.0 = RandomFloat() * SwPI2 // Wobble
    newObj.pointee.SpecialF.1 = GetTerrainY(x, z) + (ramphorWobbleDiff + 150.0) + (Float(height) * 190.0) // FlightHeight

    // SET BETTER INFO

    let skeleton = newObj.pointee.Skeleton!
    skeleton.pointee.CurrentAnimTime = skeleton.pointee.MaxAnimTime * RandomFloat() // set random time index so all of these are not in sync

    newObj.pointee.Health = ramphorHealth
    if gGamePrefs.isKiddieMode { // no damage in kiddie mode
        newObj.pointee.Damage = 0
    } else {
        newObj.pointee.Damage = ramphorDamage
    }
    newObj.pointee.Kind = Int32(EnemyKind.ramphor.rawValue)

    // SET HOT-SPOT FOR AUTO TARGETING WEAPONS

    newObj.pointee.HeatSeekHotSpotOff.x = 0
    newObj.pointee.HeatSeekHotSpotOff.y = 0
    newObj.pointee.HeatSeekHotSpotOff.z = 0

    // MAKE SHADOW

    _ = AttachShadowToObject(newObj, .circular, 6, 10, 0)

    // SET COLLISION STUFF

    CreateCollisionBoxFromBoundingBox(newObj, 0.8, 0.9)
    newObj.pointee.LeftOff = newObj.pointee.BackOff
    newObj.pointee.RightOff = -newObj.pointee.LeftOff

    newObj.pointee.HitByWeaponHandler = cRamphorHitByWeaponCallback
    newObj.pointee.TriggerCallback = cDoTrigRamphor

    return newObj
}

private let cMoveRamphorOnSpline: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }

    let isInRange = IsSplineItemOnActiveTerrain(theNode) // update its visibility

    // MOVE ALONG THE SPLINE

    _ = IncreaseSplineIndex(theNode, 250)
    GetObjectCoordOnSpline(theNode)

    // UPDATE STUFF IF IN RANGE

    if isInRange != 0 {
        let fps = gFramesPerSecondFrac

        // DO Y CALC

        theNode.pointee.SpecialF.0 += fps * 1.3 // wobble height
        if theNode.pointee.SpecialF.0 > SwPI2 {
            theNode.pointee.SpecialF.0 -= SwPI2
        }
        theNode.pointee.Coord.y = theNode.pointee.SpecialF.1 + cos(theNode.pointee.SpecialF.0) * ramphorWobbleDiff // calc y coord

        // SEE IF CHANGE ANIMS

        let skeleton = theNode.pointee.Skeleton!

        if skeleton.pointee.AnimNum == UInt8(ramphorAnimDisoriented) { // see if done with disorientation
            if skeleton.animHasStopped {
                MorphToSkeletonAnim(skeleton, ramphorAnimCoast, 3)
            }
        }

        // SEE IF BLOCK

        else {
            var playerNum: Int16 = 0
            if CalcDistanceToClosestPlayer(&theNode.pointee.Coord, &playerNum) < blockDist {
                if skeleton.pointee.AnimNum != UInt8(ramphorAnimBlock) {
                    MorphToSkeletonAnim(skeleton, ramphorAnimBlock, 2.0)
                }
            }

            // FLIGHT ANIM

            else {
                if theNode.pointee.SpecialF.0 < Float.pi { // coast when going down the curve
                    if skeleton.pointee.AnimNum != UInt8(ramphorAnimCoast) {
                        MorphToSkeletonAnim(skeleton, ramphorAnimCoast, 4.0)
                    }
                } else { // flap when going up
                    if skeleton.pointee.AnimNum != UInt8(ramphorAnimFlap) {
                        MorphToSkeletonAnim(skeleton, ramphorAnimFlap, 4.0)
                    }
                }
            }
        }

        // DO SPECIAL CHECK TO SEE IF HIT PLAYER

        if checkIfRamphorHitPlayer(theNode) {
            return
        }

        // AIM ALONG SPLINE

        var m = OGLMatrix4x4()
        var sm = OGLMatrix4x4()
        var up = gUp
        SetLookAtMatrixAndTranslate(&m, &up, &theNode.pointee.OldCoord, &theNode.pointee.Coord)
        sm.setScale(ramphorScale, ramphorScale, ramphorScale)
        theNode.pointee.BaseTransformMatrix = sm.multiplied(by: m)

        SetObjectTransformMatrix(theNode) // update transforms
        UpdateShadow(theNode)
        CalcObjectBoxFromNode(theNode)
    }
}

// MARK: - Move Ramphor: Death

private let cMoveRamphorDeath: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }
    let fps = gFramesPerSecondFrac

    GetObjectInfo(theNode)

    // MOVE

    gDelta.y -= 4000.0 * fps // add gravity
    gCoord.x += gDelta.x * fps
    gCoord.y += gDelta.y * fps
    gCoord.z += gDelta.z * fps

    theNode.pointee.Rot.z -= fps * SwPI2

    // SEE IF HIT GROUND

    if gCoord.y <= GetTerrainY(gCoord.x, gCoord.z) {
        explodeRamphor(theNode)
        return
    }

    // UPDATE

    updateRamphor(theNode)
}

private func updateRamphor(_ theNode: UnsafeMutablePointer<ObjNode>) {
    theNode.update()
}

// MARK: - Ramphor Hit By Weapon Callback

// Returns true if object should stop bullet.
private let cRamphorHitByWeaponCallback: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<OGLPoint3D>?, UnsafeMutablePointer<OGLVector3D>?) -> UInt8 = { bullet, enemyOpt, _, _ in
    let enemy = enemyOpt!

    enemy.pointee.Health -= bullet!.pointee.Damage

    // SEE IF KILLED

    if enemy.pointee.Health <= 0.0 {
        killRamphor(enemy)
    }

    // JUST HURT

    else {
        disorientRamphor(enemy)
    }

    return 1
}

private func killRamphor(_ enemy: UnsafeMutablePointer<ObjNode>) {
    // SEE IF REMOVE FROM SPLINE

    if enemy.hasStatus(STATUS_BIT_ONSPLINE) {
        DetachEnemyFromSpline(enemy, cMoveRamphorDeath)
    }

    enemy.pointee.HitByWeaponHandler = nil

    MorphToSkeletonAnim(enemy.pointee.Skeleton, ramphorAnimDeath, 2.0)

    enemy.pointee.TerrainItemPtr = nil // dont ever come back
    enemy.pointee.CType &= ~UInt32(CTYPE_AUTOTARGETWEAPON)
}

// Returns TRUE if want to handle hit as a solid
private let cDoTrigRamphor: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?) -> UInt8 = { enemyOpt, playerOpt in
    let enemy = enemyOpt!
    let player = playerOpt!
    let playerNum = player.pointee.PlayerNum
    let playerInfo = GetPlayerInfoEntry(Int32(playerNum))

    if playerInfo.pointee.invincibilityTimer <= 0.0 {
        // DOES PLAYER HAVE SHIELD?

        if playerInfo.pointee.shieldPower > 0.0 {
            HitPlayerShield(Int16(playerNum), MAX_SHIELD_POWER * enemy.pointee.Damage, 2.0, 1)
        }

        // NO SHIELD, SO HURT PLAYER

        else if !gGamePrefs.isKiddieMode { // don't hurt in kiddie mode
            _ = PlayerLoseHealth(Int16(playerNum), enemy.pointee.Damage, .deathDive, &gCoord, 1)
        }

        playerInfo.pointee.invincibilityTimer = 1.0

        // PLAYER ALWAYS DROPS EGG ON IMPACT

        DropEgg_NoWormhole(Int16(playerNum))

        // PLAY BODYHIT EFFECT

        PlayEffect_Parms3D(Int16(EFFECT_BODYHIT), &gCoord, UInt32(NORMAL_CHANNEL_RATE), 1.1)
        PlayRumbleEffect(Int16(EFFECT_BODYHIT), Int32(playerNum))
    }

    // HURT THE RAMPHOR

    _ = hurtRamphor(enemy, 0.5)

    return 0
}

// Returns true if raptor killed
private func hurtRamphor(_ enemy: UnsafeMutablePointer<ObjNode>, _ damage: Float) -> Bool {
    enemy.pointee.Health -= damage
    if enemy.pointee.Health <= 0.0 {
        killRamphor(enemy)
        return true
    } else {
        disorientRamphor(enemy)
    }

    return false
}

private func disorientRamphor(_ enemy: UnsafeMutablePointer<ObjNode>) {
    // SET ANIM & TIMER

    MorphToSkeletonAnim(enemy.pointee.Skeleton, ramphorAnimDisoriented, 2.0)
}

private func explodeRamphor(_ theNode: UnsafeMutablePointer<ObjNode>) {
    let x = theNode.pointee.Coord.x
    let y = theNode.pointee.Coord.y
    let z = theNode.pointee.Coord.z

    gNewParticleGroupDef.magicNum = 0
    gNewParticleGroupDef.particleType = .fallingSparks
    gNewParticleGroupDef.flags = 0
    gNewParticleGroupDef.gravity = 300
    gNewParticleGroupDef.magnetism = 0
    gNewParticleGroupDef.baseScale = 25
    gNewParticleGroupDef.decayRate = -1.0
    gNewParticleGroupDef.fadeRate = 0.8
    gNewParticleGroupDef.particleTextureNum = UInt8(PARTICLE_SObjType_CokeSpray)
    gNewParticleGroupDef.srcBlend = Int32(GL_SRC_ALPHA)
    gNewParticleGroupDef.dstBlend = Int32(GL_ONE_MINUS_SRC_ALPHA)
    let pg = NewParticleGroup(&gNewParticleGroupDef)
    if pg != -1 {
        for _ in 0..<100 {
            var d = OGLVector3D()
            d.y = RandomFloat() * 400.0
            d.x = RandomFloat2() * 200.0
            d.z = RandomFloat2() * 200.0

            var pt = OGLPoint3D()
            pt.x = x + d.x * 0.27
            pt.y = y
            pt.z = z + d.z * 0.27

            withUnsafeMutablePointer(to: &pt) { ptPtr in
                withUnsafeMutablePointer(to: &d) { dPtr in
                    var newParticleDef = NewParticleDefType()
                    newParticleDef.groupNum = pg
                    newParticleDef.`where` = ptPtr
                    newParticleDef.delta = dPtr
                    newParticleDef.scale = RandomFloat() + 1.0
                    newParticleDef.rotZ = RandomFloat() * SwPI2
                    newParticleDef.rotDZ = RandomFloat2() * 10.0
                    newParticleDef.alpha = 1.0 - (RandomFloat() * 0.4)
                    _ = AddParticleToGroup(&newParticleDef)
                }
            }
        }
    }

    PlayEffect_Parms3D(Int16(EFFECT_PLANECRASH), &gCoord, UInt32(NORMAL_CHANNEL_RATE), 0.5)

    DeleteEnemy(theNode)
}

// Returns true if enemy killed
private func checkIfRamphorHitPlayer(_ enemy: UnsafeMutablePointer<ObjNode>) -> Bool {
    if gGamePrefs.isKiddieMode { // don't hurt in kiddie mode
        return false
    }

    for p in 0..<Int(gNumPlayers) {
        let playerInfo = GetPlayerInfoEntry(Int32(p))
        if playerInfo.pointee.shieldPower > 0.0 { // if player has shield then skip since other collision code handles this
            continue
        }

        // GET COORD OF HEAD AND TAIL

        var lineSeg = OGLLineSegment()
        FindCoordOfJoint(enemy, ramphorJointnumButt, &lineSeg.p1)
        FindCoordOfJoint(enemy, ramphorJointnumTailtip, &lineSeg.p2)

        // SEE IF LINE SEG HITS PLAYER GEOMETRY

        gPickAllTrianglesAsDoubleSided = 1
        var hitPt = OGLPoint3D()
        let hitObj = OGL_DoLineSegmentCollision_ObjNodes(&lineSeg, 0, UInt32(CTYPE_PLAYER1) << UInt32(p), &hitPt, nil, nil, 1)
        gPickAllTrianglesAsDoubleSided = 0

        if let hitObj {
            // HURT PLAYER

            if let triggerCallback = hitObj.pointee.TriggerCallback { // call hit obj's trigger func if any
                _ = triggerCallback(hitObj, enemy)
            }

            // HURT ENEMY

            let killed = hurtRamphor(enemy, 0.2)

            return killed
        }
    }

    return false // not killed
}
