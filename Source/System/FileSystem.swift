// FileSystem.swift - Native file-path resolution & I/O, replacing Pomme's
// Files/HostVolume Mac-toolbox emulation (FSMakeFSSpec/FSpOpenDF/FSRead/
// FSWrite/FSClose/GetEOF/FSpDelete/FindFolder/DirCreate).
//
// FSSpec keeps its C struct shape (game.h still declares `FSSpec gDataSpec`,
// and Boot.cpp/the bridging header reference it), but the resolution model
// changes: `parID` is now an index into gEngine.fs.directoryRegistry (absolute
// directory paths) rather than one of Pomme's HostVolume directory IDs,
// `vRefNum` is unused (always 0), and `cName` is a plain C string holding
// the leaf filename - not a Pascal string, despite the Str255 typedef (see
// feedback_pomme_str255_not_pascal memory: Pomme's own FSSpec never used
// Pascal-string semantics for cName either, this just keeps that).
//
// No `import Foundation`/`import Darwin` here - both pull in the Darwin SDK
// module's Point/Boolean-style legacy Carbon typedefs, which collide with
// Pomme's own definitions of the same names (the same class of problem that
// blocked the SwiftPM migration attempt). Instead, open/read/write/close/
// lseek/mkdir/unlink/access are declared as plain C functions in file.h
// (via #include <fcntl.h>/<unistd.h>/<sys/stat.h>, included through the
// project's bridging header like everything else) so they're ambiently
// visible here with no import at all - same as every other C symbol in this
// codebase.
//
// Case-insensitive path matching (Pomme's CaseInsensitiveAppendToPath) isn't
// replicated - this game's own path strings already match the on-disk
// casing exactly, and macOS's default filesystem (APFS, case-insensitive)
// resolves case mismatches at the OS level anyway.

private let kSwNoErr: OSErr = 0
private let kSwNsvErr: OSErr = -35 // Volume doesn't exist
private let kSwIoErr: OSErr = -36 // I/O error
private let kSwEofErr: OSErr = -39 // End-of-file reached
private let kSwFnfErr: OSErr = -43 // File not found
private let kSwRfNumErr: OSErr = -51 // Invalid reference number

/// FSSpec-emulation state. Owned by GameEngine as `gEngine.fs`.
final class FSSystem {
    fileprivate var directoryRegistry: [String] = []
    fileprivate var openFiles: [Int16: Int32] = [:] // refNum -> POSIX fd
    fileprivate var nextRefNum: Int16 = 1
}

private func swRegisterDirectory(_ path: String) -> Int {
    if let existing = gEngine.fs.directoryRegistry.firstIndex(of: path) {
        return existing
    }
    gEngine.fs.directoryRegistry.append(path)
    return gEngine.fs.directoryRegistry.count - 1
}

private func swDirectoryPath(_ parID: Int) -> String? {
    guard parID >= 0, parID < gEngine.fs.directoryRegistry.count else { return nil }
    return gEngine.fs.directoryRegistry[parID]
}

// MARK: - Plain path-string helpers (no URL/Foundation)

private func swDeletingLastPathComponent(_ path: String) -> String {
    guard let slash = path.lastIndex(of: "/") else { return "" }
    let dir = String(path[path.startIndex..<slash])
    return dir.isEmpty ? "/" : dir
}

private func swLastPathComponent(_ path: String) -> String {
    guard let slash = path.lastIndex(of: "/") else { return path }
    return String(path[path.index(after: slash)...])
}

private func swMakeDirectory(_ path: String) {
    // mkdir -p: walk components, creating each ancestor that doesn't exist yet.
    var current = ""
    for component in path.split(separator: "/", omittingEmptySubsequences: true) {
        current += "/" + component
        mkdir(current, 0o755) // ignores EEXIST (return value not checked)
    }
}

private func swFileExists(_ path: String) -> Bool {
    access(path, SwF_OK) == 0
}

// MARK: - Colon-path resolution

