// Electrodes.swift - Port of Electrodes.c to Swift

private let electrodeScale: Float = 2.0
private let electrodeTop: Float = 1200.0 * electrodeScale
private let maxElectrodeTargets = 8

private let maxZaps = 30
private let maxZapEndpoints = 30

private struct ZapType {
    var isUsed = false
    var numEndpoints = 0
    var alpha: Float = 0

    var endpointSparkles: [Int16] = [-1, -1]

    var endpointCoords = [OGLPoint3D](repeating: OGLPoint3D(), count: maxZapEndpoints)

    var triMesh = [MOVertexArrayData](repeating: MOVertexArrayData(), count: 2) // double-buffered VAR trimeshes
}

private let zapThickness: Float = 20.0
private let zapRandomSize: Float = 20.0
private let endpointOffset: Float = 70.0

/// Electrode-zap state. Owned by GameEngine as `gEngine.zaps`.
final class ZapSystem {
    fileprivate var pool = [ZapType](repeating: ZapType(), count: maxZaps)
    fileprivate var buffer: Int16 = 0 // which VAR double buffer? 0 or 1
}

@inline(__always) private func vertexArrayUVsBase(_ data: inout MOVertexArrayData) -> UnsafeMutablePointer<UnsafeMutablePointer<OGLTextureCoord>?> {
    withUnsafeMutablePointer(to: &data) {
        UnsafeMutableRawPointer($0.pointer(to: \.uvs)!).assumingMemoryBound(to: UnsafeMutablePointer<OGLTextureCoord>?.self)
    }
}

@inline(__always) private func vertexArrayMaterialsBase(_ data: inout MOVertexArrayData) -> UnsafeMutablePointer<UnsafeMutablePointer<MOMaterialObject>?> {
    withUnsafeMutablePointer(to: &data) {
        UnsafeMutableRawPointer($0.pointer(to: \.materials)!).assumingMemoryBound(to: UnsafeMutablePointer<MOMaterialObject>?.self)
    }
}

@inline(__always) private func vertexIndicesBase(_ triangle: UnsafeMutablePointer<MOTriangleIndecies>) -> UnsafeMutablePointer<GLuint> {
    UnsafeMutableRawPointer(triangle.pointer(to: \.vertexIndices)!).assumingMemoryBound(to: GLuint.self)
}

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    @discardableResult
    func addElectrode(x: Float, z: Float) -> UInt8 {
        // MAKE POLE

        var def = NewObjectDefinitionType()
        def.group = UInt8(MODEL_GROUP_GLOBAL)
        def.type = UInt8(GLOBAL_ObjType_Electrode_Pole)
        def.scale = electrodeScale
        def.coord.x = x
        def.coord.z = z
        def.flags = gAutoFadeStatusBits
        def.slot = 161
        def.moveCall = cMoveElectrode
        def.rot = 0

        def.coord.y = GetMinTerrainY(x, z, Int16(def.group), Int16(def.type), def.scale)

        let pole = MakeNewDisplayGroupObject(&def)!

        pole.pointee.TerrainItemPtr = self // keep ptr to item list

        if pointee.flags & UInt16(ITEM_FLAGS_USER1) != 0 { // see if already got blown up
            pole.pointee.Health = 0
            pole.pointee.DeltaRot.y = 0
            pole.pointee.ColorFilter.r = 0.3
            pole.pointee.ColorFilter.g = 0.3
            pole.pointee.ColorFilter.b = 0.3
            pole.pointee.CType = UInt32(CTYPE_SOLIDTOENEMY | CTYPE_WEAPONTEST | CTYPE_PLAYERTEST)
        } else {
            pole.pointee.What = Int32(WhatType.electrode.rawValue)
            pole.pointee.Health = 1.0
            pole.pointee.DeltaRot.y = Float.pi
            pole.pointee.CType = UInt32(CTYPE_SOLIDTOENEMY | CTYPE_WEAPONTEST | CTYPE_PLAYERTEST | CTYPE_AUTOTARGETWEAPON)
        }

        // SET COLLISION STUFF

        pole.pointee.CBits = UInt32(CBITS_ALLSOLID)
        CreateCollisionBoxFromBoundingBox(pole, 1, 1)

        pole.pointee.TriggerCallback = cDoTrigElectrode
        pole.pointee.HitByWeaponHandler = cElectrodeHitByWeaponCallback

        pole.pointee.Timer = RandomFloat() * 1.0

        pole.pointee.HeatSeekHotSpotOff.x = 0
        pole.pointee.HeatSeekHotSpotOff.y = 600.0
        pole.pointee.HeatSeekHotSpotOff.z = 0

        // MAKE TOP & BOTTOM

        def.type = UInt8(GLOBAL_ObjType_Electrode_TopBottom)
        def.slot += 1
        def.moveCall = nil
        let topbot = MakeNewDisplayGroupObject(&def)!

        // SET COLLISION STUFF

        topbot.pointee.CType = UInt32(CTYPE_SOLIDTOENEMY | CTYPE_WEAPONTEST | CTYPE_PLAYERTEST)
        topbot.pointee.TriggerCallback = cDoTrigElectrode
        topbot.pointee.HitByWeaponHandler = cElectrodeHitByWeaponCallback

        pole.pointee.ChainNode = topbot
        topbot.pointee.ChainHead = pole

        // MAKE MIDDLE

        def.type = UInt8(GLOBAL_ObjType_Electrode_Middle)
        def.slot += 1
        let middle = MakeNewDisplayGroupObject(&def)!

        middle.pointee.CType = UInt32(CTYPE_SOLIDTOENEMY | CTYPE_WEAPONTEST | CTYPE_PLAYERTEST)
        middle.pointee.TriggerCallback = cDoTrigElectrode
        middle.pointee.HitByWeaponHandler = cElectrodeHitByWeaponCallback

        topbot.pointee.ChainNode = middle
        middle.pointee.ChainHead = topbot

        return 1 // item was added
    }
}

