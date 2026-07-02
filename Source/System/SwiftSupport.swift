// SwiftSupport.swift - Shared Swift-only helpers used across ported files.
// Nothing here is exposed to C; these just work around Swift importing
// fixed-size C arrays as tuples (which can't be dynamically subscripted).

@inline(__always)
func matValue(_ m: inout OGLMatrix4x4, _ i: Int32) -> Float {
    withUnsafeMutablePointer(to: &m) {
        UnsafeMutableRawPointer($0.pointer(to: \.value)!).assumingMemoryBound(to: Float.self)[Int(i)]
    }
}

@inline(__always)
func setMatValue(_ m: inout OGLMatrix4x4, _ i: Int32, _ v: Float) {
    withUnsafeMutablePointer(to: &m) {
        UnsafeMutableRawPointer($0.pointer(to: \.value)!).assumingMemoryBound(to: Float.self)[Int(i)] = v
    }
}
