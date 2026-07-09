// BinaryParsing is a separate module when this package is built via SPM
// (tests), but its sources are compiled flat into the same module as the
// rest of the game when built via CMake/Ninja - see extern/swift-binary-parsing.
#if canImport(BinaryParsing)
import BinaryParsing
#endif

/// Uncompressed (raw pixel) texture header, followed by `bufferSize` bytes of
/// pixel data. Matches C `BG3DTextureHeader`.
public struct BG3DTextureHeader: Sendable, Equatable {
    public var width: UInt32
    public var height: UInt32
    public var srcPixelFormat: Int32
    public var dstPixelFormat: Int32
    public var bufferSize: UInt32
}

extension BG3DTextureHeader: ExpressibleByParsing {
    public init(parsing input: inout ParserSpan) throws {
        width = try UInt32(parsingBigEndian: &input)
        height = try UInt32(parsingBigEndian: &input)
        srcPixelFormat = try Int32(parsingBigEndian: &input)
        dstPixelFormat = try Int32(parsingBigEndian: &input)
        bufferSize = try UInt32(parsingBigEndian: &input)
        try input.seek(toRelativeOffset: 16)  // uint32_t reserved[4]
    }
}

/// JPEG-compressed texture header, followed by `bufferSize` bytes of JPEG
/// data, then (if `hasAlphaChannel`) `width * height` raw alpha bytes.
/// Matches C `BG3DJPEGTextureHeader`.
public struct BG3DJPEGTextureHeader: Sendable, Equatable {
    public var width: UInt32
    public var height: UInt32
    public var bufferSize: UInt32
    public var hasAlphaChannel: UInt32
}

extension BG3DJPEGTextureHeader: ExpressibleByParsing {
    public init(parsing input: inout ParserSpan) throws {
        width = try UInt32(parsingBigEndian: &input)
        height = try UInt32(parsingBigEndian: &input)
        bufferSize = try UInt32(parsingBigEndian: &input)
        hasAlphaChannel = try UInt32(parsingBigEndian: &input)
    }
}

/// Geometry header, always immediately preceding a run of vertexArray/
/// normalArray/uvArray/colorArray/triangleArray/boundingBox chunks that
/// describe `numPoints` points and `numTriangles` triangles. Matches C
/// `BG3DGeometryHeader`.
public struct BG3DGeometryHeader: Sendable, Equatable {
    public var type: UInt32
    public var numMaterials: Int32
    public var layerMaterialNum: (UInt32, UInt32, UInt32, UInt32)
    public var flags: UInt32
    public var numPoints: UInt32
    public var numTriangles: UInt32

    public static func == (lhs: BG3DGeometryHeader, rhs: BG3DGeometryHeader) -> Bool {
        lhs.type == rhs.type
            && lhs.numMaterials == rhs.numMaterials
            && lhs.layerMaterialNum == rhs.layerMaterialNum
            && lhs.flags == rhs.flags
            && lhs.numPoints == rhs.numPoints
            && lhs.numTriangles == rhs.numTriangles
    }
}

/// Geometry type values from the C `BG3D_GEOMETRYTYPE_*` enum.
public enum BG3DGeometryType: UInt32, Sendable {
    case vertexElements = 0
}

extension BG3DGeometryHeader: ExpressibleByParsing {
    public init(parsing input: inout ParserSpan) throws {
        type = try UInt32(parsingBigEndian: &input)
        numMaterials = try Int32(parsingBigEndian: &input)
        let m0 = try UInt32(parsingBigEndian: &input)
        let m1 = try UInt32(parsingBigEndian: &input)
        let m2 = try UInt32(parsingBigEndian: &input)
        let m3 = try UInt32(parsingBigEndian: &input)
        layerMaterialNum = (m0, m1, m2, m3)
        flags = try UInt32(parsingBigEndian: &input)
        numPoints = try UInt32(parsingBigEndian: &input)
        numTriangles = try UInt32(parsingBigEndian: &input)
        try input.seek(toRelativeOffset: 16)  // uint32_t reserved[4]
    }
}
