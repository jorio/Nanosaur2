// Collision.swift - Port of Collision.c to Swift
//
// gCollisionList/gNumCollisions/gTotalSides are native Swift storage now
// (converted 2026-07-07): nothing in any .c file touches them anymore.
// gCollisionList was a fixed-size C array exposed via EnemyInternal.h's
// GetCollisionListEntry shim; it's now a permanent, never-freed
// UnsafeMutablePointer buffer, with the accessor reimplemented in plain
// Swift under the same name/signature so its call sites elsewhere
// (Player_Terrain.swift, Enemy.swift, Player_Weapons.swift) didn't need
// to change.

var gNumCollisions: Int16 = 0
var gTotalSides: UInt8 = 0

private let maxCollisions = 60

private let gCollisionListBuf: UnsafeMutablePointer<CollisionRec> = {
    let buf = UnsafeMutablePointer<CollisionRec>.allocate(capacity: maxCollisions)
    buf.initialize(repeating: CollisionRec(), count: maxCollisions)
    return buf
}()
func GetCollisionListEntry(_ i: Int32) -> UnsafeMutablePointer<CollisionRec>! {
    gCollisionListBuf + Int(i)
}

// Not extern'd in any header in the original C source, so nothing outside
// Collision.c ever referenced them despite having external linkage there.
private var gSolidTriggerKeepDelta: UInt8 = 0
private var gTriggerSides: UInt8 = 0

@inline(__always) private func collisionBoxesBase(_ n: UnsafeMutablePointer<ObjNode>) -> UnsafeMutablePointer<CollisionBoxType> {
    UnsafeMutableRawPointer(n.pointer(to: \.CollisionBoxes)!).assumingMemoryBound(to: CollisionBoxType.self)
}

