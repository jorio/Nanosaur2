// Enemy_Brach.swift - Port of Enemy_Brach.c to Swift

private let maxBrachs: Int8 = 7

private let brachScale: Float = 6.0

private let brachDetachDist: Float = 500.0
private let brachChaseDistMax: Float = 3000.0
private let brachTargetOffset: Float = 20.0

private let brachTurnSpeed: Float = 2.0
private let brachWalkSpeed: Float = 300.0

private let brachHealth: Float = 1.1
private let brachDamage: Float = 0.7

// MARK: - Anims

private let brachAnimStand = 0
private let brachAnimWalk = 1
private let brachAnimDeath = 2
private let brachAnimScratch = 3
private let brachAnimEat = 4

@c @implementation
public func AddEnemy_Brach(_ itemPtr: UnsafeMutablePointer<TerrainItemEntryType>!, _ x: Float, _ z: Float) -> UInt8 {
    if gNumEnemies >= gMaxEnemies { // keep from getting absurd
        return 0
    }

    if itemPtr.pointee.parm.3 & 1 == 0 { // see if always add
        if GetNumEnemyOfKindSlot(Int32(EnemyKind.brach.rawValue))!.pointee >= maxBrachs {
            return 0
        }
    }

    let newObj = makeBrach(x, z, Int16(brachAnimStand))!

    newObj.pointee.TerrainItemPtr = itemPtr

    newObj.pointee.Timer = RandomFloat() * 10.0

    // SET ROT

    newObj.pointee.Rot.y = Float(itemPtr.pointee.parm.0) * (Float.pi * 2 / 8.0)
    UpdateObjectTransforms(newObj)

    gNumEnemies += 1
    GetNumEnemyOfKindSlot(Int32(EnemyKind.brach.rawValue))!.pointee += 1

    return 1
}

private func makeBrach(_ x: Float, _ z: Float, _ animNum: Int16) -> UnsafeMutablePointer<ObjNode>? {
    // MAKE SKELETON ENEMY

    let newObj = MakeEnemySkeleton(UInt8(SkeletonType.brach.rawValue), animNum, x, z, brachScale, 0, cMoveBrach)!

    // SET BETTER INFO

    newObj.pointee.Skeleton!.pointee.CurrentAnimTime = newObj.pointee.Skeleton!.pointee.MaxAnimTime * RandomFloat() // set random time index so all of these are not in sync

    newObj.pointee.Health = brachHealth
    newObj.pointee.Damage = brachDamage
    newObj.pointee.Kind = Int32(EnemyKind.brach.rawValue)

    // MAKE SHADOW

    _ = AttachShadowToObject(newObj, .circular, 12, 20, 0)

    // SET COLLISION STUFF

    CalcNewTargetOffsets(newObj, brachTargetOffset)

    CreateCollisionBoxFromBoundingBox(newObj, 0.5, 0.9)
    newObj.pointee.LeftOff = newObj.pointee.BackOff
    newObj.pointee.RightOff = -newObj.pointee.LeftOff

    newObj.pointee.HitByWeaponHandler = cBrachHitByWeaponCallback

    return newObj
}

// MARK: - Move Brach

private let cMoveBrach: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }

    if TrackTerrainItem(theNode) != 0 { // just check to see if it's gone
        DeleteEnemy(theNode)
        return
    }

    GetObjectInfo(theNode)

    let animNum = Int(theNode.pointee.Skeleton!.pointee.AnimNum)
    switch animNum {
    case brachAnimStand: moveBrachStand(theNode)
    case brachAnimWalk: moveBrachWalk(theNode)
    case brachAnimDeath: moveBrachDeath(theNode)
    case brachAnimScratch: moveBrachScratch(theNode)
    case brachAnimEat: moveBrachEat(theNode)
    default: break
    }
}

private func moveBrachStand(_ theNode: UnsafeMutablePointer<ObjNode>) {
    theNode.pointee.Skeleton!.pointee.AnimSpeed = 0.3 // slow this down

    // SEE IF DO SCRATCH / EAT

    theNode.pointee.Timer -= gFramesPerSecondFrac
    if theNode.pointee.Timer <= 0.0 {
        if MyRandomLong() & 1 != 0 {
            MorphToSkeletonAnim(theNode.pointee.Skeleton, brachAnimScratch, 3)
        } else {
            MorphToSkeletonAnim(theNode.pointee.Skeleton, brachAnimEat, 1)
        }

        theNode.pointee.Timer = 3.0 + RandomFloat() * 5.0
    }

    // DO ENEMY COLLISION

    if DoEnemyCollisionDetect(theNode, SwDEFAULT_ENEMY_COLLISION_CTYPES, 1) != 0 {
        return
    }

    updateBrach(theNode)
}

