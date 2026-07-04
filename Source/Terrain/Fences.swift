// Fences.swift - Port of Fences.c to Swift
//
// gNumFences and gFenceList stay defined in the stubbed Fences.c because
// Pick.swift and File.swift (already ported) read/write them directly via
// `extern`. gFenceTriMeshData also stays because PickInternal.h's
// GetFenceTriMeshDataEntry shim references it directly. gNumFencesDrawn
// stays too since it's `extern`'d in game.h (conservatively, even though
// nothing currently reads it). gFenceObj, gFenceMaterials, and the double-
// buffered vertex-array storage (gFenceVertexArrays in the original C)
// have no `extern` declaration anywhere and are only ever touched from
// this file, so they move into private Swift storage.
//
// The double-buffered vertex arrays need a stable, never-moving address
// (gFenceTriMeshData's points/triangles/uvs/colorsFloat fields hold raw
// pointers into them across frames), so - like the master supertile
// arrays in Terrain.swift - they're heap-allocated once into flat
// UnsafeMutablePointer buffers rather than represented as Swift Arrays.
//
// VERTEXARRAYRANGES is hardcoded off in game.h, so the VAR-assignment/
// release calls in PrimeFences/DisposeFences are dead code and dropped.
// SeeIfLineSegmentHitsFence was already entirely #if 0'd out in the
// original (and its declaration commented out in fences.h too), so it's
// skipped.

private let maxFences = 90
private let maxNubsInFence = 80
private let maxNubsInFenceX2 = maxNubsInFence * 2

private let fenceSinkFactor: Float = 30.0 // How much to physically sink fences into terrain (in world units)
private let fenceStretchSinkFactor: Float = 1.0 / 8.0 // Extend fence quads downwards to avoid gaps (fraction of base fence height)

// gFenceTexture[type] = (spriteGroup, spriteNum)
private let gFenceTexture: [(Int32, Int32)] = [
    (Int32(SPRITE_GROUP_LEVELSPECIFIC), Int32(LEVEL1_SObjType_Fence_PineTree)), // FENCE_TYPE_PINETREES
    (Int32(SPRITE_GROUP_LEVELSPECIFIC), Int32(LEVEL1_SObjType_Fence_BlockEnemy)), // FENCE_TYPE_INVISIBLEBLOCKENEMY
]

private let gFenceHeight: [Float] = [
    Float(MAX_ALTITUDE_DIFF) + 100.0, // FENCE_TYPE_PINETREES
    300, // FENCE_TYPE_INVISIBLEBLOCKENEMY
]

private let gFenceSink: [Float] = [
    fenceSinkFactor, // FENCE_TYPE_PINETREES
    fenceSinkFactor, // FENCE_TYPE_INVISIBLEBLOCKENEMY
]

private let gFenceIsLit: [Bool] = [
    true, // FENCE_TYPE_PINETREES
    false, // FENCE_TYPE_INVISIBLEBLOCKENEMY
]

private var gFenceMaterials: [UnsafeMutablePointer<MOMaterialObject>?] = Array(repeating: nil, count: maxFences) // illegal refs to material for each fence in terrain

// Flat, stable-address, double-buffered vertex array storage:
// layout is [buffer(2)][fence(maxFences)][nub*2(maxNubsInFenceX2)].
private let gFenceTrianglesStorage = UnsafeMutablePointer<MOTriangleIndecies>.allocate(capacity: 2 * maxFences * maxNubsInFenceX2)
private let gFencePointsStorage = UnsafeMutablePointer<OGLPoint3D>.allocate(capacity: 2 * maxFences * maxNubsInFenceX2)
private let gFenceUVsStorage = UnsafeMutablePointer<OGLTextureCoord>.allocate(capacity: 2 * maxFences * maxNubsInFenceX2)
private let gFenceColorsStorage = UnsafeMutablePointer<OGLColorRGBA>.allocate(capacity: 2 * maxFences * maxNubsInFenceX2)

@inline(__always) private func fenceTrianglesBase(_ b: Int, _ f: Int) -> UnsafeMutablePointer<MOTriangleIndecies> {
    gFenceTrianglesStorage + (b * maxFences + f) * maxNubsInFenceX2
}
@inline(__always) private func fencePointsBase(_ b: Int, _ f: Int) -> UnsafeMutablePointer<OGLPoint3D> {
    gFencePointsStorage + (b * maxFences + f) * maxNubsInFenceX2
}
@inline(__always) private func fenceUVsBase(_ b: Int, _ f: Int) -> UnsafeMutablePointer<OGLTextureCoord> {
    gFenceUVsStorage + (b * maxFences + f) * maxNubsInFenceX2
}
@inline(__always) private func fenceColorsBase(_ b: Int, _ f: Int) -> UnsafeMutablePointer<OGLColorRGBA> {
    gFenceColorsStorage + (b * maxFences + f) * maxNubsInFenceX2
}

