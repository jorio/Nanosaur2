// Terrain.swift - Port of Terrain.c to Swift
//
// All of Terrain.c's/Terrain2.c's extern scalar/pointer/2D-array globals
// are native Swift storage now (converted 2026-07-07): nothing in any .c
// file touches them anymore - the old comment claiming other C files
// still needed them via extern was stale (same pattern as bg3d.c/
// OGL_Support.c/etc. this session). gSuperTileTextureObjects/
// gSuperTileMemoryList/gLineMarkerList were fixed-size C arrays exposed to
// other files via Get*Entry/Get*Ptr/Get*Slot shims (too large for a Swift
// tuple - MAX_SUPERTILES/MAX_SUPERTILE_TEXTURES are in the thousands);
// they're now permanent, never-freed UnsafeMutablePointer buffers (same
// "allocate once, address is stable forever" idiom as MenuBuilder.swift's
// makeMenuTreeBuffer), with the accessor functions reimplemented in plain
// Swift under the exact same names/signatures as the old C shims so their
// ~15 call sites elsewhere (File.swift, Pick.swift, Player_Race.swift,
// Player_Terrain.swift, Terrain2.swift) didn't need to change.
//
// The master supertile mesh/triangle/coord/uv/normal/color arrays,
// gEngine.terrain.workGrid, the tile-triangle-splitting tables, gEngine.terrain.hiccupTimer,
// gEngine.terrain.numSuperTilesDrawn, gEngine.terrain.numFreeSupertiles, and the (dead,
// VERTEXARRAYRANGES==0) OpenGL fence variables are only ever touched from
// this file, so they stay private Swift storage.
//
// VERTEXARRAYRANGES is hardcoded 0 in game.h, so all `#if VERTEXARRAYRANGES`
// blocks (OpenGL fence sync) are dead code and dropped. HQ_TERRAIN is
// hardcoded 1, so that branch is kept (unconditionally, no #if needed).

// MAX_SUPERTILE_TEXTURES is a multi-macro expression ClangImporter can't
// fold into a single constant: MAX_SUPERTILES_WIDE*MAX_SUPERTILES_DEEP,
// where each is MAX_TERRAIN_{WIDTH,DEPTH}(400)/SUPERTILE_SIZE(8) = 50.
private let maxSuperTileTextures = 50 * 50

// MAX_SUPERTILES/NUM_TRIS_IN_SUPERTILE/NUM_VERTICES_IN_SUPERTILE are multi-macro
// expressions ClangImporter can't fold into single constants.
private let maxSupertiles = (9 * 2 * 9 * 2) * 2 * 2 // MAX_SUPERTILES: (MAX_SUPERTILE_ACTIVE_RANGE*2 * MAX_SUPERTILE_ACTIVE_RANGE*2)*MAX_SPLITSCREENS * 2
private let numTrisInSupertile = Int(SUPERTILE_SIZE) * Int(SUPERTILE_SIZE) * 2
private let numVerticesInSupertile = (Int(SUPERTILE_SIZE) + 1) * (Int(SUPERTILE_SIZE) + 1)

/// Terrain state: scale factors, supertile grids/buffers, terrain-item
/// list, line markers, scroll tracking. Owned by GameEngine as
/// `gEngine.terrain`.
final class TerrainSystem {
    var polygonSize: Float = 0
    var polygonSizeInt: UInt32 = 0
    var superTileUnitSize: Float = 0
    var superTileUnitSizeFrac: Float = 0
    var mapToUnitValue: Float = 0
    var mapToUnitValueFrac: Float = 0
    var superTileActiveRange: Int32 = 4
    var disableHiccupTimer: UInt8 = 0
    var superTileStatusGrid: UnsafeMutablePointer<UnsafeMutablePointer<SuperTileStatus>?>!
    var tileWidth: Int = 0
    var tileDepth: Int = 0
    var unitWidth: Int = 0
    var unitDepth: Int = 0
    var numUniqueSuperTiles: Int = 0
    var superTileTextureGrid: UnsafeMutablePointer<UnsafeMutablePointer<Int16>?>!
    var superTilePixelBuffers: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>!
    var vertexShading: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>!
    var numSuperTilesDeep: Int = 0
    var numSuperTilesWide: Int = 0
    var recentTerrainNormal = OGLVector3D()

    var numTerrainItems: Int32 = 0
    var masterItemList: UnsafeMutablePointer<TerrainItemEntryType>!
    var mapYCoords: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>!
    var mapYCoordsOriginal: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>!
    var mapSplitMode: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>!
    var superTileItemIndexGrid: UnsafeMutablePointer<UnsafeMutablePointer<SuperTileItemIndexType>?>!
    var numLineMarkers: Int32 = 0

    fileprivate let superTileTextureObjectsBuf: UnsafeMutablePointer<UnsafeMutablePointer<MOMaterialObject>?> = {
        let buf = UnsafeMutablePointer<UnsafeMutablePointer<MOMaterialObject>?>.allocate(capacity: maxSuperTileTextures)
        buf.initialize(repeating: nil, count: maxSuperTileTextures)
        return buf
    }()

    fileprivate let superTileMemoryListBuf: UnsafeMutablePointer<SuperTileMemoryType> = {
        let buf = UnsafeMutablePointer<SuperTileMemoryType>.allocate(capacity: maxSupertiles)
        buf.initialize(repeating: SuperTileMemoryType(), count: maxSupertiles)
        return buf
    }()

    fileprivate let lineMarkerListBuf: UnsafeMutablePointer<LineMarkerDefType> = {
        let buf = UnsafeMutablePointer<LineMarkerDefType>.allocate(capacity: Int(MAX_LINEMARKERS))
        buf.initialize(repeating: LineMarkerDefType(), count: Int(MAX_LINEMARKERS))
        return buf
    }()

    fileprivate var numSuperTilesDrawn: Int16 = 0
    fileprivate var hiccupTimer: UInt8 = 0

    // polygonSizeFrac had no `extern` declaration anywhere in the headers,
    // so it was always file-private to Terrain.c.
    fileprivate var polygonSizeFrac: Float = 0

    fileprivate var numFreeSupertiles: Int16 = 0

    // TILE SPLITTING TABLES - file-local only, plain nested Swift arrays.
    fileprivate var tileTriangles1_A = Array(repeating: Array(repeating: [UInt8](repeating: 0, count: 3), count: Int(SUPERTILE_SIZE)), count: Int(SUPERTILE_SIZE))
    fileprivate var tileTriangles2_A = Array(repeating: Array(repeating: [UInt8](repeating: 0, count: 3), count: Int(SUPERTILE_SIZE)), count: Int(SUPERTILE_SIZE))
    fileprivate var tileTriangles1_B = Array(repeating: Array(repeating: [UInt8](repeating: 0, count: 3), count: Int(SUPERTILE_SIZE)), count: Int(SUPERTILE_SIZE))
    fileprivate var tileTriangles2_B = Array(repeating: Array(repeating: [UInt8](repeating: 0, count: 3), count: Int(SUPERTILE_SIZE)), count: Int(SUPERTILE_SIZE))

    fileprivate var workGrid = Array(repeating: Array(repeating: OGLVertex(), count: Int(SUPERTILE_SIZE) + 1), count: Int(SUPERTILE_SIZE) + 1)

    // MASTER ARRAYS FOR ALL SUPERTILE DATA FOR CURRENT LEVEL
    fileprivate var superTileMeshData: UnsafeMutablePointer<MOVertexArrayData>?
    fileprivate var superTileTriangles: UnsafeMutablePointer<MOTriangleIndecies>?
    fileprivate var superTileCoords: UnsafeMutablePointer<OGLPoint3D>?
    fileprivate var superTileUVs: UnsafeMutablePointer<OGLTextureCoord>?
    fileprivate var superTileNormals: UnsafeMutablePointer<OGLVector3D>?
    fileprivate var superTileColors: UnsafeMutablePointer<OGLColorRGBA>?

