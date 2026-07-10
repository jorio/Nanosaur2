// Enemy_Raptor.swift - Port of Enemy_Raptor.c to Swift

private let maxRaptors = 7

private let raptorScale: Float = 2.5

private let raptorChaseDistMax: Float = 5000.0

private let raptorTargetOffset: Float = 100.0

private let raptorTurnSpeed: Float = 4.2
private let raptorWalkSpeed: Float = 2300.0

private let raptorHealth: Float = 0.7
private let raptorDamage: Float = 0.4

private let raptorWalkAnimSpeedFactor: Float = 0.0009

private let raptorAttackDist: Float = 1100.0
private let raptorJumpDeltaY: Float = 2800.0

// MARK: - Anims

private let raptorAnimWalk = 0
private let raptorAnimStand = 1
private let raptorAnimDeath = 2
private let raptorAnimKnockedDown = 3
private let raptorAnimJump = 4
private let raptorAnimTurnLeft = 5
private let raptorAnimTurnRight = 6
private let raptorAnimWalkLeft = 7
private let raptorAnimWalkRight = 8

// MARK: - Modes

private let raptorModeWalkInFront: Int32 = 0
private let raptorModeWalkToPlayer: Int32 = 1
private let raptorModeWalkHome: Int32 = 2

private let raptorJointnumHead = 3
private let raptorJointnumTailtip = 22

// MARK: - Add raptor enemy

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    @discardableResult
    func addEnemyRaptor(x: Float, z: Float) -> UInt8 {
        if gGamePrefs.isKiddieMode { // don't add any non-spline enemies in kiddie mode
            return 0
        }

        if gNumEnemies >= gMaxEnemies { // keep from getting absurd
            return 0
        }

        if (pointee.parm.3 & 1) == 0 { // see if always add
            if gNumEnemyOfKind[Int(EnemyKind.raptor.rawValue)] >= maxRaptors {
                return 0
            }
        }

        let newObj = makeRaptor(x, z, Int16(raptorAnimWalk))!

        newObj.pointee.TerrainItemPtr = self

        gNumEnemies += 1
        gNumEnemyOfKind[Int(EnemyKind.raptor.rawValue)] += 1

        return 1
    }
}

// MARK: - Make raptor

private func makeRaptor(_ x: Float, _ z: Float, _ animNum: Int16) -> UnsafeMutablePointer<ObjNode>? {
    // MAKE SKELETON ENEMY

    let newObj = MakeEnemySkeleton(UInt8(SkeletonType.raptor.rawValue), animNum, x, z, raptorScale, 0, cMoveRaptor)!

    newObj.pointee.Mode = raptorModeWalkInFront

    // SET BETTER INFO

    let skeleton = newObj.pointee.Skeleton!
    skeleton.pointee.CurrentAnimTime = skeleton.pointee.MaxAnimTime * RandomFloat() // set random time index so all of these are not in sync

    newObj.pointee.Health = raptorHealth
    if gGamePrefs.isKiddieMode { // no damage in kiddie mode
        newObj.pointee.Damage = 0
    } else {
        newObj.pointee.Damage = raptorDamage
    }
    newObj.pointee.Kind = Int32(EnemyKind.raptor.rawValue)

    // SET HOT-SPOT FOR AUTO TARGETING WEAPONS

    newObj.pointee.HeatSeekHotSpotOff.x = 0
    newObj.pointee.HeatSeekHotSpotOff.y = 0
    newObj.pointee.HeatSeekHotSpotOff.z = -20

    // MAKE SHADOW

    _ = AttachShadowToObject(newObj, .circular, 6, 10, 0)

    // SET COLLISION STUFF

    CalcNewTargetOffsets(newObj, raptorTargetOffset)

    CreateCollisionBoxFromBoundingBox(newObj, 0.5, 0.9)
    newObj.pointee.LeftOff = newObj.pointee.BackOff
    newObj.pointee.RightOff = -newObj.pointee.LeftOff

    newObj.pointee.HitByWeaponHandler = cRaptorHitByWeaponCallback
    newObj.pointee.TriggerCallback = cDoTrigRaptor

    return newObj
}

