// Contrails.swift - Port of Contrails.c to Swift

private let maxContrails = 15
private let maxRefPointsInContrail = 50
private let playerWingContrailAlpha: Float = 0.6

private struct ContrailType {
    var isUsed: UInt8 = 0

    var width: Float = 0
    var indexPtr: UnsafeMutablePointer<Int16>?

    var numPoints: Int16 = 0
    var nextPointIndex: Int16 = 0
    var refPoints: InlineArray<50, OGLPoint3D> = InlineArray(repeating: OGLPoint3D())
    var alphas: InlineArray<50, Float> = InlineArray(repeating: 0)
    var aimVectors: InlineArray<50, OGLVector3D> = InlineArray(repeating: OGLVector3D())

    var meshData: InlineArray<2, MOVertexArrayData> = InlineArray(repeating: MOVertexArrayData())
}

private var gContrails: InlineArray<15, ContrailType> = InlineArray(repeating: ContrailType())

@inline(__always) private func contrailSlotBase(_ n: UnsafeMutablePointer<ObjNode>) -> UnsafeMutablePointer<Int16> {
    UnsafeMutableRawPointer(n.pointer(to: \.ContrailSlot)!).assumingMemoryBound(to: Int16.self)
}

@inline(__always) private func previousWingContrailPtBase(_ pi: UnsafeMutablePointer<PlayerInfoType>) -> UnsafeMutablePointer<OGLPoint3D> {
    UnsafeMutableRawPointer(pi.pointer(to: \.previousWingContrailPt)!).assumingMemoryBound(to: OGLPoint3D.self)
}

@inline(__always) private func vertexIndicesBase(_ triangle: UnsafeMutablePointer<MOTriangleIndecies>) -> UnsafeMutablePointer<GLuint> {
    UnsafeMutableRawPointer(triangle.pointer(to: \.vertexIndices)!).assumingMemoryBound(to: GLuint.self)
}

func InitContrails() {
    // INIT THE CONTRAIL LISTS

    for i in 0..<maxContrails {
        gContrails[i].isUsed = 0 // mark as free

        // INIT THE DOUBLE-BUFFERED MESH DATA

        for b in 0..<2 {
            let varType = UInt8(Int32(VertexArrayRangeType.contrails1.rawValue) + Int32(b))
            gContrails[i].meshData[b].VARtype = Int16(varType)
            gContrails[i].meshData[b].numMaterials = 0
            gContrails[i].meshData[b].numPoints = 0
            gContrails[i].meshData[b].numTriangles = 0
            gContrails[i].meshData[b].normals = nil
            gContrails[i].meshData[b].colorsFloat = nil
            gContrails[i].meshData[b].uvs.0 = nil
            gContrails[i].meshData[b].uvs.1 = nil

            gContrails[i].meshData[b].points = OGL_AllocVertexArrayMemory(Int(MemoryLayout<OGLPoint3D>.size * maxRefPointsInContrail * 2), varType)!.assumingMemoryBound(to: OGLPoint3D.self)
            gContrails[i].meshData[b].colorsFloat = OGL_AllocVertexArrayMemory(Int(MemoryLayout<OGLColorRGBA>.size * maxRefPointsInContrail * 2), varType)!.assumingMemoryBound(to: OGLColorRGBA.self)
            gContrails[i].meshData[b].triangles = OGL_AllocVertexArrayMemory(Int(MemoryLayout<MOTriangleIndecies>.size * maxRefPointsInContrail * 2 - 2), varType)!.assumingMemoryBound(to: MOTriangleIndecies.self)
        }
    }

    // CREATE OBJECT FOR DRAWING

    var def = NewObjectDefinitionType()
    def.genre = UInt8(CUSTOM_GENRE)
    def.slot = Int16(CONTRAIL_SLOT)
    def.flags = UInt32(STATUS_BIT_NOLIGHTING | STATUS_BIT_DOUBLESIDED | STATUS_BIT_DONTCULL | STATUS_BIT_NOZWRITES | STATUS_BIT_GLOW)
    def.scale = 1
    def.moveCall = cMoveContrails
    def.drawCall = cDrawContrails

    let obj = MakeNewObject(&def)!
    obj.pointee.VertexArrayMode = UInt8(VertexArrayRangeType.contrails1.rawValue)
}