// INPUT: startNumCollisions = value to start gNumCollisions at should we need to keep existing data in collision list
func CollisionDetect(_ baseNode: UnsafeMutablePointer<ObjNode>!, _ CType: UInt32, _ startNumCollisions: Int16) {
    gNumCollisions = startNumCollisions // clear list

    // GET BASE BOX INFO

    let numBaseBoxes = baseNode.pointee.NumCollisionBoxes
    if numBaseBoxes == 0 {
        return
    }
    let baseBoxList = collisionBoxesBase(baseNode)

    let leftSide = baseBoxList[0].left
    let rightSide = baseBoxList[0].right
    let frontSide = baseBoxList[0].front
    let backSide = baseBoxList[0].back
    let bottomSide = baseBoxList[0].bottom
    let topSide = baseBoxList[0].top

    // SCAN AGAINST ALL OBJECTS

    scan: for thisNode in usableObjectNodes {
        let cType = thisNode.pointee.CType
        if cType == INVALID_NODE_FLAG { // see if something went wrong
            break scan
        }

        nextNode: repeat {
            if (cType & CType) == 0 { // see if we want to check this Type
                break nextNode
            }

            if thisNode.hasStatus(STATUS_BIT_NOCOLLISION) { // don't collide against these
                break nextNode
            }

            if thisNode == baseNode { // dont collide against itself
                break nextNode
            }

            if baseNode.pointee.ChainNode == thisNode { // don't collide against its own chained object
                break nextNode
            }

            // NOW DO COLLISION BOX CHECK

            let targetNumBoxes = thisNode.pointee.NumCollisionBoxes // see if target has any boxes
            if targetNumBoxes != 0 {
                let targetBoxList = collisionBoxesBase(thisNode)

                // CHECK BASE BOX AGAINST EACH TARGET BOX

                for target in 0..<Int(targetNumBoxes) {
                    // DO RECTANGLE INTERSECTION

                    if rightSide < targetBoxList[target].left {
                        continue
                    }

                    if leftSide > targetBoxList[target].right {
                        continue
                    }

                    if frontSide < targetBoxList[target].back {
                        continue
                    }

                    if backSide > targetBoxList[target].front {
                        continue
                    }

                    if bottomSide > targetBoxList[target].top {
                        continue
                    }

                    if topSide < targetBoxList[target].bottom {
                        continue
                    }

                    // THERE HAS BEEN A COLLISION SO CHECK WHICH SIDE PASSED THRU

                    var sideBits: UInt16 = 0
                    let cBits = thisNode.pointee.CBits // get collision info bits

                    var gotSides = false
                    if cBits & UInt32(CBITS_ALLSOLID) == 0 { // if not a solid, then add it without side info
                        gotSides = true
                    }

                    if !gotSides {
                        // CHECK FRONT COLLISION

                        if cBits & UInt32(SIDE_BITS_BACK) != 0 { // see if target has solid back
                            if baseBoxList[0].oldFront < targetBoxList[target].oldBack { // get old & see if already was in target (if so, skip)
                                if (baseBoxList[0].front >= targetBoxList[target].back) && // see if currently in target
                                    (baseBoxList[0].front <= targetBoxList[target].front) {
                                    sideBits = UInt16(SIDE_BITS_FRONT)
                                }
                            }
                        }

                        // CHECK BACK COLLISION

                        if cBits & UInt32(SIDE_BITS_FRONT) != 0 { // see if target has solid front
                            if baseBoxList[0].oldBack > targetBoxList[target].oldFront { // get old & see if already was in target
                                if (baseBoxList[0].back <= targetBoxList[target].front) && // see if currently in target
                                    (baseBoxList[0].back >= targetBoxList[target].back) {
                                    sideBits = UInt16(SIDE_BITS_BACK)
                                }
                            }
                        }

                        // CHECK RIGHT COLLISION

                        if cBits & UInt32(SIDE_BITS_LEFT) != 0 { // see if target has solid left
                            if baseBoxList[0].oldRight < targetBoxList[target].oldLeft { // get old & see if already was in target
                                if (baseBoxList[0].right >= targetBoxList[target].left) && // see if currently in target
                                    (baseBoxList[0].right <= targetBoxList[target].right) {
                                    sideBits |= UInt16(SIDE_BITS_RIGHT)
                                }
                            }
                        }

                        // CHECK COLLISION ON LEFT

                        if cBits & UInt32(SIDE_BITS_RIGHT) != 0 { // see if target has solid right
                            if baseBoxList[0].oldLeft > targetBoxList[target].oldRight { // get old & see if already was in target
                                if (baseBoxList[0].left <= targetBoxList[target].right) && // see if currently in target
                                    (baseBoxList[0].left >= targetBoxList[target].left) {
                                    sideBits |= UInt16(SIDE_BITS_LEFT)
                                }
                            }
                        }

                        // CHECK TOP COLLISION

                        if cBits & UInt32(SIDE_BITS_BOTTOM) != 0 { // see if target has solid bottom
                            if baseBoxList[0].oldTop < targetBoxList[target].oldBottom { // get old & see if already was in target
                                if (baseBoxList[0].top >= targetBoxList[target].bottom) && // see if currently in target
                                    (baseBoxList[0].top <= targetBoxList[target].top) {
                                    sideBits |= UInt16(SIDE_BITS_TOP)
                                }
                            }
                        }

                        // CHECK COLLISION ON BOTTOM

                        if cBits & UInt32(SIDE_BITS_TOP) != 0 { // see if target has solid top
                            if baseBoxList[0].oldBottom > targetBoxList[target].oldTop { // get old & see if already was in target
                                if (baseBoxList[0].bottom <= targetBoxList[target].top) && // see if currently in target
                                    (baseBoxList[0].bottom >= targetBoxList[target].bottom) {
                                    sideBits |= UInt16(SIDE_BITS_BOTTOM)
                                }
                            }
                        }

                        // SEE IF ANYTHING TO ADD OR IF IMPENETRABLE

                        if sideBits == 0 { // if 0 then no new sides passed thru this time
                            if cBits & UInt32(CBITS_IMPENETRABLE) != 0 { // if its impenetrable, add to list regardless of sides
                                if gCoord.x < thisNode.pointee.Coord.x { // try to assume some side info based on which side we're on relative to the target
                                    sideBits |= UInt16(SIDE_BITS_RIGHT)
                                } else {
                                    sideBits |= UInt16(SIDE_BITS_LEFT)
                                }

                                if gCoord.z < thisNode.pointee.Coord.z {
                                    sideBits |= UInt16(SIDE_BITS_FRONT)
                                } else {
                                    sideBits |= UInt16(SIDE_BITS_BACK)
                                }

                                gotSides = true
                            } else if cBits & UInt32(CBITS_ALWAYSTRIGGER) != 0 { // also always add if always trigger
                                gotSides = true
                            } else {
                                continue
                            }
                        } else {
                            gotSides = true
                        }
                    }
                    _ = gotSides

                    // ADD TO COLLISION LIST

                    let entry = GetCollisionListEntry(Int32(gNumCollisions))!
                    entry.pointee.baseBox = 0
                    entry.pointee.targetBox = UInt8(target)
                    entry.pointee.sides = sideBits
                    entry.pointee.type = UInt8(COLLISION_TYPE_OBJ)
                    entry.pointee.objectPtr = thisNode
                    gNumCollisions += 1
                    gTotalSides |= UInt8(truncatingIfNeeded: sideBits) // remember total of this
                }
            }
        } while false
    }

    if gNumCollisions > maxCollisions { // see if overflowed (memory corruption ensued)
        SwFatal("CollisionDetect: gNumCollisions > MAX_COLLISIONS")
    }
}

