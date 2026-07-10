// Player_Terrain.swift - Port of Player_Terrain.c to Swift
//
// gTargetMaxSpeed/gCurrentMaxSpeed are native Swift storage now (converted
// 2026-07-07): nothing in any .c file touches them anymore.
// GetTargetMaxSpeed/SetTargetMaxSpeed/GetCurrentMaxSpeed/SetCurrentMaxSpeed
// (formerly shims in PlayerInternal.h) are now plain Swift functions with
// the same names/signatures.


func GetTargetMaxSpeed(_ i: Int32) -> Float { gEngine.player.targetMaxSpeed[Int(i)] }
func SetTargetMaxSpeed(_ i: Int32, _ v: Float) { gEngine.player.targetMaxSpeed[Int(i)] = v }
func GetCurrentMaxSpeed(_ i: Int32) -> Float { gEngine.player.currentMaxSpeed[Int(i)] }
func SetCurrentMaxSpeed(_ i: Int32, _ v: Float) { gEngine.player.currentMaxSpeed[Int(i)] = v }

private let flightSlideFactor: Float = 15.0 // smaller == more slide, larger = less slide
private let flightTurnSensitivity: Float = 1.9 // smaller == slower turns, larger == faster turns

private let maxFlightZRot: Float = (Float.pi / 2.0 * 0.6)

private let defaultPlayerShadowScale: Float = 8.0

private let playerMinSpeed: Float = 650.0


private let gJetpackButtOff = OGLPoint3D(x: 0, y: 11.3, z: 33)

@inline(__always) private func sparklesBase(_ n: UnsafeMutablePointer<ObjNode>) -> UnsafeMutablePointer<Int16> {
    UnsafeMutableRawPointer(n.pointer(to: \.Sparkles)!).assumingMemoryBound(to: Int16.self)
}

@inline(__always) private func overrideTextureBase(_ skelObjData: UnsafeMutablePointer<SkeletonObjDataType>) -> UnsafeMutablePointer<UnsafeMutablePointer<MOMaterialObject>?> {
    UnsafeMutableRawPointer(skelObjData.pointer(to: \.overrideTexture)!).assumingMemoryBound(to: UnsafeMutablePointer<MOMaterialObject>?.self)
}

// MARK: - Create player model: terrain

// Creates an ObjNode for the player
//
// INPUT:
//			where = floor coord where to init the player.
//			rotY = rotation to assign to player if oldObj is nil.
func CreatePlayerObject(_ playerNum: Int16, _ where_: UnsafeMutablePointer<OGLPoint3D>?, _ rotY: Float) {
    let where_ = where_!

    // MAKE SKELETON

    var def = NewObjectDefinitionType()
    def.type = UInt8(SkeletonType.player.rawValue)
    def.animNum = UInt8(PlayerAnim.flap.rawValue)
    def.coord.x = where_.pointee.x
    def.coord.z = where_.pointee.z
    def.coord.y = FindHighestCollisionAtXZ(where_.pointee.x, where_.pointee.z, UInt32(CTYPE_MISC | CTYPE_TERRAIN)) + 500
    def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_NOTEXTUREWRAP | STATUS_BIT_ROTXZY)
    def.slot = Int16(PLAYER_SLOT)
    def.moveCall = cMovePlayer
    def.drawCall = cDrawPlayer
    def.rot = rotY
    def.scale = PLAYER_DEFAULT_SCALE

    let newObj = MakeNewSkeletonObject(&def)!
    newObj.pointee.PlayerNum = UInt8(playerNum)

    def.drawCall = nil // clear draw call for jetpack et al.

    // SET COLLISION INFO

    gEngine.player.playerBottomOff = newObj.pointee.LocalBBox.min.y // calc offset to bottom for collision function later

    newObj.pointee.CType = UInt32(CTYPE_PLAYER1) << UInt32(playerNum)
    newObj.pointee.CBits = UInt32(CBITS_ALLSOLID)
    SetObjectCollisionBounds(newObj, 40, newObj.pointee.LocalBBox.min.y, -40, 40, 40, -40)

    newObj.pointee.HitByWeaponHandler = cPlayerHitByWeaponCallback

    // SET HOT-SPOT FOR AUTO TARGETING WEAPONS

    newObj.pointee.HeatSeekHotSpotOff.x = 0
    newObj.pointee.HeatSeekHotSpotOff.y = 0
    newObj.pointee.HeatSeekHotSpotOff.z = -80

    newObj.pointee.Special.5 = -1 // SmokeParticleGroup

    // SET OVERRIDE TEXTURE FOR PLAYER 2

    if playerNum > 0 {
        if GetNumSpritesInGroup(Int32(SPRITE_GROUP_P2SKIN)) == 0 {
            LoadSpriteGroupFromFile(Int32(SPRITE_GROUP_P2SKIN), ":Sprites:textures:player2", 0)
        }

        overrideTextureBase(newObj.pointee.Skeleton!)[0] = GetSpriteGroupPtr(Int32(SPRITE_GROUP_P2SKIN))![0].materialObject?.assumingMemoryBound(to: MOMaterialObject.self)
    }

    // MAKE JETPACK

    def.group = UInt8(MODEL_GROUP_PLAYER)
    def.type = UInt8(PLAYER_ObjType_JetPack)
    def.flags = gAutoFadeStatusBits
    def.slot += 1
    def.moveCall = MovePlayerJetpack
    def.drawCall = nil
    let jetpack = MakeNewDisplayGroupObject(&def)!

    newObj.pointee.ChainNode = jetpack
    jetpack.pointee.ChainHead = newObj

    // BLUE THING

    def.type = UInt8(PLAYER_ObjType_JetPackBlue)
    def.flags = gAutoFadeStatusBits | UInt32(STATUS_BIT_UVTRANSFORM | STATUS_BIT_GLOW | STATUS_BIT_NOLIGHTING)
    def.slot += 1
    def.moveCall = nil
    let blue = MakeNewDisplayGroupObject(&def)!

    blue.pointee.ColorFilter.a = 0.99
    jetpack.pointee.ChainNode = blue
    blue.pointee.ChainHead = jetpack

    // MAKE SPARKLES FOR GUN TURRETS

    let sparkleOff = [
        OGLPoint3D(x: 21.21, y: 19.068, z: 21.183),
        OGLPoint3D(x: -21.21, y: 19.068, z: 21.183),
    ]

    for j in 0..<2 {
        let i = GetFreeSparkle(jetpack)
        sparklesBase(jetpack)[j] = i
        if i != -1 {
            let sparkle = GetSparkleSlot(Int32(i))!

            sparkle.pointee.flags = UInt32(SPARKLE_FLAG_OMNIDIRECTIONAL | SPARKLE_FLAG_TRANSFORMWITHOWNER)
            sparkle.pointee.where = sparkleOff[j]

            sparkle.pointee.color.r = 1
            sparkle.pointee.color.g = 1
            sparkle.pointee.color.b = 1
            sparkle.pointee.color.a = 1

            sparkle.pointee.scale = 15.0
            sparkle.pointee.separation = 15.0

            sparkle.pointee.textureNum = Int16(PARTICLE_SObjType_GreenGlint)
        }
    }

    // SET OTHER STUFF

    SetTargetMaxSpeed(Int32(playerNum), PLAYER_NORMAL_MAX_SPEED)
    SetCurrentMaxSpeed(Int32(playerNum), PLAYER_NORMAL_MAX_SPEED)

    let pi = GetPlayerInfoEntry(Int32(playerNum))
    pi.pointee.objNode = newObj
    pi.pointee.coord = newObj.pointee.Coord

    _ = AttachShadowToObject(newObj, .square, defaultPlayerShadowScale, defaultPlayerShadowScale * 1.1, 1) // NOTE: original C passed GLOBAL_SObjType_Shadow_Nano (=3), which numerically equals SHADOW_TYPE_SQUARE

    // SET COLLISION FOR VS MODES
    //
    // In VS. modes the players can collide with each other, so
    // set triggers on the players.

    if gVSMode != .none {
        newObj.pointee.CType |= UInt32(CTYPE_TRIGGER)
        newObj.pointee.CBits |= UInt32(CBITS_ALWAYSTRIGGER)
        newObj.pointee.TriggerCallback = cDoTrig_Player
    }

    if gTimeDemo != 0 {
        HidePlayer(newObj)
    }
}

