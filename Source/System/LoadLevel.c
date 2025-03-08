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


			/* LOAD GLOBAL BG3D GEOMETRY */

	FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ":Models:global.bg3d", &spec);
	ImportBG3D(&spec, MODEL_GROUP_GLOBAL,  VERTEX_ARRAY_RANGE_TYPE_BG3DMODELS);

	FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ":Models:playerparts.bg3d", &spec);
	ImportBG3D(&spec, MODEL_GROUP_PLAYER,  VERTEX_ARRAY_RANGE_TYPE_BG3DMODELS);

	FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ":Models:weapons.bg3d", &spec);
	ImportBG3D(&spec, MODEL_GROUP_WEAPONS,  VERTEX_ARRAY_RANGE_TYPE_BG3DMODELS);

	BG3D_SphereMapGeomteryMaterial(MODEL_GROUP_PLAYER, PLAYER_ObjType_JetPack,
									-1, MULTI_TEXTURE_COMBINE_ADD, SPHEREMAP_SObjType_Satin);





			/* LOAD LEVEL SPECIFIC BG3D GEOMETRY */

	{
		SDL_snprintf(path, sizeof(path), ":Models:%s.bg3d", kBiomeNames[currentBiome]);
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

	const char* levelSpecificSpritePaths[5] =
	{
		":Sprites:textures:blockenemy",
	};
	int numLevelSpecificSprites = 1;

	switch (currentBiome)
	{
		case BIOME_FOREST:
			levelSpecificSpritePaths[numLevelSpecificSprites++] = ":Sprites:textures:pinefence";
			break;

		case BIOME_DESERT:
			levelSpecificSpritePaths[numLevelSpecificSprites++] = ":Sprites:textures:dustdevil";
			break;

		default:
			break;
	}

	GAME_ASSERT_MESSAGE(
			numLevelSpecificSprites <= (int) (sizeof(levelSpecificSpritePaths)/sizeof(levelSpecificSpritePaths[0])),
			"too many level-specific sprites in array");

	LoadSpriteGroupFromFiles(SPRITE_GROUP_LEVELSPECIFIC, numLevelSpecificSprites, levelSpecificSpritePaths);


			/* LOAD OVERHEAD MAP */
	{
		SDL_snprintf(path, sizeof(path), ":Sprites:maps:%s", kLevelNames[gLevelNum]);
		FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, path, &spec);
		LoadSpriteGroupFromFile(SPRITE_GROUP_OVERHEADMAP, path, 0);
	}


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
		SDL_snprintf(path, sizeof(path), ":Terrain:%s.ter", kLevelNames[gLevelNum]);
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

	SDL_Log("%s: %d ms", __func__, (timeEndLoad.lo - timeStartLoad.lo) / 1000);
}





















