// Enemy.swift - Port of Enemy.c to Swift

var gNumEnemyOfKind: [Int8] = Array(repeating: 0, count: EnemyKind.allCases.count)
var gNumEnemies: Int32 = 0
var gMaxEnemies: Int32 = 0

func InitEnemyManager() {
    gNumEnemies = 0
    gMaxEnemies = 16

    for i in 0..<gNumEnemyOfKind.count {
        gNumEnemyOfKind[i] = 0
    }
}

func DeleteEnemy(_ theEnemy: UnsafeMutablePointer<ObjNode>!) {
    if !theEnemy.hasStatus(STATUS_BIT_ONSPLINE) { // spline enemies dont factor into the enemy counts!
        gNumEnemyOfKind[Int(theEnemy.pointee.Kind)] -= 1 // dec kind count
        if gNumEnemyOfKind[Int(theEnemy.pointee.Kind)] < 0 {
            SwAlert("DeleteEnemy: < 0")
            gNumEnemyOfKind[Int(theEnemy.pointee.Kind)] = 0
        }

        gNumEnemies -= 1 // dec global count
    }

    DeleteObject(theEnemy) // nuke the obj
}

func UpdateEnemy(_ theNode: UnsafeMutablePointer<ObjNode>!) {
    theNode.pointee.Speed = gEngine.objects.delta.length

    theNode.update()
}

// This routine creates a non-character skeleton which is an enemy.
//
// INPUT:	itemPtr->parm[0] = skeleton type 0..n
//
// OUTPUT:	ObjNode or nil if err.
func MakeEnemySkeleton(_ skeletonType: UInt8, _ animNum: Int16, _ x: Float, _ z: Float, _ scale: Float, _ rot: Float, _ moveCall: (@convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void)!) -> UnsafeMutablePointer<ObjNode>! {
    // MAKE NEW SKELETON OBJECT

    var def = NewObjectDefinitionType()
    def.type = skeletonType
    def.animNum = UInt8(animNum)
    def.coord.x = x
    def.coord.y = GetTerrainY(x, z)
    def.coord.z = z
    def.flags = gAutoFadeStatusBits
    def.slot = Int16(ENEMY_SLOT) + Int16(skeletonType)
    def.moveCall = moveCall
    def.rot = rot
    def.scale = scale

    let newObj = MakeNewSkeletonObject(&def)!

    // SET DEFAULT COLLISION INFO
    //
    // Enemies have collision boxes, but they're not used for player collision detection.
    // Player's use CTYPE_PLAYERTEST for line-segment testing on the actual polys for accuracy

    newObj.pointee.CType = UInt32(CTYPE_ENEMY) | UInt32(CTYPE_BLOCKCAMERA) | UInt32(CTYPE_AUTOTARGETWEAPON) | UInt32(CTYPE_PLAYERTEST) | UInt32(CTYPE_WEAPONTEST)
    newObj.pointee.CBits = UInt32(CBITS_NOTTOP)

    newObj.pointee.Coord.y -= newObj.pointee.LocalBBox.min.y // offset so bottom touches ground
    newObj.updateTransforms()

    return newObj
}

// OUTPUT: true if was on spline, false if wasnt
func DetachEnemyFromSpline(_ theNode: UnsafeMutablePointer<ObjNode>!, _ moveCall: (@convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void)!) {
    guard theNode.hasStatus(STATUS_BIT_ONSPLINE) else { // must be on spline
        return
    }

    DetachObjectFromSpline(theNode, moveCall)

    gNumEnemies += 1 // count as a normal enemy now
    gNumEnemyOfKind[Int(theNode.pointee.Kind)] += 1
}

// OUTPUT: nil if no enemies
func FindClosestEnemy(_ pt: UnsafeMutablePointer<OGLPoint3D>!, _ dist: UnsafeMutablePointer<Float>!) -> UnsafeMutablePointer<ObjNode>! {
    var best: UnsafeMutablePointer<ObjNode>?
    var minDist: Float = 10_000_000

    for node in usableObjectNodes {
        if node.pointee.CType & UInt32(CTYPE_ENEMY) != 0 {
            let d = CalcQuickDistance(pt.pointee.x, pt.pointee.z, node.pointee.Coord.x, node.pointee.Coord.z)
            if d < minDist {
                minDist = d
                best = node
            }
        }
    }

    dist.pointee = minDist
    return best
}

// coord is in gEngine.objects.coord
func IsWaterInFrontOfEnemy(_ r: Float) -> UInt8 {
    let x = gEngine.objects.coord.x - sin(r) * 30.0
    let z = gEngine.objects.coord.z - cos(r) * 30.0

    return IsXZOverWater(x, z)
}

