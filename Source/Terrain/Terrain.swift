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
// gWorkGrid, the tile-triangle-splitting tables, gHiccupTimer,
// gNumSuperTilesDrawn, gNumFreeSupertiles, and the (dead,
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

var gTerrainPolygonSize: Float = 0
var gTerrainPolygonSizeInt: UInt32 = 0
var gTerrainSuperTileUnitSize: Float = 0
var gTerrainSuperTileUnitSizeFrac: Float = 0
var gMapToUnitValue: Float = 0
var gMapToUnitValueFrac: Float = 0
var gSuperTileActiveRange: Int32 = 4
var gDisableHiccupTimer: UInt8 = 0
var gSuperTileStatusGrid: UnsafeMutablePointer<UnsafeMutablePointer<SuperTileStatus>?>!
var gTerrainTileWidth: Int = 0
var gTerrainTileDepth: Int = 0
var gTerrainUnitWidth: Int = 0
var gTerrainUnitDepth: Int = 0
var gNumUniqueSuperTiles: Int = 0
var gSuperTileTextureGrid: UnsafeMutablePointer<UnsafeMutablePointer<Int16>?>!
var gSuperTilePixelBuffers: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>!
var gVertexShading: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>!
var gNumSuperTilesDeep: Int = 0
var gNumSuperTilesWide: Int = 0
var gRecentTerrainNormal = OGLVector3D()

var gNumTerrainItems: Int32 = 0
var gMasterItemList: UnsafeMutablePointer<TerrainItemEntryType>!
var gMapYCoords: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>!
var gMapYCoordsOriginal: UnsafeMutablePointer<UnsafeMutablePointer<Float>?>!
var gMapSplitMode: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>!
var gSuperTileItemIndexGrid: UnsafeMutablePointer<UnsafeMutablePointer<SuperTileItemIndexType>?>!
var gNumLineMarkers: Int32 = 0

private let gSuperTileTextureObjectsBuf: UnsafeMutablePointer<UnsafeMutablePointer<MOMaterialObject>?> = {
    let buf = UnsafeMutablePointer<UnsafeMutablePointer<MOMaterialObject>?>.allocate(capacity: maxSuperTileTextures)
    buf.initialize(repeating: nil, count: maxSuperTileTextures)
    return buf
}()
func GetSuperTileTextureObjectSlot(_ i: Int32) -> UnsafeMutablePointer<UnsafeMutablePointer<MOMaterialObject>?>! {
    gSuperTileTextureObjectsBuf + Int(i)
}

private let gSuperTileMemoryListBuf: UnsafeMutablePointer<SuperTileMemoryType> = {
    let buf = UnsafeMutablePointer<SuperTileMemoryType>.allocate(capacity: maxSupertiles)
    buf.initialize(repeating: SuperTileMemoryType(), count: maxSupertiles)
    return buf
}()
func GetSuperTileMemoryEntry(_ i: Int32) -> UnsafeMutablePointer<SuperTileMemoryType>! {
    gSuperTileMemoryListBuf + Int(i)
}

private let gLineMarkerListBuf: UnsafeMutablePointer<LineMarkerDefType> = {
    let buf = UnsafeMutablePointer<LineMarkerDefType>.allocate(capacity: Int(MAX_LINEMARKERS))
    buf.initialize(repeating: LineMarkerDefType(), count: Int(MAX_LINEMARKERS))
    return buf
}()
func GetLineMarkerPtr(_ i: Int32) -> UnsafeMutablePointer<LineMarkerDefType> {
    gLineMarkerListBuf + Int(i)
}

private var gNumSuperTilesDrawn: Int16 = 0
private var gHiccupTimer: UInt8 = 0

// gTerrainPolygonSizeFrac has no `extern` declaration anywhere in the headers
// (only gTerrainPolygonSize, gTerrainPolygonSizeInt, gTerrainSuperTileUnitSizeFrac,
// and gMapToUnitValueFrac are), so it was always file-private to Terrain.c.
private var gTerrainPolygonSizeFrac: Float = 0

// MAX_SUPERTILES/NUM_TRIS_IN_SUPERTILE/NUM_VERTICES_IN_SUPERTILE are multi-macro
// expressions ClangImporter can't fold into single constants.
private let maxSupertiles = (9 * 2 * 9 * 2) * 2 * 2 // MAX_SUPERTILES: (MAX_SUPERTILE_ACTIVE_RANGE*2 * MAX_SUPERTILE_ACTIVE_RANGE*2)*MAX_SPLITSCREENS * 2
private let numTrisInSupertile = Int(SUPERTILE_SIZE) * Int(SUPERTILE_SIZE) * 2
private let numVerticesInSupertile = (Int(SUPERTILE_SIZE) + 1) * (Int(SUPERTILE_SIZE) + 1)