// MARK: - Move player

private let cMovePlayer: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }

    if gTimeDemo != 0 {
        return
    }

    theNode.getInfo()

    // JUMP TO HANDLER

    let animNum = UInt32(theNode.pointee.Skeleton!.pointee.AnimNum)
    switch PlayerAnim(rawValue: animNum) {
    case .flap, .flapWithEgg, .coasting, .none: // .none covers AnimNum 13 ("xxxx", a dead slot in the original move table)
        MovePlayer_Flying(theNode)
    case .bankLeft, .bankLeftEgg, .bankRight, .bankRightEgg:
        MovePlayer_Banking(theNode)
    case .deathDive:
        MovePlayer_DeathDive(theNode)
    case .appearWormhole:
        MovePlayer_AppearWormhole(theNode)
    case .readyToGrab:
        MovePlayer_ReadyToGrab(theNode)
    case .enterWormhole:
        MovePlayer_EnterWormhole(theNode)
    case .disoriented:
        MovePlayer_FlyingDisoriented(theNode)
    case .dustDevil:
        MovePlayer_DustDevil(theNode)
    }
}

// MARK: - Move player: flying

private func MovePlayer_Flying(_ theNode: UnsafeMutablePointer<ObjNode>) {
    // MOVE PLAYER

    // DO MOTION CONTROLS

    DoPlayerFlightControls(theNode)

    // DO ACTION CONTROL

    CheckPlayerActionControls(theNode)

    // SET APPROPRIATE ANIM

    let pi = GetPlayerInfoEntry(Int32(theNode.pointee.PlayerNum))
    if pi.pointee.carriedObj != nil {
        SetPlayerFlyingAnim_WithEgg(theNode)
    } else {
        SetPlayerFlyingAnim(theNode)
    }

    // MOVE & COLLIDE

    _ = DoPlayerMovementAndCollision(theNode, 0)

    // UPDATE IT

    UpdatePlayer(theNode)
}

// MARK: - Move player: banking

private func MovePlayer_Banking(_ theNode: UnsafeMutablePointer<ObjNode>) {
    theNode.pointee.Skeleton!.pointee.AnimSpeed = 1.5
    MovePlayer_Flying(theNode)
}

// MARK: - Move player: ready to grab

private func MovePlayer_ReadyToGrab(_ theNode: UnsafeMutablePointer<ObjNode>) {
    theNode.pointee.Skeleton!.pointee.AnimSpeed = 1.7

    MovePlayer_Flying(theNode)
}

// MARK: - Move player: flying disoriented

private func MovePlayer_FlyingDisoriented(_ theNode: UnsafeMutablePointer<ObjNode>) {
    // SEE IF STOP DISORIENTATION

    if theNode.pointee.Skeleton!.animHasStopped {
        SetPlayerFlyingAnim(theNode)
    }

    // MOVE PLAYER

    // DO MOTION CONTROLS

    DoPlayerFlightControls(theNode)

    // DO ACTION CONTROL

    CheckPlayerActionControls(theNode)

    // MOVE & COLLIDE

    _ = DoPlayerMovementAndCollision(theNode, 0)

    // UPDATE IT

    UpdatePlayer(theNode)
}

// MARK: - Move player: death dive

private func MovePlayer_DeathDive(_ player: UnsafeMutablePointer<ObjNode>) {
    let fps = gFramesPerSecondFrac

    gEngine.objects.delta.y -= 800.0 * fps
    gEngine.objects.delta.applyFrictionXZ(300) // air friction

    // MOVE IT

    gEngine.objects.coord.x += gEngine.objects.delta.x * fps
    gEngine.objects.coord.y += gEngine.objects.delta.y * fps
    gEngine.objects.coord.z += gEngine.objects.delta.z * fps

    // TILT TO NOSE DIVE

    player.pointee.Rot.z = DecayToZero(player.pointee.Rot.z, fps * 0.5)

    // SEE IF HIT GROUND

    if gEngine.objects.coord.y < GetTerrainY(gEngine.objects.coord.x, gEngine.objects.coord.z) {
        ExplodePlayer(player, Int16(player.pointee.PlayerNum), &gEngine.objects.coord)
    }

    UpdatePlayer(player)
}

// MARK: - Move player: appear wormhole

private func MovePlayer_AppearWormhole(_ player: UnsafeMutablePointer<ObjNode>) {
    let fps = gFramesPerSecondFrac
    let playerNum = Int32(player.pointee.PlayerNum)

    // SLOW DOWN

    player.pointee.Speed -= 500.0 * fps
    if player.pointee.Speed < playerMinSpeed {
        player.pointee.Speed = playerMinSpeed
    }

    // CALC NEW DELTA

    gEngine.objects.delta = gEngine.objects.delta.normalized()
    gEngine.objects.delta.x *= player.pointee.Speed
    gEngine.objects.delta.y *= player.pointee.Speed
    gEngine.objects.delta.z *= player.pointee.Speed

    // MOVE

    gEngine.objects.coord.x += gEngine.objects.delta.x * fps
    gEngine.objects.coord.y += gEngine.objects.delta.y * fps
    gEngine.objects.coord.z += gEngine.objects.delta.z * fps

    // ARE WE OUT OF THE WORMHOLE?

    if gEngine.objects.coord.y < (GetTerrainY(gEngine.objects.coord.x, gEngine.objects.coord.z) + MAX_ALTITUDE_DIFF) {
        SetCurrentMaxSpeed(playerNum, -gEngine.objects.delta.y) // match speeds when exiting wormhole
        MorphToSkeletonAnim(player.pointee.Skeleton, .flap, 2)
        _ = FadePlayer(player, 1.0) // make sure totally faded in
    }

    // FADE IN

    _ = FadePlayer(player, 0.4 * fps)

    UpdatePlayer(player)
}

// MARK: - Move player: enter wormhole

// Make player fly into the wormhole
private func MovePlayer_EnterWormhole(_ player: UnsafeMutablePointer<ObjNode>) {
    let fps = gFramesPerSecondFrac

    // SEE IF GO STRAIGHT UP

    let dist = gEngine.objects.coord.distance(to: gExitWormhole!.pointee.Coord) // get current dist to joint
    if dist < 50.0 {
        let up = OGLVector3D(x: 0, y: 1, z: 0)
        player.pointee.MotionVector = up.transformed(by: gExitWormhole!.pointee.BaseTransformMatrix) // make aim up wormhole
    }

    // MOVE IT

    gEngine.objects.delta.x = player.pointee.MotionVector.x * player.pointee.Speed // move toward the joint
    gEngine.objects.delta.y = player.pointee.MotionVector.y * player.pointee.Speed
    gEngine.objects.delta.z = player.pointee.MotionVector.z * player.pointee.Speed

    gEngine.objects.coord.x += gEngine.objects.delta.x * fps
    gEngine.objects.coord.y += gEngine.objects.delta.y * fps
    gEngine.objects.coord.z += gEngine.objects.delta.z * fps

    // ROTATE UP

    player.pointee.Rot.x += fps * 2.0
    if player.pointee.Rot.x > Float.pi / 2.2 {
        player.pointee.Rot.x = Float.pi / 2.2
    }

    player.pointee.Rot.z = DecayToZero(player.pointee.Rot.z, Float.pi * fps)

    player.pointee.Speed += 200.0 * fps

    // FADE OUT

    if FadePlayer(player, -0.3 * fps) != 0 {
        StartLevelCompletion(2.0)
    }

    // SHRINK

    player.pointee.Scale.x -= fps * 0.5
    var s = player.pointee.Scale.x
    if s < 0.0 {
        s = 0.0
        StartLevelCompletion(2.0)
    }

    player.pointee.Scale.x = s
    player.pointee.Scale.y = s
    player.pointee.Scale.z = s

    UpdatePlayer(player)
}