    // Scroll tracking - was `static int[MAX_PLAYERS]` in the original C,
    // only ever touched from this file.
    fileprivate var currentSuperTileRow: [Int32] = Array(repeating: 0, count: Int(MAX_PLAYERS))
    fileprivate var currentSuperTileCol: [Int32] = Array(repeating: 0, count: Int(MAX_PLAYERS))
    fileprivate var previousSuperTileCol: [Int32] = Array(repeating: 0, count: Int(MAX_PLAYERS))
    fileprivate var previousSuperTileRow: [Int32] = Array(repeating: 0, count: Int(MAX_PLAYERS))
}

func GetSuperTileTextureObjectSlot(_ i: Int32) -> UnsafeMutablePointer<UnsafeMutablePointer<MOMaterialObject>?>! {
    gEngine.terrain.superTileTextureObjectsBuf + Int(i)
}

func GetSuperTileMemoryEntry(_ i: Int32) -> UnsafeMutablePointer<SuperTileMemoryType>! {
    gEngine.terrain.superTileMemoryListBuf + Int(i)
}

func GetLineMarkerPtr(_ i: Int32) -> UnsafeMutablePointer<LineMarkerDefType> {
    gEngine.terrain.lineMarkerListBuf + Int(i)
}

// IsStereo is a parameterized C macro, which Swift can't import as a callable symbol.
private func isStereo() -> Bool { gGamePrefs.stereoGlassesMode != UInt8(StereoGlassesMode.off.rawValue) }

// MARK: - Init terrain manager

// Only called at boot!
func InitTerrainManager() {
    SetTerrainScale(Int32(DEFAULT_TERRAIN_SCALE)) // set scale to some default for now

    // BUILT TRIANGLE SPLITTING TABLES

    for y in 0..<Int(SUPERTILE_SIZE) {
        for x in 0..<Int(SUPERTILE_SIZE) {
            gEngine.terrain.tileTriangles1_A[y][x][0] = UInt8((Int(SUPERTILE_SIZE) + 1) * y + x + 1)
            gEngine.terrain.tileTriangles1_A[y][x][1] = UInt8((Int(SUPERTILE_SIZE) + 1) * y + x)
            gEngine.terrain.tileTriangles1_A[y][x][2] = UInt8((Int(SUPERTILE_SIZE) + 1) * (y + 1) + x)

            gEngine.terrain.tileTriangles2_A[y][x][0] = UInt8((Int(SUPERTILE_SIZE) + 1) * (y + 1) + x + 1)
            gEngine.terrain.tileTriangles2_A[y][x][1] = UInt8((Int(SUPERTILE_SIZE) + 1) * y + x + 1)
            gEngine.terrain.tileTriangles2_A[y][x][2] = UInt8((Int(SUPERTILE_SIZE) + 1) * (y + 1) + x)

            gEngine.terrain.tileTriangles1_B[y][x][0] = UInt8((Int(SUPERTILE_SIZE) + 1) * (y + 1) + x)
            gEngine.terrain.tileTriangles1_B[y][x][1] = UInt8((Int(SUPERTILE_SIZE) + 1) * (y + 1) + x + 1)
            gEngine.terrain.tileTriangles1_B[y][x][2] = UInt8((Int(SUPERTILE_SIZE) + 1) * y + x)

            gEngine.terrain.tileTriangles2_B[y][x][0] = UInt8((Int(SUPERTILE_SIZE) + 1) * (y + 1) + x + 1)
            gEngine.terrain.tileTriangles2_B[y][x][1] = UInt8((Int(SUPERTILE_SIZE) + 1) * y + x + 1)
            gEngine.terrain.tileTriangles2_B[y][x][2] = UInt8((Int(SUPERTILE_SIZE) + 1) * y + x)
        }
    }
}

// MARK: - Set terrain scale

func SetTerrainScale(_ polygonSize: Int32) {
    gEngine.terrain.polygonSize = Float(polygonSize) // size in world units of terrain polygon
    gEngine.terrain.polygonSizeInt = UInt32(polygonSize)

    gEngine.terrain.polygonSizeFrac = 1.0 / gEngine.terrain.polygonSize

    gEngine.terrain.superTileUnitSize = Float(SUPERTILE_SIZE) * gEngine.terrain.polygonSize // world unit size of a supertile
    gEngine.terrain.superTileUnitSizeFrac = 1.0 / gEngine.terrain.superTileUnitSize

    gEngine.terrain.mapToUnitValue = gEngine.terrain.polygonSize / Float(OREOMAP_TILE_SIZE) // value to xlate Oreo map pixel coords to 3-space unit coords
    gEngine.terrain.mapToUnitValueFrac = 1.0 / gEngine.terrain.mapToUnitValue

    if gGamePrefs.isLowRenderQuality {
        gEngine.terrain.superTileActiveRange = 7
    } else {
        gEngine.terrain.superTileActiveRange = Int32(MAX_SUPERTILE_ACTIVE_RANGE)
    }
}

// MARK: - Init current scroll settings

func InitCurrentScrollSettings() {
    for i in 0..<Int(gEngine.player.numPlayers) { // init settings for each player in game
        let pi = GetPlayerInfoEntry(Int32(i))
        let x = Int(pi.pointee.coord.x - (Float(gEngine.terrain.superTileActiveRange) * gEngine.terrain.superTileUnitSize))
        let y = Int(pi.pointee.coord.z - (Float(gEngine.terrain.superTileActiveRange) * gEngine.terrain.superTileUnitSize))

        var dummy1: Int32 = 0
        var dummy2: Int32 = 0
        GetSuperTileInfo(x, y, &gEngine.terrain.currentSuperTileCol[i], &gEngine.terrain.currentSuperTileRow[i], &dummy1, &dummy2)

        gEngine.terrain.previousSuperTileCol[i] = -100000
        gEngine.terrain.previousSuperTileRow[i] = -100000
    }

    // CREATE DUMMY CUSTOM OBJECT TO CAUSE TERRAIN DRAWING AT THE DESIRED TIME

    var def = NewObjectDefinitionType()
    def.genre = UInt8(CUSTOM_GENRE)
    def.slot = Int16(TERRAIN_SLOT)
    def.moveCall = nil
    def.drawCall = DrawTerrain
    def.flags = UInt32(STATUS_BIT_DONTCULL | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOTEXTUREWRAP)
    def.scale = 1

    let obj = MakeNewObject(&def)!
    obj.pointee.VertexArrayMode = UInt8(VertexArrayRangeType.terrain.rawValue)
}


// MARK: - Init supertile grid

func InitSuperTileGrid() {
    gEngine.terrain.superTileStatusGrid = alloc2DArray(SuperTileStatus.self, rows: Int(gEngine.terrain.numSuperTilesDeep), cols: Int(gEngine.terrain.numSuperTilesWide)) // alloc 2D grid array

    // INIT ALL GRID SLOTS TO EMPTY AND UNUSED

    for r in 0..<Int(gEngine.terrain.numSuperTilesDeep) {
        for c in 0..<Int(gEngine.terrain.numSuperTilesWide) {
            gEngine.terrain.superTileStatusGrid[r]![c].supertileIndex = 0
            gEngine.terrain.superTileStatusGrid[r]![c].statusFlags = 0
            gEngine.terrain.superTileStatusGrid[r]![c].playerHereFlags = 0
        }
    }
}

// MARK: - Dispose terrain