private var gFenceObj: UnsafeMutablePointer<ObjNode>?

// MARK: - Prime fences

// Called during terrain prime function to initialize
@c @implementation
public func PrimeFences() {
    if gNumFences > Int32(maxFences) {
        SwFatal("PrimeFences: gNumFences > MAX_FENCES")
    }

    // ADJUST TO GAME COORDINATES

    for f in 0..<Int(gNumFences) {
        let fence = gFenceList + f // point to this fence
        let nubs = fence.pointee.nubList! // point to nub list
        let numNubs = Int(fence.pointee.numNubs) // get # nubs in fence
        let type = Int(fence.pointee.type) // get fence type

        let (group, sprite) = gFenceTexture[type] // get sprite info

        if sprite > GetNumSpritesInGroup(group) {
            SwFatal("PrimeFences: illegal fence sprite")
        }

        if numNubs == 1 {
            SwFatal("PrimeFences: numNubs == 1")
        }

        if numNubs > maxNubsInFence {
            SwFatal("PrimeFences: numNubs > MAX_NUBS_IN_FENCE")
        }

        let sink = gFenceSink[type] // get fence sink factor

        for i in 0..<numNubs { // adjust nubs
            nubs[i].x *= gMapToUnitValue
            nubs[i].z *= gMapToUnitValue
            nubs[i].y = GetTerrainY(nubs[i].x, nubs[i].z) - sink // calc Y
        }

        // CALCULATE VECTOR FOR EACH SECTION

        let sectionVectors = AllocPtrClear(MemoryLayout<OGLVector2D>.size * (numNubs - 1))?.assumingMemoryBound(to: OGLVector2D.self) // alloc array to hold vectors
        guard let sectionVectors else {
            SwFatal("PrimeFences: AllocPtr failed!")
            return
        }
        fence.pointee.sectionVectors = sectionVectors

        for i in 0..<(numNubs - 1) {
            sectionVectors[i].x = nubs[i + 1].x - nubs[i].x
            sectionVectors[i].y = nubs[i + 1].z - nubs[i].z

            OGLVector2D_Normalize(&sectionVectors[i], &sectionVectors[i])
        }

        // CALCULATE NORMALS FOR EACH SECTION

        let sectionNormals = AllocPtrClear(MemoryLayout<OGLVector2D>.size * (numNubs - 1))?.assumingMemoryBound(to: OGLVector2D.self) // alloc array to hold vectors
        guard let sectionNormals else {
            SwFatal("PrimeFences: AllocPtr failed!")
            return
        }
        fence.pointee.sectionNormals = sectionNormals

        for i in 0..<(numNubs - 1) {
            var v = OGLVector3D()

            v.x = sectionVectors[i].x // get section vector (as calculated above)
            v.z = sectionVectors[i].y

            sectionNormals[i].x = -v.z // reduced cross product to get perpendicular normal
            sectionNormals[i].y = v.x
            OGLVector2D_Normalize(&sectionNormals[i], &sectionNormals[i])
        }
    }

    // MAKE FENCE GEOMETRY

    makeFenceGeometry()

    // CREATE DUMMY CUSTOM OBJECT TO CAUSE FENCE DRAWING AT THE DESIRED TIME
    //
    // The fences need to be drawn after the Cyc object, but before any sprite or font objects.

    var def = NewObjectDefinitionType()
    def.genre = UInt8(CUSTOM_GENRE)
    def.slot = Int16(FENCE_SLOT)
    def.moveCall = nil
    def.drawCall = cDrawFences
    def.flags = UInt32(STATUS_BIT_DOUBLESIDED | STATUS_BIT_NOLIGHTING | STATUS_BIT_DONTCULL | STATUS_BIT_CLIPALPHA6)
    def.scale = 1

    let fenceObj = MakeNewObject(&def)!
    gFenceObj = fenceObj
    fenceObj.pointee.VertexArrayMode = UInt8(VERTEX_ARRAY_RANGE_TYPE_USER_FENCES)

    // (VERTEXARRAYRANGES is hardcoded off, so the "assign memory to vertex
    // array range" block here is dead code and dropped.)
}

