// Player.swift - Port of Player.c to Swift
//
// gNumPlayers, gPlayerInfo, gDeathTimer, gPlayerIsDead stay defined in
// Player.c and `extern`'d via game.h/SwiftInternal.h/PlayerInternal.h: many
// still-unported C files (and already-ported Contrails.swift, Player_Race.swift,
// File.swift, etc.) read/write them directly. gBestCheckpointCoord/Aim,
// gCurrentMaxSpeed/gTargetMaxSpeed, and gCameraInDeathDiveMode are the same
// story - accessed through the Get*/Set* shims in PlayerInternal.h since
// Swift can't dynamically index a fixed-size C array.

// MARK: - fixed-array-field helpers (all struct fields, never unions)

@inline(__always) private func weaponQuantityBase(_ p: UnsafeMutablePointer<PlayerInfoType>) -> UnsafeMutablePointer<Int16> {
    UnsafeMutableRawPointer(p.pointer(to: \.weaponQuantity)!).assumingMemoryBound(to: Int16.self)
}

@inline(__always) private func previousWingContrailPtBase(_ p: UnsafeMutablePointer<PlayerInfoType>) -> UnsafeMutablePointer<OGLPoint3D> {
    UnsafeMutableRawPointer(p.pointer(to: \.previousWingContrailPt)!).assumingMemoryBound(to: OGLPoint3D.self)
}

@inline(__always) private func raceCheckpointTaggedBase(_ p: UnsafeMutablePointer<PlayerInfoType>) -> UnsafeMutablePointer<UInt8> {
    UnsafeMutableRawPointer(p.pointer(to: \.raceCheckpointTagged)!).assumingMemoryBound(to: UInt8.self)
}

// MARK: - Init player info
//
// Called once at beginning of game

@c @implementation
public func InitPlayerInfo_Game() {
    for i in 0..<Int(MAX_PLAYERS) {
        let pi = GetPlayerInfoEntry(Int32(i))!

        // INIT SOME THINGS IF NOT LOADING SAVED GAME
        if gPlayingFromSavedGame == 0 {
            if gVSMode == .battle { // more lives in battle mode
                pi.pointee.numFreeLives = 5
            } else {
                pi.pointee.numFreeLives = 3
            }

            pi.pointee.health = 1.0

            if gVSMode == .race { // start with very little fuel in races
                pi.pointee.jetpackFuel = 0.25
            } else {
                pi.pointee.jetpackFuel = 1.0
            }

            pi.pointee.shieldPower = MAX_SHIELD_POWER

            let weaponQuantity = weaponQuantityBase(pi)
            for w in 0..<WeaponType.allCases.count { // init weapon inventory
                weaponQuantity[w] = 0
            }
        }

        SetDeathTimer(Int32(i), 0)

        pi.pointee.startX = 0
        pi.pointee.startZ = 0
        pi.pointee.coord.x = 0
        pi.pointee.coord.y = 0
        pi.pointee.coord.z = 0

        pi.pointee.blinkTimer = 2

        pi.pointee.turretSide = 0

        pi.pointee.wormhole = nil

        pi.pointee.currentWeapon = Int16(WeaponType.sonicScream.rawValue)
        weaponQuantityBase(pi)[Int(WeaponType.sonicScream.rawValue)] = 999 // we have infinite of these, but set to 999 anyways
    }
}

// MARK: - Init player at start of level

