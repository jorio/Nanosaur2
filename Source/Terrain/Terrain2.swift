// Terrain2.swift - Port of Terrain2.c to Swift
//
// gEngine.terrain.numTerrainItems, gEngine.terrain.masterItemList, gEngine.terrain.mapYCoords, gEngine.terrain.mapYCoordsOriginal,
// gEngine.terrain.mapSplitMode, gEngine.terrain.superTileItemIndexGrid, gEngine.terrain.numLineMarkers, and
// gLineMarkerList stay defined in Terrain.c (which already holds the rest
// of the shared terrain globals): many other already-ported and
// still-unported files read/write them directly via `extern`.

// AddCrystal/Bushes.swift's/Trees.swift's/etc. Add* routines are all
// TerrainItemEntryType methods, not @convention(c) free functions, so they
// don't fit the table's uniform element type directly - wrap each one in a
// thin @convention(c) closure.

private let nilAdd: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { _, _, _ in
    0
}

private let cAddGrass: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addGrass(x: x, z: z)
}
private let cAddFern: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addFern(x: x, z: z)
}
private let cAddBerryBush: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addBerryBush(x: x, z: z)
}
private let cAddCatTail: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addCatTail(x: x, z: z)
}
private let cAddDesertBush: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addDesertBush(x: x, z: z)
}
private let cAddCactus: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addCactus(x: x, z: z)
}
private let cAddPalmBush: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addPalmBush(x: x, z: z)
}
private let cAddGeckoPlant: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addGeckoPlant(x: x, z: z)
}
private let cAddSproutPlant: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addSproutPlant(x: x, z: z)
}
private let cAddIvy: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addIvy(x: x, z: z)
}
private let cAddBirchTree: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addBirchTree(x: x, z: z)
}
private let cAddPineTree: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addPineTree(x: x, z: z)
}
private let cAddEgg: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addEgg(x: x, z: z)
}
private let cAddEggWormhole: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addEggWormhole(x: x, z: z)
}
private let cAddTowerTurret: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addTowerTurret(x: x, z: z)
}
private let cAddWeaponPOW: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addWeaponPOW(x: x, z: z)
}
private let cAddSmallTree: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addSmallTree(x: x, z: z)
}
private let cAddFallenTree: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addFallenTree(x: x, z: z)
}
private let cAddTreeStump: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addTreeStump(x: x, z: z)
}
private let cAddRock: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addRock(x: x, z: z)
}
private let cAddEnemyRaptor: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addEnemyRaptor(x: x, z: z)
}
private let cAddDustDevil: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addDustDevil(x: x, z: z)
}
private let cAddAirMine: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addAirMine(x: x, z: z)
}
private let cAddForestDoor: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addForestDoor(x: x, z: z)
}
private let cAddForestDoorKey: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addForestDoorKey(x: x, z: z)
}
private let cAddElectrode: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addElectrode(x: x, z: z)
}
private let cAddHealthPOW: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addHealthPOW(x: x, z: z)
}
private let cAddFuelPOW: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addFuelPOW(x: x, z: z)
}
private let cAddRiverRock: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addRiverRock(x: x, z: z)
}
private let cAddGasMound: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addGasMound(x: x, z: z)
}
private let cAddBentPineTree: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addBentPineTree(x: x, z: z)
}
private let cAddEnemyBrach: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addEnemyBrach(x: x, z: z)
}
private let cAddDesertTree: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addDesertTree(x: x, z: z)
}
private let cAddCrystal: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addCrystal(x: x, z: z)
}
private let cAddPalmTree: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addPalmTree(x: x, z: z)
}
private let cAddLaserOrb: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addLaserOrb(x: x, z: z)
}
private let cAddShieldPOW: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addShieldPOW(x: x, z: z)
}
private let cAddSmoker: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addSmoker(x: x, z: z)
}
private let cAddFlame: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addFlame(x: x, z: z)
}
private let cAddBurntDesertTree: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addBurntDesertTree(x: x, z: z)
}
private let cAddHydraTree: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addHydraTree(x: x, z: z)
}
private let cAddOddTree: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addOddTree(x: x, z: z)
}
private let cAddAsteroid: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addAsteroid(x: x, z: z)
}
private let cAddSwampFallenTree: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addSwampFallenTree(x: x, z: z)
}
private let cAddSwampStump: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addSwampStump(x: x, z: z)
}
private let cAddHole: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addHole(x: x, z: z)
}
private let cAddFreeLifePOW: @convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8 = { itemPtr, x, z in
    itemPtr!.addFreeLifePOW(x: x, z: z)
}