// MARK: -

// MARK: - Move raptor

private let cMoveRaptor: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }

    if TrackTerrainItem(theNode) != 0 { // just check to see if it's gone
        DeleteEnemy(theNode)
        return
    }

    theNode.getInfo()

    switch Int(theNode.pointee.Skeleton!.pointee.AnimNum) {
    case raptorAnimWalk, raptorAnimTurnLeft, raptorAnimTurnRight, raptorAnimWalkLeft, raptorAnimWalkRight:
        moveRaptorWalk(theNode)
    case raptorAnimStand:
        moveRaptorStand(theNode)
    case raptorAnimDeath:
        moveRaptorDeath(theNode)
    case raptorAnimKnockedDown:
        moveRaptorKnockedDown(theNode)
    case raptorAnimJump:
        moveRaptorJump(theNode)
    default:
        break
    }
}

// MARK: - Move raptor: standing

private func moveRaptorStand(_ theNode: UnsafeMutablePointer<ObjNode>) {
    // TURN TOWARDS ME

    var playerNum: Int16 = 0
    let dist = CalcDistanceToClosestPlayer(&gEngine.objects.coord, &playerNum)
    let playerInfo = GetPlayerInfoEntry(Int32(playerNum))

    _ = theNode.turnTowardTarget(from: &gEngine.objects.coord, toX: playerInfo.pointee.coord.x,
                                toZ: playerInfo.pointee.coord.z, turnSpeed: raptorTurnSpeed, useOffsets: 0, crossOut: nil)

    if dist < raptorChaseDistMax {
        theNode.pointee.SpecialF.0 = 0 // WalkSpeed
        theNode.pointee.Mode = raptorModeWalkInFront
        MorphToSkeletonAnim(theNode.pointee.Skeleton, raptorAnimWalk, 3)
    }

    // DO ENEMY COLLISION

    if DoEnemyCollisionDetect(theNode, SwDEFAULT_ENEMY_COLLISION_CTYPES, 1) != 0 {
        return
    }

    updateRaptor(theNode)
}

// MARK: - Move raptor: walking

