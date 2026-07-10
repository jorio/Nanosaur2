// Objects2.swift - Port of Objects2.c to Swift
//
// gEngine.objects.meshNum was `static` (file-private) in C, so it moves into private Swift
// state; gEngine.objects.numWorldCalcsThisFrame stays declared in game.h/extern-visible but
// nothing else in the codebase actually references it, so it's fine as a
// plain Swift global too (no C-linkage needed since nothing `extern`s it).

private let SHADOW_Y_OFF: Float = 2.1


// MARK: - fixed-array-field helpers (all struct fields, never unions)

@inline(__always) private func collisionBoxesBase(_ n: UnsafeMutablePointer<ObjNode>) -> UnsafeMutablePointer<CollisionBoxType> {
    UnsafeMutableRawPointer(n.pointer(to: \.CollisionBoxes)!).assumingMemoryBound(to: CollisionBoxType.self)
}

@inline(__always) private func worldMeshesBase(_ n: UnsafeMutablePointer<ObjNode>) -> UnsafeMutablePointer<MOVertexArrayData> {
    UnsafeMutableRawPointer(n.pointer(to: \.WorldMeshes)!).assumingMemoryBound(to: MOVertexArrayData.self)
}

@inline(__always) private func worldPlaneEQsBase(_ n: UnsafeMutablePointer<ObjNode>) -> UnsafeMutablePointer<UnsafeMutablePointer<OGLPlaneEquation>?> {
    UnsafeMutableRawPointer(n.pointer(to: \.WorldPlaneEQs)!).assumingMemoryBound(to: UnsafeMutablePointer<OGLPlaneEquation>?.self)
}

// MARK: - Object collision

func AddCollisionBoxToObject(_ theNode: UnsafeMutablePointer<ObjNode>, _ top: Float, _ bottom: Float, _ left: Float, _ right: Float, _ front: Float, _ back: Float) {
    let boxPtr = collisionBoxesBase(theNode)

    let i = Int(theNode.pointee.NumCollisionBoxes) // inc # collision boxes
    theNode.pointee.NumCollisionBoxes += 1

    boxPtr[i].left = theNode.pointee.Coord.x + left
    boxPtr[i].right = theNode.pointee.Coord.x + right
    boxPtr[i].top = theNode.pointee.Coord.y + top
    boxPtr[i].bottom = theNode.pointee.Coord.y + bottom
    boxPtr[i].back = theNode.pointee.Coord.z + back
    boxPtr[i].front = theNode.pointee.Coord.z + front

    KeepOldCollisionBoxes(theNode)
}

func CreateCollisionBoxFromBoundingBox(_ theNode: UnsafeMutablePointer<ObjNode>, _ tweakXZ: Float, _ tweakY: Float) {
    theNode.pointee.NumCollisionBoxes = 1

    var sx: Float, sy: Float, sz: Float
    if Int32(theNode.pointee.Genre) == Int32(SKELETON_GENRE) {
        sx = tweakXZ; sz = tweakXZ
        sy = 1.0
    } else {
        sx = theNode.pointee.Scale.x * tweakXZ
        sy = theNode.pointee.Scale.y
        sz = theNode.pointee.Scale.z * tweakXZ
    }

    // CONVERT TO COLLISON BOX
    let bBox = theNode.pointee.LocalBBox

    theNode.pointee.LeftOff = bBox.min.x * sx
    theNode.pointee.RightOff = bBox.max.x * sx
    theNode.pointee.FrontOff = bBox.max.z * sz
    theNode.pointee.BackOff = bBox.min.z * sz
    theNode.pointee.BottomOff = bBox.min.y * sy
    theNode.pointee.TopOff = theNode.pointee.BottomOff + (bBox.max.y - bBox.min.y) * sy * tweakY

    CalcObjectBoxFromNode(theNode)
    KeepOldCollisionBoxes(theNode)
}

