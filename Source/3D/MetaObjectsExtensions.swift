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

    // Reinterpretations as the concrete `MO*Object` subtype. Each `MO*Object`
    // struct starts with `MetaObjectHeader`, matching the layout the C code
    // assumes when it casts a `MetaObjectPtr` based on `header.type`.
    var asGroup: UnsafeMutablePointer<MOGroupObject> { assumingMemoryBound(to: MOGroupObject.self) }
    var asMaterial: UnsafeMutablePointer<MOMaterialObject> { assumingMemoryBound(to: MOMaterialObject.self) }
    var asVertexArray: UnsafeMutablePointer<MOVertexArrayObject> { assumingMemoryBound(to: MOVertexArrayObject.self) }
    var asMatrix: UnsafeMutablePointer<MOMatrixObject> { assumingMemoryBound(to: MOMatrixObject.self) }
    var asPicture: UnsafeMutablePointer<MOPictureObject> { assumingMemoryBound(to: MOPictureObject.self) }
    var asSprite: UnsafeMutablePointer<MOSpriteObject> { assumingMemoryBound(to: MOSpriteObject.self) }

    // MARK: - MetaObjectHeader getters/setters

    var cookie: UInt32 {
        get { header.pointee.cookie }
        set { header.pointee.cookie = newValue }
    }

    var type: MetaObjectType {
        get { header.pointee.type }
        set { header.pointee.type = newValue }
    }

    var refCount: Int {
        get { header.pointee.refCount }
        set { header.pointee.refCount = newValue }
    }

    var subType: Int {
        get { header.pointee.subType }
        set { header.pointee.subType = newValue }
    }

    var data: UnsafeMutableRawPointer? {
        get { header.pointee.data }
        set { header.pointee.data = newValue }
    }

    var parentGroup: MetaObjectsRef? {
        get { UnsafeMutableRawPointer(header.pointee.parentGroup) }
        set { header.pointee.parentGroup = newValue?.assumingMemoryBound(to: MetaObjectHeader.self) }
    }

    var prevNode: MetaObjectsRef? {
        get { UnsafeMutableRawPointer(header.pointee.prevNode) }
        set { header.pointee.prevNode = newValue?.assumingMemoryBound(to: MetaObjectHeader.self) }
    }

    var nextNode: MetaObjectsRef? {
        get { UnsafeMutableRawPointer(header.pointee.nextNode) }
        set { header.pointee.nextNode = newValue?.assumingMemoryBound(to: MetaObjectHeader.self) }
    }

    /// Draws this meta object, recursing through groups as needed.
    func draw() { MO_DrawObject(self) }

    /// Increments the reference count and returns `self`, mirroring
    /// `MO_GetNewReference`'s "take a new reference" semantics.
    @discardableResult
    func retain() -> MetaObjectsRef { MO_GetNewReference(self) }

    /// Decrements the reference count, freeing the object once it hits zero.
    func release() { MO_DisposeObjectReference(self) }

    /// Appends `child` to this group's content list. `self` must actually be a group.
    func append(_ child: MetaObjectsRef?) {
        MO_AppendToGroup(assumingMemoryBound(to: MOGroupObject.self), child)
    }

    /// Inserts `child` at the start of this group's content list. `self` must actually be a group.
    func prepend(_ child: MetaObjectsRef?) {
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

// MARK: - MOGroupObject

extension UnsafeMutablePointer where Pointee == MOGroupObject {
    var numObjectsInGroup: Int32 {
        get { pointee.objectData.numObjectsInGroup }
        set { pointee.objectData.numObjectsInGroup = newValue }
    }

    func groupContent(at index: Int) -> MetaObjectsRef? {
        UnsafeMutableRawPointer(groupContentsBase(self)[index])
    }

    func setGroupContent(_ value: MetaObjectsRef?, at index: Int) {
        groupContentsBase(self)[index] = value?.assumingMemoryBound(to: MetaObjectHeader.self)
    }
}

// MARK: - MOMaterialObject

extension UnsafeMutablePointer where Pointee == MOMaterialObject {
    var flags: UInt32 {
        get { pointee.objectData.flags }
        set { pointee.objectData.flags = newValue }
    }

    var diffuseColor: OGLColorRGBA {
        get { pointee.objectData.diffuseColor }
        set { pointee.objectData.diffuseColor = newValue }
    }

    var multiTextureMode: UInt16 {
        get { pointee.objectData.multiTextureMode }
        set { pointee.objectData.multiTextureMode = newValue }
    }

    var multiTextureCombine: UInt16 {
        get { pointee.objectData.multiTextureCombine }
        set { pointee.objectData.multiTextureCombine = newValue }
    }

    var envMapNum: UInt16 {
        get { pointee.objectData.envMapNum }
        set { pointee.objectData.envMapNum = newValue }
    }

    var numMipmaps: UInt32 {
        get { pointee.objectData.numMipmaps }
        set { pointee.objectData.numMipmaps = newValue }
    }

    var width: UInt32 {
        get { pointee.objectData.width }
        set { pointee.objectData.width = newValue }
    }

    var height: UInt32 {
        get { pointee.objectData.height }
        set { pointee.objectData.height = newValue }
    }
}

// MARK: - MOMatrixObject

extension UnsafeMutablePointer where Pointee == MOMatrixObject {
    var matrix: OGLMatrix4x4 {
        get { pointee.matrix }
        set { pointee.matrix = newValue }
    }
}

// MARK: - MOPictureObject

extension UnsafeMutablePointer where Pointee == MOPictureObject {
    var drawCoord: OGLPoint3D {
        get { pointee.objectData.drawCoord }
        set { pointee.objectData.drawCoord = newValue }
    }

    var drawScaleX: Float {
        get { pointee.objectData.drawScaleX }
        set { pointee.objectData.drawScaleX = newValue }
    }

    var drawScaleY: Float {
        get { pointee.objectData.drawScaleY }
        set { pointee.objectData.drawScaleY = newValue }
    }

    var fullWidth: Int32 {
        get { pointee.objectData.fullWidth }
        set { pointee.objectData.fullWidth = newValue }
    }

    var fullHeight: Int32 {
        get { pointee.objectData.fullHeight }
        set { pointee.objectData.fullHeight = newValue }
    }

    var material: UnsafeMutablePointer<MOMaterialObject>? {
        get { pointee.objectData.material }
        set { pointee.objectData.material = newValue }
    }
}

// MARK: - MOSpriteObject

extension UnsafeMutablePointer where Pointee == MOSpriteObject {
    var width: Float {
        get { pointee.objectData.width }
        set { pointee.objectData.width = newValue }
    }

    var height: Float {
        get { pointee.objectData.height }
        set { pointee.objectData.height = newValue }
    }

    var aspectRatio: Float {
        get { pointee.objectData.aspectRatio }
        set { pointee.objectData.aspectRatio = newValue }
    }

    var scaleBasis: Float {
        get { pointee.objectData.scaleBasis }
        set { pointee.objectData.scaleBasis = newValue }
    }

    var drawCentered: Bool {
        get { pointee.objectData.drawCentered != 0 }
        set { pointee.objectData.drawCentered = newValue ? 1 : 0 }
    }

    var coord: OGLPoint3D {
        get { pointee.objectData.coord }
        set { pointee.objectData.coord = newValue }
    }

    var scaleX: Float {
        get { pointee.objectData.scaleX }
        set { pointee.objectData.scaleX = newValue }
    }

    var scaleY: Float {
        get { pointee.objectData.scaleY }
        set { pointee.objectData.scaleY = newValue }
    }

    var rot: Float {
        get { pointee.objectData.rot }
        set { pointee.objectData.rot = newValue }
    }

    var material: UnsafeMutablePointer<MOMaterialObject>? {
        get { pointee.objectData.material }
        set { pointee.objectData.material = newValue }
    }
}

// MARK: - MOVertexArrayObject

extension UnsafeMutablePointer where Pointee == MOVertexArrayObject {
    var VARtype: Int16 {
        get { pointee.objectData.VARtype }
        set { pointee.objectData.VARtype = newValue }
    }

    var numMaterials: Int16 {
        get { pointee.objectData.numMaterials }
        set { pointee.objectData.numMaterials = newValue }
    }

    func material(at index: Int) -> UnsafeMutablePointer<MOMaterialObject>? {
        materialsBase(self)[index]
    }

    func setMaterial(_ value: UnsafeMutablePointer<MOMaterialObject>?, at index: Int) {
        materialsBase(self)[index] = value
    }

    var numPoints: Int32 {
        get { pointee.objectData.numPoints }
        set { pointee.objectData.numPoints = newValue }
    }

    var numTriangles: Int32 {
        get { pointee.objectData.numTriangles }
        set { pointee.objectData.numTriangles = newValue }
    }

    var points: UnsafeMutablePointer<OGLPoint3D>? {
        get { pointee.objectData.points }
        set { pointee.objectData.points = newValue }
    }

    var normals: UnsafeMutablePointer<OGLVector3D>? {
        get { pointee.objectData.normals }
        set { pointee.objectData.normals = newValue }
    }

    func uv(at index: Int) -> UnsafeMutablePointer<OGLTextureCoord>? {
        uvsBase(self)[index]
    }

    func setUV(_ value: UnsafeMutablePointer<OGLTextureCoord>?, at index: Int) {
        uvsBase(self)[index] = value
    }

    var colorsFloat: UnsafeMutablePointer<OGLColorRGBA>? {
        get { pointee.objectData.colorsFloat }
        set { pointee.objectData.colorsFloat = newValue }
    }

    var triangles: UnsafeMutablePointer<MOTriangleIndecies>? {
        get { pointee.objectData.triangles }
        set { pointee.objectData.triangles = newValue }
    }

    var bBox: OGLBoundingBox {
        get { pointee.objectData.bBox }
        set { pointee.objectData.bBox = newValue }
    }

    var pointCapacity: Int32 {
        get { pointee.objectData.pointCapacity }
        set { pointee.objectData.pointCapacity = newValue }
    }

    var triangleCapacity: Int32 {
        get { pointee.objectData.triangleCapacity }
        set { pointee.objectData.triangleCapacity = newValue }
    }
}

/// Flat, dynamically-indexable pointer into `materials[MAX_MATERIAL_LAYERS]`.
@inline(__always) private func materialsBase(_ obj: UnsafeMutablePointer<MOVertexArrayObject>) -> UnsafeMutablePointer<UnsafeMutablePointer<MOMaterialObject>?> {
    UnsafeMutableRawPointer(obj.pointer(to: \.objectData.materials)!).assumingMemoryBound(to: UnsafeMutablePointer<MOMaterialObject>?.self)
}

/// Flat, dynamically-indexable pointer into `uvs[MAX_MATERIAL_LAYERS]`.
@inline(__always) private func uvsBase(_ obj: UnsafeMutablePointer<MOVertexArrayObject>) -> UnsafeMutablePointer<UnsafeMutablePointer<OGLTextureCoord>?> {
    UnsafeMutableRawPointer(obj.pointer(to: \.objectData.uvs)!).assumingMemoryBound(to: UnsafeMutablePointer<OGLTextureCoord>?.self)
}

/// Flat, dynamically-indexable pointer into `groupContents[MO_MAX_ITEMS_IN_GROUP]`.
@inline(__always) private func groupContentsBase(_ obj: UnsafeMutablePointer<MOGroupObject>) -> UnsafeMutablePointer<UnsafeMutablePointer<MetaObjectHeader>?> {
    UnsafeMutableRawPointer(obj.pointer(to: \.objectData.groupContents)!).assumingMemoryBound(to: UnsafeMutablePointer<MetaObjectHeader>?.self)
}