private func moveRaptorWalk(_ theNode: UnsafeMutablePointer<ObjNode>) {
    let skeleton = theNode.pointee.Skeleton!
    let fps = gFramesPerSecondFrac

    let oldRotY = theNode.pointee.Rot.y

    var dist: Float
    var aim: Float = 0
    var cross: Float = 0
    var px: Float = 0
    var pz: Float = 0

    // SEE IF WALK TO HOME POSITION

    if theNode.pointee.Mode == raptorModeWalkHome {
        px = theNode.pointee.InitCoord.x
        pz = theNode.pointee.InitCoord.z
        var playerNum: Int16 = 0
        dist = CalcDistanceToClosestPlayer(&gEngine.objects.coord, &playerNum)
        aim = theNode.turnTowardTarget(from: &gEngine.objects.coord, toX: px, toZ: pz, turnSpeed: raptorTurnSpeed, useOffsets: 0, crossOut: &cross)

        if dist < 500.0 { // are we basically home?
            theNode.pointee.Mode = raptorModeWalkInFront
        } else {
            theNode.pointee.SpecialF.1 -= fps // HomeTimer: only try to go home for so long, then give up
            if theNode.pointee.SpecialF.1 <= 0.0 {
                theNode.pointee.Mode = raptorModeWalkInFront
            }
        }
    } else {
        // MOVE TOWARD PLAYER

        var playerNum: Int16 = 0
        dist = CalcDistanceToClosestPlayer(&gEngine.objects.coord, &playerNum)
        let player = GetPlayerInfoEntry(Int32(playerNum)).pointee.objNode!

        // SEE IF MOVING TOWARD POINT IN FRONT

        if theNode.pointee.Mode == raptorModeWalkInFront {
            let r = player.pointee.Rot.y
            px = player.pointee.Coord.x - sin(r) * 2600.0 // calc pt in front of player
            pz = player.pointee.Coord.z - cos(r) * 2600.0

            dist = CalcQuickDistance(px, pz, gEngine.objects.coord.x, gEngine.objects.coord.z) // calc dist to the target pt
            aim = theNode.turnTowardTarget(from: &gEngine.objects.coord, toX: px, toZ: pz, turnSpeed: raptorTurnSpeed, useOffsets: 1, crossOut: &cross)

            if dist < 400.0 { // once we've reached this point then switch to enemy target mode
                theNode.pointee.Mode = raptorModeWalkToPlayer

                px = player.pointee.Coord.x
                pz = player.pointee.Coord.z

                dist = CalcQuickDistance(px, pz, gEngine.objects.coord.x, gEngine.objects.coord.z) // calc dist to player
                aim = theNode.turnTowardTarget(from: &gEngine.objects.coord, toX: px, toZ: pz, turnSpeed: raptorTurnSpeed, useOffsets: 1, crossOut: &cross)
            }
        }

        // MOVE DIRECTLY TO PLAYER

        else if theNode.pointee.Mode == raptorModeWalkToPlayer {
            px = player.pointee.Coord.x
            pz = player.pointee.Coord.z

            dist = CalcQuickDistance(px, pz, gEngine.objects.coord.x, gEngine.objects.coord.z) // calc dist to player
            aim = theNode.turnTowardTarget(from: &gEngine.objects.coord, toX: px, toZ: pz, turnSpeed: raptorTurnSpeed, useOffsets: 1, crossOut: &cross)
        } else {
            // shouldn't happen
            return
        }
    }

    // ACCELERATE
    //
    // Max speed is a factor of how fast the enemy is turning.
    // The more it's turning, the slower it goes.

    var maxSpeed = raptorWalkSpeed - (fabsf(aim) * 200.0)
    if maxSpeed < (raptorWalkSpeed / 4) { // make sure doesn't get too slow
        maxSpeed = raptorWalkSpeed / 4
    }

    theNode.pointee.SpecialF.0 += fps * (maxSpeed * 0.3) // WalkSpeed
    if theNode.pointee.SpecialF.0 > maxSpeed {
        theNode.pointee.SpecialF.0 = maxSpeed
    }

    let walkSpeed = theNode.pointee.SpecialF.0

    skeleton.pointee.AnimSpeed = walkSpeed * raptorWalkAnimSpeedFactor

    // MOVE

    let r = theNode.pointee.Rot.y
    gEngine.objects.delta.x = -sin(r) * walkSpeed
    gEngine.objects.delta.z = -cos(r) * walkSpeed
    gEngine.objects.delta.y -= ENEMY_GRAVITY * fps // add gravity

    gEngine.objects.coord.x += gEngine.objects.delta.x * fps
    gEngine.objects.coord.y += gEngine.objects.delta.y * fps
    gEngine.objects.coord.z += gEngine.objects.delta.z * fps

    // SET APPROPRIATE WALK ANIM

    theNode.pointee.DeltaRot.y = (r - oldRotY) * gFramesPerSecond

    if fabsf(theNode.pointee.DeltaRot.y) > 1.5 {
        if cross < 0.0 {
            if skeleton.pointee.AnimNum != UInt8(raptorAnimWalkLeft) {
                MorphToSkeletonAnim(skeleton, raptorAnimWalkLeft, 5)
            }
        } else {
            if skeleton.pointee.AnimNum != UInt8(raptorAnimWalkRight) {
                MorphToSkeletonAnim(skeleton, raptorAnimWalkRight, 5)
            }
        }
    } else if skeleton.pointee.AnimNum != UInt8(raptorAnimWalk) {
        MorphToSkeletonAnim(skeleton, raptorAnimWalk, 5)
    }

    // SEE IF STAND

    if theNode.pointee.Mode != raptorModeWalkHome { // only if not walking home
        if dist > raptorChaseDistMax {
            MorphToSkeletonAnim(theNode.pointee.Skeleton, raptorAnimStand, 2)
        }
    }

    // DO ENEMY COLLISION

    if DoEnemyCollisionDetect(theNode, SwDEFAULT_ENEMY_COLLISION_CTYPES | UInt32(CTYPE_WATER), 0) != 0 {
        return
    }

    if gTotalSides != 0 { // if touched something then slow us down
        if gNumCollisions == 0 { // if it wasn't an objNode (probably fence), then switch mode
            theNode.pointee.Mode = raptorModeWalkHome
            theNode.pointee.SpecialF.1 = 3.0 // HomeTimer
        }

        theNode.pointee.SpecialF.0 = raptorWalkSpeed * 0.2 // WalkSpeed
    }

    // SEE IF JUMP

    if !gGamePrefs.isKiddieMode {
        if theNode.pointee.Mode == raptorModeWalkToPlayer { // only when walking directly to player
            if (dist < raptorAttackDist) && (aim < (Float.pi / 8)) {
                gEngine.objects.delta.y = raptorJumpDeltaY
                gEngine.objects.delta.x *= 0.7
                gEngine.objects.delta.z *= 0.7
                MorphToSkeletonAnim(theNode.pointee.Skeleton, raptorAnimJump, 5)
                PlayEffect3D(Int16(EFFECT_RAPTORATTACK), &gEngine.objects.coord)
            }
        }
    }

    updateRaptor(theNode)
}

