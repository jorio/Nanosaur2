// ObjNodeExtensions.swift - method-call sugar for free functions that take
// an ObjNode as their logical receiver. Covers both already-ported Swift
// functions and still-C ones (Skeleton/Collision/SplineItems/Terrain/
// Effects) — wrapping a C function in an extension works the same either
// way since this is just a thin call-through, not an implementation.
//
// These can't be done via C's swift_name(self:) member-import mechanism:
// combining swift_name with @c @implementation crashes the Swift 6.3.2
// compiler for anything ported via @c @implementation (verified via an
// isolated repro), and even for still-C functions swift_name(self:) binds
// to the value-typed ObjNode struct rather than UnsafeMutablePointer<ObjNode>,
// which is what this codebase actually uses everywhere. Plain Swift
// extensions sidestep both problems and read the same either way.
//
// Purely additive: existing call sites are untouched.

extension UnsafeMutablePointer where Pointee == ObjNode {
    // StatusBits sugar - replaces the raw `StatusBits |= UInt32(STATUS_BIT_X)`
    // / `&= ~UInt32(...)` / `& UInt32(...) != 0` trio. Takes the STATUS_BIT_*
    // constants at their imported type (untyped Int from the anonymous C
    // enum in globals.h) so call sites need no casts; combined bits
    // (STATUS_BIT_A | STATUS_BIT_B) work too.
    func hasStatus(_ bits: Int) -> Bool { pointee.StatusBits & UInt32(bits) != 0 }
    func setStatus(_ bits: Int) { pointee.StatusBits |= UInt32(bits) }
    func clearStatus(_ bits: Int) { pointee.StatusBits &= ~UInt32(bits) }

    /// Hidden = not drawn (STATUS_BIT_HIDDEN). `hide()`/`show()` affect this
    /// node only; see `hideChain()`/`showChain()` for whole chains.
    var isHidden: Bool { hasStatus(STATUS_BIT_HIDDEN) }
    func hide() { setStatus(STATUS_BIT_HIDDEN) }
    func show() { clearStatus(STATUS_BIT_HIDDEN) }

    /// Sugar over the `Boolean` (UInt8) `isUsed` slot-allocation flag in
    /// gEngine.objects.objectListStorage, replacing `pointee.isUsed = 1` / `== 0` boilerplate.
    var isUsed: Bool {
        get { pointee.isUsed != 0 }
        nonmutating set { pointee.isUsed = newValue ? 1 : 0 }
    }

    /// True if WorldMeshes/WorldPlaneEQs hold current world-space copies of
    /// the model's vertices (used for picking; invalidated on every
    /// transform update).
    var hasWorldPoints: Bool {
        get { pointee.HasWorldPoints != 0 }
        nonmutating set { pointee.HasWorldPoints = newValue ? 1 : 0 }
    }

    /// ObjNode.Kind interpreted as a WeaponType - only meaningful on
    /// bullet/projectile nodes. (Kind is polysemous: it holds EnemyKind for
    /// enemies and WhatType for pickable terrain items.)
    var weaponKind: WeaponType? {
        get { WeaponType(rawValue: pointee.Kind) }
        nonmutating set { pointee.Kind = (newValue ?? .none).rawValue }
    }

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

    // From skeleton.h (SkeletonAnim.c/Bones.c — not yet ported)
    func drawSkeleton() { DrawSkeleton(self) }
    func updateSkeletonAnimation() { UpdateSkeletonAnimation(self) }
    func burnSkeleton(flameScale: Float) { BurnSkeleton(self, flameScale) }
    func updateSkinnedGeometry() { UpdateSkinnedGeometry(self) }

    // From collision.h (Collision.c — not yet ported)
    @discardableResult func handleCollisions(cType: UInt32, deltaBounce: Float) -> UInt8 { HandleCollisions(self, cType, deltaBounce) }

    // From splineitems.h (SplineItems.c — not yet ported)
    func isSplineItemOnActiveTerrain() -> UInt8 { IsSplineItemOnActiveTerrain(self) }
    func addToSplineObjectList(setAim: UInt8) { AddToSplineObjectList(self, setAim) }
    @discardableResult func removeFromSplineObjectList() -> UInt8 { RemoveFromSplineObjectList(self) }
    @discardableResult func increaseSplineIndex(speed: Float) -> UInt8 { IncreaseSplineIndex(self, speed) }
    func increaseSplineIndexZigZag(speed: Float) { IncreaseSplineIndexZigZag(self, speed) }
    func detachFromSpline(moveCall: (@convention(c) (UnsafeMutablePointer<ObjNode>?) -> Void)!) { DetachObjectFromSpline(self, moveCall) }
    func setSplineAim() { SetSplineAim(self) }
    func getCoordOnSpline() { GetObjectCoordOnSpline(self) }
    func getCoordOnSpline(x: UnsafeMutablePointer<Float>!, z: UnsafeMutablePointer<Float>!) { GetObjectCoordOnSpline2(self, x, z) }

