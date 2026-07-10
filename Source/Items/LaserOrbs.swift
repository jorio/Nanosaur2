// LaserOrbs.swift - Port of LaserOrbs.c to Swift

private let laserOrbScale: Float = 4.0
private let laserOrbShootDist: Float = 3700.0
private let laserDamage: Float = 0.15 // per second of exposure

private enum OrbMode: Int32 {
    case seeking = 0
    case shooting = 1
}

private let laserBeamSize: Float = 20.0

private let orbRingYOff: Float = laserOrbScale * 67.0
private let orbRingDiameter: Float = laserOrbScale * 21.0

// MARK: - Add laser orb

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    @discardableResult
    func addLaserOrb(x: Float, z: Float) -> UInt8 {
        if gGamePrefs.isKiddieMode { // dont add these in kiddie mode
            return 0
        }

        let newObj = makeLaserOrb(x, z)

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list
        newObj.pointee.MoveCall = cMoveLaserOrb

        return 1 // item was added
    }
}

// MARK: - Make laser orb

private func makeLaserOrb(_ x: Float, _ z: Float) -> UnsafeMutablePointer<ObjNode> {
    // MAKE BODY

    var def = NewObjectDefinitionType()
    def.group = UInt8(MODEL_GROUP_GLOBAL)
    def.type = UInt8(GLOBAL_ObjType_LaserOrb)
    def.scale = laserOrbScale
    def.coord.x = x
    def.coord.z = z
    def.coord.y = GetTerrainY(x, z)
    def.flags = gEngine.game.autoFadeStatusBits
    def.slot = Int16(SLOT_OF_DUMB) - 2
    def.moveCall = nil
    def.rot = RandomFloat() * SwPI2

    let newObj = MakeNewDisplayGroupObject(&def)!

    newObj.pointee.Health = 0.4
    newObj.pointee.Mode = OrbMode.seeking.rawValue

    // SET COLLISION STUFF

    newObj.pointee.CType = UInt32(CTYPE_MISC | CTYPE_WEAPONTEST | CTYPE_PLAYERTEST | CTYPE_AUTOTARGETWEAPON)
    newObj.pointee.CBits = UInt32(CBITS_ALLSOLID)
    CreateCollisionBoxFromBoundingBox(newObj, 1, 1)

    newObj.pointee.HitByWeaponHandler = cLaserOrbHitByWeaponCallback

    newObj.pointee.HeatSeekHotSpotOff.x = 0
    newObj.pointee.HeatSeekHotSpotOff.y = 40.0
    newObj.pointee.HeatSeekHotSpotOff.z = 0

    // MAKE GREEN THING

    def.type = UInt8(GLOBAL_ObjType_LaserOrbGreen)
    def.flags = gEngine.game.autoFadeStatusBits | UInt32(STATUS_BIT_UVTRANSFORM)
    def.slot += 1
    let green = MakeNewDisplayGroupObject(&def)!

    green.pointee.CType = UInt32(CTYPE_MISC | CTYPE_WEAPONTEST | CTYPE_PLAYERTEST | CTYPE_AUTOTARGETWEAPON)
    green.pointee.CBits = UInt32(CBITS_ALLSOLID)
    CreateCollisionBoxFromBoundingBox(green, 1, 1)

    green.pointee.HitByWeaponHandler = cLaserOrbHitByWeaponCallback

    // ATTACH SHADOW

    AttachShadowToObject(newObj, .circular, 7, 7, 0)

    // MAKE DUMMY OBJECT FOR DRAWING LASER BEAM

    def.genre = UInt8(CUSTOM_GENRE)
    def.slot = Int16(PARTICLE_SLOT) + 2
    def.moveCall = nil
    def.drawCall = cDrawOrbLaserBeam
    def.flags = UInt32(STATUS_BIT_DOUBLESIDED | STATUS_BIT_DONTCULL | STATUS_BIT_GLOW | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOFOG | STATUS_BIT_NOZWRITES)

    let laser = MakeNewObject(&def)!
    def.drawCall = nil

    newObj.pointee.ChainNode = green
    green.pointee.ChainHead = newObj

    green.pointee.ChainNode = laser
    laser.pointee.ChainHead = green

    return newObj
}

