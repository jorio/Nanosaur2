// SkeletonExtensions.swift - method-call sugar for the already-ported
// SkeletonJoints.swift free function that takes a SkeletonObjDataType as
// its logical receiver. See ObjNodeExtensions.swift for why this is a
// plain Swift extension rather than swift_name(self:).

extension UnsafeMutablePointer where Pointee == SkeletonObjDataType {
    func updateJointTransforms(_ jointNum: Int) { UpdateJointTransforms(self, jointNum) }
}
