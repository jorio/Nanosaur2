// Holes.swift - Port of Holes.c to Swift

private let holeModeInactive: Int32 = 0
private let holeModeSource: Int32 = 1
private let holeModeDest: Int32 = 2

private let maxHoleTargets = 11

@inline(__always) private func jointTransformMatrixBase(_ skelObjData: UnsafeMutablePointer<SkeletonObjDataType>) -> UnsafeMutablePointer<OGLMatrix4x4> {
    UnsafeMutableRawPointer(skelObjData.pointer(to: \.jointTransformMatrix)!).assumingMemoryBound(to: OGLMatrix4x4.self)
}

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    @discardableResult
    func addHole(x: Float, z: Float) -> UInt8 {
        var def = NewObjectDefinitionType()
        def.genre = UInt8(EVENT_GENRE)
        def.coord.x = x
        def.coord.z = z
        def.coord.y = pointee.terrainY
        def.flags = 0
        def.scale = 1
        def.slot = Int16(SLOT_OF_DUMB + 50)
        def.moveCall = cMoveHole

        let newObj = MakeNewObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list

        newObj.pointee.What = Int32(WhatType.hole.rawValue)
        newObj.pointee.Kind = Int32(pointee.parm.0) // remember hole group #

        newObj.pointee.Mode = holeModeInactive
        newObj.pointee.Timer = RandomFloat() * 2.0 // delay until worm

        return 1 // item was added
    }
}

private let cMoveHole: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }
    let fps = gFramesPerSecondFrac

    switch theNode.pointee.Mode {
    // SEE IF SHOULD MAKE NEW WORM

    case holeModeInactive:
        // SEE IF CAN DELETE

        if TrackTerrainItem(theNode) != 0 {
            DeleteObject(theNode)
            return
        }

        // CHECK TIMER

        theNode.pointee.Timer -= fps
        if theNode.pointee.Timer <= 0.0 {
            makeHoleWorm(theNode) // try to make worm come out of here
            theNode.pointee.Timer = 1.0 + RandomFloat() * 1.0 // delay for next time
        }

    // DO SOURCE HOLE DIRT

    case holeModeSource, holeModeDest:
        if theNode.pointee.Flag.0 != 0 {
            theNode.pointee.SpecialF.0 += fps
            if theNode.pointee.SpecialF.0 < 1.0 {
                spewDirtFromHole(theNode)
            }
        }

    default:
        break
    }
}

private func makeHoleWorm(_ hole: UnsafeMutablePointer<ObjNode>) {
    var targets = [UnsafeMutablePointer<ObjNode>?](repeating: nil, count: maxHoleTargets)
    var numTargets = 0

    // SCAN FOR AVAILABLE DESTINATION HOLE

    // BUILD LIST OF ELIGIBLE TARGET ELECTRODES

    var thisNode = gFirstNodePtr
    repeat {
        if thisNode != hole { // dont target itself
            if thisNode!.pointee.What == Int32(WhatType.hole.rawValue) { // only look for holes
                if thisNode!.pointee.Kind == hole.pointee.Kind { // in same group?
                    if thisNode!.pointee.Mode == holeModeInactive { // only allow inactive holes
                        targets[numTargets] = thisNode
                        numTargets += 1
                        if numTargets >= maxHoleTargets {
                            break
                        }
                    }
                }
            }
        }
        thisNode = thisNode!.pointee.NextNode
    } while thisNode != nil

    // CHOOSE A RANDOM TARGET

    if numTargets == 0 {
        return
    }

    let theTarget = targets[Int(RandomRange(0, UInt16(numTargets - 1)))]!

    let dist = CalcQuickDistance(theTarget.pointee.Coord.x, theTarget.pointee.Coord.z, hole.pointee.Coord.x, hole.pointee.Coord.z) // calc dist between targets
    let minY = dist * 0.25
    let maxY = hole.pointee.Coord.y + (dist * 0.8)

    // CONSTRUCT A SPLINE BETWEEN HOLES

    // CALC "FROM" NUBS

    var nubs = [OGLPoint3D](repeating: OGLPoint3D(), count: 5)
    nubs[0] = hole.pointee.Coord
    nubs[0].y -= dist * 1.5
    nubs[1] = hole.pointee.Coord

    // CALC "TO" NUBS

    nubs[3] = theTarget.pointee.Coord
    nubs[4] = theTarget.pointee.Coord
    nubs[4].y -= dist * 1.5 // last nub is a dummy nub, so move it down to set angle of spline

    // CALC TOP OF ARCH NUB

    nubs[2].x = (hole.pointee.Coord.x + theTarget.pointee.Coord.x) * 0.5
    nubs[2].z = (hole.pointee.Coord.z + theTarget.pointee.Coord.z) * 0.5

    nubs[2].y = (hole.pointee.Coord.y + theTarget.pointee.Coord.y) * 0.5

    var p: Int16 = 0
    var holeCoord = hole.pointee.Coord
    _ = CalcDistanceToClosestPlayer(&holeCoord, &p)
    let playerY = GetPlayerInfoEntry(Int32(p)).pointee.coord.y
    if (playerY - hole.pointee.Coord.y) < minY {
        nubs[2].y += minY // set to min height
    } else {
        var temp = playerY * 0.95 // calc desired y

        if temp > maxY {
            temp = maxY
        }
        nubs[2].y = temp // set height to player's
    }

    // TRY TO GENERATE A SPLINE

    let splineNum = nubs.withUnsafeMutableBufferPointer { buf in
        GenerateCustomSpline(5, buf.baseAddress!, 800)
    }
    if splineNum == -1 {
        return
    }

    // MAKE WORM OBJECT

    var def = NewObjectDefinitionType()
    def.type = UInt8(SkeletonType.worm.rawValue)
    def.animNum = 0
    def.scale = 6.0
    def.coord = hole.pointee.Coord
    def.flags = gAutoFadeStatusBits
    def.slot = 491
    def.moveCall = cMoveHoleWorm
    def.rot = 0

    let worm = MakeNewSkeletonObject(&def)!

    worm.pointee.Skeleton!.pointee.JointsAreGlobal = 1

    worm.pointee.SplineNum = UInt8(splineNum)
    worm.pointee.SplinePlacement = 0.04

    worm.pointee.SpecialPtr.0 = UnsafeMutableRawPointer(hole)
    worm.pointee.SpecialPtr.1 = UnsafeMutableRawPointer(theTarget)

    // SET COLLISION STUFF

    worm.pointee.CType = UInt32(CTYPE_WEAPONTEST | CTYPE_PLAYERTEST)
    worm.pointee.CBits = 0
    worm.pointee.Damage = 0.2

    // SET HOLE INFO

    hole.pointee.Mode = holeModeSource
    theTarget.pointee.Mode = holeModeDest

    hole.pointee.Flag.0 = 0 // holes have not spewed dirt yet
    theTarget.pointee.Flag.0 = 0

    // PRIME IT

    updateWormJoints(worm, Int16(splineNum), 0)
    UpdateSkinnedGeometry(worm)
}