private let cMoveElectrode: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { poleOpt in
    guard let pole = poleOpt else { return }
    let fps = gFramesPerSecondFrac
    let isAlive = pole.pointee.What == Int32(WhatType.electrode.rawValue)

    // SEE IF GONE

    if TrackTerrainItem(pole) != 0 {
        DeleteObject(pole)
        return
    }

    // ROTATE PARTS

    let topbot = pole.pointee.ChainNode!
    let middle = topbot.pointee.ChainNode!

    topbot.pointee.Rot.y += pole.pointee.DeltaRot.y * fps
    middle.pointee.Rot.y -= pole.pointee.DeltaRot.y * fps

    UpdateObjectTransforms(topbot)
    UpdateObjectTransforms(middle)

    // UPDATE EFFECT

    if pole.pointee.EffectChannel == -1 {
        pole.pointee.EffectChannel = PlayEffect_Parms3D(Int16(EFFECT_ELECTRODEHUM), &pole.pointee.Coord, UInt32(NORMAL_CHANNEL_RATE) + (MyRandomLong() & 0x1fff), 0.8)
    } else {
        _ = Update3DSoundChannel(Int16(EFFECT_ELECTRODEHUM), &pole.pointee.EffectChannel, &pole.pointee.Coord)
    }

    // SEE IF IS STILL ACTIVE

    if !isAlive {
        MakeSteam(pole, pole.pointee.Coord.x, pole.pointee.Coord.y, pole.pointee.Coord.z)
        return
    }

    // FLICKER

    let c = 0.3 + (pole.pointee.Health * 0.7) // calc dim based on health

    let topbotColor = (0.7 + RandomFloat() * 0.3) * c
    topbot.pointee.ColorFilter.r = topbotColor
    topbot.pointee.ColorFilter.b = topbotColor
    topbot.pointee.ColorFilter.g = topbotColor

    let middleColor = (0.7 + RandomFloat() * 0.3) * c
    middle.pointee.ColorFilter.r = middleColor
    middle.pointee.ColorFilter.b = middleColor
    middle.pointee.ColorFilter.g = middleColor

    // SEE IF ZAP

    pole.pointee.Timer -= fps
    if pole.pointee.Timer <= 0.0 {
        var targets = [UnsafeMutablePointer<ObjNode>?](repeating: nil, count: maxElectrodeTargets)
        var numTargets = 0
        let x = pole.pointee.Coord.x
        let z = pole.pointee.Coord.z

        pole.pointee.Timer = RandomFloat() * 0.35 // reset timer

        // BUILD LIST OF ELIGIBLE TARGET ELECTRODES

        for node in allObjectNodes {
            if node != pole,
               node.pointee.What == Int32(WhatType.electrode.rawValue), // only look for electrodes
               CalcQuickDistance(x, z, node.pointee.Coord.x, node.pointee.Coord.z) < 4000.0 { // in range?
                targets[numTargets] = node
                numTargets += 1
                if numTargets >= maxElectrodeTargets {
                    break
                }
            }
        }

        // CHOOSE A RANDOM TARGET

        if numTargets > 0 {
            let theTarget = targets[Int(RandomRange(0, UInt16(numTargets - 1)))]!
            doElectrodeZap(pole, theTarget)
        }
    }
}