// MARK: - Move player: dust devil

private func MovePlayer_DustDevil(_ player: UnsafeMutablePointer<ObjNode>) {
    let fps = gFramesPerSecondFrac
    let p = Int32(player.pointee.PlayerNum)
    let pi = GetPlayerInfoEntry(p)
    let radius = pi.pointee.radiusFromDustDevil
    let devil = pi.pointee.dustDevilObj! // get dust devil objNode

    player.pointee.Timer -= fps

    // SPIN PLAYER

    if player.pointee.Timer > 0.0 {
        if PlayerLoseHealth(Int16(p), 0.04 * fps, .explode, &gEngine.objects.coord, 0) != 0 { // lose some health while spinning
            return
        }

        // ACCELERATE SPIN

        pi.pointee.dustDevilRotSpeed += fps * SwPI2
        if pi.pointee.dustDevilRotSpeed > (4000.0 / radius) {
            pi.pointee.dustDevilRotSpeed = (4000.0 / radius)
        }

        // SPIN

        pi.pointee.dustDevilRot += pi.pointee.dustDevilRotSpeed * fps
        let r = pi.pointee.dustDevilRot

        gEngine.objects.coord.x = devil.pointee.Coord.x - sin(r) * radius
        gEngine.objects.coord.z = devil.pointee.Coord.z - cos(r) * radius

        // ROTATE TO AIM

        player.pointee.Rot.y += fps * 9.0
    }

    // EJECT PLAYER

    else {
        // CALC EJECTION TRAJECTORY

        if pi.pointee.ejectedFromDustDevil == 0 {
            let speed: Float = 3000.0
            var v = OGLVector3D()
            let up = OGLVector3D(x: 0, y: 1, z: 0)

            v.x = gEngine.objects.coord.x - devil.pointee.Coord.x // calc vector from devil to player
            v.z = gEngine.objects.coord.z - devil.pointee.Coord.z
            FastNormalizeVector(v.x, 0, v.z, &v)

            v = up.cross(v) // calc cross product to get ejection vector

            gEngine.objects.delta.x = v.x * speed // calc delta
            gEngine.objects.delta.y = 0
            gEngine.objects.delta.z = v.z * speed

            player.pointee.Speed = speed // set player speeds
            SetCurrentMaxSpeed(p, speed)

            pi.pointee.ejectedFromDustDevil = 1

            player.pointee.Rot.y = CalcYAngleFromPointToPoint(0, gEngine.objects.coord.x, gEngine.objects.coord.z, gEngine.objects.coord.x + v.x, gEngine.objects.coord.z + v.z)
        }

        // MOVE

        gEngine.objects.coord.x += gEngine.objects.delta.x * fps
        gEngine.objects.coord.y += gEngine.objects.delta.y * fps
        gEngine.objects.coord.z += gEngine.objects.delta.z * fps
    }

    UpdatePlayer(player)

    // SEE IF DONE

    if player.pointee.Timer <= -0.3 {
        DisorientPlayer(player)
    }
}

// MARK: - Update player

private func UpdatePlayer(_ theNode: UnsafeMutablePointer<ObjNode>) {
    let fps = gFramesPerSecondFrac
    let playerNum = Int32(theNode.pointee.PlayerNum)

    // UPDATE CURRENT MAX SPEED

    if gVSMode == .race {
        let pi0 = GetPlayerInfoEntry(0)
        let pi1 = GetPlayerInfoEntry(1)
        let dist = pi0.pointee.coord.distance(to: pi1.pointee.coord)

        let pi = GetPlayerInfoEntry(playerNum)
        if pi.pointee.jetpackActive == 0 {
            SetTargetMaxSpeed(playerNum, PLAYER_NORMAL_MAX_SPEED)

            if dist > 2000.0 {
                if pi.pointee.place == 1 {
                    SetTargetMaxSpeed(playerNum, PLAYER_NORMAL_MAX_SPEED * 1.25)
                }
            }
        }

        if theNode.pointee.Speed < GetCurrentMaxSpeed(playerNum) {
            theNode.pointee.Speed = GetCurrentMaxSpeed(playerNum)
        }
    }

    // NEED TO SLOW TO TARGET SPEED

    if GetCurrentMaxSpeed(playerNum) > GetTargetMaxSpeed(playerNum) {
        var v = GetCurrentMaxSpeed(playerNum)
        v -= fps * 600.0
        if v < GetTargetMaxSpeed(playerNum) {
            v = GetTargetMaxSpeed(playerNum)
        }
        SetCurrentMaxSpeed(playerNum, v)
    }

    // NEED TO SPEEDUP TO TARGET SPEED

    else if GetCurrentMaxSpeed(playerNum) < GetTargetMaxSpeed(playerNum) {
        var v = GetCurrentMaxSpeed(playerNum)
        v += fps * 800.0
        if v > GetTargetMaxSpeed(playerNum) {
            v = GetTargetMaxSpeed(playerNum)
        }
        SetCurrentMaxSpeed(playerNum, v)
    }

    // UPDATE OBJECT AS LONG AS NOT BEING MATRIX CONTROLLED

    theNode.update()

    let pi = GetPlayerInfoEntry(playerNum)
    pi.pointee.coord = gEngine.objects.coord // update player coord

    // CHECK INV TIMER

    pi.pointee.invincibilityTimer -= fps

    // SEE IF CROSSED ANY LINE MARKERS

    switch gLevelNum {
    case Int16(LevelNum.race1.rawValue), Int16(LevelNum.race2.rawValue): // call special line marker function for race modes
        theNode.updatePlayerRaceMarkers()
    default:
        HandlePlayerLineMarkerCrossing(theNode)
    }

    // UPDATE CONTRAILS

    UpdatePlayerContrails(theNode)

    // UPDATE CROSSHAIRS

    UpdatePlayerCrosshairs(theNode)

    // UPDATE SHIELD

    UpdatePlayerShield(Int16(playerNum))

    // MAKE SMOKE TRAIL IF HURT

    if !gGamePrefs.isLowRenderQuality && pi.pointee.health < 0.33 {
        MakePlayerSmoke(theNode)
    }

    // HIDE SMOKE TRAIL IF FIRST-PERSON

    let particleGroup = Int16(theNode.pointee.Special.5) // SmokeParticleGroup
    let magicNum = UInt32(theNode.pointee.Special.4) // SmokeParticleMagic

    if particleGroup != -1 && VerifyParticleGroupMagicNum(particleGroup, magicNum) != 0 {
        if GetCameraMode(playerNum) == UInt8(CameraMode.firstPerson.rawValue) {
            SetParticleGroupVisiblePanes(particleGroup, playerNum != 0, playerNum != 1)
        } else {
            SetParticleGroupVisiblePanes(particleGroup, true, true)
        }
    }
}

// MARK: - Make player smoke

