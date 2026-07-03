// MetaObjectsExtensions.swift - idiomatic Swift call-site sugar for the
// MetaObjects.swift free-function API, which mirrors the original C
// `MetaObjectPtr` (untyped `void*`) style throughout.
//
// `MetaObjectsRef` is just a more Swift-readable name for `MetaObjectPtr`
// (itself a typealias for `UnsafeMutableRawPointer`) — no new type, no new
// runtime behavior. Every meta object (group/geometry/material/matrix/
// picture/sprite) shares a `MetaObjectHeader` at offset 0, which is why the
// C API — and this extension — can operate on it generically without
// knowing the concrete subtype.
//
// Purely additive: existing call sites (MO_DrawObject(x), etc.) are untouched.

typealias MetaObjectsRef = MetaObjectPtr

extension MetaObjectsRef {
    /// The common header shared by every meta object subtype.
    var header: UnsafeMutablePointer<MetaObjectHeader> {
        assumingMemoryBound(to: MetaObjectHeader.self)
    }

    var type: MetaObjectType { header.pointee.type }
    var refCount: Int { header.pointee.refCount }

    /// Draws this meta object, recursing through groups as needed.
    func draw() { MO_DrawObject(self) }

    /// Increments the reference count and returns `self`, mirroring
    /// `MO_GetNewReference`'s "take a new reference" semantics.
    @discardableResult
    func retain() -> MetaObjectsRef { MO_GetNewReference(self) }

    /// Decrements the reference count, freeing the object once it hits zero.
    func release() { MO_DisposeObjectReference(self) }

    /// Appends `child` to this group's content list. `self` must actually be a group.
    func append(_ child: MetaObjectsRef) {
        MO_AppendToGroup(assumingMemoryBound(to: MOGroupObject.self), child)
    }

    /// Inserts `child` at the start of this group's content list. `self` must actually be a group.
    func prepend(_ child: MetaObjectsRef) {
        MO_AttachToGroupStart(assumingMemoryBound(to: MOGroupObject.self), child)
    }

    /// Recursively computes the local-space bounding box, optionally applying `transform` to each vertex first.
    func calcBoundingBox(transform: UnsafeMutablePointer<OGLMatrix4x4>? = nil) -> OGLBoundingBox {
        var bBox = OGLBoundingBox()
        MO_CalcBoundingBox(self, &bBox, transform)
        return bBox
    }

    /// Recursively computes the radius of the smallest bounding sphere centered on the origin.
    func calcBoundingSphere() -> Float {
        var bSphere: Float = 0
        MO_CalcBoundingSphere(self, &bSphere)
        return bSphere
    }

    /// Offsets the UVs of this object, recursing through groups if needed.
    func offsetUVs(du: Float, dv: Float) { MO_Object_OffsetUVs(self, du, dv) }

    /// Offsets the UVs of this vertex-array geometry directly (no group recursion). `self` must be a vertex array.
    func offsetVertexArrayUVs(du: Float, dv: Float) { MO_VertexArray_OffsetUVs(self, du, dv) }
}
