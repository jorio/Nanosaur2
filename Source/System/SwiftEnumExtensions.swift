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

// MARK: - ParticleType (effects.h)

extension ParticleType: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [ParticleType] = [.fallingSparks, .gravitoids]
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

// MARK: - ShadowType / WhatType (objects.h)

extension ShadowType: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [ShadowType] = [.circular, .balsaPlane, .circularDark, .square]
}

extension WhatType: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [WhatType] = [.undefined, .electrode, .eggWormhole, .egg, .hole]
}

// MARK: - ShardMode (shards.h)

extension ShardMode: @retroactive Sendable {}

// MARK: - PlayerDeathType / PlayerAnim / PlayerJoint / WeaponType (player.h)

extension PlayerDeathType: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [PlayerDeathType] = [.explode, .deathDive]
}

extension PlayerAnim: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [PlayerAnim] = [.flap, .bankLeft, .bankRight, .deathDive, .appearWormhole, .readyToGrab, .flapWithEgg, .bankLeftEgg, .bankRightEgg, .enterWormhole, .disoriented, .dustDevil, .coasting]
}

extension PlayerJoint: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [PlayerJoint] = [.leftArmpit, .rightArmpit, .leftFoot, .rightFoot, .rightWing3, .rightWingtip, .leftWing3, .leftWingtip, .head, .jaw, .eggHold]
}

extension WeaponType: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [WeaponType] = [.none, .blaster, .clusterShot, .heatSeeker, .sonicScream, .bomb] // NUM_WEAPON_TYPES (_count) intentionally excluded
}

// MARK: - SkeletonType / AnimDirection / AnimEventKind / AccelerationMode (skeleton.h)

extension SkeletonType: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [SkeletonType] = [.player, .wormhole, .raptor, .bonusWormhole, .brach, .worm, .ramphor] // MAX_SKELETON_TYPES (_count) intentionally excluded
}

extension AnimDirection: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [AnimDirection] = [.forward, .backward]
}

extension AnimEventKind: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [AnimEventKind] = [.stop, .loop, .zigzag, .gotoMarker, .setMarker, .playSound, .setFlag, .clearFlag, .pause]
}

extension AccelerationMode: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [AccelerationMode] = [.linear, .easeInOut, .easeIn, .easeOut]
}

// MARK: - WaterType (water.h)

extension WaterType: @retroactive Sendable, @retroactive CaseIterable {
    public static let allCases: [WaterType] = [.green, .blue, .lava, .lavaDir0, .lavaDir1, .lavaDir2, .lavaDir3, .lavaDir4, .lavaDir5, .lavaDir6, .lavaDir7] // NUM_WATER_TYPES (_count) intentionally excluded
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
