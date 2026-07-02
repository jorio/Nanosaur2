// ObjNodeExtensions.swift - method-call sugar for the already-ported free
// functions (across Objects.swift, SkeletonJoints.swift, QuadMesh.swift,
// Sparkle.swift, Player_Race.swift) that take an ObjNode as their logical
// receiver.
//
// These can't be done via C's swift_name(self:) member-import mechanism:
// combining swift_name with @c @implementation on the same declaration
// crashes the Swift 6.3.2 compiler (verified via an isolated repro). Plain
// Swift extensions sidestep that entirely and additionally avoid the
// `.pointee` that swift_name(self:) would have required, since it binds to
// the value-typed ObjNode struct rather than UnsafeMutablePointer<ObjNode>.
//
// Purely additive: existing call sites are untouched.

extension UnsafeMutablePointer where Pointee == ObjNode {
    func calcRadiusFromBBox() { CalcObjectRadiusFromBBox(self) }
    func resetDisplayGroup() { ResetDisplayGroupObject(self) }
    func attachGeometryToDisplayGroup(_ geometry: MetaObjectPtr?) { AttachGeometryToDisplayGroupObject(self, geometry) }
    func createBaseGroup() { CreateBaseGroup(self) }
    func disposeBaseGroup() { DisposeObjectBaseGroup(self) }
    func getInfo() { GetObjectInfo(self) }
    func update() { UpdateObject(self) }
    func updateTransforms() { UpdateObjectTransforms(self) }
    func setGridLocation() { SetObjectGridLocation(self) }
    func setTransformMatrix() { SetObjectTransformMatrix(self) }
    @discardableResult func setVisible(_ visible: UInt8) -> UInt8 { SetObjectVisible(self, visible) }
    func appendToChain(_ newTail: UnsafeMutablePointer<ObjNode>) { AppendNodeToChain(self, newTail) }
    func sendToOverlayPane() { SendNodeToOverlayPane(self) }
    func chainLength() -> Int32 { GetNodeChainLength(self) }
    func chainTail() -> UnsafeMutablePointer<ObjNode>? { GetChainTailNode(self) }
    func nthChainedNode(_ targetIndex: Int32, outPrevNode: UnsafeMutablePointer<UnsafeMutablePointer<ObjNode>?>? = nil) -> UnsafeMutablePointer<ObjNode>? {
        GetNthChainedNode(self, targetIndex, outPrevNode)
    }

    // From SkeletonJoints.swift
    func findCoordOfJoint(_ jointNum: Int, outPoint: UnsafeMutablePointer<OGLPoint3D>) { FindCoordOfJoint(self, jointNum, outPoint) }
    func findCoordOnJoint(_ jointNum: Int, inPoint: UnsafePointer<OGLPoint3D>, outPoint: UnsafeMutablePointer<OGLPoint3D>) { FindCoordOnJoint(self, jointNum, inPoint, outPoint) }
    func findCoordOnJointAtFlagEvent(_ jointNum: Int, inPoint: UnsafePointer<OGLPoint3D>, outPoint: UnsafeMutablePointer<OGLPoint3D>) { FindCoordOnJointAtFlagEvent(self, jointNum, inPoint, outPoint) }
    func findJointMatrixAtFlagEvent(_ jointNum: Int, flagNum: UInt8, m: UnsafeMutablePointer<OGLMatrix4x4>) { FindJointMatrixAtFlagEvent(self, jointNum, flagNum, m) }
    func findJointFullMatrix(_ jointNum: Int, outMatrix: UnsafeMutablePointer<OGLMatrix4x4>) { FindJointFullMatrix(self, jointNum, outMatrix) }

    // From QuadMesh.swift
    func quadMeshWithin() -> UnsafeMutablePointer<MOVertexArrayData> { GetQuadMeshWithin(self) }

    // From Sparkle.swift
    func getFreeSparkle() -> Int16 { GetFreeSparkle(self) }

    // From Player_Race.swift
    func updatePlayerRaceMarkers() { UpdatePlayerRaceMarkers(self) }
}

extension Optional where Wrapped == UnsafeMutablePointer<ObjNode> {
    func delete() { DeleteObject(self) }
    func detach(subrecurse: UInt8 = 0) { DetachObject(self, subrecurse) }
    func attach(recurse: UInt8 = 0) { AttachObject(self, recurse) }
    func unchain() { UnchainNode(self) }
    func chainLength() -> Int32 { GetNodeChainLength(self) }
    func chainTail() -> UnsafeMutablePointer<ObjNode>? { GetChainTailNode(self) }
}
