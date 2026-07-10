// SplineItems.swift - Port of SplineItems.c to Swift

// SplinePointType, SplineDefType, and File_SplineDefType are native Swift
// structs (converted from structs.h 2026-07-07) - nothing in any .c file
// touches them. SplineItemType stays C-imported (pinned via ObjNode's
// SplineItemPtr field), so SplineDefType's itemList field below still
// refers to the ClangImporter-provided type.

struct SplinePointType {
    var x: Float = 0
    var z: Float = 0
}

struct SplineDefType {
    var numNubs: Int16 = 0
    var nubList: UnsafeMutablePointer<SplinePointType>!
    var numPoints: Int32 = 0
    var pointList: UnsafeMutablePointer<SplinePointType>!
    var numItems: Int16 = 0
    var itemList: UnsafeMutablePointer<SplineItemType>!
    var bBox = Rect()
}

struct File_SplineDefType {
    var numNubs: Int16 = 0
    var junk1: Int32 = 0
    var numPoints: Int32 = 0
    var junk2: Int32 = 0
    var numItems: Int16 = 0
    var junk3: Int32 = 0
    var bBox = Rect()
}

private let maxSplineObjects = 100
private let maxSplineItemNum = 49 // for error checking!

/// Terrain-spline state plus SplineManager.swift's custom-spline slots.
/// Owned by GameEngine as `gEngine.splines`.
final class SplineSystem {
    var splineList: UnsafeMutablePointer<SplineDefType>!
    var numSplines: Int = 0

    fileprivate var numSplineObjects = 0
    fileprivate var splineObjectList = [UnsafeMutablePointer<ObjNode>?](repeating: nil, count: maxSplineObjects)

    // SplineManager.swift's custom-spline slot buffer (permanent, never
    // freed; GetCustomSplineSlot hands out stable pointers into it)
    let customSplinesBuf: UnsafeMutablePointer<CustomSplineType> = {
        let buf = UnsafeMutablePointer<CustomSplineType>.allocate(capacity: 40)
        buf.initialize(repeating: CustomSplineType(), count: 40)
        return buf
    }()
}

private func nilPrime(_ splineNum: Int, _ itemPtr: UnsafeMutablePointer<SplineItemType>!) -> UInt8 {
    return 0
}

private let gSplineItemPrimeRoutines: [(Int, UnsafeMutablePointer<SplineItemType>?) -> UInt8] = [
    nilPrime, // My Start Coords
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    PrimeEnemy_Raptor, // 15: raptor enemy
    PrimeDustDevil, // 16:
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    PrimeEnemy_Brach, // 26: brach
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    PrimeLaserOrb, // 32: laser orb
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime, // 40:
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    nilPrime,
    PrimeEnemy_Ramphor, // 48
    PrimeTimeDemoSpline, // 49
]

// Called during terrain prime function to initialize
// all items on the splines and recalc spline coords
func PrimeSplines() {
    // ADJUST SPLINE TO GAME COORDINATES

    for s in 0..<gEngine.splines.numSplines {
        let points = gEngine.splines.splineList[s].pointList!

        for i in 0..<Int(gEngine.splines.splineList[s].numPoints) {
            points[i].x *= gEngine.terrain.mapToUnitValue
            points[i].z *= gEngine.terrain.mapToUnitValue
        }
    }

    // CLEAR SPLINE OBJECT LIST

    gEngine.splines.numSplineObjects = 0 // no items in spline object node list yet

    for s in 0..<gEngine.splines.numSplines {
        // SCAN ALL ITEMS ON THIS SPLINE

        for i in 0..<Int(gEngine.splines.splineList[s].numItems) {
            let itemPtr = gEngine.splines.splineList[s].itemList! + i // point to this item
            let type = Int(itemPtr.pointee.type) // get item type
            if type > maxSplineItemNum {
                SwFatal("PrimeSplines: type > MAX_SPLINE_ITEM_NUM")
            }

            let flag = gSplineItemPrimeRoutines[type](s, itemPtr) // call item's Prime routine
            if flag != 0 {
                itemPtr.pointee.flags |= UInt16(ITEM_FLAGS_INUSE) // set in-use flag
            }
        }
    }
}

