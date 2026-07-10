// Objects.swift - Port of Objects.c to Swift
//
// The object-system state lives in ObjectSystem (gEngine.objects) now:
// nothing in any .c file touches any of it anymore.

private let MAX_OBJECTS_COUNT = 5000
private let OBJ_DEL_Q_SIZE_COUNT = 1500

/// Object-system state (master linked list, per-move scratch, autofade,
/// slot storage). Owned by GameEngine as `gEngine.objects`.
final class ObjectSystem {
    // Master object linked list
    var firstNodePtr: UnsafeMutablePointer<ObjNode>?
    var currentNode: UnsafeMutablePointer<ObjNode>?
    var numObjectNodes: Int32 = 0
    var numObjectNodesPeak: Int32 = 0

    // Coord/delta scratch of the object currently being moved
    // (GetObjectInfo copies in, UpdateObject copies back out)
    var coord = OGLPoint3D()
    var delta = OGLVector3D()

    // Autofade
    var autoFadeStartDist: Float = 0
    var autoFadeEndDist: Float = 0
    var autoFadeRangeFrac: Float = 0

    // Backing storage - was `static` (file-private) in the original C, so
    // it never needed to stay C-linked. A plain C array this size
    // (objectListStorage is 5000 ObjNodes) would import as an unworkable
    // giant tuple anyway, so we manage the storage ourselves with the same
    // zero-initializing allocator the C code already used for clearedObj.
    fileprivate let objectListStorage = AllocPtrClear(MemoryLayout<ObjNode>.size * MAX_OBJECTS_COUNT)!.assumingMemoryBound(to: ObjNode.self)
    fileprivate let objectDeleteQueueStorage = AllocPtrClear(MemoryLayout<UnsafeMutablePointer<ObjNode>?>.size * OBJ_DEL_Q_SIZE_COUNT)!.assumingMemoryBound(to: UnsafeMutablePointer<ObjNode>?.self)
    fileprivate var clearedObj: UnsafeMutablePointer<ObjNode>!

    fileprivate var mostRecentlyAddedNode: UnsafeMutablePointer<ObjNode>?
    fileprivate var nextNode: UnsafeMutablePointer<ObjNode>?
    fileprivate var numObjsInDeleteQueue: Int32 = 0

    // Objects2.swift scratch (fileprivate wouldn't reach across files)
    var meshNum: Int32 = 0
    var numWorldCalcsThisFrame: Int32 = 0

    // Pick.swift config flag
    var pickAllTrianglesAsDoubleSided: UInt8 = 0
}

// MARK: - fixed-array-field helpers (all struct fields, never unions)

@inline(__always) private func sparklesBase(_ n: UnsafeMutablePointer<ObjNode>) -> UnsafeMutablePointer<Int16> {
    UnsafeMutableRawPointer(n.pointer(to: \.Sparkles)!).assumingMemoryBound(to: Int16.self)
}
@inline(__always) private func contrailSlotBase(_ n: UnsafeMutablePointer<ObjNode>) -> UnsafeMutablePointer<Int16> {
    UnsafeMutableRawPointer(n.pointer(to: \.ContrailSlot)!).assumingMemoryBound(to: Int16.self)
}
@inline(__always) private func collisionBoxesBase(_ n: UnsafeMutablePointer<ObjNode>) -> UnsafeMutablePointer<CollisionBoxType> {
    UnsafeMutableRawPointer(n.pointer(to: \.CollisionBoxes)!).assumingMemoryBound(to: CollisionBoxType.self)
}
@inline(__always) private func worldMeshesBase(_ n: UnsafeMutablePointer<ObjNode>) -> UnsafeMutablePointer<MOVertexArrayData> {
    UnsafeMutableRawPointer(n.pointer(to: \.WorldMeshes)!).assumingMemoryBound(to: MOVertexArrayData.self)
}
@inline(__always) private func worldPlaneEQsBase(_ n: UnsafeMutablePointer<ObjNode>) -> UnsafeMutablePointer<UnsafeMutablePointer<OGLPlaneEquation>?> {
    UnsafeMutableRawPointer(n.pointer(to: \.WorldPlaneEQs)!).assumingMemoryBound(to: UnsafeMutablePointer<OGLPlaneEquation>?.self)
}

// MARK: - Object creation

func InitObjectManager() {
    // NOTE for 3DS: ObjectSystem's objectListStorage/objectDeleteQueueStorage
    // are instance properties allocated when gEngine is constructed. An
    // earlier file-scope-lazy-global version of this storage deadlocked
    // Embedded Swift's lazy-init guard on first touch (see
    // feedback_embedded_swift_lazy_globals) - if boot ever hangs at the
    // checkpoint below, gEngine's own lazy init is the first suspect.
    #if NANOSAUR_3DS
    "InitObjectManager: sizeof(ObjNode)=\(MemoryLayout<ObjNode>.size) total=\(MemoryLayout<ObjNode>.size * MAX_OBJECTS_COUNT)".withCString { Debug3DS_Log($0) }
    #endif

    // MARK ALL OBJECTS AS NOT USED
    for i in 0..<MAX_OBJECTS_COUNT {
        (gEngine.objects.objectListStorage + i).isUsed = false
    }
    #if NANOSAUR_3DS
    Debug3DS_Log("InitObjectManager: cleared isUsed loop")
    #endif

    CreateDummyInitObject()
    #if NANOSAUR_3DS
    Debug3DS_Log("InitObjectManager: CreateDummyInitObject done")
    #endif

    // INIT LINKED LIST

    gEngine.objects.currentNode = nil

    // CLEAR ENTIRE OBJECT LIST

    gEngine.objects.firstNodePtr = nil // no node yet

    gEngine.objects.numObjectNodes = 0
    #if NANOSAUR_3DS
    Debug3DS_Log("InitObjectManager: done")
    #endif
}

// We make a dummy ObjNode which is initialized to the default settings
// so that we can quickly initialize new ObjNode's simply by BlockMoving
// this dummy node into them.
private func CreateDummyInitObject() {
    gEngine.objects.clearedObj = AllocPtrClear(MemoryLayout<ObjNode>.size)!.assumingMemoryBound(to: ObjNode.self) // make a dummy objNode which is cleared to 0's
    #if NANOSAUR_3DS
    Debug3DS_Log("CreateDummyInitObject: clearedObj allocated")
    #endif

    for i in 0..<Int(MAX_NODE_SPARKLES) { // no sparkles
        sparklesBase(gEngine.objects.clearedObj)[i] = -1
    }

    gEngine.objects.clearedObj.pointee.LocalBBox.isEmpty = 1
    gEngine.objects.clearedObj.pointee.WorldBBox.isEmpty = 1

    gEngine.objects.clearedObj.pointee.BoundingSphereRadius = 100

    gEngine.objects.clearedObj.pointee.VertexArrayMode = UInt8(VertexArrayRangeType.bg3dModels.rawValue) // assume this object's vertex data is in the cached/static mode

    gEngine.objects.clearedObj.pointee.EffectChannel = -1 // no streaming sound effect
    gEngine.objects.clearedObj.pointee.ParticleGroup = -1 // no particle group

    for i in 0..<Int(MAX_CONTRAILS_PER_OBJNODE) { // no contrails
        contrailSlotBase(gEngine.objects.clearedObj)[i] = -1
    }

    gEngine.objects.clearedObj.pointee.SplineObjectIndex = -1 // no index yet

    gEngine.objects.clearedObj.pointee.ColorFilter.r = 1.0
    gEngine.objects.clearedObj.pointee.ColorFilter.g = 1.0
    gEngine.objects.clearedObj.pointee.ColorFilter.b = 1.0
    gEngine.objects.clearedObj.pointee.ColorFilter.a = 1.0
}

