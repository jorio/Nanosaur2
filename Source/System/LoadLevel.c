/****************************/
/*      LOAD LEVEL.C        */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/***************/
/* EXTERNALS   */
/***************/

#include "game.h"

/****************************/
/*    PROTOTYPES            */
/****************************/



/****************************/
/*    CONSTANTS             */
/****************************/


/**********************/
/*     VARIABLES      */
/**********************/

static const int kLevelBiomes[NUM_LEVELS] =
{
	[LEVEL_NUM_ADVENTURE1]	= BIOME_FOREST,
	[LEVEL_NUM_ADVENTURE2]	= BIOME_DESERT,
	[LEVEL_NUM_ADVENTURE3]	= BIOME_SWAMP,
	[LEVEL_NUM_RACE1]		= BIOME_SWAMP,
	[LEVEL_NUM_RACE2]		= BIOME_DESERT,
	[LEVEL_NUM_BATTLE1]		= BIOME_FOREST,
	[LEVEL_NUM_BATTLE2]		= BIOME_DESERT,
	[LEVEL_NUM_FLAG1]		= BIOME_SWAMP,
	[LEVEL_NUM_FLAG2]		= BIOME_FOREST,
};

static const char* kLevelNames[NUM_LEVELS] =
{
	[LEVEL_NUM_ADVENTURE1]	= "level1",
	[LEVEL_NUM_ADVENTURE2]	= "level2",
	[LEVEL_NUM_ADVENTURE3]	= "level3",
	[LEVEL_NUM_RACE1]		= "race1",
	[LEVEL_NUM_RACE2]		= "race2",
	[LEVEL_NUM_BATTLE1]		= "battle1",
	[LEVEL_NUM_BATTLE2]		= "battle2",
	[LEVEL_NUM_FLAG1]		= "flag1",
	[LEVEL_NUM_FLAG2]		= "flag2",
};

static const char*	kBiomeNames[NUM_BIOMES] =
{
	[BIOME_FOREST]			= "forest",
	[BIOME_DESERT]			= "desert",
	[BIOME_SWAMP]			= "swamp",
};


/************************** LOAD LEVEL ART ***************************/