// nothing prime

func GetCoordOnSplineFromIndex(_ splinePtr: UnsafeMutablePointer<SplineDefType>!, _ findex: Float, _ x: UnsafeMutablePointer<Float>!, _ z: UnsafeMutablePointer<Float>!) {
    // CALC INDEX OF THIS PT AND NEXT

    let numPointsInSpline = Int(splinePtr.pointee.numPoints) // get # points in the spline
    let i = Int(findex) // round down to int
    var i2 = i + 1
    if i2 >= numPointsInSpline { // make sure not go too far
        i2 = numPointsInSpline - 1
    }

    let points = splinePtr.pointee.pointList! // point to point list

    // INTERPOLATE

    let ratio = findex - Float(i) // calc 0.0 - .999 remainder for weighing the points
    let oneMinusRatio = 1.0 - ratio

    x.pointee = points[i].x * oneMinusRatio + points[i2].x * ratio // calc interpolated coord
    z.pointee = points[i].z * oneMinusRatio + points[i2].z * ratio
}

func GetCoordOnSpline(_ splinePtr: UnsafeMutablePointer<SplineDefType>!, _ placement: Float, _ x: UnsafeMutablePointer<Float>!, _ z: UnsafeMutablePointer<Float>!) {
    let numPointsInSpline = Int(splinePtr.pointee.numPoints) // get # points in the spline
    let findex = Float(numPointsInSpline) * placement // calc float index

    GetCoordOnSplineFromIndex(splinePtr, findex, x, z)
}

// Same as above except returns coord of the next point on the spline instead of the exact
// current one.
func GetNextCoordOnSpline(_ splinePtr: UnsafeMutablePointer<SplineDefType>!, _ placement: Float, _ x: UnsafeMutablePointer<Float>!, _ z: UnsafeMutablePointer<Float>!) {
    let numPointsInSpline = Float(splinePtr.pointee.numPoints) // get # points in the spline

    var findex = numPointsInSpline * placement // get index
    findex += 1.0 // bump it up +1

    if findex >= numPointsInSpline { // see if wrap around
        findex = 0
    }

    GetCoordOnSplineFromIndex(splinePtr, findex, x, z)
}

// Same as above except takes in input spline index offset
func GetCoordOnSpline2(_ splinePtr: UnsafeMutablePointer<SplineDefType>!, _ placement: Float, _ offset: Float, _ x: UnsafeMutablePointer<Float>!, _ z: UnsafeMutablePointer<Float>!) {
    let numPointsInSpline = Float(splinePtr.pointee.numPoints) // get # points in the spline

    var findex = numPointsInSpline * placement // get index
    findex += offset // bump it up

    if findex >= numPointsInSpline { // see if wrap around
        findex -= numPointsInSpline
    }

    GetCoordOnSplineFromIndex(splinePtr, findex, x, z)
}

// Returns true if the input objnode is in visible range.
// Also, this function handles the attaching and detaching of the objnode
// as needed.
func IsSplineItemOnActiveTerrain(_ theNode: UnsafeMutablePointer<ObjNode>!) -> UInt8 {
    var visible = true

    // IF IS ON AN ACTIVE SUPERTILE, THEN ASSUME VISIBLE

    let row = Int(theNode.pointee.Coord.z * gEngine.terrain.superTileUnitSizeFrac) // calc supertile row,col
    let col = Int(theNode.pointee.Coord.x * gEngine.terrain.superTileUnitSizeFrac)

    if (row < 0) || (row >= gEngine.terrain.numSuperTilesDeep) || (col < 0) || (col >= gEngine.terrain.numSuperTilesWide) { // make sure in bounds
        visible = false
    } else {
        if gEngine.terrain.superTileStatusGrid[row]![col].playerHereFlags != 0 {
            visible = true
        } else {
            visible = false
        }
    }

    // HANDLE OBJNODE UPDATES

    if visible {
        if theNode.hasStatus(STATUS_BIT_DETACHED) { // see if need to insert into linked list
            AttachObject(theNode, 1)
        }
    } else {
        if !theNode.hasStatus(STATUS_BIT_DETACHED) { // see if need to remove from linked list
            DetachObject(theNode, 1)
        }
    }

    return visible ? 1 : 0
}

