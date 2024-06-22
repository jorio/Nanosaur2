/****************************/
/*   LEVEL INTRO SCREEN.C   */
/* By Brian Greenstone      */
/* (c)2003 Pangea Software  */
/* (c)2022 Iliyas Jorio     */
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
static void MakeLevelIntroStarDome(void);
static void MoveIntroStarDome(ObjNode *theNode);
static void MakeLevelIntroSaveSprites(void);
static void SetupScreensaverObjects(void);
static void SetupCreditsObjects(void);
static void MovePressAnyKey(ObjNode* theNode);
static void MoveCreditsLine(ObjNode* theNode);
static void DrawBottomGradient(ObjNode* theNode);


/****************************/
/*    CONSTANTS             */
/****************************/

#define kCreditLineDuration		3.5f
#define kCreditLinePause		0.5f
#define kCreditFirstDelay		1.0f
#define kCreditFadeInTime		0.2f
#define kCreditFadeOutTime		0.3f

static struct
{
	const char* role;
	const char* name;
}
kCreditsText[] =
{
	{ "PROGRAMMING & DESIGN", "Brian Greenstone" },
	{ "ART & DESIGN", "Scott Harper" },
	{ "MUSIC", "Aleksander Dimitrijevic" },
	{ "ANIMATION", "Peter Greenstone" },
	{ "ILLUSTRATOR", "Rich Bonk" },
	{ "COLORIST", "Ben Prenevost" },
	{ "ADDITIONAL PROGRAMMING", "Iliyas Jorio" },
	{ 0 },
};

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
	MakeFadeEvent(kFadeFlags_In, 1.5);


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
			case	INTRO_MODE_CREDITS:
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

	if (IsStereo())
	{
		gAnaglyphFocallength	= 300.0f;
		gAnaglyphEyeSeparation 	= 20.0f;

		if (IsStereoAnaglyph())
		{
			viewDef.lights.ambientColor = (OGLColorRGBA) {.8f, .8f, .8f, 1.0f};
		}
	}


	OGL_SetupGameView(&viewDef);


				/************/
				/* LOAD ART */
				/************/

	InitParticleSystem();
	InitSparkles();

			/* LOAD MODELS */

	FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ":Models:playerparts.bg3d", &spec);
	ImportBG3D(&spec, MODEL_GROUP_PLAYER, VERTEX_ARRAY_RANGE_TYPE_BG3DMODELS);

	FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, ":Models:levelintro.bg3d", &spec);
	ImportBG3D(&spec, MODEL_GROUP_LEVELINTRO, VERTEX_ARRAY_RANGE_TYPE_BG3DMODELS);


			/* LOAD SPRITES */

	LoadSpriteGroupFromFile(SPRITE_GROUP_LEVELSPECIFIC, ":Sprites:menu:nanologo", 0);


			/* LOAD SKELETONS */

	LoadASkeleton(SKELETON_TYPE_BONUSWORMHOLE);
	LoadASkeleton(SKELETON_TYPE_PLAYER);



			/*****************/
			/* MAKE WORMHOLE */
			/*****************/

	NewObjectDefinitionType wormholeDef =
	{
		.type		= SKELETON_TYPE_BONUSWORMHOLE,
		.animNum	= 0,
		.coord.x	= 0.0f,
		.coord.y	= 0,
		.coord.z	= 0,
		.flags		= STATUS_BIT_DONTCULL | STATUS_BIT_DOUBLESIDED | STATUS_BIT_UVTRANSFORM | STATUS_BIT_GLOW | STATUS_BIT_NOZWRITES | STATUS_BIT_NOLIGHTING,
		.slot		= 100,
		.moveCall	= MoveLevelIntroWorm,
		.rot		= 0,
		.scale		= 26,
	};

	newObj = MakeNewSkeletonObject(&wormholeDef);
	newObj->Skeleton->JointsAreGlobal = true;
	UpdateObjectTransforms(newObj);
	UpdateLevelIntroWormJoints(newObj);

	if (gIntroMode != INTRO_MODE_SCREENSAVER && gIntroMode != INTRO_MODE_CREDITS)
		PlayEffect_Parms(EFFECT_WORMHOLE, FULL_CHANNEL_VOLUME/2, FULL_CHANNEL_VOLUME/3, NORMAL_CHANNEL_RATE);


			/***************/
			/* MAKE PLAYER */
			/***************/

	MakeLevelIntroWormNano();


			/******************/
			/* MAKE STAR DOME */
			/******************/

	MakeLevelIntroStarDome();


			/*********************/
			/* DO MODE SPECIFICS */
			/*********************/

	switch(gIntroMode)
	{
		case	INTRO_MODE_SAVEGAME:
				MakeLevelIntroSaveSprites();
				break;

		case	INTRO_MODE_SCREENSAVER:
				SetupScreensaverObjects();
				break;

		case	INTRO_MODE_CREDITS:
				SetupCreditsObjects();
				break;
	}
}