// MARK: - Trigger / Hit Callbacks

// Returns TRUE if want to handle hit as a solid
private let cDoTrigElectrode: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?) -> UInt8 = { mine, playerOpt in
    let player = playerOpt!
    _ = PlayerSmackedIntoObject(player, mine, .explode)

    return 1
}

// Returns true if object should stop bullet.
private let cElectrodeHitByWeaponCallback: @convention(c) (UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<ObjNode>?, UnsafeMutablePointer<OGLPoint3D>?, UnsafeMutablePointer<OGLVector3D>?) -> UInt8 = { bullet, theNodeOpt, _, _ in
    var pole = theNodeOpt!

    while let chainHead = pole.pointee.ChainHead { // scan for the parent object of the whole electrode gizmo
        pole = chainHead
    }

    pole.pointee.Health -= bullet!.pointee.Damage * 0.8
    if pole.pointee.Health <= 0.0 {
        pole.pointee.Health = 0
        pole.pointee.What = 0 // no longer a zappable electrode
        pole.pointee.TerrainItemPtr!.pointee.flags |= UInt16(ITEM_FLAGS_USER1) // set flag so will come back dead next time
        pole.pointee.CType &= ~UInt32(CTYPE_AUTOTARGETWEAPON) // dont auto-target anymore
    }

    // MAKE DIMMER

    let c = 0.3 + (pole.pointee.Health * 0.7)

    pole.pointee.ColorFilter.r = c
    pole.pointee.ColorFilter.g = c
    pole.pointee.ColorFilter.b = c

    // SLOW SPIN

    pole.pointee.DeltaRot.y = pole.pointee.Health * Float.pi

    return 1
}

// MARK: - Do Electrode Zap

