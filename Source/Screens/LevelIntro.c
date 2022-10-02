/****************************/
/*   	LEVEL INTRO SCREEN.C		*/
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/

#include "game.h"

/****************************/
/*    PROTOTYPES            */
/****************************/

static void SetupLevelIntroScreen(void);
static void FreeLevelIntroScreen(void);
static void MoveLevelIntroWorm(ObjNode *theNode);
static void UpdateLevelIntroWormJoints(ObjNode *theNode);
static void MoveLevelIntroNano(ObjNode *theNode);
static void MakeLevelIntroWormNano(void);
static void MoveIntroStarDome(ObjNode *theNode);
static void MakeLevelIntroSaveSprites(void);
static void MovePressAnyKey(ObjNode* theNode);


/****************************/
/*    CONSTANTS             */
/****************************/


/*********************/
/*    VARIABLES      */
/*********************/

static OGLPoint3D		gWormholeDeformPoints[30];
static	Byte			gIntroMode;


/********************** DO LEVEL INTRO SCREEN **************************/

void DoLevelIntroScreen(Byte mode)
{
Boolean	bail = false;
float	timer = 5.0f;

#if SKIPFLUFF
	if (mode == INTRO_MODE_NOSAVE)
	{
		return;
	}
#endif

	gIntroMode = mode;


			/* SETUP */

	SetupLevelIntroScreen();
	MakeFadeEvent(true, 1.5);


			/*************/
			/* MAIN LOOP */
			/*************/

	do
	{
		CalcFramesPerSecond();
		DoSDLMaintenance();

		MoveObjects();
		OGL_DrawScene(DrawObjects);

		switch(gIntroMode)
		{
			case	INTRO_MODE_SCREENSAVER:
					if (UserWantsOut())
						bail = true;
					break;


			case	INTRO_MODE_NOSAVE:
					timer -= gFramesPerSecondFrac;
					if ((timer < 0.0f) || UserWantsOut())
						bail = true;
					break;

			case	INTRO_MODE_SAVEGAME:
					if (gMenuOutcome != 0)
					{
						bail = true;
					}
					break;

		}
	}while(!bail);


			/************/
			/* FADE OUT */
			/************/

	OGL_FadeOutScene(DrawObjects, MoveObjects);


			/* DO SAVE */

	switch (gMenuOutcome)
	{
		case 'sf#0':
		case 'sf#1':
		case 'sf#2':
		case 'sf#3':
		case 'sf#4':
		case 'sf#5':
		case 'sf#6':
		case 'sf#7':
		case 'sf#8':
		case 'sf#9':
			SaveGame(gMenuOutcome - 'sf#0');
			break;

		case 'dont':
		default:
			break;
	}


			/* CLEANUP */

	FreeLevelIntroScreen();
}



/********************* SETUP LEVEL INTRO SCREEN **********************/

