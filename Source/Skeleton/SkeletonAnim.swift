// SkeletonAnim.swift - Port of SkeletonAnim.c to Swift
//
// gAccelerationCurve/gEngine.skeletons.disableAnimSounds are native Swift storage now
// (converted 2026-07-07): nothing in any .c file touches them anymore.
// gAccelerationCurve was a fixed-size C array exposed via skeleton.h's
// GetAccelerationCurvePtr shim; it's now a permanent, never-freed
// UnsafeMutablePointer buffer, with the accessor reimplemented in plain
// Swift under the same name/signature.


private let curveSize = 2000

private let gAccelerationCurveBuf: UnsafeMutablePointer<Float> = {
    let buf = UnsafeMutablePointer<Float>.allocate(capacity: curveSize)
    buf.initialize(repeating: 0, count: curveSize)
    return buf
}()
func GetAccelerationCurvePtr() -> UnsafeMutablePointer<Float>! { gAccelerationCurveBuf }
private let maxJoints = 40
private let maxFlagsInObjNode = 5

private let accelModeLinear = Int32(AccelerationMode.linear.rawValue)
private let accelModeEaseInOut = Int32(AccelerationMode.easeInOut.rawValue)
private let accelModeEaseIn = Int32(AccelerationMode.easeIn.rawValue)
private let accelModeEaseOut = Int32(AccelerationMode.easeOut.rawValue)

@inline(__always) private func jointKeyframesBase(_ skeletonDef: UnsafeMutablePointer<SkeletonDefType>) -> UnsafeMutablePointer<JointKeyFrameHeader> {
    UnsafeMutableRawPointer(skeletonDef.pointer(to: \.JointKeyframes)!).assumingMemoryBound(to: JointKeyFrameHeader.self)
}

@inline(__always) private func numKeyFramesBase(_ header: UnsafeMutablePointer<JointKeyFrameHeader>) -> UnsafeMutablePointer<Int8> {
    UnsafeMutableRawPointer(header.pointer(to: \.numKeyFrames)!).assumingMemoryBound(to: Int8.self)
}

@inline(__always) private func jointCurrentPositionBase(_ skeleton: UnsafeMutablePointer<SkeletonObjDataType>) -> UnsafeMutablePointer<JointKeyframeType> {
    UnsafeMutableRawPointer(skeleton.pointer(to: \.JointCurrentPosition)!).assumingMemoryBound(to: JointKeyframeType.self)
}

@inline(__always) private func morphStartBase(_ skeleton: UnsafeMutablePointer<SkeletonObjDataType>) -> UnsafeMutablePointer<JointKeyframeType> {
    UnsafeMutableRawPointer(skeleton.pointer(to: \.MorphStart)!).assumingMemoryBound(to: JointKeyframeType.self)
}

@inline(__always) private func morphEndBase(_ skeleton: UnsafeMutablePointer<SkeletonObjDataType>) -> UnsafeMutablePointer<JointKeyframeType> {
    UnsafeMutableRawPointer(skeleton.pointer(to: \.MorphEnd)!).assumingMemoryBound(to: JointKeyframeType.self)
}

private func setObjNodeFlag(_ node: UnsafeMutablePointer<ObjNode>, _ flagNum: UInt8, _ value: UInt8) {
    switch Int(flagNum) {
    case 0: node.pointee.Flag.0 = Int8(value)
    case 1: node.pointee.Flag.1 = Int8(value)
    case 2: node.pointee.Flag.2 = Int8(value)
    case 3: node.pointee.Flag.3 = Int8(value)
    case 4: node.pointee.Flag.4 = Int8(value)
    case 5: node.pointee.Flag.5 = Int8(value)
    default: break
    }
}

func SetSkeletonAnimTime(_ skeleton: UnsafeMutablePointer<SkeletonObjDataType>!, _ timeRatio: Float) {
    let def = skeleton.pointee.skeletonDefinition!
    let time = skeleton.pointee.MaxAnimTime * timeRatio
    skeleton.pointee.CurrentAnimTime = time
    let timeInt = Int16(time)

    // SET ANIM EVENT INDEX BASED ON TIME

    let animNum = Int(skeleton.pointee.AnimNum)
    let numAnimEvents = Int(def.pointee.NumAnimEvents![animNum])
    let events = def.pointee.AnimEventsList![animNum]!

    for i in 0..<numAnimEvents {
        if events[i].time >= timeInt {
            skeleton.pointee.AnimEventIndex = UInt8(i)
            break
        }
    }
}