private let cMoveHoleWorm: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { wormOpt in
    guard let worm = wormOpt else { return }
    let fps = gFramesPerSecondFrac
    let splineNum = Int16(worm.pointee.SplineNum)

    let from = worm.pointee.SpecialPtr.0!.assumingMemoryBound(to: ObjNode.self) // get from-to hole ObjNodes
    let to = worm.pointee.SpecialPtr.1!.assumingMemoryBound(to: ObjNode.self)

    GetObjectInfo(worm)

    let numPointsInSpline = Float(GetCustomSplineSlot(Int32(splineNum)).pointee.numPoints)
    worm.pointee.SplinePlacement += fps * 0.19
    let splineIndex = worm.pointee.SplinePlacement

    // SEE IF @ END OF SPLINE

    if splineIndex >= 0.98 {
        FreeACustomSpline(splineNum)

        from.pointee.Mode = holeModeInactive
        to.pointee.Mode = holeModeInactive

        DeleteObject(worm)
        return
    }

    // GET NEW COORD ON SPLINE

    let i = Int(splineIndex * numPointsInSpline)

    gCoord = GetCustomSplineSlot(Int32(splineNum)).pointee.splinePoints![i]

    // UPDATE JOINTS ON SPLINE

    updateWormJoints(worm, splineNum, Int32(i))

    // SEE IF START DIRT

    // SEE IF START @ FROM

    if from.pointee.Flag.0 == 0 {
        let dist = abs(from.pointee.Coord.y - gCoord.y)
        if dist < 300.0 {
            from.pointee.Flag.0 = 1
            from.pointee.SpecialF.0 = 0
            PlayEffect_Parms3D(Int16(EFFECT_DIRT), &from.pointee.Coord, UInt32(NORMAL_CHANNEL_RATE) - (MyRandomLong() & 0x1fff), 2.0)
        }
    }

    // SEE IF START @ TO

    else if (to.pointee.Flag.0 == 0) && (from.pointee.SpecialF.0 > 0.5) {
        let dist = abs(to.pointee.Coord.y - gCoord.y)
        if dist < 250.0 {
            to.pointee.Flag.0 = 1
            to.pointee.SpecialF.0 = 0
            PlayEffect_Parms3D(Int16(EFFECT_DIRT), &to.pointee.Coord, UInt32(NORMAL_CHANNEL_RATE) - (MyRandomLong() & 0x1fff), 2.0)
        }
    }

    UpdateObject(worm)
}

// MARK: - Update Worm Joints

