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

    /// Set when a non-looping anim reaches the end of its sequence.
    var animHasStopped: Bool {
        get { pointee.AnimHasStopped != 0 }
        nonmutating set { pointee.AnimHasStopped = newValue ? 1 : 0 }
    }
}