private func MakePlayerSmoke(_ theNode: UnsafeMutablePointer<ObjNode>) {
    let fps = gFramesPerSecondFrac

    theNode.pointee.SpecialF.4 -= fps // SmokeTimer: see if add smoke
    if theNode.pointee.SpecialF.4 <= 0.0 {
        theNode.pointee.SpecialF.4 += 0.02 // reset timer

        var particleGroup = Int16(theNode.pointee.Special.5) // SmokeParticleGroup
        let magicNum = UInt32(theNode.pointee.Special.4) // SmokeParticleMagic

        if (particleGroup == -1) || (VerifyParticleGroupMagicNum(particleGroup, magicNum) == 0) {
            let newMagicNum = MyRandomLong()
            theNode.pointee.Special.4 = Int(newMagicNum) // SmokeParticleMagic

            var groupDef = NewParticleGroupDefType()
            groupDef.magicNum = newMagicNum
            groupDef.particleType = .fallingSparks
            groupDef.flags = UInt32(PARTICLE_FLAGS_DONTCHECKGROUND | PARTICLE_FLAGS_ALLAIM)
            groupDef.gravity = 0
            groupDef.magnetism = 0
            groupDef.baseScale = 9.0
            groupDef.decayRate = -0.4
            groupDef.fadeRate = 0.6
            groupDef.particleTextureNum = UInt8(PARTICLE_SObjType_BlackSmoke)
            groupDef.srcBlend = GL_SRC_ALPHA
            groupDef.dstBlend = GL_ONE_MINUS_SRC_ALPHA
            particleGroup = NewParticleGroup(&groupDef)
            theNode.pointee.Special.5 = Int(particleGroup) // SmokeParticleGroup
        }

        if particleGroup != -1 {
            let x = gEngine.objects.coord.x
            let y = gEngine.objects.coord.y
            let z = gEngine.objects.coord.z

            for _ in 0..<2 {
                var p = OGLPoint3D()
                p.x = x + RandomFloat2() * 20.0
                p.y = y + RandomFloat2() * 20.0
                p.z = z + RandomFloat2() * 20.0

                var d = OGLVector3D()
                d.x = RandomFloat2() * 20.0
                d.y = RandomFloat2() * 20.0
                d.z = RandomFloat2() * 20.0

                var newParticleDef = NewParticleDefType()
                newParticleDef.groupNum = particleGroup
                newParticleDef.scale = RandomFloat() + 1.0
                newParticleDef.rotZ = RandomFloat() * SwPI2
                newParticleDef.rotDZ = RandomFloat2()
                newParticleDef.alpha = 0.9

                let stop: Bool = withUnsafeMutablePointer(to: &p) { pPtr in
                    withUnsafeMutablePointer(to: &d) { dPtr in
                        newParticleDef.where = pPtr
                        newParticleDef.delta = dPtr
                        return AddParticleToGroup(&newParticleDef) != 0
                    }
                }
                if stop {
                    theNode.pointee.Special.5 = -1 // SmokeParticleGroup
                    break
                }
            }
        }
    }
}

// MARK: - Draw player

private let cDrawPlayer: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }
    let playerNum = Int32(theNode.pointee.PlayerNum)

    if (GetCameraMode(playerNum) != UInt8(CameraMode.firstPerson.rawValue)) || (gCurrentSplitScreenPane != theNode.pointee.PlayerNum) {
        theNode.drawSkeleton()
    }

    // DRAW TARGETING FOR 2P MODES
    //
    // This draws the orange ring around the other player so that
    // we can see him more easily.

    if gVSMode != .none {
        if gCurrentSplitScreenPane != theNode.pointee.PlayerNum { // if we're drawing the "other" player...
            let otherPi = GetPlayerInfoEntry(Int32(gCurrentSplitScreenPane))
            var size = theNode.pointee.Coord.distance(to: otherPi.pointee.coord) * 0.12
            if size > 600.0 {
                size = 600.0
            }

            if size > 110.0 {
                var m = OGLMatrix4x4()

                let gUpValue = gUp
                withUnsafePointer(to: gUpValue) {
                    SetLookAtMatrixAndTranslate(&m, $0, &theNode.pointee.Coord, &otherPi.pointee.camera.cameraLocation)
                }

                OGL_PushState()
                withUnsafePointer(to: m.value) {
                    $0.withMemoryRebound(to: Float.self, capacity: 16) {
                        gEngine.renderer.multMatrix($0)
                    }
                }

                let mo = GetSpriteGroupPtr(Int32(SPRITE_GROUP_INFOBAR))![Int(INFOBAR_SObjType_GunSight_OuterRing)].materialObject!.assumingMemoryBound(to: MOMaterialObject.self)
                MO_DrawMaterial(mo) // activate material

                OGL_DisableCullFace()
                OGL_DisableLighting()
                OGL_DisableFog()
                gGlobalTransparency = 1.0

                gEngine.renderer.beginImmediate(.quads)
                gEngine.renderer.texCoord2f(0, 0); gEngine.renderer.vertex2f(-size, -size)
                gEngine.renderer.texCoord2f(0, 1); gEngine.renderer.vertex2f(-size, size)
                gEngine.renderer.texCoord2f(1, 1); gEngine.renderer.vertex2f(size, size)
                gEngine.renderer.texCoord2f(1, 0); gEngine.renderer.vertex2f(size, -size)
                gEngine.renderer.endImmediate()

                OGL_PopState()
            }
        }
    }
}

// MARK: - Do player flight controls

// Handles the flight controls for the player based on the analogControl values.
private func DoPlayerFlightControls(_ player: UnsafeMutablePointer<ObjNode>) {
    let fps = gFramesPerSecondFrac
    let playerNum = Int32(player.pointee.PlayerNum)
    let pi = GetPlayerInfoEntry(playerNum)

    // SEE IF CONTROL IS ALLOWED RIGHT NOW

    if gVSMode == .race { // don't allow control while doing read-set-go for race start
        if gRaceReadySetGoTimer > 0.0 {
            return
        }
    }

    // DO SIDE-BANKING

    let sideBank = pi.pointee.analogControlX
    var rotZ = player.pointee.Rot.z

    // PULL BACK TO ZERO

    if fabsf(sideBank) < 0.1 { // only pull back if user isn't controlling
        var pull = fabsf(rotZ) * 1.5 // calc amount of roll-back based on z-rotaton:  more snap-back the steeper the rotation
        if pull < 0.1 {
            pull = 0.1
        }
        pull *= fps

        if rotZ > 0.0 {
            rotZ -= pull
            if rotZ < 0.0 {
                rotZ = 0.0
            }
        } else {
            rotZ += pull
            if rotZ > 0.0 {
                rotZ = 0.0
            }
        }
    }

    // ROTATE BASED ON USER DELTA

    rotZ += sideBank * fps * -1.8

    // CHECK FOR MAX PINNING

    if rotZ > maxFlightZRot {
        rotZ = maxFlightZRot
    } else if rotZ < -maxFlightZRot {
        rotZ = -maxFlightZRot
    }

    player.pointee.Rot.z = rotZ

    // DO PITCH-YAW

    var pitch = pi.pointee.analogControlZ
    if pitch > 0 {
        if gEngine.objects.coord.y > (CalcPlayerMaxAltitude(gEngine.objects.coord.x, gEngine.objects.coord.z) - 150.0) { // see if we're near the max altitude
            pitch = 0
        }
    }

    var rotX = player.pointee.Rot.x

    // PULL BACK TO ZERO

    if fabsf(pitch) < 0.1 {
        var pull = fabsf(rotX) * 0.8 // calc amount of roll-back based on x-rotaton:  more snap-back the steeper the rotation
        pull *= fps

        if rotX > 0.0 {
            rotX -= pull
            if rotX < 0.0 {
                rotX = 0.0
            }
        } else {
            rotX += pull
            if rotX > 0.0 {
                rotX = 0.0
            }
        }
    }

    // ROTATE BASED ON USER DELTA

    rotX += pitch * fps * 1.4

    // CHECK FOR MAX PINNING

    if rotX > (Float.pi / 3) {
        rotX = Float.pi / 3
    } else if rotX < (-Float.pi / 1.9) {
        rotX = -Float.pi / 1.9
    }

    player.pointee.Rot.x = rotX

    // DO Y-AXIS ROTATION

    player.pointee.Rot.y += rotZ * fps * flightTurnSensitivity

    player.updateTransforms() // update the matrix so that it's accurate when we do our move
}

// MARK: - Check player action controls