private func doElectrodeZap(_ fromObj: UnsafeMutablePointer<ObjNode>, _ toObj: UnsafeMutablePointer<ObjNode>) {
    // IF BOTH ELECTRODES ARE CULLED THEN DON'T ACTUALLY MAKE THE ZAP

    if (IsObjectTotallyCulled(fromObj) != 0) && (IsObjectTotallyCulled(toObj) != 0) {
        return
    }

    // GET NEW ZAP

    let zapSlot = getFreeZapSlot()
    if zapSlot == -1 {
        return
    }

    gEngine.zaps.pool[zapSlot].alpha = 1.3 // set inital alpha of this zap

    // CALCULATE ENDPOINTS

    // DETERMINE HOW MANY ENDPOINTS

    let dist = fromObj.pointee.Coord.distance(to: toObj.pointee.Coord)

    var x = fromObj.pointee.Coord.x
    var y = fromObj.pointee.Coord.y + RandomFloat() * electrodeTop
    var z = fromObj.pointee.Coord.z

    var numEndpoints: Int
    if gGamePrefs.isLowRenderQuality {
        numEndpoints = Int(dist * 0.01) // calc # zap endpoints based on distance
    } else {
        numEndpoints = Int(dist * 0.015) // calc # zap endpoints based on distance
    }

    if numEndpoints > maxZapEndpoints {
        numEndpoints = maxZapEndpoints
    }
    if numEndpoints < 2 {
        numEndpoints = 2
    }

    gEngine.zaps.pool[zapSlot].numEndpoints = numEndpoints

    // CALC VECTOR FROM->TO

    var boltVector = OGLVector3D()
    boltVector.x = toObj.pointee.Coord.x - x
    boltVector.y = (toObj.pointee.Coord.y + 30.0 + RandomFloat() * electrodeTop) - y
    boltVector.z = toObj.pointee.Coord.z - z

    var v = OGLVector3D()
    FastNormalizeVector(boltVector.x, boltVector.y, boltVector.z, &v) // also create a normalize version

    boltVector.x -= v.x * endpointOffset // offset to get endoing away from center of pole
    boltVector.z -= v.z * endpointOffset

    let o: Float = 1.0 / Float(numEndpoints - 1)
    boltVector.x *= o // divide vector length for multiple segments
    boltVector.y *= o
    boltVector.z *= o

    // SET STARTING POINT

    gEngine.zaps.pool[zapSlot].endpointCoords[0].x = x + v.x * endpointOffset // offset to get endoing away from center of pole
    gEngine.zaps.pool[zapSlot].endpointCoords[0].z = z + v.z * endpointOffset
    gEngine.zaps.pool[zapSlot].endpointCoords[0].y = y

    // CALC INTERMEDIATE & END POINTS

    for i in 1..<numEndpoints {
        x += boltVector.x // calc linear endpoint value
        y += boltVector.y
        z += boltVector.z

        gEngine.zaps.pool[zapSlot].endpointCoords[i].x = x
        gEngine.zaps.pool[zapSlot].endpointCoords[i].y = y
        gEngine.zaps.pool[zapSlot].endpointCoords[i].z = z
    }

    // ALLOCATE ZAP GEOMETRY

    allocateZapGeometry(zapSlot)

    // MAKE ENDPOINT SPARKLES

    // FROM

    var i = GetFreeSparkle(nil) // make new sparkle
    gEngine.zaps.pool[zapSlot].endpointSparkles[0] = i
    if i != -1 {
        let sparkle = GetSparkleSlot(Int32(i))!
        sparkle.pointee.flags = UInt32(SPARKLE_FLAG_OMNIDIRECTIONAL | SPARKLE_FLAG_RANDOMSPIN | SPARKLE_FLAG_FLICKER)
        sparkle.pointee.where = gEngine.zaps.pool[zapSlot].endpointCoords[0]

        sparkle.pointee.color.r = 1
        sparkle.pointee.color.g = 1
        sparkle.pointee.color.b = 1
        sparkle.pointee.color.a = 1

        sparkle.pointee.scale = 80.0
        sparkle.pointee.separation = 10.0

        sparkle.pointee.textureNum = Int16(PARTICLE_SObjType_BlueSpark)
    }

    // TO

    i = GetFreeSparkle(nil) // make new sparkle
    gEngine.zaps.pool[zapSlot].endpointSparkles[1] = i
    if i != -1 {
        let sparkle = GetSparkleSlot(Int32(i))!
        sparkle.pointee.flags = UInt32(SPARKLE_FLAG_OMNIDIRECTIONAL | SPARKLE_FLAG_RANDOMSPIN | SPARKLE_FLAG_FLICKER)
        sparkle.pointee.where = gEngine.zaps.pool[zapSlot].endpointCoords[numEndpoints - 1]

        sparkle.pointee.color.r = 1
        sparkle.pointee.color.g = 1
        sparkle.pointee.color.b = 1
        sparkle.pointee.color.a = 1

        sparkle.pointee.scale = 80.0
        sparkle.pointee.separation = 10.0

        sparkle.pointee.textureNum = Int16(PARTICLE_SObjType_BlueSpark)
    }
}

// MARK: - Init/Free Zaps

func InitZaps() {
    gEngine.zaps.buffer = 0

    for i in 0..<maxZaps {
        gEngine.zaps.pool[i].isUsed = false // all slots are free
    }

    // CREATE DUMMY CUSTOM OBJECT TO CAUSE ZAP DRAWING AT THE DESIRED TIME

    var def = NewObjectDefinitionType()
    def.genre = UInt8(CUSTOM_GENRE)
    def.slot = Int16(SLOT_OF_DUMB + 80)
    def.flags = UInt32(STATUS_BIT_DOUBLESIDED | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOZWRITES | STATUS_BIT_NOFOG | STATUS_BIT_DONTCULL | STATUS_BIT_GLOW)
    def.moveCall = cMoveZaps
    def.drawCall = cDrawZaps
    def.scale = 1

    let newObj = MakeNewObject(&def)!
    newObj.pointee.VertexArrayMode = UInt8(VertexArrayRangeType.zaps1.rawValue)
    newObj.pointee.Damage = 1.0
}

func FreeAllZaps() {
    for i in 0..<maxZaps {
        if gEngine.zaps.pool[i].isUsed {
            freeZap(i)
        }
    }
}