@c @implementation
public func InitPlayerAtStartOfLevel() {
    // FIRST PRIME THE TERRAIN TO CAUSE ALL OBJECTS TO BE GENERATED BEFORE WE PUT THE PLAYER DOWN
    InitCurrentScrollSettings()
    DoPlayerTerrainUpdate()

    // INIT EACH PLAYER'S INFO
    for i in 0..<Int(gNumPlayers) {
        let pi = GetPlayerInfoEntry(Int32(i))!

        pi.pointee.invincibilityTimer = 0

        pi.pointee.burnTimer = 0

        pi.pointee.shieldObj = nil
        pi.pointee.weaponChargeChannel = -1

        pi.pointee.jetpackActive = 0

        pi.pointee.crosshairTargetObj = nil

        SetPlayerIsDead(Int32(i), 0)

        pi.pointee.waterRippleTimer = 0

        let contrailPt = previousWingContrailPtBase(pi)
        contrailPt[0].x = 10_000_000
        contrailPt[0].y = 10_000_000
        contrailPt[0].z = 10_000_000
        contrailPt[1].x = 10_000_000
        contrailPt[1].y = 10_000_000
        contrailPt[1].z = 10_000_000

        pi.pointee.carriedObj = nil

        // INIT RACE-SPECIFIC INFO
        let raceCheckpointTagged = raceCheckpointTaggedBase(pi)
        for j in 0..<Int(MAX_LINEMARKERS) { // start with all race checkpoints tagged to trick lapNum @ start of race
            raceCheckpointTagged[j] = 1
        }

        pi.pointee.movingBackwards = 0
        pi.pointee.wrongWay = 0

        pi.pointee.lapNum = -1 // start @ -1 since we cross the finish line @ start
        pi.pointee.raceCheckpointNum = Int16(gNumLineMarkers) - 1
        pi.pointee.place = Int16(i)
        pi.pointee.distToNextCheckpoint = 0
        pi.pointee.raceComplete = 0

        pi.pointee.dirtParticleTimer = 0
        pi.pointee.dirtParticleGroup = -1

        // CREATE THE PLAYER
        CreatePlayerObject(Int16(i), &pi.pointee.coord, pi.pointee.startRotY)

        SetBestCheckpointCoord(Int32(i), pi.pointee.coord) // set first checkpoint @ starting location
        SetBestCheckpointAim(Int32(i), pi.pointee.objNode!.pointee.Rot.y)

        // GIVE PLAYER A SHIELD
        if pi.pointee.shieldPower > 0 { // only give shield obj if have shield power
            CreatePlayerShield(Int16(i))
        }
    }

    // LAY DOWN ENTRY WORMHOLE IN ADVENTURE MODE
    if gVSMode == .none {
        var wormStartOff = OGLPoint3D(x: 0, y: 1200, z: 0)
        var wormVector = OGLVector3D(x: 0, y: 1, z: 0)

        let pi0 = GetPlayerInfoEntry(0)!
        let player = pi0.pointee.objNode!

        let wormhole = MakeEntryWormhole(0)!

        // CALC COORD AND VECTOR OF PLAYER AT START OF WORMHOLE
        OGLPoint3D_Transform(&wormStartOff, &wormhole.pointee.BaseTransformMatrix, &player.pointee.Coord)
        OGLVector3D_Transform(&wormVector, &wormhole.pointee.BaseTransformMatrix, &player.pointee.Delta)

        player.pointee.Speed = 2500.0

        player.pointee.Delta.x *= -player.pointee.Speed
        player.pointee.Delta.y *= -player.pointee.Speed
        player.pointee.Delta.z *= -player.pointee.Speed

        pi0.pointee.coord = player.pointee.Coord

        SetSkeletonAnim(player.pointee.Skeleton, Int(PlayerAnim.appearWormhole.rawValue))
        player.pointee.Rot.x = -Float(PI) / 2 + wormhole.pointee.Rot.x

        FadePlayer(player, -0.99) // start faded out
    }
}

// MARK: - Disorient player

@c @implementation
public func DisorientPlayer(_ player: UnsafeMutablePointer<ObjNode>) {
    let playerNum = player.pointee.PlayerNum

    if gGamePrefs.kiddieMode == 0 { // don't drop eggs in kiddie mode
        DropEgg_NoWormhole(Int16(playerNum))
    }

    if Int(player.pointee.Skeleton!.pointee.AnimNum) != Int(PlayerAnim.disoriented.rawValue) {
        MorphToSkeletonAnim(player.pointee.Skeleton, Int(PlayerAnim.disoriented.rawValue), 3.0)
    }
}

// MARK: - Player lose health
//
// return true if player killed
//
// where is usually gCoord, but if nil then use coord from player's objNode

@c @implementation
public func PlayerLoseHealth(_ playerNum: Int16, _ damage: Float, _ deathType: UInt8, _ where_: UnsafeMutablePointer<OGLPoint3D>?, _ disorient: UInt8) -> UInt8 {
    var killed: UInt8 = 0

    let pi = GetPlayerInfoEntry(Int32(playerNum))!

    if pi.pointee.invincibilityTimer > 0 { // see if invincible
        return 0
    }

    if pi.pointee.health < 0 { // see if already dead
        return 1
    }

    pi.pointee.health -= damage

    // SEE IF KILLED
    if pi.pointee.health <= 0 {
        pi.pointee.health = 0

        KillPlayer(playerNum, deathType, where_)
        killed = 1
    }
    // JUST HURT
    else if disorient != 0 {
        DisorientPlayer(pi.pointee.objNode!)
    }

    // FORCE FEEDBACK
    if killed == 0 {
        PlayRumbleEffect(Int16(EFFECT_BODYHIT), Int32(playerNum))
    }

    return killed
}

// MARK: - Kill player
//
// where is usually gCoord, but if nil then use coord from player's objNode

@c @implementation
public func KillPlayer(_ playerNum: Int16, _ deathType: UInt8, _ where_: UnsafeMutablePointer<OGLPoint3D>?) {
    let pi = GetPlayerInfoEntry(Int32(playerNum))!
    let player = pi.pointee.objNode!

    // MAKE SURE STOPPED CHARGE/JETPACK
    pi.pointee.weaponCharge = 0

    StopAChannel(&pi.pointee.weaponChargeChannel)

    JetpackOff(playerNum)

    // DROP EGG (IF ANY)
    DropEgg_NoWormhole(playerNum)

    // VERIFY ANIM IF ALREADY DEAD
    //
    // This should assure us that we don't get kicked out of our death anim accidentally
    if GetPlayerIsDead(Int32(playerNum)) != 0 { // see if already dead
        return
    }

    // KILL US NOW
    SetPlayerIsDead(Int32(playerNum), 1)
    pi.pointee.health = 0 // make sure this is set correctly

    switch deathType {
    case UInt8(PlayerDeathType.explode.rawValue):
        ExplodePlayer(player, playerNum, where_)

    case UInt8(PlayerDeathType.deathDive.rawValue):
        MorphToSkeletonAnim(player.pointee.Skeleton, Int(PlayerAnim.deathDive.rawValue), 3.0)
        let t: Float = 8.0
        SetDeathTimer(Int32(playerNum), t)
        pi.pointee.invincibilityTimer = t
        SetCameraInDeathDiveMode(Int32(playerNum), 1)
        PlayEffect3D(Int16(EFFECT_BODYHIT), &player.pointee.Coord)
        PlayRumbleEffect(Int16(EFFECT_BODYHIT), Int32(playerNum))

    default:
        break
    }

    // SPECIAL STUFF FOR BATTLE MODE
    if gVSMode == .battle {
        if pi.pointee.numFreeLives <= 0 { // is this player out of lives?
            ShowWinLose(playerNum, 1) // lost
            ShowWinLose(playerNum ^ 1, 0) // win
            StartLevelCompletion(5.0)
        }
    }
}

