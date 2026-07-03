// Eggs.swift - Port of Eggs.c to Swift

private let eggScale: Float = 6.0

// Called when terrain is loaded - it counts the total egg inventory for this level.
@c @implementation
public func FindAllEggItems() {
    // INIT EGG COUNTS

    for (i, _) in EggColor.allCases.enumerated() {
        GetNumEggsToSaveSlot(Int32(i))!.pointee = 0
        GetNumEggsSavedSlot(Int32(i))!.pointee = 0
    }

    // SCAN FOR EGG ITEM

    let itemPtr = gMasterItemList! // get pointer to data inside the LOCKED handle

    for i in 0..<Int(gNumTerrainItems) {
        if itemPtr[i].type == UInt16(MAP_ITEM_EGG) { // see if it's an Egg item
            let eggColor = Int(itemPtr[i].parm.0) // egg color # is in parm 0
            if eggColor >= EggColor.allCases.count {
                SwFatal("FindAllEggItems: bad egg color!")
            }

            GetNumEggsToSaveSlot(Int32(eggColor))!.pointee += 1 // inc counter
        }
    }
}

@c @implementation
public func AddEgg(_ itemPtr: UnsafeMutablePointer<TerrainItemEntryType>!, _ x: Float, _ z: Float) -> UInt8 {
    let eggColor = Int32(itemPtr.pointee.parm.0)

    // MAKE NEST

    var def = NewObjectDefinitionType()
    def.group = UInt8(MODEL_GROUP_GLOBAL)
    def.type = UInt8(GLOBAL_ObjType_Nest)
    def.coord.x = x
    def.coord.z = z
    def.coord.y = itemPtr.pointee.terrainY
    def.slot = Int16(SLOT_OF_DUMB)
    def.moveCall = cMoveNest
    def.scale = eggScale
    def.flags = gAutoFadeStatusBits
    def.rot = RandomFloat() * SwPI2

    let nest = MakeNewDisplayGroupObject(&def)!

    nest.pointee.TerrainItemPtr = itemPtr // keep ptr to item list

    if itemPtr.pointee.flags & UInt16(ITEM_FLAGS_USER1) == 0 { // if user flag is set then egg has already been saved, so don't make it
        // MAKE EGG

        def.type = UInt8(Int32(GLOBAL_ObjType_RedEgg) + eggColor)
        def.slot += 1
        def.moveCall = cMoveEggNotCarried
        let egg = MakeNewDisplayGroupObject(&def)!

        egg.pointee.What = Int32(WhatType.egg.rawValue)

        egg.pointee.Kind = eggColor // remember what color of egg this is
        egg.pointee.Flag.0 = 0 // CanResetEgg

        egg.pointee.Coord.y -= egg.pointee.LocalBBox.min.y
        egg.pointee.InitCoord.y = egg.pointee.Coord.y
        egg.pointee.Rot.x = 0 // rot onto side

        UpdateObjectTransforms(egg)

        // SET COLLISION STUFF

        egg.pointee.CType = UInt32(CTYPE_EGG)
        egg.pointee.CBits = UInt32(CBITS_ALLSOLID)
        CreateCollisionBoxFromBoundingBox(egg, 1, 1)

        // SET HOLD OFFSETS

        egg.pointee.HoldOffset.x = 0
        egg.pointee.HoldOffset.y = 0
        egg.pointee.HoldOffset.z = 0

        egg.pointee.HoldRot.x = 0
        egg.pointee.HoldRot.y = 0
        egg.pointee.HoldRot.z = 0

        egg.pointee.Special.1 = 0 // TargetJoint

        egg.pointee.Timer = 0 // DelayUntilCanPickup

        nest.pointee.ChainNode = egg
        egg.pointee.ChainHead = nest

        nest.pointee.Flag.1 = 1 // NestHasEgg: the egg is in the nest

        // MAKE BEAM

        def.type = UInt8(GLOBAL_ObjType_EggBeam)
        def.flags |= UInt32(STATUS_BIT_GLOW | STATUS_BIT_NOZWRITES | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOFOG)
        def.slot = Int16(SLOT_OF_DUMB + 50)
        def.moveCall = nil
        let beam = MakeNewDisplayGroupObject(&def)!

        switch eggColor {
        case 0: // red
            beam.pointee.ColorFilter.g = 0.5
            beam.pointee.ColorFilter.b = 0.5
        case 1: // green
            beam.pointee.ColorFilter.r = 0.5
            beam.pointee.ColorFilter.b = 0.5
        case 2: // blue
            beam.pointee.ColorFilter.r = 0.5
            beam.pointee.ColorFilter.g = 0.5
        case 3: // yellow
            beam.pointee.ColorFilter.b = 0.5
        case 4: // purple
            beam.pointee.ColorFilter.g = 0.5
        default:
            break
        }

        egg.pointee.ChainNode = beam

        _ = AttachShadowToObject(egg, .circular, 3, 3, 1)
    }

    return 1 // item was added
}