// Initializes the trimesh vertex array data for this zap
private func allocateZapGeometry(_ zapSlot: Int) {
    let numEndpoints = gEngine.zaps.pool[zapSlot].numEndpoints
    let numVerts = numEndpoints * 2
    let numTriangles = numVerts - 2

    for b in 0..<2 { // allocate for both double-buffers
        gEngine.zaps.pool[zapSlot].triMesh[b].VARtype = Int16(VertexArrayRangeType.zaps1.rawValue) + Int16(b)
        gEngine.zaps.pool[zapSlot].triMesh[b].numMaterials = 1
        vertexArrayMaterialsBase(&gEngine.zaps.pool[zapSlot].triMesh[b])[0] = GetSpriteGroupPtr(Int32(SPRITE_GROUP_PARTICLES))![Int(PARTICLE_SObjType_ZapBeam)].materialObject?.assumingMemoryBound(to: MOMaterialObject.self) // set illegal ref
        gEngine.zaps.pool[zapSlot].triMesh[b].numPoints = Int32(numVerts)
        gEngine.zaps.pool[zapSlot].triMesh[b].numTriangles = Int32(numTriangles)

        // ALLOCATE VARS

        gEngine.zaps.pool[zapSlot].triMesh[b].points = OGL_AllocVertexArrayMemory(Int(MemoryLayout<OGLPoint3D>.size * numVerts), UInt8(VertexArrayRangeType.zaps1.rawValue) + UInt8(b))?.assumingMemoryBound(to: OGLPoint3D.self)
        vertexArrayUVsBase(&gEngine.zaps.pool[zapSlot].triMesh[b])[0] = OGL_AllocVertexArrayMemory(Int(MemoryLayout<OGLTextureCoord>.size * numVerts), UInt8(VertexArrayRangeType.zaps1.rawValue) + UInt8(b))?.assumingMemoryBound(to: OGLTextureCoord.self)
        gEngine.zaps.pool[zapSlot].triMesh[b].triangles = OGL_AllocVertexArrayMemory(Int(MemoryLayout<MOTriangleIndecies>.size * numTriangles), UInt8(VertexArrayRangeType.zaps1.rawValue) + UInt8(b))?.assumingMemoryBound(to: MOTriangleIndecies.self)

        gEngine.zaps.pool[zapSlot].triMesh[b].normals = nil
        gEngine.zaps.pool[zapSlot].triMesh[b].colorsFloat = nil

        // BUILD THE GEOMETRY

        // SET VERTEX POINTS

        var p = 0
        for i in 0..<numEndpoints {
            gEngine.zaps.pool[zapSlot].triMesh[b].points[p].x = gEngine.zaps.pool[zapSlot].endpointCoords[i].x // top vertex
            gEngine.zaps.pool[zapSlot].triMesh[b].points[p].y = gEngine.zaps.pool[zapSlot].endpointCoords[i].y + zapThickness
            gEngine.zaps.pool[zapSlot].triMesh[b].points[p].z = gEngine.zaps.pool[zapSlot].endpointCoords[i].z

            gEngine.zaps.pool[zapSlot].triMesh[b].points[p + 1].x = gEngine.zaps.pool[zapSlot].endpointCoords[i].x // bottom vertex
            gEngine.zaps.pool[zapSlot].triMesh[b].points[p + 1].y = gEngine.zaps.pool[zapSlot].endpointCoords[i].y - zapThickness
            gEngine.zaps.pool[zapSlot].triMesh[b].points[p + 1].z = gEngine.zaps.pool[zapSlot].endpointCoords[i].z

            p += 2
        }

        // SET VERTEX UVS

        p = 0
        var u: Float = 0
        let uvs0 = vertexArrayUVsBase(&gEngine.zaps.pool[zapSlot].triMesh[b])[0]!
        for _ in 0..<numEndpoints {
            uvs0[p].u = u // top vertex
            uvs0[p].v = 1.0

            uvs0[p + 1].u = u // bottom vertex
            uvs0[p + 1].v = 0.0

            u += 0.4
            p += 2
        }

        // SET TRIANGLES

        var t = 0
        p = 0
        for _ in 0..<(numEndpoints - 1) {
            let triangleBase = gEngine.zaps.pool[zapSlot].triMesh[b].triangles! + t
            vertexIndicesBase(triangleBase)[0] = GLuint(p)
            vertexIndicesBase(triangleBase)[1] = GLuint(p + 1)
            vertexIndicesBase(triangleBase)[2] = GLuint(p + 2)
            t += 1

            let triangleBase2 = gEngine.zaps.pool[zapSlot].triMesh[b].triangles! + t
            vertexIndicesBase(triangleBase2)[0] = GLuint(p + 2)
            vertexIndicesBase(triangleBase2)[1] = GLuint(p + 1)
            vertexIndicesBase(triangleBase2)[2] = GLuint(p + 3)
            t += 1
            p += 2
        }
    }
}