// MARK: - Move raptor: jump

private func moveRaptorJump(_ theNode: UnsafeMutablePointer<ObjNode>) {
    let fps = gFramesPerSecondFrac

    gEngine.objects.delta.applyFriction(400.0)

    gEngine.objects.delta.y -= ENEMY_GRAVITY * fps // add gravity

    gEngine.objects.coord.x += gEngine.objects.delta.x * fps
    gEngine.objects.coord.y += gEngine.objects.delta.y * fps
    gEngine.objects.coord.z += gEngine.objects.delta.z * fps

    // DO ENEMY COLLISION

    if DoEnemyCollisionDetect(theNode, SwDEFAULT_ENEMY_COLLISION_CTYPES | UInt32(CTYPE_WATER), 0) != 0 {
        return
    }

    // DO SPECIAL CHECK TO SEE IF HIT PLAYER

    if checkIfRaptorHitPlayer(theNode) {
        return
    }

    // SEE IF LANDED

    if theNode.hasStatus(STATUS_BIT_ONGROUND) {
        theNode.pointee.SpecialF.0 = theNode.pointee.Speed // WalkSpeed
        theNode.pointee.Mode = raptorModeWalkInFront
        MorphToSkeletonAnim(theNode.pointee.Skeleton, raptorAnimWalk, 7.0)
    }

    updateRaptor(theNode)
}

// MARK: - Move raptor: knocked down

private func moveRaptorKnockedDown(_ theNode: UnsafeMutablePointer<ObjNode>) {
    let fps = gFramesPerSecondFrac

    gEngine.objects.delta.applyFriction(700.0)

    gEngine.objects.delta.y -= ENEMY_GRAVITY * fps // add gravity

    gEngine.objects.coord.x += gEngine.objects.delta.x * fps
    gEngine.objects.coord.y += gEngine.objects.delta.y * fps
    gEngine.objects.coord.z += gEngine.objects.delta.z * fps

    // SEE IF DONE

    theNode.pointee.Timer -= fps // ButtTimer
    if theNode.pointee.Timer <= 0.0 {
        MorphToSkeletonAnim(theNode.pointee.Skeleton, raptorAnimStand, 2.0)
    }

    // DO ENEMY COLLISION

    if DoEnemyCollisionDetect(theNode, SwDEFAULT_ENEMY_COLLISION_CTYPES, 1) != 0 {
        return
    }

    updateRaptor(theNode)
}

// MARK: - Move raptor: death

private func moveRaptorDeath(_ theNode: UnsafeMutablePointer<ObjNode>) {
    let fps = gFramesPerSecondFrac

    // SEE IF GONE
    //
    // if was culled on last frame and is far enough away, then delete it

    if IsObjectTotallyCulled(theNode) != 0 {
        var playerNum: Int16 = 0
        let dist = CalcDistanceToClosestPlayer(&gEngine.objects.coord, &playerNum)

        if dist > 1000.0 {
            DeleteEnemy(theNode)
            return
        }
    }

    if theNode.hasStatus(STATUS_BIT_ONGROUND) { // if on ground, add friction
        gEngine.objects.delta.applyFriction(2000.0)
    }
    gEngine.objects.delta.y -= ENEMY_GRAVITY * fps // add gravity
    gEngine.objects.coord.x += gEngine.objects.delta.x * fps
    gEngine.objects.coord.y += gEngine.objects.delta.y * fps
    gEngine.objects.coord.z += gEngine.objects.delta.z * fps

    // DO ENEMY COLLISION

    if DoEnemyCollisionDetect(theNode, SwDEATH_ENEMY_COLLISION_CTYPES, 1) != 0 {
        return
    }

    // UPDATE

    updateRaptor(theNode)
}