// Checks for special action controls
//
// INPUT:	theNode = the node of the player
private func CheckPlayerActionControls(_ player: UnsafeMutablePointer<ObjNode>) {
    let playerNum = Int32(player.pointee.PlayerNum)

    // SEE IF CONTROL IS ALLOWED RIGHT NOW

    if gVSMode == .race { // don't allow control while doing read-set-go for race start
        if gRaceReadySetGoTimer > 0.0 {
            return
        }
    }

    // SEE IF CHANGE WEAPON SELECTION

    // SEE IF SELECT NEXT WEAPON

    if SwIsNeedDown(Int(kNeed_NextWeapon), Int(playerNum)) { // is Next button pressed?
        SelectNextWeapon(Int16(playerNum), 1, 1)
        SetAutoFireDelay(playerNum, 0)
    } else if SwIsNeedDown(Int(kNeed_PrevWeapon), Int(playerNum)) {
        SelectNextWeapon(Int16(playerNum), 1, -1)
        SetAutoFireDelay(playerNum, 0)
    }

    // SEE IF NEW FIRE BUTTON

    switch GetNeedState(Int32(kNeed_Fire), playerNum) {
    case Int32(KEYSTATE_DOWN):
        PlayerFireButtonPressed(player, 1) // pass the newButtonPressed flag for handlers that don't auto-fire
    case Int32(KEYSTATE_HELD):
        PlayerFireButtonPressed(player, 0)
    case Int32(KEYSTATE_UP):
        PlayerFireButtonReleased(player)
    default:
        SetAutoFireDelay(playerNum, 0) // not pressing Fire button, so clear auto-fire delay timer
    }

    // SEE IF JETPACK BUTTON

    if SwIsNeedActive(Int(kNeed_Jetpack), Int(playerNum)) { // is jetpack button pressed?
        PlayerJetpackButtonPressed(player, Int16(playerNum))
    } else {
        JetpackOff(Int16(playerNum))
    }
}

// MARK: - Player jetpack button pressed

private func PlayerJetpackButtonPressed(_ player: UnsafeMutablePointer<ObjNode>, _ playerNum: Int16) {
    let fps = gFramesPerSecondFrac
    let pi = GetPlayerInfoEntry(Int32(playerNum))

    // DO WE HAVE FUEL?

    if pi.pointee.jetpackFuel <= 0.0 {
        JetpackOff(playerNum)
        return
    }

    // IF NEW THEN MAKE POOF
    if pi.pointee.jetpackActive == 0 {
        PlayEffect_Parms3D(Int16(EFFECT_JETPACKIGNITE), &gEngine.objects.coord, UInt32(NORMAL_CHANNEL_RATE), 0.7)

        pi.pointee.jetpackRumbleCooldown = 0
    }

    // BURN FUEL

    pi.pointee.jetpackFuel -= fps * 0.05
    if pi.pointee.jetpackFuel < 0.0 {
        pi.pointee.jetpackFuel = 0.0
    }

    SetTargetMaxSpeed(Int32(playerNum), PLAYER_JETPACK_MAX_SPEED)

    player.pointee.Speed += 1000.0 * fps

    pi.pointee.jetpackActive = 1

    // UPDATE EFFECT

    if player.pointee.EffectChannel == -1 {
        player.pointee.EffectChannel = PlayEffect_Parms3D(Int16(EFFECT_JETPACKHUM), &gEngine.objects.coord, UInt32(NORMAL_CHANNEL_RATE), 1.0)
    } else {
        Update3DSoundChannel(Int16(EFFECT_JETPACKHUM), &player.pointee.EffectChannel, &gEngine.objects.coord)
    }

    // FORCE FEEDBACK

    pi.pointee.jetpackRumbleCooldown -= gFramesPerSecondFrac
    if pi.pointee.jetpackRumbleCooldown <= 0 {
        PlayRumbleEffect(Int16(EFFECT_JETPACKHUM), Int32(playerNum))
        pi.pointee.jetpackRumbleCooldown = 0.100 // should match duration of rumble effect in sound.c
    }
}

// MARK: - Jetpack off

// Called once per frame when jetpack is off.
func JetpackOff(_ playerNum: Int16) {
    let pi = GetPlayerInfoEntry(Int32(playerNum))
    let player = pi.pointee.objNode!

    pi.pointee.jetpackActive = 0

    StopAChannelIfEffectNum(&player.pointee.EffectChannel, Int16(EFFECT_JETPACKHUM)) // stop jetpack sfx

    // DECELERATE TO NORMAL MAX SPEED

    SetTargetMaxSpeed(Int32(playerNum), PLAYER_NORMAL_MAX_SPEED)
}

// MARK: - Move player jetpack

// Called to align jetpack on the player's body.
func MovePlayerJetpack(_ jetpackOpt: UnsafeMutablePointer<ObjNode>?) {
    guard let jetpack = jetpackOpt else { return }
    let player = jetpack.pointee.ChainHead!
    let blue = jetpack.pointee.ChainNode!
    let fps = gFramesPerSecondFrac
    let playerNum = Int32(player.pointee.PlayerNum)

    // SET MATRIX

    var m = OGLMatrix4x4()
    FindJointFullMatrix(player, 0, &m)
    m.value.13 += 3.0 // offset y a tad to help alignment
    jetpack.pointee.BaseTransformMatrix = m
    SetObjectTransformMatrix(jetpack)

    // UPDATE COORD

    jetpack.pointee.Coord.x = jetpack.pointee.BaseTransformMatrix.value.12
    jetpack.pointee.Coord.y = jetpack.pointee.BaseTransformMatrix.value.13
    jetpack.pointee.Coord.z = jetpack.pointee.BaseTransformMatrix.value.14

    // UPDATE GUN TURRET SPARKLES

    let sparkles = sparklesBase(jetpack)
    for j in 0..<2 {
        let i = sparkles[j]
        if i != -1 {
            let sparkle = GetSparkleSlot(Int32(i))!
            sparkle.pointee.scale -= fps * 90.0
            if sparkle.pointee.scale < 15.0 {
                sparkle.pointee.scale = 15.0
            }
        }
    }

    // UPDATE BLUE

    blue.pointee.TextureTransformV -= fps * 1.5
    blue.pointee.TextureTransformU -= fps * 0.2

    // SET MATRIX

    blue.pointee.BaseTransformMatrix = m
    SetObjectTransformMatrix(blue)

    // UPDATE COORD

    blue.pointee.Coord = jetpack.pointee.Coord

    // MAKE JET EXHAUST

    let pi = GetPlayerInfoEntry(playerNum)
    if pi.pointee.jetpackActive != 0 {
        MakeJetpackExhaust(jetpack)
    } else if sparklesBase(jetpack)[2] != -1 {
        DeleteSparkle(sparklesBase(jetpack)[2])
        sparklesBase(jetpack)[2] = -1
    }
}

// MARK: - Make jetpack exhaust