// Deletes any existing terrain data
func DisposeTerrain() {
    DisposeSuperTileMemoryList()

    // FREE ALL TEXTURE OBJECTS

    for i in 0..<Int(gEngine.terrain.numUniqueSuperTiles) {
        MO_DisposeObjectReference(UnsafeMutableRawPointer(GetSuperTileTextureObjectSlot(Int32(i))!.pointee))
        GetSuperTileTextureObjectSlot(Int32(i))!.pointee = nil
    }
    gEngine.terrain.numUniqueSuperTiles = 0

    if gEngine.terrain.superTileItemIndexGrid != nil {
        free2DArray(gEngine.terrain.superTileItemIndexGrid)
        gEngine.terrain.superTileItemIndexGrid = nil
    }

    if gEngine.terrain.superTileTextureGrid != nil {
        free2DArray(gEngine.terrain.superTileTextureGrid)
        gEngine.terrain.superTileTextureGrid = nil
    }

    if gEngine.terrain.superTileStatusGrid != nil {
        free2DArray(gEngine.terrain.superTileStatusGrid)
        gEngine.terrain.superTileStatusGrid = nil
    }

    if gEngine.terrain.vertexShading != nil {
        free2DArray(gEngine.terrain.vertexShading)
        gEngine.terrain.vertexShading = nil
    }

    if gEngine.terrain.masterItemList != nil {
        SafeDisposePtr(gEngine.terrain.masterItemList)
        gEngine.terrain.masterItemList = nil
    }

    if gEngine.terrain.mapYCoords != nil {
        free2DArray(gEngine.terrain.mapYCoords)
        gEngine.terrain.mapYCoords = nil
    }

    if gEngine.terrain.mapYCoordsOriginal != nil {
        free2DArray(gEngine.terrain.mapYCoordsOriginal)
        gEngine.terrain.mapYCoordsOriginal = nil
    }

    if gEngine.terrain.mapSplitMode != nil {
        free2DArray(gEngine.terrain.mapSplitMode)
        gEngine.terrain.mapSplitMode = nil
    }

    // NUKE SPLINE DATA

    if let splineList = gEngine.splines.splineList {
        for i in 0..<Int(gEngine.splines.numSplines) {
            SafeDisposePtr(splineList[i].pointList) // nuke point list
            SafeDisposePtr(splineList[i].itemList) // nuke item list
        }
        SafeDisposePtr(splineList)
        gEngine.splines.splineList = nil
    }

    // NUKE WATER PATCH

    if gEngine.water.listHandle != nil {
        DisposeWaterListHandle(gEngine.water.listHandle)
        gEngine.water.listHandle = nil
    }

    gEngine.water.list = nil
    gEngine.water.numPatches = 0
    gEngine.terrain.numSuperTilesDeep = 0
    gEngine.terrain.numSuperTilesWide = 0

    releaseAllSuperTiles()

    DisposeFences()
}

// MARK: -

// MARK: - Create supertile memory list

// Preallocates memory and initializes the data for the maximum number of supertiles that
// we will ever need on this level.
func CreateSuperTileMemoryList() {
    // ALLOCATE ARRAYS FOR ALL THE DATA WE WILL NEED

    gEngine.terrain.numFreeSupertiles = Int16(maxSupertiles)

    // ALLOC BASE TRIMESH DATA FOR ALL SUPERTILES

    guard let meshData = AllocPtrClear(MemoryLayout<MOVertexArrayData>.size * maxSupertiles)?.assumingMemoryBound(to: MOVertexArrayData.self) else {
        SwFatal("CreateSuperTileMemoryList: AllocPtr failed - gEngine.terrain.superTileMeshData")
        return
    }
    gEngine.terrain.superTileMeshData = meshData

    // ALLOC TRIANGLE ARRAYS ALL SUPERTILES

    let triangles = OGL_AllocVertexArrayMemory(Int(MemoryLayout<MOTriangleIndecies>.size * numTrisInSupertile * maxSupertiles), UInt8(VertexArrayRangeType.terrain.rawValue))!.assumingMemoryBound(to: MOTriangleIndecies.self)
    gEngine.terrain.superTileTriangles = triangles

    // ALLOC POINTS FOR ALL SUPERTILES

    let coords = OGL_AllocVertexArrayMemory(Int(MemoryLayout<OGLPoint3D>.size * (numVerticesInSupertile * maxSupertiles)), UInt8(VertexArrayRangeType.terrain.rawValue))!.assumingMemoryBound(to: OGLPoint3D.self)
    gEngine.terrain.superTileCoords = coords

    // ALLOC VERTEX NORMALS FOR ALL SUPERTILES

    let normals = OGL_AllocVertexArrayMemory(Int(MemoryLayout<OGLVector3D>.size * (numVerticesInSupertile * maxSupertiles)), UInt8(VertexArrayRangeType.terrain.rawValue))!.assumingMemoryBound(to: OGLVector3D.self)
    gEngine.terrain.superTileNormals = normals

    // ALLOC UVS FOR ALL SUPERTILES

    let uvs = OGL_AllocVertexArrayMemory(Int(MemoryLayout<OGLTextureCoord>.size * numVerticesInSupertile * maxSupertiles), UInt8(VertexArrayRangeType.terrain.rawValue))!.assumingMemoryBound(to: OGLTextureCoord.self)
    gEngine.terrain.superTileUVs = uvs

    // ALLOC VERTEX COLORS FOR ALL SUPERTILES

    let colors = OGL_AllocVertexArrayMemory(Int(MemoryLayout<OGLColorRGBA>.size * numVerticesInSupertile * maxSupertiles), UInt8(VertexArrayRangeType.terrain.rawValue))!.assumingMemoryBound(to: OGLColorRGBA.self)
    gEngine.terrain.superTileColors = colors

    // FOR EACH POSSIBLE SUPERTILE SET INFO

    // These normalized UVs must track the assembled supertile texture's
    // actual layout (File.swift's kSuperTile* constants): the content
    // occupies kSuperTileTexSize texels inset by kSuperTileBorder inside a
    // kSuperTileCanvasSize-wide texture. Desktop: 256 content, 1px border,
    // 258 canvas (scale 256/258, translate 1/258 - unchanged). 3DS: 128
    // content, 0 border, 128 canvas (scale 1.0, translate 0 - samples the
    // whole POT texture, since the seam border is dropped there so the
    // texture stays power-of-two; see File.swift's constants comment).
    let seamlessTexmapSize: Float = Float(kSuperTileCanvasSize)
    let seamlessUVScale: Float = Float(kSuperTileTexSize) / seamlessTexmapSize
    let seamlessUVTranslate: Float = Float(kSuperTileBorder) / seamlessTexmapSize

    for i in 0..<maxSupertiles {
        let superTile = GetSuperTileMemoryEntry(Int32(i))!
        superTile.pointee.mode = UInt8(SUPERTILE_MODE_FREE) // it's free for use

        // POINT TO ARRAYS

        let j = i * numVerticesInSupertile // index * supertile needs

        let meshPtr = meshData + i
        let coordPtr = coords + j
        let normalPtr = normals + j
        let uvPtr = uvs + j
        let colorPtr = colors + j
        let triPtr = triangles + i * numTrisInSupertile

        superTile.pointee.meshData = meshPtr

        // SET MESH STRUCTURE

        meshPtr.pointee.VARtype = Int16(VertexArrayRangeType.terrain.rawValue)
        meshPtr.pointee.numMaterials = -1 // textures will be manually submitted in drawing function!
        meshPtr.pointee.numPoints = Int32(numVerticesInSupertile)
        meshPtr.pointee.numTriangles = Int32(numTrisInSupertile)

        meshPtr.pointee.points = coordPtr
        meshPtr.pointee.normals = normalPtr
        meshPtr.pointee.uvs.0 = uvPtr
        meshPtr.pointee.colorsFloat = colorPtr
        meshPtr.pointee.triangles = triPtr

        // SET UV & COLOR VALUES

        var jj = 0
        for v in 0...Int(SUPERTILE_SIZE) {
            for u in 0...Int(SUPERTILE_SIZE) {
                var uu = Float(u) / Float(SUPERTILE_SIZE) // sets uv's 0.0 -> 1.0 for single texture map
                var vv = Float(v) / Float(SUPERTILE_SIZE)

                // HQ_TERRAIN (hardcoded on): seamless terrain texturing
                uu = (uu * seamlessUVScale) + seamlessUVTranslate
                vv = (vv * seamlessUVScale) + seamlessUVTranslate

                uvPtr[jj].u = uu
                uvPtr[jj].v = vv

                jj += 1
            }
        }
    }
}

// MARK: - Dispose supertile memory list