// For use by non-skeleton enemies.
//
// OUTPUT: true = was deleted
func DoEnemyCollisionDetect(_ theEnemy: UnsafeMutablePointer<ObjNode>!, _ ctype: UInt32, _ useBBoxBottom: UInt8) -> UInt8 {
    var ctype = ctype
    let wasInWater = theEnemy.pointee.StatusBits & UInt32(STATUS_BIT_UNDERWATER) // see if was in H2O on previous frame

    // AUTOMATICALLY HANDLE THE BORING STUFF

    _ = HandleCollisions(theEnemy, ctype, -0.9)

    // SCAN FOR INTERESTING STUFF

    for i in 0..<Int32(gEngine.collision.numCollisions) {
        let entry = GetCollisionListEntry(i)!
        if entry.pointee.type == UInt8(COLLISION_TYPE_OBJ) {
            guard let hitObj = entry.pointee.objectPtr else { continue } // get ObjNode of this collision
            ctype = hitObj.pointee.CType

            if ctype == UInt32(INVALID_NODE_FLAG) { // see if has since become invalid
                continue
            }

            // HURT

            if ctype & UInt32(CTYPE_HURTENEMY) != 0 {
                if let hurtCallback = theEnemy.pointee.HurtCallback { // if has a hurt callback
                    if hurtCallback(theEnemy, hitObj.pointee.Damage) != 0 { // handle hit (returns true if was deleted)
                        return 1
                    }
                }
            }

            // TOUCHED PLAYER

            else if ctype & (UInt32(CTYPE_PLAYER1) | UInt32(CTYPE_PLAYER2)) != 0 {
                EnemyTouchedPlayer(theEnemy, hitObj)
            }
        }
    }

    // CHECK & HANDLE TERRAIN COLLISION

    let bottomOff = useBBoxBottom != 0 ? theEnemy.pointee.LocalBBox.min.y : theEnemy.pointee.BottomOff // use bbox's bottom or collision box's bottom

    let terrainY = GetTerrainY(gEngine.objects.coord.x, gEngine.objects.coord.z) // get terrain Y
    let distToFloor = (gEngine.objects.coord.y + bottomOff) - terrainY // calc amount I'm above or under

    if distToFloor <= 0.0 { // see if on or under floor
        gEngine.objects.coord.y = terrainY - bottomOff
        gEngine.objects.delta.y = 0
        theEnemy.setStatus(STATUS_BIT_ONGROUND)

        // DEAL WITH SLOPES
        //
        // Using the floor normal here, apply some deltas to it.
        // Only apply slopes when on the ground (or really close to it)
    }

    // SEE IF HIT WATER SURFACE

    if ctype & UInt32(CTYPE_WATER) != 0 {
        if gEngine.objects.delta.y <= 0.0 { // only check water if moving down
            var patchNum: Int32 = 0

            // CHECK IF IN WATER NOW

            if DoWaterCollisionDetect(theEnemy, gEngine.objects.coord.x, gEngine.objects.coord.y + theEnemy.pointee.BottomOff, gEngine.objects.coord.z, &patchNum) != 0 {
                let waterY = GetWaterBBoxEntry(patchNum)!.pointee.max.y
                var splashPt = OGLPoint3D()

                // MAKE SPLASH IF THIS IS A FIRST TOUCH OF THE WATER

                if wasInWater == 0 {
                    // (no-op in the original C too — commented out)
                }

                // OTHERWISE JUST UPDATE RIPPLES
                else {
                    theEnemy.pointee.SpecialF.4 -= gFramesPerSecondFrac // EnemyWaterRippleTimer
                    if theEnemy.pointee.SpecialF.4 <= 0.0 {
                        theEnemy.pointee.SpecialF.4 += 0.1
                        splashPt.x = gEngine.objects.coord.x
                        splashPt.y = waterY
                        splashPt.z = gEngine.objects.coord.z
                        CreateNewRipple(&splashPt, 30.0, 50.0, 0.7)
                    }
                }

                gEngine.objects.delta.y = 0
            }
        }
    }

    return 0
}

func EnemyTouchedPlayer(_ enemy: UnsafeMutablePointer<ObjNode>!, _ player: UnsafeMutablePointer<ObjNode>!) {
    switch enemy.pointee.Kind {
    // case ENEMY_KIND_COMPUTERBUG: ComputerBugTouchedPlayer(enemy, player)
    default:
        break
    }
}

func MoveEnemySkipChunk(_ chunk: UnsafeMutablePointer<ObjNode>!) {
    let fps = gFramesPerSecondFrac

    chunk.getInfo()

    gEngine.objects.delta.y -= 2000.0 * fps // gravity

    gEngine.objects.coord.x += gEngine.objects.delta.x * fps
    gEngine.objects.coord.y += gEngine.objects.delta.y * fps
    gEngine.objects.coord.z += gEngine.objects.delta.z * fps

    if gEngine.objects.coord.y < (GetTerrainY(gEngine.objects.coord.x, gEngine.objects.coord.z) - 600.0) { // see if gone
        DeleteObject(chunk)
        return
    }

    chunk.pointee.Rot.x += chunk.pointee.DeltaRot.x * fps
    chunk.pointee.Rot.y += chunk.pointee.DeltaRot.y * fps
    chunk.pointee.Rot.z += chunk.pointee.DeltaRot.z * fps

    chunk.update()
}