// Same as above, but does not touch the old boxes
func CreateCollisionBoxFromBoundingBox_Update(_ theNode: UnsafeMutablePointer<ObjNode>, _ tweakXZ: Float, _ tweakY: Float) {
    theNode.pointee.NumCollisionBoxes = 1

    var sx: Float, sy: Float, sz: Float
    if Int32(theNode.pointee.Genre) == Int32(SKELETON_GENRE) {
        sx = tweakXZ; sz = tweakXZ
        sy = 1.0
    } else {
        sx = theNode.pointee.Scale.x * tweakXZ
        sy = theNode.pointee.Scale.y
        sz = theNode.pointee.Scale.z * tweakXZ
    }

    // CONVERT TO COLLISON BOX
    let bBox = theNode.pointee.LocalBBox

    theNode.pointee.LeftOff = bBox.min.x * sx
    theNode.pointee.RightOff = bBox.max.x * sx
    theNode.pointee.FrontOff = bBox.max.z * sz
    theNode.pointee.BackOff = bBox.min.z * sz
    theNode.pointee.BottomOff = bBox.min.y * sy
    theNode.pointee.TopOff = theNode.pointee.BottomOff + (bBox.max.y - bBox.min.y) * sy * tweakY

    CalcObjectBoxFromNode(theNode)
}

// Same as above except it expands the x/z box to the max of x or z so object can rotate without problems.
func CreateCollisionBoxFromBoundingBox_Maximized(_ theNode: UnsafeMutablePointer<ObjNode>, _ scaleMag: Float) {
    theNode.pointee.NumCollisionBoxes = 1

    // POINT TO BOUNDING BOX
    let bBox = theNode.pointee.LocalBBox

    // DETERMINE LARGEST SIDE
    var s: Float
    if Int32(theNode.pointee.Genre) == Int32(SKELETON_GENRE) {
        s = 1.0 // skeleton bboxes are already scaled correctly
    } else {
        s = theNode.pointee.Scale.x
    }

    s *= scaleMag

    var maxSide = fabsf(bBox.min.x * s)
    var off = fabsf(bBox.max.x * s)
    if off > maxSide { maxSide = off }
    off = fabsf(bBox.max.z * s)
    if off > maxSide { maxSide = off }
    off = fabsf(bBox.min.z) * s
    if off > maxSide { maxSide = off }

    // CONVERT TO COLLISON BOX
    theNode.pointee.LeftOff = -maxSide
    theNode.pointee.RightOff = maxSide
    theNode.pointee.FrontOff = maxSide
    theNode.pointee.BackOff = -maxSide
    theNode.pointee.TopOff = bBox.max.y * s
    theNode.pointee.BottomOff = bBox.min.y * s
    theNode.pointee.TopOff = theNode.pointee.BottomOff + (bBox.max.y - bBox.min.y) * s

    CalcObjectBoxFromNode(theNode)
    KeepOldCollisionBoxes(theNode)
}

func CreateCollisionBoxFromBoundingBox_Rotated(_ theNode: UnsafeMutablePointer<ObjNode>, _ tweakXZ: Float, _ tweakY: Float) {
    theNode.pointee.NumCollisionBoxes = 1

    // CALC ROTATED BBOX
    var m = OGLMatrix4x4()
    m.setRotateXYZ(theNode.pointee.Rot.x, theNode.pointee.Rot.y, theNode.pointee.Rot.z) // make rot matrix

    var bBox = OGLBoundingBox()
    if Int32(theNode.pointee.Genre) == Int32(SKELETON_GENRE) { // calc bbox
        MO_CalcBoundingBox(GetBG3DGroupObject(Int32(MODEL_GROUP_SKELETONBASE) + Int32(theNode.pointee.Type), 0), &bBox, &m)
    } else {
        MO_CalcBoundingBox(GetBG3DGroupObject(Int32(theNode.pointee.Group), Int32(theNode.pointee.Type)), &bBox, &m)
    }

    // CONVERT TO COLLISON BOX
    let s = theNode.pointee.Scale.x

    theNode.pointee.LeftOff = bBox.min.x * (s * tweakXZ)
    theNode.pointee.RightOff = bBox.max.x * (s * tweakXZ)
    theNode.pointee.FrontOff = bBox.max.z * (s * tweakXZ)
    theNode.pointee.BackOff = bBox.min.z * (s * tweakXZ)

    theNode.pointee.BottomOff = bBox.min.y * s
    theNode.pointee.TopOff = theNode.pointee.BottomOff + (bBox.max.y - bBox.min.y) * s * tweakY

    CalcObjectBoxFromNode(theNode)
    KeepOldCollisionBoxes(theNode)
}