private let cMoveNest: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { nestOpt in
    guard let nest = nestOpt else { return }

    // GET BEAM OBJ

    let egg = nest.pointee.ChainNode
    let beam = egg?.pointee.ChainNode

    // SEE IF GONE, ONLY IF EGG IS STILL IN THE NEST OR IF EGG WENT THRU WORMHOLE

    if (nest.pointee.Flag.1 != 0) || (beam == nil) {
        if TrackTerrainItem(nest) != 0 {
            DeleteObject(nest)
            return
        }
    }

    // UPDATE BEAM

    if let beam {
        // DECAY BEAM IF EGG IS OUT OF NEST

        if nest.pointee.Flag.1 == 0 {
            beam.pointee.ColorFilter.a -= gFramesPerSecondFrac * 0.3
            if beam.pointee.ColorFilter.a <= 0.0 {
                beam.pointee.ColorFilter.a = 0.0
            }
        }

        // UNDULATE THE BEAM

        else {
            beam.pointee.SpecialF.0 += gFramesPerSecondFrac * Float.pi
            beam.pointee.ColorFilter.a = 0.4 + sin(beam.pointee.SpecialF.0) * 0.1
        }
    }
}

// MARK: - Move Egg: Not Carried

private let cMoveEggNotCarried: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { eggOpt in
    guard let egg = eggOpt else { return }
    let fps = gFramesPerSecondFrac
    let onGround = egg.pointee.StatusBits & UInt32(STATUS_BIT_ONGROUND)

    let nest = egg.pointee.ChainHead!

    GetObjectInfo(egg)

    // MOVE IT

    gDelta.y += -3000.0 * fps // gravity

    if onGround != 0 {
        ApplyFrictionToDeltasXZ(300, &gDelta) // ground friction

        if nest.pointee.Flag.1 != 0 {
            egg.pointee.Rot.x = 0 // keep up
        } else {
            egg.pointee.Rot.x = Float.pi / 2 // keep on side
        }
    } else {
        ApplyFrictionToDeltasXZ(100, &gDelta) // air friction
        egg.pointee.Rot.x += fps * 1.5 // spin in air
    }

    // MOVE

    gCoord.x += gDelta.x * fps
    gCoord.y += gDelta.y * fps
    gCoord.z += gDelta.z * fps

    // COLLISION DETECT

    _ = HandleCollisions(egg, UInt32(CTYPE_FENCE | CTYPE_TERRAIN | CTYPE_MISC), 0.1)

    // SEE IF NEED TO RESET IT BACK TO ITS NEST

    if egg.pointee.Flag.0 != 0 { // has the egg been picked up before?
        egg.pointee.SpecialF.0 -= fps
        if egg.pointee.SpecialF.0 <= 0.0 { // is it ok to try resetting now?
            if egg.pointee.SpecialF.0 < -25.0 { // if we've tried for 25 seconds with no results, then just force it to get reset
                resetEggToNest(egg)
            } else if (CalcDistanceToClosestPlayer(&gCoord, nil) > 1500.0) && (IsObjectTotallyCulled(egg) != 0) { // only reset if players are far enough away & nobody can see it
                // SEE IF THE HOME POSITION IS ALSO CULLED

                var m = OGLMatrix4x4()
                let bbox = egg.pointer(to: \.LocalBBox)! // get ptr to egg's local-space bbox

                egg.pointee.Coord = egg.pointee.InitCoord // move back to init coord (this gets zapped at update below if bboxvisible() fails)
                UpdateObjectTransforms(egg)
                OGLMatrix4x4_Multiply(&egg.pointee.BaseTransformMatrix, &gWorldToFrustumMatrix, &m)

                if OGL_IsBBoxVisible(bbox, nil) == 0 { // see if it would be culled there
                    resetEggToNest(egg)
                }
            }
        }
    }

    // SEE IF PICKED UP BY A PLAYER

    egg.pointee.Timer -= fps // DelayUntilCanPickup
    if egg.pointee.Timer <= 0.0 { // only allow pickup if timer is ready
        for i in 0..<Int(gNumPlayers) {
            if GetPlayerIsDead(Int32(i)) != 0 { // dead players can't pick up eggs
                continue
            }

            let playerInfo = GetPlayerInfoEntry(Int32(i))!
            if playerInfo.pointee.carriedObj == nil { // is player already carrying anything?
                let player = playerInfo.pointee.objNode!

                // SEE IF "HOLD" POINT HITS EGG

                var footCoord = OGLPoint3D()
                FindCoordOfJoint(player, Int(PlayerJoint.eggHold.rawValue), &footCoord) // get coord of joint
                if OGLPoint3D_Distance(&footCoord, &gCoord) < 150.0 { // is coord close enough to egg?
                    playerPickedUpEgg(egg, Int16(i))
                    break
                }
            }
        }
    }

    // UPDATE

    UpdateObject(egg)
}

