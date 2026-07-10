// ResourceFile.swift - Parser for classic Mac OS resource-fork files
// (the .rsrc / .ter.rsrc files under Data/), replacing Pomme's
// GetResource/FSpOpenResFile/Handle-based Resource Manager emulation
// (extern/Pomme/src/Files/Resources.cpp) with a pure, tested, standalone
// parser - same approach as Sources/BG3DFile for the BG3D model format.
//
// Format (Inside Macintosh: Files, "Resource Manager"):
//   Resource header (16 bytes): dataOffset(UInt32) mapOffset(UInt32)
//     dataLength(UInt32) mapLength(UInt32), followed by 240 bytes of
//     reserved system/app data (256 bytes total before the data section).
//   Resource map (at mapOffset): 16 bytes reserved copy of header + 4 bytes
//     next-resource-map handle + 2 bytes file ref num + 2 bytes file
//     attributes + 2 bytes type-list offset (relative to mapOffset) + 2
//     bytes name-list offset (relative to mapOffset) = 28 bytes, followed by
//     the type list.
//   Type list (at typeListOff): UInt16 (resource-type count minus 1), then
//     per type: OSType(4) + UInt16 (resource count minus 1) + UInt16
//     (reference-list offset, relative to typeListOff).
//   Reference list (at refListOff, per type): per resource: SInt16 id(2) +
//     UInt16 name offset (relative to nameListOff, or 0xFFFF if unnamed)(2)
//     + UInt32 packed attributes (top byte = flags, low 3 bytes = data
//     offset relative to dataOffset)(4) + 4 bytes junk (handle) = 12 bytes.
//   Resource data (at dataOffset + packed offset): SInt32 length, then the
//     resource's raw bytes.
//   Resource name (at nameListOff + name offset, if present): Pascal string
//     (1-byte length prefix + that many bytes).
#if canImport(BinaryParsing)
import BinaryParsing
#endif

public enum ResourceFileParsingError: Error, Sendable, Equatable {
    case notAppleDouble
    case noResourceForkEntry
    case compressedResourceUnsupported
}

// See BG3DFile.swift's bg3dThrow for why this is needed: ThrownParsingError
// aliases the concrete ParsingError type (with no user-error payload) under
// Embedded Swift, so ResourceFileParsingError's specific cases can't be
// carried through there - downgrades to a plain `.invalidValue` status.
#if $Embedded
private func resourceFileThrow(_ error: ResourceFileParsingError) -> ParsingError {
    ParsingError(statusOnly: .invalidValue)
}
#else
private func resourceFileThrow(_ error: ResourceFileParsingError) -> ResourceFileParsingError {
    error
}
#endif

public struct ResourceFileEntry: Sendable, Equatable {
    public var type: UInt32 // OSType, e.g. 'Bone'
    public var id: Int16
    public var name: String?
    public var data: [UInt8]
}

/// A fully parsed classic-Mac resource-fork file. Pure data representation -
/// callers look up resources by type/id, same as `GetResource`/`Get1Resource`
/// did against Pomme's Resource Manager emulation.
public struct ResourceFile: Sendable, Equatable {
    public var entries: [ResourceFileEntry]

    /// Equivalent of `GetResource(type, id)` - returns the resource's raw
    /// bytes, or nil if not present.
    public func resource(type: UInt32, id: Int16) -> [UInt8]? {
        entries.first(where: { $0.type == type && $0.id == id })?.data
    }

    /// Equivalent of `Get1IndResource(type, index)` (1-based index, in
    /// ascending id order, matching the ordered-map iteration Pomme uses).
    public func resource(type: UInt32, index: Int) -> ResourceFileEntry? {
        let matches = entries.filter { $0.type == type }.sorted { $0.id < $1.id }
        guard index >= 1, index <= matches.count else { return nil }
        return matches[index - 1]
    }
}

