// Wormhole.swift - Port of Wormhole.c to Swift
//
// gOpenPlayerWormhole/gExitWormhole are native Swift storage now
// (converted 2026-07-07): nothing in any .c file touches them anymore.

var gOpenPlayerWormhole: UInt8 = 0
var gExitWormhole: UnsafeMutablePointer<ObjNode>!

private let playerWormholeSize: Float = 4.0
private let eggWormholeSize: Float = 4.0
private let minDistToGetEgg: Float = 1600.0

@inline(__always) private func deformedMeshesBase(_ skelObjData: UnsafeMutablePointer<SkeletonObjDataType>) -> UnsafeMutablePointer<MOVertexArrayData> {
    UnsafeMutableRawPointer(skelObjData.pointer(to: \.deformedMeshes)!).assumingMemoryBound(to: MOVertexArrayData.self)
}

@inline(__always) private func vertexArrayMaterialsBase(_ data: UnsafeMutablePointer<MOVertexArrayData>) -> UnsafeMutablePointer<UnsafeMutablePointer<MOMaterialObject>?> {
    UnsafeMutableRawPointer(data.pointer(to: \.materials)!).assumingMemoryBound(to: UnsafeMutablePointer<MOMaterialObject>?.self)
}

@inline(__always) private func vertexArrayUVsBase(_ data: UnsafeMutablePointer<MOVertexArrayData>) -> UnsafeMutablePointer<UnsafeMutablePointer<OGLTextureCoord>?> {
    UnsafeMutableRawPointer(data.pointer(to: \.uvs)!).assumingMemoryBound(to: UnsafeMutablePointer<OGLTextureCoord>?.self)
}

func InitWormholes() {
    gOpenPlayerWormhole = 0
    gExitWormhole = nil

    modifyWormholeTextures()
}

// Does some funky multi-texture assignments to the wormhole models
private func modifyWormholeTextures() {
    // PLAYER WORMHOLE

    var mo = GetBG3DGroupObject(Int32(MODEL_GROUP_GLOBAL), Int32(GLOBAL_ObjType_EntryWormhole))!.assumingMemoryBound(to: MOVertexArrayObject.self) // point to this object

    if mo.pointee.objectHeader.type == .group { // see if need to go into group
        SwFatal("ModifyWormholeTextures: object is group")
    }

    // ASSUME MO IS A VERTEX ARRAY OBJECT

    var va = mo.pointer(to: \.objectData)! // point to vertex array data

    var mat = vertexArrayMaterialsBase(va)[0]! // get pointer to material
    mat.pointee.objectData.flags |= UInt32(BG3D_MATERIALFLAG_MULTITEXTURE) // set flags for multi-texture

    mat.pointee.objectData.multiTextureCombine = UInt16(MULTI_TEXTURE_COMBINE_ADD) // set combining mode

    // EGG WORMHOLE

    mo = GetBG3DGroupObject(Int32(MODEL_GROUP_SKELETONBASE) + Int32(SkeletonType.wormhole.rawValue), 0)!.assumingMemoryBound(to: MOVertexArrayObject.self) // point to this object

    if mo.pointee.objectHeader.type == .group { // see if need to go into group
        SwFatal("ModifyWormholeTextures: object is group")
    }

    // ASSUME MO IS A VERTEX ARRAY OBJECT

    va = mo.pointer(to: \.objectData)! // point to vertex array data

    mat = vertexArrayMaterialsBase(va)[0]! // get pointer to material
    mat.pointee.objectData.flags |= UInt32(BG3D_MATERIALFLAG_MULTITEXTURE) // set flags for multi-texture

    mat.pointee.objectData.multiTextureCombine = UInt16(MULTI_TEXTURE_COMBINE_ADD) // set combining mode
}

// MARK: - Egg Wormhole