private var gNumFreeSupertiles: Int16 = 0

// TILE SPLITTING TABLES - file-local only, plain nested Swift arrays.

private var gTileTriangles1_A = Array(repeating: Array(repeating: [UInt8](repeating: 0, count: 3), count: Int(SUPERTILE_SIZE)), count: Int(SUPERTILE_SIZE))
private var gTileTriangles2_A = Array(repeating: Array(repeating: [UInt8](repeating: 0, count: 3), count: Int(SUPERTILE_SIZE)), count: Int(SUPERTILE_SIZE))
private var gTileTriangles1_B = Array(repeating: Array(repeating: [UInt8](repeating: 0, count: 3), count: Int(SUPERTILE_SIZE)), count: Int(SUPERTILE_SIZE))
private var gTileTriangles2_B = Array(repeating: Array(repeating: [UInt8](repeating: 0, count: 3), count: Int(SUPERTILE_SIZE)), count: Int(SUPERTILE_SIZE))

private var gWorkGrid = Array(repeating: Array(repeating: OGLVertex(), count: Int(SUPERTILE_SIZE) + 1), count: Int(SUPERTILE_SIZE) + 1)

// MASTER ARRAYS FOR ALL SUPERTILE DATA FOR CURRENT LEVEL

private var gSuperTileMeshData: UnsafeMutablePointer<MOVertexArrayData>?
private var gSuperTileTriangles: UnsafeMutablePointer<MOTriangleIndecies>?
private var gSuperTileCoords: UnsafeMutablePointer<OGLPoint3D>?
private var gSuperTileUVs: UnsafeMutablePointer<OGLTextureCoord>?
private var gSuperTileNormals: UnsafeMutablePointer<OGLVector3D>?
private var gSuperTileColors: UnsafeMutablePointer<OGLColorRGBA>?

// IsStereo is a parameterized C macro, which Swift can't import as a callable symbol.
private func isStereo() -> Bool { gGamePrefs.stereoGlassesMode != UInt8(StereoGlassesMode.off.rawValue) }

// MARK: - Init terrain manager

// Only called at boot!
func InitTerrainManager() {
    SetTerrainScale(Int32(DEFAULT_TERRAIN_SCALE)) // set scale to some default for now

    // BUILT TRIANGLE SPLITTING TABLES

    for y in 0..<Int(SUPERTILE_SIZE) {
        for x in 0..<Int(SUPERTILE_SIZE) {
            gTileTriangles1_A[y][x][0] = UInt8((Int(SUPERTILE_SIZE) + 1) * y + x + 1)
            gTileTriangles1_A[y][x][1] = UInt8((Int(SUPERTILE_SIZE) + 1) * y + x)
            gTileTriangles1_A[y][x][2] = UInt8((Int(SUPERTILE_SIZE) + 1) * (y + 1) + x)

            gTileTriangles2_A[y][x][0] = UInt8((Int(SUPERTILE_SIZE) + 1) * (y + 1) + x + 1)
            gTileTriangles2_A[y][x][1] = UInt8((Int(SUPERTILE_SIZE) + 1) * y + x + 1)
            gTileTriangles2_A[y][x][2] = UInt8((Int(SUPERTILE_SIZE) + 1) * (y + 1) + x)

            gTileTriangles1_B[y][x][0] = UInt8((Int(SUPERTILE_SIZE) + 1) * (y + 1) + x)
            gTileTriangles1_B[y][x][1] = UInt8((Int(SUPERTILE_SIZE) + 1) * (y + 1) + x + 1)
            gTileTriangles1_B[y][x][2] = UInt8((Int(SUPERTILE_SIZE) + 1) * y + x)

            gTileTriangles2_B[y][x][0] = UInt8((Int(SUPERTILE_SIZE) + 1) * (y + 1) + x + 1)
            gTileTriangles2_B[y][x][1] = UInt8((Int(SUPERTILE_SIZE) + 1) * y + x + 1)
            gTileTriangles2_B[y][x][2] = UInt8((Int(SUPERTILE_SIZE) + 1) * y + x)
        }
    }
}

// MARK: - Set terrain scale

func SetTerrainScale(_ polygonSize: Int32) {
    gTerrainPolygonSize = Float(polygonSize) // size in world units of terrain polygon
    gTerrainPolygonSizeInt = UInt32(polygonSize)

    gTerrainPolygonSizeFrac = 1.0 / gTerrainPolygonSize

    gTerrainSuperTileUnitSize = Float(SUPERTILE_SIZE) * gTerrainPolygonSize // world unit size of a supertile
    gTerrainSuperTileUnitSizeFrac = 1.0 / gTerrainSuperTileUnitSize

    gMapToUnitValue = gTerrainPolygonSize / Float(OREOMAP_TILE_SIZE) // value to xlate Oreo map pixel coords to 3-space unit coords
    gMapToUnitValueFrac = 1.0 / gMapToUnitValue

    if gGamePrefs.isLowRenderQuality {
        gSuperTileActiveRange = 7
    } else {
        gSuperTileActiveRange = Int32(MAX_SUPERTILE_ACTIVE_RANGE)
    }
}