// MARK: - Spline Objects

// Called by object's primer function to add the detached node to the spline item master
// list so that it can be maintained.
func AddToSplineObjectList(_ theNode: UnsafeMutablePointer<ObjNode>!, _ setAim: UInt8) {
    if gEngine.splines.numSplineObjects >= maxSplineObjects {
        SwFatal("AddToSplineObjectList: too many spline objects")
    }

    theNode.pointee.SplineObjectIndex = Int16(gEngine.splines.numSplineObjects) // remember where in list this is

    gEngine.splines.splineObjectList[gEngine.splines.numSplineObjects] = theNode
    gEngine.splines.numSplineObjects += 1

    // SET INITIAL AIM

    if setAim != 0 {
        SetSplineAim(theNode)
    }
}

func SetSplineAim(_ theNode: UnsafeMutablePointer<ObjNode>!) {
    var x: Float = 0
    var z: Float = 0

    GetCoordOnSpline2(&gEngine.splines.splineList[Int(theNode.pointee.SplineNum)], theNode.pointee.SplinePlacement, 3, &x, &z) // get coord of next point on spline
    theNode.pointee.Rot.y = CalcYAngleFromPointToPoint(theNode.pointee.Rot.y, theNode.pointee.Coord.x, theNode.pointee.Coord.z, x, z) // calc y rot aim
}

// OUTPUT:  true = the obj was on a spline and it was removed from it
//			false = the obj was not on a spline.
func RemoveFromSplineObjectList(_ theNode: UnsafeMutablePointer<ObjNode>!) -> UInt8 {
    theNode.clearStatus(STATUS_BIT_ONSPLINE) // make sure this flag is off

    if theNode.pointee.SplineObjectIndex != -1 {
        gEngine.splines.splineObjectList[Int(theNode.pointee.SplineObjectIndex)] = nil // nil out the entry into the list
        theNode.pointee.SplineObjectIndex = -1
        theNode.pointee.SplineItemPtr = nil
        theNode.pointee.SplineMoveCall = nil
        return 1
    } else {
        return 0
    }
}

// Called by level cleanup to dispose of the detached ObjNode's in this list.
func EmptySplineObjectList() {
    for i in 0..<gEngine.splines.numSplineObjects {
        if let o = gEngine.splines.splineObjectList[i] {
            DeleteObject(o) // This will dispose of all memory used by the node.
            // RemoveFromSplineObjectList will be called by it.
        }
    }
    gEngine.splines.numSplineObjects = 0
}

func MoveSplineObjects() {
    for i in 0..<gEngine.splines.numSplineObjects {
        guard let theNode = gEngine.splines.splineObjectList[i] else { continue }

        // UPDATE SKELETON ANIMATION

        if theNode.pointee.Skeleton != nil {
            theNode.updateSkeletonAnimation()
        }

        // CALL SPLINE MOVE

        if let splineMoveCall = theNode.pointee.SplineMoveCall {
            KeepOldCollisionBoxes(theNode) // keep old boxes & other stuff
            splineMoveCall(theNode) // call object's spline move routine
        }

        // UPDATE SKELETON'S MESH

        if theNode.pointee.CType != INVALID_NODE_FLAG {
            if theNode.pointee.Skeleton != nil {
                UpdateSkinnedGeometry(theNode)
            }
        }
    }
}