// Splits a colon-separated path (e.g. ":Skeletons:raptor.skeleton" or
// ":Sprites:maps:battle1") relative to `baseDir` into (parentDir, leaf).
// A leading colon is stripped; each further colon-separated component
// (other than the last) is a directory to descend into; an empty component
// (from "::") means "go to parent directory" - though nothing in this
// codebase's own path strings actually uses "::".
private func resolveColonPath(_ baseDir: String, _ colonPath: String) -> (parentDir: String, leaf: String) {
    var suffix = Substring(colonPath)
    if suffix.first == ":" {
        suffix = suffix.dropFirst()
    }
    let components = suffix.split(separator: ":", omittingEmptySubsequences: false).map(String.init)

    var dir = baseDir
    for component in components.dropLast() {
        if component.isEmpty {
            dir = swDeletingLastPathComponent(dir)
        } else {
            dir += "/" + component
        }
    }

    return (dir, components.last ?? "")
}

// MARK: - cName helpers (plain C string, not Pascal - see file header comment)

private func setCName(_ spec: UnsafeMutablePointer<FSSpec>, _ name: String) {
    let cNamePtr = UnsafeMutableRawPointer(spec.pointer(to: \.cName)!).assumingMemoryBound(to: Int8.self)
    let utf8 = Array(name.utf8.prefix(255))
    for (i, byte) in utf8.enumerated() {
        cNamePtr[i] = Int8(bitPattern: byte)
    }
    cNamePtr[utf8.count] = 0
}

private func getCName(_ spec: UnsafePointer<FSSpec>) -> String {
    let cNamePtr = UnsafeRawPointer(spec.pointer(to: \.cName)!).assumingMemoryBound(to: Int8.self)
    return String(cString: cNamePtr)
}

private func resolvedPath(_ spec: UnsafePointer<FSSpec>) -> String? {
    guard let dir = swDirectoryPath(spec.pointee.parID) else { return nil }
    return dir + "/" + getCName(spec)
}

// MARK: - FSSpec construction

// Equivalent of Pomme::Files::HostPathToFSSpec - builds an FSSpec for an
// already-resolved absolute host path. Used once at boot for gDataSpec (see
// Boot.cpp).
@c @implementation
public func SwHostPathToFSSpec(_ cFullPath: UnsafePointer<Int8>?) -> FSSpec {
    let fullPath = String(cString: cFullPath!)

    var spec = FSSpec()
    spec.vRefNum = 0
    spec.parID = swRegisterDirectory(swDeletingLastPathComponent(fullPath))
    withUnsafeMutablePointer(to: &spec) { setCName($0, swLastPathComponent(fullPath)) }
    return spec
}

@c @implementation
public func SwFSMakeFSSpec(_ vRefNum: Int16, _ parID: Int, _ cstrFileName: UnsafePointer<Int8>?, _ spec: UnsafeMutablePointer<FSSpec>?) -> OSErr {
    guard let spec, let baseDir = swDirectoryPath(parID) else {
        return kSwNsvErr
    }

    let (parentDir, leaf) = resolveColonPath(baseDir, String(cString: cstrFileName!))

    spec.pointee.vRefNum = 0
    spec.pointee.parID = swRegisterDirectory(parentDir)
    setCName(spec, leaf)

    return swFileExists(parentDir + "/" + leaf) ? kSwNoErr : kSwFnfErr
}

// MARK: - Open-file registry (refNum-based, mirroring Pomme's own model)


@c @implementation
public func SwFSpOpenDF(_ spec: UnsafePointer<FSSpec>?, _ permission: Int8, _ refNum: UnsafeMutablePointer<Int16>?) -> OSErr {
    guard let spec, let path = resolvedPath(spec) else {
        return kSwNsvErr
    }

    let fd: Int32
    if permission == Int8(fsWrPerm.rawValue) || permission == Int8(fsRdWrPerm.rawValue) {
        fd = SwOpen(path, SwO_RDWR | SwO_CREAT, 0o644)
    } else {
        fd = SwOpen(path, SwO_RDONLY, 0)
    }

    guard fd >= 0 else {
        return kSwFnfErr
    }

    let newRefNum = gEngine.fs.nextRefNum
    gEngine.fs.nextRefNum += 1
    gEngine.fs.openFiles[newRefNum] = fd
    refNum?.pointee = newRefNum
    return kSwNoErr
}