func DisposeSuperTileMemoryList() {
    // NUKE ALL MASTER ARRAYS WHICH WILL FREE UP ALL SUPERTILE MEMORY

    if let meshData = gEngine.terrain.superTileMeshData {
        SafeDisposePtr(meshData)
    }
    gEngine.terrain.superTileMeshData = nil

    if let triangles = gEngine.terrain.superTileTriangles {
        OGL_FreeVertexArrayMemory(triangles, UInt8(VertexArrayRangeType.terrain.rawValue))
        gEngine.terrain.superTileTriangles = nil
    }

    if let coords = gEngine.terrain.superTileCoords {
        OGL_FreeVertexArrayMemory(coords, UInt8(VertexArrayRangeType.terrain.rawValue))
    }
    gEngine.terrain.superTileCoords = nil

    if let normals = gEngine.terrain.superTileNormals {
        OGL_FreeVertexArrayMemory(normals, UInt8(VertexArrayRangeType.terrain.rawValue))
    }
    gEngine.terrain.superTileNormals = nil

    if let uvs = gEngine.terrain.superTileUVs {
        OGL_FreeVertexArrayMemory(uvs, UInt8(VertexArrayRangeType.terrain.rawValue))
    }
    gEngine.terrain.superTileUVs = nil

    if let colors = gEngine.terrain.superTileColors {
        OGL_FreeVertexArrayMemory(colors, UInt8(VertexArrayRangeType.terrain.rawValue))
    }
    gEngine.terrain.superTileColors = nil
}

// MARK: - Get free supertile memory

// Finds one of the preallocated supertile memory blocks and returns its index
// IT ALSO MARKS THE BLOCK AS USED
//
// OUTPUT: index into gSuperTileMemoryList
private func getFreeSuperTileMemory() -> Int16 {
    // SCAN FOR A FREE BLOCK

    for i in 0..<maxSupertiles {
        let superTile = GetSuperTileMemoryEntry(Int32(i))!
        if superTile.pointee.mode == UInt8(SUPERTILE_MODE_FREE) {
            superTile.pointee.mode = UInt8(SUPERTILE_MODE_USED)
            gEngine.terrain.numFreeSupertiles -= 1
            return Int16(i)
        }
    }

    SwFatal("No Free Supertiles!")
    return -1 // ERROR, NO FREE BLOCKS!!!! SHOULD NEVER GET HERE!
}

// MARK: -

// MARK: - Build terrain supertile

// Builds a new supertile which has scrolled on
//
// INPUT: startCol = starting tile column in map
//		  startRow = starting tile row in map
//
// OUTPUT: index to supertile
private func buildTerrainSuperTile(_ startCol: Int, _ startRow: Int) -> UInt16 {
    // SEE IF WE CAN MODIFY THE TERRAIN DATA
    //
    // If we're using Vertex Array Range then we need to be careful that we don't modify any data that's
    // in the vertex array memory until the GPU is done with it.
    //
    // (VERTEXARRAYRANGES is hardcoded off, so the fence-wait here is dead code and dropped.)

    let superTileNum = getFreeSuperTileMemory() // get memory block for the data
    let superTilePtr = GetSuperTileMemoryEntry(Int32(superTileNum))! // get ptr to it

    // SET COORDINATE DATA

    superTilePtr.pointee.x = (Float(startCol) * gEngine.terrain.polygonSize) + (gEngine.terrain.superTileUnitSize * 0.5) // also remember world coords (center of supertile)
    superTilePtr.pointee.z = (Float(startRow) * gEngine.terrain.polygonSize) + (gEngine.terrain.superTileUnitSize * 0.5)

    superTilePtr.pointee.left = Int(Float(startCol) * gEngine.terrain.polygonSize) // also save left/back coord
    superTilePtr.pointee.back = Int(Float(startRow) * gEngine.terrain.polygonSize)

    superTilePtr.pointee.tileRow = startRow // save tile row/col
    superTilePtr.pointee.tileCol = startCol

    // GET THE TRIMESH

    let meshData = superTilePtr.pointee.meshData! // get ptr to mesh data
    let triangleList = meshData.pointee.triangles! // get ptr to triangle index list
    let vertexPointList = meshData.pointee.points! // get ptr to points list
    let vertexColorList = meshData.pointee.colorsFloat // get ptr to vertex color
    let vertexNormals = meshData.pointee.normals! // get ptr to vertex normals

    var miny: Float = 10_000_000 // init bbox counters
    var maxy: Float = -miny

    // CREATE VERTEX GRID

    for row2 in 0...Int(SUPERTILE_SIZE) {
        let row = row2 + Int(startRow)

        for col2 in 0...Int(SUPERTILE_SIZE) {
            let col = col2 + Int(startCol)

            var height: Float
            if (row >= Int(gEngine.terrain.tileDepth)) || (col >= Int(gEngine.terrain.tileWidth)) { // check for edge vertices (off map array)
                height = 0
            } else {
                height = gEngine.terrain.mapYCoords[row]![col] // get pixel height here
            }

            // SET COORD

            gEngine.terrain.workGrid[row2][col2].point.x = Float(col) * gEngine.terrain.polygonSize
            gEngine.terrain.workGrid[row2][col2].point.z = Float(row) * gEngine.terrain.polygonSize
            gEngine.terrain.workGrid[row2][col2].point.y = height // save height @ this tile's upper left corner

            // SET UV

            gEngine.terrain.workGrid[row2][col2].uv.u = Float(col2) * (0.99 / Float(SUPERTILE_SIZE)) // sets uv's 0.0 -> .99 for single texture map
            gEngine.terrain.workGrid[row2][col2].uv.v = 0.99 - (Float(row2) * (0.99 / Float(SUPERTILE_SIZE)))

            // SET COLOR

            gEngine.terrain.workGrid[row2][col2].color.r = 1.0
            gEngine.terrain.workGrid[row2][col2].color.g = 1.0
            gEngine.terrain.workGrid[row2][col2].color.b = 1.0
            gEngine.terrain.workGrid[row2][col2].color.a = 1.0

            if height > maxy { // keep track of min/max
                maxy = height
            }
            if height < miny {
                miny = height
            }
        }
    }

    // CREATE TERRAIN MESH POLYGONS

    // SET VERTEX COORDS

    var numPoints = 0
    for row in 0..<(Int(SUPERTILE_SIZE) + 1) {
        for col in 0..<(Int(SUPERTILE_SIZE) + 1) {
            vertexPointList[numPoints] = gEngine.terrain.workGrid[row][col].point // copy from work grid
            numPoints += 1
        }
    }

    // UPDATE TRIMESH DATA WITH NEW INFO

    var i = 0
    for row2 in 0..<Int(SUPERTILE_SIZE) {
        let row = row2 + Int(startRow)

        for col2 in 0..<Int(SUPERTILE_SIZE) {
            let col = col2 + Int(startCol)

            // SET SPLITTING INFO

            if gEngine.terrain.mapSplitMode[row]![col] == UInt8(SPLIT_BACKWARD) { // set coords & uv's based on splitting
                // \
                triangleList[i].vertexIndices.0 = UInt32(gEngine.terrain.tileTriangles1_B[row2][col2][0])
                triangleList[i].vertexIndices.1 = UInt32(gEngine.terrain.tileTriangles1_B[row2][col2][1])
                triangleList[i].vertexIndices.2 = UInt32(gEngine.terrain.tileTriangles1_B[row2][col2][2])
                i += 1
                triangleList[i].vertexIndices.0 = UInt32(gEngine.terrain.tileTriangles2_B[row2][col2][0])
                triangleList[i].vertexIndices.1 = UInt32(gEngine.terrain.tileTriangles2_B[row2][col2][1])
                triangleList[i].vertexIndices.2 = UInt32(gEngine.terrain.tileTriangles2_B[row2][col2][2])
                i += 1
            } else {
                // /
                triangleList[i].vertexIndices.0 = UInt32(gEngine.terrain.tileTriangles1_A[row2][col2][0])
                triangleList[i].vertexIndices.1 = UInt32(gEngine.terrain.tileTriangles1_A[row2][col2][1])
                triangleList[i].vertexIndices.2 = UInt32(gEngine.terrain.tileTriangles1_A[row2][col2][2])
                i += 1
                triangleList[i].vertexIndices.0 = UInt32(gEngine.terrain.tileTriangles2_A[row2][col2][0])
                triangleList[i].vertexIndices.1 = UInt32(gEngine.terrain.tileTriangles2_A[row2][col2][1])
                triangleList[i].vertexIndices.2 = UInt32(gEngine.terrain.tileTriangles2_A[row2][col2][2])
                i += 1
            }
        }
    }

    // CALCULATE VERTEX NORMALS

    CalculateSupertileVertexNormals(meshData, startRow, startCol)

    // CALCULATE VERTEX COLORS

    if let vertexColorList {
        // GET LIGHT DATA

        let ambientR = gEngine.game.viewInfoPtr!.pointee.lightList.ambientColor.r // get ambient color
        let ambientG = gEngine.game.viewInfoPtr!.pointee.lightList.ambientColor.g
        let ambientB = gEngine.game.viewInfoPtr!.pointee.lightList.ambientColor.b

        let fillR0 = gEngine.game.viewInfoPtr!.pointee.lightList.fillColor.0.r // get fill color
        let fillG0 = gEngine.game.viewInfoPtr!.pointee.lightList.fillColor.0.g
        let fillB0 = gEngine.game.viewInfoPtr!.pointee.lightList.fillColor.0.b
        var fillDir0 = gEngine.game.viewInfoPtr!.pointee.lightList.fillDirection.0 // get fill direction
        fillDir0.x = -fillDir0.x
        fillDir0.y = -fillDir0.y
        fillDir0.z = -fillDir0.z

        var fillR1: Float = 0, fillG1: Float = 0, fillB1: Float = 0
        var fillDir1 = OGLVector3D()

        let numFillLights = gEngine.game.viewInfoPtr!.pointee.lightList.numFillLights
        if numFillLights > 1 {
            fillR1 = gEngine.game.viewInfoPtr!.pointee.lightList.fillColor.1.r
            fillG1 = gEngine.game.viewInfoPtr!.pointee.lightList.fillColor.1.g
            fillB1 = gEngine.game.viewInfoPtr!.pointee.lightList.fillColor.1.b
            fillDir1 = gEngine.game.viewInfoPtr!.pointee.lightList.fillDirection.1
            fillDir1.x = -fillDir1.x
            fillDir1.y = -fillDir1.y
            fillDir1.z = -fillDir1.z
        }

        i = 0
        for row in 0...Int(SUPERTILE_SIZE) {
            for col in 0...Int(SUPERTILE_SIZE) {
                let shade = gEngine.terrain.vertexShading[row + Int(startRow)]![col + Int(startCol)] // get value from shading grid

                // APPLY LIGHTING TO THE VERTEX

                var r = ambientR // factor in the ambient
                var g = ambientG
                var b = ambientB

                var dot = vertexNormals[i].dot(fillDir0)
                if dot > 0.0 {
                    r += fillR0 * dot
                    g += fillG0 * dot
                    b += fillB0 * dot
                }

                if numFillLights > 1 {
                    dot = vertexNormals[i].dot(fillDir1)
                    if dot > 0.0 {
                        r += fillR1 * dot
                        g += fillG1 * dot
                        b += fillB1 * dot
                    }
                }

                if r > 1.0 { r = 1.0 }
                if g > 1.0 { g = 1.0 }
                if b > 1.0 { b = 1.0 }

                // SAVE COLOR INTO LIST

                vertexColorList[i].r = r * shade // apply shade
                vertexColorList[i].g = g * shade
                vertexColorList[i].b = b * shade
                vertexColorList[i].a = 1.0
                i += 1
            }
        }
    }

    // CALC COORD & BBOX
    //
    // This y coord is not used to translate since the terrain has no translation matrix
    // instead, this is used by the culling routine for culling tests

    superTilePtr.pointee.y = (miny + maxy) * 0.5 // calc center y coord as average of top & bottom

    superTilePtr.pointee.bBox.min.x = gEngine.terrain.workGrid[0][0].point.x
    superTilePtr.pointee.bBox.max.x = gEngine.terrain.workGrid[0][0].point.x + gEngine.terrain.superTileUnitSize
    superTilePtr.pointee.bBox.min.y = miny
    superTilePtr.pointee.bBox.max.y = maxy
    superTilePtr.pointee.bBox.min.z = gEngine.terrain.workGrid[0][0].point.z
    superTilePtr.pointee.bBox.max.z = gEngine.terrain.workGrid[0][0].point.z + gEngine.terrain.superTileUnitSize

    if gEngine.terrain.disableHiccupTimer != 0 {
        superTilePtr.pointee.hiccupTimer = 0
    } else {
        superTilePtr.pointee.hiccupTimer = gEngine.terrain.hiccupTimer
        gEngine.terrain.hiccupTimer += 1
        gEngine.terrain.hiccupTimer &= 0x1 // spread over 2 frames
    }

    // WE'VE MODIFIED DATA IN THE VERTEX ARRAY RANGE, SO FORCE AN UPDATE

    OGL_SetVertexArrayRangeDirty(Int16(VertexArrayRangeType.terrain.rawValue))

    return superTileNum >= 0 ? UInt16(superTileNum) : 0
}

