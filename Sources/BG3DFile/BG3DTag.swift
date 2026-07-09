/// Chunk tag values from the BG3D file format's tag-stream body.
///
/// Mirrors the C `BG3D_TAGTYPE_*` enum in `Source/Headers/bg3d.h`.
public enum BG3DTag: UInt32, Sendable {
    case materialFlags = 0
    case materialDiffuseColor = 1
    case textureMap = 2
    case groupStart = 3
    case groupEnd = 4
    case geometry = 5
    case vertexArray = 6
    case normalArray = 7
    case uvArray = 8
    case colorArray = 9
    case triangleArray = 10
    case endFile = 11
    case boundingBox = 12
    case jpegTexture = 13
}