// MARK: - Hide player

@c @implementation
public func HidePlayer(_ player: UnsafeMutablePointer<ObjNode>) {
    var node: UnsafeMutablePointer<ObjNode>? = player

    while let n = node {
        n.pointee.StatusBits |= UInt32(STATUS_BIT_HIDDEN) | UInt32(STATUS_BIT_NOMOVE)
        node = n.pointee.ChainNode
    }

    player.pointee.CType = 0
}

// MARK: - Show player

@c @implementation
public func ShowPlayer(_ player: UnsafeMutablePointer<ObjNode>) {
    var node: UnsafeMutablePointer<ObjNode>? = player

    while let n = node {
        n.pointee.StatusBits &= ~(UInt32(STATUS_BIT_HIDDEN) | UInt32(STATUS_BIT_NOMOVE))
        node = n.pointee.ChainNode
    }
}

// MARK: - Fade player
//
// Return true if player is now invisible / hidden

@c @implementation
public func FadePlayer(_ player: UnsafeMutablePointer<ObjNode>, _ rate: Float) -> UInt8 {
    var a = player.pointee.ColorFilter.a
    a += rate

    if a > 1.0 {
        a = 1.0
    } else if a <= 0.0 {
        HidePlayer(player)
        return 1
    }

    var node: UnsafeMutablePointer<ObjNode>? = player
    while let n = node {
        n.pointee.ColorFilter.a = a
        node = n.pointee.ChainNode
    }

    return 0
}

// MARK: - Reset player @ best checkpoint

@c @implementation
public func ResetPlayerAtBestCheckpoint(_ playerNum: Int16) {
    let pi = GetPlayerInfoEntry(Int32(playerNum))!
    let player = pi.pointee.objNode!

    SetSkeletonAnim(player.pointee.Skeleton, Int(PlayerAnim.coasting.rawValue))

    // FIRST TAKE AWAY A LIFE AND SEE IF IT'S ALL OVER
    switch gVSMode { // not all game modes have lives
    case .race, .captureTheFlag: // infinite lives in racing & flag modes
        break

    case .battle:
        if pi.pointee.numFreeLives <= 0 { // if no lives remaining then do nothing but wait for level completion to finish
            return
        } else {
            pi.pointee.numFreeLives -= 1 // dec # lives
        }

    default:
        if pi.pointee.numFreeLives <= 0 { // if no free lives then cannot reset, so game over
            gGameOver = 1
            return
        }
        pi.pointee.numFreeLives -= 1 // dec # lives
    }

    // RESET SPEEDS
    SetTargetMaxSpeed(Int32(playerNum), PLAYER_NORMAL_MAX_SPEED)
    SetCurrentMaxSpeed(Int32(playerNum), PLAYER_NORMAL_MAX_SPEED)
    player.pointee.Speed = PLAYER_NORMAL_MAX_SPEED

    // RESET COORD @ CHECKPOINT
    //
    // In 2-player modes we start each player at a different height so that they don't materialize on top
    // of each other if they both die and reincarnate simultaneously!
    let checkpointCoord = GetBestCheckpointCoord(Int32(playerNum))
    pi.pointee.coord = checkpointCoord
    player.pointee.Coord = checkpointCoord

    // ALWAYS REINCARNATE HIGH
    if playerNum == 0 {
        let y = CalcPlayerMaxAltitude(player.pointee.Coord.x, player.pointee.Coord.z) - 600.0
        pi.pointee.coord.y = y
        player.pointee.Coord.y = y
    } else {
        let y = CalcPlayerMaxAltitude(player.pointee.Coord.x, player.pointee.Coord.z) - (600.0 + 200.0) // player 2 starts lower than player 1
        pi.pointee.coord.y = y
        player.pointee.Coord.y = y
    }

    DoPlayerTerrainUpdate() // do this to prime any objecs/platforms there before we calc our new y Coord

    player.pointee.OldCoord = player.pointee.Coord
    player.pointee.Delta.x = 0
    player.pointee.Delta.y = 0
    player.pointee.Delta.z = 0

    player.pointee.Scale.x = PLAYER_DEFAULT_SCALE
    player.pointee.Scale.y = PLAYER_DEFAULT_SCALE
    player.pointee.Scale.z = PLAYER_DEFAULT_SCALE

    // RESET COLLISION & STATUS INFO
    player.pointee.CType = UInt32(CTYPE_PLAYER1) << playerNum // make sure collision is set

    if gVSMode != .none { // be sure to reset this for 2P modes
        player.pointee.CType |= UInt32(CTYPE_TRIGGER)
        player.pointee.CBits |= UInt32(CBITS_ALWAYSTRIGGER)
        player.pointee.TriggerCallback = cDoTrig_Player
    }

    ShowPlayer(player)
    FadePlayer(player, 1.0)

    pi.pointee.health = 1.0
    player.pointee.Health = 1.0
    pi.pointee.burnTimer = 0

    SetPlayerIsDead(Int32(playerNum), 0)

    pi.pointee.invincibilityTimer = 1.0

    player.pointee.Rot.x = 0
    player.pointee.Rot.z = 0
    player.pointee.Rot.y = GetBestCheckpointAim(Int32(playerNum)) // set the aim

    SetCameraInDeathDiveMode(Int32(playerNum), 0) // make sure camera not frozen

    SetPlayerFlyingAnim(player)

    InitCamera_Terrain(playerNum)

    MakeFadeEvent(UInt8(kFadeFlags_In) | (UInt8(kFadeFlags_P1) << playerNum), 3.0)
}