func SetSkeletonAnim(_ skeleton: UnsafeMutablePointer<SkeletonObjDataType>!, _ animNum: Int) {
    setSkeletonAnimGuts(skeleton, animNum)

    GetModelCurrentPosition(skeleton) // update matrices
}

// PlayerAnim boundary overloads - the player is the only skeleton whose anim
// numbers are a Swift enum (enemy anims are still plain Int constants local
// to each enemy file), so these let player call sites drop the
// Int(...rawValue) cast noise.
func SetSkeletonAnim(_ skeleton: UnsafeMutablePointer<SkeletonObjDataType>!, _ anim: PlayerAnim) {
    SetSkeletonAnim(skeleton, Int(anim.rawValue))
}

func MorphToSkeletonAnim(_ skeleton: UnsafeMutablePointer<SkeletonObjDataType>!, _ anim: PlayerAnim, _ speed: Float) {
    MorphToSkeletonAnim(skeleton, Int(anim.rawValue), speed)
}

private func setSkeletonAnimGuts(_ skeleton: UnsafeMutablePointer<SkeletonObjDataType>?, _ animNum: Int) {
    guard let skeleton else { return }

    if animNum >= Int(skeleton.pointee.skeletonDefinition!.pointee.NumAnims) {
        SwFatal("SetSkeletonAnim: illegal animNum")
    }

    skeleton.pointee.LoopBackTime = 0
    skeleton.pointee.AnimNum = UInt8(animNum)
    skeleton.pointee.AnimDirection = UInt8(AnimDirection.forward.rawValue)
    skeleton.pointee.AnimEventIndex = 0
    skeleton.pointee.CurrentAnimTime = 0
    skeleton.pointee.PauseTimer = 0
    skeleton.pointee.MaxAnimTime = calcMaxKeyFrameTime(skeleton)
    skeleton.animHasStopped = false
    skeleton.isMorphing = false
    skeleton.pointee.AnimSpeed = 1.0
}

func MorphToSkeletonAnim(_ skeleton: UnsafeMutablePointer<SkeletonObjDataType>!, _ animNum: Int, _ speed: Float) {
    // SET THE USUAL STUFF FIRST

    guard let skeleton else { return }

    if animNum >= Int(skeleton.pointee.skeletonDefinition!.pointee.NumAnims) {
        SwFatal("MorphToSkeletonAnim: bad anim #")
    }

    setSkeletonAnimGuts(skeleton, animNum)

    let skeletonDef = skeleton.pointee.skeletonDefinition!
    let jointKeyframes = jointKeyframesBase(skeletonDef)
    let jointCurrentPosition = jointCurrentPositionBase(skeleton)
    let morphStart = morphStartBase(skeleton)
    let morphEnd = morphEndBase(skeleton)

    // NOW SET MORPHING STUFF

    skeleton.isMorphing = true
    skeleton.pointee.MorphPercent = 0
    skeleton.pointee.MorphSpeed = speed

    for j in 0..<Int(skeletonDef.pointee.NumBones) {
        morphStart[j] = jointCurrentPosition[j]

        let numKeyFrames = numKeyFramesBase(jointKeyframes + j)
        if numKeyFrames[animNum] > 0 {
            morphEnd[j] = jointKeyframes[j].keyFrames![animNum]![0]
        } else {
            morphEnd[j] = jointCurrentPosition[j]
        }
    }

    GetModelCurrentPosition(skeleton) // update matrices
}