private func resetEggToNest(_ egg: UnsafeMutablePointer<ObjNode>) {
    let nest = egg.pointee.ChainHead!

    // MOVE BACK TO NEST

    gCoord = egg.pointee.InitCoord
    gDelta.x = 0
    gDelta.y = 0
    gDelta.z = 0

    // LET NEST KNOW

    nest.pointee.Flag.1 = 1 // NestHasEgg
}

private func playerPickedUpEgg(_ egg: UnsafeMutablePointer<ObjNode>, _ playerNum: Int16) {
    // LET NEST KNOW THE EGG IS GONE

    let nest = egg.pointee.ChainHead!
    nest.pointee.Flag.1 = 0 // NestHasEgg

    // GET THE EGG

    GetPlayerInfoEntry(Int32(playerNum))!.pointee.carriedObj = egg // give egg to player
    egg.pointee.PlayerNum = UInt8(playerNum) // remember which player has it
    egg.pointee.MoveCall = cMoveEggCarried // change move call
    egg.pointee.Flag.0 = 1 // CanResetEgg: we can now reset it when needed
    egg.pointee.SpecialF.0 = 15.0 // ResetEggDelay

    PlayEffect_Parms3D(Int16(EFFECT_GRABEGG), &gCoord, UInt32(NORMAL_CHANNEL_RATE), 0.6)
    PlayRumbleEffect(Int16(EFFECT_GRABEGG), Int32(playerNum))
}

// MARK: - Move Egg: Carried

private let cMoveEggCarried: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { eggOpt in
    guard let egg = eggOpt else { return }
    let playerNum = egg.pointee.PlayerNum // which player # is carrying this egg?
    let player = GetPlayerInfoEntry(Int32(playerNum))!.pointee.objNode! // get holding player obj

    // ALIGN EGG IN PLAYER'S GRASP

    UpdateCarriedObject(player, egg)

    // SEE IF AUTOMATICALLY THROW INTO WORMHOLE
    //
    // In addition to having manual control over dropping eggs (see below),
    // the eggs will automatically release themselves from the player's grasp
    // if a wormhole is detected to be within range.

    if let wormhole = FindClosestEggWormholeInRange(Int16(egg.pointee.Kind), &egg.pointee.Coord) { // find closest in-range wormhole
        let nest = egg.pointee.ChainHead!

        nest.pointee.ChainNode = nil // detach egg from the nest
        egg.pointee.ChainHead = nil
        nest.pointee.TerrainItemPtr!.pointee.flags |= UInt16(ITEM_FLAGS_USER1) // set flag so nest knows the egg is gone forever

        egg.pointee.SpecialPtr.0 = UnsafeMutableRawPointer(wormhole) // Wormhole
        egg.pointee.MoveCall = cMoveEggIntoWormhole
        egg.pointee.Delta.x = 0
        egg.pointee.Delta.y = 0
        egg.pointee.Delta.z = 0
        egg.pointee.Speed = player.pointee.Speed
        GetPlayerInfoEntry(Int32(playerNum))!.pointee.carriedObj = nil // player not holding anything
        return
    }

    // SEE IF PLAYER DROP EGG

    if SwIsNeedDown(Int(kNeed_Drop), Int(playerNum)) { // is drop button pressed?
        DropEgg_NoWormhole(Int16(playerNum))
    }
}

// Does a generic drop of the egg - when it doesn't need to
// go into a wormhole.
@c @implementation
public func DropEgg_NoWormhole(_ playerNum: Int16) {
    let playerInfo = GetPlayerInfoEntry(Int32(playerNum))!
    if let egg = playerInfo.pointee.carriedObj { // get egg
        egg.pointee.Timer = 1.0 // DelayUntilCanPickup: delay until can be picked back up
        egg.pointee.MoveCall = cMoveEggNotCarried
        egg.pointee.Delta.x = playerInfo.pointee.objNode!.pointee.Delta.x * 0.8 // match player's delta minus some friction
        egg.pointee.Delta.y = playerInfo.pointee.objNode!.pointee.Delta.y * 0.8
        egg.pointee.Delta.z = playerInfo.pointee.objNode!.pointee.Delta.z * 0.8
        playerInfo.pointee.carriedObj = nil // player not holding anything
    }
}

// MARK: - Move Egg: Into Wormhole