// This is a generic collision handler.  Takes care of
// all processing.
//
// INPUT:  cType = CType bit mask for collision matching
//
// OUTPUT: totalSides
func HandleCollisions(_ theNode: UnsafeMutablePointer<ObjNode>!, _ cType: UInt32, _ deltaBounce: Float) -> UInt8 {
    var deltaBounce = deltaBounce
    var totalSides: UInt8 = 0
    var hitImpenetrable = false
    var numPasses = 0
    var hasTriggered = false
    var trigger: UnsafeMutablePointer<ObjNode>?
    var bottomSide: Float = 0

    if deltaBounce > 0.0 { // make sure Brian entered a (-) bounce value!
        deltaBounce = -deltaBounce
    }

    let previouslyOnGround = theNode.hasStatus(STATUS_BIT_ONGROUND) // remember if was on ground or not

    theNode.clearStatus(STATUS_BIT_ONGROUND) // assume not on anything now

    gNumCollisions = 0
    let oldNumCollisions: Int16 = 0
    totalSides = 0

    passLoop: while true {
        let originalX = gCoord.x // remember starting coords
        let originalY = gCoord.y
        let originalZ = gCoord.z

        var numSolidHits = 0

        CalcObjectBoxFromGlobal(theNode) // calc current collision box

        // GET THE COLLISION LIST

        CollisionDetect(theNode, cType, gNumCollisions) // get collision info

        var maxOffsetX: Float = -10000
        var maxOffsetZ: Float = -10000
        var maxOffsetY: Float = -10000
        var offXSign: Float = 0
        var offYSign: Float = 0
        var offZSign: Float = 0

        // GET BASE BOX INFO

        if theNode.pointee.NumCollisionBoxes == 0 { // it's gotta have a collision box
            return 0
        }
        let boxList = collisionBoxesBase(theNode)
        bottomSide = boxList[0].bottom

        // SCAN THRU ALL RETURNED COLLISIONS

        for i in Int(oldNumCollisions)..<Int(gNumCollisions) {
            let entry = GetCollisionListEntry(Int32(i))!
            let base = entry.pointee.baseBox // get collision box index for base & target
            let target = entry.pointee.targetBox
            let targetObj = entry.pointee.objectPtr // get ptr to target objnode

            let baseBoxPtr = boxList + Int(base) // calc ptrs to base & target collision boxes
            var targetBoxPtr: UnsafeMutablePointer<CollisionBoxType>?
            if let targetObj {
                targetBoxPtr = collisionBoxesBase(targetObj) + Int(target)
            }

            // HANDLE OBJECT COLLISIONS

            if entry.pointee.type == UInt8(COLLISION_TYPE_OBJ) {
                // SEE IF THIS OBJECT HAS SINCE BECOME INVALID

                let targetCType = targetObj!.pointee.CType // get ctype of hit obj
                if targetCType == INVALID_NODE_FLAG {
                    continue
                }

                // HANDLE TRIGGERS

                if ((targetCType & UInt32(CTYPE_TRIGGER) != 0) && (cType & UInt32(CTYPE_TRIGGER) != 0)) || // target must be trigger and we must have been looking for them as well
                    ((targetCType & UInt32(CTYPE_TRIGGER2) != 0) && (cType & UInt32(CTYPE_TRIGGER2) != 0)) {
                    gSolidTriggerKeepDelta = 0 // assume solid triggers will cause delta to stop below

                    if let triggerCallback = targetObj!.pointee.TriggerCallback { // make sure there's a callback installed
                        gTriggerSides = UInt8(truncatingIfNeeded: entry.pointee.sides) // set this global in case the trigger handler needs it (rather than passing it to the trigger func)
                        if triggerCallback(targetObj, theNode) == 0 { // returns false if handle as non-solid trigger
                            entry.pointee.sides = 0
                        }

                        trigger = targetObj // remember which obj we triggered
                    }

                    numSolidHits += 1

                    maxOffsetX = gCoord.x - originalX // see if trigger caused a move
                    if maxOffsetX < 0.0 {
                        maxOffsetX = -maxOffsetX
                        offXSign = -1
                    } else if maxOffsetX > 0.0 {
                        offXSign = 1
                    }

                    maxOffsetZ = gCoord.z - originalZ
                    if maxOffsetZ < 0.0 {
                        maxOffsetZ = -maxOffsetZ
                        offZSign = -1
                    } else if maxOffsetZ > 0.0 {
                        offZSign = 1
                    }

                    hasTriggered = true // dont allow multi-pass collision once there is a trigger (to avoid multiple hits on the same trigger)

                    if gSolidTriggerKeepDelta != 0 { // if trigger's callback set this then set delta bounce to 1.0 so it'll no affect the deltas
                        deltaBounce = 1.0
                    }
                }

                // DO SOLID FIXING

                if entry.pointee.sides & SwALL_SOLID_SIDES != 0 { // see if object with any solidness
                    numSolidHits += 1

                    if targetObj!.pointee.CBits & UInt32(CBITS_IMPENETRABLE) != 0 { // if this object is impenetrable, then throw out any other collision offsets
                        hitImpenetrable = true
                        maxOffsetX = -10000
                        maxOffsetZ = -10000
                        maxOffsetY = -10000
                        offXSign = 0
                        offYSign = 0
                        offZSign = 0
                    }

                    if entry.pointee.sides & UInt16(SIDE_BITS_BACK) != 0 { // SEE IF BACK HIT
                        let offset = (targetBoxPtr!.pointee.front - baseBoxPtr.pointee.back) + 0.01 // see how far over it went
                        if offset > maxOffsetZ {
                            maxOffsetZ = offset
                            offZSign = 1
                        }
                        gDelta.z *= deltaBounce
                    } else if entry.pointee.sides & UInt16(SIDE_BITS_FRONT) != 0 { // SEE IF FRONT HIT
                        let offset = (baseBoxPtr.pointee.front - targetBoxPtr!.pointee.back) + 0.01 // see how far over it went
                        if offset > maxOffsetZ {
                            maxOffsetZ = offset
                            offZSign = -1
                        }
                        gDelta.z *= deltaBounce
                    }

                    if entry.pointee.sides & UInt16(SIDE_BITS_LEFT) != 0 { // SEE IF HIT LEFT
                        let offset = (targetBoxPtr!.pointee.right - baseBoxPtr.pointee.left) + 0.01 // see how far over it went
                        if offset > maxOffsetX {
                            maxOffsetX = offset
                            offXSign = 1
                        }
                        gDelta.x *= deltaBounce
                    } else if entry.pointee.sides & UInt16(SIDE_BITS_RIGHT) != 0 { // SEE IF HIT RIGHT
                        let offset = (baseBoxPtr.pointee.right - targetBoxPtr!.pointee.left) + 0.01 // see how far over it went
                        if offset > maxOffsetX {
                            maxOffsetX = offset
                            offXSign = -1
                        }
                        gDelta.x *= deltaBounce
                    }

                    if entry.pointee.sides & UInt16(SIDE_BITS_BOTTOM) != 0 { // SEE IF HIT BOTTOM
                        let offset = (targetBoxPtr!.pointee.top - baseBoxPtr.pointee.bottom) + 0.01 // see how far over it went
                        if offset > maxOffsetY {
                            maxOffsetY = offset
                            offYSign = 1
                        }
                        gDelta.y = -150 // keep some downward momentum!!
                    } else if entry.pointee.sides & UInt16(SIDE_BITS_TOP) != 0 { // SEE IF HIT TOP
                        let offset = (baseBoxPtr.pointee.top - targetBoxPtr!.pointee.bottom) + 1.0 // see how far over it went
                        if offset > maxOffsetY {
                            maxOffsetY = offset
                            offYSign = -1
                        }
                        gDelta.y = 0
                    }
                }
            }

            totalSides |= UInt8(truncatingIfNeeded: entry.pointee.sides) // keep sides info

            if hitImpenetrable { // if that was impenetrable, then we dont need to check other collisions
                break
            }
        }

        // IF THERE WAS A SOLID HIT, THEN WE NEED TO UPDATE AND TRY AGAIN

        if numSolidHits > 0 {
            // ADJUST MAX AMOUNTS

            gCoord.x = originalX + (maxOffsetX * offXSign)
            gCoord.z = originalZ + (maxOffsetZ * offZSign)
            gCoord.y = originalY + (maxOffsetY * offYSign) // y is special - we do some additional rouding to avoid the jitter problem

            // SEE IF NEED TO SET GROUND FLAG

            if totalSides & UInt8(SIDE_BITS_BOTTOM) != 0 {
                if !previouslyOnGround { // if not already on ground, then add some friction upon landing
                    // (hitMPlatform is always false in the original C source; special-case dropped)
                }
                theNode.setStatus(STATUS_BIT_ONGROUND)
            }

            // SEE IF DO ANOTHER PASS

            numPasses += 1
            if (numPasses < 3) && (!hitImpenetrable) && (!hasTriggered) { // see if can do another pass and havnt hit anything impenetrable
                continue passLoop
            }
        }

        break passLoop
    }

    // SEE IF UPDATE TRIGGER INFO

    if let trigger { // did we hit a trigger this time?
        theNode.pointee.CurrentTriggerObj = trigger // yep, so remember it
    } else {
        theNode.pointee.CurrentTriggerObj = nil
    }

    // CHECK FENCE COLLISION

    if cType & UInt32(CTYPE_FENCE) != 0 {
        if DoFenceCollision(theNode) != 0 {
            totalSides |= UInt8(truncatingIfNeeded: SwALL_SOLID_SIDES)
            numPasses += 1
            // (matches original: additional pass was never re-triggered here since
            // there is no loop back to "again" after fence collision in the C source)
        }
    }

    // SEE IF DO AUTOMATIC TERRAIN GROUND HIT

    if cType & UInt32(CTYPE_TERRAIN) != 0 {
        let y = GetTerrainY(gCoord.x, gCoord.z) // get terrain Y

        if bottomSide <= y { // see if bottom is under ground
            gCoord.y += y - bottomSide

            if gDelta.y < 0.0 { // if was going down then bounce y
                gDelta.y *= deltaBounce
                if abs(gDelta.y) < 30.0 { // if small enough just make zero
                    gDelta.y = 0
                }
            }

            theNode.setStatus(STATUS_BIT_ONGROUND)

            totalSides |= UInt8(SIDE_BITS_BOTTOM)
        }
    }

    // SEE IF DO WATER COLLISION TEST

    if cType & UInt32(CTYPE_WATER) != 0 {
        var patchNum: Int32 = 0
        DoWaterCollisionDetect(theNode, gCoord.x, gCoord.y, gCoord.z, &patchNum)
    }

    gTotalSides = totalSides
    return totalSides
}