// MARK: - Update raptor

private func updateRaptor(_ theNode: UnsafeMutablePointer<ObjNode>) {
    theNode.update()
}

// MARK: -

// MARK: - Prime raptor enemy

func PrimeEnemy_Raptor(_ splineNum: Int, _ itemPtr: UnsafeMutablePointer<SplineItemType>!) -> UInt8 {
    // GET SPLINE INFO

    let placement = itemPtr.pointee.placement
    var x: Float = 0
    var z: Float = 0
    GetCoordOnSpline(gSplineList + splineNum, placement, &x, &z)

    // MAKE RAPTOR

    let newObj = makeRaptor(x, z, Int16(raptorAnimWalk))!

    // SET BETTER INFO

    newObj.setStatus(STATUS_BIT_ONSPLINE)
    newObj.pointee.SplineItemPtr = itemPtr
    newObj.pointee.SplineNum = UInt8(splineNum)
    newObj.pointee.SplinePlacement = placement
    newObj.pointee.SplineMoveCall = cMoveRaptorOnSpline // set move call

    newObj.pointee.Coord.y -= newObj.pointee.BottomOff

    // ADD SPLINE OBJECT TO SPLINE OBJECT LIST

    DetachObject(newObj, 1) // detach this object from the linked list
    AddToSplineObjectList(newObj, 1)

    return 1
}

// MARK: - Move raptor on spline

private let cMoveRaptorOnSpline: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }

    let isInRange = IsSplineItemOnActiveTerrain(theNode) // update its visibility

    // MOVE ALONG THE SPLINE

    _ = IncreaseSplineIndex(theNode, 350)
    GetObjectCoordOnSpline(theNode)

    // UPDATE STUFF IF IN RANGE

    if isInRange != 0 {
        // CALC ANIM SPEED

        theNode.pointee.Speed = theNode.pointee.Delta.length
        theNode.pointee.Skeleton!.pointee.AnimSpeed = theNode.pointee.Speed * raptorWalkAnimSpeedFactor

        // AIM ALONG SPLINE

        theNode.pointee.Rot.y = CalcYAngleFromPointToPoint(theNode.pointee.Rot.y, theNode.pointee.OldCoord.x, theNode.pointee.OldCoord.z, // calc y rot aim
                                                            theNode.pointee.Coord.x, theNode.pointee.Coord.z)

        theNode.pointee.Coord.y = GetTerrainY(theNode.pointee.Coord.x, theNode.pointee.Coord.z) - theNode.pointee.BottomOff // calc y coord
        theNode.updateTransforms() // update transforms
        UpdateShadow(theNode)

        // DO SOME COLLISION CHECKING

        theNode.getInfo()
        if DoEnemyCollisionDetect(theNode, UInt32(CTYPE_HURTENEMY), 1) != 0 {
            return
        }
    }
}

// MARK: -

// MARK: - Raptor hit by weapon callback

// Returns true if object should stop bullet.
private let cRaptorHitByWeaponCallback: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<OGLPoint3D>?, UnsafeMutablePointer<OGLVector3D>?) -> UInt8 = { bullet, enemyOpt, _, _ in
    let enemy = enemyOpt!

    enemy.pointee.Health -= bullet!.pointee.Damage

    // SEE IF KILLED

    if enemy.pointee.Health <= 0.0 {
        killRaptor(enemy)
    }

    // JUST HURT

    else {
        if enemy.hasStatus(STATUS_BIT_ONSPLINE) {
            DetachEnemyFromSpline(enemy, cMoveRaptor)
        }

        knockDownRaptor(enemy)
    }

    return 1
}

