//
// sobjtypes.h
//


enum
{
	SPRITE_GROUP_SPHEREMAPS 		= 	0,
	SPRITE_GROUP_INFOBAR			=	1,
	SPRITE_GROUP_PARTICLES			=	3,
	SPRITE_GROUP_INTROSTORY			=	4,
	SPRITE_GROUP_MAINMENU			=	4,
	SPRITE_GROUP_GLOBAL				= 	5,
	SPRITE_GROUP_FONT				= 	6,
	SPRITE_GROUP_LEVELSPECIFIC		= 	7,
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

	GLOBAL_SObjType_Player2Skin,

	GLOBAL_SObjType_LaserOrbBeam

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
	SPHEREMAP_SObjType_SheenAlpha
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

	PARTICLE_SObjType_FireRing

};


/******************* DIALOG SOBJTYPES *************************/

enum
{
	FONT_SObjType_Comma,
	FONT_SObjType_Dash,
	FONT_SObjType_Period,
	FONT_SObjType_ExclamationMark,
	FONT_SObjType_Apostrophe,
	FONT_SObjType_Ampersand,

	FONT_SObjType_UU,
	FONT_SObjType_OO,
	FONT_SObjType_AA,
	FONT_SObjType_AO,
	FONT_SObjType_NN,
	FONT_SObjType_EE,
	FONT_SObjType_Ax,
	FONT_SObjType_Ox,
	FONT_SObjType_Oa,
	FONT_SObjType_beta,

	FONT_SObjType_0,
	FONT_SObjType_1,
	FONT_SObjType_2,
	FONT_SObjType_3,
	FONT_SObjType_4,
	FONT_SObjType_5,
	FONT_SObjType_6,
	FONT_SObjType_7,
	FONT_SObjType_8,
	FONT_SObjType_9,

	FONT_SObjType_A,
	FONT_SObjType_B,
	FONT_SObjType_C,
	FONT_SObjType_D,
	FONT_SObjType_E,
	FONT_SObjType_F,
	FONT_SObjType_G,
	FONT_SObjType_H,
	FONT_SObjType_I,
	FONT_SObjType_J,
	FONT_SObjType_K,
	FONT_SObjType_L,
	FONT_SObjType_M,
	FONT_SObjType_N,
	FONT_SObjType_O,
	FONT_SObjType_P,
	FONT_SObjType_Q,
	FONT_SObjType_R,
	FONT_SObjType_S,
	FONT_SObjType_T,
	FONT_SObjType_U,
	FONT_SObjType_V,
	FONT_SObjType_W,
	FONT_SObjType_X,
	FONT_SObjType_Y,
	FONT_SObjType_Z,

	FONT_SObjType_BackArrow,

	FONT_SObjType_BoxCursor,
	FONT_SObjType_ArrowCursor
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
	INFOBAR_SObjType_GameOver,
	INFOBAR_SObjType_EnterWormhole,

	INFOBAR_SObjType_LeftArrow,
	INFOBAR_SObjType_RightArrow
};


/******************* LEVEL 1 *************************/

enum
{
	LEVEL1_SObjType_Fence_PineTree,
	LEVEL1_SObjType_OHM,
	LEVEL1_SObjType_BattleOHM,
	LEVEL1_SObjType_FlagOHM
};


/******************* LEVEL 2 *************************/

enum
{
	LEVEL2_SObjType_DustDevil,
	LEVEL2_SObjType_OHM,
	LEVEL2_SObjType_Race2OHM,
	LEVEL2_SObjType_Battle2OHM
};

/******************* LEVEL 3 *************************/

enum
{
	LEVEL3_SObjType_OHM,
	LEVEL3_SObjType_RaceOHM,
	LEVEL3_SObjType_FlagOHM
};



/***************** MAIN MENU *************************/

enum
{
	MAINMENU_SObjType_Credits,

	MAINMENU_SObjType_SaveIcon,
	MAINMENU_SObjType_NoSaveIcon,
	MAINMENU_SObjType_PressAnyKey,

	MAINMENU_SObjType_NanoLogo

};