// MARK: - Point/Poly Tests

// Quadrants:
//    1 | 0
//    -----
//    2 | 3
//
//	INPUT:	pt_x,pt_y	:	point x,y coords
//			cnt			:	# points in poly
//			polypts		:	ptr to array of 2D points
func IsPointInPoly2D(_ pt_x: Float, _ pt_y: Float, _ numVerts: UInt8, _ polypts: UnsafeMutablePointer<OGLPoint2D>!) -> UInt8 {
    var oldquad: UInt8
    var newquad: UInt8
    var wind: Int8 = 0 // current winding number

    // INIT STARTING VALUES

    var lastpt_x = polypts[Int(numVerts) - 1].x // get last point's coords
    var lastpt_y = polypts[Int(numVerts) - 1].y

    if lastpt_x < pt_x { // calc quadrant of the last point
        oldquad = lastpt_y < pt_y ? 2 : 1
    } else {
        oldquad = lastpt_y < pt_y ? 3 : 0
    }

    // WIND THROUGH ALL POINTS

    for i in 0..<Int(numVerts) {
        // GET THIS POINT INFO

        let thispt_x = polypts[i].x // get this point's coords
        let thispt_y = polypts[i].y

        if thispt_x < pt_x { // calc quadrant of this point
            newquad = thispt_y < pt_y ? 2 : 1
        } else {
            newquad = thispt_y < pt_y ? 3 : 0
        }

        // SEE IF QUADRANT CHANGED

        if oldquad != newquad {
            if (oldquad + 1) & 3 == newquad { // see if advanced
                wind += 1
            } else if (newquad + 1) & 3 == oldquad { // see if backed up
                wind -= 1
            } else {
                // upper left to lower right, or upper right to lower left.
                // Determine direction of winding  by intersection with x==0.

                var a = (lastpt_y - thispt_y) * (pt_x - lastpt_x)
                var b = lastpt_x - thispt_x
                a += lastpt_y * b
                b *= pt_y

                if a > b {
                    wind += 2
                } else {
                    wind -= 2
                }
            }
        }

        // MOVE TO NEXT POINT

        lastpt_x = thispt_x
        lastpt_y = thispt_y
        oldquad = newquad
    }

    return wind != 0 ? 1 : 0 // non zero means point in poly
}