// Also keeps old coordinate and stuff
func KeepOldCollisionBoxes(_ theNode: UnsafeMutablePointer<ObjNode>) {
    let boxes = collisionBoxesBase(theNode)

    for i in 0..<Int(theNode.pointee.NumCollisionBoxes) {
        boxes[i].oldTop = boxes[i].top
        boxes[i].oldBottom = boxes[i].bottom
        boxes[i].oldLeft = boxes[i].left
        boxes[i].oldRight = boxes[i].right
        boxes[i].oldFront = boxes[i].front
        boxes[i].oldBack = boxes[i].back
    }

    theNode.pointee.OldCoord = theNode.pointee.Coord // remember coord also
}

// This does a simple 1 box calculation for basic objects.
// Box is calculated based on theNode's coords.
func CalcObjectBoxFromNode(_ theNode: UnsafeMutablePointer<ObjNode>) {
    if theNode.pointee.NumCollisionBoxes > 0 {
        let boxPtr = collisionBoxesBase(theNode) // get ptr to 1st box (presumed only box)

        boxPtr[0].left = theNode.pointee.Coord.x + theNode.pointee.LeftOff
        boxPtr[0].right = theNode.pointee.Coord.x + theNode.pointee.RightOff
        boxPtr[0].top = theNode.pointee.Coord.y + theNode.pointee.TopOff
        boxPtr[0].bottom = theNode.pointee.Coord.y + theNode.pointee.BottomOff
        boxPtr[0].back = theNode.pointee.Coord.z + theNode.pointee.BackOff
        boxPtr[0].front = theNode.pointee.Coord.z + theNode.pointee.FrontOff
    }
}

// This does a simple 1 box calculation for basic objects.
// Box is calculated based on gEngine.objects.coord
func CalcObjectBoxFromGlobal(_ theNode: UnsafeMutablePointer<ObjNode>?) {
    guard let theNode else {
        return
    }

    let boxPtr = collisionBoxesBase(theNode) // get ptr to 1st box (presumed only box)

    boxPtr[0].left = gEngine.objects.coord.x + theNode.pointee.LeftOff
    boxPtr[0].right = gEngine.objects.coord.x + theNode.pointee.RightOff
    boxPtr[0].back = gEngine.objects.coord.z + theNode.pointee.BackOff
    boxPtr[0].front = gEngine.objects.coord.z + theNode.pointee.FrontOff
    boxPtr[0].top = gEngine.objects.coord.y + theNode.pointee.TopOff
    boxPtr[0].bottom = gEngine.objects.coord.y + theNode.pointee.BottomOff
}

// Sets an object's collision offset/bounds. Adjust accordingly for input rotation 0..3 (clockwise)
func SetObjectCollisionBounds(_ theNode: UnsafeMutablePointer<ObjNode>, _ top: Float, _ bottom: Float, _ left: Float, _ right: Float, _ front: Float, _ back: Float) {
    theNode.pointee.NumCollisionBoxes = 1 // 1 collision box
    theNode.pointee.TopOff = top
    theNode.pointee.BottomOff = bottom
    theNode.pointee.LeftOff = left
    theNode.pointee.RightOff = right
    theNode.pointee.FrontOff = front
    theNode.pointee.BackOff = back

    CalcObjectBoxFromNode(theNode)
    KeepOldCollisionBoxes(theNode)
}

func CalcNewTargetOffsets(_ theNode: UnsafeMutablePointer<ObjNode>, _ scale: Float) {
    theNode.pointee.TargetOff.x = RandomFloat2() * scale
    theNode.pointee.TargetOff.z = RandomFloat2() * scale
}

// MARK: - Object shadows