// OUTPUT: 	x,y = coords
func GetObjectCoordOnSpline(_ theNode: UnsafeMutablePointer<ObjNode>!) {
    var placement = theNode.pointee.SplinePlacement // get placement
    if placement < 0.0 {
        placement = 0
    } else if placement >= 1.0 {
        placement = 0.999
    }

    let splinePtr = gEngine.splines.splineList + Int(theNode.pointee.SplineNum) // point to the spline

    GetCoordOnSpline(splinePtr, placement, &theNode.pointee.Coord.x, &theNode.pointee.Coord.z) // get coord

    theNode.pointee.Delta.x = (theNode.pointee.Coord.x - theNode.pointee.OldCoord.x) * gFramesPerSecond // calc delta
    theNode.pointee.Delta.z = (theNode.pointee.Coord.z - theNode.pointee.OldCoord.z) * gFramesPerSecond
    theNode.pointee.Delta.y = 0
}

func GetObjectCoordOnSpline2(_ theNode: UnsafeMutablePointer<ObjNode>!, _ x: UnsafeMutablePointer<Float>!, _ z: UnsafeMutablePointer<Float>!) {
    var placement = theNode.pointee.SplinePlacement // get placement
    if placement < 0.0 {
        placement = 0
    } else if placement >= 1.0 {
        placement = 0.999
    }

    let splinePtr = gEngine.splines.splineList + Int(theNode.pointee.SplineNum) // point to the spline

    GetCoordOnSpline(splinePtr, placement, x, z) // get coord
}

// Moves objects on spline at given speed
//
// Returns true if increase caused item to wrap to beginning of spline
func IncreaseSplineIndex(_ theNode: UnsafeMutablePointer<ObjNode>!, _ speed: Float) -> UInt8 {
    var speed = speed
    speed *= gFramesPerSecondFrac

    let splinePtr = gEngine.splines.splineList + Int(theNode.pointee.SplineNum) // point to the spline
    let numPointsInSpline = Float(splinePtr.pointee.numPoints) // get # points in the spline

    theNode.pointee.SplinePlacement += speed / numPointsInSpline
    if theNode.pointee.SplinePlacement > 0.999 {
        theNode.pointee.SplinePlacement -= 0.999
        if theNode.pointee.SplinePlacement > 0.999 { // see if it wrapped somehow
            theNode.pointee.SplinePlacement = 0
        }
        return 1
    }
    return 0
}

// Moves objects on spline at given speed, but zigzags
func IncreaseSplineIndexZigZag(_ theNode: UnsafeMutablePointer<ObjNode>!, _ speed: Float) {
    var speed = speed
    speed *= gFramesPerSecondFrac

    let splinePtr = gEngine.splines.splineList + Int(theNode.pointee.SplineNum) // point to the spline
    let numPointsInSpline = Float(splinePtr.pointee.numPoints) // get # points in the spline

    // GOING BACKWARD

    if theNode.hasStatus(STATUS_BIT_REVERSESPLINE) { // see if going backward
        theNode.pointee.SplinePlacement -= speed / numPointsInSpline
        if theNode.pointee.SplinePlacement <= 0.0 {
            theNode.pointee.SplinePlacement = 0
            theNode.pointee.StatusBits ^= UInt32(STATUS_BIT_REVERSESPLINE) // toggle direction
        }
    }

    // GOING FORWARD

    else {
        theNode.pointee.SplinePlacement += speed / numPointsInSpline
        if theNode.pointee.SplinePlacement >= 0.999 {
            theNode.pointee.SplinePlacement = 0.999
            theNode.pointee.StatusBits ^= UInt32(STATUS_BIT_REVERSESPLINE) // toggle direction
        }
    }
}

func DetachObjectFromSpline(_ theNode: UnsafeMutablePointer<ObjNode>!, _ moveCall: (@convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void)!) {
    if !theNode.hasStatus(STATUS_BIT_ONSPLINE) {
        return
    }

    // MAKE SURE ALL COMPONENTS ARE IN LINKED LIST

    AttachObject(theNode, 1)

    // REMOVE FROM SPLINE

    _ = RemoveFromSplineObjectList(theNode)

    theNode.pointee.InitCoord = theNode.pointee.Coord // remember where started

    theNode.pointee.MoveCall = moveCall
}
