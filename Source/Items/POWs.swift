// POWs.swift - Port of POWs.c to Swift

private let powYOff: Float = 200.0

private let powScale: Float = 10.0

private enum PowMode: Int32 {
    case normal = 0
    case fadeOut = 1
    case fadeIn = 2
    case delay = 3
}

private let powReappearDelay: Float = 10.0

@inline(__always) private func weaponQuantityBase(_ p: UnsafeMutablePointer<PlayerInfoType>) -> UnsafeMutablePointer<Int16> {
    UnsafeMutableRawPointer(p.pointer(to: \.weaponQuantity)!).assumingMemoryBound(to: Int16.self)
}

// MARK: - Add weapon powerup

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    @discardableResult
    func addWeaponPOW(x: Float, z: Float) -> UInt8 {
        let weaponType = Int16(pointee.parm.0)

        if weaponType == Int16(WeaponType.sonicScream.rawValue) { // since this is an infinite weapon, don't need POW's
            return 1
        }

        // MAKE FRAME

        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_GLOBAL)
        def.type = UInt8(GLOBAL_ObjType_POWFrame)
        def.scale = powScale
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY + powYOff
        def.flags = gAutoFadeStatusBits
        def.slot = Int16(PLAYER_SLOT) + 55
        def.moveCall = cMovePOW
        def.rot = RandomFloat() * SwPI2

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        newObj.pointee.Special.0 = Int(weaponType) // WeaponPOWType
        newObj.pointee.Mode = PowMode.normal.rawValue

        switch WeaponType(rawValue: Int32(weaponType)) {
        case .heatSeeker:
            if gVSMode == .none { // fewer missiles in 2P modes
                newObj.pointee.Special.1 = 10 // WeaponPOWQuantity
            } else {
                newObj.pointee.Special.1 = 4
            }

        case .blaster:
            newObj.pointee.Special.1 = 25

        default:
            newObj.pointee.Special.1 = 20
        }

        newObj.pointee.SpecialF.0 = RandomFloat() * SwPI2 // Wobble

        // SET COLLISION STUFF

        newObj.pointee.CType = UInt32(CTYPE_TRIGGER | CTYPE_POWERUP)
        newObj.pointee.CBits = 0
        CreateCollisionBoxFromBoundingBox_Maximized(newObj, 1.5)

        newObj.pointee.TriggerCallback = cDoTrig_WeaponPOW

        // MAKE MEMBRANE

        def.type = UInt8(Int32(GLOBAL_ObjType_BlasterPOWMembrane) + Int32(weaponType))
        def.flags |= UInt32(STATUS_BIT_DOUBLESIDED | STATUS_BIT_GLOW | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOFOG | STATUS_BIT_NOFOG)
        def.slot = Int16(SLOT_OF_DUMB) + 3
        def.moveCall = nil
        let membrane = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.ChainNode = membrane

        AttachShadowToObject(newObj, .circular, 5, 2, 1)

        return 1 // item was added
    }
}

// MARK: - Move weapon powerup

private let cMovePOW: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { powOpt in
    let pow = powOpt!
    let mem = pow.pointee.ChainNode!
    let fps = gFramesPerSecondFrac

    if TrackTerrainItem(pow) != 0 { // just check to see if it's gone
        DeleteObject(pow)
        return
    }

    // SPIN

    pow.pointee.Rot.y += fps * Float.pi

    // WOBBLE

    pow.pointee.SpecialF.0 += fps * 2.5 // Wobble
    pow.pointee.Coord.y = pow.pointee.InitCoord.y + sin(pow.pointee.SpecialF.0) * 15.0

    pow.updateTransforms()
    UpdateShadow(pow)

    // UPDATE MODE SPECIFIC

    switch PowMode(rawValue: pow.pointee.Mode) {
    case .normal:
        break

    case .fadeOut:
        mem.pointee.ColorFilter.a -= fps * 2.0
        if mem.pointee.ColorFilter.a <= 0.0 {
            mem.pointee.ColorFilter.a = 0.0
            if gEngine.player.numPlayers > 1 { // if in multi-player level, then set delay until POW fades back in
                pow.pointee.Mode = PowMode.delay.rawValue

                if gVSMode == .race {
                    pow.pointee.Timer = powReappearDelay * 0.5
                } else {
                    pow.pointee.Timer = powReappearDelay
                }
            } else {
                if pow.isTotallyCulled() != 0 { // 1-player mode, so just nix once culled
                    pow.pointee.TerrainItemPtr = nil // don't come back
                    DeleteObject(pow)
                    return
                }
            }
        }

    case .fadeIn:
        mem.pointee.ColorFilter.a += fps * 2.0
        if mem.pointee.ColorFilter.a >= 1.0 {
            mem.pointee.ColorFilter.a = 1.0
            pow.pointee.Mode = PowMode.normal.rawValue
            pow.pointee.CType = UInt32(CTYPE_TRIGGER | CTYPE_POWERUP)
        }

    case .delay:
        pow.pointee.Timer -= fps
        if pow.pointee.Timer <= 0.0 {
            pow.pointee.Mode = PowMode.fadeIn.rawValue
        }

    default:
        break
    }

    // UPDATE MEMBRANE

    mem.pointee.Rot.y = pow.pointee.Rot.y
    mem.pointee.Coord.y = pow.pointee.Coord.y
    mem.updateTransforms()
}