static void SetupLevelIntroScreen(void)
{
FSSpec				spec;
OGLSetupInputType	viewDef;
static const OGLVector3D	fillDirection1 = { -.3, -.5, -1.0 };
ObjNode	*newObj;


			/**************/
			/* SETUP VIEW */
			/**************/

	OGL_NewViewDef(&viewDef);

	viewDef.camera.fov 			= 1.1;
	viewDef.camera.hither 		= 50;
	viewDef.camera.yon 			= 8000;

	viewDef.styles.useFog			= true;
	viewDef.styles.fogStart			= viewDef.camera.yon * .1f;
	viewDef.styles.fogEnd			= viewDef.camera.yon * .9f;
	viewDef.view.clearColor.r 		= 0;
	viewDef.view.clearColor.g 		= 0;
	viewDef.view.clearColor.b		= 0;
	viewDef.view.clearBackBuffer	= true;

	viewDef.camera.from[0].x		= 0;
	viewDef.camera.from[0].y		= 0;
	viewDef.camera.from[0].z		= 0;

	viewDef.camera.to[0].x 			= 0.0f;
	viewDef.camera.to[0].y 			= 0.0f;
	viewDef.camera.to[0].z 			= -1500.0f;

	viewDef.lights.ambientColor.r = .3;
	viewDef.lights.ambientColor.g = .3;
	viewDef.lights.ambientColor.b = .3;
	viewDef.lights.fillDirection[0] = fillDirection1;

			/* INIT ANAGLYPH INFO */

	if (gGamePrefs.stereoGlassesMode != STEREO_GLASSES_MODE_OFF)
	{
		gAnaglyphFocallength	= 300.0f;
		gAnaglyphEyeSeparation 	= 20.0f;

		if (gGamePrefs.stereoGlassesMode == STEREO_GLASSES_MODE_ANAGLYPH)
		{
			viewDef.lights.ambientColor.r = .8;
			viewDef.lights.ambientColor.g = .8;
			viewDef.lights.ambientColor.b = .8;
		}
	}


	OGL_SetupGameView(&viewDef);


				/************/
				/* LOAD ART */
				/************/

	InitParticleSystem();
	InitSparkles();

			/* LOAD MODELS */

	FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ":models:playerparts.bg3d", &spec);
	ImportBG3D(&spec, MODEL_GROUP_PLAYER, VERTEX_ARRAY_RANGE_TYPE_BG3DMODELS);

	FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ":models:levelintro.bg3d", &spec);
	ImportBG3D(&spec, MODEL_GROUP_LEVELINTRO, VERTEX_ARRAY_RANGE_TYPE_BG3DMODELS);


			/* LOAD SPRITES */

	LoadSpriteGroupFromFiles(SPRITE_GROUP_MAINMENU, 1, (const char*[]) {":sprites:nanologo.png"}, 0);
	LoadSpriteAtlas(SPRITE_GROUP_FONT, "font", kAtlasLoadFont);


			/* LOAD SKELETONS */

	LoadASkeleton(SKELETON_TYPE_BONUSWORMHOLE);
	LoadASkeleton(SKELETON_TYPE_PLAYER);



			/*****************/
			/* MAKE WORMHOLE */
			/*****************/

	gNewObjectDefinition.type 		= SKELETON_TYPE_BONUSWORMHOLE;
	gNewObjectDefinition.animNum	= 0;
	gNewObjectDefinition.coord.x 	= 0.0f;
	gNewObjectDefinition.coord.y 	= 0;
	gNewObjectDefinition.coord.z 	= 0;
	gNewObjectDefinition.flags 		= STATUS_BIT_DONTCULL|STATUS_BIT_DOUBLESIDED|STATUS_BIT_UVTRANSFORM|STATUS_BIT_GLOW|
									STATUS_BIT_NOZWRITES | STATUS_BIT_NOLIGHTING;
	gNewObjectDefinition.slot 		= 100;
	gNewObjectDefinition.moveCall	= MoveLevelIntroWorm;
	gNewObjectDefinition.rot 		= 0;
	gNewObjectDefinition.scale 		= 26.0;

	newObj = MakeNewSkeletonObject(&gNewObjectDefinition);

	newObj->Skeleton->JointsAreGlobal = true;

	UpdateObjectTransforms(newObj);

	UpdateLevelIntroWormJoints(newObj);

	PlayEffect_Parms(EFFECT_WORMHOLE, FULL_CHANNEL_VOLUME/2, FULL_CHANNEL_VOLUME/3, NORMAL_CHANNEL_RATE);


			/***************/
			/* MAKE PLAYER */
			/***************/

	MakeLevelIntroWormNano();



			/******************/
			/* MAKE STAR DOME */
			/******************/

	gNewObjectDefinition.group	= MODEL_GROUP_LEVELINTRO;
	gNewObjectDefinition.type 	= LEVELINTRO_ObjType_StarDome;
	gNewObjectDefinition.coord.x = 0;
	gNewObjectDefinition.coord.y = 0;
	gNewObjectDefinition.coord.z = -5500;
	gNewObjectDefinition.flags 	= STATUS_BIT_DONTCULL|STATUS_BIT_NOLIGHTING|STATUS_BIT_NOFOG|STATUS_BIT_DOUBLESIDED|STATUS_BIT_NOZBUFFER;
	gNewObjectDefinition.slot 	= 0;
	gNewObjectDefinition.moveCall = MoveIntroStarDome;
	gNewObjectDefinition.rot 	= 0;
	gNewObjectDefinition.scale 	= 12;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);



			/*********************/
			/* DO MODE SPECIFICS */
			/*********************/

	switch(gIntroMode)
	{
		case	INTRO_MODE_SAVEGAME:
				MakeLevelIntroSaveSprites();
				break;


		case	INTRO_MODE_SCREENSAVER:
			{
					/* PRESS ANY KEY */

				NewObjectDefinitionType textDef =
				{
					.coord		= {640/2, 450, 0},
					.slot		= SPRITE_SLOT,
					.moveCall	= MovePressAnyKey,
					.scale		= 0.35f,
				};
				newObj = TextMesh_New(Localize(gUserPrefersGamepad? STR_PRESS_START: STR_PRESS_ANY_KEY), kTextMeshAlignCenter, &textDef);
				newObj->ColorFilter.a = .6f;
				newObj->AnaglyphZ = 6.0f;

					/* NANO LOGO */

				NewObjectDefinitionType logoDef =
				{
					.group		= SPRITE_GROUP_MAINMENU,
					.type		= MAINMENU_SObjType_NanoLogo,
					.coord		= {20, 0, 0},
					.slot		= SPRITE_SLOT,
					.scale		= 150,
				};
				newObj = MakeSpriteObject(&logoDef, false);
				newObj->AnaglyphZ = 6.0f;

				break;
			}
	}
}




