// SkeletonExtensions.swift - method-call sugar for free functions that take
// a SkeletonObjDataType as their logical receiver. Covers both the
// already-ported SkeletonJoints.swift function and still-C ones (from
// SkeletonAnim.c, not yet ported). See ObjNodeExtensions.swift for why this
// is a plain Swift extension rather than swift_name(self:).

extension UnsafeMutablePointer where Pointee == SkeletonObjDataType {
    func updateJointTransforms(_ jointNum: Int) { UpdateJointTransforms(self, jointNum) }

    // From skeleton.h (SkeletonAnim.c — not yet ported)
    func setAnim(_ animNum: Int) { SetSkeletonAnim(self, animNum) }
    func getModelCurrentPosition() { GetModelCurrentPosition(self) }
    func morphToAnim(_ animNum: Int, speed: Float) { MorphToSkeletonAnim(self, animNum, speed) }
    func setAnimTime(_ timeRatio: Float) { SetSkeletonAnimTime(self, timeRatio) }

    /// True if AnimNum is currently this player anim (player skeletons only;
    /// enemy anim numbers are plain Int constants local to each enemy file).
    func isAnim(_ anim: PlayerAnim) -> Bool { pointee.AnimNum == UInt8(anim.rawValue) }

    /// Set when a non-looping anim reaches the end of its sequence.
    var animHasStopped: Bool {
        get { pointee.AnimHasStopped != 0 }
        nonmutating set { pointee.AnimHasStopped = newValue ? 1 : 0 }
    }

    /// True when joints are already in world-space coords.
    var jointsAreGlobal: Bool {
        get { pointee.JointsAreGlobal != 0 }
        nonmutating set { pointee.JointsAreGlobal = newValue ? 1 : 0 }
    }

    /// Set while morphing from one anim to another.
    var isMorphing: Bool {
        get { pointee.IsMorphing != 0 }
        nonmutating set { pointee.IsMorphing = newValue ? 1 : 0 }
    }
}