extension ResourceFile: ExpressibleByParsing {
    public init(parsing input: inout ParserSpan) throws(ThrownParsingError) {
        // These .rsrc files aren't raw resource-fork data - they're wrapped
        // in AppleDouble format (the standard way to store a classic Mac
        // resource fork as a standalone file on a non-HFS filesystem; see
        // extern/Pomme/src/Files/HostVolume.cpp's ADFJumpToResourceFork,
        // which this mirrors). AppleDouble header: magic
        // 0x00051607_00020000 (8 bytes) + 16 bytes filler + UInt16 entry
        // count, then per entry: entryID(4) + offset(4) + length(4). Entry
        // ID 2 is the resource fork; everything from its offset onward is
        // the classic resource-fork format below.
        let adfMagic = try UInt64(parsingBigEndian: &input)
        guard adfMagic == 0x0005_1607_0002_0000 else {
            throw resourceFileThrow(.notAppleDouble)
        }
        input = try input.seeking(toRelativeOffset: 16) // filler
        let numEntries = Int(try UInt16(parsingBigEndian: &input))

        var resForkOffset: Int?
        for _ in 0..<numEntries {
            let entryID = try UInt32(parsingBigEndian: &input)
            let entryOffset = try Int(UInt32(parsingBigEndian: &input))
            input = try input.seeking(toRelativeOffset: 4) // length
            if entryID == 2 {
                resForkOffset = entryOffset
                break
            }
        }
        guard let resForkOffset else {
            throw resourceFileThrow(.noResourceForkEntry)
        }

        var forkInput = try input.seeking(toAbsoluteOffset: resForkOffset)
        let dataSectionOff = resForkOffset + Int(try UInt32(parsingBigEndian: &forkInput))
        let mapSectionOff = resForkOffset + Int(try UInt32(parsingBigEndian: &forkInput))
        // (dataSectionLen, mapSectionLen, and the 112+128 bytes of
        // system/app-reserved data that follow aren't needed - everything
        // else is read via absolute seeks below.)

        var mapInput = try input.seeking(toAbsoluteOffset: mapSectionOff)
        // reserved copy of header(16) + next-resource-map handle(4) + file ref num(2) + file attributes(2)
        mapInput = try mapInput.seeking(toRelativeOffset: 16 + 4 + 2 + 2)
        let typeListOff = mapSectionOff + Int(try UInt16(parsingBigEndian: &mapInput))
        let nameListOff = mapSectionOff + Int(try UInt16(parsingBigEndian: &mapInput))

        var typeListInput = try input.seeking(toAbsoluteOffset: typeListOff)
        let numTypes = 1 + Int(try UInt16(parsingBigEndian: &typeListInput))

        var entries: [ResourceFileEntry] = []

        for _ in 0..<numTypes {
            let resType = try UInt32(parsingBigEndian: &typeListInput)
            let resCount = 1 + Int(try UInt16(parsingBigEndian: &typeListInput))
            let refListOff = typeListOff + Int(try UInt16(parsingBigEndian: &typeListInput))

            var refListInput = try input.seeking(toAbsoluteOffset: refListOff)

            for _ in 0..<resCount {
                let resID = Int16(bitPattern: try UInt16(parsingBigEndian: &refListInput))
                let nameRelOff = try UInt16(parsingBigEndian: &refListInput)
                let packedAttr = try UInt32(parsingBigEndian: &refListInput)
                refListInput = try refListInput.seeking(toRelativeOffset: 4) // junk (in-memory handle)

                let resFlags = UInt8((packedAttr & 0xFF00_0000) >> 24)
                guard (resFlags & 1) == 0 else {
                    throw resourceFileThrow(.compressedResourceUnsupported)
                }
                let resDataOff = dataSectionOff + Int(packedAttr & 0x00FF_FFFF)

                var name: String?
                if nameRelOff != 0xFFFF {
                    var nameInput = try input.seeking(toAbsoluteOffset: nameListOff + Int(nameRelOff))
                    let nameLength = Int(try UInt8(parsing: &nameInput))
                    name = try String(parsingUTF8: &nameInput, count: nameLength)
                }

                var dataInput = try input.seeking(toAbsoluteOffset: resDataOff)
                let size = Int(try Int32(parsingBigEndian: &dataInput))
                let data = try [UInt8](parsing: &dataInput, byteCount: size)

                entries.append(ResourceFileEntry(type: resType, id: resID, name: name, data: data))
            }
        }

        self.entries = entries
    }
}