/******************* MAKE LEVEL INTRO WORM PLAYER **********************/

static void MakeLevelIntroWormNano(void)
{
ObjNode	*newObj, *jetpack, *blue;
short	i, j;

			/* MAKE SKELETON */

	gNewObjectDefinition.type 		= SKELETON_TYPE_PLAYER;
	gNewObjectDefinition.animNum	= PLAYER_ANIM_FLAP;
	gNewObjectDefinition.flags 		= STATUS_BIT_NOTEXTUREWRAP | STATUS_BIT_USEALIGNMENTMATRIX;
	gNewObjectDefinition.slot 		= 200;
	gNewObjectDefinition.moveCall	= MoveLevelIntroNano;
	gNewObjectDefinition.rot 		= 0;
	gNewObjectDefinition.scale 		= .6;

	newObj = MakeNewSkeletonObject(&gNewObjectDefinition);

	newObj->Skeleton->AnimSpeed = 2.0f;

	MoveLevelIntroNano(newObj);								// prime it


		/*****************/
		/* MAKE JETPACK  */
		/*****************/

	gNewObjectDefinition.group 		= MODEL_GROUP_PLAYER;
	gNewObjectDefinition.type 		= PLAYER_ObjType_JetPack;
	gNewObjectDefinition.flags 		= 0;
	gNewObjectDefinition.slot		= SLOT_OF_DUMB;
	gNewObjectDefinition.moveCall 	= MovePlayerJetpack;
	jetpack = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	newObj->ChainNode = jetpack;
	jetpack->ChainHead = newObj;

		/* BLUE THING */

	gNewObjectDefinition.type 		= PLAYER_ObjType_JetPackBlue;
	gNewObjectDefinition.flags 		= 0 | STATUS_BIT_UVTRANSFORM | STATUS_BIT_GLOW | STATUS_BIT_NOLIGHTING;
	gNewObjectDefinition.slot		= SLOT_OF_DUMB + 1;
	gNewObjectDefinition.moveCall 	= nil;
	blue = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	blue->ColorFilter.a = .99;
	jetpack->ChainNode = blue;
	blue->ChainHead = jetpack;



		/* MAKE SPARKLES FOR GUN TURRETS */

	for (j = 0; j < 2; j++)
	{
		i = GetFreeSparkle(jetpack);
		if (i != -1)
		{
			static OGLPoint3D	sparkleOff[2] =
			{
				{21.21, 19.068, 21.183},
				{-21.21, 19.068, 21.183},
			};

			gSparkles[i].flags = SPARKLE_FLAG_OMNIDIRECTIONAL  | SPARKLE_FLAG_TRANSFORMWITHOWNER;
			gSparkles[i].where = sparkleOff[j];

			gSparkles[i].color.r = 1;
			gSparkles[i].color.g = 1;
			gSparkles[i].color.b = 1;
			gSparkles[i].color.a = 1;

			gSparkles[i].scale 	= 30.0f;
			gSparkles[i].separation = .0f;

			gSparkles[i].textureNum = PARTICLE_SObjType_GreenGlint;
		}
	}

}



/********************** FREE LEVEL INTRO SCREEN **********************/

static void FreeLevelIntroScreen(void)
{
	StopAllEffectChannels();
	MyFlushEvents();
	DeleteAllObjects();
	FreeAllSkeletonFiles(-1);
	InitSparkles();				// this will actually delete all the sparkles
	DisposeAllSpriteGroups();
	DisposeSpriteAtlas(SPRITE_GROUP_FONT);
	DisposeAllBG3DContainers();
	OGL_DisposeGameView();

}

#pragma mark -

/*************** MOVE INTRO STAR DOME *******************/

static void MoveIntroStarDome(ObjNode *theNode)
{
	theNode->Rot.z += gFramesPerSecondFrac * .6f;

	UpdateObjectTransforms(theNode);

}


/******************* MOVE LEVEL INTRO NANO *********************/