// MARK: - Move laser orb

private let cMoveLaserOrb: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    moveLaserOrb(theNodeOpt!)
}

// This is also called by the spline move function, so be careful!
private func moveLaserOrb(_ theNode: UnsafeMutablePointer<ObjNode>) {
    let fps = gEngine.framesPerSecondFrac
    var doUpdate = true

    // SEE IF GONE

    if !theNode.hasStatus(STATUS_BIT_ONSPLINE) {
        if TrackTerrainItem(theNode) != 0 {
            DeleteObject(theNode)
            return
        }
    }

    switch OrbMode(rawValue: theNode.pointee.Mode) {
    // LOOKING FOR A PLAYER TO SHOOT AT

    case .seeking:
        // SEE IF PLAYER IN RANGE

        var p: Int16 = 0
        let dist = CalcDistanceToClosestPlayer(&theNode.pointee.Coord, &p) // calc dist to player
        let pu = UInt8(p)

        if dist <= laserOrbShootDist {
            theNode.pointee.TargetOff.x = RandomFloat2() * 150.0 // set random aim
            theNode.pointee.TargetOff.y = RandomFloat2() * 150.0
            theNode.pointee.TargetOff.z = RandomFloat2() * 150.0

            theNode.pointee.PlayerNum = pu
            theNode.pointee.Mode = OrbMode.shooting.rawValue
            theNode.pointee.Timer = 0.3 + RandomFloat() * 1.5
            updateLaserOrbCollision(theNode, fps)
        }

    // SHOOTING LASER

    case .shooting:
        // SEE IF DONE

        theNode.pointee.Timer -= fps
        if theNode.pointee.Timer <= 0.0 {
            theNode.pointee.Mode = OrbMode.seeking.rawValue
        }

        // UPDATE COLLISION

        else {
            if CalcLaserVectorToPlayer(theNode, Int32(theNode.pointee.PlayerNum)) != 0 {
                theNode.pointee.Mode = OrbMode.seeking.rawValue
                doUpdate = true
            } else {
                updateLaserOrbCollision(theNode, fps)
            }
        }

    default:
        break
    }

    // UPDATE OTHER THINGS

    guard doUpdate else { return }

    if theNode.pointee.CType == UInt32(INVALID_NODE_FLAG) { // see if already deleted
        SwFatal("MoveLaserOrb: orb got nixed mid-stream!")
    }

    theNode.pointee.Rot.y -= fps * 1.8
    theNode.updateTransforms()
    UpdateShadow(theNode)
    CalcObjectBoxFromNode(theNode)
    updateLaserOrbSparkles(theNode)

    // ANIMATE GREEN THING

    let green = theNode.pointee.ChainNode!

    green.pointee.TextureTransformU -= fps * 2.5
    green.pointee.Coord = theNode.pointee.Coord
    green.pointee.BaseTransformMatrix = theNode.pointee.BaseTransformMatrix
    SetObjectTransformMatrix(green)
}

private func updateLaserOrbCollision(_ theNode: UnsafeMutablePointer<ObjNode>, _ fps: Float) {
    var ray = OGLRay()
    var worldHitCoord = OGLPoint3D()
    var hitNormal = OGLVector3D()
    var hitObj: UnsafeMutablePointer<ObjNode>?

    ray.direction = theNode.pointee.MotionVector

    ray.origin.x = theNode.pointee.Coord.x + ray.direction.x * orbRingDiameter
    ray.origin.y = theNode.pointee.Coord.y + orbRingYOff
    ray.origin.z = theNode.pointee.Coord.z + ray.direction.z * orbRingDiameter

    // DO RAY COLLISION

    HideObjectChain(theNode) // temporarily hide so we don't collide with ourselves

    var ctypes = UInt32(CTYPE_SOLIDTOENEMY | CTYPE_MISC | CTYPE_FENCE | CTYPE_TERRAIN | // set CTYPE mask to find what we're looking for
        CTYPE_PLAYER1 | CTYPE_PLAYER2 | CTYPE_ENEMY | CTYPE_WEAPONTEST)

    let hit = withUnsafeMutablePointer(to: &hitObj) { hitObjPtr in
        HandleRayCollision(&ray, hitObjPtr, &worldHitCoord, &hitNormal, &ctypes) != 0
    }

    ShowObjectChain(theNode)

    // WE HIT SOMETHING

    if hit {
        theNode.pointee.SpecialF.0 = ray.distance // LaserDistance: get dist to target from the returned ray info

        if let hitObj, hitObj != theNode { // did we hit an objNode (but not ourselves)
            theNode.pointee.Damage = laserDamage * fps // set special damage
            if let handler = hitObj.pointee.HitByWeaponHandler { // see if there is a handler for this object
                _ = handler(theNode, hitObj, &worldHitCoord, &hitNormal)
            }
        }
    } else {
        theNode.pointee.SpecialF.0 = 10000.0 // LaserDistance: set as "infinite"
    }
}