extension UnsafeMutablePointer where Pointee == TerrainItemEntryType {
    @discardableResult
    func addEggWormhole(x: Float, z: Float) -> UInt8 {
        // SEE IF NEED TO CREATE AN EXIT WORMHOLE INSTEAD

        if gOpenPlayerWormhole != 0 {
            if gExitWormhole == nil {
                makeExitWormhole(x, z)
            }
            return 0
        }

        // MAKE NEW SKELETON OBJECT

        var def = NewObjectDefinitionType()
        def.type = UInt8(SkeletonType.wormhole.rawValue)
        def.animNum = 0
        def.coord.x = x
        def.coord.y = pointee.terrainY + 1300.0
        def.coord.z = z
        def.flags = UInt32(STATUS_BIT_DOUBLESIDED | STATUS_BIT_UVTRANSFORM | STATUS_BIT_NOZWRITES | STATUS_BIT_GLOW)
        def.slot = Int16(SLOT_OF_DUMB)
        def.moveCall = cMoveEggWormhole
        def.drawCall = cDrawWormhole
        def.rot = Float(pointee.parm.0) * (SwPI2 / 8)
        def.scale = eggWormholeSize

        let newObj = MakeNewSkeletonObject(&def)!

        newObj.pointee.TerrainItemPtr = self // keep ptr to item list
        newObj.pointee.PlayerNum = pointee.parm.1 // remember this for capture the flag modes
        newObj.pointee.What = Int32(WhatType.eggWormhole.rawValue)

        newObj.pointee.Rot.x = 0.8
        UpdateObjectTransforms(newObj)

        return 1 // item was added
    }
}

private let cMoveEggWormhole: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }
    let fps = gFramesPerSecondFrac

    // SEE IF GONE

    if TrackTerrainItem(theNode) != 0 {
        DeleteObject(theNode)
        return
    }

    // DO TEXTURE ANIMATION

    theNode.pointee.TextureTransformU += fps * 0.5 // spin
    theNode.pointee.TextureTransformV -= fps * 0.3 // suck

    theNode.pointee.SpecialF.0 += fps * -0.1 // TextureTransformU2: spin
    theNode.pointee.SpecialF.1 -= fps * 0.4 // TextureTransformV2: suck

    // SEE IF NEED TO MAKE VANISH

    if gOpenPlayerWormhole != 0 {
        if theNode.pointee.Skeleton!.pointee.AnimNum != 1 { // see if need to change to vanish anim
            MorphToSkeletonAnim(theNode.pointee.Skeleton, 1, 2.0)
            PlayEffect3D(Int16(EFFECT_WORMHOLEVANISH), &theNode.pointee.Coord)
        }

        theNode.pointee.Rot.x += fps

        theNode.pointee.Scale.z -= fps * 6.0
        theNode.pointee.Scale.y = theNode.pointee.Scale.z
        theNode.pointee.Scale.x = theNode.pointee.Scale.z

        if theNode.pointee.Scale.x <= 0.0 {
            // SEE IF MAKE PLAYER'S EXIT WORMHOLE HERE

            if gExitWormhole == nil {
                makeExitWormhole(theNode.pointee.Coord.x, theNode.pointee.Coord.z)
            }

            DeleteObject(theNode)
            return
        }

        UpdateObjectTransforms(theNode)
    }

    // UPDATE EFFECT

    if theNode.pointee.EffectChannel == -1 {
        theNode.pointee.EffectChannel = PlayEffect_Parms3D(Int16(EFFECT_WORMHOLE), &theNode.pointee.Coord, UInt32(NORMAL_CHANNEL_RATE) * 3 / 2, 1.0)
    } else {
        gEngine.sound.channelInfo[Int(theNode.pointee.EffectChannel)].volumeAdjust = theNode.pointee.Scale.x / eggWormholeSize // set volume based on scale

        _ = Update3DSoundChannel(Int16(EFFECT_WORMHOLE), &theNode.pointee.EffectChannel, &theNode.pointee.Coord)
    }
}

