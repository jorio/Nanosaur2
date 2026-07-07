import Foundation
import Testing

@testable import BG3DFile

private func fixtureURLs() -> [URL] {
    let root = Bundle.module.resourceURL!.appendingPathComponent("Fixtures")
    let fm = FileManager.default
    let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil)!
    return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "bg3d" }.sorted {
        $0.lastPathComponent < $1.lastPathComponent
    }
}

@Test func allFixturesHaveValidHeader() throws {
    let urls = fixtureURLs()
    #expect(!urls.isEmpty)
    for url in urls {
        let data = try Data(contentsOf: url)
        let file = try BG3DFile(parsing: data)
        #expect(file.header.isValid, "\(url.lastPathComponent) should have a valid BG3D header")
        #expect(file.header.majorRev == 1, "\(url.lastPathComponent) major version")
    }
}

@Test func allFixturesParseWithoutError() throws {
    for url in fixtureURLs() {
        let data = try Data(contentsOf: url)
        let file = try BG3DFile(parsing: data)
        #expect(!file.chunks.isEmpty, "\(url.lastPathComponent) should contain at least one chunk")
    }
}

@Test func weaponsHeaderMatchesKnownBytes() throws {
    // Verified by hand via `xxd` against Data/Models/weapons.bg3d:
    // "BG3D 1.0        " + 01 00 00 00 (NumVersion 1.0.0.0), followed
    // immediately by a materialFlags(1) / materialDiffuseColor(1,1,1,1) /
    // jpegTexture(128x128) chunk sequence.
    let url = fixtureURLs().first { $0.lastPathComponent == "weapons.bg3d" }!
    let data = try Data(contentsOf: url)
    let file = try BG3DFile(parsing: data)

    #expect(file.header.majorRev == 1)
    #expect(file.header.minorAndBugRev == 0)

    guard case .materialFlags(let flags) = file.chunks[0] else {
        Issue.record("expected materialFlags as first chunk")
        return
    }
    #expect(flags == 1)

    guard case .materialDiffuseColor(let color) = file.chunks[1] else {
        Issue.record("expected materialDiffuseColor as second chunk")
        return
    }
    #expect(color == BG3DColorRGBA(r: 1, g: 1, b: 1, a: 1))

    guard case .jpegTexture(let header, let jpegData, _) = file.chunks[2] else {
        Issue.record("expected jpegTexture as third chunk")
        return
    }
    #expect(header.width == 128)
    #expect(header.height == 128)
    #expect(header.bufferSize == 0xF2C)
    #expect(jpegData.count == Int(header.bufferSize))
}

@Test func geometryChunksHaveConsistentPointAndTriangleCounts() throws {
    // For every geometry header, the vertexArray/normalArray/uvArray/
    // colorArray that follow it must carry exactly numPoints elements, and
    // triangleArray must carry exactly numTriangles - this is exactly the
    // invariant that a byte-layout bug in the header structs would violate
    // (wrong counts read -> wrong-sized array parsed -> stream desync).
    for url in fixtureURLs() {
        let data = try Data(contentsOf: url)
        let file = try BG3DFile(parsing: data)

        var expectedPoints = 0
        var expectedTriangles = 0

        for chunk in file.chunks {
            switch chunk {
            case .geometry(let header):
                expectedPoints = Int(header.numPoints)
                expectedTriangles = Int(header.numTriangles)
                #expect(header.type == BG3DGeometryType.vertexElements.rawValue)

            case .vertexArray(let points):
                #expect(points.count == expectedPoints, "\(url.lastPathComponent) vertexArray count")

            case .normalArray(let normals):
                #expect(normals.count == expectedPoints, "\(url.lastPathComponent) normalArray count")

            case .uvArray(let uvs):
                #expect(uvs.count == expectedPoints, "\(url.lastPathComponent) uvArray count")

            case .colorArray(let colors):
                #expect(colors.count == expectedPoints, "\(url.lastPathComponent) colorArray count")

            case .triangleArray(let triangles):
                #expect(triangles.count == expectedTriangles, "\(url.lastPathComponent) triangleArray count")

            default:
                break
            }
        }
    }
}

@Test func groupStartsAndEndsBalance() throws {
    for url in fixtureURLs() {
        let data = try Data(contentsOf: url)
        let file = try BG3DFile(parsing: data)

        var depth = 0
        for chunk in file.chunks {
            switch chunk {
            case .groupStart: depth += 1
            case .groupEnd: depth -= 1
            default: break
            }
            #expect(depth >= 0, "\(url.lastPathComponent) groupEnd without matching groupStart")
        }
        #expect(depth == 0, "\(url.lastPathComponent) unbalanced groupStart/groupEnd")
    }
}

@Test func textureBufferSizesAreConsistent() throws {
    for url in fixtureURLs() {
        let data = try Data(contentsOf: url)
        let file = try BG3DFile(parsing: data)

        for chunk in file.chunks {
            switch chunk {
            case .textureMap(let header, let pixels):
                #expect(pixels.count == Int(header.bufferSize), "\(url.lastPathComponent) textureMap buffer size")

            case .jpegTexture(let header, let jpegData, let alphaChannel):
                #expect(jpegData.count == Int(header.bufferSize), "\(url.lastPathComponent) jpegTexture buffer size")
                if header.hasAlphaChannel != 0 {
                    #expect(
                        alphaChannel?.count == Int(header.width) * Int(header.height),
                        "\(url.lastPathComponent) jpegTexture alpha channel size")
                } else {
                    #expect(alphaChannel == nil)
                }

            default:
                break
            }
        }
    }
}