// MARK: - Calculate supertile vertex normals

func CalculateSupertileVertexNormals(_ meshData: UnsafeMutablePointer<MOVertexArrayData>!, _ startRow: Int, _ startCol: Int) {
    let vertexPointList = meshData.pointee.points! // get ptr to points list
    let vertexNormals = meshData.pointee.normals! // get ptr to vertex normals
    let triangleList = meshData.pointee.triangles! // get ptr to triangle index list

    var faceNormal = [OGLVector3D](repeating: OGLVector3D(), count: numTrisInSupertile)

    // CALC FACE NORMALS

    for i in 0..<numTrisInSupertile {
        CalcFaceNormal_NotNormalized(&vertexPointList[Int(triangleList[i].vertexIndices.0)],
                                      &vertexPointList[Int(triangleList[i].vertexIndices.1)],
                                      &vertexPointList[Int(triangleList[i].vertexIndices.2)],
                                      &faceNormal[i])
    }

    // CALCULATE VERTEX NORMALS

    var i = 0
    for row in 0...Int(SUPERTILE_SIZE) {
        for col in 0...Int(SUPERTILE_SIZE) {
            // SCAN 4 TILES AROUND THIS TILE TO CALC AVERAGE NORMAL FOR THIS VERTEX
            //
            // We use the face normal already calculated for triangles inside the supertile,
            // but for tiles/tris outside the supertile (on the borders), we need to calculate
            // the face normals there.

            var avX: Float = 0, avY: Float = 0, avZ: Float = 0 // init the normal

            for ro in -1...0 {
                for co in -1...0 {
                    let cc = col + co
                    let rr = row + ro

                    if (cc >= 0) && (cc < Int(SUPERTILE_SIZE)) && (rr >= 0) && (rr < Int(SUPERTILE_SIZE)) { // see if this vertex is in supertile bounds
                        let n1Index = rr * (Int(SUPERTILE_SIZE) * 2) + (cc * 2) // average 2 triangles...
                        let n1 = faceNormal[n1Index]
                        let n2 = faceNormal[n1Index + 1]
                        avX += n1.x + n2.x // ...and average with current average
                        avY += n1.y + n2.y
                        avZ += n1.z + n2.z
                    } else { // tile is out of supertile, so calc face normal & average
                        var nA = OGLVector3D()
                        var nB = OGLVector3D()
                        CalcTileNormals_NotNormalized(startRow + rr, startCol + cc, &nA, &nB) // calculate the 2 face normals for this tile
                        avX += nA.x + nB.x // average with current average
                        avY += nA.y + nB.y
                        avZ += nA.z + nB.z
                    }
                }
            }

            FastNormalizeVector(avX, avY, avZ, &vertexNormals[i]) // normalize the vertex normal
            i += 1
        }
    }
}