func UpdateSkeletonAnimation(_ theNode: UnsafeMutablePointer<ObjNode>!) {
    guard let skeleton = theNode.pointee.Skeleton else { return }
    let skeletonDef = skeleton.pointee.skeletonDefinition!
    let fps = gEngine.framesPerSecondFrac

    // IF JUST GOT A MORPH POSITION, THEN UPDATE MORPH

    if skeleton.isMorphing {
        skeleton.pointee.MorphPercent += skeleton.pointee.MorphSpeed * fps
        if skeleton.pointee.MorphPercent >= 1.0 {
            skeleton.isMorphing = false
        }
        GetModelCurrentPosition(skeleton)
        return
    }

    // GET SOME BASIC INFO

    let animNum = Int(skeleton.pointee.AnimNum)
    var animEventIndex = skeleton.pointee.AnimEventIndex
    var currentTime = skeleton.pointee.CurrentAnimTime
    var animDirection = skeleton.pointee.AnimDirection
    var loopbackTime = skeleton.pointee.LoopBackTime

    // INCREMENT TIME INDEX

    if skeleton.pointee.PauseTimer > 0.0 {
        skeleton.pointee.PauseTimer -= gEngine.framesPerSecondFrac
    } else {
        if animDirection == UInt8(AnimDirection.forward.rawValue) {
            currentTime += (30.0 * fps) * skeleton.pointee.AnimSpeed
        } else {
            currentTime -= (30.0 * fps) * skeleton.pointee.AnimSpeed
            if currentTime < loopbackTime {
                currentTime = loopbackTime + (loopbackTime - currentTime)
                switch Int(skeleton.pointee.EndMode) {
                case Int(AnimEventKind.zigzag.rawValue):
                    animDirection = UInt8(AnimDirection.forward.rawValue)
                    if loopbackTime == 0 {
                        animEventIndex = 0
                    } else {
                        animEventIndex = getNextAnimEventAtTime(skeleton, currentTime)
                    }

                default:
                    skeleton.animHasStopped = true
                }
            }
        }
    }

    // CHECK FOR ANIM EVENTS

    var loopCount: UInt8 = 0
    let events = skeletonDef.pointee.AnimEventsList![animNum]!

    while animEventIndex < skeletonDef.pointee.NumAnimEvents![animNum]
            && currentTime >= Float(events[Int(animEventIndex)].time) {
        let event = events[Int(animEventIndex)]
        let eventTime = Float(event.time)
        let eventType = event.type
        let eventValue = event.value

        switch Int(eventType) {
        case Int(AnimEventKind.stop.rawValue):
            skeleton.animHasStopped = true
            animEventIndex += 1

        case Int(AnimEventKind.setMarker.rawValue):
            animEventIndex += 1
            skeleton.pointee.LoopBackTime = eventTime
            loopbackTime = eventTime

        case Int(AnimEventKind.loop.rawValue):
            loopCount += 1
            if loopbackTime != 0 {
                currentTime -= eventTime
                currentTime += loopbackTime
                animEventIndex = getNextAnimEventAtTime(skeleton, currentTime)
            } else {
                if currentTime != 0 {
                    currentTime -= eventTime
                    animEventIndex = 0
                } else {
                    skeleton.animHasStopped = true
                    animEventIndex += 1
                }
            }

        case Int(AnimEventKind.zigzag.rawValue):
            loopCount += 1
            animDirection = UInt8(AnimDirection.backward.rawValue)
            currentTime -= eventTime - currentTime
            skeleton.pointee.EndMode = UInt8(AnimEventKind.zigzag.rawValue)
            animEventIndex += 1

        case Int(AnimEventKind.setFlag.rawValue):
            if eventValue >= maxFlagsInObjNode {
                SwFatal("Error: ANIMEVENT_TYPE_SETFLAG > MAX_FLAGS_IN_OBJNODE!")
            }
            setObjNodeFlag(theNode, eventValue, 1)
            animEventIndex += 1

        case Int(AnimEventKind.clearFlag.rawValue):
            if eventValue >= maxFlagsInObjNode {
                SwFatal("Error: ANIMEVENT_TYPE_SETFLAG > MAX_FLAGS_IN_OBJNODE!")
            }
            setObjNodeFlag(theNode, eventValue, 0)
            animEventIndex += 1

        case Int(AnimEventKind.playSound.rawValue):
            if gEngine.skeletons.disableAnimSounds == 0 {
                switch eventValue {
                case 0:
                    break

                default:
                    break
                }
            }
            animEventIndex += 1

        case Int(AnimEventKind.pause.rawValue):
            skeleton.pointee.PauseTimer = Float(eventValue) / 30.0
            currentTime = eventTime
            animEventIndex += 1

        default:
            animEventIndex += 1
        }

        if loopCount > 1 {
            break
        }
    }

    // UPDATE OBJ RECORD

    skeleton.pointee.CurrentAnimTime = currentTime
    skeleton.pointee.AnimDirection = animDirection
    skeleton.pointee.AnimEventIndex = animEventIndex

    // UPDATE ALL OF THE TRANSFORMS & SUCH

    GetModelCurrentPosition(skeleton)
}

