// GameEngine.swift - central owner of the game's Swift-side mutable state.
//
// The C port left ~400 file-scope globals behind; they are migrating into
// this class one subsystem per commit, following the same incremental
// discipline as the original port. Globals still defined in C stubs for
// C-ABI reasons (gGamePrefs in Main.c, gMetalMode in BootGlobals.c, ...)
// cannot move and stay where they are.

final class GameEngine {
    /// Active rendering backend. GL by default; SwMetalBackend_Activate
    /// swaps in the Metal backend under --metal during draw-context
    /// creation, before any drawing happens.
    var renderer: RenderBackend = GLRenderBackend()

    /// Object system: master ObjNode list, per-move coord/delta scratch,
    /// autofade settings, slot storage (see Objects.swift).
    let objects = ObjectSystem()

    /// Player state for both players (see Player.swift).
    let player = PlayerSystem()

    /// Collision-detection scratch (see Collision.swift).
    let collision = CollisionSystem()

    /// Terrain, terrain splines, fences, and water (see Source/Terrain/).
    let terrain = TerrainSystem()
    let splines = SplineSystem()
    let fences = FenceSystem()
    let water = WaterSystem()

    /// Effect pools (see Source/Effects/ and Items/Electrodes+DustDevil).
    let shards = ShardSystem()
    let particles = ParticleSystem()
    let confetti = ConfettiSystem()
    let contrails = ContrailSystem()
    let sparkles = SparkleSystem()
    let zaps = ZapSystem()
    let dustDevils = DustDevilSystem()

    /// 3D support systems.
    let camera = CameraSystem()
    let bones = BoneSystem()
    let bg3d = BG3DSystem()
    let metaObjects = MetaObjectSystem()

    /// Sound and input.
    let sound = SoundSystem()
    let input = InputSystem()

    /// App/session-level systems.
    let game = GameState()
    let misc = MiscSystem()
    let window = WindowSystem()
    let levelFile = LevelFileScratch()
    let localization = LocalizationSystem()
    let menu = MenuSystem()
    let twitches = TwitchSystem()
    let fs = FSSystem()
    let atlases = AtlasSystem()
    let sprites = SpriteSystem()

    /// Frame timing - directly on the engine: it's the hottest read in
    /// the game (nearly every move callback starts with it).
    var framesPerSecond: Float = 13
    var framesPerSecondFrac: Float = 1.0 / 13

    /// Gameplay domains.
    let enemies = EnemySystem()
    let items = ItemSystem()
    let skeletons = SkeletonSystem()
    let metalBackend = MetalBackendHolder()
}

/// The single engine instance. A plain global (not dependency injection)
/// because hundreds of C-shaped call sites and @convention(c) move/draw
/// callbacks have no way to carry a context parameter.
let gEngine = GameEngine()