// MARK: - Calc laser vector to player

// Returns true if angle is too steep
@discardableResult
private func CalcLaserVectorToPlayer(_ orb: UnsafeMutablePointer<ObjNode>, _ p: Int32) -> UInt8 {
    var v = OGLVector3D()

    let player = GetPlayerInfoEntry(p)

    let px = player.pointee.coord.x + orb.pointee.TargetOff.x // get player coords with offset
    let py = player.pointee.coord.y + orb.pointee.TargetOff.y
    let pz = player.pointee.coord.z + orb.pointee.TargetOff.z

    var x = orb.pointee.Coord.x // get coords of center of laser ring
    let y = orb.pointee.Coord.y + orbRingYOff
    var z = orb.pointee.Coord.z

    v.x = px - x // calc vector to player
    v.y = py - y
    v.z = pz - z
    FastNormalizeVector(v.x, v.y, v.z, &v)

    x += v.x * orbRingDiameter // adjust vector from point on laser ring
    z += v.z * orbRingDiameter

    v.x = px - x // calc better vector to player
    v.y = py - y
    v.z = pz - z
    FastNormalizeVector(v.x, v.y, v.z, &orb.pointee.MotionVector)

    // SEE IF ANGLE IS TOO STEEP

    let dot = gUp.dot(orb.pointee.MotionVector)
    if dot > 0.5 || dot < -0.5 {
        return 1
    }

    return 0
}

// MARK: -

// MARK: - Laser orb hit by weapon callback

// Returns true if object should stop bullet.
private let cLaserOrbHitByWeaponCallback: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<OGLPoint3D>?, UnsafeMutablePointer<OGLVector3D>?) -> UInt8 = { bullet, theNodeOpt, _, _ in
    var theNode = theNodeOpt!

    // FIND BASE OBJECT

    while let chainHead = theNode.pointee.ChainHead {
        theNode = chainHead
    }

    // CAUSE DAMAGE

    theNode.pointee.Health -= bullet!.pointee.Damage
    if theNode.pointee.Health <= 0.0 {
        explodeLaserOrb(theNode)
    }

    return 1
}

// MARK: - Explode laser orb