// MARK: - Release supertile object

// Deactivates the terrain object
private func releaseSuperTileObject(_ superTileNum: Int16) {
    // (VERTEXARRAYRANGES is hardcoded off, so the fence-wait here is dead code and dropped.)

    GetSuperTileMemoryEntry(Int32(superTileNum))!.pointee.mode = UInt8(SUPERTILE_MODE_FREE) // it's free!
    gEngine.terrain.numFreeSupertiles += 1
}

// MARK: - Release all supertiles

private func releaseAllSuperTiles() {
    for i in 0..<maxSupertiles {
        releaseSuperTileObject(Int16(i))
    }

    gEngine.terrain.numFreeSupertiles = Int16(maxSupertiles)
}

// MARK: -

// MARK: - Draw terrain

// This is the main call to update the screen.  It draws all ObjNode's and the terrain itself
func DrawTerrain(_ theNode: UnsafeMutablePointer<ObjNode>?) {
    // DRAW STUFF

    // SET A NICE STATE FOR TERRAIN DRAWING

    OGL_PushState()

    OGL_SetNormalizeNormals(false) // turn off vector normalization since scale == 1
    OGL_DisableBlend() // no blending for terrain - its always opaque
    gEngine.renderer.setAlphaTestEnabled(false)

    gEngine.terrain.numSuperTilesDrawn = 0

    // SCAN THE SUPERTILE GRID AND LOOK FOR USED & VISIBLE SUPERTILES

    for r in 0..<Int(gEngine.terrain.numSuperTilesDeep) {
        for c in 0..<Int(gEngine.terrain.numSuperTilesWide) {
            if gEngine.terrain.superTileStatusGrid[r]![c].statusFlags & UInt8(SUPERTILE_IS_USED_THIS_FRAME) != 0 { // see if used
                let i = Int(gEngine.terrain.superTileStatusGrid[r]![c].supertileIndex) // extract supertile #

                // SEE WHICH UNIQUE SUPERTILE TEXTURE TO USE

                let unique = Int(gEngine.terrain.superTileTextureGrid[r]![c])
                if unique == -1 { // if -1 then its a blank
                    continue
                }

                // SEE IF DELAY HICCUP TIMER

                let superTile = GetSuperTileMemoryEntry(Int32(i))!
                if superTile.pointee.hiccupTimer != 0 {
                    superTile.pointee.hiccupTimer -= 1
                    continue
                }

                // SEE IF IS CULLED

                let superTileVisible = OGL_IsBBoxVisible(&superTile.pointee.bBox, nil) != 0
                if !superTileVisible {
                    continue
                }

                // DRAW THE MESH IN THIS SUPERTILE

                // SUBMIT THE TEXTURE

                MO_DrawMaterial(GetSuperTileTextureObjectSlot(Int32(unique))!.pointee)

                // SUBMIT THE GEOMETRY

                MO_DrawGeometry_VertexArray(superTile.pointee.meshData)
                gEngine.terrain.numSuperTilesDrawn += 1
            }
        }
    }

    OGL_PopState()
    gEngine.renderer.setAlphaTestEnabled(true)

    // PREPARE SUPERTILE GRID FOR THE NEXT FRAME

    var doPrepGrid = true
    if gEngine.view.activeSplitScreenMode != UInt8(SplitscreenMode.none.rawValue) { // if splitscreen, then dont do this until done with player #2
        if gEngine.view.currentSplitScreenPane < 1 {
            doPrepGrid = false
        }
    }

    if doPrepGrid {
        for r in 0..<Int(gEngine.terrain.numSuperTilesDeep) {
            for c in 0..<Int(gEngine.terrain.numSuperTilesWide) {
                // IF THIS SUPERTILE WAS NOT USED BUT IS DEFINED, THEN FREE IT

                if gEngine.terrain.superTileStatusGrid[r]![c].statusFlags & UInt8(SUPERTILE_IS_DEFINED) != 0 { // is it defined?
                    if gEngine.terrain.superTileStatusGrid[r]![c].statusFlags & UInt8(SUPERTILE_IS_USED_THIS_FRAME) == 0 { // was it used?  If not, then release the supertile definition
                        releaseSuperTileObject(Int16(gEngine.terrain.superTileStatusGrid[r]![c].supertileIndex))
                        gEngine.terrain.superTileStatusGrid[r]![c].statusFlags = 0 // no longer defined
                    }
                }

                // ASSUME SUPERTILES WILL BE UNUSED ON NEXT FRAME

                if !isStereo() || (gEngine.view.anaglyphPass > 0) {
                    gEngine.terrain.superTileStatusGrid[r]![c].statusFlags &= ~UInt8(SUPERTILE_IS_USED_THIS_FRAME) // clear the isUsed bit
                }
            }
        }
    }

    // (VERTEXARRAYRANGES is hardcoded off, so the "insert OpenGL fence" block here is dead code and dropped.)

    // DRAW SPLINES IN DEBUG MODE

    if gEngine.game.debugMode == 2 {
        gEngine.renderer.setColor4f(0.5, 1.0, 0.75, 1)

        for splineNum in 0..<Int(gEngine.splines.numSplines) {
            gEngine.renderer.beginImmediate(.lineStrip)

            let spline = gEngine.splines.splineList[splineNum]
            for nubNum in 0..<Int(spline.numPoints) {
                let x = spline.pointList![nubNum].x
                let z = spline.pointList![nubNum].z
                let y = GetTerrainY(x, z) + 10

                gEngine.renderer.vertex3f(x, y, z)
            }

            gEngine.renderer.endImmediate()
        }

        gEngine.renderer.setColor4f(1.0, 0.5, 0.2, 1)
        for customSplineNum in 0..<Int(MAX_CUSTOM_SPLINES) {
            let customSpline = GetCustomSplineSlot(Int32(customSplineNum))
            if !customSpline.isUsed {
                continue
            }

            gEngine.renderer.beginImmediate(.lineStrip)
            for nubNum in 0..<Int(customSpline.pointee.numPoints) {
                let x = customSpline.pointee.splinePoints![nubNum].x
                let y = customSpline.pointee.splinePoints![nubNum].y
                let z = customSpline.pointee.splinePoints![nubNum].z
                gEngine.renderer.vertex3f(x, y, z)
            }
            gEngine.renderer.endImmediate()
        }
    }
}

// MARK: -

// MARK: - Get terrain height at coord