func GetModelCurrentPosition(_ skeleton: UnsafeMutablePointer<SkeletonObjDataType>!) {
    let animNum = Int(skeleton.pointee.AnimNum)
    let currentAnimTime = skeleton.pointee.CurrentAnimTime
    let currentAnimTimeInt = Int32(currentAnimTime)
    let skeletonDef = skeleton.pointee.skeletonDefinition!

    if skeleton.jointsAreGlobal {
        return
    }

    let jointKeyframes = jointKeyframesBase(skeletonDef)
    let jointCurrentPosition = jointCurrentPositionBase(skeleton)

    // GET INFO FOR EACH JOINT

    for jointNum in 0..<Int(skeletonDef.pointee.NumBones) {
        // SEE IF MORPHING

        if skeleton.isMorphing {
            getModelMorphPosition(skeleton, jointNum, jointCurrentPosition + jointNum)
        } else {
            // SCAN KEYFRAMES FOR CURRENT TIME

            let numKeyFrames = Int(numKeyFramesBase(jointKeyframes + jointNum)[animNum])
            if numKeyFrames == 0 {
                return
            }

            var didUpdate = false
            for keyFrameNum in 0..<numKeyFrames {
                let kfPtr = jointKeyframes[jointNum].keyFrames![animNum]! + keyFrameNum

                if kfPtr.pointee.tick > currentAnimTimeInt {
                    if keyFrameNum == 0 {
                        jointCurrentPosition[jointNum] = kfPtr.pointee
                    } else {
                        interpolateKeyFrames(
                            jointKeyframes[jointNum].keyFrames![animNum]! + (keyFrameNum - 1),
                            kfPtr,
                            jointCurrentPosition + jointNum,
                            currentAnimTime)
                    }
                    didUpdate = true
                    break
                }
            }

            if !didUpdate {
                jointCurrentPosition[jointNum] = jointKeyframes[jointNum].keyFrames![Int(skeleton.pointee.AnimNum)]![numKeyFrames - 1]
            }
        }

        // UPDATE SKELETON VIEW

        UpdateJointTransforms(skeleton, jointNum)
    }
}

private func getModelMorphPosition(_ skeleton: UnsafeMutablePointer<SkeletonObjDataType>, _ jointNum: Int, _ interpKf: UnsafeMutablePointer<JointKeyframeType>) {
    let morphStart = morphStartBase(skeleton)
    let morphEnd = morphEndBase(skeleton)
    let kf1 = morphStart + jointNum
    let kf2 = morphEnd + jointNum
    let k2Percent = skeleton.pointee.MorphPercent
    let k1Percent = 1.0 - k2Percent

    // CALC NEW INTERPOLATED DATA

    interpKf.pointee.coord.x = (kf1.pointee.coord.x * k1Percent) + (kf2.pointee.coord.x * k2Percent)
    interpKf.pointee.coord.y = (kf1.pointee.coord.y * k1Percent) + (kf2.pointee.coord.y * k2Percent)
    interpKf.pointee.coord.z = (kf1.pointee.coord.z * k1Percent) + (kf2.pointee.coord.z * k2Percent)
    interpKf.pointee.rotation.x = (kf1.pointee.rotation.x * k1Percent) + (kf2.pointee.rotation.x * k2Percent)
    interpKf.pointee.rotation.y = (kf1.pointee.rotation.y * k1Percent) + (kf2.pointee.rotation.y * k2Percent)
    interpKf.pointee.rotation.z = (kf1.pointee.rotation.z * k1Percent) + (kf2.pointee.rotation.z * k2Percent)

    if kf1.pointee.scale.x != 1.0 || kf2.pointee.scale.x != 1.0 {
        interpKf.pointee.scale.z = (kf1.pointee.scale.z * k1Percent) + (kf2.pointee.scale.z * k2Percent)
        interpKf.pointee.scale.y = interpKf.pointee.scale.z
        interpKf.pointee.scale.x = interpKf.pointee.scale.y
    } else {
        interpKf.pointee.scale.z = 1.0
        interpKf.pointee.scale.y = interpKf.pointee.scale.z
        interpKf.pointee.scale.x = interpKf.pointee.scale.y
    }
}