private func explodeLaserOrb(_ theNode: UnsafeMutablePointer<ObjNode>) {
    PlayEffect_Parms3D(Int16(EFFECT_TURRETEXPLOSION), &theNode.pointee.Coord, UInt32(NORMAL_CHANNEL_RATE), 2.0)

    MakeFireRing(theNode.pointee.Coord.x, theNode.pointee.Coord.y + (laserOrbScale * 60.0), theNode.pointee.Coord.z)

    // MAKE FIREBALL

    let x = theNode.pointee.Coord.x
    let y = theNode.pointee.Coord.y
    let z = theNode.pointee.Coord.z

    gEngine.particles.newGroupDef.magicNum = 0
    gEngine.particles.newGroupDef.particleType = .fallingSparks
    gEngine.particles.newGroupDef.flags = UInt32(PARTICLE_FLAGS_DONTCHECKGROUND)
    gEngine.particles.newGroupDef.gravity = -50
    gEngine.particles.newGroupDef.magnetism = 0
    gEngine.particles.newGroupDef.baseScale = 20
    gEngine.particles.newGroupDef.decayRate = -5.0
    gEngine.particles.newGroupDef.fadeRate = 0.7
    gEngine.particles.newGroupDef.particleTextureNum = UInt8(PARTICLE_SObjType_Fire)
    gEngine.particles.newGroupDef.srcBlend = GL_SRC_ALPHA
    gEngine.particles.newGroupDef.dstBlend = GL_ONE
    var pg = NewParticleGroup(&gEngine.particles.newGroupDef)
    if pg != -1 {
        for _ in 0..<150 {
            var d = OGLVector3D()
            d.y = RandomFloat2() * 100.0
            d.x = RandomFloat2() * 100.0
            d.z = RandomFloat2() * 100.0

            var pt = OGLPoint3D()
            pt.x = x + d.x * 0.8
            pt.y = y + RandomFloat() * (laserOrbScale * 70.0)
            pt.z = z + d.z * 0.8

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

    gEngine.particles.newGroupDef.magicNum = 0
    gEngine.particles.newGroupDef.particleType = .fallingSparks
    gEngine.particles.newGroupDef.flags = UInt32(PARTICLE_FLAGS_DONTCHECKGROUND)
    gEngine.particles.newGroupDef.gravity = 0
    gEngine.particles.newGroupDef.magnetism = 0
    gEngine.particles.newGroupDef.baseScale = 15
    gEngine.particles.newGroupDef.decayRate = 0.5
    gEngine.particles.newGroupDef.fadeRate = 1.0
    gEngine.particles.newGroupDef.particleTextureNum = UInt8(PARTICLE_SObjType_WhiteSpark4)
    gEngine.particles.newGroupDef.srcBlend = GL_SRC_ALPHA
    gEngine.particles.newGroupDef.dstBlend = GL_ONE
    pg = NewParticleGroup(&gEngine.particles.newGroupDef)
    if pg != -1 {
        for _ in 0..<220 {
            let q = RandomFloat() * SwPI2
            var d = OGLVector3D()
            d.x = sin(q) * 800.0
            d.y = RandomFloat2() * 20.0
            d.z = cos(q) * 800.0

            var pt = OGLPoint3D()
            pt.x = x + d.x * 0.05
            pt.y = y + (laserOrbScale * 60.0)
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

    // FRAGMENT

    ExplodeGeometry(theNode, 600, .fromOrigin, 3, 1.0)

    // DELETE

    theNode.pointee.TerrainItemPtr = nil // dont ever come back
    DeleteObject(theNode)
}

// MARK: -

// MARK: - Draw orb laser beam

private let cDrawOrbLaserBeam: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { beamOpt in
    let beam = beamOpt!
    let orb = beam.pointee.ChainHead!.pointee.ChainHead!

    // DRAW THE LASER BEAM

    if orb.pointee.Mode == OrbMode.shooting.rawValue {
        var uv = [OGLTextureCoord](repeating: OGLTextureCoord(), count: 4)
        var p = [OGLPoint3D](repeating: OGLPoint3D(), count: 4)
        var side = OGLVector3D()

        MO_DrawMaterial(GetSpriteGroupPtr(Int32(SPRITE_GROUP_GLOBAL))![Int(GLOBAL_SObjType_LaserOrbBeam)].materialObject?.assumingMemoryBound(to: MOMaterialObject.self)) // activate material
        OGL_SetColor4f(1, 1, 1, orb.pointee.Timer * 2.0)

        let dist = orb.pointee.SpecialF.0 // LaserDistance

        orb.pointee.TextureTransformU -= gEngine.framesPerSecondFrac * 8.0
        let u = orb.pointee.TextureTransformU

        uv[0].u = u
        uv[0].v = 0
        uv[1].u = u
        uv[1].v = 1
        uv[2].u = u + dist * 0.007
        uv[2].v = 1
        uv[3].u = u + dist * 0.007
        uv[3].v = 0

        // GET INFO

        let vx = orb.pointee.MotionVector.x
        let vy = orb.pointee.MotionVector.y
        let vz = orb.pointee.MotionVector.z

        let x = orb.pointee.Coord.x + vx * orbRingDiameter
        let y = orb.pointee.Coord.y + orbRingYOff
        let z = orb.pointee.Coord.z + vz * orbRingDiameter

        // DRAW VERTICAL QUAD

        p[0].x = x
        p[0].y = y - laserBeamSize
        p[0].z = z

        p[1].x = x
        p[1].y = y + laserBeamSize
        p[1].z = z

        p[2].x = x + vx * dist
        p[2].y = p[1].y + vy * dist
        p[2].z = z + vz * dist

        p[3].x = p[2].x
        p[3].y = p[0].y + vy * dist
        p[3].z = p[2].z

        gEngine.renderer.beginImmediate(.quads)

        for i in 0..<4 {
            gEngine.renderer.texCoord2f(uv[i].u, uv[i].v)
            gEngine.renderer.vertex3f(p[i].x, p[i].y, p[i].z)
        }

        gEngine.renderer.endImmediate()

        // DRAW HORIZONTAL QUAD

        side = gUp.cross(orb.pointee.MotionVector) // calc side x-axis vector

        p[0].x = x + side.x * laserBeamSize
        p[0].y = y
        p[0].z = z + side.z * laserBeamSize

        p[1].x = x - side.x * laserBeamSize
        p[1].y = y
        p[1].z = z - side.z * laserBeamSize

        p[2].x = p[1].x + vx * dist
        p[2].y = y + vy * dist
        p[2].z = p[1].z + vz * dist

        p[3].x = p[0].x + vx * dist
        p[3].y = p[2].y
        p[3].z = p[0].z + vz * dist

        gEngine.renderer.beginImmediate(.quads)

        for i in 0..<4 {
            gEngine.renderer.texCoord2f(uv[i].u, uv[i].v)
            gEngine.renderer.vertex3f(p[i].x, p[i].y, p[i].z)
        }

        gEngine.renderer.endImmediate()
    }
}

// MARK: - Update laser orb sparkles

private func updateLaserOrbSparkles(_ orb: UnsafeMutablePointer<ObjNode>) {
    // SEE IF NIX SPARKLES

    if orb.pointee.Mode == OrbMode.seeking.rawValue {
        var i = sparklesBase(orb)[0]
        if i != -1 {
            DeleteSparkle(i)
            sparklesBase(orb)[0] = -1
        }

        i = sparklesBase(orb)[1]
        if i != -1 {
            DeleteSparkle(i)
            sparklesBase(orb)[1] = -1
        }

        // ALSO BE SURE NO SFX

        if orb.pointee.EffectChannel != -1 {
            StopAChannel(&orb.pointee.EffectChannel)
        }
    }

    // UPDATE SPARKLES
    else {
        // GET INFO

        let vx = orb.pointee.MotionVector.x
        let vy = orb.pointee.MotionVector.y
        let vz = orb.pointee.MotionVector.z

        let x = orb.pointee.Coord.x + vx * orbRingDiameter
        let y = orb.pointee.Coord.y + orbRingYOff
        let z = orb.pointee.Coord.z + vz * orbRingDiameter

        // SOURCE SPARKLE

        var i = sparklesBase(orb)[0]
        if i != -1 { // do we already have one?
            let sparkle = GetSparkleSlot(Int32(i))!
            sparkle.pointee.where.x = x // just update the coord
            sparkle.pointee.where.y = y
            sparkle.pointee.where.z = z
        } else {
            i = GetFreeSparkle(orb) // make new sparkle
            sparklesBase(orb)[0] = i
            if i != -1 {
                let sparkle = GetSparkleSlot(Int32(i))!
                sparkle.pointee.flags = UInt32(SPARKLE_FLAG_OMNIDIRECTIONAL | SPARKLE_FLAG_RANDOMSPIN | SPARKLE_FLAG_FLICKER | SPARKLE_FLAG_ALWAYSDRAW)
                sparkle.pointee.where.x = x
                sparkle.pointee.where.y = y
                sparkle.pointee.where.z = z

                sparkle.pointee.color.r = 1
                sparkle.pointee.color.g = 1
                sparkle.pointee.color.b = 1
                sparkle.pointee.color.a = 1

                sparkle.pointee.scale = 120.0
                sparkle.pointee.separation = 40.0

                sparkle.pointee.textureNum = Int16(PARTICLE_SObjType_BlueGlint)
            }
        }

        // TARGET SPARKLE

        let tx = x + vx * orb.pointee.SpecialF.0
        let ty = y + vy * orb.pointee.SpecialF.0
        let tz = z + vz * orb.pointee.SpecialF.0

        i = sparklesBase(orb)[1]
        if i != -1 { // do we already have one?
            let sparkle = GetSparkleSlot(Int32(i))!
            sparkle.pointee.where.x = tx // just update the coord
            sparkle.pointee.where.y = ty
            sparkle.pointee.where.z = tz
        } else {
            i = GetFreeSparkle(orb) // make new sparkle
            sparklesBase(orb)[1] = i
            if i != -1 {
                let sparkle = GetSparkleSlot(Int32(i))!
                sparkle.pointee.flags = UInt32(SPARKLE_FLAG_OMNIDIRECTIONAL | SPARKLE_FLAG_RANDOMSPIN | SPARKLE_FLAG_FLICKER | SPARKLE_FLAG_ALWAYSDRAW)
                sparkle.pointee.where.x = tx
                sparkle.pointee.where.y = ty
                sparkle.pointee.where.z = tz

                sparkle.pointee.color.r = 1
                sparkle.pointee.color.g = 1
                sparkle.pointee.color.b = 1
                sparkle.pointee.color.a = 1

                sparkle.pointee.scale = 120.0
                sparkle.pointee.separation = 40.0

                sparkle.pointee.textureNum = Int16(PARTICLE_SObjType_BlueGlint)
            }
        }

        // UPDATE SOUND EFFECT WHILE WE'RE HERE

        let player = GetPlayerInfoEntry(Int32(orb.pointee.PlayerNum))

        if orb.pointee.EffectChannel == -1 {
            orb.pointee.EffectChannel = PlayEffect_Parms3D(Int16(EFFECT_LASERBEAM), &player.pointee.coord, UInt32(NORMAL_CHANNEL_RATE) * 4 / 5, 0.5)
        } else {
            Update3DSoundChannel(Int16(EFFECT_LASERBEAM), &orb.pointee.EffectChannel, &player.pointee.coord)
        }
    }
}

@inline(__always) private func sparklesBase(_ n: UnsafeMutablePointer<ObjNode>) -> UnsafeMutablePointer<Int16> {
    UnsafeMutableRawPointer(n.pointer(to: \.Sparkles)!).assumingMemoryBound(to: Int16.self)
}

// MARK: -

// MARK: - Prime laser orb

func PrimeLaserOrb(_ splineNum: Int, _ itemPtr: UnsafeMutablePointer<SplineItemType>!) -> UInt8 {
    // GET SPLINE INFO

    let placement = itemPtr.pointee.placement
    var x: Float = 0
    var z: Float = 0
    GetCoordOnSpline(gEngine.splines.splineList + splineNum, placement, &x, &z)

    // MAKE RAPTOR

    let newObj = makeLaserOrb(x, z)

    // SET BETTER INFO

    newObj.setStatus(STATUS_BIT_ONSPLINE)
    newObj.pointee.SplineItemPtr = itemPtr
    newObj.pointee.SplineNum = UInt8(splineNum)
    newObj.pointee.SplinePlacement = placement
    newObj.pointee.SplineMoveCall = cMoveLaserOrbOnSpline // set move call

    // ADD SPLINE OBJECT TO SPLINE OBJECT LIST
    //
    // NOTE:  Normally we'd detach the ObjNode, but Laser Orbs are special and
    //        they need to always be active!!!

    // DetachObject(newObj, true) // detach this object from the linked list
    AddToSplineObjectList(newObj, 1)

    return 1
}

// MARK: - Move laser orb on spline

private let cMoveLaserOrbOnSpline: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    let theNode = theNodeOpt!

    // MOVE ALONG THE SPLINE

    IncreaseSplineIndex(theNode, 100)
    GetObjectCoordOnSpline(theNode)

    // UPDATE STUFF IF IN RANGE

    theNode.pointee.Coord.y = GetTerrainY(theNode.pointee.Coord.x, theNode.pointee.Coord.z) // calc y coord

    moveLaserOrb(theNode)
}
