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
let M10: Int32 = 1
let M20: Int32 = 2
let M30: Int32 = 3
let M01: Int32 = 4
let M11: Int32 = 5
let M21: Int32 = 6
let M31: Int32 = 7
let M02: Int32 = 8
let M12: Int32 = 9
let M22: Int32 = 10
let M32: Int32 = 11
let M03: Int32 = 12
let M13: Int32 = 13
let M23: Int32 = 14
let M33: Int32 = 15

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

// OGLMatrix3x3 value[9] indices (see ogl_support.h's N00..N22 enum).
let N00: Int32 = 0
let N10: Int32 = 1
let N20: Int32 = 2
let N01: Int32 = 3
let N11: Int32 = 4
let N21: Int32 = 5
let N02: Int32 = 6
let N12: Int32 = 7
let N22: Int32 = 8

@inline(__always)
func mat3Value(_ m: inout OGLMatrix3x3, _ i: Int32) -> Float {
    withUnsafeMutablePointer(to: &m) {
        UnsafeMutableRawPointer($0).assumingMemoryBound(to: Float.self)[Int(i)]
    }
}

@inline(__always)
func setMat3Value(_ m: inout OGLMatrix3x3, _ i: Int32, _ v: Float) {
    withUnsafeMutablePointer(to: &m) {
        UnsafeMutableRawPointer($0).assumingMemoryBound(to: Float.self)[Int(i)] = v
    }
}

// Reimplements the Alloc_2d_array/Free_2d_array parameterized macros
// (globals.h), which aren't importable as Swift symbols. Allocates `rows`
// row pointers plus one contiguous `rows * cols` backing block, with each
// row pointer offset into that block — matching the C macro's layout
// exactly (row 0's pointer IS the block's base address).
func alloc2DArray<T>(_ type: T.Type, rows: Int, cols: Int) -> UnsafeMutablePointer<UnsafeMutablePointer<T>?> {
    let array = AllocPtrClear(MemoryLayout<UnsafeMutablePointer<T>?>.size * rows)!.assumingMemoryBound(to: UnsafeMutablePointer<T>?.self)
    let flat = AllocPtrClear(MemoryLayout<T>.size * rows * cols)!.assumingMemoryBound(to: T.self)
    for i in 0..<rows {
        array[i] = flat + i * cols
    }
    return array
}

func free2DArray<T>(_ array: UnsafeMutablePointer<UnsafeMutablePointer<T>?>?) {
    guard let array else { return }
    SafeDisposePtr(array[0])
    SafeDisposePtr(array)
}