func DisposeContrails() {
    for i in 0..<maxContrails {
        for b in 0..<2 {
            let mesh = gContrails[i].meshData[b]

            OGL_FreeVertexArrayMemory(mesh.points, UInt8(mesh.VARtype))
            OGL_FreeVertexArrayMemory(mesh.colorsFloat, UInt8(mesh.VARtype))
            OGL_FreeVertexArrayMemory(mesh.triangles, UInt8(mesh.VARtype))

            gContrails[i].meshData[b].points = nil
            gContrails[i].meshData[b].colorsFloat = nil
            gContrails[i].meshData[b].triangles = nil
        }
    }
}

func MakeNewContrail(_ width: Float, _ contrailNum: UnsafeMutablePointer<Int16>!) {
    // SCAN FOR A FREE CONTRAIL

    var foundIndex = -1
    for i in 0..<maxContrails {
        if gContrails[i].isUsed == 0 {
            foundIndex = i
            break
        }
    }

    if foundIndex < 0 {
        contrailNum.pointee = -1
        return // no free contrails, so bail
    }

    // INIT THIS CONTRAIL SLOT

    let i = foundIndex
    gContrails[i].isUsed = 1 // make this slot as used
    gContrails[i].numPoints = 0
    gContrails[i].nextPointIndex = 0
    gContrails[i].width = width
    gContrails[i].indexPtr = contrailNum

    for j in 0..<maxRefPointsInContrail {
        gContrails[i].alphas[j] = 0 // clear all alpha values
    }

    contrailNum.pointee = Int16(i)
}

func AddPointToContrail(_ contrailNum: Int16, _ wherePtr: UnsafeMutablePointer<OGLPoint3D>!, _ aim: UnsafeMutablePointer<OGLVector3D>!, _ alpha: Float) {
    let contrailNum = Int(contrailNum)
    if gContrails[contrailNum].isUsed == 0 {
        SwFatal("AddPointToContrail:  bad contrailNum")
    }

    var p = Int(gContrails[contrailNum].nextPointIndex) // get index into ref point list

    gContrails[contrailNum].alphas[p] = alpha // set initial alpha for this ref pt.
    gContrails[contrailNum].refPoints[p] = wherePtr.pointee // set coord of ref pt.
    gContrails[contrailNum].aimVectors[p] = aim.pointee // remember the aim vector at this pt

    // INC REF PT INDEX

    p += 1
    if p >= maxRefPointsInContrail { // see if wrap around
        p = 0
    }

    gContrails[contrailNum].nextPointIndex = Int16(p) // set where next pt will go
}

func ModifyContrailPreviousAddition(_ contrailNum: Int16, _ wherePtr: UnsafeMutablePointer<OGLPoint3D>!) {
    let contrailNum = Int(contrailNum)
    if contrailNum < 0 {
        SwFatal("ModifyContrailPreviousAddition:  bad contrailNum")
    }
    if gContrails[contrailNum].isUsed == 0 {
        SwFatal("ModifyContrailPreviousAddition:  bad contrailNum")
    }

    var p = Int(gContrails[contrailNum].nextPointIndex) - 1 // get index into ref point list, then back 1
    if p < 0 {
        p = maxRefPointsInContrail - 1
    }

    gContrails[contrailNum].refPoints[p] = wherePtr.pointee // set coord of ref pt.
}

func DisconnectContrail(_ contrailNum: Int16) {
    if contrailNum != -1 {
        gContrails[Int(contrailNum)].indexPtr = nil
    }
}