// MARK: - Update carried object

@c @implementation
public func UpdateCarriedObject(_ player: UnsafeMutablePointer<ObjNode>, _ held: UnsafeMutablePointer<ObjNode>) {
    // CALC SCALE MATRIX
    let scale = held.pointee.Scale.x / player.pointee.Scale.x // to adjust from player's scale to held's scale
    var mst = OGLMatrix4x4()
    OGLMatrix4x4_SetScale(&mst, scale, scale, scale)

    // CALC TRANSLATE MATRIX
    setMatValue(&mst, M03, held.pointee.HoldOffset.x) // insert translation into scale matrix
    setMatValue(&mst, M13, held.pointee.HoldOffset.y)
    setMatValue(&mst, M23, held.pointee.HoldOffset.z)

    // CALC ROTATE MATRIX
    var rm = OGLMatrix4x4()
    OGLMatrix4x4_SetRotate_XYZ(&rm, held.pointee.HoldRot.x, held.pointee.HoldRot.y, held.pointee.HoldRot.z)
    var m2 = OGLMatrix4x4()
    OGLMatrix4x4_Multiply(&rm, &mst, &m2)

    // GET ALIGNMENT MATRIX
    var m = OGLMatrix4x4()
    FindJointFullMatrix(player, Int(PlayerJoint.eggHold.rawValue), &m) // get joint's matrix

    OGLMatrix4x4_Multiply(&m2, &m, &held.pointee.BaseTransformMatrix)
    SetObjectTransformMatrix(held)

    // GET COORDS FOR OBJECT & KEEP COLLISION BOX
    //
    // even tho the collision box is turned off while the player
    // is carrying the object, we maintain these values
    // so that when the player drops the object things
    // dont freak out.
    held.pointee.Coord.x = matValue(&held.pointee.BaseTransformMatrix, M03)
    held.pointee.OldCoord.x = held.pointee.Coord.x
    held.pointee.Coord.y = matValue(&held.pointee.BaseTransformMatrix, M13)
    held.pointee.OldCoord.y = held.pointee.Coord.y
    held.pointee.Coord.z = matValue(&held.pointee.BaseTransformMatrix, M23)
    held.pointee.OldCoord.z = held.pointee.Coord.z

    held.pointee.Rot.y = player.pointee.Rot.y
    CalcObjectBoxFromNode(held)
    UpdateShadow(held)

    // (Nano 2 doesn't chain anything off held objects, so the "ALSO UPDATE ANY CHAINS" block is dead code - omitted)
}

// MARK: - Calc distance to closest player

@c @implementation
public func CalcDistanceToClosestPlayer(_ pt: UnsafeMutablePointer<OGLPoint3D>, _ playerNum: UnsafeMutablePointer<Int16>?) -> Float {
    // CHECK PLAYER 1
    var d1: Float
    if GetPlayerIsDead(0) != 0 { // ignore dead player
        d1 = 10_000_000
    } else {
        d1 = OGLPoint3D_Distance(pt, &GetPlayerInfoEntry(0)!.pointee.coord) // get player 1 dist
    }

    playerNum?.pointee = 0

    // CHECK PLAYER 2
    if gNumPlayers > 1 {
        if GetPlayerIsDead(1) != 0 { // ignore dead player
            return d1
        }

        let d2 = OGLPoint3D_Distance(pt, &GetPlayerInfoEntry(1)!.pointee.coord)
        if d2 < d1 {
            playerNum?.pointee = 1
            return d2
        }
    }

    return d1
}

// MARK: - Explode player
//
// where is usually gCoord, but if nil then use coord from player's objNode

