// BinaryParsing is a separate module when this package is built via SPM
// (tests), but its sources are compiled flat into the same module as the
// rest of the game when built via CMake/Ninja - see extern/swift-binary-parsing.
#if canImport(BinaryParsing)
import BinaryParsing
#endif

/// 3-component float vector, matches the file's on-disk point/vector/normal encoding.
public struct BG3DPoint3D: Sendable, Equatable {
    public var x: Float
    public var y: Float
    public var z: Float

    public init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }
}

extension BG3DPoint3D: ExpressibleByParsing {
    public init(parsing input: inout ParserSpan) throws {
        let x = Float(bitPattern: try UInt32(parsingBigEndian: &input))
        let y = Float(bitPattern: try UInt32(parsingBigEndian: &input))
        let z = Float(bitPattern: try UInt32(parsingBigEndian: &input))
        self.init(x: x, y: y, z: z)
    }
}

/// 2-component UV texture coordinate.
public struct BG3DTextureCoord: Sendable, Equatable {
    public var u: Float
    public var v: Float

    public init(u: Float, v: Float) {
        self.u = u
        self.v = v
    }
}

extension BG3DTextureCoord: ExpressibleByParsing {
    public init(parsing input: inout ParserSpan) throws {
        let u = Float(bitPattern: try UInt32(parsingBigEndian: &input))
        let v = Float(bitPattern: try UInt32(parsingBigEndian: &input))
        self.init(u: u, v: v)
    }
}

/// RGBA color with float components (used for material diffuse color).
public struct BG3DColorRGBA: Sendable, Equatable {
    public var r: Float
    public var g: Float
    public var b: Float
    public var a: Float

    public init(r: Float, g: Float, b: Float, a: Float) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
}

extension BG3DColorRGBA: ExpressibleByParsing {
    public init(parsing input: inout ParserSpan) throws {
        let r = Float(bitPattern: try UInt32(parsingBigEndian: &input))
        let g = Float(bitPattern: try UInt32(parsingBigEndian: &input))
        let b = Float(bitPattern: try UInt32(parsingBigEndian: &input))
        let a = Float(bitPattern: try UInt32(parsingBigEndian: &input))
        self.init(r: r, g: g, b: b, a: a)
    }
}

/// RGBA color with byte components (on-disk vertex color encoding).
public struct BG3DColorRGBAByte: Sendable, Equatable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8
    public var a: UInt8
}

extension BG3DColorRGBAByte: ExpressibleByParsing {
    public init(parsing input: inout ParserSpan) throws {
        r = try UInt8(parsing: &input)
        g = try UInt8(parsing: &input)
        b = try UInt8(parsing: &input)
        a = try UInt8(parsing: &input)
    }
}

/// Axis-aligned bounding box. Matches C `OGLBoundingBox`: `OGLPoint3D min;
/// OGLPoint3D max; Boolean isEmpty;` - the trailing `Boolean` (1 byte) is
/// padded to 4-byte alignment on disk, for 28 bytes total.
public struct BG3DBoundingBox: Sendable, Equatable {
    public var min: BG3DPoint3D
    public var max: BG3DPoint3D
    public var isEmpty: Bool
}

extension BG3DBoundingBox: ExpressibleByParsing {
    public init(parsing input: inout ParserSpan) throws {
        min = try BG3DPoint3D(parsing: &input)
        max = try BG3DPoint3D(parsing: &input)
        isEmpty = try UInt8(parsing: &input) != 0
        try input.seek(toRelativeOffset: 3)  // trailing alignment padding
    }
}

/// One triangle's 3 vertex indices.
public struct BG3DTriangle: Sendable, Equatable {
    public var vertexIndices: (UInt32, UInt32, UInt32)

    public init(vertexIndices: (UInt32, UInt32, UInt32)) {
        self.vertexIndices = vertexIndices
    }

    public static func == (lhs: BG3DTriangle, rhs: BG3DTriangle) -> Bool {
        lhs.vertexIndices == rhs.vertexIndices
    }
}

extension BG3DTriangle: ExpressibleByParsing {
    public init(parsing input: inout ParserSpan) throws {
        let a = try UInt32(parsingBigEndian: &input)
        let b = try UInt32(parsingBigEndian: &input)
        let c = try UInt32(parsingBigEndian: &input)
        self.init(vertexIndices: (a, b, c))
    }
}
