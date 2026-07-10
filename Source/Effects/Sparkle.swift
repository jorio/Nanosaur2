// Sparkle.swift - Port of Sparkle.c to Swift
//
// gSparkles/gEngine.sparkles.numSparkles are native Swift storage now (converted
// 2026-07-07): nothing in any .c file touches them anymore. gSparkles was
// a fixed-size C array exposed via SparkleInternal.h's GetSparkleSlot
// shim; it's now a permanent, never-freed UnsafeMutablePointer buffer,
// with the accessor reimplemented in plain Swift under the same name/
// signature so its many call sites elsewhere didn't need to change.

/// Sparkle state. Owned by GameEngine as `gEngine.sparkles`.
final class SparkleSystem {
    var numSparkles: Int32 = 0

    fileprivate let buf: UnsafeMutablePointer<SparkleType> = {
        let buf = UnsafeMutablePointer<SparkleType>.allocate(capacity: 600)
        buf.initialize(repeating: SparkleType(), count: 600)
        return buf
    }()

    fileprivate var playerSparkleColor: Float = 0
}
func GetSparkleSlot(_ i: Int32) -> UnsafeMutablePointer<SparkleType>! {
    gEngine.sparkles.buf + Int(i)
}

extension UnsafeMutablePointer where Pointee == SparkleType {
    var isActive: Bool {
        get { pointee.isActive != 0 }
        nonmutating set { pointee.isActive = newValue ? 1 : 0 }
    }
}


func InitSparkles() {
    for i in 0..<Int32(MAX_SPARKLES) {
        GetSparkleSlot(i)!.isActive = false
    }

    gEngine.sparkles.playerSparkleColor = 0

    gEngine.sparkles.numSparkles = 0
}

// OUTPUT: -1 if none
func GetFreeSparkle(_ theNode: UnsafeMutablePointer<ObjNode>?) -> Int16 {
    // FIND A FREE SLOT
    var i: Int32 = 0
    while i < Int32(MAX_SPARKLES) {
        if !GetSparkleSlot(i)!.isActive {
            let slot = GetSparkleSlot(i)!
            slot.isActive = true
            slot.pointee.owner = theNode
            gEngine.sparkles.numSparkles += 1
            return Int16(i)
        }
        i += 1
    }
    return -1
}

func DeleteSparkle(_ i: Int16) {
    if i == -1 {
        return
    }

    let slot = GetSparkleSlot(Int32(i))!
    if slot.isActive {
        slot.isActive = false
        gEngine.sparkles.numSparkles -= 1
    } else {
        SwAlert("DeleteSparkle: double delete sparkle")
    }
}

