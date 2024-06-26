//
// sobjtypes.h
//


enum
{
	ATLAS_GROUP_NULL				=	0,
	ATLAS_GROUP_FONT1				,
	ATLAS_GROUP_FONT2				,
	ATLAS_GROUP_FONT3				,
	MAX_ATLASES
};

enum
{
	SPRITE_GROUP_NULL				=	0,
	SPRITE_GROUP_SPHEREMAPS 		,
	SPRITE_GROUP_INFOBAR			,
	SPRITE_GROUP_CURSOR				,
	SPRITE_GROUP_PARTICLES			,
	SPRITE_GROUP_GLOBAL				,
	SPRITE_GROUP_LEVELSPECIFIC		,
	SPRITE_GROUP_OVERHEADMAP		,
	SPRITE_GROUP_P2SKIN				,
	MAX_SPRITE_GROUPS
};

		/* GLOBAL SPRITES */

enum
{
	GLOBAL_SObjType_Shadow_Circular,
	GLOBAL_SObjType_Shadow_CircularDark,
	GLOBAL_SObjType_Shadow_Square,
	GLOBAL_SObjType_Shadow_Nano,
	GLOBAL_SObjType_WaterRipple,
	GLOBAL_SObjType_GreenWater,
	GLOBAL_SObjType_BlueWater,
	GLOBAL_SObjType_LavaWater,
	GLOBAL_SObjType_LaserOrbBeam,
	GLOBAL_SObjType_COUNT,

};





		/* SPHEREMAP SPRITES */

enum
{
	SPHEREMAP_SObjType_Satin,
	SPHEREMAP_SObjType_Sea,
	SPHEREMAP_SObjType_DarkDusk,
	SPHEREMAP_SObjType_Medow,
	SPHEREMAP_SObjType_Sheen,
	SPHEREMAP_SObjType_DarkYosemite,
	SPHEREMAP_SObjType_Red,
	SPHEREMAP_SObjType_Tundra,
	SPHEREMAP_SObjType_SheenAlpha,
	SPHEREMAP_SObjType_COUNT,
};



		/* PARTICLE SPRITES */

enum
{
	PARTICLE_SObjType_WhiteSpark,
	PARTICLE_SObjType_WhiteSpark2,
	PARTICLE_SObjType_WhiteSpark3,
	PARTICLE_SObjType_WhiteSpark4,
	PARTICLE_SObjType_WhiteGlow,

	PARTICLE_SObjType_RedGlint,
	PARTICLE_SObjType_GreenGlint,
	PARTICLE_SObjType_BlueGlint,
	PARTICLE_SObjType_YellowGlint,

	PARTICLE_SObjType_RedSpark,
	PARTICLE_SObjType_GreenSpark,
	PARTICLE_SObjType_BlueSpark,

	PARTICLE_SObjType_GreySmoke,
	PARTICLE_SObjType_BlackSmoke,
	PARTICLE_SObjType_RedFumes,
	PARTICLE_SObjType_GreenFumes,
	PARTICLE_SObjType_CokeSpray,

	PARTICLE_SObjType_Splash,
	PARTICLE_SObjType_SnowFlakes,
	PARTICLE_SObjType_Fire,
	PARTICLE_SObjType_Bubble,
	PARTICLE_SObjType_SwampDirt,

	PARTICLE_SObjType_Confetti_Birch,
	PARTICLE_SObjType_Confetti_Pine,
	PARTICLE_SObjType_Confetti_NanoFlesh,

	PARTICLE_SObjType_LensFlare0,
	PARTICLE_SObjType_LensFlare1,
	PARTICLE_SObjType_LensFlare2,
	PARTICLE_SObjType_LensFlare3,

	PARTICLE_SObjType_ZapBeam,

	PARTICLE_SObjType_GasCloud,

	PARTICLE_SObjType_Flame0,
	PARTICLE_SObjType_Flame1,
	PARTICLE_SObjType_Flame2,
	PARTICLE_SObjType_Flame3,
	PARTICLE_SObjType_Flame4,
	PARTICLE_SObjType_Flame5,
	PARTICLE_SObjType_Flame6,
	PARTICLE_SObjType_Flame7,
	PARTICLE_SObjType_Flame8,
	PARTICLE_SObjType_Flame9,
	PARTICLE_SObjType_Flame10,