private let cMoveContrails: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNode in
    guard let theNode else { return }

    let fps = gFramesPerSecondFrac
    let buffNum = Int(gGameViewInfoPtr!.pointee.frameCount & 1) // which VAR buffer to use?

    theNode.pointee.VertexArrayMode = UInt8(Int32(VertexArrayRangeType.contrails1.rawValue) + Int32(buffNum)) // update the VAR range info

    for i in 0..<maxContrails {
        if gContrails[i].isUsed == 0 {
            continue
        }

        // GET INDEX TO MOST RECENTLY ADDED REF PT

        var startRefP = Int(gContrails[i].nextPointIndex) - 1
        if startRefP < 0 {
            startRefP = maxRefPointsInContrail - 1
        }

        // DEC THE ALPHA OF THE REF PT & COUNT # PTS

        var numActivePts = 0 // init ref pt counter
        var refP = startRefP

        while gContrails[i].alphas[refP] > 0.0 {
            gContrails[i].alphas[refP] -= fps * 0.5 // dec this alpha
            if gContrails[i].alphas[refP] <= 0.0 { // if the alpha has gone to zero then this is the tail end of the contrail
                break
            }

            numActivePts += 1

            refP -= 1 // dec ref pt index
            if refP < 0 { // see if wrap around
                refP = maxRefPointsInContrail - 1
            }
            if refP == startRefP { // if wrapped back to start then exit loop
                break
            }
        }

        // IF NO ACTIVE PTS THEN DISABLE THE CONTRAIL

        if numActivePts == 0 {
            gContrails[i].isUsed = 0 // not used anymore
            if let indexPtr = gContrails[i].indexPtr {
                indexPtr.pointee = -1 // pass -1 back to the index
            }

            continue
        }

        // BUILD GEOMETRY

        if numActivePts < 2 { // it takes at least 2 ref pts to build any geometry
            gContrails[i].meshData[buffNum].numPoints = 0
            gContrails[i].meshData[buffNum].numTriangles = 0
            continue
        }

        // SET MESH BASIC INFO

        gContrails[i].meshData[buffNum].numPoints = Int32(numActivePts * 2) // set # pts in geometry
        gContrails[i].meshData[buffNum].numTriangles = Int32(numActivePts * 2 - 2) // set # triangles in geometry

        let points = gContrails[i].meshData[buffNum].points! // get ptrs to vertex arrays
        let triangles = gContrails[i].meshData[buffNum].triangles!
        let colors = gContrails[i].meshData[buffNum].colorsFloat!

        refP = startRefP

        var alphaFade: Float = 0.0
        var vertexIndex = 0
        var t = 0
        var remainingActivePts = numActivePts

        while remainingActivePts > 0 { // loop thru all active ref pts to build geometry from
            let refX = gContrails[i].refPoints[refP].x // get ref pt coords
            let refY = gContrails[i].refPoints[refP].y
            let refZ = gContrails[i].refPoints[refP].z

            let v = gContrails[i].aimVectors[refP] // get ref pt's aim vector

            // CALC CROSS PRODUCT TO GIVE US THE SIDE VECTOR (AND MULTIPLY BY WIDTH)

            var cross = OGLVector3D()
            cross.x = -v.z * gContrails[i].width
            cross.z = v.x * gContrails[i].width

            // SET THE COORDS OF THE LEFT & RIGHT VERTICES

            points[vertexIndex].x = refX + cross.x // left vertex coord
            points[vertexIndex].z = refZ + cross.z
            points[vertexIndex].y = refY

            points[vertexIndex + 1].x = refX - cross.x // right vertex coord
            points[vertexIndex + 1].z = refZ - cross.z
            points[vertexIndex + 1].y = refY

            // SET VERTEX COLORS

            // SET ALPHA TO TRANSPARENT ON END TIPS

            if vertexIndex == 0 || remainingActivePts == 1 {
                colors[vertexIndex].a = 0
                colors[vertexIndex + 1].a = 0
            }

            // OTHERWISE USE CALCULATION

            else {
                colors[vertexIndex].a = gContrails[i].alphas[refP] * alphaFade
                colors[vertexIndex + 1].a = gContrails[i].alphas[refP] * alphaFade

                alphaFade += 0.05
                if alphaFade > 1.0 {
                    alphaFade = 1.0
                }
            }

            // SET CONTRAIL COLOR

            colors[vertexIndex].r = 1.0
            colors[vertexIndex].g = 1.0
            colors[vertexIndex].b = 1.0
            colors[vertexIndex + 1].r = 1.0
            colors[vertexIndex + 1].g = 1.0
            colors[vertexIndex + 1].b = 1.0

            // BUILD TRIANGLES

            if vertexIndex > 0 {
                let tri0 = vertexIndicesBase(triangles + t)
                tri0[0] = GLuint(vertexIndex - 2) // back left vert
                tri0[1] = GLuint(vertexIndex - 1) // back right vert
                tri0[2] = GLuint(vertexIndex) // fore left vert
                t += 1

                let tri1 = vertexIndicesBase(triangles + t)
                tri1[0] = GLuint(vertexIndex) // fore left vert
                tri1[1] = GLuint(vertexIndex - 1) // back right vert
                tri1[2] = GLuint(vertexIndex + 1) // fore right vert
                t += 1
            }

            vertexIndex += 2
            refP -= 1
            if refP < 0 {
                refP = maxRefPointsInContrail - 1
            }
            remainingActivePts -= 1
        }

        OGL_SetVertexArrayRangeDirty(Int16(theNode.pointee.VertexArrayMode)) // we modified some geometry so we'll need an update
    }
}