// MARK: - Make fence geometry

private func makeFenceGeometry() {
    for f in 0..<Int(gNumFences) {
        // GET FENCE INFO

        let fence = gFenceList + f // point to this fence
        let nubs = fence.pointee.nubList! // point to nub list
        let numNubs = Int(fence.pointee.numNubs) // get # nubs in fence
        let type = Int(fence.pointee.type) // get fence type
        let height = gFenceHeight[type] // get fence height

        let (group, sprite) = gFenceTexture[type] // get sprite info

        var aspectRatio: Float
        if group == SPRITE_GROUP_NULL {
            aspectRatio = 1
            gFenceMaterials[f] = nil
        } else {
            aspectRatio = GetSpriteGroupList(group)![Int(sprite)].aspectRatio // get aspect ratio
            gFenceMaterials[f] = GetSpriteGroupList(group)![Int(sprite)].materialObject?.assumingMemoryBound(to: MOMaterialObject.self) // keep illegal ref to the material
        }

        let textureUOff = 1.0 / height * aspectRatio // calc UV offset

        // SET VERTEX ARRAY HEADER

        var minX: Float = -1_000_000, minY: Float = -1_000_000, minZ: Float = -1_000_000 // build new bboxes while we do this
        var maxX: Float = 1_000_000, maxY: Float = 1_000_000, maxZ: Float = 1_000_000

        for b in 0..<2 { // make geometry for each double-buffer
            let triMeshData = GetFenceTriMeshDataEntry(Int32(f), Int32(b))!

            triMeshData.pointee.VARtype = Int16(VERTEX_ARRAY_RANGE_TYPE_USER_FENCES) + Int16(b)

            triMeshData.pointee.numMaterials = -1 // we submit these manually
            triMeshData.pointee.materials.0 = nil
            triMeshData.pointee.points = fencePointsBase(b, f)
            triMeshData.pointee.triangles = fenceTrianglesBase(b, f)
            triMeshData.pointee.uvs.0 = fenceUVsBase(b, f)
            triMeshData.pointee.normals = nil
            triMeshData.pointee.colorsFloat = fenceColorsBase(b, f)
            triMeshData.pointee.numPoints = Int32(numNubs * 2) // 2 vertices per nub
            triMeshData.pointee.numTriangles = Int32((numNubs - 1) * 2) // 2 faces per nub (minus 1st)

            let triangles = fenceTrianglesBase(b, f)
            let points = fencePointsBase(b, f)
            let uvs = fenceUVsBase(b, f)
            let colors = fenceColorsBase(b, f)

            // BUILD TRIANGLE INFO

            var j = 0
            for _ in 0..<maxNubsInFence {
                triangles[j].vertexIndices.0 = UInt32(1 + j)
                triangles[j].vertexIndices.1 = UInt32(0 + j)
                triangles[j].vertexIndices.2 = UInt32(3 + j)

                triangles[j + 1].vertexIndices.0 = UInt32(3 + j)
                triangles[j + 1].vertexIndices.1 = UInt32(0 + j)
                triangles[j + 1].vertexIndices.2 = UInt32(2 + j)

                j += 2
            }

            // INIT VERTEX COLORS

            for i in 0..<maxNubsInFenceX2 {
                colors[i] = OGLColorRGBA(r: 1, g: 1, b: 1, a: 1)
            }

            // BUILD POINTS, UV's

            maxX = -1_000_000; maxY = -1_000_000; maxZ = -1_000_000 // build new bboxes while we do this
            minX = -maxX; minY = -maxY; minZ = -maxZ

            var u: Float = 0
            j = 0
            for i in 0..<numNubs {
                // GET COORDS

                let x = nubs[i].x
                let z = nubs[i].z
                let y = nubs[i].y - (height * fenceStretchSinkFactor)
                let y2 = y + height * (1 + fenceStretchSinkFactor)

                // CHECK BBOX

                if x < minX { minX = x } // find min/max bounds for bbox
                if x > maxX { maxX = x }
                if z < minZ { minZ = z }
                if z > maxZ { maxZ = z }
                if y < minY { minY = y }
                if y2 > maxY { maxY = y2 }

                // SET COORDS

                points[j].x = x
                points[j].y = y
                points[j].z = z

                points[j + 1].x = x
                points[j + 1].y = y2
                points[j + 1].z = z

                // CALC UV COORDS

                if i > 0 {
                    u += OGLPoint3D_Distance(&points[j], &points[j - 2]) * textureUOff
                }

                uvs[j].v = (1 + fenceStretchSinkFactor) // bottom
                uvs[j + 1].v = 0 // top
                uvs[j].u = u
                uvs[j + 1].u = u

                j += 2
            }
        }

        // SET CALCULATED BBOX

        fence.pointee.bBox.min.x = minX
        fence.pointee.bBox.max.x = maxX
        fence.pointee.bBox.min.y = minY
        fence.pointee.bBox.max.y = maxY
        fence.pointee.bBox.min.z = minZ
        fence.pointee.bBox.max.z = maxZ
        fence.pointee.bBox.isEmpty = 0
    }
}