func AttachShadowToObject(_ theNode: UnsafeMutablePointer<ObjNode>, _ shadowType: ShadowType, _ scaleX: Float, _ scaleZ: Float, _ checkBlockers: UInt8) -> UnsafeMutablePointer<ObjNode>? {
    let x = theNode.pointee.Coord.x
    let z = theNode.pointee.Coord.z
    let y = GetTerrainY(x, z) + SHADOW_Y_OFF

    var def = NewObjectDefinitionType()
    def.genre = UInt8(CUSTOM_GENRE)
    def.coord = OGLPoint3D(x: x, y: y, z: z)
    def.scale = scaleX
    def.rot = theNode.pointee.Rot.y
    def.flags = UInt32(STATUS_BIT_NOZWRITES | STATUS_BIT_NOLIGHTING) | gAutoFadeStatusBits
    def.slot = theNode.pointee.Slot >= UInt16(SLOT_OF_DUMB + 1) ? Int16(theNode.pointee.Slot + 1) : Int16(SLOT_OF_DUMB + 1) // shadow *must* be after parent!
    def.moveCall = nil
    def.drawCall = cDrawShadow

    guard let shadowObj = MakeNewObject(&def) else {
        return nil
    }

    theNode.pointee.ShadowNode = shadowObj

    shadowObj.pointee.SpecialF.0 = scaleX // need to remeber scales for update
    shadowObj.pointee.SpecialF.1 = scaleZ
    shadowObj.pointee.Flag.0 = Int8(bitPattern: checkBlockers)
    shadowObj.pointee.Kind = Int32(bitPattern: shadowType.rawValue) // remember the shadow type

    return shadowObj
}

// For creating shadows whic are never going to call UpdateShadow()
func AttachStaticShadowToObject(_ theNode: UnsafeMutablePointer<ObjNode>, _ shadowType: ShadowType, _ scaleX: Float, _ scaleZ: Float) -> UnsafeMutablePointer<ObjNode> {
    let x = theNode.pointee.Coord.x
    let z = theNode.pointee.Coord.z
    let y = GetTerrainY(x, z) + SHADOW_Y_OFF

    var def = NewObjectDefinitionType()
    def.genre = UInt8(CUSTOM_GENRE)
    def.coord = OGLPoint3D(x: x, y: y, z: z)
    def.flags = UInt32(STATUS_BIT_NOZWRITES | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOFOG) | gAutoFadeStatusBits
    def.slot = theNode.pointee.Slot >= UInt16(SLOT_OF_DUMB + 1) ? Int16(theNode.pointee.Slot + 1) : Int16(SLOT_OF_DUMB + 1) // shadow *must* be after parent!
    def.moveCall = nil
    def.drawCall = cDrawShadow
    def.rot = theNode.pointee.Rot.y
    def.scale = scaleX

    let shadowObj = MakeNewObject(&def)!

    theNode.pointee.ShadowNode = shadowObj

    shadowObj.pointee.Kind = Int32(bitPattern: shadowType.rawValue) // remember the shadow type
    shadowObj.pointee.Scale.x = scaleX
    shadowObj.pointee.Scale.z = scaleZ
    RotateOnTerrain(shadowObj, SHADOW_Y_OFF, nil) // set transform matrix

    return shadowObj
}