private let maxItemNum = 48 // for error checking!

private let gTerrainItemAddRoutines: [(@convention(c) (UnsafeMutablePointer<TerrainItemEntryType>?, Float, Float) -> UInt8)] = [
    nilAdd, // My Start Coords
    cAddBirchTree,
    cAddPineTree,
    cAddEgg,
    cAddEggWormhole,
    cAddTowerTurret,
    cAddWeaponPOW,
    cAddSmallTree,
    cAddFallenTree,
    cAddTreeStump,
    cAddGrass,
    cAddFern,
    cAddBerryBush,
    cAddCatTail,
    cAddRock,
    cAddEnemyRaptor,
    cAddDustDevil, // 16
    cAddAirMine, // 17: air mine
    cAddForestDoor,
    cAddForestDoorKey,
    cAddElectrode,
    cAddHealthPOW,
    cAddFuelPOW,
    cAddRiverRock,
    cAddGasMound,
    cAddBentPineTree,
    cAddEnemyBrach, // 26:
    cAddDesertTree, // 27
    cAddDesertBush,
    cAddCactus,
    cAddCrystal,
    cAddPalmTree,
    cAddLaserOrb, // 32
    cAddShieldPOW,
    cAddSmoker,
    cAddFlame,
    cAddPalmBush, // 36: palm bush
    cAddBurntDesertTree,
    cAddHydraTree,
    cAddOddTree,
    cAddGeckoPlant,
    cAddSproutPlant,
    cAddIvy,
    cAddAsteroid,
    cAddSwampFallenTree,
    cAddSwampStump,
    cAddHole, // 46: hole worms
    cAddFreeLifePOW,
    nilAdd, // 48: Ramphor enemy
]

// MARK: - Build terrain item list
//
// This takes the input item list and resorts it according to supertile grid number
// such that the items on any supertile are all sequential in the list instead of scattered.

func BuildTerrainItemList() {
    // ALLOC MEMORY FOR SUPERTILE ITEM INDEX GRID

    gEngine.terrain.superTileItemIndexGrid = alloc2DArray(SuperTileItemIndexType.self, rows: Int(gEngine.terrain.numSuperTilesDeep), cols: Int(gEngine.terrain.numSuperTilesWide))

    if gEngine.terrain.numTerrainItems == 0 {
        SwFatal("BuildTerrainItemList: there must be at least 1 terrain item!")
    }

    // ALLOC MEMORY FOR NEW LIST

    guard let tempItemList = AllocPtrClear(MemoryLayout<TerrainItemEntryType>.size * Int(gEngine.terrain.numTerrainItems))?.assumingMemoryBound(to: TerrainItemEntryType.self) else {
        SwFatal("BuildTerrainItemList: AllocPtr failed!")
        return
    }

    let srcList = gEngine.terrain.masterItemList!
    let newList = tempItemList

    // SCAN ALL SUPERTILES

    var total = 0

    for row in 0..<Int(gEngine.terrain.numSuperTilesDeep) {
        for col in 0..<Int(gEngine.terrain.numSuperTilesWide) {
            gEngine.terrain.superTileItemIndexGrid[row]![col].numItems = 0 // no items on this supertile yet

            // FIND ALL ITEMS ON THIS SUPERTILE

            for i in 0..<Int(gEngine.terrain.numTerrainItems) {
                var itemX = Int(srcList[i].x) // get pixel coords of item
                var itemZ = Int(srcList[i].y)

                itemX /= Int(gEngine.terrain.superTileUnitSize) // convert to supertile row
                itemZ /= Int(gEngine.terrain.superTileUnitSize) // convert to supertile column

                if itemX == col && itemZ == row { // see if its on this supertile
                    if gEngine.terrain.superTileItemIndexGrid[row]![col].numItems == 0 { // see if this is the 1st item
                        gEngine.terrain.superTileItemIndexGrid[row]![col].itemIndex = UInt16(total) // set starting index
                    }

                    newList[total] = srcList[i] // copy into new list

                    // PRE-CALC THE TERRAIN Y FOR THIS ITEM

                    newList[total].terrainY = GetTerrainY(Float(newList[total].x), Float(newList[total].y))

                    // INC

                    total += 1 // inc counter
                    gEngine.terrain.superTileItemIndexGrid[row]![col].numItems += 1 // inc # items on this supertile
                } else if itemX > col { // since original list is sorted, we can know when we are past the usable edge
                    break
                }
            }
        }
    }

    // NUKE THE ORIGINAL ITEM LIST AND REASSIGN TO THE NEW SORTED LIST

    SafeDisposePtr(UnsafeMutableRawPointer(gEngine.terrain.masterItemList)) // nuke old list
    gEngine.terrain.masterItemList = tempItemList // reassign

    // DO SOME ITEM INITIALIZATION

    findPlayerStartCoordItems() // look thru items for my start coords

    FindAllEggItems()
}