    // From terrain.h (Terrain.c/Terrain2.c — not yet ported)
    func trackTerrainItem() -> UInt8 { TrackTerrainItem(self) }
    func drawTerrain() { DrawTerrain(self) }
    func rotateOnTerrain(yOffset: Float, surfaceNormal: UnsafeMutablePointer<OGLVector3D>!) { RotateOnTerrain(self, yOffset, surfaceNormal) }
    func rotateOnTerrainWideArea(yOffset: Float, radius: Float) { RotateOnTerrain_WideArea(self, yOffset, radius) }
    func seeIfCrossedLineMarker(whichLine: UnsafeMutablePointer<Int>!) -> UInt8 { SeeIfCrossedLineMarker(self, whichLine) }

    // From objects.h (remaining functions not yet wrapped by the Objects.c port)
    func calcNewTargetOffsets(scale: Float) { CalcNewTargetOffsets(self, scale) }
    func calcObjectBoxFromNode() { CalcObjectBoxFromNode(self) }
    func calcObjectBoxFromGlobal() { CalcObjectBoxFromGlobal(self) }
    func setCollisionBounds(top: Float, bottom: Float, left: Float, right: Float, front: Float, back: Float) {
        SetObjectCollisionBounds(self, top, bottom, left, right, front, back)
    }
    func attachStaticShadow(type: ShadowType, scaleX: Float, scaleZ: Float) -> UnsafeMutablePointer<ObjNode>! {
        AttachStaticShadowToObject(self, type, scaleX, scaleZ)
    }
    func updateShadow() { UpdateShadow(self) }
    func isTotallyCulled() -> UInt8 { IsObjectTotallyCulled(self) }
    func attachShadow(type: ShadowType, scaleX: Float, scaleZ: Float, checkBlockers: UInt8) -> UnsafeMutablePointer<ObjNode>! {
        AttachShadowToObject(self, type, scaleX, scaleZ, checkBlockers)
    }
    func createCollisionBoxFromBoundingBox(tweakXZ: Float, tweakY: Float) { CreateCollisionBoxFromBoundingBox(self, tweakXZ, tweakY) }
    func createCollisionBoxFromBoundingBoxMaximized(scaleMag: Float) { CreateCollisionBoxFromBoundingBox_Maximized(self, scaleMag) }
    func createCollisionBoxFromBoundingBoxRotated(tweakXZ: Float, tweakY: Float) { CreateCollisionBoxFromBoundingBox_Rotated(self, tweakXZ, tweakY) }
    func updateCollisionBoxFromBoundingBox(tweakXZ: Float, tweakY: Float) { CreateCollisionBoxFromBoundingBox_Update(self, tweakXZ, tweakY) }
    func keepOldCollisionBoxes() { KeepOldCollisionBoxes(self) }
    func addCollisionBox(top: Float, bottom: Float, left: Float, right: Float, front: Float, back: Float) {
        AddCollisionBoxToObject(self, top, bottom, left, right, front, back)
    }
    func calcDisplayGroupWorldPoints() { CalcDisplayGroupWorldPoints(self) }
    func hideChain() { HideObjectChain(self) }
    func showChain() { ShowObjectChain(self) }

    // From items.h (Items.c — not yet ported)
    func drawCyclorama() { DrawCyclorama(self) }

    // From effects.h (Particles.c — not yet ported)
    func particleHit(flags: UInt16) -> UInt8 { ParticleHitObject(self, flags) }
    func sprayWater(x: Float, y: Float, z: Float) { SprayWater(self, x, y, z) }
    func burnFire(x: Float, y: Float, z: Float, doSmoke: UInt8, particleType: Int16, scale: Float, moreFlags: UInt32) {
        BurnFire(self, x, y, z, doSmoke, particleType, scale, moreFlags)
    }
}

extension Optional where Wrapped == UnsafeMutablePointer<ObjNode> {
    func delete() { DeleteObject(self) }
    func detach(subrecurse: UInt8 = 0) { DetachObject(self, subrecurse) }
    func attach(recurse: UInt8 = 0) { AttachObject(self, recurse) }
    func unchain() { UnchainNode(self) }
    func chainLength() -> Int32 { GetNodeChainLength(self) }
    func chainTail() -> UnsafeMutablePointer<ObjNode>? { GetChainTailNode(self) }
}
