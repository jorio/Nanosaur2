//
// mobjtypes.h
//

#ifndef __MOBJT
#define __MOBJT

enum
{
	MODEL_GROUP_GLOBAL		=	0,
	MODEL_GROUP_LEVELSPECIFIC =	1,
	MODEL_GROUP_LEVELINTRO =	2,
	MODEL_GROUP_WEAPONS		 = 	3,
	MODEL_GROUP_PLAYER		 = 	4,

	MODEL_GROUP_SKELETONBASE				// skeleton files' models are attached here
};




/******************* GLOBAL *************************/

enum
{
	GLOBAL_ObjType_WaterSpat,
	GLOBAL_ObjType_ShockwaveRing,

	GLOBAL_ObjType_RedEgg,
	GLOBAL_ObjType_GreenEgg,
	GLOBAL_ObjType_BlueEgg,
	GLOBAL_ObjType_YellowEgg,
	GLOBAL_ObjType_PurpleEgg,
	GLOBAL_ObjType_Nest,
	GLOBAL_ObjType_EggBeam,

	GLOBAL_ObjType_POWFrame,
	GLOBAL_ObjType_HealthPOWFrame,
	GLOBAL_ObjType_HealthPOWMembrane,
	GLOBAL_ObjType_FuelPOWMembrane,
	GLOBAL_ObjType_ShieldPOWMembrane,
	GLOBAL_ObjType_FreeLifePOWMembrane,

	GLOBAL_ObjType_BlasterPOWMembrane,
	GLOBAL_ObjType_TriplePOWMembrane,
	GLOBAL_ObjType_MissilePOWMembrane,
	GLOBAL_ObjType_SonicScreamPOWMembrane,
	GLOBAL_ObjType_BombPOWMembrane,

	GLOBAL_ObjType_EntryWormhole,

	GLOBAL_ObjType_TowerTurret_Lens,
	GLOBAL_ObjType_TowerTurret_TurretBullet,

	GLOBAL_ObjType_Electrode_Pole,
	GLOBAL_ObjType_Electrode_TopBottom,
	GLOBAL_ObjType_Electrode_Middle,

	GLOBAL_ObjType_ForestDoor_Door,
	GLOBAL_ObjType_ForestDoor_KeyHolder,
	GLOBAL_ObjType_ForestDoor_Key,
	GLOBAL_ObjType_ForestDoor_Ring,

	GLOBAL_ObjType_LaserOrb,
	GLOBAL_ObjType_LaserOrbGreen

};


/******************** PLAYER PARTS ************************/

enum
{
	PLAYER_ObjType_JetPack,
	PLAYER_ObjType_JetPackBlue
};


/******************* WEAPONS *************************/

enum
{
	WEAPONS_ObjType_BlasterBullet = 0,
	WEAPONS_ObjType_ClusterBullet,
	WEAPONS_ObjType_HeatSeekerBullet,
	WEAPONS_ObjType_Bomb,
	WEAPONS_ObjType_BombShockwave,

	WEAPONS_ObjType_Shield
};


/******************* LEVEL 1: FOREST *************************/

enum
{
	LEVEL1_ObjType_Cyc = 0,
	LEVEL1_ObjType_CloudGrid,
	LEVEL1_ObjType_Tree_Birch_HighRed,
	LEVEL1_ObjType_Tree_Birch_HighYellow,
	LEVEL1_ObjType_Tree_Birch_MediumRed,
	LEVEL1_ObjType_Tree_Birch_MediumYellow,
	LEVEL1_ObjType_Tree_Birch_LowRed,
	LEVEL1_ObjType_Tree_Birch_LowYellow,
	LEVEL1_ObjType_Tree_Birch_Flat,

