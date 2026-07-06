// LoadLevel.swift - Port of LoadLevel.c to Swift
// The level/biome lookup tables stay in LoadLevel.c; see LoadLevelInternal.h.

func LoadLevelArt() {
    let currentBiome = GetLevelBiome(Int32(gLevelNum))

    var timeStartLoad = UnsignedWide()
    Microseconds(&timeStartLoad)

    gLoadingThermoPercent = 0

    glClearColor(0, 0, 0, 0) // clear to black for loading screen

    // LOAD GLOBAL BG3D GEOMETRY

    var spec = FSSpec()

    _ = ResolveDataFileSpec(":Models:global.bg3d", &spec)
    ImportBG3D(&spec, Int32(MODEL_GROUP_GLOBAL), Int16(VertexArrayRangeType.bg3dModels.rawValue))

    _ = ResolveDataFileSpec(":Models:playerparts.bg3d", &spec)
    ImportBG3D(&spec, Int32(MODEL_GROUP_PLAYER), Int16(VertexArrayRangeType.bg3dModels.rawValue))

    _ = ResolveDataFileSpec(":Models:weapons.bg3d", &spec)
    ImportBG3D(&spec, Int32(MODEL_GROUP_WEAPONS), Int16(VertexArrayRangeType.bg3dModels.rawValue))

    BG3D_SphereMapGeomteryMaterial(Int16(MODEL_GROUP_PLAYER), Int16(PLAYER_ObjType_JetPack),
                                    -1, UInt16(MULTI_TEXTURE_COMBINE_ADD), UInt16(SPHEREMAP_SObjType_Satin))

    // LOAD LEVEL SPECIFIC BG3D GEOMETRY

    do {
        let path = ":Models:\(String(cString: GetBiomeName(currentBiome))).bg3d"
        _ = ResolveDataFileSpec(path, &spec)
        ImportBG3D(&spec, Int32(MODEL_GROUP_LEVELSPECIFIC), Int16(VertexArrayRangeType.bg3dModels.rawValue))
    }

    for (i, _) in EggColor.allCases.enumerated() {
        BG3D_SphereMapGeomteryMaterial(Int16(MODEL_GROUP_GLOBAL), Int16(GLOBAL_ObjType_RedEgg) + Int16(i),
                                        -1, UInt16(MULTI_TEXTURE_COMBINE_ADD), UInt16(SPHEREMAP_SObjType_Satin))
    }

    BG3D_SphereMapGeomteryMaterial(Int16(MODEL_GROUP_GLOBAL), Int16(GLOBAL_ObjType_TowerTurret_Lens),
                                    -1, UInt16(MULTI_TEXTURE_COMBINE_ADD), UInt16(SPHEREMAP_SObjType_Sheen))

    // LOAD SPRITES

    var levelSpecificSpritePaths: [String] = [":Sprites:textures:blockenemy"]

    switch currentBiome {
    case .forest:
        levelSpecificSpritePaths.append(":Sprites:textures:pinefence")
    case .desert:
        levelSpecificSpritePaths.append(":Sprites:textures:dustdevil")
    default:
        break
    }

    var levelSpecificSpritePathsCStrings = levelSpecificSpritePaths.map { strdup($0)! }
    levelSpecificSpritePathsCStrings.withUnsafeMutableBufferPointer { buf -> Void in
        buf.withMemoryRebound(to: UnsafePointer<CChar>.self) { cbuf in
            LoadSpriteGroupFromFiles(Int32(SPRITE_GROUP_LEVELSPECIFIC), Int32(cbuf.count), cbuf.baseAddress!)
        }
    }
    for p in levelSpecificSpritePathsCStrings { free(p) }

    // LOAD OVERHEAD MAP
    do {
        let path = ":Sprites:maps:\(String(cString: GetLevelName(Int32(gLevelNum))))"
        _ = ResolveDataFileSpec(path, &spec)
        LoadSpriteGroupFromFile(Int32(SPRITE_GROUP_OVERHEADMAP), path, 0)
    }

    // DRAW THE LOADING TEXT AND THERMO

    DrawLoading(0)

    // LOAD SKELETONS

    LoadASkeleton(UInt8(SkeletonType.player.rawValue))
    LoadASkeleton(UInt8(SkeletonType.raptor.rawValue))
    LoadASkeleton(UInt8(SkeletonType.brach.rawValue))

    LoadASkeleton(UInt8(SkeletonType.wormhole.rawValue))

    // LOAD TERRAIN

    do {
        let path = ":Terrain:\(String(cString: GetLevelName(Int32(gLevelNum)))).ter"
        _ = ResolveDataFileSpec(path, &spec)
        LoadPlayfield(&spec)
    }

    // RESTORE CLEAR COLOR

    let cc = gGameViewInfoPtr!.pointee.clearColor
    glClearColor(cc.r, cc.g, cc.b, 1.0)

    // DO BIOME SPECIFIC STUFF

    switch currentBiome {
    case .forest: // LEVEL_NUM_ADVENTURE1, LEVEL_NUM_BATTLE1, LEVEL_NUM_FLAG2
        BG3D_SphereMapGeomteryMaterial(Int16(MODEL_GROUP_LEVELSPECIFIC), Int16(LEVEL1_ObjType_AirMine_Mine),
                                        -1, UInt16(MULTI_TEXTURE_COMBINE_ADD), UInt16(SPHEREMAP_SObjType_Satin))

    case .desert: // LEVEL_NUM_ADVENTURE2, LEVEL_NUM_RACE2, LEVEL_NUM_BATTLE2
        BG3D_SphereMapGeomteryMaterial(Int16(MODEL_GROUP_LEVELSPECIFIC), Int16(LEVEL2_ObjType_AirMine_Mine),
                                        -1, UInt16(MULTI_TEXTURE_COMBINE_ADD), UInt16(SPHEREMAP_SObjType_Satin))

        BG3D_SphereMapGeomteryMaterial(Int16(MODEL_GROUP_LEVELSPECIFIC), Int16(LEVEL2_ObjType_Crystal1),
                                        -1, UInt16(MULTI_TEXTURE_COMBINE_ADD), UInt16(SPHEREMAP_SObjType_Sheen))

    case .swamp: // LEVEL_NUM_ADVENTURE3, LEVEL_NUM_RACE1, LEVEL_NUM_FLAG1
        LoadASkeleton(UInt8(SkeletonType.worm.rawValue))
        LoadASkeleton(UInt8(SkeletonType.ramphor.rawValue))

    default:
        break
    }

    var timeEndLoad = UnsignedWide()
    Microseconds(&timeEndLoad)

    SwLog("\(#function): \((timeEndLoad.lo - timeStartLoad.lo) / 1000) ms")
}