private func interpolateKeyFrames(_ kf1: UnsafeMutablePointer<JointKeyframeType>, _ kf2: UnsafeMutablePointer<JointKeyframeType>, _ interpKf: UnsafeMutablePointer<JointKeyframeType>, _ currentTime: Float) {
    let one: Float = 1.0

    // GET ACCELERATION MODE

    let accMode1 = kf1.pointee.accelerationMode
    let accMode2 = kf2.pointee.accelerationMode
    let accMode3: Int32

    if accMode1 == accelModeEaseInOut || accMode1 == accelModeEaseOut {
        if accMode2 == accelModeEaseInOut || accMode2 == accelModeEaseIn {
            accMode3 = accelModeEaseInOut
        } else {
            accMode3 = accelModeEaseOut
        }
    } else {
        if accMode2 == accelModeEaseInOut || accMode2 == accelModeEaseIn {
            accMode3 = accelModeEaseIn
        } else {
            accMode3 = accelModeLinear
        }
    }

    // CALC K1/K2 RATIOS

    let time1 = Float(kf1.pointee.tick)
    let time2 = Float(kf2.pointee.tick)
    let diffA = time2 - time1
    let diffB = currentTime - time1
    var k2Percent = diffB / diffA
    var k1Percent = one - k2Percent

    // HANDLE SPECIAL ACCELERATION MODES

    switch accMode3 {
    case accelModeEaseInOut:
        k1Percent = accelerationPercent(k1Percent)
        k2Percent = one - k1Percent

    case accelModeEaseIn:
        k1Percent = accelerationPercent(0.5 * k1Percent)
        k1Percent *= 2.0
        if k1Percent > one {
            k1Percent = one
        } else if k1Percent < 0.0 {
            k1Percent = 0.0
        }
        k2Percent = 1.0 - k1Percent

    case accelModeEaseOut:
        k2Percent = accelerationPercent(0.5 * k2Percent)
        k2Percent *= 2.0
        if k2Percent > one {
            k2Percent = one
        } else if k2Percent < 0.0 {
            k2Percent = 0.0
        }
        k1Percent = one - k2Percent

    default:
        break
    }

    // CALC NEW INTERPOLATED DATA

    interpKf.pointee.coord.x = (kf1.pointee.coord.x * k1Percent) + (kf2.pointee.coord.x * k2Percent)
    interpKf.pointee.coord.y = (kf1.pointee.coord.y * k1Percent) + (kf2.pointee.coord.y * k2Percent)
    interpKf.pointee.coord.z = (kf1.pointee.coord.z * k1Percent) + (kf2.pointee.coord.z * k2Percent)
    interpKf.pointee.rotation.x = (kf1.pointee.rotation.x * k1Percent) + (kf2.pointee.rotation.x * k2Percent)
    interpKf.pointee.rotation.y = (kf1.pointee.rotation.y * k1Percent) + (kf2.pointee.rotation.y * k2Percent)
    interpKf.pointee.rotation.z = (kf1.pointee.rotation.z * k1Percent) + (kf2.pointee.rotation.z * k2Percent)

    if kf1.pointee.scale.x != one || kf2.pointee.scale.x != one {
        interpKf.pointee.scale.z = (kf1.pointee.scale.z * k1Percent) + (kf2.pointee.scale.z * k2Percent)
        interpKf.pointee.scale.y = interpKf.pointee.scale.z
        interpKf.pointee.scale.x = interpKf.pointee.scale.y
    } else {
        interpKf.pointee.scale.z = one
        interpKf.pointee.scale.y = interpKf.pointee.scale.z
        interpKf.pointee.scale.x = interpKf.pointee.scale.y
    }
}

private func calcMaxKeyFrameTime(_ skeleton: UnsafeMutablePointer<SkeletonObjDataType>) -> Float {
    var maxTime: Int32 = 0
    let skeletonDef = skeleton.pointee.skeletonDefinition!
    let jointKeyframes = jointKeyframesBase(skeletonDef)
    let animNum = Int(skeleton.pointee.AnimNum)

    for jointNum in 0..<Int(skeletonDef.pointee.NumBones) {
        let numKeyFrames = Int(numKeyFramesBase(jointKeyframes + jointNum)[animNum])
        for keyFrameNum in 0..<numKeyFrames {
            let time = jointKeyframes[jointNum].keyFrames![animNum]![keyFrameNum].tick
            if time > maxTime {
                maxTime = time
            }
        }
    }

    return Float(maxTime)
}

private func getNextAnimEventAtTime(_ skeleton: UnsafeMutablePointer<SkeletonObjDataType>, _ time: Float) -> UInt8 {
    let animNum = Int(skeleton.pointee.AnimNum)
    let skeletonDef = skeleton.pointee.skeletonDefinition!
    let numEvents = skeletonDef.pointee.NumAnimEvents![animNum]
    let events = skeletonDef.pointee.AnimEventsList![animNum]!

    for i in 0..<numEvents {
        if Float(events[Int(i)].time) >= time {
            return i
        }
    }

    return 0
}