func FindClosestEggWormholeInRange(_ playerNum: Int16, _ pt: UnsafeMutablePointer<OGLPoint3D>!) -> UnsafeMutablePointer<ObjNode>! {
    var best: UnsafeMutablePointer<ObjNode>?
    var minDist: Float = 1000000

    // FIND CLOSEST WORMHOLE

    for node in allObjectNodes {
        guard node.pointee.What == Int32(WhatType.eggWormhole.rawValue) else {
            continue
        }

        if gVSMode == .captureTheFlag, // only find wormhole valid for this player
           Int16(node.pointee.PlayerNum) == playerNum {
            continue
        }

        // POINT MUST BE IN FRONT OF WORMHOLE

        var mouthPt = OGLPoint3D()
        var mouthPt2 = OGLPoint3D()
        FindCoordOfJoint(node, 1, &mouthPt) // calc coord of mouth of wormhole
        FindCoordOfJoint(node, 0, &mouthPt2)

        var vraw = OGLVector3D() // calc aim vector of mouth
        vraw.x = mouthPt2.x - mouthPt.x
        vraw.y = mouthPt2.y - mouthPt.y
        vraw.z = mouthPt2.z - mouthPt.z
        let v = vraw.normalized()

        var v2raw = OGLVector3D() // calc vector from pt to mouth
        v2raw.x = mouthPt2.x - pt.pointee.x
        v2raw.y = mouthPt2.y - pt.pointee.y
        v2raw.z = mouthPt2.z - pt.pointee.z
        let v2 = v2raw.normalized()

        let dot = v.dot(v2) // calc angle between vectors to determine if in front
        if dot < 0.0 {
            // POINT MUST BE CLOSE ENOUGH

            let d = pt.pointee.distance(to: mouthPt2) // calc dist to mouth
            if d < minDist {
                minDist = d
                best = node
            }
        }
    }

    // IS IT IN RANGE?

    if minDist < minDistToGetEgg {
        return best
    }

    return nil
}

// MARK: - Entry Wormhole

// Create an entry wormhole at Player 1's position.
func MakeEntryWormhole(_ playerNum: Int16) -> UnsafeMutablePointer<ObjNode>! {
    let playerInfo = GetPlayerInfoEntry(Int32(playerNum))
    let x = playerInfo.pointee.coord.x
    let z = playerInfo.pointee.coord.z

    let player = playerInfo.pointee.objNode!

    // MAKE NEW OBJECT

    var def = NewObjectDefinitionType()
    def.group = UInt8(MODEL_GROUP_GLOBAL)
    def.type = UInt8(GLOBAL_ObjType_EntryWormhole)
    def.coord.x = x
    def.coord.y = GetTerrainY(x, z) + MAX_ALTITUDE_DIFF
    def.coord.z = z
    def.flags = UInt32(STATUS_BIT_DOUBLESIDED | STATUS_BIT_UVTRANSFORM | STATUS_BIT_NOZWRITES | STATUS_BIT_GLOW)
    def.slot = Int16(SLOT_OF_DUMB)
    def.moveCall = cMoveEntryWormhole
    def.drawCall = cDrawWormhole
    def.rot = player.pointee.Rot.y
    def.scale = playerWormholeSize

    let newObj = MakeNewDisplayGroupObject(&def)!

    newObj.pointee.Rot.x = Float.pi / 5
    UpdateObjectTransforms(newObj)

    newObj.pointee.Health = 3.0 // set life of wormhole before start to fade out

    newObj.pointee.PlayerNum = UInt8(playerNum)
    playerInfo.pointee.wormhole = newObj

    return newObj // item was added
}