private func MakeJetpackExhaust(_ jetpack: UnsafeMutablePointer<ObjNode>) {
    var buttPt = OGLPoint3D()

    // MAKE EXHAUST SPARKLE

    let sparkles = sparklesBase(jetpack)
    if sparkles[2] == -1 {
        let i = GetFreeSparkle(jetpack) // make new sparkle
        sparkles[2] = i
        if i != -1 {
            let sparkle = GetSparkleSlot(Int32(i))!

            sparkle.pointee.flags = UInt32(SPARKLE_FLAG_TRANSFORMWITHOWNER | SPARKLE_FLAG_FLICKER | SPARKLE_FLAG_RANDOMSPIN)
            sparkle.pointee.where = gJetpackButtOff

            sparkle.pointee.color.r = 1
            sparkle.pointee.color.g = 1
            sparkle.pointee.color.b = 1
            sparkle.pointee.color.a = 1

            sparkle.pointee.aim.x = 0
            sparkle.pointee.aim.y = 0
            sparkle.pointee.aim.z = 1

            sparkle.pointee.scale = 100.0
            sparkle.pointee.separation = 50.0

            sparkle.pointee.textureNum = Int16(PARTICLE_SObjType_RedGlint)
        }
    }

    // LEAVE FLAME TRAIL

    jetpack.pointee.ParticleTimer -= gFramesPerSecondFrac
    if jetpack.pointee.ParticleTimer <= 0.0 {
        jetpack.pointee.ParticleTimer += 0.02 // reset timer

        buttPt = gJetpackButtOff.transformed(by: jetpack.pointee.BaseTransformMatrix) // calc butt coord where smoke comes from

        var particleGroup = jetpack.pointee.ParticleGroup
        let magicNum = jetpack.pointee.ParticleMagicNum

        if (particleGroup == -1) || (VerifyParticleGroupMagicNum(particleGroup, magicNum) == 0) {
            let newMagicNum = MyRandomLong()
            jetpack.pointee.ParticleMagicNum = newMagicNum

            var groupDef = NewParticleGroupDefType()
            groupDef.magicNum = newMagicNum
            groupDef.particleType = .fallingSparks
            groupDef.flags = UInt32(PARTICLE_FLAGS_DONTCHECKGROUND | PARTICLE_FLAGS_ALLAIM)
            groupDef.gravity = 0
            groupDef.magnetism = 0
            groupDef.baseScale = 15
            groupDef.decayRate = 0.6
            groupDef.fadeRate = 1.3
            groupDef.particleTextureNum = UInt8(PARTICLE_SObjType_RedFumes)
            groupDef.srcBlend = GL_SRC_ALPHA
            groupDef.dstBlend = GL_ONE
            particleGroup = NewParticleGroup(&groupDef)
            jetpack.pointee.ParticleGroup = particleGroup
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
                newParticleDef.scale = 1.0 + RandomFloat() * 1.0
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
                    jetpack.pointee.ParticleGroup = -1
                    break
                }
            }
        }
    }
}

// MARK: - Do player movement and collision detect

// OUTPUT: true if disabled or killed
@discardableResult
private func DoPlayerMovementAndCollision(_ theNode: UnsafeMutablePointer<ObjNode>, _ useBBoxForTerrain: UInt8) -> Bool {
    let fps = gFramesPerSecondFrac
    let forward = OGLVector3D(x: 0, y: 0, z: -1)
    var aim = OGLVector3D()
    var deltaVec = OGLVector3D()
    var killed = false
    let playerNum = Int32(theNode.pointee.PlayerNum)

    // ACCEL IN DIRECTION OF AIM

    // GET AIM & MOTION VECTORS

    aim = forward.transformed(by: theNode.pointee.BaseTransformMatrix) // calc aim vector - the direction we want to be moving
    FastNormalizeVector(gEngine.objects.delta.x, gEngine.objects.delta.y, gEngine.objects.delta.z, &deltaVec) // calc current motion vector

    // CALC INTERPOLATION BETWEEN AIM & MOTION

    var f = flightSlideFactor * fps // calc interpolation % from 0 to 1
    if f > 1.0 {
        f = 1.0
    }
    let oneMinusF = 1.0 - f

    deltaVec.x = (deltaVec.x * oneMinusF) + (aim.x * f) // interpolate it
    deltaVec.y = (deltaVec.y * oneMinusF) + (aim.y * f)
    deltaVec.z = (deltaVec.z * oneMinusF) + (aim.z * f)

    // ACCELERATE / DECELERATE

    theNode.pointee.Speed = DecayToZero(theNode.pointee.Speed, fps * fabsf(theNode.pointee.Rot.z) * 100.0) // friction based on z-rot banking

    theNode.pointee.Speed -= deltaVec.y * 300.0 * fps // up/down friction
    if theNode.pointee.Speed > GetCurrentMaxSpeed(playerNum) {
        theNode.pointee.Speed = GetCurrentMaxSpeed(playerNum)
    } else if theNode.pointee.Speed < playerMinSpeed {
        theNode.pointee.Speed = playerMinSpeed
    }

    // SET DELTA

    let speed = theNode.pointee.Speed
    gEngine.objects.delta.x = deltaVec.x * speed // apply new motion vector to our deltas with speed
    gEngine.objects.delta.y = deltaVec.y * speed
    gEngine.objects.delta.z = deltaVec.z * speed

    // CHECK MAX ALTITUDE
    //
    // As the player approaches the max ceiling, we decay the Delta.y value
    // based on the distance to the max y.  This should give us a nice smooth
    // ceiling instead of a sudden stop at max_y.

    if gEngine.objects.delta.y > 0.0 {
        let maxAlt = CalcPlayerMaxAltitude(gEngine.objects.coord.x, gEngine.objects.coord.z)

        var diff = maxAlt - gEngine.objects.coord.y // calc dist to MAX Y

        if diff < 0.0 { // if over max, then just pin y value to max
            gEngine.objects.coord.y = maxAlt
        } else if diff < 300.0 { // are we within our decay calculation range?
            diff = 30.0 / diff // this does the decay calc

            gEngine.objects.delta.y -= gEngine.objects.delta.y * diff // decay delta.y
            if gEngine.objects.delta.y < 0.0 {
                gEngine.objects.delta.y = 0
            }
        }
    }

    // MOVE IT

    gEngine.objects.coord.x += gEngine.objects.delta.x * fps
    gEngine.objects.coord.y += gEngine.objects.delta.y * fps
    gEngine.objects.coord.z += gEngine.objects.delta.z * fps

    // DO OBJECT COLLISION DETECT

    if DoPlayerCollisionDetect(theNode, useBBoxForTerrain) {
        killed = true
    }

    // CHECK FENCE COLLISION

    if DoFenceCollision(theNode) != 0 {
        killed = true
        KillPlayer(Int16(playerNum), .explode, &gEngine.objects.coord)
    }

    // CHECK LINE-SEGMENT COLLISION

    DoPlayerLineSegmentCollision(theNode)

    // CHECK FLOOR

    let terrainY = GetTerrainY(gEngine.objects.coord.x, gEngine.objects.coord.z)
    let pi = GetPlayerInfoEntry(playerNum)
    pi.pointee.distToFloor = gEngine.objects.coord.y + theNode.pointee.LocalBBox.min.y - terrainY // calc dist to floor

    return killed
}

// MARK: - Do player line segment collision

private func DoPlayerLineSegmentCollision(_ player: UnsafeMutablePointer<ObjNode>) {
    var lineSeg = OGLLineSegment()
    var hitPt = OGLPoint3D()
    let joints: [[Int32]] = [
        [Int32(PlayerJoint.leftWing3.rawValue), Int32(PlayerJoint.rightWing3.rawValue)],
        [Int32(PlayerJoint.jaw.rawValue), Int32(PlayerJoint.eggHold.rawValue)],
    ]

    // TEST VARIOUS LINE SEGMENTS FOR COLLISION

    for i in 0..<2 {
        // CALC LINE SEGMENT BETWEEN JOINTS

        FindCoordOfJoint(player, Int(joints[i][0]), &lineSeg.p1)
        FindCoordOfJoint(player, Int(joints[i][1]), &lineSeg.p2)

        gPickAllTrianglesAsDoubleSided = 1
        let hitObj = OGL_DoLineSegmentCollision_ObjNodes(&lineSeg, UInt32(STATUS_BIT_HIDDEN), UInt32(CTYPE_PLAYERTEST), &hitPt, nil, nil, 1)
        gPickAllTrianglesAsDoubleSided = 0

        if let hitObj {
            if let trigger = hitObj.pointee.TriggerCallback { // call hit obj's trigger func if any
                _ = trigger(hitObj, player)
            } else {
                let pi = GetPlayerInfoEntry(Int32(player.pointee.PlayerNum))
                if pi.pointee.invincibilityTimer <= 0.0 { // otherwise, just kill player
                    KillPlayer(Int16(player.pointee.PlayerNum), .explode, &gEngine.objects.coord)
                }
            }

            return
        }
    }
}