private func updateWormJoints(_ theNode: UnsafeMutablePointer<ObjNode>, _ splineNum: Int16, _ splineIndexIn: Int32) {
    let skeleton = theNode.pointee.Skeleton!
    let skeletonDef = skeleton.pointee.skeletonDefinition!

    let numJoints = Int(skeletonDef.pointee.NumBones) // get # joints in this skeleton

    let scale = theNode.pointee.Scale.x

    // TRANSFORM EACH JOINT TO WORLD-SPACE
    //
    // NOTE:  to get the head aimed correctly, we create a 1st dummy joint.
    //			The dummy joint isn't part of the worm - it's just a "leader".

    var prevCoord = OGLPoint3D(x: 0, y: 0, z: 0)
    var splineIndex = Float(splineIndexIn)
    let splinePoints = GetCustomSplineSlot(Int32(splineNum)).pointee.splinePoints!
    let jointMatricesBase = jointTransformMatrixBase(skeleton)

    for jointNum in -1..<numJoints {
        // GET COORDS OF THIS SEGMENT

        let coord = splinePoints[Int(splineIndex)]

        splineIndex -= 6.0 * scale // prepare for next segment's index
        if splineIndex < 0 {
            splineIndex = 0
        }

        if jointNum != -1 {
            var up = OGLVector3D(x: 0.99, y: 0.01, z: 0) // NOTE:  we must use a slightly off-axis up vector to avoid getting parallel vectors below
            var m2 = OGLMatrix4x4()
            var m = OGLMatrix4x4()

            // TRANSFORM JOINT'S MATRIX TO WORLD COORDS

            m.setScale(scale, scale, scale)
            var coordVar = coord
            var prevCoordVar = prevCoord
            SetLookAtMatrixAndTranslate(&m2, &up, &coordVar, &prevCoordVar)
            (jointMatricesBase + jointNum).pointee = m.multiplied(by: m2)
        }

        prevCoord = coord
    }
}

// MARK: - Spew Dirt From Hole

private func spewDirtFromHole(_ theNode: UnsafeMutablePointer<ObjNode>) {
    let fps = gFramesPerSecondFrac

    theNode.pointee.ParticleTimer -= fps
    if theNode.pointee.ParticleTimer <= 0.0 {
        theNode.pointee.ParticleTimer += 0.03 // reset timer

        var particleGroup = theNode.pointee.ParticleGroup
        var magicNum = theNode.pointee.ParticleMagicNum

        if (particleGroup == -1) || (VerifyParticleGroupMagicNum(particleGroup, magicNum) == 0) {
            magicNum = MyRandomLong() // generate a random magic num
            theNode.pointee.ParticleMagicNum = magicNum

            var groupDef = NewParticleGroupDefType()
            groupDef.magicNum = magicNum
            groupDef.type = UInt8(ParticleType.fallingSparks.rawValue)
            groupDef.flags = UInt32(PARTICLE_FLAGS_BOUNCE)
            groupDef.gravity = 2000
            groupDef.magnetism = 0
            groupDef.baseScale = 70.0
            groupDef.decayRate = 0.9
            groupDef.fadeRate = 0.5
            groupDef.particleTextureNum = UInt8(PARTICLE_SObjType_SwampDirt)
            groupDef.srcBlend = Int32(GL_SRC_ALPHA)
            groupDef.dstBlend = Int32(GL_ONE_MINUS_SRC_ALPHA)
            particleGroup = NewParticleGroup(&groupDef)
            theNode.pointee.ParticleGroup = particleGroup
        }

        if particleGroup != -1 {
            let x = theNode.pointee.Coord.x
            let y = theNode.pointee.Coord.y
            let z = theNode.pointee.Coord.z

            for _ in 0..<4 {
                var p = OGLPoint3D()
                p.x = x + RandomFloat2() * 160.0
                p.y = y
                p.z = z + RandomFloat2() * 160.0

                var d = OGLVector3D()
                d.x = RandomFloat2() * 450.0
                d.y = 900.0 + RandomFloat() * 300.0
                d.z = RandomFloat2() * 450.0

                let added: UInt8 = withUnsafeMutablePointer(to: &p) { pPtr in
                    withUnsafeMutablePointer(to: &d) { dPtr in
                        var newParticleDef = NewParticleDefType()
                        newParticleDef.groupNum = particleGroup
                        newParticleDef.`where` = pPtr
                        newParticleDef.delta = dPtr
                        newParticleDef.scale = RandomFloat() * 1.5 + 1.0
                        newParticleDef.rotZ = RandomFloat() * SwPI2
                        newParticleDef.rotDZ = RandomFloat2() * 5.0
                        newParticleDef.alpha = 1.0
                        return AddParticleToGroup(&newParticleDef)
                    }
                }

                if added != 0 {
                    theNode.pointee.ParticleGroup = -1
                    break
                }
            }
        }
    }
}