// MAKE NEW OBJECT & RETURN PTR TO IT
//
// The linked list is sorted from smallest to largest!
func MakeNewObject(_ newObjDef: UnsafeMutablePointer<NewObjectDefinitionType>) -> UnsafeMutablePointer<ObjNode>? {
    let flags = newObjDef.pointee.flags

    // FIND NEW FREE OBJECT
    //
    // For speed, we try to find a free object in our big object array.
    // But if nothing is free then we malloc one as a last resort to keep
    // the game from just crashing.

    var newNodePtr: UnsafeMutablePointer<ObjNode>!
    var i: Int32 = -1
    for idx in 0..<Int32(MAX_OBJECTS_COUNT) {
        if !(gEngine.objects.objectListStorage + Int(idx)).isUsed {
            newNodePtr = gEngine.objects.objectListStorage + Int(idx) // point to object from list
            i = idx
            break
        }
    }

    if newNodePtr == nil {
        // NOTHING AVAILBLE IN LIST, SO MALLOC A NEW ONE
        newNodePtr = AllocPtrClear(MemoryLayout<ObjNode>.size)!.assumingMemoryBound(to: ObjNode.self)
        i = -1
    }

    // CLEAR THE OBJNODE & SET DATA

    newNodePtr.pointee = gEngine.objects.clearedObj.pointee // copy the cleared/initied obj into here

    newNodePtr.pointee.objectNum = Int16(i) // not from gObjectList array
    newNodePtr.isUsed = true

    newNodePtr.pointee.Cookie = MyRandomLong() // give each object a unique cookie

    // INITIALIZE ALL OF THE FIELDS

    let slot = newObjDef.pointee.slot

    newNodePtr.pointee.Slot = UInt16(bitPattern: slot)
    newNodePtr.pointee.Type = Int32(newObjDef.pointee.type)
    newNodePtr.pointee.Group = Int32(newObjDef.pointee.group)
    newNodePtr.pointee.MoveCall = newObjDef.pointee.moveCall
    newNodePtr.pointee.CustomDrawFunction = newObjDef.pointee.drawCall

    if flags & UInt32(STATUS_BIT_ONSPLINE) != 0 {
        newNodePtr.pointee.SplineMoveCall = newObjDef.pointee.moveCall // save spline move routine
    }

    newNodePtr.pointee.Genre = newObjDef.pointee.genre
    newNodePtr.pointee.Coord = newObjDef.pointee.coord // save coords
    newNodePtr.pointee.InitCoord = newObjDef.pointee.coord
    newNodePtr.pointee.OldCoord = newObjDef.pointee.coord

    newNodePtr.pointee.GridX = Int32(newNodePtr.pointee.Coord.x) / Int32(GRID_SIZE) // set initial grid position
    newNodePtr.pointee.GridY = Int32(newNodePtr.pointee.Coord.y) / Int32(GRID_SIZE)
    newNodePtr.pointee.GridZ = Int32(newNodePtr.pointee.Coord.z) / Int32(GRID_SIZE)

    newNodePtr.pointee.StatusBits = flags

    newNodePtr.pointee.Rot.y = newObjDef.pointee.rot
    newNodePtr.pointee.Scale.x = newObjDef.pointee.scale
    newNodePtr.pointee.Scale.y = newObjDef.pointee.scale
    newNodePtr.pointee.Scale.z = newObjDef.pointee.scale

    // MAKE SURE SCALE != 0

    if newNodePtr.pointee.Scale.x == 0.0 { newNodePtr.pointee.Scale.x = 0.0001 }
    if newNodePtr.pointee.Scale.y == 0.0 { newNodePtr.pointee.Scale.y = 0.0001 }
    if newNodePtr.pointee.Scale.z == 0.0 { newNodePtr.pointee.Scale.z = 0.0001 }

    // INSERT NODE INTO LINKED LIST

    newNodePtr.setStatus(STATUS_BIT_DETACHED) // its not attached to linked list yet
    AttachObject(newNodePtr, 0)

    gEngine.objects.numObjectNodes += 1

    if gEngine.objects.numObjectNodes > gEngine.objects.numObjectNodesPeak {
        gEngine.objects.numObjectNodesPeak = gEngine.objects.numObjectNodes
        if gEngine.objects.numObjectNodesPeak > Int32(MAX_OBJECTS_COUNT) {
            SwLog("WARNING: New object count peak: \(gEngine.objects.numObjectNodesPeak). Consider raising MAX_OBJECTS!")
        }
    }

    // CLEANUP

    gEngine.objects.mostRecentlyAddedNode = newNodePtr // remember this
    return newNodePtr
}

// This is an ObjNode who's BaseGroup is a group, therefore these objects
// can be transformed (scale,rot,trans).
func MakeNewDisplayGroupObject(_ newObjDef: UnsafeMutablePointer<NewObjectDefinitionType>) -> UnsafeMutablePointer<ObjNode>? {
    newObjDef.pointee.genre = UInt8(DISPLAY_GROUP_GENRE)

    guard let newObj = MakeNewObject(newObjDef) else {
        SwFatal("MakeNewDisplayGroupObject: MakeNewObject failed!")
        return nil
    }

    // MAKE BASE GROUP & ADD GEOMETRY TO IT

    CreateBaseGroup(newObj) // create group object
    let group = newObjDef.pointee.group // get group #
    let type = newObjDef.pointee.type // get type #

    if Int32(type) >= GetNumObjectsInBG3DGroup(Int32(group)) { // see if illegal
        SwFatal("MakeNewDisplayGroupObject: type > gNumObjectsInGroupList[]! group=\(group) type=\(type)")
    }

    AttachGeometryToDisplayGroupObject(newObj, GetBG3DGroupObject(Int32(group), Int32(type)))

    // SET BOUNDING BOX & SPHERE

    newObj.pointee.LocalBBox = GetObjectGroupBBox(Int32(group), Int32(type)) // get this model's local bounding box

    newObj.pointee.BoundingSphereRadius = GetObjectGroupBSphere(newObj.pointee.Group, newObj.pointee.Type) * newObj.pointee.Scale.x

    return newObj
}

func CalcObjectRadiusFromBBox(_ theNode: UnsafeMutablePointer<ObjNode>) {
    var max = abs(theNode.pointee.LocalBBox.max.x) // get radius to right
    var n = abs(theNode.pointee.LocalBBox.min.x) // get radius to left
    if n > max { max = n }

    n = abs(theNode.pointee.LocalBBox.min.z) // get radius to back
    if n > max { max = n }
    n = abs(theNode.pointee.LocalBBox.max.z) // get radius to front
    if n > max { max = n }

    n = abs(theNode.pointee.LocalBBox.min.y) // get radius to bottom
    if n > max { max = n }
    n = abs(theNode.pointee.LocalBBox.max.y) // get radius to top
    if n > max { max = n }

    max *= 1.41 // multiply by sqrt(2) to expand radius to include worst-case corners
    // be better way to do this would have been to just calculate the max vertex distance, but that's slower to do real-time

    if theNode.pointee.Genre == UInt8(DISPLAY_GROUP_GENRE) {
        max *= theNode.pointee.Scale.x // scale to object's scale (skeleton's are already scaled)
    }

    theNode.pointee.BoundingSphereRadius = max
}

// If the ObjNode's "Type" field has changed, call this to dispose of
// the old BaseGroup and create a new one with the correct model attached.
func ResetDisplayGroupObject(_ theNode: UnsafeMutablePointer<ObjNode>) {
    DisposeObjectBaseGroup(theNode) // dispose of old group
    CreateBaseGroup(theNode) // create new group object

    if theNode.pointee.Type >= GetNumObjectsInBG3DGroup(theNode.pointee.Group) { // see if illegal
        SwFatal("ResetDisplayGroupObject: type > gNumObjectsInGroupList[]!")
    }

    AttachGeometryToDisplayGroupObject(theNode, GetBG3DGroupObject(theNode.pointee.Group, theNode.pointee.Type)) // attach geometry to group

    // SET BOUNDING BOX

    theNode.pointee.LocalBBox = GetObjectGroupBBox(theNode.pointee.Group, theNode.pointee.Type)

    // IF HAD WORLD DATA, NUKE IT

    let meshes = worldMeshesBase(theNode)
    let planeEQs = worldPlaneEQsBase(theNode)
    for i in 0..<Int(MAX_MESHES_IN_MODEL) { // delete the arrays since the sizes may have changed with new object
        if meshes[i].points != nil {
            SafeDisposePtr(meshes[i].points)
            meshes[i].points = nil
        }

        if planeEQs[i] != nil {
            SafeDisposePtr(planeEQs[i])
            planeEQs[i] = nil
        }
    }
    theNode.hasWorldPoints = false
}