private func moveBrachScratch(_ theNode: UnsafeMutablePointer<ObjNode>) {
    theNode.pointee.Skeleton!.pointee.AnimSpeed = 0.7 // slow this down

    if theNode.pointee.Skeleton!.pointee.AnimHasStopped != 0 {
        SetSkeletonAnim(theNode.pointee.Skeleton, brachAnimStand)
    }

    // DO ENEMY COLLISION

    if DoEnemyCollisionDetect(theNode, SwDEFAULT_ENEMY_COLLISION_CTYPES, 1) != 0 {
        return
    }

    updateBrach(theNode)
}

private func moveBrachEat(_ theNode: UnsafeMutablePointer<ObjNode>) {
    theNode.pointee.Skeleton!.pointee.AnimSpeed = 0.4 // slow this down

    if theNode.pointee.Skeleton!.pointee.AnimHasStopped != 0 {
        SetSkeletonAnim(theNode.pointee.Skeleton, brachAnimStand)
    }

    // DO ENEMY COLLISION

    if DoEnemyCollisionDetect(theNode, SwDEFAULT_ENEMY_COLLISION_CTYPES, 1) != 0 {
        return
    }

    updateBrach(theNode)
}

private func moveBrachWalk(_ theNode: UnsafeMutablePointer<ObjNode>) {
    let fps = gFramesPerSecondFrac

    // MOVE TOWARD PLAYER

    var playerNum: Int16 = 0
    _ = CalcDistanceToClosestPlayer(&gCoord, &playerNum) // find out who's the closest player

    if GetPlayerIsDead(Int32(playerNum)) == 0 { // don't aim at dead players
        let playerInfo = GetPlayerInfoEntry(Int32(playerNum))!
        _ = TurnObjectTowardTarget(theNode, &gCoord, playerInfo.pointee.coord.x, playerInfo.pointee.coord.z,
                                    brachTurnSpeed, 0, nil)
    }

    let r = theNode.pointee.Rot.y
    gDelta.x = -sin(r) * brachWalkSpeed
    gDelta.z = -cos(r) * brachWalkSpeed
    gDelta.y -= ENEMY_GRAVITY * fps // add gravity

    gCoord.x += gDelta.x * fps
    gCoord.y += gDelta.y * fps
    gCoord.z += gDelta.z * fps

    if IsWaterInFrontOfEnemy(r) != 0 { // if about to enter water then stop
        MorphToSkeletonAnim(theNode.pointee.Skeleton, brachAnimStand, 8)
    }

    // DO ENEMY COLLISION

    if DoEnemyCollisionDetect(theNode, SwDEFAULT_ENEMY_COLLISION_CTYPES, 0) != 0 {
        return
    }

    updateBrach(theNode)
}

private func moveBrachDeath(_ theNode: UnsafeMutablePointer<ObjNode>) {
    let fps = gFramesPerSecondFrac

    theNode.pointee.Skeleton!.pointee.AnimSpeed = 0.4

    // SEE IF GONE
    //
    // if was culled on last frame and is far enough away, then delete it

    if IsObjectTotallyCulled(theNode) != 0 {
        var playerNum: Int16 = 0
        let dist = CalcDistanceToClosestPlayer(&gCoord, &playerNum)

        if dist > 3000.0 {
            DeleteEnemy(theNode)
            return
        }
    }

    if theNode.pointee.StatusBits & UInt32(STATUS_BIT_ONGROUND) != 0 { // if on ground, add friction
        ApplyFrictionToDeltas(2000.0, &gDelta)
    }
    gDelta.y -= ENEMY_GRAVITY * fps // add gravity
    gCoord.x += gDelta.x * fps
    gCoord.y += gDelta.y * fps
    gCoord.z += gDelta.z * fps

    // DO ENEMY COLLISION

    if DoEnemyCollisionDetect(theNode, SwDEATH_ENEMY_COLLISION_CTYPES, 1) != 0 {
        return
    }

    // UPDATE

    updateBrach(theNode)
}