	LEVEL1_ObjType_Tree_Pine_HighDead,
	LEVEL1_ObjType_Tree_Pine_High,
	LEVEL1_ObjType_Tree_Pine_MediumDead,
	LEVEL1_ObjType_Tree_Pine_Medium,
	LEVEL1_ObjType_Tree_Pine_LowDead,
	LEVEL1_ObjType_Tree_Pine_Low,
	LEVEL1_ObjType_Tree_Pine_Flat,

	LEVEL1_ObjType_SmallTree,
	LEVEL1_ObjType_FallenTree,
	LEVEL1_ObjType_TreeStump,

	LEVEL1_ObjType_BentPine1_Trunk,
	LEVEL1_ObjType_BentPine2_Trunk,
	LEVEL1_ObjType_BentPine1_Leaves,
	LEVEL1_ObjType_BentPine2_Leaves,


	LEVEL1_ObjType_Grass,
	LEVEL1_ObjType_GrassPatch,

	LEVEL1_ObjType_LowFern,
	LEVEL1_ObjType_HighFern,
	LEVEL1_ObjType_LowBerryBush,
	LEVEL1_ObjType_HighBerryBush,
	LEVEL1_ObjType_SmallCattail,
	LEVEL1_ObjType_LargeCattail,

	LEVEL1_ObjType_Rock1,
	LEVEL1_ObjType_Rock2,
	LEVEL1_ObjType_Rock3,
	LEVEL1_ObjType_Rock4,
	LEVEL1_ObjType_TallRock1,
	LEVEL1_ObjType_TallRock2,
	LEVEL1_ObjType_RiverRock1,
	LEVEL1_ObjType_RiverRock2,

	LEVEL1_ObjType_GasMound1,
	LEVEL1_ObjType_GasMound2,
	LEVEL1_ObjType_GasMound3,

	LEVEL1_ObjType_ForestDoor_Wall,

	LEVEL1_ObjType_AirMine_Base,
	LEVEL1_ObjType_AirMine_Chain,
	LEVEL1_ObjType_AirMine_Mine,

	LEVEL1_ObjType_TowerTurret_Base,
	LEVEL1_ObjType_TowerTurret_Turret,
	LEVEL1_ObjType_TowerTurret_Wheel,
	LEVEL1_ObjType_TowerTurret_Gun


};


/******************* LEVEL 2: DESERT *************************/

enum
{
	LEVEL2_ObjType_Cyc 			= 0,
	LEVEL2_ObjType_CloudGrid,

	LEVEL2_ObjType_AirMine_Base,
	LEVEL2_ObjType_AirMine_Chain,
	LEVEL2_ObjType_AirMine_Mine,


	LEVEL2_ObjType_Tree1,
	LEVEL2_ObjType_Tree2,
	LEVEL2_ObjType_Tree3,
	LEVEL2_ObjType_Tree4,
	LEVEL2_ObjType_Tree5,
	LEVEL2_ObjType_Tree1_Canopy,
	LEVEL2_ObjType_Tree2_Canopy,
	LEVEL2_ObjType_Tree3_Canopy,
	LEVEL2_ObjType_Tree4_Canopy,
	LEVEL2_ObjType_Tree5_Canopy,

	LEVEL2_ObjType_BurntTree1,
	LEVEL2_ObjType_BurntTree2,

	LEVEL2_ObjType_PalmTree1,
	LEVEL2_ObjType_PalmTree2,
	LEVEL2_ObjType_PalmTree3,
	LEVEL2_ObjType_PalmTree1_Canopy,
	LEVEL2_ObjType_PalmTree2_Canopy,
	LEVEL2_ObjType_PalmTree3_Canopy,

	LEVEL2_ObjType_Bush1,
	LEVEL2_ObjType_Bush2,
	LEVEL2_ObjType_Bush3,
	LEVEL2_ObjType_BushBurnt,
	LEVEL2_ObjType_PalmBush1,
	LEVEL2_ObjType_PalmBush2,
	LEVEL2_ObjType_PalmBush3,