// Attaches a geometry object to the BaseGroup object. MakeNewDisplayGroupObject must have already been
// called which made the group & transforms.
func AttachGeometryToDisplayGroupObject(_ theNode: UnsafeMutablePointer<ObjNode>, _ geometry: MetaObjectPtr?) {
    UnsafeMutableRawPointer(theNode.pointee.BaseGroup)?.append(geometry)
}

// The base group contains the base transform matrix plus any other objects you want to add into it.
// This routine creates the new group and then adds a transform matrix.
//
// The base is composed of BaseGroup & BaseTransformObject.
func CreateBaseGroup(_ theNode: UnsafeMutablePointer<ObjNode>) {
    var transMatrix = OGLMatrix4x4()
    var scaleMatrix = OGLMatrix4x4()
    var rotMatrix = OGLMatrix4x4()

    // CREATE THE BASE GROUP OBJECT

    let baseGroupRaw = MO_CreateNewObjectOfType(.group, 0, nil)
    guard let baseGroupRaw else {
        SwFatal("CreateBaseGroup: MO_CreateNewObjectOfType failed!")
        return
    }
    theNode.pointee.BaseGroup = baseGroupRaw.assumingMemoryBound(to: MOGroupObject.self)

    // SETUP BASE MATRIX

    if theNode.pointee.Scale.x == 0 || theNode.pointee.Scale.y == 0 || theNode.pointee.Scale.z == 0 {
        SwFatal("CreateBaseGroup: A scale component == 0")
    }

    scaleMatrix.setScale(theNode.pointee.Scale.x, theNode.pointee.Scale.y, // make scale matrix
                           theNode.pointee.Scale.z)

    rotMatrix.setRotateXYZ(theNode.pointee.Rot.x, theNode.pointee.Rot.y, // make rotation matrix
                                theNode.pointee.Rot.z)

    transMatrix.setTranslate(theNode.pointee.Coord.x, theNode.pointee.Coord.y, // make translate matrix
                               theNode.pointee.Coord.z)

    theNode.pointee.BaseTransformMatrix = scaleMatrix.multiplied(by: rotMatrix) // mult scale & rot matrices

    theNode.pointee.BaseTransformMatrix = theNode.pointee.BaseTransformMatrix.multiplied(by: transMatrix) // mult by trans matrix

    // CREATE A MATRIX XFORM

    let transObjectRaw = MO_CreateNewObjectOfType(.matrix, 0, &theNode.pointee.BaseTransformMatrix) // make matrix xform object
    guard let transObjectRaw else {
        SwFatal("CreateBaseGroup: MO_CreateNewObjectOfType/Matrix Failed!")
        return
    }
    let transObject = transObjectRaw.assumingMemoryBound(to: MOMatrixObject.self)

    UnsafeMutableRawPointer(theNode.pointee.BaseGroup)?.prepend(transObjectRaw) // add to base group
    theNode.pointee.BaseTransformObject = transObject // keep extra LEGAL ref (remember to dispose later)
}

// MARK: - Object processing

func MoveObjects() {
    // Deliberately NOT a `for node in allObjectNodes` walk (ObjNodeList.swift):
    // move callbacks can delete ARBITRARY nodes, which requires the
    // gEngine.objects.nextNode-global fixup that DetachObject performs when the pending
    // next node is the one being deleted. A snapshot iterator can't know
    // about that.
    if gEngine.objects.firstNodePtr == nil { // see if there are any objects
        return
    }

    var thisNodePtr = gEngine.objects.firstNodePtr

    while true {
        let node = thisNodePtr!

        // VERIFY NODE

        if node.pointee.CType == INVALID_NODE_FLAG {
            SwFatal("MoveObjects: CType == INVALID_NODE_FLAG")
        }

        gEngine.objects.currentNode = node // set current object node
        gEngine.objects.nextNode = node.pointee.NextNode // get next node now (cuz current node might get deleted)

        repeat { // goto-next simulator
            // SEE IF SHOULD SKIP WHEN PAUSED

            if gEngine.screens.gamePaused != 0 && !node.hasStatus(STATUS_BIT_MOVEINPAUSE) {
                break
            }

            // UPDATE SKELETON ANIMATION

            if node.pointee.Skeleton != nil {
                UpdateSkeletonAnimation(node)
            }

            // NEXT TRY TO MOVE IT

            if !node.hasStatus(STATUS_BIT_ONSPLINE) { // make sure don't call a move call if on spline
                if !node.hasStatus(STATUS_BIT_NOMOVE), let moveCall = node.pointee.MoveCall {
                    KeepOldCollisionBoxes(node) // keep old boxes & other stuff
                    moveCall(node) // call object's move routine
                }
            }

            // UPDATE SKELETON'S MESH

            if node.pointee.CType != INVALID_NODE_FLAG {
                if node.pointee.Skeleton != nil {
                    UpdateSkinnedGeometry(node)
                }
            }
        } while false

        thisNodePtr = gEngine.objects.nextNode // next node
        if thisNodePtr == nil { break }
    }

    // FLUSH THE DELETE QUEUE

    FlushObjectDeleteQueue()
}