// MARK: - Find player start coord item
//
// Scans thru item list for item type #14 which is a teleport reciever / start coord,

private func findPlayerStartCoordItems() {
    var flags = [Bool](repeating: false, count: Int(MAX_PLAYERS))

    let itemPtr = gEngine.terrain.masterItemList! // get pointer to data inside the LOCKED handle

    // SCAN FOR "START COORD" ITEM

    for i in 0..<Int(gEngine.terrain.numTerrainItems) {
        if itemPtr[i].type == UInt16(MAP_ITEM_MYSTARTCOORD) { // see if it's a MyStartCoord item
            // CHECK FOR BIT INFO

            let p = Int(itemPtr[i].parm.0) // player # is in parm 0

            if p >= Int(MAX_PLAYERS) { // skip illegal player #'s
                continue
            }

            let pi = GetPlayerInfoEntry(Int32(p))
            pi.pointee.coord.x = Float(itemPtr[i].x)
            pi.pointee.startX = Int32(itemPtr[i].x)
            pi.pointee.coord.z = Float(itemPtr[i].y)
            pi.pointee.startZ = Int32(itemPtr[i].y)
            pi.pointee.startRotY = Float(itemPtr[i].parm.1) * (SwPI2 / 8.0) // calc starting rotation aim

            if flags[p] { // if we already got a coord for this player then err
                SwFatal("FindPlayerStartCoordItems:  duplicate start item for player #n")
            }
            flags[p] = true
        }
    }
}

// MARK: -

// MARK: - Add terrain items on supertile
//
// Called by DoPlayerTerrainUpdate() per each supertile needed.
// This scans all of the items on this supertile and attempts to add them.

func AddTerrainItemsOnSuperTile(_ row: Int, _ col: Int) {
    let numItems = Int(gEngine.terrain.superTileItemIndexGrid[row]![col].numItems) // see how many items are on this supertile
    if numItems == 0 {
        return
    }

    let startIndex = Int(gEngine.terrain.superTileItemIndexGrid[row]![col].itemIndex) // get starting index into item list
    let itemPtr = gEngine.terrain.masterItemList! + startIndex // get pointer to 1st item on this supertile

    // SCAN ALL ITEMS UNDER HERE

    for i in 0..<numItems {
        if itemPtr[i].flags & UInt16(ITEM_FLAGS_INUSE) != 0 { // see if item available
            continue
        }

        let x = Float(itemPtr[i].x) // get item coords
        let z = Float(itemPtr[i].y)

        if SeeIfCoordsOutOfRange(x, z) != 0 { // only add if this supertile is active by player
            continue
        }

        let type = Int(itemPtr[i].type) // get item #
        if type > maxItemNum { // error check!
            SwFatal("Illegal Map Item Type \(type)!")
        }

        let flag = gTerrainItemAddRoutines[type](&itemPtr[i], itemPtr[i].x.toFloat, itemPtr[i].y.toFloat) // call item's ADD routine
        if flag != 0 {
            itemPtr[i].flags |= UInt16(ITEM_FLAGS_INUSE) // set in-use flag
        }
    }
}

private extension UInt32 {
    var toFloat: Float { Float(self) }
}

// MARK: - Track terrain item
//
// Returns true if theNode is out of range

func TrackTerrainItem(_ theNode: UnsafeMutablePointer<ObjNode>!) -> UInt8 {
    if theNode.hasStatus(STATUS_BIT_DONTPURGE) { // see if non-purgable
        return 0
    }

    return SeeIfCoordsOutOfRange(theNode.pointee.Coord.x, theNode.pointee.Coord.z) // see if out of range of all players
}

// MARK: - See if coords out of range
//
// Returns true if the given x/z coords are outside the item delete
// window of any of the players.