func UpdateShadow(_ theNode: UnsafeMutablePointer<ObjNode>?) {
    guard let theNode else {
        return
    }

    guard let shadowNode = theNode.pointee.ShadowNode else {
        return
    }

    if theNode.hasStatus(STATUS_BIT_HIDDEN) { // hide shadow if parent hidden
        shadowNode.setStatus(STATUS_BIT_HIDDEN)
    } else {
        shadowNode.clearStatus(STATUS_BIT_HIDDEN)
    }

    shadowNode.pointee.ColorFilter.a = theNode.pointee.ColorFilter.a * 0.9 // match fade and decay a little to adjust it how we want it

    let x = theNode.pointee.Coord.x
    let bottom = theNode.pointee.Coord.y + theNode.pointee.BottomOff
    let z = theNode.pointee.Coord.z

    shadowNode.pointee.Coord = theNode.pointee.Coord
    shadowNode.pointee.Rot.y = theNode.pointee.Rot.y

    // SEE IF SHADOW IS ON BLOCKER OBJECT OR ON TERRAIN
    var onBlocker = false

    if shadowNode.pointee.Flag.0 != 0 {
        var top = theNode.pointee.Coord.y + theNode.pointee.TopOff // init top
        var highestY: Float = -100_000

        // SEE IF ON WATER
        var y: Float = 0
        if GetWaterY(x, z, &y) != 0 {
            top = y + SHADOW_Y_OFF
            if top > GetTerrainY(x, z) { // make sure water is above terrain
                onBlocker = true
                highestY = y
            }
        }

        // SEE IF ON OBJNODE
        for node in usableObjectNodes {
            if node.pointee.CType & UInt32(CTYPE_BLOCKSHADOW) != 0 { // look for things which can block the shadow
                let boxes = collisionBoxesBase(node)
                for i in 0..<Int(node.pointee.NumCollisionBoxes) { // check all collision boxes
                    if x < boxes[i].left { continue }
                    if x > boxes[i].right { continue }
                    if z > boxes[i].front { continue }
                    if z < boxes[i].back { continue }

                    if bottom < boxes[i].top // if bottom & top of owner is below top of blocker, then skip
                        && top < boxes[i].top {
                        continue
                    }

                    // SHADOW IS ON OBJECT
                    if boxes[i].top > highestY { // is this higher than anything else we've found?
                        highestY = boxes[i].top
                    }

                    onBlocker = true
                }
            }
        }

        // SET SHADOW'S Y
        if onBlocker {
            shadowNode.pointee.Coord.y = highestY + SHADOW_Y_OFF // set shadow's Y
        }

        // IF WE WERE ON ONE THEN FINISH AND BAIL
        if onBlocker {
            shadowNode.pointee.Scale.x = shadowNode.pointee.SpecialF.0 // use preset scale
            shadowNode.pointee.Scale.z = shadowNode.pointee.SpecialF.1
            UpdateObjectTransforms(shadowNode)
            return
        }
    }

    // SHADOW IS ON TERRAIN
    RotateOnTerrain(shadowNode, SHADOW_Y_OFF, nil) // set transform matrix

    // CALC SCALE OF SHADOW
    var dist = (bottom - shadowNode.pointee.Coord.y) * (1.0 / 1000.0) // as we go higher, shadow gets smaller
    if dist < 0 {
        dist = 0
    }

    dist = 1.0 - dist

    var scaleX = dist * shadowNode.pointee.SpecialF.0
    var scaleZ = dist * shadowNode.pointee.SpecialF.1

    if scaleX < 0 { scaleX = 0 }
    if scaleZ < 0 { scaleZ = 0 }

    shadowNode.pointee.Scale.x = scaleX // this scale wont get updated until next frame (RotateOnTerrain).
    shadowNode.pointee.Scale.z = scaleZ
}

private let cDrawShadow: @convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void = { theNode in
    drawShadow(theNode!)
}

private func drawShadow(_ theNode: UnsafeMutablePointer<ObjNode>) {
    let shadowType = Int(theNode.pointee.Kind)

    OGL_PushState()
    OGL_DisableCullFace()

    // SUBMIT THE MATRIX
    withUnsafePointer(to: &theNode.pointee.BaseTransformMatrix) {
        UnsafeRawPointer($0).withMemoryRebound(to: Float.self, capacity: 16) {
            gEngine.renderer.multMatrix($0)
        }
    }

    // SUBMIT SHADOW TEXTURE
    gGlobalTransparency = theNode.pointee.ColorFilter.a

    MO_DrawMaterial(GetSpriteGroupPtr(Int32(SPRITE_GROUP_GLOBAL))![Int(GLOBAL_SObjType_Shadow_Circular) + shadowType].materialObject?.assumingMemoryBound(to: MOMaterialObject.self))

    // DRAW THE SHADOW
    gEngine.renderer.beginImmediate(.quads)
    gEngine.renderer.texCoord2f(0, 0); gEngine.renderer.vertex3f(-20, 0, 20)
    gEngine.renderer.texCoord2f(1, 0); gEngine.renderer.vertex3f(20, 0, 20)
    gEngine.renderer.texCoord2f(1, 1); gEngine.renderer.vertex3f(20, 0, -20)
    gEngine.renderer.texCoord2f(0, 1); gEngine.renderer.vertex3f(-20, 0, -20)
    gEngine.renderer.endImmediate()

    OGL_PopState()
    gGlobalTransparency = 1.0
}

