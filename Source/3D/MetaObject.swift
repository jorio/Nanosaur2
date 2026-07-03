// MetaObject.swift
//
// `final class` wrapper around `MetaObjectsRef` (the C `MetaObjectPtr`
// opaque `void *` handle). Reference counting is manual and mirrors the
// underlying C object's own `refCount` field, driven by `MO_GetNewReference`/
// `MO_DisposeObjectReference` — NOT by Swift ARC/deinit.
//
// Un-ported C code still reads and writes raw `MetaObjectPtr` values directly
// (e.g. `ObjNode.BaseGroup`, `MOGroupData.groupContents`) with zero awareness
// of any Swift wrapper's lifetime. An earlier spike confirmed that attaching
// this type to C storage via `SWIFT_SHARED_REFERENCE` causes the Swift
// compiler to insert *implicit* retains/releases on every plain struct field
// access, which would silently desync from that unaware C bookkeeping. This
// class avoids that hazard entirely by never letting ARC touch the C
// reference count: `own`/`retain` and `release` are the only way to create or
// give up a reference, both go through `Unmanaged` explicitly, and this class
// intentionally has no `deinit` that calls into C.

final class MetaObject {
    /// The wrapped `MetaObjectPtr`.
    let ref: MetaObjectsRef

    private init(ref: MetaObjectsRef) {
        self.ref = ref
    }

    /// Wraps `ref`, taking ownership of a reference the caller already holds
    /// (e.g. one just returned by `MO_CreateNewObjectOfType`). Returns an
    /// `Unmanaged` reference; the caller must balance it with exactly one
    /// `release(_:)` call.
    static func own(_ ref: MetaObjectsRef) -> Unmanaged<MetaObject> {
        .passRetained(MetaObject(ref: ref))
    }

    /// Takes a *new* C-side reference to `ref` (mirrors `MO_GetNewReference`)
    /// and wraps it. Returns an `Unmanaged` reference; the caller must balance
    /// it with exactly one `release(_:)` call.
    static func retain(_ ref: MetaObjectsRef) -> Unmanaged<MetaObject> {
        .passRetained(MetaObject(ref: MO_GetNewReference(ref)))
    }

    /// Releases the underlying C reference (`MO_DisposeObjectReference`) and
    /// consumes `unmanaged`, deallocating this wrapper. Must be called exactly
    /// once per `own`/`retain` call — never rely on `deinit` for this.
    func release(_ unmanaged: Unmanaged<MetaObject>) {
        MO_DisposeObjectReference(ref)
        unmanaged.release()
    }

    // MARK: - MetaObjectHeader properties (mirrors MetaObjectsRef)

    var type: MetaObjectType { ref.type }
    var refCount: Int { ref.refCount }
    var subType: Int { ref.subType }
    var data: UnsafeMutableRawPointer? { ref.data }
    var parentGroup: MetaObjectsRef? { ref.parentGroup }

    // MARK: - Operations (mirrors MetaObjectsRef)

    /// Draws this meta object, recursing through groups as needed.
    func draw() { ref.draw() }

    /// Appends `child` to this group's content list. `self` must actually be a group.
    func append(_ child: MetaObjectsRef?) { ref.append(child) }

    /// Inserts `child` at the start of this group's content list. `self` must actually be a group.
    func prepend(_ child: MetaObjectsRef?) { ref.prepend(child) }

    /// Recursively computes the local-space bounding box, optionally applying `transform` to each vertex first.
    func calcBoundingBox(transform: UnsafeMutablePointer<OGLMatrix4x4>? = nil) -> OGLBoundingBox {
        ref.calcBoundingBox(transform: transform)
    }

    /// Recursively computes the radius of the smallest bounding sphere centered on the origin.
    func calcBoundingSphere() -> Float { ref.calcBoundingSphere() }

    /// Offsets the UVs of this object, recursing through groups if needed.
    func offsetUVs(du: Float, dv: Float) { ref.offsetUVs(du: du, dv: dv) }

    /// Offsets the UVs of this vertex-array geometry directly (no group recursion). `self` must be a vertex array.
    func offsetVertexArrayUVs(du: Float, dv: Float) { ref.offsetVertexArrayUVs(du: du, dv: dv) }
}