@c @implementation
public func SwFSRead(_ refNum: Int16, _ count: UnsafeMutablePointer<Int>?, _ buffPtr: Ptr?) -> OSErr {
    guard let fd = gEngine.fs.openFiles[refNum], let count, let buffPtr else {
        return kSwRfNumErr
    }
    let n = read(fd, buffPtr, UInt(count.pointee))
    guard n >= 0 else {
        return kSwIoErr
    }
    let short = n < count.pointee
    count.pointee = n
    return short ? kSwEofErr : kSwNoErr
}

@c @implementation
public func SwFSWrite(_ refNum: Int16, _ count: UnsafeMutablePointer<Int>?, _ buffPtr: Ptr?) -> OSErr {
    guard let fd = gEngine.fs.openFiles[refNum], let count, let buffPtr else {
        return kSwRfNumErr
    }
    let n = write(fd, buffPtr, UInt(count.pointee))
    guard n >= 0 else {
        return kSwIoErr
    }
    count.pointee = n
    return kSwNoErr
}

@c @implementation
public func SwFSClose(_ refNum: Int16) -> OSErr {
    guard let fd = gEngine.fs.openFiles.removeValue(forKey: refNum) else {
        return kSwRfNumErr
    }
    close(fd)
    return kSwNoErr
}

@c @implementation
public func SwGetEOF(_ refNum: Int16, _ logEOF: UnsafeMutablePointer<Int>?) -> OSErr {
    guard let fd = gEngine.fs.openFiles[refNum], let logEOF else {
        return kSwRfNumErr
    }
    let current = lseek(fd, 0, SwSEEK_CUR)
    let size = lseek(fd, 0, SwSEEK_END)
    lseek(fd, current, SwSEEK_SET)
    guard size >= 0 else {
        return kSwIoErr
    }
    logEOF.pointee = Int(size)
    return kSwNoErr
}

@c @implementation
public func SwFSpDelete(_ spec: UnsafePointer<FSSpec>?) -> OSErr {
    guard let spec, let path = resolvedPath(spec) else {
        return kSwNsvErr
    }
    unlink(path)
    return kSwNoErr
}

// MARK: - Preferences folder

@c @implementation
public func SwFindFolder(_ vRefNum: Int16, _ folderType: OSType, _ createFolder: Int8, _ foundVRefNum: UnsafeMutablePointer<Int16>?, _ foundDirID: UnsafeMutablePointer<Int>?) -> OSErr {
    guard let home = getenv("HOME") else {
        return kSwNsvErr
    }
    let path = String(cString: home) + "/Library/Application Support"
    swMakeDirectory(path)
    foundVRefNum?.pointee = 0
    foundDirID?.pointee = swRegisterDirectory(path)
    return kSwNoErr
}

@c @implementation
public func SwDirCreate(_ vRefNum: Int16, _ parentDirID: Int, _ cstrDirectoryName: UnsafePointer<Int8>?, _ createdDirID: UnsafeMutablePointer<Int>?) -> OSErr {
    guard let baseDir = swDirectoryPath(parentDirID) else {
        return kSwNsvErr
    }
    let path = baseDir + "/" + String(cString: cstrDirectoryName!)
    swMakeDirectory(path)
    createdDirID?.pointee = swRegisterDirectory(path)
    return kSwNoErr
}

// creator/fileType/scriptTag are ignored - see the C declaration's comment.
@c @implementation
public func SwFSpCreate(_ spec: UnsafePointer<FSSpec>?, _ creator: OSType, _ fileType: OSType, _ scriptTag: Int16) -> OSErr {
    guard let spec, let path = resolvedPath(spec) else {
        return kSwNsvErr
    }
    let fd = SwOpen(path, SwO_RDWR | SwO_CREAT, 0o644)
    guard fd >= 0 else {
        return kSwIoErr
    }
    close(fd)
    return kSwNoErr
}