/******************* MAKE LEVEL INTRO WORM PLAYER **********************/

static void MakeLevelIntroWormNano(void)
{
ObjNode	*newObj, *jetpack, *blue;
short	i, j;

			/* MAKE SKELETON */

	NewObjectDefinitionType def =
	{
		.type		= SKELETON_TYPE_PLAYER,
		.animNum	= PLAYER_ANIM_FLAP,
		.flags		= STATUS_BIT_NOTEXTUREWRAP | STATUS_BIT_USEALIGNMENTMATRIX,
		.slot		= 200,
		.moveCall	= MoveLevelIntroNano,
		.rot		= 0,
		.scale		= .6,
	};

	newObj = MakeNewSkeletonObject(&def);

	newObj->Skeleton->AnimSpeed = 2.0f;

	MoveLevelIntroNano(newObj);								// prime it


		/*****************/
		/* MAKE JETPACK  */
		/*****************/

	def.group 		= MODEL_GROUP_PLAYER;
	def.type 		= PLAYER_ObjType_JetPack;
	def.flags 		= 0;
	def.slot		= SLOT_OF_DUMB;
	def.moveCall 	= MovePlayerJetpack;
	jetpack = MakeNewDisplayGroupObject(&def);

	newObj->ChainNode = jetpack;
	jetpack->ChainHead = newObj;

		/* BLUE THING */

	def.type 		= PLAYER_ObjType_JetPackBlue;
	def.flags 		= STATUS_BIT_UVTRANSFORM | STATUS_BIT_GLOW | STATUS_BIT_NOLIGHTING;
	def.slot		= SLOT_OF_DUMB + 1;
	def.moveCall 	= nil;
	blue = MakeNewDisplayGroupObject(&def);

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


/******************* MAKE LEVEL INTRO STAR DOME **********************/

static void MakeLevelIntroStarDome(void)
{
	int width = 0;
	int height = 0;
	GLuint textureName = OGL_TextureMap_LoadImageFile(":Sprites:textures:stardome", &width, &height, NULL);
	MOMaterialData matData =
	{
		.flags				= BG3D_MATERIALFLAG_TEXTURED,
		.diffuseColor		= {1,1,1,1},
		.numMipmaps			= 1,
		.width				= width,
		.height				= height,
		.textureName[0] 	= textureName,
	};
	MOMaterialObject* matRef = MO_CreateNewObjectOfType(MO_TYPE_MATERIAL, 0, &matData);//MO_GetNewReference(matData);

	NewObjectDefinitionType def =
	{
		.genre	= QUADMESH_GENRE,
		.coord.x = 0,
		.coord.y = 0,
		.coord.z = -5500,
		.flags 	= STATUS_BIT_DONTCULL|STATUS_BIT_NOLIGHTING|STATUS_BIT_NOFOG|STATUS_BIT_DOUBLESIDED|STATUS_BIT_NOZBUFFER,
		.slot 	= 0,
		.moveCall = MoveIntroStarDome,
		.rot 	= 0,
		.scale 	= 10000,
	};
	ObjNode* stardome = MakeQuadMeshObject(&def, 1, matRef);
	MOVertexArrayData* stardomeVAD = GetQuadMeshWithin(stardome);
	stardomeVAD->numPoints = 4;
	stardomeVAD->numTriangles = 2;
	stardomeVAD->points[0] = (OGLPoint3D) {-1, -1, 0};
	stardomeVAD->points[1] = (OGLPoint3D) { 1, -1, 0};
	stardomeVAD->points[2] = (OGLPoint3D) { 1,  1, 0};
	stardomeVAD->points[3] = (OGLPoint3D) {-1,  1, 0};
	stardomeVAD->uvs[0][0] = (OGLTextureCoord) {0, 0};
	stardomeVAD->uvs[0][1] = (OGLTextureCoord) {6, 0};
	stardomeVAD->uvs[0][2] = (OGLTextureCoord) {6, 6};
	stardomeVAD->uvs[0][3] = (OGLTextureCoord) {0, 6};

	MO_DisposeObjectReference(matRef);
}


/********************** FREE LEVEL INTRO SCREEN **********************/

static void FreeLevelIntroScreen(void)
{
	StopAllEffectChannels();
	MyFlushEvents();
	DeleteAllObjects();
	FreeAllSkeletonFiles(-1);
	InitSparkles();				// this will actually delete all the sparkles
	DisposeSpriteGroup(SPRITE_GROUP_LEVELSPECIFIC);
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

int GetLevelSpecificMenuLayoutFlags(const MenuItem* mi)
{
	int id = mi->id;
	if ((gLevelNum == 1 && id == 'lvl1') || (gLevelNum == 2 && id == 'lvl2'))
	{
		return 0;
	}
	return kMILayoutFlagHidden | kMILayoutFlagDisabled;
}

static void MakeLevelIntroSaveSprites(void)
{
	static const MenuItem saveMenuTree[] =
	{
		{ .id='lvin'},
		{ .type=kMIPick, .text=STR_SAVE_GAME, .next='save', .customHeight=1, },
		{ .type=kMIPick, .text=STR_CONTINUE_WITHOUT_SAVING, .customHeight=1, .id='nosv', .next='EXIT' },

		{.id='save'},
		{kMILabel, .text=STR_ENTERING_LEVEL_2, .id='lvl1', .getLayoutFlags=GetLevelSpecificMenuLayoutFlags},
		{kMILabel, .text=STR_ENTERING_LEVEL_3, .id='lvl2', .getLayoutFlags=GetLevelSpecificMenuLayoutFlags},
		{kMIFileSlot, STR_FILE, .id='sf#0', .fileSlot=0, .next='EXIT'},
		{kMIFileSlot, STR_FILE, .id='sf#1', .fileSlot=1, .next='EXIT'},
		{kMIFileSlot, STR_FILE, .id='sf#2', .fileSlot=2, .next='EXIT'},
		{kMIFileSlot, STR_FILE, .id='sf#3', .fileSlot=3, .next='EXIT'},
		{kMIFileSlot, STR_FILE, .id='sf#4', .fileSlot=4, .next='EXIT'},
		{kMIPick, STR_CONTINUE_WITHOUT_SAVING, .id='nosv', .next='EXIT' },
		{kMISpacer, .customHeight=1.5f},

		{ .id=0 }
	};


	MenuStyle style = kDefaultMenuStyle;
	style.darkenPaneOpacity = 0.6f;
	style.yOffset = 400;
	style.standardScale *= 0.75f;
	style.rowHeight *= 0.75f;
	MakeMenu(saveMenuTree, &style);

	MakeMouseCursorObject();
}

/************************ MAKE SCREENSAVER OBJECTS ************************/

static void SetupScreensaverObjects(void)
{
	ObjNode* newObj;

			/* PRESS ANY KEY */

	NewObjectDefinitionType textDef =
	{
		.group		= ATLAS_GROUP_FONT1,
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
		.group		= SPRITE_GROUP_LEVELSPECIFIC,
		.type		= MAINMENU_SObjType_NanoLogo,
		.coord		= {20, 0, 0},
		.slot		= SPRITE_SLOT,
		.scale		= 150,
	};
	newObj = MakeSpriteObject(&logoDef, false);
	newObj->AnaglyphZ = 6.0f;
}

/************************ MAKE CREDITS OBJECTS ************************/

static void SetupCreditsObjects(void)
{
		/* MAKE GRADIENT SO TEXT IS MORE READABLE */

	NewObjectDefinitionType gradientDef =
	{
		.genre		= CUSTOM_GENRE,
		.coord		= {0, 0, 0},
		.slot		= 150,		// between wormhole and nano
		.scale		= 1,
		.drawCall	= DrawBottomGradient,
	};
	MakeNewObject(&gradientDef);

		/* MAKE TEXT */

	float delay = kCreditFirstDelay;

	for (int i = 0; kCreditsText[i].role; i++)
	{
		NewObjectDefinitionType textDef =
		{
			.group		= ATLAS_GROUP_FONT2,
			.coord		= {640/2, 400, 0},
			.slot		= SPRITE_SLOT,
			.scale		= 0.4f,
			.moveCall	= MoveCreditsLine,
		};

		ObjNode* objs[2];

		objs[0] = TextMesh_New(kCreditsText[i].role, kTextMeshAlignCenter, &textDef);
		objs[0]->AnaglyphZ = 6.0f;
		objs[0]->ColorFilter = (OGLColorRGBA) {1,0.6,0.2,1};

		textDef.group = ATLAS_GROUP_FONT1;
		textDef.coord.y += 32;
		textDef.scale = 0.6f;
		objs[1] = TextMesh_New(kCreditsText[i].name, kTextMeshAlignCenter | kTextMeshSmallCaps, &textDef);
		objs[1]->AnaglyphZ = 6.0f;

		for (int j = 0; j < 2; j++)
		{
			objs[j]->ColorFilter.a = 0;
			objs[j]->Timer = -delay;
		}

		delay += kCreditLineDuration + kCreditLinePause;
	}

		/* MAKE END LOGO */

	NewObjectDefinitionType logoDef =
	{
		.group		= SPRITE_GROUP_LEVELSPECIFIC,
		.type		= MAINMENU_SObjType_NanoLogo,
		.coord		= {640/2, 400+15, 0},
		.slot		= SPRITE_SLOT,
		.scale		= 250,
		.moveCall	= MoveCreditsLine,
	};
	ObjNode* logo = MakeSpriteObject(&logoDef, true);
	logo->AnaglyphZ = 6.0f;
	logo->Timer = -delay;
	logo->Flag[0] = true;
	logo->ColorFilter.a = 0;
}


/******************** MOVE PRESS ANY KEY TEXT *************************/

static void MovePressAnyKey(ObjNode* theNode)
{
	theNode->Timer += gFramesPerSecondFrac * 4.0f;
	theNode->ColorFilter.a = 0.66f + sinf(theNode->Timer) * 0.33f;
}


/******************** MOVE CREDITS LINE *************************/

static void MoveCreditsLine(ObjNode* theNode)
{
	theNode->Timer += gFramesPerSecondFrac;
	float t = theNode->Timer;

	Boolean liveForever = theNode->Flag[0];

	if (t <= 0.0f)
	{
		SetObjectVisible(theNode, false);
	}
	else if (!liveForever && t >= kCreditLineDuration)
	{
		DeleteObject(theNode);
		return;
	}
	else
	{
		SetObjectVisible(theNode, true);

		float a;
		if (t < kCreditFadeInTime)
		{
			a = t / kCreditFadeInTime;
		}
		else if (!liveForever && t > kCreditLineDuration - kCreditFadeOutTime)
		{
			a = 1 - (t - kCreditLineDuration + kCreditFadeOutTime) / kCreditFadeOutTime;
		}
		else
		{
			a = 1;
		}

		theNode->ColorFilter.a = a;
	}
}

/******************** MOVE CREDITS LINE *************************/

static void DrawBottomGradient(ObjNode* theNode)
{
	(void) theNode;

	OGL_PushState();
	SetInfobarSpriteState(0, 1);
	OGL_DisableTexture2D();
	OGL_EnableBlend();

	float y = 200;
	glBegin(GL_QUADS);
	glColor4f(0,0,0,0); glVertex2f(gLogicalRect.left, y); glVertex2f(gLogicalRect.right, y);
	glColor4f(0,0,0,1); glVertex2f(gLogicalRect.right, gLogicalRect.bottom); glVertex2f(gLogicalRect.left, gLogicalRect.bottom);
	glEnd();
	OGL_PopState();
}