	LEVEL2_ObjType_Cactus_Low,
	LEVEL2_ObjType_Cactus_Small,
	LEVEL2_ObjType_Cactus_Medium,

	LEVEL2_ObjType_Crystal1,
	LEVEL2_ObjType_Crystal2,
	LEVEL2_ObjType_Crystal3,
	LEVEL2_ObjType_Crystal1Base,
	LEVEL2_ObjType_Crystal2Base,
	LEVEL2_ObjType_Crystal3Base,

	LEVEL2_ObjType_Rock_Small1,
	LEVEL2_ObjType_Rock_Medium1,
	LEVEL2_ObjType_Rock_Large1,
	LEVEL2_ObjType_Rock_Small2,
	LEVEL2_ObjType_Rock_Medium2,
	LEVEL2_ObjType_Rock_Large3,

	LEVEL2_ObjType_Grass,
	LEVEL2_ObjType_GrassPatch,

	LEVEL2_ObjType_ForestDoor_Wall,

	LEVEL2_ObjType_TowerTurret_Base,
	LEVEL2_ObjType_TowerTurret_Turret,
	LEVEL2_ObjType_TowerTurret_Wheel,
	LEVEL2_ObjType_TowerTurret_Gun

};


/******************* LEVEL 3: SWAMP *************************/

enum
{
	LEVEL3_ObjType_Cyc 			= 0,
	LEVEL3_ObjType_CloudGrid,

	LEVEL3_ObjType_HydraTree_Small,
	LEVEL3_ObjType_HydraTree_Medium,
	LEVEL3_ObjType_HydraTree_Large,

	LEVEL3_ObjType_OddTree_Small,
	LEVEL3_ObjType_OddTree_Medium1,
	LEVEL3_ObjType_OddTree_Medium2,
	LEVEL3_ObjType_OddTree_Large,

	LEVEL3_ObjType_GeckoPlant_Small,
	LEVEL3_ObjType_GeckoPlant_Medium,
	LEVEL3_ObjType_GeckoPlant_Large,

	LEVEL3_ObjType_SproutPlant,

	LEVEL3_ObjType_Grass_Single,
	LEVEL3_ObjType_Grass_Small,
	LEVEL3_ObjType_Grass_Patch,

	LEVEL3_ObjType_PurpleIvy_Small,
	LEVEL3_ObjType_PurpleIvy_Medium,
	LEVEL3_ObjType_PurpleIvy_Large,
	LEVEL3_ObjType_PurpleIvy_PatchMedium,
	LEVEL3_ObjType_PurpleIvy_PatchLarge,

	LEVEL3_ObjType_RedIvy_Small,
	LEVEL3_ObjType_RedIvy_Medium,
	LEVEL3_ObjType_RedIvy_Large,
	LEVEL3_ObjType_RedIvy_PatchMedium,
	LEVEL3_ObjType_RedIvy_PatchLarge,

	LEVEL3_ObjType_Asteroid_Cracked,
	LEVEL3_ObjType_Asteroid1,
	LEVEL3_ObjType_Asteroid2,

	LEVEL3_ObjType_AirMine_Base,
	LEVEL3_ObjType_AirMine_Chain,
	LEVEL3_ObjType_AirMine_Mine,

	LEVEL3_ObjType_ForestDoor_Wall,

	LEVEL3_ObjType_TowerTurret_Base,
	LEVEL3_ObjType_TowerTurret_Turret,
	LEVEL3_ObjType_TowerTurret_Wheel,
	LEVEL3_ObjType_TowerTurret_Gun,

	LEVEL3_ObjType_FallenTree1,
	LEVEL3_ObjType_FallenTree2,

	LEVEL3_ObjType_Stump1,
	LEVEL3_ObjType_Stump2,
	LEVEL3_ObjType_Stump3,
	LEVEL3_ObjType_Stump4
};



/********************** LEVEL INTRO *****************************/

enum
{
	LEVELINTRO_ObjType_StarDome



};

#endif