func DrawObjects() {
    var noLighting = false
    var noZBuffer = false
    var noZWrites = false
    var texWrap = false
    var clipAlpha = false
    let playerNum = gEngine.view.currentSplitScreenPane // get the player # who's draw context is being drawn

    if gEngine.objects.firstNodePtr == nil { // see if there are any objects
        return
    }

    // FIRST DO OUR CULLING

    CullTestAllObjects()

    // Deliberately NOT a `for node in allObjectNodes` walk (ObjNodeList.swift):
    // this loop reads NextNode AFTER running each node's custom draw
    // function, preserving the legacy stop-on-delete semantics if a draw
    // callback ever deletes its own node (DetachObject nulls the deleted
    // node's NextNode).
    var theNode: UnsafeMutablePointer<ObjNode>? = gEngine.objects.firstNodePtr

    // GET CAMERA COORDS

    let cameraPlacementsBase = UnsafeMutableRawPointer(gEngine.game.viewInfoPtr!.pointer(to: \.cameraPlacement)!).assumingMemoryBound(to: OGLCameraPlacement.self)
    let cam = cameraPlacementsBase + Int(gEngine.view.currentSplitScreenPane)
    let cameraX = cam.pointee.cameraLocation.x
    let cameraZ = cam.pointee.cameraLocation.z

    let isOverlayPane = gEngine.view.currentSplitScreenPane == gEngine.player.numPlayers

    // MAIN NODE TASK LOOP

    while true {
        let node = theNode!

        drawNode: repeat { // goto-next simulator
            let statusBits = node.pointee.StatusBits // get obj's status bits

            if statusBits & ((UInt32(STATUS_BIT_ISCULLED1) << UInt32(gEngine.view.currentSplitScreenPane)) | UInt32(STATUS_BIT_HIDDEN)) != 0 { // see if is culled or hidden
                break drawNode
            }

            if statusBits & UInt32(STATUS_BIT_ONLYSHOWTHISPLAYER) != 0 { // see if only show for current player's draw context
                if node.pointee.PlayerNum != playerNum {
                    break drawNode
                }
            } else if isOverlayPane { // if drawing overlay pane, only look at nodes explicitly setting STATUS_BIT_ONLYSHOWTHISPLAYER
                break drawNode
            }

            if node.pointee.CType == INVALID_NODE_FLAG { // see if already deleted
                break drawNode
            }

            gEngine.metaObjects.globalTransparency = node.pointee.ColorFilter.a // get global transparency
            if gEngine.metaObjects.globalTransparency <= 0.0 { // see if invisible
                break drawNode
            }

            gEngine.metaObjects.globalColorFilter.r = node.pointee.ColorFilter.r // set color filter
            gEngine.metaObjects.globalColorFilter.g = node.pointee.ColorFilter.g
            gEngine.metaObjects.globalColorFilter.b = node.pointee.ColorFilter.b

            // CHECK AUTOFADE

            if gEngine.objects.autoFadeStartDist != 0.0 { // see if this level has autofade
                if statusBits & UInt32(STATUS_BIT_AUTOFADE) != 0 {
                    var dist = CalcQuickDistance(cameraX, cameraZ, node.pointee.Coord.x, node.pointee.Coord.z) // see if in fade zone

                    if node.pointee.Skeleton == nil { // if not a skeleton object...
                        if node.pointee.LocalBBox.isEmpty == 0 {
                            dist += (node.pointee.LocalBBox.max.x - node.pointee.LocalBBox.min.x) * 0.2 // adjust dist based on size of object in order to fade big objects closer
                        }
                    }

                    if dist >= gEngine.objects.autoFadeStartDist {
                        dist -= gEngine.objects.autoFadeStartDist // calc xparency %
                        dist *= gEngine.objects.autoFadeRangeFrac
                        if dist < 0.0 {
                            break drawNode
                        }

                        gEngine.metaObjects.globalTransparency -= dist
                        if gEngine.metaObjects.globalTransparency <= 0.0 {
                            node.pointee.StatusBits |= (UInt32(STATUS_BIT_ISCULLED1) << UInt32(gEngine.view.currentSplitScreenPane)) // set culled flag so that any related Sparkles wont be drawn either
                            break drawNode
                        }
                    }
                }
            }

            // CHECK BACKFACES

            if statusBits & UInt32(STATUS_BIT_DOUBLESIDED) != 0 {
                OGL_DisableCullFace()
            } else {
                OGL_EnableCullFace()
            }

            // CHECK NULL SHADER

            if statusBits & UInt32(STATUS_BIT_NOLIGHTING) != 0 {
                if !noLighting {
                    OGL_DisableLighting()
                    noLighting = true
                }
            } else if noLighting {
                noLighting = false
                OGL_EnableLighting()
            }

            // CHECK NO FOG

            if gEngine.game.viewInfoPtr!.pointee.useFog != 0 {
                if statusBits & UInt32(STATUS_BIT_NOFOG) != 0 {
                    OGL_DisableFog()
                } else {
                    OGL_EnableFog()
                }
            }

            // CHECK GLOW BLEND

            if statusBits & UInt32(STATUS_BIT_GLOW) != 0 {
                gEngine.metaObjects.globalMaterialFlags |= UInt32(BG3D_MATERIALFLAG_ALWAYSBLEND) // this will make sure blending is on for the glow
                OGL_BlendFunc(UInt32(GL_SRC_ALPHA), UInt32(GL_ONE))
            } else {
                gEngine.metaObjects.globalMaterialFlags &= ~UInt32(BG3D_MATERIALFLAG_ALWAYSBLEND)
                OGL_BlendFunc(UInt32(GL_SRC_ALPHA), UInt32(GL_ONE_MINUS_SRC_ALPHA))
            }

            // CHECK TEXTURE WRAP

            if statusBits & UInt32(STATUS_BIT_NOTEXTUREWRAP) != 0 {
                if !texWrap {
                    gEngine.metaObjects.globalMaterialFlags |= UInt32(BG3D_MATERIALFLAG_CLAMP_U) | UInt32(BG3D_MATERIALFLAG_CLAMP_V)
                    texWrap = true
                }
            } else if texWrap {
                texWrap = false
                gEngine.metaObjects.globalMaterialFlags &= ~(UInt32(BG3D_MATERIALFLAG_CLAMP_U) | UInt32(BG3D_MATERIALFLAG_CLAMP_V))
            }

            // CHECK ZWRITE

            if statusBits & UInt32(STATUS_BIT_NOZWRITES) != 0 {
                if !noZWrites {
                    OGL_SetDepthWrite(false)
                    noZWrites = true
                }
            } else if noZWrites {
                OGL_SetDepthWrite(true)
                noZWrites = false
            }

            // CHECK ZBUFFER

            if statusBits & UInt32(STATUS_BIT_NOZBUFFER) != 0 {
                if !noZBuffer {
                    OGL_DisableDepthTest()
                    noZBuffer = true
                }
            } else if noZBuffer {
                noZBuffer = false
                OGL_EnableDepthTest()
            }

            // CHECK EDGE ALPHA CLIPPING

            if (statusBits & UInt32(STATUS_BIT_CLIPALPHA6)) != 0 && gEngine.metaObjects.globalTransparency == 1.0 {
                if !clipAlpha {
                    gEngine.renderer.setAlphaClipping(trimLowAlpha: true)
                    clipAlpha = true
                }
            } else if clipAlpha {
                clipAlpha = false
                gEngine.renderer.setAlphaClipping(trimLowAlpha: false)
            }

            // AIM AT CAMERA

            if statusBits & UInt32(STATUS_BIT_AIMATCAMERA) != 0 {
                node.pointee.Rot.y = Float(PI) + CalcYAngleFromPointToPoint(node.pointee.Rot.y,
                                                                             node.pointee.Coord.x, node.pointee.Coord.z,
                                                                             cameraX, cameraZ)

                UpdateObjectTransforms(node)
            }

            // SHOW COLLISION BOXES

            if gEngine.game.debugMode == 2 {
                DrawCollisionBoxes(node, 0)
                // DrawBoundingSpheres(node)
                // DrawBoundingBoxes(node)
            }

            // THE FOLLOWING IS A HACK
            // which fixes a rare bug that some people were reporting where objects would fade in/out randomly.
            // It appears that this might be a bug in certain older hardware where glColor gets messed up.
            // Beta testers have reported that the following fixes it - it's basically a forced reset of the glColor mode.
            // We cannot call our OGL_SetColor4f() function since it thinks the color is alredy 1,1,1,1, so we just force it here.

            gEngine.renderer.setColor4f(1, 1, 1, 1)
            gEngine.view.stateColor.r = 1
            gEngine.view.stateColor.g = 1
            gEngine.view.stateColor.b = 1
            gEngine.view.stateColor.a = 1

            // SEE IF DO U/V TRANSFORM

            if statusBits & UInt32(STATUS_BIT_UVTRANSFORM) != 0 {
                gEngine.renderer.matrixMode(.texture) // set texture matrix
                gEngine.renderer.translate(node.pointee.TextureTransformU, node.pointee.TextureTransformV, 0)
                gEngine.renderer.matrixMode(.modelview)
            }

            // SUBMIT THE GEOMETRY

            if noLighting || node.pointee.Scale.y == 1.0 { // if scale == 1 or no lighting, then dont need to normalize vectors
                OGL_SetNormalizeNormals(false)
            } else {
                OGL_SetNormalizeNormals(true)
            }

            if let customDraw = node.pointee.CustomDrawFunction { // if has custom draw function, then override and use that
                customDraw(node)
            } else {
                switch Int32(node.pointee.Genre) {
                case Int32(EVENT_GENRE):
                    break

                case Int32(SKELETON_GENRE):
                    DrawSkeleton(node)

                case Int32(DISPLAY_GROUP_GENRE), Int32(QUADMESH_GENRE):
                    if let baseGroup = node.pointee.BaseGroup {
                        UnsafeMutableRawPointer(baseGroup).draw()
                    }

                case Int32(SPRITE_GENRE):
                    if let spriteMO = node.pointee.SpriteMO {
                        OGL_PushState() // keep state

                        SetInfobarSpriteState(node.pointee.AnaglyphZ, 1)

                        spriteMO.pointee.objectData.coord = node.pointee.Coord // update Meta Object's coord info
                        spriteMO.pointee.objectData.scaleX = node.pointee.Scale.x
                        spriteMO.pointee.objectData.scaleY = node.pointee.Scale.y
                        spriteMO.pointee.objectData.rot = node.pointee.Rot.y

                        UnsafeMutableRawPointer(spriteMO).draw()
                        OGL_PopState() // restore state
                    }

                case Int32(TEXTMESH_GENRE):
                    if let baseGroup = node.pointee.BaseGroup {
                        OGL_PushState()
                        SetInfobarSpriteState(node.pointee.AnaglyphZ, 1)

                        UnsafeMutableRawPointer(baseGroup).draw()

                        if gEngine.game.debugMode >= 2 {
                            TextMesh_DrawExtents(node)
                        }

                        OGL_PopState()
                    }

                case Int32(CUSTOM_GENRE):
                    break // CustomDrawFunction is nil here (handled above), matches original fallthrough

                default:
                    break
                }
            }

            // SEE IF END UV TRANSFORM

            if statusBits & UInt32(STATUS_BIT_UVTRANSFORM) != 0 {
                gEngine.renderer.matrixMode(.texture) // set texture matrix
                gEngine.renderer.loadIdentity()
                gEngine.renderer.matrixMode(.modelview)
            }
        } while false

        // NEXT NODE
        theNode = node.pointee.NextNode
        if theNode == nil { break }
    }

    // RESET SETTINGS TO DEFAULT

    if noZBuffer {
        OGL_EnableDepthTest()
    }

    if noZWrites {
        OGL_SetDepthWrite(true)
    }

    OGL_EnableCullFace()
    OGL_BlendFunc(UInt32(GL_SRC_ALPHA), UInt32(GL_ONE_MINUS_SRC_ALPHA))

    if texWrap {
        gEngine.metaObjects.globalMaterialFlags &= ~(UInt32(BG3D_MATERIALFLAG_CLAMP_U) | UInt32(BG3D_MATERIALFLAG_CLAMP_V))
    }

    if clipAlpha {
        gEngine.renderer.setAlphaClipping(trimLowAlpha: false)
    }

    gEngine.metaObjects.globalTransparency = 1.0 // reset this in case it has changed
    gEngine.metaObjects.globalColorFilter.r = 1.0
    gEngine.metaObjects.globalColorFilter.g = 1.0
    gEngine.metaObjects.globalColorFilter.b = 1.0
    gEngine.metaObjects.globalMaterialFlags = 0

    OGL_SetNormalizeNormals(true)
}