func CalcAccelerationSplineCurve() {
    let accelerationCurve = GetAccelerationCurvePtr()!
    for i in 0..<curveSize {
        let x = Float(i) / Float(curveSize)
        let n = x * x * (3.0 - 2.0 * x)
        accelerationCurve[i] = n
    }
}

private func accelerationPercent(_ percent: Float) -> Float {
    let i = Int(Float(curveSize - 1) * percent)
    let accelerationCurve = GetAccelerationCurvePtr()!

    if accelerationCurve[i] > 1.0 {
        SwFatal(" gAccelerationCurve > 1.0")
    } else if accelerationCurve[i] < 0.0 {
        SwFatal(" gAccelerationCurve < 0")
    }

    if percent > 1.0 {
        SwFatal(" AccelerationPercent > 1.0")
    } else if percent < 0.0 {
        SwFatal(" AccelerationPercent < 0")
    }

    return accelerationCurve[i]
}

func BurnSkeleton(_ theNode: UnsafeMutablePointer<ObjNode>!, _ flameScale: Float) {
    let fps = gEngine.framesPerSecondFrac
    var groupDef = NewParticleGroupDefType()
    var newParticleDef = NewParticleDefType()
    var d = OGLVector3D()
    var jointCoord: InlineArray<40, OGLPoint3D> = InlineArray(repeating: OGLPoint3D())
    var p = OGLPoint3D()

    // CALC COORDS OF EACH JOINT

    let numJoints = Int(theNode.pointee.Skeleton!.pointee.skeletonDefinition!.pointee.NumBones)
    for i in 0..<numJoints {
        FindCoordOfJoint(theNode, i, &jointCoord[i])
    }

    // CREATE PARTICLE GROUP

    theNode.pointee.ParticleTimer -= fps
    if theNode.pointee.ParticleTimer <= 0.0 {
        theNode.pointee.ParticleTimer += 0.05

        var particleGroup = theNode.pointee.ParticleGroup
        var magicNum = theNode.pointee.ParticleMagicNum

        if particleGroup == -1 || VerifyParticleGroupMagicNum(particleGroup, magicNum) == 0 {
            magicNum = MyRandomLong()
            theNode.pointee.ParticleMagicNum = magicNum

            groupDef.magicNum = magicNum
            groupDef.particleType = .fallingSparks
            groupDef.flags = UInt32(PARTICLE_FLAGS_DONTCHECKGROUND)
            groupDef.gravity = -200
            groupDef.magnetism = 0
            groupDef.baseScale = flameScale
            groupDef.decayRate = 0.6
            groupDef.fadeRate = 1.2
            groupDef.particleTextureNum = UInt8(PARTICLE_SObjType_Fire)
            groupDef.srcBlend = Int32(GL_SRC_ALPHA)
            groupDef.dstBlend = Int32(GL_ONE)
            particleGroup = NewParticleGroup(&groupDef)
            theNode.pointee.ParticleGroup = particleGroup
        }

        // ADD TO PARTICLE GROUP

        if particleGroup != -1 {
            for i in 0..<numJoints {
                p.x = jointCoord[i].x + RandomFloat2() * 30.0
                p.y = jointCoord[i].y + RandomFloat2() * 30.0
                p.z = jointCoord[i].z + RandomFloat2() * 30.0

                d.x = 0
                d.y = 300.0 + RandomFloat() * 100.0
                d.z = 0

                newParticleDef.groupNum = particleGroup
                newParticleDef.scale = 1.0 + RandomFloat() * 0.5
                newParticleDef.rotZ = RandomFloat() * SwPI2
                newParticleDef.rotDZ = RandomFloat2() * 8.0
                newParticleDef.alpha = 0.8

                let addParticleFailed = withUnsafeMutablePointer(to: &p) { pPtr in
                    withUnsafeMutablePointer(to: &d) { dPtr in
                        newParticleDef.where = pPtr
                        newParticleDef.delta = dPtr
                        return AddParticleToGroup(&newParticleDef) != 0
                    }
                }

                if addParticleFailed {
                    theNode.pointee.ParticleGroup = -1
                    break
                }
            }
        }
    }
}
