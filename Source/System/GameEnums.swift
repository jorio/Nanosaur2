// GameEnums.swift - Native Swift enums that used to be C enums declared with
// SWIFT_ENUM_CLOSED in various headers. Converted once nothing in the
// remaining C code touched them (directly, via a struct field embedded in a
// header parsed by every .c file through game.h, or via a static inline C
// function) — see project memory for the full verification methodology.
//
// Each `_count`/`NUM_X`/`MAX_X` sentinel case from the original C enum was
// dropped; use `EnumName.allCases.count` instead (CaseIterable is
// auto-derived for these plain, no-payload enums, so this just works).

enum DialogMessage: Int32, CaseIterable {
    case needsnailshell = 0
    case gotsnailshell
    case findscarecrowhead
    case putscarecrowhead
    case attachedscarecrowhead
    case findmarble
    case bowlmarble
    case donebowling
    case chipmunkMap4acorn
    case chipmunkCheckpoint4acorn
    case chipmunkMousetrap
    case chipmunkThanks
    case chipmunkCheckpoint
    case poolwater
    case smashberries
    case squishmore
    case squishdone
    case doghouse
    case gotfleas
    case gotticks
    case happydog
    case rememberdog
    case plumbingintro
    case slotcar
    case rescuemice
    case rescuemice2
    case micesaved
    case slotcarplayerwon
    case slotcartryagain
    case dopuzzle
    case donepuzzle
    case bombhills
    case bombhills2
    case hillsdone
    case mothball
    case silicondoor
    case getredclovers
    case gotredclovers
    case gofishing
    case morefish
    case thanksfish
    case getfood
    case morefood
    case thanksfood
    case getkindling
    case morekindling
    case lightfire
    case enterhive
    case bottlekey
    case micedrown
    case thanksnodrown
    case glider
    case sodacan
}

enum ParticleType: Int32, CaseIterable {
    case fallingSparks
    case gravitoids
}

enum AnimDirection: Int32, CaseIterable {
    case forward
    case backward
}

enum AnimEventKind: Int32, CaseIterable {
    case stop
    case loop
    case zigzag
    case gotoMarker
    case setMarker
    case playSound
    case setFlag
    case clearFlag
    case pause
}

enum AccelerationMode: Int32, CaseIterable {
    case linear
    case easeInOut
    case easeIn
    case easeOut
}

enum PowType: Int32, CaseIterable {
    case stunPulse
    case health
    case jumpJet
    case fuel
    case supernova
    case freeze
    case magnet
    case growth
    case flame
    case flare
    case dart
    case freeLife
}

enum WaterType: Int32, CaseIterable {
    case green = 0
    case blue
    case lava
    case lavaDir0
    case lavaDir1
    case lavaDir2
    case lavaDir3
    case lavaDir4
    case lavaDir5
    case lavaDir6
    case lavaDir7
}

enum ShadowType: UInt32, CaseIterable {
    case circular
    case balsaPlane
    case circularDark
    case square
}

enum WhatType: Int32, CaseIterable {
    case undefined = 0
    case electrode
    case eggWormhole
    case egg
    case hole
}

enum PlayerDeathType: Int32, CaseIterable {
    case explode
    case deathDive
}

enum PlayerAnim: UInt32, CaseIterable {
    case flap
    case bankLeft
    case bankRight
    case deathDive
    case appearWormhole
    case readyToGrab
    case flapWithEgg
    case bankLeftEgg
    case bankRightEgg
    case enterWormhole
    case disoriented
    case dustDevil
    case coasting
}

enum PlayerJoint: Int32, CaseIterable {
    case leftArmpit = 1
    case rightArmpit = 2
    case leftFoot = 8
    case rightFoot = 11
    case rightWing3 = 13
    case rightWingtip = 16
    case leftWing3 = 18
    case leftWingtip = 21
    case head = 23
    case jaw = 24
    case eggHold = 27
}

enum LevelNum: Int16, CaseIterable {
    case adventure1
    case adventure2
    case adventure3
    case race1
    case race2
    case battle1
    case battle2
    case flag1
    case flag2
}

