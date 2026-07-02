// SwiftSupport.swift - Shared Swift-only helpers used across ported files.
// Nothing here is exposed to C; these just work around Swift importing
// fixed-size C arrays as tuples (which can't be dynamically subscripted).

// NOTE: OGLMatrix4x4 is a C union. Union members import as computed
// accessors rather than stored properties, so `pointer(to: \.value)` has no
// physical offset to resolve and returns nil at runtime (crashing on the
// force-unwrap) even though it type-checks. A union's address is always
// the same as its member's address, so we cast the matrix's own pointer
// directly instead of going through the (union) `.value` key path.

// OGLMatrix4x4 column-major value[16] indices (see ogl_support.h's M00..M33 enum).
let M00: Int32 = 0
let M11: Int32 = 5
let M22: Int32 = 10
let M03: Int32 = 12
let M13: Int32 = 13
let M23: Int32 = 14

@inline(__always)
func matValue(_ m: inout OGLMatrix4x4, _ i: Int32) -> Float {
    withUnsafeMutablePointer(to: &m) {
        UnsafeMutableRawPointer($0).assumingMemoryBound(to: Float.self)[Int(i)]
    }
}

@inline(__always)
func setMatValue(_ m: inout OGLMatrix4x4, _ i: Int32, _ v: Float) {
    withUnsafeMutablePointer(to: &m) {
        UnsafeMutableRawPointer($0).assumingMemoryBound(to: Float.self)[Int(i)] = v
    }
}
