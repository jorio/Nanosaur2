// SwiftEnumExtensions.swift - Sendable + CaseIterable conformances for the
// project's SWIFT_ENUM_CLOSED/SWIFT_FLAG_ENUM C enums.
//
// CaseIterable.allCases is always a hand-written array literal, never
// derived from a `_count`/sentinel case - those sentinel cases exist for
// the ORIGINAL C code's array sizing and must never appear in `allCases`.
// The leading underscore on `_count`-named cases (see e.g. WeaponType)
// is a naming-convention signal that it's a sizing sentinel, not a real
// case - avoid referencing it from Swift; there's no compiler enforcement
// of this, so it relies on code review.
//
// DialogMessage/ParticleType/AnimDirection/AnimEventKind/AccelerationMode/
// PowType/WaterType/ShadowType/WhatType/PlayerDeathType/PlayerAnim/
// PlayerJoint are now plain Swift enums in GameEnums.swift with real
// CaseIterable conformance auto-derived by the compiler - no manual
// extension needed for those anymore.

// MARK: - MenuState / MouseState (MenuInternal.h)

extension MenuState: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [MenuState] = [.off, .fadeIn, .ready, .fadeOut, .awaitingKeyPress, .awaitingPadPress, .awaitingMouseClick]
}

extension MouseState: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [MouseState] = [.off, .wandering, .hovering, .grabbing]
}

// MARK: - CameraMode (camera.h)

extension CameraMode: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [CameraMode] = [.normal, .firstPerson, .anaglyphClose]
}

// MARK: - Biome / VSMode (main.h)

extension Biome: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [Biome] = [.forest, .desert, .swamp] // NUM_BIOMES (_count) intentionally excluded
}

extension VSMode: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [VSMode] = [.none, .race, .battle, .captureTheFlag]
}

// MARK: - MetaObjectType (metaobjects.h)

extension MetaObjectType: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [MetaObjectType] = [.group, .geometry, .material, .matrix, .picture, .sprite]
}

// MARK: - MenuItemType (menu.h)

extension MenuItemType: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [MenuItemType] = [.sentinel, .pick, .label, .spacer, .cycler1, .cycler2, .slider, .keyBinding, .padBinding, .mouseBinding, .fileSlot] // kMI_COUNT (_count) intentionally excluded
}

// MARK: - ShardMode (shards.h)

extension ShardMode: @retroactive Sendable {}

// MARK: - WeaponType (player.h)

extension WeaponType: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [WeaponType] = [.none, .blaster, .clusterShot, .heatSeeker, .sonicScream, .bomb] // NUM_WEAPON_TYPES (_count) intentionally excluded
}

// MARK: - SkeletonType (skeleton.h)

extension SkeletonType: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [SkeletonType] = [.player, .wormhole, .raptor, .bonusWormhole, .brach, .worm, .ramphor] // MAX_SKELETON_TYPES (_count) intentionally excluded
}

// MARK: - EggColor (items.h)

extension EggColor: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [EggColor] = [.red, .green, .blue, .yellow, .purple] // NUM_EGG_TYPES (_count) intentionally excluded
}

// MARK: - EnemyKind (enemy.h)

extension EnemyKind: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [EnemyKind] = [.raptor, .brach, .ramphor] // NUM_ENEMY_KINDS (_count) intentionally excluded
}

// MARK: - LevelNum (main.h)

extension LevelNum: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [LevelNum] = [.adventure1, .adventure2, .adventure3, .race1, .race2, .battle1, .battle2, .flag1, .flag2] // NUM_LEVELS (_count) intentionally excluded
}

// MARK: - SplitscreenMode (ogl_support.h)

extension SplitscreenMode: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [SplitscreenMode] = [.none, .horizontal, .vertical] // NUM_SPLITSCREEN_MODES (_count) intentionally excluded
}

// MARK: - VertexArrayRangeType (ogl_support.h)

extension VertexArrayRangeType: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [VertexArrayRangeType] = [.particles1, .particles2, .terrain, .bg3dModels, .skeletons, .skeletons2, .contrails1, .contrails2, .zaps1, .zaps2, .user1, .userFences, .userFences2, .userWater, .userDustDevil] // NUM_VERTEX_ARRAY_RANGES (_count) intentionally excluded
}

// MARK: - StereoGlassesMode (ogl_support.h)

extension StereoGlassesMode: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [StereoGlassesMode] = [.off, .anaglyphColor, .anaglyphMono, .shutter]
}