// MARK: - Object culling

func CullTestAllObjects() {
    // PROCESS EACH OBJECT
    for node in allObjectNodes {
        var skipToNext = false
        var drawOn = false

        if node.hasStatus(STATUS_BIT_HIDDEN) { // if hidden then skip
            skipToNext = true
        } else if node.hasStatus(STATUS_BIT_DONTCULL) { // see if dont want to use our culling
            drawOn = true
        } else if node.pointee.LocalBBox.isEmpty != 0 { // skip culling if no bbox
            drawOn = true
        }

        if !skipToNext && !drawOn {
            // CALCULATE THE LOCAL->FRUSTUM MATRIX FOR THIS OBJECT
            var m = OGLMatrix4x4()

            if Int32(node.pointee.Genre) == Int32(SKELETON_GENRE) { // skeletons are already oriented, just need translation
                var m2 = OGLMatrix4x4()
                m2.setTranslate(node.pointee.Coord.x, node.pointee.Coord.y, node.pointee.Coord.z)
                m = m2.multiplied(by: gWorldToFrustumMatrix)
            } else { // non-skeletons need full transform
                m = node.pointee.BaseTransformMatrix.multiplied(by: gWorldToFrustumMatrix)
            }

            let m00 = matValue(&m, M00), m01 = matValue(&m, M01), m02 = matValue(&m, M02), m03 = matValue(&m, M03)
            let m10 = matValue(&m, M10), m11 = matValue(&m, M11), m12 = matValue(&m, M12), m13 = matValue(&m, M13)
            let m20 = matValue(&m, M20), m21 = matValue(&m, M21), m22 = matValue(&m, M22), m23 = matValue(&m, M23)
            let m30 = matValue(&m, M30), m31 = matValue(&m, M31), m32 = matValue(&m, M32), m33 = matValue(&m, M33)

            // TRANSFORM THE BOUNDING BOX
            let bBox = node.pointee.LocalBBox
            let minX = bBox.min.x, minY = bBox.min.y, minZ = bBox.min.z
            let maxX = bBox.max.x, maxY = bBox.max.y, maxZ = bBox.max.z

            var clipCodeAND: UInt32 = ~0

            for i in 0..<8 {
                var lX: Float, lY: Float, lZ: Float // Local space co-ordinates

                switch i { // load current bbox corner in IX,IY,IZ
                case 0: lX = minX; lY = minY; lZ = minZ
                case 1: lX = minX; lY = minY; lZ = maxZ
                case 2: lX = minX; lY = maxY; lZ = minZ
                case 3: lX = minX; lY = maxY; lZ = maxZ
                case 4: lX = maxX; lY = minY; lZ = minZ
                case 5: lX = maxX; lY = minY; lZ = maxZ
                case 6: lX = maxX; lY = maxY; lZ = minZ
                default: lX = maxX; lY = maxY; lZ = maxZ
                }

                let hW = lX * m30 + lY * m31 + lZ * m32 + m33 // Homogeneous co-ordinates
                let hY = lX * m10 + lY * m11 + lZ * m12 + m13
                let hZ = lX * m20 + lY * m21 + lZ * m22 + m23
                let hX = lX * m00 + lY * m01 + lZ * m02 + m03

                let minusHW = -hW

                var clipFlags: UInt32 // CHECK Y
                if hY < minusHW {
                    clipFlags = 0x8
                } else if hY > hW {
                    clipFlags = 0x4
                } else {
                    clipFlags = 0
                }

                // CHECK Z
                if hZ > hW {
                    clipFlags |= 0x20
                } else if hZ < 0 {
                    clipFlags |= 0x10
                }

                // CHECK X
                if hX < minusHW {
                    clipFlags |= 0x2
                } else if hX > hW {
                    clipFlags |= 0x1
                }

                clipCodeAND &= clipFlags
            }

            // SEE IF WAS CULLED OR NOT
            if clipCodeAND != 0 { // check for case #2
                drawOn = false
            } else {
                drawOn = true
            }
        }

        if !skipToNext {
            if drawOn {
                node.pointee.StatusBits &= ~(UInt32(STATUS_BIT_ISCULLED1) << gCurrentSplitScreenPane) // clear cull bit
            } else {
                node.pointee.StatusBits |= (UInt32(STATUS_BIT_ISCULLED1) << gCurrentSplitScreenPane) // set cull bit for this pane/player
            }
        }
    }
}