// This is a bit of a hack.  Basically, we temporarily modify the TriMesh structure
// so that it appears to have all the data needed for drawing multi-textured.
private let cDrawWormhole: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }
    let va: UnsafeMutablePointer<MOVertexArrayData>

    if theNode.pointee.What == Int32(WhatType.eggWormhole.rawValue) { // gotta handle the two types differently
        let skeleton = theNode.pointee.Skeleton!
        let buffNum = Int(gGameViewInfoPtr!.pointee.frameCount & 1)

        va = deformedMeshesBase(skeleton) + (buffNum * Int(MAX_DECOMPOSED_TRIMESHES)) // point to triMesh
    } else {
        let mo = GetBG3DGroupObject(Int32(MODEL_GROUP_GLOBAL), Int32(GLOBAL_ObjType_EntryWormhole))!.assumingMemoryBound(to: MOVertexArrayObject.self)
        va = mo.pointer(to: \.objectData)! // point to vertex array data
    }

    // MAKE TEMPORARY MODIFICATIONS

    let materialsBase = vertexArrayMaterialsBase(va)
    let uvsBase = vertexArrayUVsBase(va)

    va.pointee.numMaterials = 2
    materialsBase[1] = materialsBase[0]
    uvsBase[1] = uvsBase[0]

    OGL_ActiveTextureUnit(UInt32(GL_TEXTURE1))
    gEngine.renderer.matrixMode(.texture) // set texture matrix
    gEngine.renderer.loadIdentity()
    gEngine.renderer.translate(theNode.pointee.SpecialF.0, theNode.pointee.SpecialF.1, 0)
    gEngine.renderer.matrixMode(.modelview)
    OGL_ActiveTextureUnit(UInt32(GL_TEXTURE0))

    // DRAW IT

    if theNode.pointee.What == Int32(WhatType.eggWormhole.rawValue) {
        DrawSkeleton(theNode)
    } else {
        UnsafeMutableRawPointer(theNode.pointee.BaseGroup)?.draw()
    }

    // RESTORE MODS

    va.pointee.numMaterials = 1
    materialsBase[1] = nil
    uvsBase[1] = nil

    OGL_ActiveTextureUnit(UInt32(GL_TEXTURE1))
    gEngine.renderer.matrixMode(.texture) // set texture matrix
    gEngine.renderer.loadIdentity()
    gEngine.renderer.matrixMode(.modelview)
    OGL_ActiveTextureUnit(UInt32(GL_TEXTURE0))
}

private let cMoveEntryWormhole: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }
    let fps = gFramesPerSecondFrac
    let oldH = theNode.pointee.Health

    theNode.pointee.Health -= fps
    if theNode.pointee.Health < 0.0 {
        if oldH >= 0.0 {
            PlayEffect_Parms3D(Int16(EFFECT_WORMHOLEVANISH), &theNode.pointee.Coord, UInt32(NORMAL_CHANNEL_RATE), 2.0)
            PlayRumbleEffect(Int16(EFFECT_WORMHOLEVANISH), Int32(theNode.pointee.PlayerNum))
        }

        theNode.pointee.Scale.z -= fps * 8.0
        theNode.pointee.Scale.y = theNode.pointee.Scale.z
        theNode.pointee.Scale.x = theNode.pointee.Scale.z
        if theNode.pointee.Scale.x <= 0.0 {
            GetPlayerInfoEntry(Int32(theNode.pointee.PlayerNum)).pointee.wormhole = nil
            DeleteObject(theNode)
            return
        }
    }

    theNode.pointee.TextureTransformU += fps * 0.5 // spin
    theNode.pointee.TextureTransformV += fps * 0.3 // spit

    theNode.pointee.SpecialF.0 += fps * -0.1 // TextureTransformU2: spin
    theNode.pointee.SpecialF.1 += fps * 0.4 // TextureTransformV2: spit

    UpdateObjectTransforms(theNode)

    // UPDATE EFFECT

    if theNode.pointee.EffectChannel == -1 {
        theNode.pointee.EffectChannel = PlayEffect_Parms3D(Int16(EFFECT_WORMHOLE), &theNode.pointee.Coord, UInt32(NORMAL_CHANNEL_RATE), 1.0)
    } else {
        _ = Update3DSoundChannel(Int16(EFFECT_WORMHOLE), &theNode.pointee.EffectChannel, &theNode.pointee.Coord)
    }
}

// MARK: - Exit Wormhole