// MARK: - Trigger callback: weapon pow

// Returns TRUE if want to handle hit as a solid
private let cDoTrig_WeaponPOW: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?) -> UInt8 = { triggerOpt, theNodeOpt in
    let trigger = triggerOpt!
    let theNode = theNodeOpt!

    let weaponType = Int(trigger.pointee.Special.0) // WeaponPOWType
    let quan = Int16(clamping: trigger.pointee.Special.1) // WeaponPOWQuantity
    let playerNum = theNode.pointee.PlayerNum

    let pi = GetPlayerInfoEntry(Int32(playerNum))

    weaponQuantityBase(pi)[weaponType] += quan // add in quantity
    if weaponQuantityBase(pi)[weaponType] > 999 { // max @ 999
        weaponQuantityBase(pi)[weaponType] = 999
    }

    if pi.currentWeapon == .none { // if no weapon was selected then select this
        pi.pointee.currentWeapon = Int16(weaponType)
    }

    // MAKE FADE OUT

    trigger.pointee.Mode = PowMode.fadeOut.rawValue
    trigger.pointee.CType = 0

    // PLAY EFFECT

    PlayEffect_Parms3D(Int16(EFFECT_GETPOW), &trigger.pointee.Coord, UInt32(NORMAL_CHANNEL_RATE), 0.6)
    PlayRumbleEffect(Int16(EFFECT_GETPOW), Int32(playerNum))

    return 0
}

// MARK: -

// MARK: - Add health powerup

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    @discardableResult
    func addHealthPOW(x: Float, z: Float) -> UInt8 {
        // MAKE FRAME

        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_GLOBAL)
        def.type = UInt8(GLOBAL_ObjType_HealthPOWFrame)
        def.scale = powScale
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY + powYOff
        def.flags = gAutoFadeStatusBits
        def.slot = Int16(PLAYER_SLOT) + 55
        def.moveCall = cMovePOW
        def.rot = RandomFloat() * SwPI2

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list
        newObj.pointee.Mode = PowMode.normal.rawValue

        // SET COLLISION STUFF

        newObj.pointee.CType = UInt32(CTYPE_TRIGGER | CTYPE_POWERUP)
        newObj.pointee.CBits = 0
        CreateCollisionBoxFromBoundingBox_Maximized(newObj, 1.5)

        newObj.pointee.TriggerCallback = cDoTrig_HealthPOW

        // MAKE MEMBRANE

        def.type = UInt8(GLOBAL_ObjType_HealthPOWMembrane)
        def.flags |= UInt32(STATUS_BIT_DOUBLESIDED | STATUS_BIT_GLOW | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOFOG)
        def.slot = Int16(SLOT_OF_DUMB) + 3
        def.moveCall = nil
        let membrane = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.ChainNode = membrane

        AttachShadowToObject(newObj, .circular, 4, 1.5, 1)

        return 1 // item was added
    }
}

// MARK: - Trigger callback: health pow