func SeeIfCoordsOutOfRange(_ x: Float, _ z: Float) -> UInt8 {
    // SEE IF OUT OF RANGE

    if x < 0 || z < 0 {
        return 1
    }
    if x >= Float(gEngine.terrain.unitWidth) || z >= Float(gEngine.terrain.unitDepth) {
        return 1
    }

    // SEE IF A PLAYER USES THIS SUPERTILE

    let col = Int(x * gEngine.terrain.superTileUnitSizeFrac) // calc supertile relative row/col that the coord lies on
    let row = Int(z * gEngine.terrain.superTileUnitSizeFrac)

    if gEngine.terrain.superTileStatusGrid[row]![col].playerHereFlags != 0 { // if a player is using this supertile, then coords are in range
        return 0
    } else {
        return 1 // otherwise, out of range since no players can see this supertile
    }
}

// MARK: - Rotate on terrain
//
// Rotates an object's x & z such that it's lying on the terrain.
//
// INPUT: surfaceNormal == optional input normal to use.

func RotateOnTerrain(_ theNode: UnsafeMutablePointer<ObjNode>!, _ yOffset: Float, _ surfaceNormal: UnsafeMutablePointer<OGLVector3D>?) {
    var up = OGLVector3D()
    var to = OGLPoint3D()
    var m2 = OGLMatrix4x4()

    // GET CENTER Y COORD & TERRAIN NORMAL

    let x = theNode.pointee.Coord.x
    let z = theNode.pointee.Coord.z
    let y = GetTerrainY(x, z) + yOffset
    theNode.pointee.Coord.y = y

    if let surfaceNormal {
        up = surfaceNormal.pointee
    } else {
        up = gEngine.terrain.recentTerrainNormal
    }

    // CALC "TO" COORD

    let r = theNode.pointee.Rot.y
    to.x = x + sin(r) * -30.0
    to.z = z + cos(r) * -30.0
    to.y = GetTerrainY(to.x, to.z) + yOffset

    // CREATE THE MATRIX

    SetLookAtMatrix(&theNode.pointee.BaseTransformMatrix, &up, &theNode.pointee.Coord, &to)

    // POP IN THE TRANSLATE INTO THE MATRIX

    setMatValue(&theNode.pointee.BaseTransformMatrix, M03, x)
    setMatValue(&theNode.pointee.BaseTransformMatrix, M13, y)
    setMatValue(&theNode.pointee.BaseTransformMatrix, M23, z)

    // SET SCALE

    m2.setScale(theNode.pointee.Scale.x, // make scale matrix
                theNode.pointee.Scale.y,
                theNode.pointee.Scale.z)
    var result = OGLMatrix4x4()
    result = m2.multiplied(by: theNode.pointee.BaseTransformMatrix)
    theNode.pointee.BaseTransformMatrix = result
}

// MARK: - Rotate on terrain: wide area
//
// Same as above except it averages normals around the center.

func RotateOnTerrain_WideArea(_ theNode: UnsafeMutablePointer<ObjNode>!, _ yOffset: Float, _ radius: Float) {
    // GET CENTER Y COORD & TERRAIN NORMAL

    let x = theNode.pointee.Coord.x
    let z = theNode.pointee.Coord.z
    _ = GetTerrainY(x, z)
    var up = gEngine.terrain.recentTerrainNormal

    // AVERAGE IN THE RADIAL NORMALS

    var r: Float = 0
    while r < SwPI2 {
        // float x2 = x + sin(r) * radius;
        // float z2 = z + cos(r) * radius;

        _ = GetTerrainY(x, z)
        up.x += gEngine.terrain.recentTerrainNormal.x
        up.y += gEngine.terrain.recentTerrainNormal.y
        up.z += gEngine.terrain.recentTerrainNormal.z

        r += Float.pi / 8
    }
    up = up.normalized()

    RotateOnTerrain(theNode, yOffset, &up)
}

// MARK: ======= TERRAIN PRE-CONSTRUCTION =========

// MARK: - Calc tile normals
//
// Given a row, col coord, calculate the face normals for the 2 triangles.