@c @implementation
public func ExplodePlayer(_ player: UnsafeMutablePointer<ObjNode>, _ playerNum: Int16, _ where_: UnsafeMutablePointer<OGLPoint3D>?) {
    let x: Float, y: Float, z: Float
    if let where_ {
        x = where_.pointee.x
        y = where_.pointee.y
        z = where_.pointee.z
    } else {
        x = player.pointee.Coord.x
        y = player.pointee.Coord.y
        z = player.pointee.Coord.z
    }

    // MAKE FIREBALL
    gNewParticleGroupDef.magicNum = 0
    gNewParticleGroupDef.type = UInt8(ParticleType.fallingSparks.rawValue)
    gNewParticleGroupDef.flags = 0
    gNewParticleGroupDef.gravity = 0
    gNewParticleGroupDef.magnetism = 0
    gNewParticleGroupDef.baseScale = 18
    gNewParticleGroupDef.decayRate = -4.0
    gNewParticleGroupDef.fadeRate = 1.1
    gNewParticleGroupDef.particleTextureNum = UInt8(PARTICLE_SObjType_Fire)
    gNewParticleGroupDef.srcBlend = GL_SRC_ALPHA
    gNewParticleGroupDef.dstBlend = GL_ONE
    var pg = NewParticleGroup(&gNewParticleGroupDef)
    if pg != -1 {
        for _ in 0..<100 {
            var d = OGLVector3D()
            d.y = RandomFloat2() * 150.0
            d.x = RandomFloat2() * 150.0
            d.z = RandomFloat2() * 150.0

            var pt = OGLPoint3D()
            pt.x = x + d.x * 0.2
            pt.y = y + d.y * 0.2
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
    gNewParticleGroupDef.flags = UInt32(PARTICLE_FLAGS_BOUNCE)
    gNewParticleGroupDef.gravity = 700
    gNewParticleGroupDef.magnetism = 0
    gNewParticleGroupDef.baseScale = 10
    gNewParticleGroupDef.decayRate = 0.4
    gNewParticleGroupDef.fadeRate = 0.7
    gNewParticleGroupDef.particleTextureNum = UInt8(PARTICLE_SObjType_BlueSpark)
    gNewParticleGroupDef.srcBlend = GL_SRC_ALPHA
    gNewParticleGroupDef.dstBlend = GL_ONE
    pg = NewParticleGroup(&gNewParticleGroupDef)
    if pg != -1 {
        for _ in 0..<70 {
            var d = OGLVector3D()
            d.x = RandomFloat2() * 600.0
            d.y = RandomFloat2() * 600.0
            d.z = RandomFloat2() * 600.0

            var pt = OGLPoint3D()
            pt.x = x + d.x * 0.05
            pt.y = y + d.y * 0.05
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

    // CONFETTI
    gNewConfettiGroupDef.magicNum = 0
    gNewConfettiGroupDef.flags = UInt32(PARTICLE_FLAGS_DONTCHECKGROUND)
    gNewConfettiGroupDef.gravity = 300
    gNewConfettiGroupDef.baseScale = 6.0
    gNewConfettiGroupDef.decayRate = 1.0
    gNewConfettiGroupDef.fadeRate = 1.0
    gNewConfettiGroupDef.confettiTextureNum = UInt8(PARTICLE_SObjType_Confetti_NanoFlesh)

    pg = NewConfettiGroup(&gNewConfettiGroupDef)
    if pg != -1 {
        for _ in 0..<150 {
            var d = OGLVector3D()
            d.x = RandomFloat2() * 400.0
            d.y = RandomFloat2() * 400.0
            d.z = RandomFloat2() * 400.0

            var pt = OGLPoint3D()
            pt.x = x + d.x * 0.05
            pt.y = y + d.y * 0.05
            pt.z = z + d.z * 0.05

            var newConfettiDef = NewConfettiDefType()
            newConfettiDef.groupNum = pg
            newConfettiDef.scale = 1.0 + RandomFloat()
            newConfettiDef.rot.x = RandomFloat() * SwPI2
            newConfettiDef.rot.y = RandomFloat() * SwPI2
            newConfettiDef.rot.z = RandomFloat() * SwPI2
            newConfettiDef.deltaRot.x = RandomFloat2() * 20.0
            newConfettiDef.deltaRot.y = RandomFloat2() * 20.0
            newConfettiDef.deltaRot.z = 0
            newConfettiDef.alpha = Float(FULL_ALPHA)
            newConfettiDef.fadeDelay = 1.0 + RandomFloat()

            let stop: Bool = withUnsafeMutablePointer(to: &pt) { ptPtr in
                withUnsafeMutablePointer(to: &d) { dPtr in
                    newConfettiDef.where = ptPtr
                    newConfettiDef.delta = dPtr
                    return AddConfettiToGroup(&newConfettiDef) != 0
                }
            }
            if stop {
                break
            }
        }
    }

    // OTHER
    HidePlayer(player)

    let t: Float = GetPlayerInfoEntry(0)!.pointee.numFreeLives <= 0 ? 6.0 : 3.0 // longer death timer if the game is over (so we can see the YOU LOSE sign
    SetDeathTimer(Int32(playerNum), t)
    GetPlayerInfoEntry(Int32(playerNum))!.pointee.invincibilityTimer = t

    PlayEffect_Parms3D(Int16(EFFECT_PLANECRASH), &gCoord, UInt32(NORMAL_CHANNEL_RATE), 0.5)
    PlayRumbleEffect(Int16(EFFECT_PLANECRASH), Int32(playerNum))
}

// MARK: - Player hit by weapon callback
//
// This callback is invoked whenever a trap's weapon hits a player object (such as gun turret blaster bullets)

@c @implementation
public func PlayerHitByWeaponCallback(_ weapon: UnsafeMutablePointer<ObjNode>, _ player: UnsafeMutablePointer<ObjNode>, _ hitCoord: UnsafeMutablePointer<OGLPoint3D>?, _ hitNormal: UnsafeMutablePointer<OGLVector3D>?) -> UInt8 {
    let p = player.pointee.PlayerNum
    var playerKilled: UInt8 = 0

    let pi = GetPlayerInfoEntry(Int32(p))!

    // DOUBLE-CHECK FOR SHIELD
    //
    // Most weapons will hit the shield geometry before ever getting here.
    // However, some things like the bomb shockwaves will hit both the
    // shield and the player, so be careful.
    if pi.pointee.shieldPower > 0 {
        if weapon.pointee.Kind == Int32(WeaponType.sonicScream.rawValue) {
            _ = playerShieldHitByWeaponCallback(weapon, pi.pointee.shieldObj, hitCoord, hitNormal)
        }
    }
    // NO SHIELD, SO HURT PLAYER
    else {
        playerKilled = PlayerLoseHealth(Int16(p), weapon.pointee.Damage, UInt8(PlayerDeathType.deathDive.rawValue), nil, 1)
    }

    return playerKilled
}

// MARK: - Trigger callback: player
//
// This gets called when one player touches another player.

private let cDoTrig_Player: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?) -> UInt8 = { trigger, theNode in
    DoTrig_Player(trigger!, theNode!)
}

@c @implementation
public func DoTrig_Player(_ trigger: UnsafeMutablePointer<ObjNode>, _ theNode: UnsafeMutablePointer<ObjNode>) -> UInt8 {
    PlayEffect3D(Int16(EFFECT_BODYHIT), &trigger.pointee.Coord)

    // THE ANGLE OF IMPACT WILL DETERMINE THE DAMAGE INFLICTED
    let angle = acosf(OGLVector3D_Dot(&trigger.pointee.MotionVector, &theNode.pointee.MotionVector))
    var damage = angle / (Float(PI) / 2.0)
    if damage < 0.5 {
        damage = 0.5
    }

    // HURT BOTH PLAYERS
    let p1 = trigger.pointee.PlayerNum
    let p2 = theNode.pointee.PlayerNum

    let p1Dead = PlayerLoseHealth(Int16(p1), damage, UInt8(PlayerDeathType.deathDive.rawValue), nil, 1) != 0
    GetPlayerInfoEntry(Int32(p1))!.pointee.invincibilityTimer = 0.5

    let p2Dead = PlayerLoseHealth(Int16(p2), damage, UInt8(PlayerDeathType.deathDive.rawValue), &gCoord, 1) != 0
    GetPlayerInfoEntry(Int32(p2))!.pointee.invincibilityTimer = 0.5

    PlayRumbleEffect(Int16(EFFECT_BODYHIT), Int32(p1))
    PlayRumbleEffect(Int16(EFFECT_BODYHIT), Int32(p2))

    // SPECIAL STUFF FOR BATTLE MODE
    //
    // We need to check if both players lost simultaneously
    if gVSMode == .battle {
        let p0Info = GetPlayerInfoEntry(0)!
        let p1Info = GetPlayerInfoEntry(1)!

        // DID BOTH PLAYERS JUST DIE, AND WERE BOTH OUT OF FREE LIVES? IF SO, IT'S A DRAW
        if p1Dead && p2Dead && p0Info.pointee.numFreeLives <= 0 && p1Info.pointee.numFreeLives <= 0 {
            ShowWinLose(0, 2) // draw
            ShowWinLose(1, 2) // draw
            StartLevelCompletion(5.0)
        }
        // DID PLAYER 1 JUST BITE IT?
        else if p1Dead && p0Info.pointee.numFreeLives <= 0 {
            ShowWinLose(0, 1) // lose
            ShowWinLose(1, 0) // win
            StartLevelCompletion(5.0)
        }
        // DID PLAYER 2 JUST BITE IT?
        else if p2Dead && p1Info.pointee.numFreeLives <= 0 {
            ShowWinLose(1, 1) // lose
            ShowWinLose(0, 0) // win
            StartLevelCompletion(5.0)
        }
    }

    return 1 // handle as solid collision
}

// MARK: - Create player shield
//
// This creates the physical shield object which is always active as long as the player
// has some shield power. It remains invisible until the shield is hit by something which
// causes it to momentarily become visible.

@c @implementation
public func CreatePlayerShield(_ playerNum: Int16) {
    let pi = GetPlayerInfoEntry(Int32(playerNum))!
    let player = pi.pointee.objNode!

    // MAKE SHIELD OBJ
    if pi.pointee.shieldObj == nil {
        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_WEAPONS)
        def.type = UInt8(WEAPONS_ObjType_Shield)
        def.scale = player.pointee.BoundingSphereRadius * 1.1
        def.coord = player.pointee.Coord
        def.flags = UInt32(STATUS_BIT_GLOW | STATUS_BIT_DOUBLESIDED | STATUS_BIT_NOZWRITES | STATUS_BIT_ROTXZY | STATUS_BIT_UVTRANSFORM | STATUS_BIT_NOFOG)
        def.slot = Int16(SLOT_OF_DUMB - 1)
        def.moveCall = nil
        def.drawCall = cDrawPlayerShield
        def.rot = 0

        let shield = MakeNewDisplayGroupObject(&def)!

        shield.pointee.PlayerNum = UInt8(playerNum)
        shield.pointee.CType = UInt32(CTYPE_WEAPONTEST) | UInt32(CTYPE_MISC) | UInt32(CTYPE_PLAYERSHIELD)
        shield.pointee.HitByWeaponHandler = cPlayerShieldHitByWeaponCallback

        pi.pointee.shieldObj = shield

        shield.pointee.ColorFilter.a = 0.0 // start hidden
    }
}

// MARK: - Update player shield

@c @implementation
public func UpdatePlayerShield(_ playerNum: Int16) {
    let pi = GetPlayerInfoEntry(Int32(playerNum))!
    guard let shield = pi.pointee.shieldObj else { // do we have a shield?
        return
    }

    let player = pi.pointee.objNode!
    let fps = gFramesPerSecondFrac

    // FADE OUT
    shield.pointee.ColorFilter.a -= fps * 3.0
    if shield.pointee.ColorFilter.a <= 0.0 {
        shield.pointee.ColorFilter.a = 0.0

        // IS THE SHIELD EMPTY?
        if pi.pointee.shieldPower <= 0.0 {
            DeleteObject(shield) // nix the shield
            pi.pointee.shieldObj = nil
            return
        }
    }

    // HIDE WITH PLAYER
    if player.pointee.StatusBits & UInt32(STATUS_BIT_HIDDEN) != 0 {
        shield.pointee.StatusBits |= UInt32(STATUS_BIT_HIDDEN)
    } else {
        shield.pointee.StatusBits &= ~UInt32(STATUS_BIT_HIDDEN)
    }

    // DO TEXTURE ANIMATION
    shield.pointee.TextureTransformU += fps * 0.8
    shield.pointee.TextureTransformV += fps * 0.3
    shield.pointee.SpecialF.0 += fps * -0.4
    shield.pointee.SpecialF.1 += fps * -0.5

    // UPDATE TRANSFORMS
    shield.pointee.Coord = player.pointee.Coord
    shield.pointee.Rot = player.pointee.Rot

    UpdateObjectTransforms(shield)
}

// MARK: - Player shield hit by weapon callback

private let cPlayerShieldHitByWeaponCallback: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<OGLPoint3D>?, UnsafeMutablePointer<OGLVector3D>?) -> UInt8 = { bullet, shield, hitCoord, hitTriangleNormal in
    playerShieldHitByWeaponCallback(bullet!, shield!, hitCoord, hitTriangleNormal)
}

private func playerShieldHitByWeaponCallback(_ bullet: UnsafeMutablePointer<ObjNode>, _ shield: UnsafeMutablePointer<ObjNode>, _ hitCoord: UnsafeMutablePointer<OGLPoint3D>?, _ hitTriangleNormal: UnsafeMutablePointer<OGLVector3D>?) -> UInt8 {
    let playerNum = shield.pointee.PlayerNum // see which player's shield got hit
    let pi = GetPlayerInfoEntry(Int32(playerNum))!

    // IF SHIELD IS ALREADY GONE THEN LET BULLET THRU
    if pi.pointee.shieldPower <= 0.0 {
        return 0
    }

    // SEE IF SHIELD IS GONE
    //
    // Once shield power is set to 0 it will delete itself during the update function above
    HitPlayerShield(Int16(playerNum), bullet.pointee.Damage, 1.0, 0)

    return 0
}

// MARK: - Hit player shield

@c @implementation
public func HitPlayerShield(_ playerNum: Int16, _ damage: Float, _ shieldGlowDuration: Float, _ disorientPlayer: UInt8) {
    let pi = GetPlayerInfoEntry(Int32(playerNum))!
    let shield = pi.pointee.shieldObj

    if pi.pointee.invincibilityTimer <= 0.0 { // if still invincible then don't dec the shield
        pi.pointee.shieldPower -= damage // cause damage to shield
        if pi.pointee.shieldPower <= 0.0 {
            pi.pointee.shieldPower = 0.0
        }
    }

    if let shield { // make sure shield obj really exists
        // PLAY EFFECT IF SHIELD WAS ALMOST DIMMED
        if shield.pointee.ColorFilter.a < 0.2 {
            PlayEffect_Parms3D(Int16(EFFECT_SHIELD), &pi.pointee.coord, UInt32(NORMAL_CHANNEL_RATE), 0.3)
            PlayRumbleEffect(Int16(EFFECT_SHIELD), Int32(playerNum))
        }

        // MAKE IT GLOW
        shield.pointee.ColorFilter.a = shieldGlowDuration
    }

    // DISORIENT PLAYER
    if disorientPlayer != 0 {
        DisorientPlayer(pi.pointee.objNode!)
    }
}

// MARK: - Draw player shield
//
// This is a bit of a hack. Basically, we temporarily modify the TriMesh structure
// so that it appears to have all the data needed for drawing multi-textured.

private let cDrawPlayerShield: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNode in
    drawPlayerShield(theNode!)
}