// MARK: - Dispose fences

@c @implementation
public func DisposeFences() {
    if gFenceList == nil {
        return
    }

    // (VERTEXARRAYRANGES is hardcoded off, so the VAR-release calls here
    // are dead code and dropped.)

    for f in 0..<Int(gNumFences) {
        if gFenceList[f].sectionVectors != nil {
            SafeDisposePtr(gFenceList[f].sectionVectors) // nuke section vectors
        }
        gFenceList[f].sectionVectors = nil

        if gFenceList[f].sectionNormals != nil {
            SafeDisposePtr(gFenceList[f].sectionNormals) // nuke normal vectors
        }
        gFenceList[f].sectionNormals = nil

        if gFenceList[f].nubList != nil {
            SafeDisposePtr(gFenceList[f].nubList)
        }
        gFenceList[f].nubList = nil
    }

    SafeDisposePtr(gFenceList)
    gFenceList = nil
    gNumFences = 0
}

// MARK: -

// MARK: - Update fences

@c @implementation
public func UpdateFences() {
    let autoFadeStart = gAutoFadeStartDist
    let autoFadeEndDist = gAutoFadeEndDist
    let autoFadeRangeFrac = gAutoFadeRange_Frac

    // UPDATE VAR TYPE FOR THE CURRENT FRAME'S DOUBLE-BUFFER

    let buffNum = Int(gGameViewInfoPtr!.pointee.frameCount & 1) // which VAR buffer to use?
    gFenceObj!.pointee.VertexArrayMode = UInt8(VERTEX_ARRAY_RANGE_TYPE_USER_FENCES) + UInt8(buffNum)

    // UPDATE THE AUTO-FADE FOR EACH FENCE
    //
    // NOTE:  we cannot do this in split-screen mode while using VAR because
    // 		the fades are different for each pane which means we'd have to wait
    //		for P1's drawing to complete before modifying P2's fence.

    if (gAutoFadeStatusBits != 0) && (gNumPlayers == 1) {
        let camX = gGameViewInfoPtr!.pointee.cameraPlacement.0.cameraLocation.x // get camera coords
        let camZ = gGameViewInfoPtr!.pointee.cameraPlacement.0.cameraLocation.z

        for f in 0..<Int(gNumFences) {
            let fence = gFenceList + f // point to this fence
            let nubs = fence.pointee.nubList! // point to nub list
            let numNubs = Int(fence.pointee.numNubs) // get # nubs in fence

            if fence.pointee.type == UInt16(FENCE_TYPE_INVISIBLEBLOCKENEMY) // don't bother with invisible fences
                && gDebugMode != 2 { // unless we're in debug mode
                continue
            }

            let colors = fenceColorsBase(buffNum, f)

            var j = 0
            for i in 0..<numNubs {
                // CALC & SET TRANSPARENCY

                var alpha: Float
                let dist0 = CalcQuickDistance(camX, camZ, nubs[i].x, nubs[i].z) // see if in fade zone
                if dist0 < autoFadeStart {
                    alpha = 1.0
                } else if dist0 >= autoFadeEndDist {
                    alpha = 0.0
                } else {
                    var dist = dist0 - autoFadeStart // calc xparency %
                    dist *= autoFadeRangeFrac
                    if dist < 0.0 {
                        alpha = 0
                    } else {
                        alpha = 1.0 - dist
                    }
                }

                colors[j].a = alpha
                colors[j + 1].a = alpha

                j += 2
            }

            OGL_SetVertexArrayRangeDirty(Int16(gFenceObj!.pointee.VertexArrayMode)) // we've updated the VAR
        }
    }
}

