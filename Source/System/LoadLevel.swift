// LoadLevel.swift - Port of LoadLevel.c to Swift

private let kLevelBiomes: [LevelNum: Biome] = [
    .adventure1: .forest,
    .adventure2: .desert,
    .adventure3: .swamp,
    .race1: .swamp,
    .race2: .desert,
    .battle1: .forest,
    .battle2: .desert,
    .flag1: .swamp,
    .flag2: .forest,
]

private let kLevelNames: [LevelNum: String] = [
    .adventure1: "level1",
    .adventure2: "level2",
    .adventure3: "level3",
    .race1: "race1",
    .race2: "race2",
    .battle1: "battle1",
    .battle2: "battle2",
    .flag1: "flag1",
    .flag2: "flag2",
]

private let kBiomeNames: [Biome: String] = [
    .forest: "forest",
    .desert: "desert",
    .swamp: "swamp",
]

func GetLevelBiome(_ levelNum: Int16) -> Biome {
    kLevelBiomes[LevelNum(rawValue: levelNum)!]!
}

func GetLevelName(_ levelNum: Int16) -> String {
    kLevelNames[LevelNum(rawValue: levelNum)!]!
}

func GetBiomeName(_ biome: Biome) -> String {
    kBiomeNames[biome]!
}

func LoadLevelArt() {
    let currentBiome = GetLevelBiome(gEngine.game.levelNum)

    var timeStartLoad = UnsignedWide()
    SwMicroseconds(&timeStartLoad)

    gEngine.screens.loadingThermoPercent = 0

    gEngine.renderer.setClearColor(0, 0, 0) // clear to black for loading screen

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
        let path = ":Models:\(GetBiomeName(currentBiome)).bg3d"
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

    LoadSpriteGroupFromFiles(Int32(SPRITE_GROUP_LEVELSPECIFIC), levelSpecificSpritePaths)

    // LOAD OVERHEAD MAP
    do {
        let path = ":Sprites:maps:\(GetLevelName(gEngine.game.levelNum))"
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
        let path = ":Terrain:\(GetLevelName(gEngine.game.levelNum)).ter"
        _ = ResolveDataFileSpec(path, &spec)
        LoadPlayfield(&spec)
    }

    // RESTORE CLEAR COLOR

    let cc = gEngine.game.viewInfoPtr!.pointee.clearColor
    gEngine.renderer.setClearColor(cc.r, cc.g, cc.b)

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
    SwMicroseconds(&timeEndLoad)

    SwLog("\(#function): \((timeEndLoad.lo - timeStartLoad.lo) / 1000) ms")
}