void LoadLevelArt(void)
{
FSSpec	spec;
char	path[256];

	const int currentBiome = kLevelBiomes[gLevelNum];

	UnsignedWide timeStartLoad;
	Microseconds(&timeStartLoad);

	gLoadingThermoPercent = 0;

	glClearColor(0,0,0,0);						// clear to black for loading screen

				/* LOAD AUDIO */

//	if (levelSoundFiles[gLevelNum][0] > 0)
//	{
//		FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, levelSoundFiles[gLevelNum], &spec);
//		LoadSoundBank(&spec, SOUND_BANK_LEVELSPECIFIC);
//	}


			/* LOAD GLOBAL BG3D GEOMETRY */

	FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ":models:Global.bg3d", &spec);
	ImportBG3D(&spec, MODEL_GROUP_GLOBAL,  VERTEX_ARRAY_RANGE_TYPE_BG3DMODELS);

	FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ":models:playerparts.bg3d", &spec);
	ImportBG3D(&spec, MODEL_GROUP_PLAYER,  VERTEX_ARRAY_RANGE_TYPE_BG3DMODELS);

	FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ":Models:Weapons.bg3d", &spec);
	ImportBG3D(&spec, MODEL_GROUP_WEAPONS,  VERTEX_ARRAY_RANGE_TYPE_BG3DMODELS);

	BG3D_SphereMapGeomteryMaterial(MODEL_GROUP_PLAYER, PLAYER_ObjType_JetPack,
									-1, MULTI_TEXTURE_COMBINE_ADD, SPHEREMAP_SObjType_Satin);





			/* LOAD LEVEL SPECIFIC BG3D GEOMETRY */

	{
		snprintf(path, sizeof(path), ":models:%s.bg3d", kBiomeNames[currentBiome]);
		FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, path, &spec);
		ImportBG3D(&spec, MODEL_GROUP_LEVELSPECIFIC,  VERTEX_ARRAY_RANGE_TYPE_BG3DMODELS);
	}


	for (int i = 0; i < NUM_EGG_TYPES; i++)
	{
		BG3D_SphereMapGeomteryMaterial(MODEL_GROUP_GLOBAL, GLOBAL_ObjType_RedEgg + i,
									-1, MULTI_TEXTURE_COMBINE_ADD, SPHEREMAP_SObjType_Satin);
	}


	BG3D_SphereMapGeomteryMaterial(MODEL_GROUP_GLOBAL, GLOBAL_ObjType_TowerTurret_Lens,
									-1, MULTI_TEXTURE_COMBINE_ADD, SPHEREMAP_SObjType_Sheen);




			/****************/
			/* LOAD SPRITES */
			/****************/

	switch (currentBiome)
	{
		case BIOME_FOREST:
			LoadSpriteGroupFromFile(SPRITE_GROUP_LEVELSPECIFIC, ":sprites:textures:pinefence", 0);
			break;

		case BIOME_DESERT:
			LoadSpriteGroupFromFile(SPRITE_GROUP_LEVELSPECIFIC, ":sprites:textures:dustdevil", 0);
			break;

		default:
			break;
	}


			/* LOAD OVERHEAD MAP */
	{
		snprintf(path, sizeof(path), ":sprites:maps:%s", kLevelNames[gLevelNum]);
		FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, path, &spec);
		LoadSpriteGroupFromFile(SPRITE_GROUP_OVERHEADMAP, path, 0);
	}

	LoadSpriteGroupFromSeries(SPRITE_GROUP_INFOBAR,		INFOBAR_SObjType_COUNT,		"infobar");
	LoadSpriteGroupFromSeries(SPRITE_GROUP_GLOBAL,		GLOBAL_SObjType_COUNT,		"global");
	LoadSpriteGroupFromSeries(SPRITE_GROUP_SPHEREMAPS,	SPHEREMAP_SObjType_COUNT,	"spheremap");


			/* DRAW THE LOADING TEXT AND THERMO */

	DrawLoading(0);


			/******************/
			/* LOAD SKELETONS */
			/******************/

	LoadASkeleton(SKELETON_TYPE_PLAYER);
	LoadASkeleton(SKELETON_TYPE_RAPTOR);
	LoadASkeleton(SKELETON_TYPE_BRACH);

	LoadASkeleton(SKELETON_TYPE_WORMHOLE);


			/****************/
			/* LOAD TERRAIN */
			/****************/

	{
		snprintf(path, sizeof(path), ":terrain:%s.ter", kLevelNames[gLevelNum]);
		FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, path, &spec);
		LoadPlayfield(&spec);
	}


			/* RESTORE CLEAR COLOR */

	glClearColor(gGameViewInfoPtr->clearColor.r, gGameViewInfoPtr->clearColor.g, gGameViewInfoPtr->clearColor.b, 1.0);



			/***************************/
			/* DO BIOME SPECIFIC STUFF */
			/***************************/

	switch (currentBiome)
	{
		case	BIOME_FOREST: //LEVEL_NUM_ADVENTURE1, LEVEL_NUM_BATTLE1, LEVEL_NUM_FLAG2
				BG3D_SphereMapGeomteryMaterial(MODEL_GROUP_LEVELSPECIFIC, LEVEL1_ObjType_AirMine_Mine,
												-1, MULTI_TEXTURE_COMBINE_ADD, SPHEREMAP_SObjType_Satin);
				break;

		case	BIOME_DESERT: //LEVEL_NUM_ADVENTURE2, LEVEL_NUM_RACE2, LEVEL_NUM_BATTLE2
				BG3D_SphereMapGeomteryMaterial(MODEL_GROUP_LEVELSPECIFIC, LEVEL2_ObjType_AirMine_Mine,
												-1, MULTI_TEXTURE_COMBINE_ADD, SPHEREMAP_SObjType_Satin);

				BG3D_SphereMapGeomteryMaterial(MODEL_GROUP_LEVELSPECIFIC, LEVEL2_ObjType_Crystal1,
												-1, MULTI_TEXTURE_COMBINE_ADD, SPHEREMAP_SObjType_Sheen);
				break;


		case	BIOME_SWAMP: //LEVEL_NUM_ADVENTURE3, LEVEL_NUM_RACE1, LEVEL_NUM_FLAG1
				LoadASkeleton(SKELETON_TYPE_WORM);
				LoadASkeleton(SKELETON_TYPE_RAMPHOR);
				break;
	}

	UnsignedWide timeEndLoad;
	Microseconds(&timeEndLoad);

	printf("%s: %d ms\n", __func__, (timeEndLoad.lo - timeStartLoad.lo) / 1000);
}





















