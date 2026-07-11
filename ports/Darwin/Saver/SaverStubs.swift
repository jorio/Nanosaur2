// SaverStubs.swift - minimal stand-ins for engine subsystems the screen
// saver does not compile (ports/Darwin). GameEngine.swift instantiates one
// object per subsystem; for the subsystems whose real source files are
// gameplay-sized (player, terrain, enemies, sound, menus...), the saver
// build swaps in these state-only shells instead. Each stub carries ONLY
// the fields that files actually compiled into the saver reference; if a
// newly added engine file needs more, add the field here rather than
// pulling in the whole gameplay file.
//
// Compiled ONLY by ports/Darwin's CMakeLists (never globbed by the desktop
// build), and guarded anyway for safety:

#if NANOSAUR_SCREENSAVER

// MARK: - gEngine subsystem shells (see GameEngine.swift)

final class PlayerSystem {
    var numPlayers: UInt8 = 1
}

final class CollisionSystem {}

final class TerrainSystem {
    // Read by Particles.swift's generic particle update (ground bounce);
    // zero polygonSize means "no terrain" paths behave inertly.
    var polygonSize: Float = 0
    var recentTerrainNormal = OGLVector3D()
}
final class SplineSystem {}
final class FenceSystem {}
final class WaterSystem {}
final class ShardSystem {}
final class ConfettiSystem {}
final class ContrailSystem {}
final class ZapSystem {}
final class DustDevilSystem {}
final class EnemySystem {}
final class ItemSystem {}
final class SoundSystem {}
final class MenuSystem {}

final class InputSystem {
    var userPrefersGamepad: UInt8 = 0
    var cursorCoord = OGLPoint2D()
}

// Main.swift's GameState, minus the fields only Main.swift itself touches.
final class GameState {
    var vsMode: VSMode = .none

    var viewInfoPtr: UnsafeMutablePointer<OGLSetupOutputType>!
    var frameNum: UInt32 = 0
    var levelNum: Int16 = 0
    var debugMode: UInt8 = 0
    var autoFadeStatusBits: UInt32 = 0
    var timeDemo: UInt8 = 0
    var gameOver: UInt8 = 0
    var levelCompleted: UInt8 = 0
    var playingFromSavedGame: UInt8 = 0
    var skipLevelIntro: UInt8 = 0
    var raceReadySetGoTimer: Float = 0
    var prefsFolderVRefNum: Int16 = 0
    var prefsFolderDirID: Int = 0
    var worldSunDirection = OGLVector3D()
}

// MiscScreens.swift's ScreenSystem, trimmed to what the wormhole scene and
// the shared draw path read.
final class ScreenSystem {
    var gamePaused: UInt8 = 0
    var wormholeDeformPoints = [OGLPoint3D](repeating: OGLPoint3D(), count: 30)
    var introMode: UInt8 = 0
}

// MARK: - No-op sound layer
//
// Sound.swift isn't compiled (SDL audio streams); these are the sound
// calls reachable from the compiled subset. All safe no-ops in a saver.

func FadeSound(_ ratio: Float) {}
func KillSong() {}
func StopAllEffectChannels() {}

// MARK: - No-op input layer (Input.swift isn't compiled; the system ends
// the saver on any input, so the engine never needs to poll anything)

func DoSDLMaintenance() {}
func GrabMouse(_ capture: UInt8) {}

// MARK: - No-op sound channel + terrain queries
//
// Objects.swift's generic move/delete paths reference these; the wormhole
// scene has no terrain, no water, no splines, and no effect channels
// (EffectChannel stays -1), so all of them are dead at runtime here.

func StopAChannel(_ channelNum: UnsafeMutablePointer<Int16>!) {}
func TrackTerrainItem(_ theNode: UnsafeMutablePointer<ObjNode>!) -> UInt8 { 0 }
func RotateOnTerrain(_ theNode: UnsafeMutablePointer<ObjNode>!, _ yOffset: Float, _ surfaceNormal: UnsafeMutablePointer<OGLVector3D>?) {}
func GetTerrainY(_ x: Float, _ z: Float) -> Float { 0 }
func GetWaterY(_ x: Float, _ z: Float, _ y: UnsafeMutablePointer<Float>) -> UInt8 { 0 }
func RemoveFromSplineObjectList(_ theNode: UnsafeMutablePointer<ObjNode>!) -> UInt8 { 0 }

// MARK: - Prefs
//
// File.swift's LoadPrefs falls back to InitDefaultPrefs (Main.swift, not
// compiled) when the prefs file is missing/invalid. The saver never calls
// LoadPrefs - Nanosaur2Saver_Boot sets the few fields the subset reads.

func InitDefaultPrefs() {}

// MARK: - Quit-path no-ops (CleanQuit in Misc.swift; a saver never quits
// the process itself, and has no terrain or sound to dispose)

func DisposeTerrain() {}
func ShutdownSound() {}
func UpdateListenerLocation() {}

// MARK: - Gameplay queries reachable from Particles.swift's generic paths
// (no terrain/water/collision/players exist in the saver scene)

@discardableResult
func PlayEffect_Parms3D(_ effectNum: Int16, _ where_: UnsafeMutablePointer<OGLPoint3D>!, _ rateMultiplier: UInt32, _ volumeAdjust: Float) -> Int16 { -1 }
func CreateNewRipple(_ where_: UnsafePointer<OGLPoint3D>, _ baseScale: Float, _ scaleSpeed: Float, _ fadeRate: Float) {}
func FindHighestCollisionAtXZ(_ x: Float, _ z: Float, _ cType: UInt32) -> Float { -10_000_000 }
func DoSimpleBoxCollisionAgainstObject(_ top: Float, _ bottom: Float, _ left: Float, _ right: Float, _ front: Float, _ back: Float, _ targetNode: UnsafeMutablePointer<ObjNode>!) -> UInt8 { 0 }

// One zeroed player-info entry (Player.swift isn't compiled). The scene
// never sets any of it; readers see inert defaults.
private let gStubPlayerInfo: UnsafeMutablePointer<PlayerInfoType> = {
    let p = UnsafeMutablePointer<PlayerInfoType>.allocate(capacity: Int(MAX_PLAYERS))
    p.initialize(repeating: PlayerInfoType(), count: Int(MAX_PLAYERS))
    return p
}()

func GetPlayerInfoEntry(_ i: Int32) -> UnsafeMutablePointer<PlayerInfoType> { gStubPlayerInfo + Int(i) }
func GetPlayerIsDead(_ i: Int32) -> UInt8 { 0 }

#endif // NANOSAUR_SCREENSAVER