// MARK: - Move / Draw Zaps

private let cMoveZaps: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { _ in
    let fps = gFramesPerSecondFrac

    gEngine.zaps.buffer ^= 1 // toggle buffer to move & then draw

    for i in 0..<maxZaps {
        if !gEngine.zaps.pool[i].isUsed { // is this one active
            continue
        }

        // FADE OUT

        gEngine.zaps.pool[i].alpha -= fps * 1.2
        if gEngine.zaps.pool[i].alpha <= 0.0 {
            freeZap(i)
            continue
        }

        let numEndpoints = gEngine.zaps.pool[i].numEndpoints

        // RANDOMIZE THE COORDS

        var p = 0
        for j in 0..<numEndpoints {
            let y = gEngine.zaps.pool[i].endpointCoords[j].y + RandomFloat2() * zapRandomSize
            let thick = (zapThickness / 3) + zapThickness * RandomFloat()

            gEngine.zaps.pool[i].triMesh[Int(gEngine.zaps.buffer)].points[p].y = y + thick
            gEngine.zaps.pool[i].triMesh[Int(gEngine.zaps.buffer)].points[p + 1].y = y - thick

            p += 2
        }

        OGL_SetVertexArrayRangeDirty(Int16(VertexArrayRangeType.zaps1.rawValue) + gEngine.zaps.buffer)

        // SEE IF HIT PLAYER

        var lineSeg = OGLLineSegment()
        lineSeg.p1 = gEngine.zaps.pool[i].endpointCoords[0]
        lineSeg.p2 = gEngine.zaps.pool[i].endpointCoords[numEndpoints - 1]

        var worldHitCoord = OGLPoint3D()
        if let hitObj = OGL_DoLineSegmentCollision_ObjNodes(&lineSeg, UInt32(STATUS_BIT_HIDDEN), UInt32(CTYPE_PLAYERSHIELD | CTYPE_ENEMY | CTYPE_PLAYER1 | CTYPE_PLAYER2), &worldHitCoord, nil, nil, 0) {
            if let handler = hitObj.pointee.HitByWeaponHandler { // see if there is a handler for this object
                _ = handler(nil, hitObj, nil, nil)
            }
        }
    }
}

private let cDrawZaps: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { _ in
    OGL_SetColor4f(1, 1, 1, 1)

    for i in 0..<maxZaps {
        if !gEngine.zaps.pool[i].isUsed { // is this one active
            continue
        }

        gEngine.metaObjects.globalTransparency = gEngine.zaps.pool[i].alpha

        MO_DrawGeometry_VertexArray(&gEngine.zaps.pool[i].triMesh[Int(gEngine.zaps.buffer)])
    }

    gEngine.metaObjects.globalTransparency = 1.0
}

private func getFreeZapSlot() -> Int {
    for i in 0..<maxZaps {
        if !gEngine.zaps.pool[i].isUsed {
            gEngine.zaps.pool[i].isUsed = true
            return i
        }
    }
    return -1
}

private func freeZap(_ zapNum: Int) {
    SwGameAssert(gEngine.zaps.pool[zapNum].isUsed)

    for b in 0..<2 {
        OGL_FreeVertexArrayMemory(gEngine.zaps.pool[zapNum].triMesh[b].points, UInt8(VertexArrayRangeType.zaps1.rawValue) + UInt8(b))
        OGL_FreeVertexArrayMemory(vertexArrayUVsBase(&gEngine.zaps.pool[zapNum].triMesh[b])[0], UInt8(VertexArrayRangeType.zaps1.rawValue) + UInt8(b))
        OGL_FreeVertexArrayMemory(gEngine.zaps.pool[zapNum].triMesh[b].triangles, UInt8(VertexArrayRangeType.zaps1.rawValue) + UInt8(b))

        gEngine.zaps.pool[zapNum].triMesh[b].points = nil
        vertexArrayUVsBase(&gEngine.zaps.pool[zapNum].triMesh[b])[0] = nil
        gEngine.zaps.pool[zapNum].triMesh[b].triangles = nil
    }

    // FREE SPARKLES

    for i in 0..<2 {
        if gEngine.zaps.pool[zapNum].endpointSparkles[i] != -1 {
            DeleteSparkle(gEngine.zaps.pool[zapNum].endpointSparkles[i])
            gEngine.zaps.pool[zapNum].endpointSparkles[i] = -1
        }
    }

    gEngine.zaps.pool[zapNum].isUsed = false
}