private func DrawCollisionBoxes(_ theNode: UnsafeMutablePointer<ObjNode>!, _ old: UInt8) {
    // SET LINE MATERIAL

    OGL_DisableTexture2D()

    // SCAN EACH COLLISION BOX

    let n = theNode.pointee.NumCollisionBoxes // get # collision boxes
    let c = collisionBoxesBase(theNode) // pt to array

    for i in 0..<Int(n) {
        // GET BOX PARAMS

        var left: Float, right: Float, top: Float, bottom: Float, front: Float, back: Float
        if old != 0 {
            left = c[i].oldLeft
            right = c[i].oldRight
            top = c[i].oldTop
            bottom = c[i].oldBottom
            front = c[i].oldFront
            back = c[i].oldBack
        } else {
            left = c[i].left
            right = c[i].right
            top = c[i].top
            bottom = c[i].bottom
            front = c[i].front
            back = c[i].back
        }

        // DRAW TOP

        gEngine.renderer.beginImmediate(.lineLoop)
        OGL_SetColor4f(1, 0, 0, 1)
        gEngine.renderer.vertex3f(left, top, back)
        OGL_SetColor4f(1, 1, 0, 1)
        gEngine.renderer.vertex3f(left, top, front)
        gEngine.renderer.vertex3f(right, top, front)
        OGL_SetColor4f(1, 0, 0, 1)
        gEngine.renderer.vertex3f(right, top, back)
        gEngine.renderer.endImmediate()

        // DRAW BOTTOM

        gEngine.renderer.beginImmediate(.lineLoop)
        OGL_SetColor4f(1, 0, 0, 1)
        gEngine.renderer.vertex3f(left, bottom, back)
        OGL_SetColor4f(1, 1, 0, 1)
        gEngine.renderer.vertex3f(left, bottom, front)
        gEngine.renderer.vertex3f(right, bottom, front)
        OGL_SetColor4f(1, 0, 0, 1)
        gEngine.renderer.vertex3f(right, bottom, back)
        gEngine.renderer.endImmediate()

        // DRAW LEFT

        gEngine.renderer.beginImmediate(.lineLoop)
        OGL_SetColor4f(1, 0, 0, 1)
        gEngine.renderer.vertex3f(left, top, back)
        OGL_SetColor4f(1, 0, 0, 1)
        gEngine.renderer.vertex3f(left, bottom, back)
        OGL_SetColor4f(1, 1, 0, 1)
        gEngine.renderer.vertex3f(left, bottom, front)
        gEngine.renderer.vertex3f(left, top, front)
        gEngine.renderer.endImmediate()

        // DRAW RIGHT

        gEngine.renderer.beginImmediate(.lineLoop)
        OGL_SetColor4f(1, 0, 0, 1)
        gEngine.renderer.vertex3f(right, top, back)
        gEngine.renderer.vertex3f(right, bottom, back)
        OGL_SetColor4f(1, 1, 0, 1)
        gEngine.renderer.vertex3f(right, bottom, front)
        gEngine.renderer.vertex3f(right, top, front)
        gEngine.renderer.endImmediate()
    }

    OGL_SetColor4f(1, 1, 1, 1)
}

