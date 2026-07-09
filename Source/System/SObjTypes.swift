// SObjTypes.swift - Native Swift constants that used to be plain
// (non-typedef'd) C enum constants declared in sobjtypes.h. Converted once
// nothing in the remaining C code touched them (verified 2026-07-07: zero
// references in any .c/.cpp file). The ATLAS_GROUP_* and SPRITE_GROUP_*
// blocks stay in sobjtypes.h - ATLAS_GROUP_FONT1/FONT2 are used directly in
// Source/System/Menu.c and Source/Screens/Settings.c, and
// MAX_SPRITE_GROUPS sizes real extern-global arrays in
// Source/3D/Sprites.c.
//
// These stay as loose global constants (not a Swift enum) since the
// original C enums were anonymous/unnamed - callers already treat them as
// plain Int index values, not as cases of a closed set.

let GLOBAL_SObjType_Shadow_Circular: Int = 0
let GLOBAL_SObjType_Shadow_CircularDark: Int = 1
let GLOBAL_SObjType_Shadow_Square: Int = 2
let GLOBAL_SObjType_Shadow_Nano: Int = 3
let GLOBAL_SObjType_WaterRipple: Int = 4
let GLOBAL_SObjType_GreenWater: Int = 5
let GLOBAL_SObjType_BlueWater: Int = 6
let GLOBAL_SObjType_LavaWater: Int = 7
let GLOBAL_SObjType_LaserOrbBeam: Int = 8
let GLOBAL_SObjType_COUNT: Int = 9

let SPHEREMAP_SObjType_Satin: Int = 0
let SPHEREMAP_SObjType_Sea: Int = 1
let SPHEREMAP_SObjType_DarkDusk: Int = 2
let SPHEREMAP_SObjType_Medow: Int = 3
let SPHEREMAP_SObjType_Sheen: Int = 4
let SPHEREMAP_SObjType_DarkYosemite: Int = 5
let SPHEREMAP_SObjType_Red: Int = 6
let SPHEREMAP_SObjType_Tundra: Int = 7
let SPHEREMAP_SObjType_SheenAlpha: Int = 8
let SPHEREMAP_SObjType_COUNT: Int = 9

let PARTICLE_SObjType_WhiteSpark: Int = 0
let PARTICLE_SObjType_WhiteSpark2: Int = 1
let PARTICLE_SObjType_WhiteSpark3: Int = 2
let PARTICLE_SObjType_WhiteSpark4: Int = 3
let PARTICLE_SObjType_WhiteGlow: Int = 4
let PARTICLE_SObjType_RedGlint: Int = 5
let PARTICLE_SObjType_GreenGlint: Int = 6
let PARTICLE_SObjType_BlueGlint: Int = 7
let PARTICLE_SObjType_YellowGlint: Int = 8
let PARTICLE_SObjType_RedSpark: Int = 9
let PARTICLE_SObjType_GreenSpark: Int = 10
let PARTICLE_SObjType_BlueSpark: Int = 11
let PARTICLE_SObjType_GreySmoke: Int = 12
let PARTICLE_SObjType_BlackSmoke: Int = 13
let PARTICLE_SObjType_RedFumes: Int = 14
let PARTICLE_SObjType_GreenFumes: Int = 15
let PARTICLE_SObjType_CokeSpray: Int = 16
let PARTICLE_SObjType_Splash: Int = 17
let PARTICLE_SObjType_SnowFlakes: Int = 18
let PARTICLE_SObjType_Fire: Int = 19
let PARTICLE_SObjType_Bubble: Int = 20
let PARTICLE_SObjType_SwampDirt: Int = 21
let PARTICLE_SObjType_Confetti_Birch: Int = 22
let PARTICLE_SObjType_Confetti_Pine: Int = 23
let PARTICLE_SObjType_Confetti_NanoFlesh: Int = 24
let PARTICLE_SObjType_LensFlare0: Int = 25
let PARTICLE_SObjType_LensFlare1: Int = 26
let PARTICLE_SObjType_LensFlare2: Int = 27
let PARTICLE_SObjType_LensFlare3: Int = 28
let PARTICLE_SObjType_ZapBeam: Int = 29
let PARTICLE_SObjType_GasCloud: Int = 30
let PARTICLE_SObjType_Flame0: Int = 31
let PARTICLE_SObjType_Flame1: Int = 32
let PARTICLE_SObjType_Flame2: Int = 33
let PARTICLE_SObjType_Flame3: Int = 34
let PARTICLE_SObjType_Flame4: Int = 35
let PARTICLE_SObjType_Flame5: Int = 36
let PARTICLE_SObjType_Flame6: Int = 37
let PARTICLE_SObjType_Flame7: Int = 38
let PARTICLE_SObjType_Flame8: Int = 39
let PARTICLE_SObjType_Flame9: Int = 40
let PARTICLE_SObjType_Flame10: Int = 41
let PARTICLE_SObjType_FireRing: Int = 42
let PARTICLE_SObjType_COUNT: Int = 43