func CalcTileNormals(_ row: Int, _ col: Int, _ n1: UnsafeMutablePointer<OGLVector3D>!, _ n2: UnsafeMutablePointer<OGLVector3D>!) {
    var p1 = OGLPoint3D(x: 0, y: 0, z: 0)
    var p2 = OGLPoint3D(x: 0, y: 0, z: 0)
    var p3 = OGLPoint3D(x: 0, y: 0, z: 0)
    var p4 = OGLPoint3D(x: 0, y: 0, z: 0)

    p2.z = gEngine.terrain.polygonSize
    p3.x = gEngine.terrain.polygonSize
    p3.z = gEngine.terrain.polygonSize
    p4.x = gEngine.terrain.polygonSize

    // MAKE SURE ROW/COL IS IN RANGE

    if row >= Int(gEngine.terrain.tileDepth) || row < 0 || col >= Int(gEngine.terrain.tileWidth) || col < 0 {
        n1.pointee.x = 0 // pass back up vector by default since our of range
        n2.pointee.x = 0
        n1.pointee.y = 1
        n2.pointee.y = 1
        n1.pointee.z = 0
        n2.pointee.z = 0
        return
    }

    p1.y = gEngine.terrain.mapYCoords[row]![col] // far left
    p2.y = gEngine.terrain.mapYCoords[row + 1]![col] // near left
    p3.y = gEngine.terrain.mapYCoords[row + 1]![col + 1] // near right
    p4.y = gEngine.terrain.mapYCoords[row]![col + 1] // far right

    // CALC NORMALS BASED ON SPLIT

    if gEngine.terrain.mapSplitMode[row]![col] == UInt8(SPLIT_BACKWARD) {
        CalcFaceNormal(&p2, &p3, &p1, n1) // fl, nl, nr
        CalcFaceNormal(&p3, &p4, &p1, n2) // fl, nr, fr
    } else {
        CalcFaceNormal(&p4, &p1, &p2, n1) // fl, nl, fr
        CalcFaceNormal(&p3, &p4, &p2, n2) // fr, nl, nr
    }
}

// MARK: - Calc tile normals: not normalized
//
// Given a row, col coord, calculate the face normals for the 2 triangles.

func CalcTileNormals_NotNormalized(_ row: Int, _ col: Int, _ n1: UnsafeMutablePointer<OGLVector3D>!, _ n2: UnsafeMutablePointer<OGLVector3D>!) {
    var p1 = OGLPoint3D(x: 0, y: 0, z: 0)
    var p2 = OGLPoint3D(x: 0, y: 0, z: 0)
    var p3 = OGLPoint3D(x: 0, y: 0, z: 0)
    var p4 = OGLPoint3D(x: 0, y: 0, z: 0)

    p2.z = gEngine.terrain.polygonSize
    p3.x = gEngine.terrain.polygonSize
    p3.z = gEngine.terrain.polygonSize
    p4.x = gEngine.terrain.polygonSize

    // MAKE SURE ROW/COL IS IN RANGE

    if row >= Int(gEngine.terrain.tileDepth) || row < 0 || col >= Int(gEngine.terrain.tileWidth) || col < 0 {
        n1.pointee.x = 0 // pass back up vector by default since our of range
        n2.pointee.x = 0
        n1.pointee.y = 1
        n2.pointee.y = 1
        n1.pointee.z = 0
        n2.pointee.z = 0
        return
    }

    p1.y = gEngine.terrain.mapYCoords[row]![col] // far left
    p2.y = gEngine.terrain.mapYCoords[row + 1]![col] // near left
    p3.y = gEngine.terrain.mapYCoords[row + 1]![col + 1] // near right
    p4.y = gEngine.terrain.mapYCoords[row]![col + 1] // far right

    // CALC NORMALS BASED ON SPLIT

    if gEngine.terrain.mapSplitMode[row]![col] == UInt8(SPLIT_BACKWARD) {
        CalcFaceNormal_NotNormalized(&p2, &p3, &p1, n1) // fl, nl, nr
        CalcFaceNormal_NotNormalized(&p3, &p4, &p1, n2) // fl, nr, fr
    } else {
        CalcFaceNormal_NotNormalized(&p4, &p1, &p2, n1) // fl, nl, fr
        CalcFaceNormal_NotNormalized(&p3, &p4, &p2, n2) // fr, nl, nr
    }
}

// MARK: -

// MARK: - Do item shadow casting
//
// Scans thru item list and casts a shadown onto the terrain
// by darkening the vertex colors of the terrain.