static void MoveLevelIntroNano(ObjNode *theNode)
{
OGLVector3D	v;
OGLPoint3D	p;

	theNode->Coord = gWormholeDeformPoints[1];

	OGLPoint3D_Subtract(&gWormholeDeformPoints[4], &gWormholeDeformPoints[8], &v);
	OGLVector3D_Normalize(&v, &v);

	SetAlignmentMatrix(&theNode->AlignmentMatrix, &v);

	UpdateObjectTransforms(theNode);


	p.x = theNode->Coord.x * .5f;
	p.y = theNode->Coord.y * .5f;
	p.z = theNode->Coord.z - 500.0f;

	OGL_UpdateCameraFromTo(&gGameViewInfoPtr->cameraPlacement[0].cameraLocation, &p, 0);

}



/********************* MOVE LEVEL INTRO WORM *********************/

static void MoveLevelIntroWorm(ObjNode *theNode)
{
	UpdateLevelIntroWormJoints(theNode);

	theNode->TextureTransformU += gFramesPerSecondFrac * .6f;
	theNode->TextureTransformV -= gFramesPerSecondFrac * .9f;

}


/********************* UPDATE LEVEL INTROWORM JOINTS *************************/

static void UpdateLevelIntroWormJoints(ObjNode *theNode)
{
SkeletonObjDataType	*skeleton = theNode->Skeleton;
SkeletonDefType		*skeletonDef;
short				jointNum, numJoints;
float				z, fps = gFramesPerSecondFrac;
float				scale, w;
static float		waveX = 0, waveY = 1.0;

	skeletonDef = skeleton->skeletonDefinition;

	numJoints = skeletonDef->NumBones;								// get # joints in this skeleton

	scale = theNode->Scale.x;


				/***************************/
				/* BUILD JOINT COORD TABLE */
				/***************************/

	waveX += fps * .5f;
	waveY += fps * 2.0f;

	z = 0;
	w = 0;
	for (jointNum = 0; jointNum < numJoints; jointNum++)
	{
		float	q;

		q = (float)jointNum * 80.0f;							// gets more wiggly the farther down the skeleton we go

		gWormholeDeformPoints[jointNum].x = sin(waveX + w) * q;
		gWormholeDeformPoints[jointNum].y = sin(waveY + w) * q;
		gWormholeDeformPoints[jointNum].z = z;

		w += .16f;
		z -= 350.0f;
	}

			/***************************************/
			/* TRANSFORM EACH JOINT TO WORLD-SPACE */
			/***************************************/

	for (jointNum = 0; jointNum < numJoints; jointNum++)
	{
		OGLPoint3D		coord,prevCoord;
		OGLMatrix4x4	m2, m, m3;
		static const OGLVector3D up = {0,1,0};


				/* GET COORDS OF THIS SEGMENT */

		coord = gWormholeDeformPoints[jointNum];


			/* GET PREVIOUS COORD FOR ROTATION CALCULATION */

		if (jointNum > 0)
			prevCoord = gWormholeDeformPoints[jointNum-1];


				/* TRANSFORM JOINT'S MATRIX TO WORLD COORDS */

		OGLMatrix4x4_SetScale(&m, scale, scale, scale);

		if (jointNum > 0)
		{
			SetLookAtMatrix(&m2, &up, &prevCoord, &coord);
			OGLMatrix4x4_Multiply(&m, &m2, &m3);
		}
		else
			m3 = m;

		OGLMatrix4x4_SetTranslate(&m, coord.x, coord.y, coord.z);
		OGLMatrix4x4_Multiply(&m3, &m, &skeleton->jointTransformMatrix[jointNum]);
	}
}


#pragma mark -

/************************ MAKE LEVEL INTRO SAVE SPRITES ************************/

static void MakeLevelIntroSaveSprites(void)
{
	static const MenuItem saveMenuTree[] =
	{
		{ .id='lvin'},
		{ .type=kMIPick, .text=STR_SAVE_GAME, .next='save' },
		{ .type=kMIPick, .text=STR_CONTINUE_WITHOUT_SAVING, .id='nosv', .next='EXIT' },

		{ .id=0 }
	};


	MenuStyle style = kDefaultMenuStyle;
	style.yOffset = 400;
	style.standardScale *= 0.75f;
	style.rowHeight *= 0.75f;
	MakeMenu(saveMenuTree, &style);

	RegisterFileScreen(FILESCREEN_MODE_SAVE);

	MakeMouseCursorObject();
}


/******************** MOVE PRESS ANY KEY TEXT *************************/

static void MovePressAnyKey(ObjNode* theNode)
{
	theNode->Timer += gFramesPerSecondFrac * 4.0f;
	theNode->ColorFilter.a = 0.66f + sinf(theNode->Timer) * 0.33f;
}

