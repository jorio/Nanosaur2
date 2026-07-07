// BinaryParsing is a separate module when this package is built via SPM
// (tests), but its sources are compiled flat into the same module as the
// rest of the game when built via CMake/Ninja - see extern/swift-binary-parsing.
#if canImport(BinaryParsing)
import BinaryParsing
#endif

/// The fixed 20-byte file header: a 16-byte identifier string followed by a
/// classic Mac OS `NumVersion` (4 bytes, BCD-encoded, big-endian on disk).
///
/// Matches the C `BG3DHeaderType` in `Source/Headers/bg3d.h`:
/// `char headerString[16]; NumVersion version;`
public struct BG3DHeader: Sendable, Equatable {
    public var headerString: [UInt8]
    public var majorRev: UInt8
    public var minorAndBugRev: UInt8
    public var stage: UInt8
    public var nonRelRev: UInt8

    /// True if the first 4 bytes of `headerString` spell "BG3D".
    public var isValid: Bool {
        headerString.count >= 4
            && headerString[0] == 0x42  // 'B'
            && headerString[1] == 0x47  // 'G'
            && headerString[2] == 0x33  // '3'
            && headerString[3] == 0x44  // 'D'
    }
}

extension BG3DHeader: ExpressibleByParsing {
    public init(parsing input: inout ParserSpan) throws {
        headerString = try [UInt8](parsing: &input, byteCount: 16)
        majorRev = try UInt8(parsing: &input)
        minorAndBugRev = try UInt8(parsing: &input)
        stage = try UInt8(parsing: &input)
        nonRelRev = try UInt8(parsing: &input)
    }
}