// Given a world x/z coord, return the y coord based on height map
//
// INPUT: x/z = world coords
//
// OUTPUT: y = world y coord
func GetTerrainY(_ x: Float, _ z: Float) -> Float {
    if gEngine.terrain.mapYCoords == nil { // make sure there's a terrain
        return ILLEGAL_TERRAIN_Y
    }

    // CALC TILE ROW/COL INFO

    let col = Int16(x * gEngine.terrain.polygonSizeFrac) // see which tile row/col we're on
    let row = Int16(z * gEngine.terrain.polygonSizeFrac)

    if (col < 0) || (col >= Int16(gEngine.terrain.tileWidth)) { // check bounds
        return 0
    }
    if (row < 0) || (row >= Int16(gEngine.terrain.tileDepth)) {
        return 0
    }

    let xi = x - (Float(col) * Float(gEngine.terrain.polygonSizeInt)) // calc x/z offset into the tile
    let zi = z - (Float(row) * Float(gEngine.terrain.polygonSizeInt))

    // BUILD VERTICES FOR THE 4 CORNERS OF THE TILE

    var p = [OGLPoint3D](repeating: OGLPoint3D(), count: 4)

    p[0].x = Float(col) * Float(gEngine.terrain.polygonSizeInt) // far left
    p[0].y = gEngine.terrain.mapYCoords[Int(row)]![Int(col)]
    p[0].z = Float(row) * Float(gEngine.terrain.polygonSizeInt)

    p[1].x = p[0].x + gEngine.terrain.polygonSize // far right
    p[1].y = gEngine.terrain.mapYCoords[Int(row)]![Int(col) + 1]
    p[1].z = p[0].z

    p[2].x = p[1].x // near right
    p[2].y = gEngine.terrain.mapYCoords[Int(row) + 1]![Int(col) + 1]
    p[2].z = p[1].z + gEngine.terrain.polygonSize

    p[3].x = Float(col) * Float(gEngine.terrain.polygonSizeInt) // near left
    p[3].y = gEngine.terrain.mapYCoords[Int(row) + 1]![Int(col)]
    p[3].z = p[2].z

    // CALC PLANE EQUATION FOR TRIANGLE

    var planeEq = OGLPlaneEquation()
    var xiAdj = xi

    if gEngine.terrain.mapSplitMode[Int(row)]![Int(col)] == UInt8(SPLIT_BACKWARD) { // if \ split
        if xiAdj < zi { // which triangle are we on?
            CalcPlaneEquationOfTriangle(&planeEq, &p[0], &p[2], &p[3]) // calc plane equation for left triangle
        } else {
            CalcPlaneEquationOfTriangle(&planeEq, &p[0], &p[1], &p[2]) // calc plane equation for right triangle
        }
    } else { // otherwise, / split
        xiAdj = gEngine.terrain.polygonSize - xiAdj // flip x
        if xiAdj > zi {
            CalcPlaneEquationOfTriangle(&planeEq, &p[0], &p[1], &p[3]) // calc plane equation for left triangle
        } else {
            CalcPlaneEquationOfTriangle(&planeEq, &p[1], &p[2], &p[3]) // calc plane equation for right triangle
        }
    }

    gEngine.terrain.recentTerrainNormal = planeEq.normal // remember the normal here

    return (planeEq.constant - ((planeEq.normal.x * x) + (planeEq.normal.z * z))) / planeEq.normal.y // calc intersection (IntersectionOfYAndPlane)
}

// MARK: - Get min terrain Y

// Uses the models's bounding box to find the lowest y for all sides
func GetMinTerrainY(_ x: Float, _ z: Float, _ group: Int16, _ type: Int16, _ scale: Float) -> Float {
    // POINT TO BOUNDING BOX

    let bBox = GetObjectGroupBBox(Int32(group), Int32(type)) // get this model's bounding box

    let minX = x + bBox.min.x * scale
    let maxX = x + bBox.max.x * scale
    let minZ = z + bBox.min.z * scale
    let maxZ = z + bBox.max.z * scale

    // GET CENTER

    var minY = GetTerrainY(x, z)

    // CHECK FAR LEFT

    var y = GetTerrainY(minX, minZ)
    if y < minY { minY = y }

    // CHECK FAR RIGHT

    y = GetTerrainY(maxX, minZ)
    if y < minY { minY = y }

    // CHECK FRONT LEFT

    y = GetTerrainY(minX, maxZ)
    if y < minY { minY = y }

    // CHECK FRONT RIGHT

    y = GetTerrainY(maxX, maxZ)
    if y < minY { minY = y }

    return minY
}

// MARK: - Get supertile info

// Given a world x/z coord, return some supertile info
//
// INPUT: x/y = world x/y coords
// OUTPUT: row/col in tile coords and supertile coords
func GetSuperTileInfo(_ x: Int, _ z: Int, _ superCol: UnsafeMutablePointer<Int32>!, _ superRow: UnsafeMutablePointer<Int32>!, _ tileCol: UnsafeMutablePointer<Int32>!, _ tileRow: UnsafeMutablePointer<Int32>!) {
    if (x < 0) || (z < 0) { // see if out of bounds
        return
    }
    if (x >= gEngine.terrain.unitWidth) || (z >= gEngine.terrain.unitDepth) {
        return
    }

    let col = Int32(Float(x) * (1.0 / gEngine.terrain.superTileUnitSize)) // calc supertile relative row/col that the coord lies on
    let row = Int32(Float(z) * (1.0 / gEngine.terrain.superTileUnitSize))

    superRow.pointee = row // return which supertile relative row/col it is
    superCol.pointee = col
    tileRow.pointee = row * Int32(SUPERTILE_SIZE) // return which tile row/col the super tile starts on
    tileCol.pointee = col * Int32(SUPERTILE_SIZE)
}

// MARK: -

// MARK: - Do my terrain update

private let gridMask9: [[UInt8]] = [
    // 0 == empty, 1 == draw tile, 2 == item add ring
    [0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 2, 2, 1, 1, 1, 1, 1, 1, 2, 2, 2, 0, 0, 0],
    [0, 0, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 0, 0],
    [0, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 0],
    [0, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 0],
    [2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2],
    [0, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 0],
    [0, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 0],
    [0, 0, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 0, 0],
    [0, 0, 0, 2, 2, 2, 1, 1, 1, 1, 1, 1, 2, 2, 2, 0, 0, 0],
    [0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0],
]

private let gridMask8: [[UInt8]] = [
    // 0 == empty, 1 == draw tile, 2 == item add ring
    [0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0],
    [0, 0, 2, 2, 2, 1, 1, 1, 1, 1, 1, 2, 2, 2, 0, 0],
    [0, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 0],
    [0, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 0],
    [2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2],
    [0, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 0],
    [0, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 0],
    [0, 0, 2, 2, 2, 1, 1, 1, 1, 1, 1, 2, 2, 2, 0, 0],
    [0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0],
]

private let gridMask7: [[UInt8]] = [
    // 0 == empty, 1 == draw tile, 2 == item add ring
    [0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0],
    [0, 0, 2, 2, 2, 1, 1, 1, 1, 2, 2, 2, 0, 0],
    [0, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 0],
    [0, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 0],
    [2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2],
    [0, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 0],
    [0, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 0],
    [0, 0, 2, 2, 2, 1, 1, 1, 1, 2, 2, 2, 0, 0],
    [0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0],
]

private let gridMask6: [[UInt8]] = [
    // 0 == empty, 1 == draw tile, 2 == item add ring
    [0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0],
    [0, 2, 2, 1, 1, 1, 1, 1, 1, 2, 2, 0],
    [2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2],
    [0, 2, 2, 1, 1, 1, 1, 1, 1, 2, 2, 0],
    [0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0],
]

private let gridMask5: [[UInt8]] = [
    // 0 == empty, 1 == draw tile, 2 == item add ring
    [0, 2, 2, 2, 2, 2, 2, 2, 2, 0],
    [2, 2, 1, 1, 1, 1, 1, 1, 2, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 1, 1, 2],
    [2, 2, 1, 1, 1, 1, 1, 1, 2, 2],
    [0, 2, 2, 2, 2, 2, 2, 2, 2, 0],
]

private let gridMask4: [[UInt8]] = [
    // 0 == empty, 1 == draw tile, 2 == item add ring
    [2, 2, 2, 2, 2, 2, 2, 2],
    [2, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 1, 1, 2],
    [2, 2, 2, 2, 2, 2, 2, 2],
]

private let gridMask3: [[UInt8]] = [
    // 0 == empty, 1 == draw tile, 2 == item add ring
    [2, 2, 2, 2, 2, 2],
    [2, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 2],
    [2, 1, 1, 1, 1, 2],
    [2, 2, 2, 2, 2, 2],
]