func DrawSparkles() {
    let up = OGLVector3D(x: 0, y: 1, z: 0)
    var frame: InlineArray<4, OGLPoint3D> = [
        OGLPoint3D(x: -130, y: 130, z: 0),
        OGLPoint3D(x: 130, y: 130, z: 0),
        OGLPoint3D(x: 130, y: -130, z: 0),
        OGLPoint3D(x: -130, y: -130, z: 0),
    ]

    // DRAW EACH SPARKLE

    // cameraPlacement is a fixed-size array (imports as a tuple); rebind to
    // index it dynamically by gCurrentSplitScreenPane.
    let cameraPlacementsBase = UnsafeMutableRawPointer(gEngine.game.viewInfoPtr!.pointer(to: \.cameraPlacement)!).assumingMemoryBound(to: OGLCameraPlacement.self)
    let cam = cameraPlacementsBase + Int(gCurrentSplitScreenPane) // point to camera coord

    var i: Int32 = 0
    while i < Int32(MAX_SPARKLES) {
        defer { i += 1 }

        let sparkle = GetSparkleSlot(i)!

        if !sparkle.isActive { // must be active
            continue
        }

        let flags = sparkle.pointee.flags // get sparkle flags
        let omni = (flags & UInt32(SPARKLE_FLAG_OMNIDIRECTIONAL)) != 0 // is it omni-directional?

        let owner = sparkle.pointee.owner
        var where_ = OGLPoint3D(x: 0, y: 0, z: 0)
        var aim = OGLVector3D(x: 0, y: 0, z: 0)

        if let owner { // if owner is culled on this pane then dont draw
            if (flags & UInt32(SPARKLE_FLAG_ALWAYSDRAW)) == 0 {
                if (owner.pointee.StatusBits & ((UInt32(STATUS_BIT_ISCULLED1) << UInt32(gCurrentSplitScreenPane)) | UInt32(STATUS_BIT_HIDDEN))) != 0 {
                    continue
                }
            }

            // SEE IF TRANSFORM WITH OWNER

            if (flags & UInt32(SPARKLE_FLAG_TRANSFORMWITHOWNER)) != 0 {
                where_ = sparkle.pointee.`where`.transformed(by: owner.pointee.BaseTransformMatrix)
                if !omni {
                    aim = sparkle.pointee.aim.transformed(by: owner.pointee.BaseTransformMatrix)
                }
            } else {
                where_ = sparkle.pointee.`where`
                if !omni {
                    aim = sparkle.pointee.aim
                }
            }
        } else {
            where_ = sparkle.pointee.`where`
            if !omni {
                aim = sparkle.pointee.aim
            }
        }

        // CALC ANGLE INFO

        var v = OGLVector3D(x: 0, y: 0, z: 0)
        v.x = cam.pointee.cameraLocation.x - where_.x // calc vector from sparkle to camera
        v.y = cam.pointee.cameraLocation.y - where_.y
        v.z = cam.pointee.cameraLocation.z - where_.z
        FastNormalizeVector(v.x, v.y, v.z, &v)

        let separation = sparkle.pointee.separation
        where_.x += v.x * separation // offset the base point
        where_.y += v.y * separation
        where_.z += v.z * separation

        if !omni { // if not omni then calc alpha based on angle
            let dot = v.dot(aim) // calc angle between
            if dot <= 0.0 {
                continue
            }

            sparkle.pointee.color.a = dot // make brighter as we look head-on
        }

        // CALC TRANSFORM MATRIX

        frame[0].x = -sparkle.pointee.scale // set size of quad
        frame[0].y = sparkle.pointee.scale
        frame[1].x = sparkle.pointee.scale
        frame[1].y = sparkle.pointee.scale
        frame[2].x = sparkle.pointee.scale
        frame[2].y = -sparkle.pointee.scale
        frame[3].x = -sparkle.pointee.scale
        frame[3].y = -sparkle.pointee.scale

        var m = OGLMatrix4x4()
        var up_ = up
        SetLookAtMatrixAndTranslate(&m, &up_, &where_, cam.pointer(to: \.cameraLocation)!) // aim at camera & translate
        var tc: InlineArray<4, OGLPoint3D> = InlineArray(repeating: OGLPoint3D(x: 0, y: 0, z: 0))
        for i in 0..<4 {
            tc[i] = frame[i].transformed(by: m)
        }

        // DRAW IT

        // SET ALPHA

        if (flags & UInt32(SPARKLE_FLAG_FLICKER)) != 0 { // randomly flicker alpha
            var a = sparkle.pointee.color.a

            a += RandomFloat2() * 0.5
            if a < 0.0 {
                continue
            } else if a > 1.0 {
                a = 1.0
            }

            gEngine.metaObjects.globalTransparency = a
        } else {
            gEngine.metaObjects.globalTransparency = sparkle.pointee.color.a
        }

        // SUBMIT MATERIAL

        let sprite = GetSpriteGroupPtr(Int32(SPRITE_GROUP_PARTICLES))![Int(sparkle.pointee.textureNum)]
        MO_DrawMaterial(sprite.materialObject!.assumingMemoryBound(to: MOMaterialObject.self)) // submit material

        // DRAW QUAD

        gEngine.renderer.beginImmediate(.quads)
        gEngine.renderer.texCoord2f(0, 0); gEngine.renderer.vertex3f(tc[0].x, tc[0].y, tc[0].z)
        gEngine.renderer.texCoord2f(1, 0); gEngine.renderer.vertex3f(tc[1].x, tc[1].y, tc[1].z)
        gEngine.renderer.texCoord2f(1, 1); gEngine.renderer.vertex3f(tc[2].x, tc[2].y, tc[2].z)
        gEngine.renderer.texCoord2f(0, 1); gEngine.renderer.vertex3f(tc[3].x, tc[3].y, tc[3].z)
        gEngine.renderer.endImmediate()
    }

    // RESTORE STATE

    gEngine.metaObjects.globalTransparency = 1.0
}