// Returns TRUE if want to handle hit as a solid
private let cDoTrig_HealthPOW: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?) -> UInt8 = { triggerOpt, theNodeOpt in
    let trigger = triggerOpt!
    let theNode = theNodeOpt!

    let playerNum = theNode.pointee.PlayerNum
    let pi = GetPlayerInfoEntry(Int32(playerNum))

    pi.pointee.health += 0.5
    if pi.pointee.health > 1.0 {
        pi.pointee.health = 1.0
    }

    // MAKE FADE OUT

    trigger.pointee.Mode = PowMode.fadeOut.rawValue
    trigger.pointee.CType = 0

    // PLAY EFFECT

    PlayEffect_Parms3D(Int16(EFFECT_GETPOW), &trigger.pointee.Coord, UInt32(NORMAL_CHANNEL_RATE), 0.6)
    PlayRumbleEffect(Int16(EFFECT_GETPOW), Int32(playerNum))

    return 0
}

// MARK: -

// MARK: - Add fuel powerup

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    @discardableResult
    func addFuelPOW(x: Float, z: Float) -> UInt8 {
        // MAKE FRAME

        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_GLOBAL)
        def.type = UInt8(GLOBAL_ObjType_POWFrame)
        def.scale = powScale
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY + powYOff
        def.flags = gAutoFadeStatusBits
        def.slot = Int16(PLAYER_SLOT) + 55
        def.moveCall = cMovePOW
        def.rot = RandomFloat() * SwPI2

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list
        newObj.pointee.Mode = PowMode.normal.rawValue

        // SET COLLISION STUFF

        newObj.pointee.CType = UInt32(CTYPE_TRIGGER | CTYPE_POWERUP)
        newObj.pointee.CBits = 0
        CreateCollisionBoxFromBoundingBox_Maximized(newObj, 1.5)

        newObj.pointee.TriggerCallback = cDoTrig_FuelPOW

        // MAKE MEMBRANE

        def.type = UInt8(GLOBAL_ObjType_FuelPOWMembrane)
        def.flags |= UInt32(STATUS_BIT_DOUBLESIDED | STATUS_BIT_GLOW | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOFOG)
        def.slot = Int16(SLOT_OF_DUMB) + 3
        def.moveCall = nil
        let membrane = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.ChainNode = membrane

        AttachShadowToObject(newObj, .circular, 5, 2, 1)

        return 1 // item was added
    }
}

// MARK: - Trigger callback: fuel pow

// Returns TRUE if want to handle hit as a solid
private let cDoTrig_FuelPOW: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?) -> UInt8 = { triggerOpt, theNodeOpt in
    let trigger = triggerOpt!
    let theNode = theNodeOpt!

    let playerNum = theNode.pointee.PlayerNum
    let pi = GetPlayerInfoEntry(Int32(playerNum))

    if gVSMode == .none {
        pi.pointee.jetpackFuel += 0.5
    } else {
        pi.pointee.jetpackFuel += 0.25 // in 2P modes fuel gives less
    }

    if pi.pointee.jetpackFuel > 1.0 {
        pi.pointee.jetpackFuel = 1.0
    }

    // MAKE FADE OUT

    trigger.pointee.Mode = PowMode.fadeOut.rawValue
    trigger.pointee.CType = 0

    // PLAY EFFECT

    PlayEffect_Parms3D(Int16(EFFECT_GETPOW), &trigger.pointee.Coord, UInt32(NORMAL_CHANNEL_RATE), 0.6)
    PlayRumbleEffect(Int16(EFFECT_GETPOW), Int32(playerNum))

    return 0
}

// MARK: -

// MARK: - Add shield powerup

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    @discardableResult
    func addShieldPOW(x: Float, z: Float) -> UInt8 {
        // MAKE FRAME

        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_GLOBAL)
        def.type = UInt8(GLOBAL_ObjType_POWFrame)
        def.scale = powScale
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY + powYOff
        def.flags = gAutoFadeStatusBits
        def.slot = Int16(PLAYER_SLOT) + 55
        def.moveCall = cMovePOW
        def.rot = RandomFloat() * SwPI2

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list
        newObj.pointee.Mode = PowMode.normal.rawValue

        // SET COLLISION STUFF

        newObj.pointee.CType = UInt32(CTYPE_TRIGGER | CTYPE_POWERUP)
        newObj.pointee.CBits = 0
        CreateCollisionBoxFromBoundingBox_Maximized(newObj, 1.5)

        newObj.pointee.TriggerCallback = cDoTrig_ShieldPOW

        // MAKE MEMBRANE

        def.type = UInt8(GLOBAL_ObjType_ShieldPOWMembrane)
        def.flags |= UInt32(STATUS_BIT_DOUBLESIDED | STATUS_BIT_GLOW | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOFOG)
        def.slot = Int16(SLOT_OF_DUMB) + 3
        def.moveCall = nil
        let membrane = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.ChainNode = membrane

        AttachShadowToObject(newObj, .circular, 5, 2, 1)

        return 1 // item was added
    }
}