// Quadrants:
//    1 | 0
//    -----
//    2 | 3
//
//	INPUT:	pt_x,pt_y	:	point x,y coords
//			cnt			:	# points in poly
//			polypts		:	ptr to array of 2D points
func IsPointInTriangle(_ pt_x: Float, _ pt_y: Float, _ x0: Float, _ y0: Float, _ x1: Float, _ y1: Float, _ x2: Float, _ y2: Float) -> UInt8 {
    var oldquad: UInt8
    var newquad: UInt8
    var wind: Int8

    // DO TRIVIAL REJECT

    var m = x0 // see if to left of triangle
    if x1 < m { m = x1 }
    if x2 < m { m = x2 }
    if pt_x < m {
        return 0
    }

    m = x0 // see if to right of triangle
    if x1 > m { m = x1 }
    if x2 > m { m = x2 }
    if pt_x > m {
        return 0
    }

    m = y0 // see if to back of triangle
    if y1 < m { m = y1 }
    if y2 < m { m = y2 }
    if pt_y < m {
        return 0
    }

    m = y0 // see if to front of triangle
    if y1 > m { m = y1 }
    if y2 > m { m = y2 }
    if pt_y > m {
        return 0
    }

    // DO WINDING TEST

    // INIT STARTING VALUES

    if x2 < pt_x { // calc quadrant of the last point
        oldquad = y2 < pt_y ? 2 : 1
    } else {
        oldquad = y2 < pt_y ? 3 : 0
    }

    // WIND THROUGH ALL POINTS

    wind = 0

    if x0 < pt_x { // calc quadrant of this point
        newquad = y0 < pt_y ? 2 : 1
    } else {
        newquad = y0 < pt_y ? 3 : 0
    }

    // SEE IF QUADRANT CHANGED

    if oldquad != newquad {
        if (oldquad + 1) & 3 == newquad { // see if advanced
            wind += 1
        } else if (newquad + 1) & 3 == oldquad { // see if backed up
            wind -= 1
        } else {
            // upper left to lower right, or upper right to lower left.
            // Determine direction of winding  by intersection with x==0.

            var a = (y2 - y0) * (pt_x - x2)
            var b = x2 - x0
            a += y2 * b
            b *= pt_y

            if a > b {
                wind += 2
            } else {
                wind -= 2
            }
        }
    }

    oldquad = newquad

    if x1 < pt_x { // calc quadrant of this point
        newquad = y1 < pt_y ? 2 : 1
    } else {
        newquad = y1 < pt_y ? 3 : 0
    }

    // SEE IF QUADRANT CHANGED

    if oldquad != newquad {
        if (oldquad + 1) & 3 == newquad { // see if advanced
            wind += 1
        } else if (newquad + 1) & 3 == oldquad { // see if backed up
            wind -= 1
        } else {
            // upper left to lower right, or upper right to lower left.
            // Determine direction of winding  by intersection with x==0.

            var a = (y0 - y1) * (pt_x - x0)
            var b = x0 - x1
            a += y0 * b
            b *= pt_y

            if a > b {
                wind += 2
            } else {
                wind -= 2
            }
        }
    }

    oldquad = newquad

    if x2 < pt_x { // calc quadrant of this point
        newquad = y2 < pt_y ? 2 : 1
    } else {
        newquad = y2 < pt_y ? 3 : 0
    }

    // SEE IF QUADRANT CHANGED

    if oldquad != newquad {
        if (oldquad + 1) & 3 == newquad { // see if advanced
            wind += 1
        } else if (newquad + 1) & 3 == oldquad { // see if backed up
            wind -= 1
        } else {
            // upper left to lower right, or upper right to lower left.
            // Determine direction of winding  by intersection with x==0.

            var a = (y1 - y2) * (pt_x - x1)
            var b = x1 - x2
            a += y1 * b
            b *= pt_y

            if a > b {
                wind += 2
            } else {
                wind -= 2
            }
        }
    }

    return wind != 0 ? 1 : 0 // non zero means point in poly
}