private let cDrawContrails: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { _ in
    let buffNum = Int(gGameViewInfoPtr!.pointee.frameCount & 1) // which VAR buffer to use?

    OGL_EnableBlend()
    OGL_DisableTexture2D()

    for i in 0..<maxContrails {
        if gContrails[i].isUsed != 0, gContrails[i].meshData[buffNum].numTriangles > 0 {
            MO_DrawGeometry_VertexArray(&gContrails[i].meshData[buffNum])
        }
    }
}

func UpdatePlayerContrails(_ player: UnsafeMutablePointer<ObjNode>!) {
    var pt = OGLPoint3D()
    var aim = OGLVector3D()
    let tipOff: InlineArray<2, OGLPoint3D> = [
        OGLPoint3D(x: 35, y: 0, z: 3),
        OGLPoint3D(x: -35, y: 0, z: 3),
    ]

    let p = Int(player.pointee.PlayerNum)
    let playerInfo = GetPlayerInfoPtr(Int32(p))
    let contrailSlots = contrailSlotBase(player)
    let previousWingContrailPt = previousWingContrailPtBase(playerInfo)

    // SEE IF DO CONTRAIL ON WINGS

    switch Int32(player.pointee.Skeleton!.pointee.AnimNum) {
    case Int32(PlayerAnim.flap.rawValue),
         Int32(PlayerAnim.deathDive.rawValue),
         Int32(PlayerAnim.dustDevil.rawValue),
         Int32(PlayerAnim.readyToGrab.rawValue):
        disconnectPlayerContrails(player, contrailSlots)
        return

    default:
        break
    }

    if player.pointee.Rot.z > Float.pi / 10, playerInfo.pointee.analogControlX < 0.0 { // hard right bank
        // do it
    } else if player.pointee.Rot.z < -Float.pi / 10, playerInfo.pointee.analogControlX > 0.0 { // hard left bank
        // do it
    } else if player.pointee.Rot.x > Float.pi / 8, playerInfo.pointee.analogControlZ > 0.0 { // hard bow
        // do it
    } else if player.pointee.Rot.x < -Float.pi / 8, playerInfo.pointee.analogControlZ < 0.0 { // hard lift
        // do it
    } else {
        disconnectPlayerContrails(player, contrailSlots)
        return
    }

    // UPDATE CONTRAILS ON BOTH WING TIPS

    FastNormalizeVector(player.pointee.Delta.x, player.pointee.Delta.y, player.pointee.Delta.z, &aim) // calc aim vector

    for i in 0..<2 {
        // CALC WING TIP COORD

        var tip = tipOff[i]
        if i == 0 {
            FindCoordOnJoint(player, Int(PlayerJoint.rightWingtip.rawValue), &tip, &pt)
        } else {
            FindCoordOnJoint(player, Int(PlayerJoint.leftWingtip.rawValue), &tip, &pt)
        }

        // START NEW CONTRAIL IF NEEDED

        if contrailSlots[i] == -1 {
            MakeNewContrail(1.1, contrailSlots + i)
        }

        // CHECK IF WE'VE GONE FAR ENOUGH TO ADD A NEW REF PT TO EXISTING CONTRAIL

        else {
            let dist = pt.distance(to: (previousWingContrailPt + i).pointee) // calc dist from prev contrail pt to this
            if dist < 15.0 {
                ModifyContrailPreviousAddition(contrailSlots[i], &pt) // instead of adding a new ref pt, just modify the last one so we don't get the popping effect
                continue
            }
        }

        // ADD NEW POINT TO CONTRAIL

        if contrailSlots[i] != -1 {
            AddPointToContrail(contrailSlots[i], &pt, &aim, playerWingContrailAlpha)
            previousWingContrailPt[i] = pt
        }
    }
}

private func disconnectPlayerContrails(_ player: UnsafeMutablePointer<ObjNode>, _ contrailSlots: UnsafeMutablePointer<Int16>) {
    DisconnectContrail(contrailSlots[0]) // disconnect the contrail from ContrailSlot[n]
    DisconnectContrail(contrailSlots[1])

    contrailSlots[0] = -1 // terminate any existing contrails and then bail
    contrailSlots[1] = -1
}