private func updateBrach(_ theNode: UnsafeMutablePointer<ObjNode>) {
    theNode.update()

    // SET WALK ANIM SPEED

    if theNode.pointee.Skeleton!.pointee.AnimNum == UInt8(brachAnimWalk) {
        theNode.pointee.Skeleton!.pointee.AnimSpeed = theNode.pointee.Speed * 0.003
    }
}

// MARK: - Prime Brach

@c @implementation
public func PrimeEnemy_Brach(_ splineNum: Int, _ itemPtr: UnsafeMutablePointer<SplineItemType>!) -> UInt8 {
    // GET SPLINE INFO

    let placement = itemPtr.pointee.placement
    var x: Float = 0
    var z: Float = 0
    GetCoordOnSpline(gSplineList + splineNum, placement, &x, &z)

    // MAKE BRACH

    let newObj = makeBrach(x, z, Int16(brachAnimWalk))!

    // SET BETTER INFO

    newObj.pointee.StatusBits |= UInt32(STATUS_BIT_ONSPLINE)
    newObj.pointee.SplineItemPtr = itemPtr
    newObj.pointee.SplineNum = UInt8(splineNum)
    newObj.pointee.SplinePlacement = placement
    newObj.pointee.SplineMoveCall = cMoveBrachOnSpline // set move call

    newObj.pointee.Coord.y -= newObj.pointee.BottomOff

    newObj.pointee.Skeleton!.pointee.AnimSpeed = 0.5

    // ADD SPLINE OBJECT TO SPLINE OBJECT LIST

    DetachObject(newObj, 1) // detach this object from the linked list
    AddToSplineObjectList(newObj, 1)

    return 1
}

private let cMoveBrachOnSpline: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }

    let isInRange = IsSplineItemOnActiveTerrain(theNode) // update its visibility

    // MOVE ALONG THE SPLINE

    _ = IncreaseSplineIndex(theNode, 70)
    GetObjectCoordOnSpline(theNode)

    // UPDATE STUFF IF IN RANGE

    if isInRange != 0 {
        theNode.pointee.Rot.y = CalcYAngleFromPointToPoint(theNode.pointee.Rot.y, theNode.pointee.OldCoord.x, theNode.pointee.OldCoord.z, // calc y rot aim
                                                            theNode.pointee.Coord.x, theNode.pointee.Coord.z)

        theNode.pointee.Coord.y = GetTerrainY(theNode.pointee.Coord.x, theNode.pointee.Coord.z) - theNode.pointee.BottomOff // calc y coord
        UpdateObjectTransforms(theNode) // update transforms
        UpdateShadow(theNode)

        // DO SOME COLLISION CHECKING

        GetObjectInfo(theNode)
        if DoEnemyCollisionDetect(theNode, UInt32(CTYPE_HURTENEMY), 1) != 0 {
            return
        }
    }
}

// MARK: - Brach Hit By Weapon Callback

// Returns true if object should stop bullet.
private let cBrachHitByWeaponCallback: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<OGLPoint3D>?, UnsafeMutablePointer<OGLVector3D>?) -> UInt8 = { bullet, enemyOpt, _, _ in
    let enemy = enemyOpt!

    enemy.pointee.Health -= bullet!.pointee.Damage
    if enemy.pointee.Health <= 0.0 {
        killBrach(enemy)
    } else if bullet!.pointee.Damage >= 0.1 { // if hurt enough, make grunt
        PlayEffect_Parms3D(Int16(EFFECT_BRACHHURT), &enemy.pointee.Coord, UInt32(NORMAL_CHANNEL_RATE), 1.2)
    }

    return 1
}

private func killBrach(_ enemy: UnsafeMutablePointer<ObjNode>) {
    PlayEffect_Parms3D(Int16(EFFECT_BRACHDEATH), &enemy.pointee.Coord, UInt32(NORMAL_CHANNEL_RATE), 1.0)

    // SEE IF REMOVE FROM SPLINE

    if enemy.pointee.StatusBits & UInt32(STATUS_BIT_ONSPLINE) != 0 {
        DetachEnemyFromSpline(enemy, cMoveBrach)
    }

    enemy.pointee.HitByWeaponHandler = nil

    MorphToSkeletonAnim(enemy.pointee.Skeleton, brachAnimDeath, 8.0)

    enemy.pointee.TerrainItemPtr = nil // dont ever come back
    enemy.pointee.CType &= ~UInt32(CTYPE_AUTOTARGETWEAPON)
}