private func makeExitWormhole(_ x: Float, _ z: Float) {
    // MAKE NEW OBJECT

    var def = NewObjectDefinitionType()
    def.group = UInt8(MODEL_GROUP_GLOBAL)
    def.type = UInt8(GLOBAL_ObjType_EntryWormhole)
    def.coord.x = x
    def.coord.y = GetTerrainY(x, z) + MAX_ALTITUDE_DIFF
    def.coord.z = z
    def.flags = UInt32(STATUS_BIT_DOUBLESIDED | STATUS_BIT_UVTRANSFORM | STATUS_BIT_NOZWRITES | STATUS_BIT_GLOW)
    def.slot = Int16(SLOT_OF_DUMB)
    def.moveCall = cMoveExitWormhole
    def.drawCall = cDrawWormhole
    def.rot = 0
    def.scale = 0.001 // start shrunken

    gExitWormhole = MakeNewDisplayGroupObject(&def)

    gExitWormhole!.pointee.Rot.x = Float.pi / 8
    UpdateObjectTransforms(gExitWormhole)

    PlayEffect_Parms3D(Int16(EFFECT_WORMHOLEAPPEAR), &gExitWormhole!.pointee.Coord, UInt32(NORMAL_CHANNEL_RATE), 2.0)
}

private let cMoveExitWormhole: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNodeOpt in
    guard let theNode = theNodeOpt else { return }
    let fps = gFramesPerSecondFrac

    // SCALE IT UP

    theNode.pointee.Scale.x += fps * 5.0
    var s = theNode.pointee.Scale.x
    if s > playerWormholeSize {
        s = playerWormholeSize
    }

    theNode.pointee.Scale.x = s
    theNode.pointee.Scale.y = s
    theNode.pointee.Scale.z = s

    // TEXTURE ANIMATION

    theNode.pointee.TextureTransformU -= fps * 0.5 // spin
    theNode.pointee.TextureTransformV -= fps * 0.3 // spit

    theNode.pointee.SpecialF.0 -= fps * -0.1 // TextureTransformU2: spin
    theNode.pointee.SpecialF.1 -= fps * 0.4 // TextureTransformV2: spit

    UpdateObjectTransforms(theNode)

    // UPDATE EFFECT

    if theNode.pointee.EffectChannel == -1 {
        theNode.pointee.EffectChannel = PlayEffect_Parms3D(Int16(EFFECT_WORMHOLE), &theNode.pointee.Coord, UInt32(NORMAL_CHANNEL_RATE), 1.4)
    } else {
        _ = Update3DSoundChannel(Int16(EFFECT_WORMHOLE), &theNode.pointee.EffectChannel, &theNode.pointee.Coord)
    }

    // SEE IF GRAB PLAYER

    if s == playerWormholeSize { // only grab when full size
        seeIfExitWormholeGrabPlayer(theNode)
    }
}

private func seeIfExitWormholeGrabPlayer(_ wormhole: UnsafeMutablePointer<ObjNode>) {
    let player = GetPlayerInfoEntry(0).pointee.objNode!
    let down = OGLVector3D(x: 0, y: -1, z: 0)

    // SEE IF PLAYER IS IN RANGE

    if player.pointee.Coord.distance(to: wormhole.pointee.Coord) > 1000.0 {
        return
    }

    // PLAYER MUST BE IN FRONT OF MOUTH

    let v = down.transformed(by: wormhole.pointee.BaseTransformMatrix) // calc aim vector of mouth

    var v2raw = OGLVector3D() // calc vector from player to mouth
    v2raw.x = wormhole.pointee.Coord.x - player.pointee.Coord.x
    v2raw.y = wormhole.pointee.Coord.y - player.pointee.Coord.y
    v2raw.z = wormhole.pointee.Coord.z - player.pointee.Coord.z
    let v2 = v2raw.normalized()

    let dot = v.dot(v2) // calc angle between vectors to determine if in front or back
    if dot > 0.0 {
        return
    }

    // PLAYER MUST BE AIMING AT MOUTH (disabled in the original C source)

    // TAKE CONTROL

    DropEgg_NoWormhole(Int16(player.pointee.PlayerNum)) // drop any egg
    JetpackOff(Int16(player.pointee.PlayerNum))

    MorphToSkeletonAnim(player.pointee.Skeleton, .enterWormhole, 2.0)

    player.pointee.MotionVector = v2

    gEngine.camera.inExitMode = 1
}