// MARK: - Do player collision detect

// Standard collision handler for player
//
// OUTPUT: true = disabled/killed
@discardableResult
private func DoPlayerCollisionDetect(_ theNode: UnsafeMutablePointer<ObjNode>, _ useBBoxForTerrain: UInt8) -> Bool {
    let fps = gFramesPerSecondFrac
    var killed = false
    let playerNum = Int32(theNode.pointee.PlayerNum)

    // AUTOMATICALLY HANDLE THE GOOD STUFF
    //
    // this also sets the ONGROUND status bit if on a solid object.

    if useBBoxForTerrain != 0 {
        theNode.pointee.BottomOff = theNode.pointee.LocalBBox.min.y
    } else {
        theNode.pointee.BottomOff = gEngine.player.playerBottomOff
    }

    var ctype = UInt32(CTYPE_TRIGGER | CTYPE_HURTME | CTYPE_PLAYERONLY) // get default ctypes (PLAYER_COLLISION_CTYPE)
    ctype |= UInt32(CTYPE_PLAYER2) >> UInt32(playerNum) // and also check for other player

    // CALL DEFAULT HANDLER

    _ = HandleCollisions(theNode, ctype, -0.2)

    killed = GetPlayerIsDead(playerNum) != 0 // see if player was killed during that

    // SCAN FOR INTERESTING STUFF

    for i in 0..<Int(gNumCollisions) {
        let entry = GetCollisionListEntry(Int32(i))!
        if entry.pointee.type == UInt8(COLLISION_TYPE_OBJ) {
            guard let hitObj = entry.pointee.objectPtr else { continue } // get ObjNode of this collision

            if hitObj.pointee.CType == UInt32(INVALID_NODE_FLAG) { // see if has since become invalid
                continue
            }

            // CHECK FOR TOTALLY IMPENETRABLE

            if hitObj.pointee.CBits & UInt32(CBITS_IMPENETRABLE2) != 0 {
                if entry.pointee.sides & UInt16(SIDE_BITS_BOTTOM) == 0 { // dont do this if we landed on top of it
                    gEngine.objects.coord.x = theNode.pointee.OldCoord.x // dont take any chances, just move back to original safe place
                    gEngine.objects.coord.z = theNode.pointee.OldCoord.z
                }
            }
        }
    }

    // CHECK & HANDLE TERRAIN  COLLISION

    let bottomOff: Float
    if useBBoxForTerrain != 0 {
        bottomOff = theNode.pointee.LocalBBox.min.y // use bbox for bottom
    } else {
        bottomOff = theNode.pointee.BottomOff // use collision box for bottom
    }

    let terrainY = GetTerrainY(gEngine.objects.coord.x, gEngine.objects.coord.z) // get terrain Y

    let distToFloor = (gEngine.objects.coord.y + bottomOff) - terrainY // calc amount I'm above or under

    if distToFloor <= 0.0 { // see if on or under floor
        gEngine.objects.coord.y = terrainY - bottomOff
        theNode.setStatus(STATUS_BIT_ONGROUND)

        // SEE IF HIT GROUND HEAD-ON OR SQUEEZED TO MAX ALTITUDE

        var kaboom = false
        if gEngine.objects.coord.y > MAX_ALTITUDE { // kaboom is squeezed
            kaboom = true
        } else {
            let dot = theNode.pointee.MotionVector.dot(gRecentTerrainNormal) // see if smacked into terrain

            if (dot < -0.6) && (!gGamePrefs.isKiddieMode) { // if hit head-on & not in kiddie mode
                kaboom = true
            }
        }

        if kaboom {
            killed = killed || (PlayerLoseHealth(Int16(playerNum), 1.1, .explode, &gEngine.objects.coord, 1) != 0)
        }

        // NOT SO HARD
        else {
            if gEngine.objects.delta.y < -200.0 {
                killed = killed || (PlayerLoseHealth(Int16(playerNum), fps * 0.1, .explode, &gEngine.objects.coord, 1) != 0)
            }

            DoPlayerGroundScrape(theNode, Int16(playerNum))

            // GROUND SCRAPE FORCE FEEDBACK

            if !killed {
                let pi = GetPlayerInfoEntry(playerNum)
                pi.pointee.groundScrapeRumbleCooldown -= fps
                if pi.pointee.groundScrapeRumbleCooldown <= 0 {
                    pi.pointee.groundScrapeRumbleCooldown = 0.1
                    Rumble(0.8, 0.5, 100, playerNum)
                }
            }
        }

        gEngine.objects.delta.y *= -0.1
    }

    // SEE IF HIT WATER SURFACE

    if !killed && (gEngine.objects.delta.y <= 0.0) { // only check water if moving down and not killed yet
        var patchNum: Int32 = 0

        let wasInWater = theNode.hasStatus(STATUS_BIT_UNDERWATER) // remember if was in water to begin with

        // CHECK IF IN WATER NOW

        if DoWaterCollisionDetect(theNode, gEngine.objects.coord.x, gEngine.objects.coord.y + theNode.pointee.BottomOff, gEngine.objects.coord.z, &patchNum) != 0 {
            let waterY = GetWaterBBoxEntry(patchNum)!.pointee.max.y
            var splashPt = OGLPoint3D()

            gEngine.objects.coord.y = waterY - theNode.pointee.BottomOff // keep player on surface

            let waterType = Int(gWaterList![Int(patchNum)].type)
            let isLava = (waterType >= Int(WaterType.lava.rawValue)) && (waterType <= Int(WaterType.lavaDir7.rawValue)) // see if this is lava

            // SEE IF HIT WATER HARD

            if gEngine.objects.delta.y < -400.0 {
                killed = killed || (PlayerLoseHealth(Int16(playerNum), 1.1, .explode, &gEngine.objects.coord, 1) != 0)

                splashPt.x = gEngine.objects.coord.x
                splashPt.y = waterY
                splashPt.z = gEngine.objects.coord.z
                MakeSplash(&splashPt, 1.2)
            }

            // KEEP LEVEL ON WATER
            //
            // When skimming the water we don't want the wings and things dipping into it, so force
            // the player to level out flat.

            else {
                // SEE IF HIT LAVA

                if isLava {
                    killed = killed || (PlayerLoseHealth(Int16(playerNum), fps * 1.0, .explode, &gEngine.objects.coord, 1) != 0)
                }

                theNode.pointee.Rot.z = DecayToZero(theNode.pointee.Rot.z, SwPI2 * fps)

                if theNode.pointee.Rot.x < 0.0 {
                    theNode.pointee.Rot.x = DecayToZero(theNode.pointee.Rot.x, SwPI2 * fps)
                }
            }

            // MAKE SPLASH IF THIS IS A FIRST TOUCH OF THE WATER

            if !isLava { // no splashing for lava
                let pi = GetPlayerInfoEntry(playerNum)
                if !wasInWater {
                    splashPt.x = gEngine.objects.coord.x
                    splashPt.y = waterY
                    splashPt.z = gEngine.objects.coord.z
                    MakeSplash(&splashPt, 1.0)
                }

                // OTHERWISE JUST UPDATE RIPPLES BEHIND US
                else {
                    pi.pointee.waterRippleTimer -= fps
                    if pi.pointee.waterRippleTimer <= 0.0 {
                        pi.pointee.waterRippleTimer += 0.05
                        splashPt.x = gEngine.objects.coord.x
                        splashPt.y = waterY
                        splashPt.z = gEngine.objects.coord.z
                        CreateNewRipple(&splashPt, 12.0, 40.0, 1.0)
                    }
                    SprayWater(theNode, gEngine.objects.coord.x, waterY, gEngine.objects.coord.z)
                }
            }

            gEngine.objects.delta.y = 0
        }
    }

    return killed
}

// MARK: - Player smacked into object

