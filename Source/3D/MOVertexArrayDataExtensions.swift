// MOVertexArrayDataExtensions.swift - method-call sugar for the
// already-ported QuadMesh.swift free function that takes a
// MOVertexArrayData as its logical receiver. See ObjNodeExtensions.swift
// for why this is a plain Swift extension rather than swift_name(self:).

extension UnsafeMutablePointer where Pointee == MOVertexArrayData {
    func reallocate(numQuads: Int32) { ReallocateQuadMesh(self, numQuads) }
}