// MARK: - Draw fences

private let cDrawFences: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { _ in
    let buffNum = Int(gGameViewInfoPtr!.pointee.frameCount & 1) // which VAR buffer to use?

    // SET GLOBAL MATERIAL FLAGS

    gGlobalMaterialFlags = UInt32(BG3D_MATERIALFLAG_CLAMP_V) | UInt32(BG3D_MATERIALFLAG_ALWAYSBLEND)

    // DRAW EACH FENCE

    var numFencesDrawn: Int16 = 0

    for f in 0..<Int(gNumFences) {
        let type = Int(gFenceList[f].type) // get type

        if type == Int(FENCE_TYPE_INVISIBLEBLOCKENEMY) // don't bother with invisible fences
            && gDebugMode != 2 { // unless we're in debug mode
            continue
        }

        // DO BBOX CULLING

        if OGL_IsBBoxVisible(&gFenceList[f].bBox, nil) != 0 {
            // CHECK LIGHTING

            if gFenceIsLit[type] {
                OGL_EnableLighting()
            } else {
                OGL_DisableLighting()
            }

            // SUBMIT IT

            MO_DrawMaterial(gFenceMaterials[f])
            MO_DrawGeometry_VertexArray(GetFenceTriMeshDataEntry(Int32(f), Int32(buffNum)))

            numFencesDrawn += 1

            // (the gDebugMode==2 DrawFenceNormals call was already commented
            // out in the original, and DrawFenceNormals itself was #if 0'd.)
        }
    }

    gGlobalMaterialFlags = 0
}

// MARK: -

// MARK: - Do fence collision

