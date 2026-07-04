// OGLTypes.swift - Native Swift value types that used to be C structs in
// ogl_support.h. Converted once nothing in the remaining C code (Settings.c,
// Paused.c, the menu-tree fragments, or any *.c stub file's extern globals)
// touched them directly or transitively (see project memory for the full
// struct-pinning analysis). Kept out of ogl_support.h entirely now.

struct OGLPoint4D {
    var x: Float = 0
    var y: Float = 0
    var z: Float = 0
    var w: Float = 0
}

struct OGLColorRGBA_Byte {
    var r: UInt8 = 0
    var g: UInt8 = 0
    var b: UInt8 = 0
    var a: UInt8 = 0
}

struct OGLVertex {
    var point = OGLPoint3D()
    var uv = OGLTextureCoord()
    var color = OGLColorRGBA()
}

struct OGLBoundingSphere {
    var origin = OGLPoint3D()
    var radius: Float = 0
    var isEmpty: UInt8 = 0
}

struct OGLRay {
    var origin = OGLPoint3D()
    var direction = OGLVector3D()
    var distance: Float = 0
}

struct OGLLineSegment {
    var p1 = OGLPoint3D()
    var p2 = OGLPoint3D()
}

struct OGLMatrix3x3 {
    var value: (Float, Float, Float, Float, Float, Float, Float, Float, Float) = (0, 0, 0, 0, 0, 0, 0, 0, 0)
}