// MARK: - Kill raptor

private func killRaptor(_ enemy: UnsafeMutablePointer<ObjNode>) {
    PlayEffect3D(Int16(EFFECT_RAPTORDEATH), &enemy.pointee.Coord)

    // SEE IF REMOVE FROM SPLINE

    if enemy.hasStatus(STATUS_BIT_ONSPLINE) {
        DetachEnemyFromSpline(enemy, cMoveRaptor)
    }

    enemy.pointee.HitByWeaponHandler = nil

    MorphToSkeletonAnim(enemy.pointee.Skeleton, raptorAnimDeath, 2.0)

    enemy.pointee.TerrainItemPtr = nil // dont ever come back
    enemy.pointee.CType &= ~UInt32(CTYPE_AUTOTARGETWEAPON)
}

// MARK: - Trigger callback: raptor

// Returns TRUE if want to handle hit as a solid
private let cDoTrigRaptor: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?) -> UInt8 = { enemyOpt, playerOpt in
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
            _ = PlayerLoseHealth(Int16(playerNum), enemy.pointee.Damage, .deathDive, &gEngine.objects.coord, 1)
        }

        playerInfo.pointee.invincibilityTimer = 1.0

        // PLAYER ALWAYS DROPS EGG ON IMPACT

        DropEgg_NoWormhole(Int16(playerNum))

        // PLAY BODYHIT EFFECT

        PlayEffect_Parms3D(Int16(EFFECT_BODYHIT), &gEngine.objects.coord, UInt32(NORMAL_CHANNEL_RATE), 1.1)
        PlayRumbleEffect(Int16(EFFECT_BODYHIT), Int32(playerNum))
    }

    // HURT THE RAPTOR

    _ = hurtRaptor(enemy, 0.5)

    return 0
}

// MARK: - Hurt raptor

// Returns true if raptor killed
@discardableResult
private func hurtRaptor(_ enemy: UnsafeMutablePointer<ObjNode>, _ damage: Float) -> Bool {
    let skeleton = enemy.pointee.Skeleton!
    if (skeleton.pointee.AnimNum != UInt8(raptorAnimKnockedDown)) // only hurt if not dead or knocked down already
        && (skeleton.pointee.AnimNum != UInt8(raptorAnimDeath)) {
        enemy.pointee.Health -= damage
        if enemy.pointee.Health <= 0.0 {
            killRaptor(enemy)
            return true
        } else {
            knockDownRaptor(enemy)
        }
    }

    return false
}

// MARK: - Knock down raptor

private func knockDownRaptor(_ enemy: UnsafeMutablePointer<ObjNode>) {
    // SET ANIM & TIMER

    MorphToSkeletonAnim(enemy.pointee.Skeleton, raptorAnimKnockedDown, 2.0)
    enemy.pointee.Timer = 5.0 // ButtTimer

    // SEE IF REMOVE FROM SPLINE

    if enemy.hasStatus(STATUS_BIT_ONSPLINE) {
        DetachEnemyFromSpline(enemy, cMoveRaptor)
    }
}

// MARK: - Check if raptor hit player

// Returns true if enemy killed
private func checkIfRaptorHitPlayer(_ enemy: UnsafeMutablePointer<ObjNode>) -> Bool {
    if gGamePrefs.isKiddieMode { // don't hurt in kiddie mode
        return false // TODO: I assume we should return false here -IJ
    }

    for p in 0..<Int(gEngine.player.numPlayers) {
        let playerInfo = GetPlayerInfoEntry(Int32(p))
        if playerInfo.pointee.shieldPower > 0.0 { // if player has shield then skip since other collision code handles this
            continue
        }

        // GET COORD OF HEAD AND TAIL

        var lineSeg = OGLLineSegment()
        FindCoordOfJoint(enemy, raptorJointnumHead, &lineSeg.p1)
        FindCoordOfJoint(enemy, raptorJointnumTailtip, &lineSeg.p2)

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

            let killed = hurtRaptor(enemy, 0.3)

            return killed
        }
    }

    return false // raptor not killed
}