private func DrawBoundingBoxes(_ theNode: UnsafeMutablePointer<ObjNode>!) {
    var left: Float, right: Float, top: Float, bottom: Float, front: Float, back: Float

    // SET LINE MATERIAL

    OGL_DisableTexture2D()

    // TRANSFORM BBOX TO WORLD

    if theNode.pointee.Genre == UInt8(SKELETON_GENRE) { // skeletons are already oriented, just need translation
        left = theNode.pointee.LocalBBox.min.x + theNode.pointee.Coord.x
        right = theNode.pointee.LocalBBox.max.x + theNode.pointee.Coord.x
        top = theNode.pointee.LocalBBox.max.y + theNode.pointee.Coord.y
        bottom = theNode.pointee.LocalBBox.min.y + theNode.pointee.Coord.y
        front = theNode.pointee.LocalBBox.max.z + theNode.pointee.Coord.z
        back = theNode.pointee.LocalBBox.min.z + theNode.pointee.Coord.z
    } else { // non-skeletons need full transform
        var corners: InlineArray<8, OGLPoint3D> = InlineArray(repeating: OGLPoint3D(x: 0, y: 0, z: 0))

        corners[0].x = theNode.pointee.LocalBBox.min.x // top far left
        corners[0].y = theNode.pointee.LocalBBox.max.y
        corners[0].z = theNode.pointee.LocalBBox.min.z

        corners[1].x = theNode.pointee.LocalBBox.max.x // top far right
        corners[1].y = theNode.pointee.LocalBBox.max.y
        corners[1].z = theNode.pointee.LocalBBox.min.z

        corners[2].x = theNode.pointee.LocalBBox.max.x // top near right
        corners[2].y = theNode.pointee.LocalBBox.max.y
        corners[2].z = theNode.pointee.LocalBBox.max.z

        corners[3].x = theNode.pointee.LocalBBox.min.x // top near left
        corners[3].y = theNode.pointee.LocalBBox.max.y
        corners[3].z = theNode.pointee.LocalBBox.max.z

        corners[4].x = theNode.pointee.LocalBBox.min.x // bottom far left
        corners[4].y = theNode.pointee.LocalBBox.min.y
        corners[4].z = theNode.pointee.LocalBBox.min.z

        corners[5].x = theNode.pointee.LocalBBox.max.x // bottom far right
        corners[5].y = theNode.pointee.LocalBBox.min.y
        corners[5].z = theNode.pointee.LocalBBox.min.z

        corners[6].x = theNode.pointee.LocalBBox.max.x // bottom near right
        corners[6].y = theNode.pointee.LocalBBox.min.y
        corners[6].z = theNode.pointee.LocalBBox.max.z

        corners[7].x = theNode.pointee.LocalBBox.min.x // bottom near left
        corners[7].y = theNode.pointee.LocalBBox.min.y
        corners[7].z = theNode.pointee.LocalBBox.max.z

        for i in 0..<8 {
            corners[i] = corners[i].transformed(by: theNode.pointee.BaseTransformMatrix)
        }

        // FIND NEW BOUNDS

        left = corners[0].x
        for i in 1..<8 { if corners[i].x < left { left = corners[i].x } }

        right = corners[0].x
        for i in 1..<8 { if corners[i].x > right { right = corners[i].x } }

        bottom = corners[0].y
        for i in 1..<8 { if corners[i].y < bottom { bottom = corners[i].y } }

        top = corners[0].y
        for i in 1..<8 { if corners[i].y > top { top = corners[i].y } }

        back = corners[0].z
        for i in 1..<8 { if corners[i].z < back { back = corners[i].z } }

        front = corners[0].z
        for i in 1..<8 { if corners[i].z > front { front = corners[i].z } }
    }

    // DRAW TOP

    gEngine.renderer.beginImmediate(.lineLoop)
    OGL_SetColor4f(1, 0, 0, 1)
    gEngine.renderer.vertex3f(left, top, back)
    OGL_SetColor4f(1, 1, 0, 1)
    gEngine.renderer.vertex3f(left, top, front)
    gEngine.renderer.vertex3f(right, top, front)
    OGL_SetColor4f(1, 0, 0, 1)
    gEngine.renderer.vertex3f(right, top, back)
    gEngine.renderer.endImmediate()

    // DRAW BOTTOM

    gEngine.renderer.beginImmediate(.lineLoop)
    OGL_SetColor4f(1, 0, 0, 1)
    gEngine.renderer.vertex3f(left, bottom, back)
    OGL_SetColor4f(1, 1, 0, 1)
    gEngine.renderer.vertex3f(left, bottom, front)
    gEngine.renderer.vertex3f(right, bottom, front)
    OGL_SetColor4f(1, 0, 0, 1)
    gEngine.renderer.vertex3f(right, bottom, back)
    gEngine.renderer.endImmediate()

    // DRAW LEFT

    gEngine.renderer.beginImmediate(.lineLoop)
    OGL_SetColor4f(1, 0, 0, 1)
    gEngine.renderer.vertex3f(left, top, back)
    OGL_SetColor4f(1, 0, 0, 1)
    gEngine.renderer.vertex3f(left, bottom, back)
    OGL_SetColor4f(1, 1, 0, 1)
    gEngine.renderer.vertex3f(left, bottom, front)
    gEngine.renderer.vertex3f(left, top, front)
    gEngine.renderer.endImmediate()

    // DRAW RIGHT

    gEngine.renderer.beginImmediate(.lineLoop)
    OGL_SetColor4f(1, 0, 0, 1)
    gEngine.renderer.vertex3f(right, top, back)
    gEngine.renderer.vertex3f(right, bottom, back)
    OGL_SetColor4f(1, 1, 0, 1)
    gEngine.renderer.vertex3f(right, bottom, front)
    gEngine.renderer.vertex3f(right, top, front)
    gEngine.renderer.endImmediate()
}

private func DrawBoundingSpheres(_ theNode: UnsafeMutablePointer<ObjNode>!) {
    // SET LINE MATERIAL

    OGL_DisableTexture2D()

    gEngine.renderer.beginImmediate(.lines)
    gEngine.renderer.vertex3f(theNode.pointee.Coord.x - theNode.pointee.BoundingSphereRadius, theNode.pointee.Coord.y, theNode.pointee.Coord.z)
    gEngine.renderer.vertex3f(theNode.pointee.Coord.x + theNode.pointee.BoundingSphereRadius, theNode.pointee.Coord.y, theNode.pointee.Coord.z)
    gEngine.renderer.endImmediate()

    gEngine.renderer.beginImmediate(.lines)
    gEngine.renderer.vertex3f(theNode.pointee.Coord.x, theNode.pointee.Coord.y, theNode.pointee.Coord.z - theNode.pointee.BoundingSphereRadius)
    gEngine.renderer.vertex3f(theNode.pointee.Coord.x, theNode.pointee.Coord.y, theNode.pointee.Coord.z + theNode.pointee.BoundingSphereRadius)
    gEngine.renderer.endImmediate()

    gEngine.renderer.beginImmediate(.lines)
    gEngine.renderer.vertex3f(theNode.pointee.Coord.x, theNode.pointee.Coord.y + theNode.pointee.BoundingSphereRadius, theNode.pointee.Coord.z)
    gEngine.renderer.vertex3f(theNode.pointee.Coord.x, theNode.pointee.Coord.y - theNode.pointee.BoundingSphereRadius, theNode.pointee.Coord.z)
    gEngine.renderer.endImmediate()
}

func MoveStaticObject(_ theNode: UnsafeMutablePointer<ObjNode>?) {
    guard let theNode else { return }
    if TrackTerrainItem(theNode) != 0 { // just check to see if it's gone
        DeleteObject(theNode)
        return
    }

    UpdateShadow(theNode) // prime it
}

// Keeps object conformed to terrain curves
func MoveStaticObject2(_ theNode: UnsafeMutablePointer<ObjNode>?) {
    guard let theNode else { return }
    if TrackTerrainItem(theNode) != 0 { // just check to see if it's gone
        DeleteObject(theNode)
        return
    }

    RotateOnTerrain(theNode, 0, nil) // set transform matrix
    SetObjectTransformMatrix(theNode)

    CalcObjectBoxFromNode(theNode)

    UpdateShadow(theNode) // prime it
}

// Keeps at current terrain height
func MoveStaticObject3(_ theNode: UnsafeMutablePointer<ObjNode>?) {
    guard let theNode else { return }
    if TrackTerrainItem(theNode) != 0 { // just check to see if it's gone
        DeleteObject(theNode)
        return
    }

    theNode.pointee.Coord.y = GetTerrainY(theNode.pointee.Coord.x, theNode.pointee.Coord.z) - (theNode.pointee.LocalBBox.min.y * theNode.pointee.Scale.y)

    UpdateObjectTransforms(theNode)

    if theNode.pointee.NumCollisionBoxes > 0 {
        CalcObjectBoxFromNode(theNode)
    }

    UpdateShadow(theNode) // prime it
}

// MARK: - Object deleting

func DeleteAllObjects() {
    while gEngine.objects.firstNodePtr != nil {
        DeleteObject(gEngine.objects.firstNodePtr)
    }

    FlushObjectDeleteQueue()
}