private func drawPlayerShield(_ theNode: UnsafeMutablePointer<ObjNode>) {
    let mo = GetBG3DGroupObject(Int32(MODEL_GROUP_WEAPONS), Int32(WEAPONS_ObjType_Shield))!.assumingMemoryBound(to: MOVertexArrayObject.self)
    let va = mo.pointer(to: \.objectData)! // point to vertex array data

    // MAKE TEMPORARY MODIFICATIONS
    va.pointee.numMaterials = 2
    va.pointee.materials.1 = va.pointee.materials.0
    va.pointee.uvs.1 = va.pointee.uvs.0

    OGL_ActiveTextureUnit(UInt32(GL_TEXTURE1))
    glMatrixMode(GLenum(GL_TEXTURE)) // set texture matrix
    glTranslatef(theNode.pointee.SpecialF.0, theNode.pointee.SpecialF.1, 0)
    glMatrixMode(GLenum(GL_MODELVIEW))
    OGL_ActiveTextureUnit(UInt32(GL_TEXTURE0))

    // DRAW IT
    MO_DrawObject(UnsafeMutableRawPointer(theNode.pointee.BaseGroup))

    // RESTORE MODS
    va.pointee.numMaterials = 1
    va.pointee.materials.1 = nil
    va.pointee.uvs.1 = nil

    OGL_ActiveTextureUnit(UInt32(GL_TEXTURE1))
    glMatrixMode(GLenum(GL_TEXTURE)) // set texture matrix
    glLoadIdentity()
    glMatrixMode(GLenum(GL_MODELVIEW))
    OGL_ActiveTextureUnit(UInt32(GL_TEXTURE0))
}