// returns True if hit a fence
@c @implementation
public func DoFenceCollision(_ theNode: UnsafeMutablePointer<ObjNode>!) -> UInt8 {
    // SEE IF WE HAVE AN ENEMY

    let isEnemy = (theNode.pointee.CType & UInt32(CTYPE_ENEMY)) != 0

    // CALC MY MOTION LINE SEGMENT

    let oldX = Double(theNode.pointee.OldCoord.x) // from old coord
    let oldZ = Double(theNode.pointee.OldCoord.z)
    var newX = Double(gCoord.x) // to new coord
    var newZ = Double(gCoord.z)
    let radius = Double(theNode.pointee.BoundingSphereRadius)

    var hit = false

    // SCAN THRU ALL FENCES FOR A COLLISION

    fenceLoop: for f in 0..<Int(gNumFences) {
        let r2 = Float(radius) + 20.0 // tweak a little to be safe

        if (oldX == newX) && (oldZ == newZ) { // if no movement, then don't check anything
            break
        }

        // SEE IF CAN GO OVER POSSIBLY

        let type = Int(gFenceList[f].type)

        if !isEnemy { // make sure non-enemies skip the invisible enemy fences
            if type == Int(FENCE_TYPE_INVISIBLEBLOCKENEMY) {
                continue
            }
        }

        // (The original "letGoOver"/"letGoUnder" switch only had one other
        // case, FENCE_TYPE_LAWNEDGING, which no longer exists in this
        // build and was already commented out in the original - so those
        // flags were always false, and the "go over"/"go under" branches
        // below were dead code. Dropped entirely here.)

        // QUICK CHECK TO SEE IF OLD & NEW COORDS (PLUS RADIUS) ARE OUTSIDE OF FENCE'S BBOX

        var temp = gFenceList[f].bBox.min.x - r2
        if (Float(oldX) < temp) && (Float(newX) < temp) {
            continue
        }
        temp = gFenceList[f].bBox.max.x + r2
        if (Float(oldX) > temp) && (Float(newX) > temp) {
            continue
        }

        temp = gFenceList[f].bBox.min.z - r2
        if (Float(oldZ) < temp) && (Float(newZ) < temp) {
            continue
        }
        temp = gFenceList[f].bBox.max.z + r2
        if (Float(oldZ) > temp) && (Float(newZ) > temp) {
            continue
        }

        let nubs = gFenceList[f].nubList! // point to nub list
        let numFenceSegments = Int(gFenceList[f].numNubs) - 1 // get # line segments in fence

        // SCAN EACH SECTION OF THE FENCE

        var numReScans = 0
        var i = 0
        while i < numFenceSegments {
            // GET LINE SEG ENDPOINTS

            let segFromX = Double(nubs[i].x)
            let segFromZ = Double(nubs[i].z)
            let segToX = Double(nubs[i + 1].x)
            let segToZ = Double(nubs[i + 1].z)


            // CALC NORMAL TO THE LINE
            //
            // We need to find the point on the bounding sphere which is closest to the line
            // in order to do good collision checks

            var lineNormal = OGLVector2D()
            lineNormal.x = Float(oldX - segFromX) // calc normalized vector from ref pt. to section endpoint 0
            lineNormal.y = Float(oldZ - segFromZ)
            var lineNormalNorm = OGLVector2D()
            OGLVector2D_Normalize(&lineNormal, &lineNormalNorm)
            lineNormal = lineNormalNorm
            let cross = OGLVector2D_Cross(&gFenceList[f].sectionVectors[i], &lineNormal) // calc cross product to determine which side we're on

            if cross < 0.0 {
                lineNormal.x = -gFenceList[f].sectionNormals[i].x // on the other side, so flip vector
                lineNormal.y = -gFenceList[f].sectionNormals[i].y
            } else {
                lineNormal = gFenceList[f].sectionNormals[i] // use pre-calculated vector
            }

            // CALC FROM-TO POINTS OF MOTION

            let fromX = oldX - (Double(lineNormal.x) * radius)
            let fromZ = oldZ - (Double(lineNormal.y) * radius)
            let toX = newX - (Double(lineNormal.x) * radius)
            let toZ = newZ - (Double(lineNormal.y) * radius)

            // SEE IF THE LINES INTERSECT

            var intersectX: Float = 0
            var intersectZ: Float = 0
            let intersected = IntersectLineSegments(Float(fromX), Float(fromZ), Float(toX), Float(toZ),
                                                     Float(segFromX), Float(segFromZ), Float(segToX), Float(segToZ),
                                                     &intersectX, &intersectZ) != 0

            if intersected {
                hit = true

                // HANDLE THE INTERSECTION
                //
                // Move so edge of sphere would be tangent, but also a bit
                // farther so it isnt tangent.

                gCoord.x = intersectX + (lineNormal.x * Float(radius)) + (lineNormal.x * 8.0)
                gCoord.z = intersectZ + (lineNormal.y * Float(radius)) + (lineNormal.y * 8.0)

                // BOUNCE OFF WALL

                var deltaV = OGLVector2D()
                deltaV.x = gDelta.x
                deltaV.y = gDelta.z
                var deltaVReflected = OGLVector2D()
                ReflectVector2D(&deltaV, &lineNormal, &deltaVReflected)
                deltaV = deltaVReflected
                gDelta.x = deltaV.x * 0.6
                gDelta.z = deltaV.y * 0.6

                // UPDATE COORD & SCAN AGAIN

                newX = Double(gCoord.x)
                newZ = Double(gCoord.z)
                numReScans += 1
                if numReScans < 4 {
                    i = -1 // reset segment index to scan all again (will ++ to 0 on next loop)
                } else {
                    // we don't want to get stuck inside the fence (from having landed on it)
                    gCoord.x = Float(oldX) // woah!  there were a lot of hits, so let's just reset the coords to be safe!
                    gCoord.z = Float(oldZ)
                    i += 1
                    continue fenceLoop
                }
            }

            // NO INTERSECT, DO SAFETY CHECK FOR /\ CASES
            //
            // The above check may fail when the sphere is going thru
            // the tip of a tee pee /\ intersection, so this is a hack
            // to get around it.
            else {
                // SEE IF EITHER ENDPOINT IS IN SPHERE

                if (CalcQuickDistance(Float(segFromX), Float(segFromZ), Float(newX), Float(newZ)) <= Float(radius)) ||
                    (CalcQuickDistance(Float(segToX), Float(segToZ), Float(newX), Float(newZ)) <= Float(radius)) {
                    hit = true

                    gCoord.x = Float(oldX)
                    gCoord.z = Float(oldZ)

                    // BOUNCE OFF WALL

                    var deltaV = OGLVector2D()
                    deltaV.x = gDelta.x
                    deltaV.y = gDelta.z
                    var deltaVReflected = OGLVector2D()
                ReflectVector2D(&deltaV, &lineNormal, &deltaVReflected)
                deltaV = deltaVReflected
                    gDelta.x = deltaV.x * 0.5
                    gDelta.z = deltaV.y * 0.5
                    return hit ? 1 : 0
                } else {
                    i += 1
                    continue
                }
            }

            i += 1
        } // for i
    }

    return hit ? 1 : 0
}