func DeleteObject(_ theNode: UnsafeMutablePointer<ObjNode>?) {
    guard let theNode else { // see if passed a bogus node
        return
    }

    if theNode.pointee.CType == INVALID_NODE_FLAG { // see if already deleted
        return
    }

    // CALL CUSTOM DESTRUCTOR

    if let destructor = theNode.pointee.Destructor {
        destructor(theNode)
    }

    // RECURSIVE DELETE OF CHAIN NODE & SHADOW NODE
    //
    // should do these first so that base node will have appropriate nextnode ptr
    // since it's going to be used next pass thru the moveobjects loop. This
    // assumes that all chained nodes are later in list.

    if theNode.pointee.ChainNode != nil {
        DeleteObject(theNode.pointee.ChainNode)
    }

    if theNode.pointee.ShadowNode != nil {
        DeleteObject(theNode.pointee.ShadowNode)
    }

    // SEE IF NEED TO FREE UP SPECIAL MEMORY

    switch Int32(theNode.pointee.Genre) {
    case Int32(SKELETON_GENRE):
        FreeSkeletonBaseData(theNode.pointee.Skeleton, Int16(theNode.pointee.Type)) // purge all alloced memory for skeleton data
        theNode.pointee.Skeleton = nil

    case Int32(SPRITE_GENRE):
        UnsafeMutableRawPointer(theNode.pointee.SpriteMO)?.release() // dispose reference to sprite meta object
        theNode.pointee.SpriteMO = nil

    default:
        break
    }

    let sparkles = sparklesBase(theNode)
    for i in 0..<Int(MAX_NODE_SPARKLES) { // free sparkles
        if sparkles[i] != -1 {
            DeleteSparkle(sparkles[i])
            sparkles[i] = -1
        }
    }

    // SEE IF STOP SOUND CHANNEL

    StopAChannel(&theNode.pointee.EffectChannel)

    // SEE IF NEED TO DEREFERENCE A BG3D OBJECT

    DisposeObjectBaseGroup(theNode)

    let meshes = worldMeshesBase(theNode)
    let planeEQs = worldPlaneEQsBase(theNode)
    for i in 0..<Int(MAX_MESHES_IN_MODEL) { // delete world point arrays
        if meshes[i].points != nil {
            SafeDisposePtr(meshes[i].points)
            meshes[i].points = nil
        }

        if planeEQs[i] != nil {
            SafeDisposePtr(planeEQs[i])
            planeEQs[i] = nil
        }
    }
    theNode.hasWorldPoints = false

    // REMOVE NODE FROM LINKED LIST

    DetachObject(theNode, 0)

    // SEE IF MARK AS NOT-IN-USE IN ITEM LIST

    if let terrainItemPtr = theNode.pointee.TerrainItemPtr {
        terrainItemPtr.pointee.flags &= ~UInt16(ITEM_FLAGS_INUSE) // clear the "in use" flag
    }

    // OR, IF ITS A SPLINE ITEM, THEN UPDATE SPLINE OBJECT LIST

    if theNode.hasStatus(STATUS_BIT_ONSPLINE) {
        _ = RemoveFromSplineObjectList(theNode)
    }

    // DELETE THE NODE BY ADDING TO DELETE QUEUE

    theNode.pointee.CType = INVALID_NODE_FLAG // INVALID_NODE_FLAG indicates its deleted
    theNode.pointee.Cookie = 0

    gEngine.objects.objectDeleteQueueStorage[Int(gEngine.objects.numObjsInDeleteQueue)] = theNode
    gEngine.objects.numObjsInDeleteQueue += 1
    if gEngine.objects.numObjsInDeleteQueue >= Int32(OBJ_DEL_Q_SIZE_COUNT) {
        FlushObjectDeleteQueue()
    }
}

// Simply detaches the objnode from the linked list, patches the links
// and keeps the original objnode intact.
func DetachObject(_ theNode: UnsafeMutablePointer<ObjNode>?, _ subrecurse: UInt8) {
    guard let theNode else {
        return
    }

    if theNode.hasStatus(STATUS_BIT_DETACHED) { // make sure not already detached
        return
    }

    if theNode == gEngine.objects.nextNode { // if its the next node to be moved, then fix things
        gEngine.objects.nextNode = theNode.pointee.NextNode
    }

    if theNode.pointee.PrevNode == nil { // special case 1st node
        gEngine.objects.firstNodePtr = theNode.pointee.NextNode
        if gEngine.objects.firstNodePtr != nil {
            gEngine.objects.firstNodePtr!.pointee.PrevNode = nil
        }
    } else if theNode.pointee.NextNode == nil { // special case last node
        theNode.pointee.PrevNode!.pointee.NextNode = nil
    } else { // generic middle deletion
        theNode.pointee.PrevNode!.pointee.NextNode = theNode.pointee.NextNode
        theNode.pointee.NextNode!.pointee.PrevNode = theNode.pointee.PrevNode
    }

    theNode.pointee.PrevNode = nil // seal links on original node
    theNode.pointee.NextNode = nil

    theNode.setStatus(STATUS_BIT_DETACHED)

    // SUBRECURSE CHAINS & SHADOW

    if subrecurse != 0 {
        if theNode.pointee.ChainNode != nil {
            DetachObject(theNode.pointee.ChainNode, subrecurse)
        }

        if theNode.pointee.ShadowNode != nil {
            DetachObject(theNode.pointee.ShadowNode, subrecurse)
        }
    }
}

func AttachObject(_ theNode: UnsafeMutablePointer<ObjNode>?, _ recurse: UInt8) {
    guard let theNode else {
        return
    }

    if !theNode.hasStatus(STATUS_BIT_DETACHED) { // see if already attached
        return
    }

    let slot = theNode.pointee.Slot

    if gEngine.objects.firstNodePtr == nil { // special case only entry
        gEngine.objects.firstNodePtr = theNode
        theNode.pointee.PrevNode = nil
        theNode.pointee.NextNode = nil
    } else if slot < gEngine.objects.firstNodePtr!.pointee.Slot { // INSERT AS FIRST NODE
        theNode.pointee.PrevNode = nil // no prev
        theNode.pointee.NextNode = gEngine.objects.firstNodePtr // next pts to old 1st
        gEngine.objects.firstNodePtr!.pointee.PrevNode = theNode // old pts to new 1st
        gEngine.objects.firstNodePtr = theNode
    } else { // SCAN FOR INSERTION PLACE
        var reNodePtr: UnsafeMutablePointer<ObjNode>? = gEngine.objects.firstNodePtr
        var scanNodePtr: UnsafeMutablePointer<ObjNode>? = gEngine.objects.firstNodePtr!.pointee.NextNode // start scanning for insertion slot on 2nd node

        var inserted = false
        while let scan = scanNodePtr {
            if slot < scan.pointee.Slot { // INSERT IN MIDDLE HERE
                theNode.pointee.NextNode = scan
                theNode.pointee.PrevNode = reNodePtr
                reNodePtr!.pointee.NextNode = theNode
                scan.pointee.PrevNode = theNode
                inserted = true
                break
            }
            reNodePtr = scan
            scanNodePtr = scan.pointee.NextNode // try next node
        }

        if !inserted {
            theNode.pointee.NextNode = nil // TAG TO END
            theNode.pointee.PrevNode = reNodePtr
            reNodePtr!.pointee.NextNode = theNode
        }
    }

    theNode.clearStatus(STATUS_BIT_DETACHED)

    // SUBRECURSE CHAINS & SHADOW

    if recurse != 0 {
        if theNode.pointee.ChainNode != nil {
            AttachObject(theNode.pointee.ChainNode, recurse)
        }

        if theNode.pointee.ShadowNode != nil {
            AttachObject(theNode.pointee.ShadowNode, recurse)
        }
    }
}

private func FlushObjectDeleteQueue() {
    let num = gEngine.objects.numObjsInDeleteQueue

    gEngine.objects.numObjectNodes -= num

    for i in 0..<Int(num) {
        let node = gEngine.objects.objectDeleteQueueStorage[i]!
        if node.pointee.objectNum == -1 { // see if dispose by freeing memory...
            SafeDisposePtr(node)
        } else {
            node.isUsed = false //.. or just return to gObjectList array
        }
    }

    gEngine.objects.numObjsInDeleteQueue = 0
}

func DisposeObjectBaseGroup(_ theNode: UnsafeMutablePointer<ObjNode>) {
    if theNode.pointee.BaseGroup != nil {
        UnsafeMutableRawPointer(theNode.pointee.BaseGroup)?.release()

        theNode.pointee.BaseGroup = nil
    }

    if theNode.pointee.BaseTransformObject != nil { // also nuke extra ref to transform object
        UnsafeMutableRawPointer(theNode.pointee.BaseTransformObject)?.release()
        theNode.pointee.BaseTransformObject = nil
    }
}

// MARK: - Object information

func GetObjectInfo(_ theNode: UnsafeMutablePointer<ObjNode>) {
    gEngine.objects.coord = theNode.pointee.Coord
    gEngine.objects.delta = theNode.pointee.Delta
}

