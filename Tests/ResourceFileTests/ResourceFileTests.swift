import Foundation
import Testing

@testable import ResourceFile

// Reads real assets directly from Data/Skeletons and Data/Terrain instead of
// copying/symlinking them into a test bundle - see BG3DFileTests.swift for
// the same pattern.
private func fixtureURLs() -> [URL] {
    let testFileURL = URL(fileURLWithPath: #filePath)
    let repoRoot = testFileURL
        .deletingLastPathComponent() // ResourceFileTests.swift -> ResourceFileTests/
        .deletingLastPathComponent() // ResourceFileTests/ -> Tests/
        .deletingLastPathComponent() // Tests/ -> repo root
    let dataDir = repoRoot.appendingPathComponent("Data")

    let fm = FileManager.default
    return ["Skeletons", "Terrain"].flatMap { subdir -> [URL] in
        let dir = dataDir.appendingPathComponent(subdir)
        guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: nil) else { return [] }
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "rsrc" }
    }.sorted { $0.lastPathComponent < $1.lastPathComponent }
}

@Test func allFixturesParseWithoutError() throws {
    let urls = fixtureURLs()
    #expect(!urls.isEmpty)
    for url in urls {
        let data = try Data(contentsOf: url)
        let file = try ResourceFile(parsing: data)
        #expect(!file.entries.isEmpty, "\(url.lastPathComponent) should contain at least one resource")
    }
}

@Test func raptorSkeletonHasExpectedResources() throws {
    let url = fixtureURLs().first { $0.lastPathComponent == "raptor.skeleton.rsrc" }!
    let data = try Data(contentsOf: url)
    let file = try ResourceFile(parsing: data)

    // 'Hedr' resource 1000 is the skeleton header, present in every skeleton file.
    let kResHedr: UInt32 = 0x4865_6472 // 'Hedr'
    let header = file.resource(type: kResHedr, id: 1000)
    #expect(header != nil)
    #expect((header?.count ?? 0) > 0)

    // 'Bone' resource 1000 (the first bone) should also be present.
    let kResBone: UInt32 = 0x426F_6E65 // 'Bone'
    let bone = file.resource(type: kResBone, id: 1000)
    #expect(bone != nil)
}

@Test func resourceNamesRoundTripWhenPresent() throws {
    // Not every resource is named, but if any are, the name shouldn't be
    // empty/garbage (verifies the Pascal-string offset math independently of
    // the raw resource-data offset math).
    for url in fixtureURLs() {
        let data = try Data(contentsOf: url)
        let file = try ResourceFile(parsing: data)
        for entry in file.entries {
            if let name = entry.name {
                #expect(!name.isEmpty, "\(url.lastPathComponent) resource \(entry.id) has an empty (but present) name")
            }
        }
    }
}