// Returns true if object is culled in all panes
func IsObjectTotallyCulled(_ theNode: UnsafeMutablePointer<ObjNode>) -> UInt8 {
    for i in 0..<Int(gEngine.player.numPlayers) {
        let culledThisPane = theNode.pointee.StatusBits & (UInt32(STATUS_BIT_ISCULLED1) << i)
        if culledThisPane == 0 {
            return 0
        }
    }

    return 1
}

// MARK: - World points

func CalcDisplayGroupWorldPoints(_ theNode: UnsafeMutablePointer<ObjNode>) {
    gEngine.renderer.matrixMode(.modelview)
    gEngine.renderer.pushMatrix()
    gEngine.renderer.loadIdentity()

    gEngine.objects.meshNum = 0

    moCalcWorldPointsObject(theNode, UnsafeMutableRawPointer(theNode.pointee.BaseGroup))

    gEngine.renderer.popMatrix()

    theNode.hasWorldPoints = true
    gEngine.objects.numWorldCalcsThisFrame += 1
}

private func moCalcWorldPointsObject(_ theNode: UnsafeMutablePointer<ObjNode>, _ object: MetaObjectPtr?) {
    guard let object else {
        return
    }

    let objHead = object.assumingMemoryBound(to: MetaObjectHeader.self)

    // VERIFY COOKIE
    if objHead.pointee.cookie != MO_COOKIE {
        SwFatal("MO_CalcWorldPoints_Object: cookie is invalid!")
    }

    // HANDLE TYPE
    switch objHead.pointee.type {
    case .geometry:
        let vObj = object.assumingMemoryBound(to: MOVertexArrayObject.self)
        moCalcWorldPointsVertexArray(theNode, vObj.pointer(to: \.objectData)!)

    case .group:
        moCalcWorldPointsGroup(theNode, object.assumingMemoryBound(to: MOGroupObject.self))

    case .matrix:
        moCalcWorldPointsMatrix(object.assumingMemoryBound(to: MOMatrixObject.self))

    default:
        break
    }
}

private func moCalcWorldPointsGroup(_ theNode: UnsafeMutablePointer<ObjNode>, _ object: UnsafeMutablePointer<MOGroupObject>) {
    // PUSH MATRIES WITH OPENGL
    gEngine.renderer.matrixMode(.modelview)
    gEngine.renderer.pushMatrix()

    // PARSE GROUP
    let numChildren = Int(object.numObjectsInGroup) // get # objects in group

    for i in 0..<numChildren {
        moCalcWorldPointsObject(theNode, object.groupContent(at: i))
    }

    // RETREIVE OPENGL MATRICES
    gEngine.renderer.matrixMode(.modelview)
    gEngine.renderer.popMatrix()
}

private func moCalcWorldPointsMatrix(_ matObj: UnsafeMutablePointer<MOMatrixObject>) {
    // MULTIPLY CURRENT MATRIX BY THIS
    withUnsafePointer(to: &matObj.pointee.matrix) {
        UnsafeRawPointer($0).withMemoryRebound(to: Float.self, capacity: 16) {
            gEngine.renderer.multMatrix($0)
        }
    }
}