// MARK: - Init current scroll settings

func InitCurrentScrollSettings() {
    for i in 0..<Int(gEngine.player.numPlayers) { // init settings for each player in game
        let pi = GetPlayerInfoEntry(Int32(i))
        let x = Int(pi.pointee.coord.x - (Float(gSuperTileActiveRange) * gTerrainSuperTileUnitSize))
        let y = Int(pi.pointee.coord.z - (Float(gSuperTileActiveRange) * gTerrainSuperTileUnitSize))

        var dummy1: Int32 = 0
        var dummy2: Int32 = 0
        GetSuperTileInfo(x, y, &gCurrentSuperTileCol[i], &gCurrentSuperTileRow[i], &dummy1, &dummy2)

        gPreviousSuperTileCol[i] = -100000
        gPreviousSuperTileRow[i] = -100000
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

// gCurrentSuperTileRow/Col and gPreviousSuperTileRow/Col were `static int[MAX_PLAYERS]`
// in the original C, only ever touched from this file.
private var gCurrentSuperTileRow: [Int32] = Array(repeating: 0, count: Int(MAX_PLAYERS))
private var gCurrentSuperTileCol: [Int32] = Array(repeating: 0, count: Int(MAX_PLAYERS))
private var gPreviousSuperTileCol: [Int32] = Array(repeating: 0, count: Int(MAX_PLAYERS))
private var gPreviousSuperTileRow: [Int32] = Array(repeating: 0, count: Int(MAX_PLAYERS))

// MARK: - Init supertile grid

func InitSuperTileGrid() {
    gSuperTileStatusGrid = alloc2DArray(SuperTileStatus.self, rows: Int(gNumSuperTilesDeep), cols: Int(gNumSuperTilesWide)) // alloc 2D grid array

    // INIT ALL GRID SLOTS TO EMPTY AND UNUSED

    for r in 0..<Int(gNumSuperTilesDeep) {
        for c in 0..<Int(gNumSuperTilesWide) {
            gSuperTileStatusGrid[r]![c].supertileIndex = 0
            gSuperTileStatusGrid[r]![c].statusFlags = 0
            gSuperTileStatusGrid[r]![c].playerHereFlags = 0
        }
    }
}

// MARK: - Dispose terrain

// Deletes any existing terrain data
func DisposeTerrain() {
    DisposeSuperTileMemoryList()

    // FREE ALL TEXTURE OBJECTS

    for i in 0..<Int(gNumUniqueSuperTiles) {
        MO_DisposeObjectReference(UnsafeMutableRawPointer(GetSuperTileTextureObjectSlot(Int32(i))!.pointee))
        GetSuperTileTextureObjectSlot(Int32(i))!.pointee = nil
    }
    gNumUniqueSuperTiles = 0

    if gSuperTileItemIndexGrid != nil {
        free2DArray(gSuperTileItemIndexGrid)
        gSuperTileItemIndexGrid = nil
    }

    if gSuperTileTextureGrid != nil {
        free2DArray(gSuperTileTextureGrid)
        gSuperTileTextureGrid = nil
    }

    if gSuperTileStatusGrid != nil {
        free2DArray(gSuperTileStatusGrid)
        gSuperTileStatusGrid = nil
    }

    if gVertexShading != nil {
        free2DArray(gVertexShading)
        gVertexShading = nil
    }

    if gMasterItemList != nil {
        SafeDisposePtr(gMasterItemList)
        gMasterItemList = nil
    }

    if gMapYCoords != nil {
        free2DArray(gMapYCoords)
        gMapYCoords = nil
    }

    if gMapYCoordsOriginal != nil {
        free2DArray(gMapYCoordsOriginal)
        gMapYCoordsOriginal = nil
    }

    if gMapSplitMode != nil {
        free2DArray(gMapSplitMode)
        gMapSplitMode = nil
    }

    // NUKE SPLINE DATA

    if let splineList = gSplineList {
        for i in 0..<Int(gNumSplines) {
            SafeDisposePtr(splineList[i].pointList) // nuke point list
            SafeDisposePtr(splineList[i].itemList) // nuke item list
        }
        SafeDisposePtr(splineList)
        gSplineList = nil
    }

    // NUKE WATER PATCH

    if gWaterListHandle != nil {
        DisposeWaterListHandle(gWaterListHandle)
        gWaterListHandle = nil
    }

    gWaterList = nil
    gNumWaterPatches = 0
    gNumSuperTilesDeep = 0
    gNumSuperTilesWide = 0

    releaseAllSuperTiles()

    DisposeFences()
}

// MARK: -

// MARK: - Create supertile memory list

// Preallocates memory and initializes the data for the maximum number of supertiles that
// we will ever need on this level.
func CreateSuperTileMemoryList() {
    // ALLOCATE ARRAYS FOR ALL THE DATA WE WILL NEED

    gNumFreeSupertiles = Int16(maxSupertiles)

    // ALLOC BASE TRIMESH DATA FOR ALL SUPERTILES

    guard let meshData = AllocPtrClear(MemoryLayout<MOVertexArrayData>.size * maxSupertiles)?.assumingMemoryBound(to: MOVertexArrayData.self) else {
        SwFatal("CreateSuperTileMemoryList: AllocPtr failed - gSuperTileMeshData")
        return
    }
    gSuperTileMeshData = meshData

    // ALLOC TRIANGLE ARRAYS ALL SUPERTILES

    let triangles = OGL_AllocVertexArrayMemory(Int(MemoryLayout<MOTriangleIndecies>.size * numTrisInSupertile * maxSupertiles), UInt8(VertexArrayRangeType.terrain.rawValue))!.assumingMemoryBound(to: MOTriangleIndecies.self)
    gSuperTileTriangles = triangles

    // ALLOC POINTS FOR ALL SUPERTILES

    let coords = OGL_AllocVertexArrayMemory(Int(MemoryLayout<OGLPoint3D>.size * (numVerticesInSupertile * maxSupertiles)), UInt8(VertexArrayRangeType.terrain.rawValue))!.assumingMemoryBound(to: OGLPoint3D.self)
    gSuperTileCoords = coords

    // ALLOC VERTEX NORMALS FOR ALL SUPERTILES

    let normals = OGL_AllocVertexArrayMemory(Int(MemoryLayout<OGLVector3D>.size * (numVerticesInSupertile * maxSupertiles)), UInt8(VertexArrayRangeType.terrain.rawValue))!.assumingMemoryBound(to: OGLVector3D.self)
    gSuperTileNormals = normals

    // ALLOC UVS FOR ALL SUPERTILES

    let uvs = OGL_AllocVertexArrayMemory(Int(MemoryLayout<OGLTextureCoord>.size * numVerticesInSupertile * maxSupertiles), UInt8(VertexArrayRangeType.terrain.rawValue))!.assumingMemoryBound(to: OGLTextureCoord.self)
    gSuperTileUVs = uvs

    // ALLOC VERTEX COLORS FOR ALL SUPERTILES

    let colors = OGL_AllocVertexArrayMemory(Int(MemoryLayout<OGLColorRGBA>.size * numVerticesInSupertile * maxSupertiles), UInt8(VertexArrayRangeType.terrain.rawValue))!.assumingMemoryBound(to: OGLColorRGBA.self)
    gSuperTileColors = colors

    // FOR EACH POSSIBLE SUPERTILE SET INFO

    let seamlessTexmapSize: Float = 2.0 + Float(SUPERTILE_TEXMAP_SIZE)
    let seamlessUVScale: Float = Float(SUPERTILE_TEXMAP_SIZE) / seamlessTexmapSize
    let seamlessUVTranslate: Float = 1.0 / seamlessTexmapSize

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

    if let meshData = gSuperTileMeshData {
        SafeDisposePtr(meshData)
    }
    gSuperTileMeshData = nil

    if let triangles = gSuperTileTriangles {
        OGL_FreeVertexArrayMemory(triangles, UInt8(VertexArrayRangeType.terrain.rawValue))
        gSuperTileTriangles = nil
    }

    if let coords = gSuperTileCoords {
        OGL_FreeVertexArrayMemory(coords, UInt8(VertexArrayRangeType.terrain.rawValue))
    }
    gSuperTileCoords = nil

    if let normals = gSuperTileNormals {
        OGL_FreeVertexArrayMemory(normals, UInt8(VertexArrayRangeType.terrain.rawValue))
    }
    gSuperTileNormals = nil

    if let uvs = gSuperTileUVs {
        OGL_FreeVertexArrayMemory(uvs, UInt8(VertexArrayRangeType.terrain.rawValue))
    }
    gSuperTileUVs = nil

    if let colors = gSuperTileColors {
        OGL_FreeVertexArrayMemory(colors, UInt8(VertexArrayRangeType.terrain.rawValue))
    }
    gSuperTileColors = nil
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
            gNumFreeSupertiles -= 1
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

    superTilePtr.pointee.x = (Float(startCol) * gTerrainPolygonSize) + (gTerrainSuperTileUnitSize * 0.5) // also remember world coords (center of supertile)
    superTilePtr.pointee.z = (Float(startRow) * gTerrainPolygonSize) + (gTerrainSuperTileUnitSize * 0.5)

    superTilePtr.pointee.left = Int(Float(startCol) * gTerrainPolygonSize) // also save left/back coord
    superTilePtr.pointee.back = Int(Float(startRow) * gTerrainPolygonSize)

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
            if (row >= Int(gTerrainTileDepth)) || (col >= Int(gTerrainTileWidth)) { // check for edge vertices (off map array)
                height = 0
            } else {
                height = gMapYCoords[row]![col] // get pixel height here
            }

            // SET COORD

            gWorkGrid[row2][col2].point.x = Float(col) * gTerrainPolygonSize
            gWorkGrid[row2][col2].point.z = Float(row) * gTerrainPolygonSize
            gWorkGrid[row2][col2].point.y = height // save height @ this tile's upper left corner

            // SET UV

            gWorkGrid[row2][col2].uv.u = Float(col2) * (0.99 / Float(SUPERTILE_SIZE)) // sets uv's 0.0 -> .99 for single texture map
            gWorkGrid[row2][col2].uv.v = 0.99 - (Float(row2) * (0.99 / Float(SUPERTILE_SIZE)))

            // SET COLOR

            gWorkGrid[row2][col2].color.r = 1.0
            gWorkGrid[row2][col2].color.g = 1.0
            gWorkGrid[row2][col2].color.b = 1.0
            gWorkGrid[row2][col2].color.a = 1.0

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
            vertexPointList[numPoints] = gWorkGrid[row][col].point // copy from work grid
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

            if gMapSplitMode[row]![col] == UInt8(SPLIT_BACKWARD) { // set coords & uv's based on splitting
                // \
                triangleList[i].vertexIndices.0 = UInt32(gTileTriangles1_B[row2][col2][0])
                triangleList[i].vertexIndices.1 = UInt32(gTileTriangles1_B[row2][col2][1])
                triangleList[i].vertexIndices.2 = UInt32(gTileTriangles1_B[row2][col2][2])
                i += 1
                triangleList[i].vertexIndices.0 = UInt32(gTileTriangles2_B[row2][col2][0])
                triangleList[i].vertexIndices.1 = UInt32(gTileTriangles2_B[row2][col2][1])
                triangleList[i].vertexIndices.2 = UInt32(gTileTriangles2_B[row2][col2][2])
                i += 1
            } else {
                // /
                triangleList[i].vertexIndices.0 = UInt32(gTileTriangles1_A[row2][col2][0])
                triangleList[i].vertexIndices.1 = UInt32(gTileTriangles1_A[row2][col2][1])
                triangleList[i].vertexIndices.2 = UInt32(gTileTriangles1_A[row2][col2][2])
                i += 1
                triangleList[i].vertexIndices.0 = UInt32(gTileTriangles2_A[row2][col2][0])
                triangleList[i].vertexIndices.1 = UInt32(gTileTriangles2_A[row2][col2][1])
                triangleList[i].vertexIndices.2 = UInt32(gTileTriangles2_A[row2][col2][2])
                i += 1
            }
        }
    }

    // CALCULATE VERTEX NORMALS

    CalculateSupertileVertexNormals(meshData, startRow, startCol)

    // CALCULATE VERTEX COLORS

    if let vertexColorList {
        // GET LIGHT DATA

        let ambientR = gGameViewInfoPtr!.pointee.lightList.ambientColor.r // get ambient color
        let ambientG = gGameViewInfoPtr!.pointee.lightList.ambientColor.g
        let ambientB = gGameViewInfoPtr!.pointee.lightList.ambientColor.b

        let fillR0 = gGameViewInfoPtr!.pointee.lightList.fillColor.0.r // get fill color
        let fillG0 = gGameViewInfoPtr!.pointee.lightList.fillColor.0.g
        let fillB0 = gGameViewInfoPtr!.pointee.lightList.fillColor.0.b
        var fillDir0 = gGameViewInfoPtr!.pointee.lightList.fillDirection.0 // get fill direction
        fillDir0.x = -fillDir0.x
        fillDir0.y = -fillDir0.y
        fillDir0.z = -fillDir0.z

        var fillR1: Float = 0, fillG1: Float = 0, fillB1: Float = 0
        var fillDir1 = OGLVector3D()

        let numFillLights = gGameViewInfoPtr!.pointee.lightList.numFillLights
        if numFillLights > 1 {
            fillR1 = gGameViewInfoPtr!.pointee.lightList.fillColor.1.r
            fillG1 = gGameViewInfoPtr!.pointee.lightList.fillColor.1.g
            fillB1 = gGameViewInfoPtr!.pointee.lightList.fillColor.1.b
            fillDir1 = gGameViewInfoPtr!.pointee.lightList.fillDirection.1
            fillDir1.x = -fillDir1.x
            fillDir1.y = -fillDir1.y
            fillDir1.z = -fillDir1.z
        }

        i = 0
        for row in 0...Int(SUPERTILE_SIZE) {
            for col in 0...Int(SUPERTILE_SIZE) {
                let shade = gVertexShading[row + Int(startRow)]![col + Int(startCol)] // get value from shading grid

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

    superTilePtr.pointee.bBox.min.x = gWorkGrid[0][0].point.x
    superTilePtr.pointee.bBox.max.x = gWorkGrid[0][0].point.x + gTerrainSuperTileUnitSize
    superTilePtr.pointee.bBox.min.y = miny
    superTilePtr.pointee.bBox.max.y = maxy
    superTilePtr.pointee.bBox.min.z = gWorkGrid[0][0].point.z
    superTilePtr.pointee.bBox.max.z = gWorkGrid[0][0].point.z + gTerrainSuperTileUnitSize

    if gDisableHiccupTimer != 0 {
        superTilePtr.pointee.hiccupTimer = 0
    } else {
        superTilePtr.pointee.hiccupTimer = gHiccupTimer
        gHiccupTimer += 1
        gHiccupTimer &= 0x1 // spread over 2 frames
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
    gNumFreeSupertiles += 1
}

// MARK: - Release all supertiles

private func releaseAllSuperTiles() {
    for i in 0..<maxSupertiles {
        releaseSuperTileObject(Int16(i))
    }

    gNumFreeSupertiles = Int16(maxSupertiles)
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

    gNumSuperTilesDrawn = 0

    // SCAN THE SUPERTILE GRID AND LOOK FOR USED & VISIBLE SUPERTILES

    for r in 0..<Int(gNumSuperTilesDeep) {
        for c in 0..<Int(gNumSuperTilesWide) {
            if gSuperTileStatusGrid[r]![c].statusFlags & UInt8(SUPERTILE_IS_USED_THIS_FRAME) != 0 { // see if used
                let i = Int(gSuperTileStatusGrid[r]![c].supertileIndex) // extract supertile #

                // SEE WHICH UNIQUE SUPERTILE TEXTURE TO USE

                let unique = Int(gSuperTileTextureGrid[r]![c])
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
                gNumSuperTilesDrawn += 1
            }
        }
    }

    OGL_PopState()
    gEngine.renderer.setAlphaTestEnabled(true)

    // PREPARE SUPERTILE GRID FOR THE NEXT FRAME

    var doPrepGrid = true
    if gActiveSplitScreenMode != UInt8(SplitscreenMode.none.rawValue) { // if splitscreen, then dont do this until done with player #2
        if gCurrentSplitScreenPane < 1 {
            doPrepGrid = false
        }
    }

    if doPrepGrid {
        for r in 0..<Int(gNumSuperTilesDeep) {
            for c in 0..<Int(gNumSuperTilesWide) {
                // IF THIS SUPERTILE WAS NOT USED BUT IS DEFINED, THEN FREE IT

                if gSuperTileStatusGrid[r]![c].statusFlags & UInt8(SUPERTILE_IS_DEFINED) != 0 { // is it defined?
                    if gSuperTileStatusGrid[r]![c].statusFlags & UInt8(SUPERTILE_IS_USED_THIS_FRAME) == 0 { // was it used?  If not, then release the supertile definition
                        releaseSuperTileObject(Int16(gSuperTileStatusGrid[r]![c].supertileIndex))
                        gSuperTileStatusGrid[r]![c].statusFlags = 0 // no longer defined
                    }
                }

                // ASSUME SUPERTILES WILL BE UNUSED ON NEXT FRAME

                if !isStereo() || (gAnaglyphPass > 0) {
                    gSuperTileStatusGrid[r]![c].statusFlags &= ~UInt8(SUPERTILE_IS_USED_THIS_FRAME) // clear the isUsed bit
                }
            }
        }
    }

    // (VERTEXARRAYRANGES is hardcoded off, so the "insert OpenGL fence" block here is dead code and dropped.)

    // DRAW SPLINES IN DEBUG MODE

    if gDebugMode == 2 {
        gEngine.renderer.setColor4f(0.5, 1.0, 0.75, 1)

        for splineNum in 0..<Int(gNumSplines) {
            gEngine.renderer.beginImmediate(.lineStrip)

            let spline = gSplineList[splineNum]
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
    if gMapYCoords == nil { // make sure there's a terrain
        return ILLEGAL_TERRAIN_Y
    }

    // CALC TILE ROW/COL INFO

    let col = Int16(x * gTerrainPolygonSizeFrac) // see which tile row/col we're on
    let row = Int16(z * gTerrainPolygonSizeFrac)

    if (col < 0) || (col >= Int16(gTerrainTileWidth)) { // check bounds
        return 0
    }
    if (row < 0) || (row >= Int16(gTerrainTileDepth)) {
        return 0
    }

    let xi = x - (Float(col) * Float(gTerrainPolygonSizeInt)) // calc x/z offset into the tile
    let zi = z - (Float(row) * Float(gTerrainPolygonSizeInt))

    // BUILD VERTICES FOR THE 4 CORNERS OF THE TILE

    var p = [OGLPoint3D](repeating: OGLPoint3D(), count: 4)

    p[0].x = Float(col) * Float(gTerrainPolygonSizeInt) // far left
    p[0].y = gMapYCoords[Int(row)]![Int(col)]
    p[0].z = Float(row) * Float(gTerrainPolygonSizeInt)

    p[1].x = p[0].x + gTerrainPolygonSize // far right
    p[1].y = gMapYCoords[Int(row)]![Int(col) + 1]
    p[1].z = p[0].z

    p[2].x = p[1].x // near right
    p[2].y = gMapYCoords[Int(row) + 1]![Int(col) + 1]
    p[2].z = p[1].z + gTerrainPolygonSize

    p[3].x = Float(col) * Float(gTerrainPolygonSizeInt) // near left
    p[3].y = gMapYCoords[Int(row) + 1]![Int(col)]
    p[3].z = p[2].z

    // CALC PLANE EQUATION FOR TRIANGLE

    var planeEq = OGLPlaneEquation()
    var xiAdj = xi

    if gMapSplitMode[Int(row)]![Int(col)] == UInt8(SPLIT_BACKWARD) { // if \ split
        if xiAdj < zi { // which triangle are we on?
            CalcPlaneEquationOfTriangle(&planeEq, &p[0], &p[2], &p[3]) // calc plane equation for left triangle
        } else {
            CalcPlaneEquationOfTriangle(&planeEq, &p[0], &p[1], &p[2]) // calc plane equation for right triangle
        }
    } else { // otherwise, / split
        xiAdj = gTerrainPolygonSize - xiAdj // flip x
        if xiAdj > zi {
            CalcPlaneEquationOfTriangle(&planeEq, &p[0], &p[1], &p[3]) // calc plane equation for left triangle
        } else {
            CalcPlaneEquationOfTriangle(&planeEq, &p[1], &p[2], &p[3]) // calc plane equation for right triangle
        }
    }

    gRecentTerrainNormal = planeEq.normal // remember the normal here

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
    if (x >= gTerrainUnitWidth) || (z >= gTerrainUnitDepth) {
        return
    }

    let col = Int32(Float(x) * (1.0 / gTerrainSuperTileUnitSize)) // calc supertile relative row/col that the coord lies on
    let row = Int32(Float(z) * (1.0 / gTerrainSuperTileUnitSize))

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
    if gNumUniqueSuperTiles == 0 { // dont draw if terrain not loaded
        return
    }

    // FIRST CLEAR OUT THE PLAYER FLAGS - ASSUME NO PLAYERS ON ANY SUPERTILES

    for row in 0..<Int(gNumSuperTilesDeep) {
        for col in 0..<Int(gNumSuperTilesWide) {
            gSuperTileStatusGrid[row]![col].playerHereFlags = 0
        }
    }

    gHiccupTimer = 0

    for playerNum in 0..<Int(gEngine.player.numPlayers) {
        let pi = GetPlayerInfoEntry(Int32(playerNum))

        // CALC PIXEL COORDS OF FAR LEFT SUPER TILE

        var x = pi.pointee.camera.cameraLocation.x
        var y = pi.pointee.camera.cameraLocation.z

        x -= Float(gSuperTileActiveRange) * gTerrainSuperTileUnitSize // calc pixel coords of far left supertile
        y -= Float(gSuperTileActiveRange) * gTerrainSuperTileUnitSize

        // CALC ROW/COL SUPERTILE

        gCurrentSuperTileCol[playerNum] = Int32(x * gTerrainSuperTileUnitSizeFrac + 0.5) // round to nearest row/col
        gCurrentSuperTileRow[playerNum] = Int32(y * gTerrainSuperTileUnitSizeFrac + 0.5)

        // SEE IF ROW/COLUMN HAVE CHANGED

        let deltaRow = abs(gCurrentSuperTileRow[playerNum] - gPreviousSuperTileRow[playerNum])
        let deltaCol = abs(gCurrentSuperTileCol[playerNum] - gPreviousSuperTileCol[playerNum])

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

        let maxRow = gCurrentSuperTileRow[playerNum] + (Int32(gSuperTileActiveRange) * 2)
        let maxCol = gCurrentSuperTileCol[playerNum] + (Int32(gSuperTileActiveRange) * 2)

        var maskRow = 0
        var row = gCurrentSuperTileRow[playerNum]
        while row < maxRow {
            defer { row += 1; maskRow += 1 }

            if row < 0 { // see if row is out of range
                continue
            }
            if row >= gNumSuperTilesDeep {
                break
            }

            var maskCol = 0
            var col = gCurrentSuperTileCol[playerNum]
            while col < maxCol {
                defer { col += 1; maskCol += 1 }

                if col < 0 { // see if col is out of range
                    continue
                }
                if col >= gNumSuperTilesWide {
                    break
                }

                // CHECK MASK AND SEE IF WE NEED THIS

                let mask: UInt8
                switch gSuperTileActiveRange {
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
                    gSuperTileStatusGrid[Int(row)]![Int(col)].playerHereFlags |= UInt8(1 << playerNum) // remember which players are using this supertile

                    // ONLY CREATE GEOMETRY

                    // IS THIS SUPERTILE NOT ALREADY DEFINED?

                    if gSuperTileStatusGrid[Int(row)]![Int(col)].statusFlags & UInt8(SUPERTILE_IS_DEFINED) == 0 {
                        if gSuperTileTextureGrid[Int(row)]![Int(col)] != -1 { // supertiles with texture ID -1 are blank, so dont build them
                            gSuperTileStatusGrid[Int(row)]![Int(col)].supertileIndex = buildTerrainSuperTile(Int(col) * Int(SUPERTILE_SIZE), Int(row) * Int(SUPERTILE_SIZE)) // build the supertile
                            gSuperTileStatusGrid[Int(row)]![Int(col)].statusFlags = UInt8(SUPERTILE_IS_DEFINED) | UInt8(SUPERTILE_IS_USED_THIS_FRAME) // mark as defined & used
                        }
                    } else {
                        gSuperTileStatusGrid[Int(row)]![Int(col)].statusFlags |= UInt8(SUPERTILE_IS_USED_THIS_FRAME) // mark this as used
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

        gPreviousSuperTileRow[playerNum] = gCurrentSuperTileRow[playerNum]
        gPreviousSuperTileCol[playerNum] = gCurrentSuperTileCol[playerNum]

        calcNewItemDeleteWindow(UInt8(playerNum)) // recalc item delete window
    }
}

// MARK: - Calc new item delete window

private func calcNewItemDeleteWindow(_ playerNum: UInt8) {
    let pi = GetPlayerInfoEntry(Int32(playerNum))

    // CALC LEFT SIDE OF WINDOW

    var temp = Float(gCurrentSuperTileCol[Int(playerNum)]) * gTerrainSuperTileUnitSize // convert to unit coords
    pi.pointee.itemDeleteWindow.left = temp

    // CALC RIGHT SIDE OF WINDOW

    temp += Float(gSuperTileActiveRange * 2) * gTerrainSuperTileUnitSize // calc offset to right side (SUPERTILE_DIST_WIDE)
    pi.pointee.itemDeleteWindow.right = temp

    // CALC FAR SIDE OF WINDOW

    temp = Float(gCurrentSuperTileRow[Int(playerNum)]) * gTerrainSuperTileUnitSize // convert to unit coords
    pi.pointee.itemDeleteWindow.top = temp

    // CALC NEAR SIDE OF WINDOW

    temp += Float(gSuperTileActiveRange * 2) * gTerrainSuperTileUnitSize // calc offset to bottom side (SUPERTILE_DIST_DEEP)
    pi.pointee.itemDeleteWindow.bottom = temp
}

// MARK: -

// MARK: - Calculate split mode matrix

func CalculateSplitModeMatrix() {
    gMapSplitMode = alloc2DArray(UInt8.self, rows: Int(gTerrainTileDepth), cols: Int(gTerrainTileWidth)) // alloc 2D array

    for row in 0..<Int(gTerrainTileDepth) {
        for col in 0..<Int(gTerrainTileWidth) {
            // GET Y COORDS OF 4 VERTICES

            let y0 = gMapYCoords[row]![col]
            let y1 = gMapYCoords[row]![col + 1]
            let y2 = gMapYCoords[row + 1]![col + 1]
            let y3 = gMapYCoords[row + 1]![col]

            // QUICK CHECK FOR FLAT POLYS

            if (y0 == y1) && (y0 == y2) && (y0 == y3) { // see if all same level
                gMapSplitMode[row]![col] = UInt8(SPLIT_BACKWARD)
            }

            // CALC FOLD-SPLIT
            else {
                if fabsf(y0 - y2) < fabsf(y1 - y3) {
                    gMapSplitMode[row]![col] = UInt8(SPLIT_BACKWARD) // use \ splits
                } else {
                    gMapSplitMode[row]![col] = UInt8(SPLIT_FORWARD) // use / splits
                }
            }
        }
    }
}