// MARK: - Trigger callback: shield pow

// Returns TRUE if want to handle hit as a solid
private let cDoTrig_ShieldPOW: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?) -> UInt8 = { triggerOpt, theNodeOpt in
    let trigger = triggerOpt!
    let theNode = theNodeOpt!

    // GIVE PLAYER SHIELD POWER

    let playerNum = theNode.pointee.PlayerNum
    let pi = GetPlayerInfoEntry(Int32(playerNum))

    pi.pointee.shieldPower += MAX_SHIELD_POWER * 0.5
    if pi.pointee.shieldPower > MAX_SHIELD_POWER {
        pi.pointee.shieldPower = MAX_SHIELD_POWER
    }

    if pi.pointee.shieldObj == nil { // see if need to create the shield object
        CreatePlayerShield(Int16(playerNum))
    }

    // MAKE FADE OUT

    trigger.pointee.Mode = PowMode.fadeOut.rawValue
    trigger.pointee.CType = 0

    // PLAY EFFECT

    PlayEffect_Parms3D(Int16(EFFECT_GETPOW), &trigger.pointee.Coord, UInt32(NORMAL_CHANNEL_RATE), 0.6)
    PlayRumbleEffect(Int16(EFFECT_GETPOW), Int32(playerNum))

    return 0
}

// MARK: -

// MARK: - Add free life

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    @discardableResult
    func addFreeLifePOW(x: Float, z: Float) -> UInt8 {
        // MAKE FRAME

        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_GLOBAL)
        def.type = UInt8(GLOBAL_ObjType_POWFrame)
        def.scale = powScale
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY + powYOff
        def.flags = gAutoFadeStatusBits
        def.slot = Int16(PLAYER_SLOT) + 55
        def.moveCall = cMovePOW
        def.rot = RandomFloat() * SwPI2

        let newObj = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        // SET COLLISION STUFF

        newObj.pointee.CType = UInt32(CTYPE_TRIGGER | CTYPE_POWERUP)
        newObj.pointee.CBits = 0
        CreateCollisionBoxFromBoundingBox_Maximized(newObj, 1.5)

        newObj.pointee.TriggerCallback = cDoTrig_FreeLifePOW

        // MAKE MEMBRANE

        def.type = UInt8(GLOBAL_ObjType_FreeLifePOWMembrane)
        def.flags |= UInt32(STATUS_BIT_DOUBLESIDED | STATUS_BIT_GLOW | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOFOG)
        def.slot = Int16(SLOT_OF_DUMB) + 3
        def.moveCall = nil
        let membrane = MakeNewDisplayGroupObject(&def)!

        newObj.pointee.ChainNode = membrane

        AttachShadowToObject(newObj, .circular, 4, 1.5, 1)

        return 1 // item was added
    }
}

// MARK: - Trigger callback: free life pow

// Returns TRUE if want to handle hit as a solid
private let cDoTrig_FreeLifePOW: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?) -> UInt8 = { triggerOpt, theNodeOpt in
    let trigger = triggerOpt!
    let theNode = theNodeOpt!

    let playerNum = theNode.pointee.PlayerNum
    let pi = GetPlayerInfoEntry(Int32(playerNum))

    pi.pointee.numFreeLives += 1

    // MAKE FADE OUT

    trigger.pointee.Mode = PowMode.fadeOut.rawValue
    trigger.pointee.CType = 0

    // PLAY EFFECT

    PlayEffect_Parms3D(Int16(EFFECT_GETPOW), &trigger.pointee.Coord, UInt32(NORMAL_CHANNEL_RATE), 0.6)
    PlayRumbleEffect(Int16(EFFECT_GETPOW), Int32(playerNum))

    return 0
}