func DoItemShadowCasting() {
    let up = OGLVector3D(x: 0, y: 1, z: 0)
    let shadeFactor: Float = 0.7

    // INIT SHADING GRID

    gEngine.terrain.vertexShading = alloc2DArray(Float.self, rows: Int(gEngine.terrain.tileDepth) + 1, cols: Int(gEngine.terrain.tileWidth) + 1) // alloc 2D array for map
    for row in 0...Int(gEngine.terrain.tileDepth) {
        for col in 0...Int(gEngine.terrain.tileWidth) {
            gEngine.terrain.vertexShading[row]![col] = 1.0
        }
    }

    // INIT SHADOW FLAGS TEMP BUFFER

    let shadowFlags = alloc2DArray(UInt8.self, rows: Int(gEngine.terrain.tileDepth) + 1, cols: Int(gEngine.terrain.tileWidth) + 1)

    for row in 0...Int(gEngine.terrain.tileDepth) {
        for col in 0...Int(gEngine.terrain.tileWidth) {
            shadowFlags[row]![col] = 0
        }
    }

    // GET MAIN LIGHT VECTOR INFO

    var lightVector = OGLVector2D(x: gEngine.game.viewInfoPtr!.pointee.lightList.fillDirection.0.x, y: gEngine.game.viewInfoPtr!.pointee.lightList.fillDirection.0.z)
    var lightVectorNorm = OGLVector2D()
    OGLVector2D_Normalize(&lightVector, &lightVectorNorm)
    lightVector = lightVectorNorm

    let upVar = up
    let fillDir = gEngine.game.viewInfoPtr!.pointee.lightList.fillDirection.0
    var dot = upVar.dot(fillDir)
    dot = 1.0 - dot

    // SCAN THRU ITEM LIST

    for i in 0..<Int(gEngine.terrain.numTerrainItems) {
        // SEE WHICH THINGS WE SUPPORT & GET PARMS

        let height: Float
        switch gEngine.terrain.masterItemList![i].type {
        case 1: // birch
            height = 1000

        case 2: // pine
            height = 1000

        default:
            continue
        }

        // CALCULATE LINE TO DRAW SHADOW ALONG

        var from = OGLPoint2D(x: Float(gEngine.terrain.masterItemList![i].x), y: Float(gEngine.terrain.masterItemList![i].y))
        var to = OGLPoint2D(x: from.x + lightVector.x * (height * dot), y: from.y + lightVector.y * (height * dot))

        let length = OGLPoint2D_Distance(&from, &to)

        // SCAN ALONG LIGHT AND SHADE VERTICES

        var t: Float = 1.0
        while t > 0.0 {
            let oneMinusT = 1.0 - t

            let x = (from.x * oneMinusT) + (to.x * t) // calc center x
            let z = (from.y * oneMinusT) + (to.y * t)

            var ro: Float = -0.5
            while ro <= 0.5 {
                var co: Float = -0.5
                while co <= 0.5 {
                    let row = Int(z / gEngine.terrain.polygonSize + ro) // calc row/col
                    let col = Int(x / gEngine.terrain.polygonSize + co)

                    if row < 0 || col < 0 { // check for out of bounds
                        co += 0.5
                        continue
                    }
                    if row >= Int(gEngine.terrain.tileDepth) || col >= Int(gEngine.terrain.tileWidth) {
                        co += 0.5
                        continue
                    }

                    if shadowFlags[row]![col] != 0 { // see if this already shadowed
                        co += 0.5
                        continue
                    }

                    shadowFlags[row]![col] = 1 // set flag

                    gEngine.terrain.vertexShading[row]![col] = shadeFactor // set shading

                    co += 0.5
                } // co
                ro += 0.5
            } // ro

            t -= 1.0 / (length / gEngine.terrain.polygonSize)
        }
    }

    // CLEANUP

    free2DArray(shadowFlags)
}

// MARK: -

// MARK: ====== LINE MARKERS =========

// MARK: - See if crossed line marker

func SeeIfCrossedLineMarker(_ theNode: UnsafeMutablePointer<ObjNode>!, _ whichLine: UnsafeMutablePointer<Int>!) -> UInt8 {
    // GET PLAYER'S MOVEMENT LINE SEGMENT

    let fromX = theNode.pointee.OldCoord.x
    let fromZ = theNode.pointee.OldCoord.z
    let toX = gEngine.objects.coord.x
    let toZ = gEngine.objects.coord.z

    // SEE IF CROSSED ANY LINE MARKERS

    for c in 0..<Int(gEngine.terrain.numLineMarkers) {
        var intersectX: Float = 0
        var intersectZ: Float = 0

        let marker = GetLineMarkerPtr(Int32(c))
        let x1 = marker.pointee.x.0 // get endpoints of line marker
        let z1 = marker.pointee.z.0
        let x2 = marker.pointee.x.1
        let z2 = marker.pointee.z.1

        if IntersectLineSegments(fromX, fromZ, toX, toZ, x1, z1, x2, z2, &intersectX, &intersectZ) != 0 {
            whichLine.pointee = c
            return 1
        }
    }

    // NOTHING

    whichLine.pointee = -1
    return 0
}