private func moCalcWorldPointsVertexArray(_ theNode: UnsafeMutablePointer<ObjNode>, _ data: UnsafeMutablePointer<MOVertexArrayData>) {
    let numPoints = Int(data.pointee.numPoints) // get # points in this mesh
    let meshNum = Int(gEngine.objects.meshNum)

    if meshNum >= MAX_MESHES_IN_MODEL {
        SwFatal("MO_CalcWorldPoints_VertexArray: meshNum >= MAX_MESHES_IN_MODEL")
    }

    let worldMeshes = worldMeshesBase(theNode)

    // SEE IF NEED TO INIT THIS MESH COPY
    if worldMeshes[meshNum].points == nil {
        worldMeshes[meshNum] = data.pointee // copy the entire vertex array data struct
        worldMeshes[meshNum].points = AllocPtrClear(MemoryLayout<OGLPoint3D>.size * numPoints)?.assumingMemoryBound(to: OGLPoint3D.self) // assign a new points array, however
    }

    let worldBuffer = worldMeshes[meshNum].points! // get ptr to the world-space point buffer

    // TRANSFORM ALL OF THESE POINTS TO WORLD-SPACE

    // GET THE TRANSFORM MATRIX WE'VE BUILT
    var localToWorld = OGLMatrix4x4()
    withUnsafeMutablePointer(to: &localToWorld) {
        UnsafeMutableRawPointer($0).withMemoryRebound(to: Float.self, capacity: 16) {
            gEngine.renderer.getModelViewMatrix($0)
        }
    }

    // TRANSFORM EACH POINT INTO THE BUFFER
    OGLPoint3D.transformArray(data.pointee.points, by: localToWorld, into: worldBuffer, count: numPoints)

    // CALCULATE THE PLANE EQ FOR ALL OF THE TRIANGLES
    let numTriangles = Int(data.pointee.numTriangles) // get # triangles
    let tris = data.pointee.triangles! // get ptr to triangle array

    let worldPlaneEQs = worldPlaneEQsBase(theNode)
    if worldPlaneEQs[meshNum] == nil {
        worldPlaneEQs[meshNum] = AllocPtrClear(MemoryLayout<OGLPlaneEquation>.size * numTriangles)?.assumingMemoryBound(to: OGLPlaneEquation.self) // alloc array for plane eq's
    }

    for t in 0..<numTriangles {
        var pts = (OGLPoint3D(), OGLPoint3D(), OGLPoint3D())

        pts.0 = worldBuffer[Int(tris[t].vertexIndices.0)] // get the vertex world-coords
        pts.1 = worldBuffer[Int(tris[t].vertexIndices.1)]
        pts.2 = worldBuffer[Int(tris[t].vertexIndices.2)]

        withUnsafeMutablePointer(to: &pts) {
            $0.withMemoryRebound(to: OGLPoint3D.self, capacity: 3) { ptsPtr in
                OGL_ComputeTrianglePlaneEquation(ptsPtr, worldPlaneEQs[meshNum]! + t) // calc plane eq
            }
        }
    }

    gEngine.objects.meshNum += 1
}

// MARK: - Object chains

func HideObjectChain(_ theNode: UnsafeMutablePointer<ObjNode>?) {
    var node = theNode

    while let n = node {
        n.setStatus(STATUS_BIT_HIDDEN)
        node = n.pointee.ChainNode
    }
}

func ShowObjectChain(_ theNode: UnsafeMutablePointer<ObjNode>?) {
    var node = theNode

    while let n = node {
        n.clearStatus(STATUS_BIT_HIDDEN)
        node = n.pointee.ChainNode
    }
}

// MARK: - Background picture object node

func MakeBackgroundPictureObject(_ imagePath: String) -> UnsafeMutablePointer<ObjNode> {
    // The MetaObject creation protocol passes type-specific init data as a
    // raw void* - for pictures that's a C path string, consumed synchronously
    // during creation, so a withCString scope covers its whole lifetime.
    let backgroundPicture = imagePath.withCString {
        MO_CreateNewObjectOfType(.picture, 0, UnsafeMutableRawPointer(mutating: $0))
    }

    var def = NewObjectDefinitionType()
    def.genre = UInt8(DISPLAY_GROUP_GENRE)
    def.slot = Int16(BGPIC_SLOT)
    def.scale = 1.0
    def.flags = UInt32(SwStatusBitsFor2D)

    let obj = MakeNewObject(&def)!

    CreateBaseGroup(obj)
    UnsafeMutableRawPointer(obj.pointee.BaseGroup)?.append(backgroundPicture)

    MO_DisposeObjectReference(backgroundPicture)
    return obj
}