// Returns true if player was killed by impact
func PlayerSmackedIntoObject(_ playerOpt: UnsafeMutablePointer<ObjNode>?, _ hitObjOpt: UnsafeMutablePointer<ObjNode>?, _ deathType: PlayerDeathType) -> UInt8 {
    let player = playerOpt!
    let hitObj = hitObjOpt!

    // HANDLE SPECIAL STUFF BASED ON DEATH TYPE

    switch deathType {
    case .deathDive:
        // DETERMINE WHAT ANGLE TO BOUNCE

        let r = player.pointee.Rot.y
        var pv = OGLVector2D()
        pv.x = sin(r)
        pv.y = cos(r)

        var ov = OGLVector2D()
        ov.x = hitObj.pointee.Coord.x - gEngine.objects.coord.x
        ov.y = hitObj.pointee.Coord.z - gEngine.objects.coord.z
        FastNormalizeVector2D(ov.x, ov.y, &ov, 1)

        if OGLVector2D_Cross(&ov, &pv) > 0.0 {
            player.pointee.Rot.y += Float.pi / 9
        } else {
            player.pointee.Rot.y -= Float.pi / 9
        }

        player.pointee.Rot.x *= 1.0 + RandomFloat2() * 0.2

        MakeSparkExplosion(&gEngine.objects.coord, 200, 1.0, Int16(PARTICLE_SObjType_RedSpark), 100, 1.0)

    case .explode:
        break
    }

    // KILL PLAYER

    let pi = GetPlayerInfoEntry(Int32(player.pointee.PlayerNum))
    if pi.pointee.invincibilityTimer <= 0.0 {
        KillPlayer(Int16(player.pointee.PlayerNum), deathType, &gEngine.objects.coord)
    }
    return 1
}

// MARK: - Set player flying anim

func SetPlayerFlyingAnim(_ player: UnsafeMutablePointer<ObjNode>) {
    let currentAnim = PlayerAnim(rawValue: UInt32(player.pointee.Skeleton!.pointee.AnimNum))
    var desiredAnim: PlayerAnim?
    var bestDist: Float = 100_000_000

    // SEE IF SHOULD GO INTO GRAB ANIM

    guard gEngine.objects.firstNodePtr != nil else { // see if there are any objects
        return
    }

    // SCAN THRU ALL OBJECTS LOOKING FOR SOMETHING TO PICKUP

    for thisNode in allObjectNodes {
        if thisNode.pointee.CType & UInt32(CTYPE_POWERUP | CTYPE_EGG) != 0 {
            // IS IT IN RANGE?

            let dist = gEngine.objects.coord.distance(to: thisNode.pointee.Coord)
            if (dist < bestDist) && (dist < 900.0) { // see if this is in range & is closest so far
                var v = OGLVector3D()

                // ARE WE AIMED AT IT?

                v.x = thisNode.pointee.Coord.x - gEngine.objects.coord.x // calc vector to node
                v.y = thisNode.pointee.Coord.y - gEngine.objects.coord.y
                v.z = thisNode.pointee.Coord.z - gEngine.objects.coord.z
                FastNormalizeVector(v.x, v.y, v.z, &v)

                let dot = v.dot(player.pointee.MotionVector)
                if dot > -0.1 {
                    desiredAnim = .readyToGrab
                    bestDist = dist
                }
            }
        }
    }

    // SEE WHICH GENERAL FLIGHT ANIM TO USE

    if desiredAnim != .readyToGrab { // do we want to be grabbing?
        // SEE IF BANKING RIGHT

        if player.pointee.Rot.z < (-Float.pi / 7) {
            desiredAnim = .bankRight
        }

        // SEE IF BANKING LEFT

        else if player.pointee.Rot.z > (Float.pi / 7) {
            desiredAnim = .bankLeft
        }

        // FLAP / COAST
        else {
            switch currentAnim {
            case .flap: // if currently flapping, then see if time to coast
                player.pointee.SpecialF.3 -= gFramesPerSecondFrac // FlapCoastTimer
                if player.pointee.SpecialF.3 <= 0.0 {
                    desiredAnim = .coasting
                    player.pointee.SpecialF.3 = 2.0 + RandomFloat() * 3.0
                } else {
                    desiredAnim = .flap
                }

            case .coasting: // if currently coasting, then see if time to flap
                player.pointee.SpecialF.3 -= gFramesPerSecondFrac // FlapCoastTimer
                if player.pointee.SpecialF.3 <= 0.0 {
                    desiredAnim = .flap
                    player.pointee.SpecialF.3 = 1.0 + RandomFloat() * 3.0
                } else {
                    desiredAnim = .coasting
                }

            default: // coming out of another anim, so always flap
                desiredAnim = .flap
                player.pointee.SpecialF.3 = 1.0 + RandomFloat() * 3.0
            }
        }
    }

    if let desiredAnim, desiredAnim != currentAnim {
        MorphToSkeletonAnim(player.pointee.Skeleton, desiredAnim, 4.0)
    }
}

// MARK: - Set player flying anim with egg

private func SetPlayerFlyingAnim_WithEgg(_ player: UnsafeMutablePointer<ObjNode>) {
    let currentAnim = PlayerAnim(rawValue: UInt32(player.pointee.Skeleton!.pointee.AnimNum))
    var desiredAnim: PlayerAnim

    // SEE IF BANKING RIGHT

    if player.pointee.Rot.z < (-Float.pi / 7) {
        desiredAnim = .bankRightEgg
    }

    // SEE IF BANKING LEFT

    else if player.pointee.Rot.z > (Float.pi / 7) {
        desiredAnim = .bankLeftEgg
    }

    // FLAP
    else {
        desiredAnim = .flapWithEgg
    }

    if desiredAnim != currentAnim {
        MorphToSkeletonAnim(player.pointee.Skeleton, desiredAnim, 3.0)
    }
}

// MARK: - Handle player line marker crossing

func HandlePlayerLineMarkerCrossing(_ playerOpt: UnsafeMutablePointer<ObjNode>?) {
    let player = playerOpt!
    var markerNum: Int = 0

    // SEE IF CROSSED ANY LINE MARKERS

    if SeeIfCrossedLineMarker(player, &markerNum) == 0 {
        return
    }

    // SET CHECKPOINT

    SetReincarnationCheckpointAtMarker(player, Int16(markerNum))
}

// MARK: - Set reincarnation checkpoint at marker

func SetReincarnationCheckpointAtMarker(_ playerOpt: UnsafeMutablePointer<ObjNode>?, _ markerNum: Int16) {
    let player = playerOpt!
    let playerNum = Int32(player.pointee.PlayerNum)

    // CALC CENTER OF THE LINE MARKER

    let marker = GetLineMarkerPtr(Int32(markerNum))
    let x = (marker.pointee.x.0 + marker.pointee.x.1) * 0.5
    let z = (marker.pointee.z.0 + marker.pointee.z.1) * 0.5

    // SET CHECKPOINT INFO

    SetBestCheckpointNum(playerNum, markerNum)

    var coord = OGLPoint3D()
    coord.x = x
    coord.z = z
    coord.y = GetTerrainY(x, z) + MAX_ALTITUDE_DIFF * 0.95 // start as high as we can go
    SetBestCheckpointCoord(playerNum, coord)

    SetBestCheckpointAim(playerNum, player.pointee.Rot.y)
}

// MARK: - Trigger callback: player

private let cDoTrig_Player: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?) -> UInt8 = { trigger, theNode in
    DoTrig_Player(trigger!, theNode!)
}

// MARK: - Hit-by-weapon callback: player

private let cPlayerHitByWeaponCallback: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<OGLPoint3D>?, UnsafeMutablePointer<OGLVector3D>?) -> UInt8 = { weapon, player, hitCoord, hitNormal in
    PlayerHitByWeaponCallback(weapon!, player!, hitCoord, hitNormal)
}
