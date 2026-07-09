// BinaryParsing is a separate module when this package is built via SPM
// (tests), but its sources are compiled flat into the same module as the
// rest of the game when built via CMake/Ninja - see extern/swift-binary-parsing.
#if canImport(BinaryParsing)
import BinaryParsing
#endif

public enum BG3DParsingError: Error, Sendable, Equatable {
    case invalidMagic
    case unknownTag(UInt32)
}

// ThrownParsingError is `any Error` in non-Embedded builds (so any error
// type, including BG3DParsingError, throws through unchanged) but aliases
// the concrete `ParsingError` type under Embedded Swift (ports/3DS build),
// which has no user-error payload in that configuration (ParsingError's
// `init(userError:)` and `userError` property are both `#if !$Embedded`) -
// there's no way to carry BG3DParsingError's specific case through, so this
// downgrades to a plain `.invalidValue` status there instead.
#if $Embedded
private func bg3dThrow(_ error: BG3DParsingError) -> ParsingError {
    ParsingError(statusOnly: .invalidValue)
}
#else
private func bg3dThrow(_ error: BG3DParsingError) -> BG3DParsingError {
    error
}
#endif

/// One entry in the tag-stream body of a BG3D file. `.endFile` is not
/// represented here — reaching it ends parsing.
public enum BG3DChunk: Sendable, Equatable {
    case materialFlags(UInt32)
    case materialDiffuseColor(BG3DColorRGBA)
    case textureMap(header: BG3DTextureHeader, pixels: [UInt8])
    case jpegTexture(header: BG3DJPEGTextureHeader, jpegData: [UInt8], alphaChannel: [UInt8]?)
    case groupStart
    case groupEnd
    case geometry(BG3DGeometryHeader)
    case vertexArray([BG3DPoint3D])
    case normalArray([BG3DPoint3D])
    case uvArray([BG3DTextureCoord])
    case colorArray([BG3DColorRGBAByte])
    case triangleArray([BG3DTriangle])
    case boundingBox(BG3DBoundingBox)
}

/// A fully parsed BG3D model/skeleton-reference file: the models under
/// `Data/Models` and `Data/Skeletons`.
///
/// This is a pure data representation of the file's tag stream — it doesn't
/// build any OpenGL objects or engine state. The game engine walks `chunks`
/// in order (mirroring the original imperative `parseBG3DFile` in
/// `Source/3D/Bg3d.swift`) to build its own in-memory model.
public struct BG3DFile: Sendable, Equatable {
    public var header: BG3DHeader
    public var chunks: [BG3DChunk]
}

extension BG3DFile: ExpressibleByParsing {
    public init(parsing input: inout ParserSpan) throws(ThrownParsingError) {
        let header = try BG3DHeader(parsing: &input)
        guard header.isValid else { throw bg3dThrow(.invalidMagic) }
        self.header = header

        var chunks: [BG3DChunk] = []

        // The vertex/normal/uv/color/triangle chunks are self-describing
        // only in terms of *count*, not byte length - the count comes from
        // the most recently parsed `geometry` chunk, exactly as the
        // imperative C/Swift reader tracks it via `gBG3D_CurrentGeometryObj`.
        var currentNumPoints = 0
        var currentNumTriangles = 0

        while true {
            let rawTag = try UInt32(parsingBigEndian: &input)
            guard let tag = BG3DTag(rawValue: rawTag) else {
                throw bg3dThrow(.unknownTag(rawTag))
            }

            switch tag {
            case .materialFlags:
                let flags = try UInt32(parsingBigEndian: &input)
                chunks.append(.materialFlags(flags))

            case .materialDiffuseColor:
                let color = try BG3DColorRGBA(parsing: &input)
                chunks.append(.materialDiffuseColor(color))

            case .textureMap:
                let texHeader = try BG3DTextureHeader(parsing: &input)
                let pixels = try [UInt8](parsing: &input, byteCount: Int(texHeader.bufferSize))
                chunks.append(.textureMap(header: texHeader, pixels: pixels))

            case .jpegTexture:
                let jpegHeader = try BG3DJPEGTextureHeader(parsing: &input)
                let jpegData = try [UInt8](parsing: &input, byteCount: Int(jpegHeader.bufferSize))
                var alphaChannel: [UInt8]?
                if jpegHeader.hasAlphaChannel != 0 {
                    let alphaByteCount = Int(jpegHeader.width) * Int(jpegHeader.height)
                    alphaChannel = try [UInt8](parsing: &input, byteCount: alphaByteCount)
                }
                chunks.append(.jpegTexture(header: jpegHeader, jpegData: jpegData, alphaChannel: alphaChannel))

            case .groupStart:
                chunks.append(.groupStart)

            case .groupEnd:
                chunks.append(.groupEnd)

            case .geometry:
                let geoHeader = try BG3DGeometryHeader(parsing: &input)
                currentNumPoints = Int(geoHeader.numPoints)
                currentNumTriangles = Int(geoHeader.numTriangles)
                chunks.append(.geometry(geoHeader))

            case .vertexArray:
                let points = try Array(parsing: &input, count: currentNumPoints) { (span: inout ParserSpan) throws(ParsingError) in
                    try BG3DPoint3D(parsing: &span)
                }
                chunks.append(.vertexArray(points))

            case .normalArray:
                let normals = try Array(parsing: &input, count: currentNumPoints) { (span: inout ParserSpan) throws(ParsingError) in
                    try BG3DPoint3D(parsing: &span)
                }
                chunks.append(.normalArray(normals))

            case .uvArray:
                let uvs = try Array(parsing: &input, count: currentNumPoints) { (span: inout ParserSpan) throws(ParsingError) in
                    try BG3DTextureCoord(parsing: &span)
                }
                chunks.append(.uvArray(uvs))

            case .colorArray:
                let colors = try Array(parsing: &input, count: currentNumPoints) { (span: inout ParserSpan) throws(ParsingError) in
                    try BG3DColorRGBAByte(parsing: &span)
                }
                chunks.append(.colorArray(colors))

            case .triangleArray:
                let triangles = try Array(parsing: &input, count: currentNumTriangles) { (span: inout ParserSpan) throws(ParsingError) in
                    try BG3DTriangle(parsing: &span)
                }
                chunks.append(.triangleArray(triangles))

            case .boundingBox:
                let bbox = try BG3DBoundingBox(parsing: &input)
                chunks.append(.boundingBox(bbox))

            case .endFile:
                self.chunks = chunks
                return
            }
        }
    }
}