private let cMoveEggIntoWormhole: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { eggOpt in
    guard let egg = eggOpt else { return }
    let fps = gFramesPerSecondFrac
    let wormhole = egg.pointee.SpecialPtr.0!.assumingMemoryBound(to: ObjNode.self)

    GetObjectInfo(egg)

    // CALC VECTOR TO JOINT

    var jointCoord = OGLPoint3D()
    FindCoordOfJoint(wormhole, Int(egg.pointee.Special.1), &jointCoord)
    var v2raw = OGLVector3D()
    v2raw.x = jointCoord.x - gCoord.x
    v2raw.y = jointCoord.y - gCoord.y
    v2raw.z = jointCoord.z - gCoord.z
    var v2 = OGLVector3D()
    OGLVector3D_Normalize(&v2raw, &v2)

    let dist = OGLPoint3D_Distance(&gCoord, &jointCoord) // get current dist to joint

    // MOVE IT

    gDelta.x = v2.x * egg.pointee.Speed // move toward the joint
    gDelta.y = v2.y * egg.pointee.Speed
    gDelta.z = v2.z * egg.pointee.Speed

    gCoord.x += gDelta.x * fps
    gCoord.y += gDelta.y * fps
    gCoord.z += gDelta.z * fps

    // SEE IF TIME TO DO NEXT JOINT

    let dist2 = OGLPoint3D_Distance(&gCoord, &jointCoord)
    if (dist2 > dist) || (dist2 < 40.0) { // if dist suddenly got larger, then we must have overshot the coord, or see if in range of joint
        egg.pointee.Special.1 += 1 // TargetJoint++

        if egg.pointee.Special.1 == 1 {
            PlayEffect3D(Int16(EFFECT_EGGINTOWORMHOLE), &gCoord)
            PlayRumbleEffect(Int16(EFFECT_EGGINTOWORMHOLE), Int32(egg.pointee.PlayerNum))
        }

        if egg.pointee.Special.1 >= Int(wormhole.pointee.Skeleton!.pointee.skeletonDefinition!.pointee.NumBones) {
            eggWasRetrieved(egg)
            return
        }
    }

    egg.pointee.Speed += 500.0 * fps // accelerate
    if egg.pointee.Speed > 1500.0 {
        egg.pointee.Speed = 1500.0
    }

    egg.pointee.Rot.x += fps * 4.5
    egg.pointee.Rot.z += fps * 2.4

    // SHRINK AWAY

    if egg.pointee.Special.1 > 0 { // only shrink once reached wormhole mouth
        egg.pointee.Scale.z -= fps * 0.5
        egg.pointee.Scale.y = egg.pointee.Scale.z
        egg.pointee.Scale.x = egg.pointee.Scale.z
        if egg.pointee.Scale.x <= 0.0 {
            eggWasRetrieved(egg)
            return
        }
    }

    // UPDATE

    UpdateObject(egg)
}

// Called after an egg has completed its travel thru the wormhole,
// and now we're ready to count it as saved.
private func eggWasRetrieved(_ egg: UnsafeMutablePointer<ObjNode>) {
    var gotAllEggs = true

    // INC COUNTER

    GetNumEggsSavedSlot(egg.pointee.Kind)!.pointee += 1

    // START BLINKING EGG IN INFOBAR

    HighlightInfobarEgg(egg.pointee.Kind)

    // SEE IF WE GOT ALL THE EGGS WE NEED

    switch gVSMode {
    // HANDLE REGULAR ADVENTURE MODE

    case .none:
        for (i, _) in EggColor.allCases.enumerated() {
            if GetNumEggsToSaveSlot(Int32(i))!.pointee > 0 { // do we need to get this color?
                if GetNumEggsSavedSlot(Int32(i))!.pointee < GetNumEggsToSaveSlot(Int32(i))!.pointee { // did we get them all?
                    gotAllEggs = false
                    break
                }
            }
        }

        if gotAllEggs {
            gOpenPlayerWormhole = 1
        }

    // CAPTURE THE FLAG MODE

    case .captureTheFlag:
        if gLevelCompleted == 0 { // ignore any more eggs if someone already won
            // SEE IF PLAYER 1 WON

            if GetNumEggsSavedSlot(1)!.pointee >= GetNumEggsToSaveSlot(1)!.pointee { // did we get all of P2's eggs?
                _ = ShowWinLose(0, 0) // won!
                _ = ShowWinLose(1, 1) // lost
                StartLevelCompletion(5.0)
            }

            // SEE IF PLYAER 2 WON

            else if GetNumEggsSavedSlot(0)!.pointee >= GetNumEggsToSaveSlot(0)!.pointee { // did we get all of P1's eggs?
                _ = ShowWinLose(1, 0) // won!
                _ = ShowWinLose(0, 1) // lost
                StartLevelCompletion(5.0)
            }
        }

    default:
        break
    }

    DeleteObject(egg) // note: also deletes the light beam that's chained onto this
}