// MARK: - Simple Collision Tests

// INPUT:  except == objNode to skip
//
// OUTPUT: # collisions detected
func DoSimplePointCollision(_ thePoint: UnsafeMutablePointer<OGLPoint3D>!, _ cType: UInt32, _ except: UnsafeMutablePointer<ObjNode>!) -> Int16 {
    gNumCollisions = 0

    for thisNode in usableObjectNodes {
        nextNode: repeat {
            if thisNode == except { // see if skip this one
                break nextNode
            }

            if thisNode.pointee.CType & cType == 0 { // see if we want to check this Type
                break nextNode
            }

            if thisNode.hasStatus(STATUS_BIT_NOCOLLISION) { // don't collide against these
                break nextNode
            }

            if thisNode.pointee.CBits == 0 { // see if this obj doesn't need collisioning
                break nextNode
            }

            // GET BOX INFO FOR THIS NODE

            let targetNumBoxes = thisNode.pointee.NumCollisionBoxes // if target has no boxes, then skip
            if targetNumBoxes == 0 {
                break nextNode
            }
            let targetBoxList = collisionBoxesBase(thisNode)

            // CHECK POINT AGAINST EACH TARGET BOX

            for target in 0..<Int(targetNumBoxes) {
                // DO RECTANGLE INTERSECTION

                if thePoint.pointee.x < targetBoxList[target].left {
                    continue
                }

                if thePoint.pointee.x > targetBoxList[target].right {
                    continue
                }

                if thePoint.pointee.z < targetBoxList[target].back {
                    continue
                }

                if thePoint.pointee.z > targetBoxList[target].front {
                    continue
                }

                if thePoint.pointee.y > targetBoxList[target].top {
                    continue
                }

                if thePoint.pointee.y < targetBoxList[target].bottom {
                    continue
                }

                // THERE HAS BEEN A COLLISION

                let entry = GetCollisionListEntry(Int32(gNumCollisions))!
                entry.pointee.targetBox = UInt8(target)
                entry.pointee.type = UInt8(COLLISION_TYPE_OBJ)
                entry.pointee.objectPtr = thisNode
                gNumCollisions += 1
            }
        } while false
    }

    return gNumCollisions
}

// OUTPUT: # collisions detected
func DoSimpleBoxCollision(_ top: Float, _ bottom: Float, _ left: Float, _ right: Float, _ front: Float, _ back: Float, _ cType: UInt32) -> Int16 {
    gNumCollisions = 0

    bail: for thisNode in usableObjectNodes {
        nextNode: repeat {
            if thisNode.pointee.CType & cType == 0 { // see if we want to check this Type
                break nextNode
            }

            if thisNode.hasStatus(STATUS_BIT_NOCOLLISION) { // don't collide against these
                break nextNode
            }

            // GET BOX INFO FOR THIS NODE

            let targetNumBoxes = thisNode.pointee.NumCollisionBoxes // if target has no boxes, then skip
            if targetNumBoxes == 0 {
                break nextNode
            }
            let targetBoxList = collisionBoxesBase(thisNode)

            // CHECK AGAINST EACH TARGET BOX

            for target in 0..<Int(targetNumBoxes) {
                // DO RECTANGLE INTERSECTION

                if right < targetBoxList[target].left {
                    continue
                }

                if left > targetBoxList[target].right {
                    continue
                }

                if front < targetBoxList[target].back {
                    continue
                }

                if back > targetBoxList[target].front {
                    continue
                }

                if bottom > targetBoxList[target].top {
                    continue
                }

                if top < targetBoxList[target].bottom {
                    continue
                }

                // THERE HAS BEEN A COLLISION

                let entry = GetCollisionListEntry(Int32(gNumCollisions))!
                entry.pointee.targetBox = UInt8(target)
                entry.pointee.type = UInt8(COLLISION_TYPE_OBJ)
                entry.pointee.objectPtr = thisNode
                gNumCollisions += 1
                break bail
            }
        } while false
    }

    return gNumCollisions
}