// MARK: - Calc max altitude

@c @implementation
public func CalcPlayerMaxAltitude(_ x: Float, _ z: Float) -> Float {
    var maxAlt: Float

    switch gLevelNum {
    case Int16(LEVEL_NUM_ADVENTURE1):
        maxAlt = GetTerrainY(x, z) + MAX_ALTITUDE_DIFF
        if maxAlt > MAX_ALTITUDE {
            maxAlt = MAX_ALTITUDE
        }

    default:
        maxAlt = MAX_ALTITUDE
    }

    return maxAlt
}

// MARK: - Update player steering

@c @implementation
public func UpdatePlayerSteering(_ playerNum: Int32) {
    let playerInfo = GetPlayerInfoEntry(playerNum)!

    // SET PLAYER AXIS CONTROLS
    var pitch = GetNeedAnalogSteering(Int32(kNeed_PitchUp), Int32(kNeed_PitchDown), playerNum)
    var yaw = GetNeedAnalogSteering(Int32(kNeed_YawLeft), Int32(kNeed_YawRight), playerNum)

    // AND FINALLY SEE IF MOUSE DELTAS ARE BEST (FOR KB/M FALLBACK PLAYER ONLY)
    if playerNum == Int32(gNumPlayers) - 1 {
        let mouseSensitivityFrac = Float(gGamePrefs.mouseSensitivityLevel) * 0.01

        let mouseDelta = GetMouseDelta()

        let mult: Float = 0.08 * mouseSensitivityFrac

        var mouseYaw = mouseDelta.x * mult // scale down deltas for our use
        var mousePitch = mouseDelta.y * mult

        if mouseYaw > 1.0 { // keep x values pinned
            mouseYaw = 1.0
        } else if mouseYaw < -1.0 {
            mouseYaw = -1.0
        }

        if fabsf(mouseYaw) > fabsf(yaw) { // is the mouse delta better than what we've got from the other devices?
            yaw = mouseYaw
        }

        if mousePitch > 1.0 { // keep y values pinned
            mousePitch = 1.0
        } else if mousePitch < -1.0 {
            mousePitch = -1.0
        }

        if fabsf(mousePitch) > fabsf(pitch) { // is the mouse delta better than what we've got from the other devices?
            pitch = mousePitch
        }
    }

    // INVERT PITCH IF REQUESTED
    if gGamePrefs.invertVerticalSteering != 0 {
        pitch = -pitch
    }

    // EXPOSE VALUES TO GAME
    playerInfo.pointee.analogControlX = yaw
    playerInfo.pointee.analogControlZ = pitch

    // FULL INVENTORY IF CHEAT KEY COMBO
    if IsCheatKeyComboDown() != 0 {
        playerInfo.pointee.numFreeLives = max(playerInfo.pointee.numFreeLives, 3)
        playerInfo.pointee.shieldPower = MAX_SHIELD_POWER
        playerInfo.pointee.health = 1
        playerInfo.pointee.jetpackFuel = 2 // give me more fuel than the max

        let weaponQuantity = weaponQuantityBase(playerInfo)
        weaponQuantity[Int(WeaponType.blaster.rawValue)] = 999
        weaponQuantity[Int(WeaponType.clusterShot.rawValue)] = 999
        weaponQuantity[Int(WeaponType.bomb.rawValue)] = 999
        weaponQuantity[Int(WeaponType.heatSeeker.rawValue)] = 999

        if GetPlayerInfoEntry(playerNum)!.pointee.shieldObj == nil { // see if need to create the shield object
            CreatePlayerShield(Int16(playerNum))
        }
    }
}
