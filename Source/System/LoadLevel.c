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

static const Str63	terrainFiles[NUM_LEVELS] =
{
	":terrain:Level1.ter",
	":terrain:Level2.ter",
	":terrain:Level3.ter",

	":terrain:race1.ter",
	":terrain:race2.ter",
	":terrain:battle1.ter",
	":terrain:battle2.ter",
	":terrain:flag1.ter",
	":terrain:flag2.ter",
};

static const Str63	levelModelFiles[NUM_LEVELS] =
{
	":models:Level1.bg3d",
	":models:Level2.bg3d",
	":models:Level3.bg3d",

	":models:Level3.bg3d",			// race 1:  swamp
	":models:Level2.bg3d",			// race 2:  desert
	":models:Level1.bg3d",			// battle 1: forest
	":models:Level2.bg3d",			// battle 2: desert
	":models:Level3.bg3d",			// flag 1:  swamp
	":models:Level1.bg3d",			// flag 2: forest

};

static const Str63	levelSpriteFiles[NUM_LEVELS] =
{
	":sprites:Level1.sprites",
	":sprites:Level2.sprites",
	":sprites:Level3.sprites",

	":sprites:Level3.sprites",			// race 1:  swamp
	":sprites:Level2.sprites",
	":sprites:Level1.sprites",			// battle 1: forest
	":sprites:Level2.sprites",
	":sprites:Level3.sprites",			// flag 1:  swamp
	":sprites:Level1.sprites",			// flag 2:  forest
};

#if 0
static const Str63	levelSoundFiles[NUM_LEVELS] =
{
	":Audio:Garden.sounds",
	":Audio:Garden.sounds",
	":Audio:Garden.sounds",

	":Audio:Garden.sounds",
	":Audio:Garden.sounds",
	":Audio:Garden.sounds",
	":Audio:Garden.sounds",
	":Audio:Garden.sounds",
	":Audio:Garden.sounds",
};
#endif



/************************** LOAD LEVEL ART ***************************/

void LoadLevelArt(OGLSetupOutputType *setupInfo)
{
FSSpec	spec;
short	i;

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
	ImportBG3D(&spec, MODEL_GROUP_GLOBAL, setupInfo, VERTEX_ARRAY_RANGE_TYPE_BG3DMODELS);

	FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ":models:playerparts.bg3d", &spec);
	ImportBG3D(&spec, MODEL_GROUP_PLAYER, setupInfo, VERTEX_ARRAY_RANGE_TYPE_BG3DMODELS);

	FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ":Models:Weapons.bg3d", &spec);
	ImportBG3D(&spec, MODEL_GROUP_WEAPONS, setupInfo, VERTEX_ARRAY_RANGE_TYPE_BG3DMODELS);

	BG3D_SphereMapGeomteryMaterial(MODEL_GROUP_PLAYER, PLAYER_ObjType_JetPack,
									-1, MULTI_TEXTURE_COMBINE_ADD, SPHEREMAP_SObjType_Satin);





			/* LOAD LEVEL SPECIFIC BG3D GEOMETRY */

	if (levelModelFiles[gLevelNum][0] > 0)
	{
		FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, levelModelFiles[gLevelNum], &spec);
		ImportBG3D(&spec, MODEL_GROUP_LEVELSPECIFIC, setupInfo, VERTEX_ARRAY_RANGE_TYPE_BG3DMODELS);
	}


	for (i = 0; i < NUM_EGG_TYPES; i++)
	{
		BG3D_SphereMapGeomteryMaterial(MODEL_GROUP_GLOBAL, GLOBAL_ObjType_RedEgg + i,
									-1, MULTI_TEXTURE_COMBINE_ADD, SPHEREMAP_SObjType_Satin);
	}


	BG3D_SphereMapGeomteryMaterial(MODEL_GROUP_GLOBAL, GLOBAL_ObjType_TowerTurret_Lens,
									-1, MULTI_TEXTURE_COMBINE_ADD, SPHEREMAP_SObjType_Sheen);




			/****************/
			/* LOAD SPRITES */
			/****************/

	if (levelSpriteFiles[gLevelNum][0] > 0)
	{
		FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, levelSpriteFiles[gLevelNum], &spec);
		LoadSpriteFile(&spec, SPRITE_GROUP_LEVELSPECIFIC, setupInfo);
	}

	FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ":sprites:infobar.sprites", &spec);
	LoadSpriteFile(&spec, SPRITE_GROUP_INFOBAR, setupInfo);

	FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ":sprites:global.sprites", &spec);
	LoadSpriteFile(&spec, SPRITE_GROUP_GLOBAL, setupInfo);

	FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ":sprites:spheremap.sprites", &spec);
	LoadSpriteFile(&spec, SPRITE_GROUP_SPHEREMAPS, setupInfo);

	FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ":sprites:font.sprites", &spec);
	LoadSpriteFile(&spec, SPRITE_GROUP_FONT, setupInfo);


			/* DRAW THE LOADING TEXT AND THERMO */

	GammaOn();
	DrawLoading(0);


			/******************/
			/* LOAD SKELETONS */
			/******************/

	LoadASkeleton(SKELETON_TYPE_PLAYER, setupInfo);
	LoadASkeleton(SKELETON_TYPE_RAPTOR, setupInfo);
	LoadASkeleton(SKELETON_TYPE_BRACH, setupInfo);

	LoadASkeleton(SKELETON_TYPE_WORMHOLE, setupInfo);


			/****************/
			/* LOAD TERRAIN */
			/****************/

	if (terrainFiles[gLevelNum][0] > 0)
	{
		FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, terrainFiles[gLevelNum], &spec);
		LoadPlayfield(&spec, setupInfo);
	}



	GammaOff();

			/* RESTORE CLEAR COLOR */

	glClearColor(gGameViewInfoPtr->clearColor.r, gGameViewInfoPtr->clearColor.g, gGameViewInfoPtr->clearColor.b, 1.0);



			/***************************/
			/* DO LEVEL SPECIFIC STUFF */
			/***************************/

	switch(gLevelNum)
	{
		case	LEVEL_NUM_ADVENTURE1:
		case	LEVEL_NUM_FLAG2:
		case	LEVEL_NUM_BATTLE1:
				BG3D_SphereMapGeomteryMaterial(MODEL_GROUP_LEVELSPECIFIC, LEVEL1_ObjType_AirMine_Mine,
												-1, MULTI_TEXTURE_COMBINE_ADD, SPHEREMAP_SObjType_Satin);
				break;

		case	LEVEL_NUM_ADVENTURE2:
		case	LEVEL_NUM_BATTLE2:
		case	LEVEL_NUM_RACE2:
				BG3D_SphereMapGeomteryMaterial(MODEL_GROUP_LEVELSPECIFIC, LEVEL2_ObjType_AirMine_Mine,
												-1, MULTI_TEXTURE_COMBINE_ADD, SPHEREMAP_SObjType_Satin);

				BG3D_SphereMapGeomteryMaterial(MODEL_GROUP_LEVELSPECIFIC, LEVEL2_ObjType_Crystal1,
												-1, MULTI_TEXTURE_COMBINE_ADD, SPHEREMAP_SObjType_Sheen);


				break;


		case	LEVEL_NUM_ADVENTURE3:
		case	LEVEL_NUM_RACE1:
		case	LEVEL_NUM_FLAG1:
				LoadASkeleton(SKELETON_TYPE_WORM, setupInfo);
				LoadASkeleton(SKELETON_TYPE_RAMPHOR, setupInfo);
				break;

	}

}





