func DoSimpleBoxCollisionAgainstPlayer(_ playerNum: Int16, _ top: Float, _ bottom: Float, _ left: Float, _ right: Float, _ front: Float, _ back: Float) -> UInt8 {
    if GetPlayerIsDead(Int32(playerNum)) != 0 { // if dead then blown up and can't be hit
        return 0
    }

    // GET BOX INFO FOR THIS NODE

    let playerObj = GetPlayerInfoEntry(Int32(playerNum)).pointee.objNode!
    let targetNumBoxes = playerObj.pointee.NumCollisionBoxes // if target has no boxes, then skip
    if targetNumBoxes == 0 {
        return 0
    }
    let targetBoxList = collisionBoxesBase(playerObj)

    // CHECK POINT AGAINST EACH TARGET BOX

    for target in 0..<Int(targetNumBoxes) {
        // DO RECTANGLE INTERSECTION

        if right < targetBoxList[target].left {
            continue
        }

        if left > targetBoxList[target].right {
            continue
        }

        if front < targetBoxList[target].back {
            continue
        }

        if back > targetBoxList[target].front {
            continue
        }

        if bottom > targetBoxList[target].top {
            continue
        }

        if top < targetBoxList[target].bottom {
            continue
        }

        return 1
    }

    return 0
}

// OUTPUT: 	x,y = coords
func DoSimplePointCollisionAgainstPlayer(_ playerNum: Int16, _ thePoint: UnsafeMutablePointer<OGLPoint3D>!) -> UInt8 {
    if GetPlayerIsDead(Int32(playerNum)) != 0 { // if dead then blown up and can't be hit
        return 0
    }

    // GET BOX INFO FOR THIS NODE

    let playerObj = GetPlayerInfoEntry(Int32(playerNum)).pointee.objNode!
    let targetNumBoxes = playerObj.pointee.NumCollisionBoxes // if target has no boxes, then skip
    if targetNumBoxes == 0 {
        return 0
    }
    let targetBoxList = collisionBoxesBase(playerObj)

    // CHECK POINT AGAINST EACH TARGET BOX

    for target in 0..<Int(targetNumBoxes) {
        // DO RECTANGLE INTERSECTION

        if thePoint.pointee.x < targetBoxList[target].left {
            continue
        }

        if thePoint.pointee.x > targetBoxList[target].right {
            continue
        }

        if thePoint.pointee.z < targetBoxList[target].back {
            continue
        }

        if thePoint.pointee.z > targetBoxList[target].front {
            continue
        }

        if thePoint.pointee.y > targetBoxList[target].top {
            continue
        }

        if thePoint.pointee.y < targetBoxList[target].bottom {
            continue
        }

        return 1
    }

    return 0
}

func DoSimpleBoxCollisionAgainstObject(_ top: Float, _ bottom: Float, _ left: Float, _ right: Float, _ front: Float, _ back: Float, _ targetNode: UnsafeMutablePointer<ObjNode>!) -> UInt8 {
    // GET BOX INFO FOR THIS NODE

    let targetNumBoxes = targetNode.pointee.NumCollisionBoxes // if target has no boxes, then skip
    if targetNumBoxes == 0 {
        return 0
    }
    let targetBoxList = collisionBoxesBase(targetNode)

    // CHECK POINT AGAINST EACH TARGET BOX

    for target in 0..<Int(targetNumBoxes) {
        // DO RECTANGLE INTERSECTION

        if right < targetBoxList[target].left {
            continue
        }

        if left > targetBoxList[target].right {
            continue
        }

        if front < targetBoxList[target].back {
            continue
        }

        if back > targetBoxList[target].front {
            continue
        }

        if bottom > targetBoxList[target].top {
            continue
        }

        if top < targetBoxList[target].bottom {
            continue
        }

        return 1
    }

    return 0
}

// Given the XY input, this returns the highest Y coordinate of any collision
// box here.
func FindHighestCollisionAtXZ(_ x: Float, _ z: Float, _ cType: UInt32) -> Float {
    var topY: Float = -10000000

    for thisNode in usableObjectNodes {
        nextNode: repeat {
            if thisNode.pointee.CType & cType == 0 { // matching ctype
                break nextNode
            }

            if thisNode.pointee.CBits & UInt32(CBITS_TOP) == 0 { // only top solid objects
                break nextNode
            }

            // GET BOX INFO FOR THIS NODE

            let targetNumBoxes = thisNode.pointee.NumCollisionBoxes // if target has no boxes, then skip
            if targetNumBoxes == 0 {
                break nextNode
            }
            let targetBoxList = collisionBoxesBase(thisNode)

            // CHECK POINT AGAINST EACH TARGET BOX

            for target in 0..<Int(targetNumBoxes) {
                if targetBoxList[target].top < topY { // check top
                    continue
                }

                // DO RECTANGLE INTERSECTION

                if x < targetBoxList[target].left {
                    continue
                }

                if x > targetBoxList[target].right {
                    continue
                }

                if z < targetBoxList[target].back {
                    continue
                }

                if z > targetBoxList[target].front {
                    continue
                }

                topY = targetBoxList[target].top + 0.1 // save as highest Y
            }
        } while false
    }

    return finishFindHighestCollisionAtXZ(topY, x, z, cType)
}

private func finishFindHighestCollisionAtXZ(_ topYIn: Float, _ x: Float, _ z: Float, _ cType: UInt32) -> Float {
    var topY = topYIn

    // NOW CHECK TERRAIN

    if cType & UInt32(CTYPE_TERRAIN) != 0 {
        let ty = GetTerrainY(x, z)

        if ty > topY {
            topY = ty
        }
    }

    // NOW CHECK WATER

    if cType & UInt32(CTYPE_WATER) != 0 {
        var wy: Float = 0

        if GetWaterY(x, z, &wy) != 0 {
            if wy > topY {
                topY = wy
            }
        }
    }

    return topY
}