	PARTICLE_SObjType_FireRing,
	PARTICLE_SObjType_COUNT,

};


/******************* INFOBAR SOBJTYPES *************************/

enum
{
	INFOBAR_SObjType_0,
	INFOBAR_SObjType_1,
	INFOBAR_SObjType_2,
	INFOBAR_SObjType_3,
	INFOBAR_SObjType_4,
	INFOBAR_SObjType_5,
	INFOBAR_SObjType_6,
	INFOBAR_SObjType_7,
	INFOBAR_SObjType_8,
	INFOBAR_SObjType_9,
	INFOBAR_SObjType_SSBar,

	INFOBAR_SObjType_Life,

	INFOBAR_SObjType_SmallBlankEgg,
	INFOBAR_SObjType_SmallRedEgg,
	INFOBAR_SObjType_SmallGreenEgg,
	INFOBAR_SObjType_SmallBlueEgg,
	INFOBAR_SObjType_SmallYellowEgg,
	INFOBAR_SObjType_SmallPurpleEgg,
	INFOBAR_SObjType_SmallBlankEggRed,

	INFOBAR_SObjType_WeaponFrame,
	INFOBAR_SObjType_WeaponShadow,
	INFOBAR_SObjType_Blaster,
	INFOBAR_SObjType_ClusterShot,
	INFOBAR_SObjType_HeatSeeker,
	INFOBAR_SObjType_SonicWave,
	INFOBAR_SObjType_Bomb,

	INFOBAR_SObjType_GunSight_Normal,
	INFOBAR_SObjType_GunSight_OuterRing,
	INFOBAR_SObjType_GunSight_Pointer,
	INFOBAR_SObjType_GunSight_Locked,

	INFOBAR_SObjType_Player1,
	INFOBAR_SObjType_Player2,
	INFOBAR_SObjType_YouWin,
	INFOBAR_SObjType_YouLose,
	INFOBAR_SObjType_YouDraw,
	INFOBAR_SObjType_Ready,
	INFOBAR_SObjType_Set,
	INFOBAR_SObjType_Go,
	INFOBAR_SObjType_Place1,
	INFOBAR_SObjType_Place2,
	INFOBAR_SObjType_Lap1,
	INFOBAR_SObjType_Lap2,
	INFOBAR_SObjType_Lap3,
	INFOBAR_SObjType_WrongWay,
	INFOBAR_SObjType_Lap2Message,
	INFOBAR_SObjType_FinalLapMessage,

	INFOBAR_SObjType_MapFrame,
	INFOBAR_SObjType_MapGlass,
	INFOBAR_SObjType_MapMask,
	INFOBAR_SObjType_MapLines,

	INFOBAR_SObjType_HealthRed,
	INFOBAR_SObjType_FuelRed,
	INFOBAR_SObjType_ShieldRed,

	INFOBAR_SObjType_HealthFrame,
	INFOBAR_SObjType_HealthShine,
	INFOBAR_SObjType_CircleShadow,

	INFOBAR_SObjType_FuelFrame,
	INFOBAR_SObjType_ShieldFrame,

	INFOBAR_SObjType_Loading,

	INFOBAR_SObjType_SmallEggHalo,

	INFOBAR_SObjType_LeftArrow,
	INFOBAR_SObjType_RightArrow,

	INFOBAR_SObjType_COUNT
};


/******************* BIOME SPECIFIC *************************/

enum
{
	LEVEL1_SObjType_Fence_BlockEnemy,
	LEVEL1_SObjType_Fence_PineTree,
};

enum
{
	LEVEL2_SObjType_Fence_BlockEnemy,
	LEVEL2_SObjType_DustDevil,
};

enum
{
	LEVEL3_SObjType_Fence_BlockEnemy,
};

/***************** MAIN MENU *************************/

enum
{
	MAINMENU_SObjType_NanoLogo
};