let INFOBAR_SObjType_0: Int = 0
let INFOBAR_SObjType_1: Int = 1
let INFOBAR_SObjType_2: Int = 2
let INFOBAR_SObjType_3: Int = 3
let INFOBAR_SObjType_4: Int = 4
let INFOBAR_SObjType_5: Int = 5
let INFOBAR_SObjType_6: Int = 6
let INFOBAR_SObjType_7: Int = 7
let INFOBAR_SObjType_8: Int = 8
let INFOBAR_SObjType_9: Int = 9
let INFOBAR_SObjType_SSBar: Int = 10
let INFOBAR_SObjType_Life: Int = 11
let INFOBAR_SObjType_SmallBlankEgg: Int = 12
let INFOBAR_SObjType_SmallRedEgg: Int = 13
let INFOBAR_SObjType_SmallGreenEgg: Int = 14
let INFOBAR_SObjType_SmallBlueEgg: Int = 15
let INFOBAR_SObjType_SmallYellowEgg: Int = 16
let INFOBAR_SObjType_SmallPurpleEgg: Int = 17
let INFOBAR_SObjType_SmallBlankEggRed: Int = 18
let INFOBAR_SObjType_WeaponFrame: Int = 19
let INFOBAR_SObjType_WeaponShadow: Int = 20
let INFOBAR_SObjType_Blaster: Int = 21
let INFOBAR_SObjType_ClusterShot: Int = 22
let INFOBAR_SObjType_HeatSeeker: Int = 23
let INFOBAR_SObjType_SonicWave: Int = 24
let INFOBAR_SObjType_Bomb: Int = 25
let INFOBAR_SObjType_GunSight_Normal: Int = 26
let INFOBAR_SObjType_GunSight_OuterRing: Int = 27
let INFOBAR_SObjType_GunSight_Pointer: Int = 28
let INFOBAR_SObjType_GunSight_Locked: Int = 29
let INFOBAR_SObjType_Player1: Int = 30
let INFOBAR_SObjType_Player2: Int = 31
let INFOBAR_SObjType_YouWin: Int = 32
let INFOBAR_SObjType_YouLose: Int = 33
let INFOBAR_SObjType_YouDraw: Int = 34
let INFOBAR_SObjType_Ready: Int = 35
let INFOBAR_SObjType_Set: Int = 36
let INFOBAR_SObjType_Go: Int = 37
let INFOBAR_SObjType_Place1: Int = 38
let INFOBAR_SObjType_Place2: Int = 39
let INFOBAR_SObjType_Lap1: Int = 40
let INFOBAR_SObjType_Lap2: Int = 41
let INFOBAR_SObjType_Lap3: Int = 42
let INFOBAR_SObjType_WrongWay: Int = 43
let INFOBAR_SObjType_Lap2Message: Int = 44
let INFOBAR_SObjType_FinalLapMessage: Int = 45
let INFOBAR_SObjType_MapFrame: Int = 46
let INFOBAR_SObjType_MapGlass: Int = 47
let INFOBAR_SObjType_MapMask: Int = 48
let INFOBAR_SObjType_MapLines: Int = 49
let INFOBAR_SObjType_HealthRed: Int = 50
let INFOBAR_SObjType_FuelRed: Int = 51
let INFOBAR_SObjType_ShieldRed: Int = 52
let INFOBAR_SObjType_HealthFrame: Int = 53
let INFOBAR_SObjType_HealthShine: Int = 54
let INFOBAR_SObjType_CircleShadow: Int = 55
let INFOBAR_SObjType_FuelFrame: Int = 56
let INFOBAR_SObjType_ShieldFrame: Int = 57
let INFOBAR_SObjType_Loading: Int = 58
let INFOBAR_SObjType_SmallEggHalo: Int = 59
let INFOBAR_SObjType_LeftArrow: Int = 60
let INFOBAR_SObjType_RightArrow: Int = 61
let INFOBAR_SObjType_COUNT: Int = 62

let LEVEL1_SObjType_Fence_BlockEnemy: Int = 0
let LEVEL1_SObjType_Fence_PineTree: Int = 1

let LEVEL2_SObjType_Fence_BlockEnemy: Int = 0
let LEVEL2_SObjType_DustDevil: Int = 1

let LEVEL3_SObjType_Fence_BlockEnemy: Int = 0

let MAINMENU_SObjType_NanoLogo: Int = 0