// MARK: - Line/Ray Collision

// Does linesegment-triangle picking on all scene elements to test for collisions.
//
// OUTPUT: 	hitObj = objNode that was hit, or nil if hit something other than an objNode.
//			hitPt = coordinate of the hit
//			TRUE if a collision occurred
//			cTypes = set to CTYPE_TERRAIN or CTYPE_FENCE or left alone depending on what we hit
func HandleLineSegmentCollision(_ lineSeg: UnsafePointer<OGLLineSegment>!, _ hitObj: UnsafeMutablePointer<UnsafeMutablePointer<ObjNode>?>!, _ hitPt: UnsafeMutablePointer<OGLPoint3D>!, _ hitNormal: UnsafeMutablePointer<OGLVector3D>!, _ cTypes: UnsafeMutablePointer<UInt32>!, _ allowBBoxTests: UInt8) -> UInt8 {
    var coord = OGLPoint3D()
    var normal = OGLVector3D()
    var dist: Float = 0
    var bestDist: Float = 1000000
    var hit = false
    let inCType = cTypes.pointee // get the input CType mask

    cTypes.pointee = 0 // clear the output CType mask

    // FIRST SEE IF RAY HITS ANY OBJNODES

    hitObj.pointee = OGL_DoLineSegmentCollision_ObjNodes(lineSeg, UInt32(STATUS_BIT_HIDDEN), inCType, hitPt, hitNormal, &bestDist, allowBBoxTests)
    if hitObj.pointee != nil {
        hit = true
    }

    // NEXT SEE IF HIT TERRAIN

    if inCType & UInt32(CTYPE_TERRAIN) != 0 {
        if OGL_LineSegmentCollision_Terrain(lineSeg, &coord, &normal, &dist) != 0 {
            if dist < bestDist {
                bestDist = dist
                hitPt.pointee = coord
                hitNormal.pointee = normal
                hit = true
                cTypes.pointee = UInt32(CTYPE_TERRAIN) // let caller know that we hit terrain
            }
        }
    }

    // SEE IF HIT FENCE

    if inCType & UInt32(CTYPE_FENCE) != 0 {
        if OGL_LineSegmentCollision_Fence(lineSeg, &coord, &normal, &dist) != 0 {
            if dist < bestDist {
                bestDist = dist
                hitPt.pointee = coord
                hitNormal.pointee = normal
                hit = true
                cTypes.pointee = UInt32(CTYPE_FENCE) // let caller know that we hit a fence
            }
        }
    }

    // SEE IF HIT WATER

    if inCType & UInt32(CTYPE_WATER) != 0 {
        if OGL_LineSegmentCollision_Water(lineSeg, &coord, &normal, &dist) != 0 {
            if dist < bestDist {
                bestDist = dist
                hitPt.pointee = coord
                hitNormal.pointee = normal
                hit = true
                cTypes.pointee = UInt32(CTYPE_WATER) // let caller know that we hit water
            }
        }
    }

    return hit ? 1 : 0
}

// Does ray-triangle picking on all scene elements to test for collisions.
//
// OUTPUT: 	hitObj = objNode that was hit, or nil if hit something other than an objNode.
//			hitPt = coordinate of the hit
//			TRUE if a collision occurred
//			cTypes = set to CTYPE_TERRAIN or CTYPE_FENCE or left alone depending on what we hit
func HandleRayCollision(_ ray: UnsafeMutablePointer<OGLRay>!, _ hitObj: UnsafeMutablePointer<UnsafeMutablePointer<ObjNode>?>!, _ hitPt: UnsafeMutablePointer<OGLPoint3D>!, _ hitNormal: UnsafeMutablePointer<OGLVector3D>!, _ cTypes: UnsafeMutablePointer<UInt32>!) -> UInt8 {
    var coord = OGLPoint3D()
    var normal = OGLVector3D()
    var bestDist: Float = 1000000
    var hit = false
    let inCType = cTypes.pointee // get the input CType mask

    cTypes.pointee = 0 // clear the output CType mask

    // FIRST SEE IF RAY HITS ANY OBJNODES

    hitObj.pointee = OGL_DoRayCollision_ObjNodes(ray, UInt32(STATUS_BIT_HIDDEN), inCType, hitPt, hitNormal)
    if hitObj.pointee != nil {
        bestDist = ray.pointee.distance
        hit = true
    }

    // NEXT SEE IF HIT TERRAIN

    if inCType & UInt32(CTYPE_TERRAIN) != 0 {
        if OGL_DoRayCollision_Terrain(ray, &coord, &normal) != 0 {
            if ray.pointee.distance < bestDist {
                bestDist = ray.pointee.distance
                hitPt.pointee = coord
                hitNormal.pointee = normal
                hit = true
                cTypes.pointee = UInt32(CTYPE_TERRAIN) // let caller know that we hit terrain
                hitObj.pointee = nil // nullify any obj hit from above
            }
        }
    }

    // SEE IF HIT FENCE / WATER: dead #if 0 block in the original C source, dropped.

    if hit {
        ray.pointee.distance = bestDist // pass back the best dist
    }

    return hit ? 1 : 0
}