func DoPlayerTerrainUpdate() {
    if gEngine.terrain.numUniqueSuperTiles == 0 { // dont draw if terrain not loaded
        return
    }

    // FIRST CLEAR OUT THE PLAYER FLAGS - ASSUME NO PLAYERS ON ANY SUPERTILES

    for row in 0..<Int(gEngine.terrain.numSuperTilesDeep) {
        for col in 0..<Int(gEngine.terrain.numSuperTilesWide) {
            gEngine.terrain.superTileStatusGrid[row]![col].playerHereFlags = 0
        }
    }

    gEngine.terrain.hiccupTimer = 0

    for playerNum in 0..<Int(gEngine.player.numPlayers) {
        let pi = GetPlayerInfoEntry(Int32(playerNum))

        // CALC PIXEL COORDS OF FAR LEFT SUPER TILE

        var x = pi.pointee.camera.cameraLocation.x
        var y = pi.pointee.camera.cameraLocation.z

        x -= Float(gEngine.terrain.superTileActiveRange) * gEngine.terrain.superTileUnitSize // calc pixel coords of far left supertile
        y -= Float(gEngine.terrain.superTileActiveRange) * gEngine.terrain.superTileUnitSize

        // CALC ROW/COL SUPERTILE

        gEngine.terrain.currentSuperTileCol[playerNum] = Int32(x * gEngine.terrain.superTileUnitSizeFrac + 0.5) // round to nearest row/col
        gEngine.terrain.currentSuperTileRow[playerNum] = Int32(y * gEngine.terrain.superTileUnitSizeFrac + 0.5)

        // SEE IF ROW/COLUMN HAVE CHANGED

        let deltaRow = abs(gEngine.terrain.currentSuperTileRow[playerNum] - gEngine.terrain.previousSuperTileRow[playerNum])
        let deltaCol = abs(gEngine.terrain.currentSuperTileCol[playerNum] - gEngine.terrain.previousSuperTileCol[playerNum])

        var moved: Bool
        var fullItemScan: Bool

        if (deltaRow != 0) || (deltaCol != 0) {
            moved = true
            if (deltaRow > 1) || (deltaCol > 1) { // if moved > 1 tile then need to do full item scan
                fullItemScan = true
            } else {
                fullItemScan = false
            }
        } else {
            moved = false
            fullItemScan = false
        }

        // SCAN THE GRID AND SEE WHICH SUPERTILES NEED TO BE INITIALIZED

        let maxRow = gEngine.terrain.currentSuperTileRow[playerNum] + (Int32(gEngine.terrain.superTileActiveRange) * 2)
        let maxCol = gEngine.terrain.currentSuperTileCol[playerNum] + (Int32(gEngine.terrain.superTileActiveRange) * 2)

        var maskRow = 0
        var row = gEngine.terrain.currentSuperTileRow[playerNum]
        while row < maxRow {
            defer { row += 1; maskRow += 1 }

            if row < 0 { // see if row is out of range
                continue
            }
            if row >= gEngine.terrain.numSuperTilesDeep {
                break
            }

            var maskCol = 0
            var col = gEngine.terrain.currentSuperTileCol[playerNum]
            while col < maxCol {
                defer { col += 1; maskCol += 1 }

                if col < 0 { // see if col is out of range
                    continue
                }
                if col >= gEngine.terrain.numSuperTilesWide {
                    break
                }

                // CHECK MASK AND SEE IF WE NEED THIS

                let mask: UInt8
                switch gEngine.terrain.superTileActiveRange {
                case 3:
                    mask = gridMask3[maskRow][maskCol]
                case 4:
                    mask = gridMask4[maskRow][maskCol]
                case 5:
                    mask = gridMask5[maskRow][maskCol]
                case 6:
                    mask = gridMask6[maskRow][maskCol]
                case 7:
                    mask = gridMask7[maskRow][maskCol]
                case 8:
                    mask = gridMask8[maskRow][maskCol]
                case 9:
                    mask = gridMask9[maskRow][maskCol]
                default:
                    return
                }

                if mask == 0 {
                    continue
                } else {
                    gEngine.terrain.superTileStatusGrid[Int(row)]![Int(col)].playerHereFlags |= UInt8(1 << playerNum) // remember which players are using this supertile

                    // ONLY CREATE GEOMETRY

                    // IS THIS SUPERTILE NOT ALREADY DEFINED?

                    if gEngine.terrain.superTileStatusGrid[Int(row)]![Int(col)].statusFlags & UInt8(SUPERTILE_IS_DEFINED) == 0 {
                        if gEngine.terrain.superTileTextureGrid[Int(row)]![Int(col)] != -1 { // supertiles with texture ID -1 are blank, so dont build them
                            gEngine.terrain.superTileStatusGrid[Int(row)]![Int(col)].supertileIndex = buildTerrainSuperTile(Int(col) * Int(SUPERTILE_SIZE), Int(row) * Int(SUPERTILE_SIZE)) // build the supertile
                            gEngine.terrain.superTileStatusGrid[Int(row)]![Int(col)].statusFlags = UInt8(SUPERTILE_IS_DEFINED) | UInt8(SUPERTILE_IS_USED_THIS_FRAME) // mark as defined & used
                        }
                    } else {
                        gEngine.terrain.superTileStatusGrid[Int(row)]![Int(col)].statusFlags |= UInt8(SUPERTILE_IS_USED_THIS_FRAME) // mark this as used
                    }
                }

                // SEE IF ADD ITEMS ON THIS SUPERTILE

                if moved { // dont check for items if we didnt move
                    if fullItemScan || (mask == 2) { // if full scan or mask is 2 then check for items
                        AddTerrainItemsOnSuperTile(Int(row), Int(col))
                    }
                }
            }
        }

        // UPDATE STUFF

        gEngine.terrain.previousSuperTileRow[playerNum] = gEngine.terrain.currentSuperTileRow[playerNum]
        gEngine.terrain.previousSuperTileCol[playerNum] = gEngine.terrain.currentSuperTileCol[playerNum]

        calcNewItemDeleteWindow(UInt8(playerNum)) // recalc item delete window
    }
}

// MARK: - Calc new item delete window

private func calcNewItemDeleteWindow(_ playerNum: UInt8) {
    let pi = GetPlayerInfoEntry(Int32(playerNum))

    // CALC LEFT SIDE OF WINDOW

    var temp = Float(gEngine.terrain.currentSuperTileCol[Int(playerNum)]) * gEngine.terrain.superTileUnitSize // convert to unit coords
    pi.pointee.itemDeleteWindow.left = temp

    // CALC RIGHT SIDE OF WINDOW

    temp += Float(gEngine.terrain.superTileActiveRange * 2) * gEngine.terrain.superTileUnitSize // calc offset to right side (SUPERTILE_DIST_WIDE)
    pi.pointee.itemDeleteWindow.right = temp

    // CALC FAR SIDE OF WINDOW

    temp = Float(gEngine.terrain.currentSuperTileRow[Int(playerNum)]) * gEngine.terrain.superTileUnitSize // convert to unit coords
    pi.pointee.itemDeleteWindow.top = temp

    // CALC NEAR SIDE OF WINDOW

    temp += Float(gEngine.terrain.superTileActiveRange * 2) * gEngine.terrain.superTileUnitSize // calc offset to bottom side (SUPERTILE_DIST_DEEP)
    pi.pointee.itemDeleteWindow.bottom = temp
}

// MARK: -

// MARK: - Calculate split mode matrix

func CalculateSplitModeMatrix() {
    gEngine.terrain.mapSplitMode = alloc2DArray(UInt8.self, rows: Int(gEngine.terrain.tileDepth), cols: Int(gEngine.terrain.tileWidth)) // alloc 2D array

    for row in 0..<Int(gEngine.terrain.tileDepth) {
        for col in 0..<Int(gEngine.terrain.tileWidth) {
            // GET Y COORDS OF 4 VERTICES

            let y0 = gEngine.terrain.mapYCoords[row]![col]
            let y1 = gEngine.terrain.mapYCoords[row]![col + 1]
            let y2 = gEngine.terrain.mapYCoords[row + 1]![col + 1]
            let y3 = gEngine.terrain.mapYCoords[row + 1]![col]

            // QUICK CHECK FOR FLAT POLYS

            if (y0 == y1) && (y0 == y2) && (y0 == y3) { // see if all same level
                gEngine.terrain.mapSplitMode[row]![col] = UInt8(SPLIT_BACKWARD)
            }

            // CALC FOLD-SPLIT
            else {
                if fabsf(y0 - y2) < fabsf(y1 - y3) {
                    gEngine.terrain.mapSplitMode[row]![col] = UInt8(SPLIT_BACKWARD) // use \ splits
                } else {
                    gEngine.terrain.mapSplitMode[row]![col] = UInt8(SPLIT_FORWARD) // use / splits
                }
            }
        }
    }
}