func UpdateObject(_ theNode: UnsafeMutablePointer<ObjNode>) {
    if theNode.pointee.CType == INVALID_NODE_FLAG { // see if already deleted
        return
    }

    theNode.pointee.Coord = gEngine.objects.coord
    theNode.pointee.Delta = gEngine.objects.delta
    UpdateObjectTransforms(theNode)

    FastNormalizeVector(gEngine.objects.delta.x, gEngine.objects.delta.y, gEngine.objects.delta.z, &theNode.pointee.MotionVector)

    CalcObjectBoxFromNode(theNode)

    // UPDATE ANY SHADOWS

    UpdateShadow(theNode)
}

// This updates the skeleton object's base translate & rotate transforms
func UpdateObjectTransforms(_ theNode: UnsafeMutablePointer<ObjNode>) {
    var m = OGLMatrix4x4()
    var m2: OGLMatrix4x4
    var mx = OGLMatrix4x4(), my = OGLMatrix4x4(), mz = OGLMatrix4x4(), mxz = OGLMatrix4x4()

    if theNode.pointee.CType == INVALID_NODE_FLAG { // see if already deleted
        return
    }

    // SET SCALE MATRIX

    m.setScale(theNode.pointee.Scale.x, theNode.pointee.Scale.y, theNode.pointee.Scale.z)

    // NOW ROTATE & TRANSLATE IT

    let bits = theNode.pointee.StatusBits

    // USE ALIGNMENT MATRIX

    if bits & UInt32(STATUS_BIT_USEALIGNMENTMATRIX) != 0 {
        m2 = theNode.pointee.AlignmentMatrix
    } else if bits & UInt32(STATUS_BIT_ROTXZY) != 0 { // DO XZY ROTATION
        mx.setRotateX(theNode.pointee.Rot.x)
        my.setRotateY(theNode.pointee.Rot.y)
        mz.setRotateZ(theNode.pointee.Rot.z)

        mxz = mx.multiplied(by: mz)
        m2 = OGLMatrix4x4()
        m2 = mxz.multiplied(by: my)
    } else if bits & UInt32(STATUS_BIT_ROTYZX) != 0 { // DO YZX ROTATION
        mx.setRotateX(theNode.pointee.Rot.x)
        my.setRotateY(theNode.pointee.Rot.y)
        mz.setRotateZ(theNode.pointee.Rot.z)

        mxz = my.multiplied(by: mz)
        m2 = OGLMatrix4x4()
        m2 = mxz.multiplied(by: mx)
    } else if bits & UInt32(STATUS_BIT_ROTZXY) != 0 { // DO ZXY ROTATION
        mx.setRotateX(theNode.pointee.Rot.x)
        my.setRotateY(theNode.pointee.Rot.y)
        mz.setRotateZ(theNode.pointee.Rot.z)

        mxz = mz.multiplied(by: mx)
        m2 = OGLMatrix4x4()
        m2 = mxz.multiplied(by: my)
    } else { // STANDARD XYZ ROTATION
        m2 = OGLMatrix4x4()
        m2.setRotateXYZ(theNode.pointee.Rot.x, theNode.pointee.Rot.y, theNode.pointee.Rot.z)
    }

    setMatValue(&m2, M03, theNode.pointee.Coord.x)
    setMatValue(&m2, M13, theNode.pointee.Coord.y)
    setMatValue(&m2, M23, theNode.pointee.Coord.z)

    theNode.pointee.BaseTransformMatrix = m.multiplied(by: m2)

    // UPDATE TRANSFORM OBJECT

    SetObjectTransformMatrix(theNode)
}

func SetObjectGridLocation(_ theNode: UnsafeMutablePointer<ObjNode>) {
    theNode.pointee.GridX = Int32(theNode.pointee.Coord.x) / Int32(GRID_SIZE) // n unit sized grid
    theNode.pointee.GridY = Int32(theNode.pointee.Coord.y) / Int32(GRID_SIZE)
    theNode.pointee.GridZ = Int32(theNode.pointee.Coord.z) / Int32(GRID_SIZE)
}

// This call simply resets the base transform object so that it uses the latest
// base transform matrix
func SetObjectTransformMatrix(_ theNode: UnsafeMutablePointer<ObjNode>) {
    let mo = theNode.pointee.BaseTransformObject

    if theNode.pointee.CType == INVALID_NODE_FLAG { // see if invalid
        return
    }

    if let mo { // see if this has a trans obj
        mo.pointee.matrix = theNode.pointee.BaseTransformMatrix
    }

    theNode.hasWorldPoints = false // these need to be recalculated now that we've updated the matrix

    SetObjectGridLocation(theNode)
}

func SetObjectVisible(_ theNode: UnsafeMutablePointer<ObjNode>, _ visible: UInt8) -> UInt8 {
    if visible != 0 {
        theNode.clearStatus(STATUS_BIT_HIDDEN)
    } else {
        theNode.setStatus(STATUS_BIT_HIDDEN)
    }

    return visible
}

// MARK: - Advanced node chaining

func GetNodeChainLength(_ node: UnsafeMutablePointer<ObjNode>?) -> Int32 {
    var n = node
    var length: Int32 = 0
    while length <= 0x7FFF {
        if n == nil { return length }
        n = n!.pointee.ChainNode
        length += 1
    }

    SwFatal("Circular chain?")
    return -1
}

func GetNthChainedNode(_ start: UnsafeMutablePointer<ObjNode>?, _ targetIndex: Int32, _ outPrevNode: UnsafeMutablePointer<UnsafeMutablePointer<ObjNode>?>?) -> UnsafeMutablePointer<ObjNode>? {
    var pNode: UnsafeMutablePointer<ObjNode>?
    var node = start

    if start != nil {
        var currentIndex: Int32 = 0
        while node != nil && currentIndex < targetIndex {
            pNode = node
            node = pNode!.pointee.ChainNode

            if let pNode, let node {
                SwGameAssertMessage(pNode.pointee.Slot <= node.pointee.Slot, "the game assumes that chained nodes are sorted after their parent")
            }
            currentIndex += 1
        }

        if currentIndex != targetIndex {
            node = nil
        }
    }

    if let outPrevNode {
        outPrevNode.pointee = pNode
    }

    return node
}

func GetChainTailNode(_ start: UnsafeMutablePointer<ObjNode>?) -> UnsafeMutablePointer<ObjNode>? {
    var pNode: UnsafeMutablePointer<ObjNode>?
    var node = start

    while let n = node {
        pNode = n
        node = n.pointee.ChainNode

        if let node {
            SwGameAssert(node.pointee.Slot > n.pointee.Slot)
        }
    }

    return pNode
}

func AppendNodeToChain(_ first: UnsafeMutablePointer<ObjNode>, _ newTail: UnsafeMutablePointer<ObjNode>) {
    let oldTail = GetChainTailNode(first)!
    oldTail.pointee.ChainNode = newTail

    newTail.pointee.ChainHead = first.pointee.ChainHead
    if newTail.pointee.ChainHead == nil {
        newTail.pointee.ChainHead = first
    }

    SwGameAssert(newTail.pointee.Slot > oldTail.pointee.Slot)
}

func UnchainNode(_ theNode: UnsafeMutablePointer<ObjNode>?) {
    guard let theNode else {
        return
    }

    let chainHead = theNode.pointee.ChainHead
    let chainNext = theNode.pointee.ChainNode

    var node = chainHead
    while let n = node {
        defer { node = n.pointee.ChainNode }

        if n == theNode {
            continue
        }

        if n.pointee.ChainNode == theNode {
            n.pointee.ChainNode = chainNext
        }

        if n.pointee.ChainHead == theNode { // rewrite ChainHead
            n.pointee.ChainHead = chainNext
        }
    }
}

// MARK: - Overlay pane

func SendNodeToOverlayPane(_ theNode: UnsafeMutablePointer<ObjNode>) {
    theNode.setStatus(STATUS_BIT_ONLYSHOWTHISPLAYER)
    theNode.pointee.PlayerNum = gEngine.player.numPlayers
}
