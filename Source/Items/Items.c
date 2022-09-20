/****************************/
/*   		ITEMS.C		    */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/


#include "game.h"

extern	float				gFramesPerSecondFrac,gFramesPerSecond,gTerrainPolygonSize;
extern	OGLPoint3D			gCoord;
extern	OGLVector3D			gDelta;
extern	NewObjectDefinitionType	gNewObjectDefinition;
extern	OGLBoundingBox 		gObjectGroupBBoxList[MAX_BG3D_GROUPS][MAX_OBJECTS_IN_GROUP];
extern	OGLSetupOutputType	*gGameViewInfoPtr;
extern	u_long				gAutoFadeStatusBits,gGlobalMaterialFlags;
extern	SparkleType	gSparkles[MAX_SPARKLES];
extern	short				gNumEnemies;
extern	SpriteType	*gSpriteGroupList[];
extern	AGLContext		gAGLContext;
extern	Byte				gCurrentSplitScreenPane;


/****************************/
/*    PROTOTYPES            */
/****************************/

static void CreateCloudLayer(void);
static void DrawCloudLayer(ObjNode *theNode, const OGLSetupOutputType *setupInfo);
static void MoveCloudLayer(ObjNode *theNode);
static void MoveGasMound(ObjNode *theNode);



/****************************/
/*    CONSTANTS             */
/****************************/


#define	LEAF_DEFAULT_WOBBLE_MAG		4.0f
#define	LEAF_DEFAULT_WOBBLE_SPEED	1.0f

/*********************/
/*    VARIABLES      */
/*********************/


static OGLVector2D	gCloudScroll;


/********************* INIT ITEMS MANAGER *************************/

void InitItemsManager(void)
{
	InitForestDoors();
	InitZaps();
	InitWormholes();
	InitDustDevilMemory();

	CreateCyclorama();
	CreateCloudLayer();

			/* UPDATE SONG */

//	if (gSongMovie)
//		MoviesTask(gSongMovie, 0);

}


/************************* CREATE CYCLORAMA *********************************/

void CreateCyclorama(void)
{
ObjNode	*newObj;

	gNewObjectDefinition.group	= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 	= 0;								// cyc is always 1st model in level bg3d files
	gNewObjectDefinition.coord.x = 0;
	gNewObjectDefinition.coord.y = 0;
	gNewObjectDefinition.coord.z = 0;
	gNewObjectDefinition.flags 	= STATUS_BIT_DONTCULL|STATUS_BIT_NOLIGHTING|STATUS_BIT_NOFOG; //|STATUS_BIT_NOZWRITES;
	gNewObjectDefinition.slot 	= TERRAIN_SLOT+1;					// draw after terrain for better performance since terrain blocks much of the pixels
	gNewObjectDefinition.moveCall = nil;
	gNewObjectDefinition.rot 	= 0;
	gNewObjectDefinition.scale 	= gGameViewInfoPtr->yon * .01;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	newObj->CustomDrawFunction = DrawCyclorama;

//	newObj->ColorFilter.r =
//	newObj->ColorFilter.g =
//	newObj->ColorFilter.b = .8;
}


/********************** DRAW CYCLORAMA *************************/

void DrawCyclorama(ObjNode *theNode, const OGLSetupOutputType *setupInfo)
{
OGLPoint3D cameraCoord = setupInfo->cameraPlacement[gCurrentSplitScreenPane].cameraLocation;

	glDisable(GL_ALPHA_TEST);	//--------


		/* UPDATE CYCLORAMA COORD INFO */

	theNode->Coord.x = cameraCoord.x;
	theNode->Coord.y = cameraCoord.y;
	theNode->Coord.z = cameraCoord.z;
	UpdateObjectTransforms(theNode);


			/* DRAW THE OBJECT */

	MO_DrawObject(theNode->BaseGroup, setupInfo);

	glEnable(GL_ALPHA_TEST);	//--------

}




/************************* CREATE CLOUD LAYER *********************************/

static void CreateCloudLayer(void)
{
ObjNode	*newObj;

	if (gGamePrefs.lowRenderQuality)			// don't do cloulds in low-quality mode
		return;

	gNewObjectDefinition.group	= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 	= LEVEL1_ObjType_CloudGrid;
	gNewObjectDefinition.coord.x = 0;
	gNewObjectDefinition.coord.y = 0;
	gNewObjectDefinition.coord.z = 0;
	gNewObjectDefinition.flags 	= STATUS_BIT_DONTCULL|STATUS_BIT_NOLIGHTING|STATUS_BIT_NOFOG|
									STATUS_BIT_DOUBLESIDED | STATUS_BIT_NOZWRITES;
	gNewObjectDefinition.slot 	= TERRAIN_SLOT+2;					 // draw after sky dome
	gNewObjectDefinition.moveCall = MoveCloudLayer;
	gNewObjectDefinition.rot 	= 0;
	gNewObjectDefinition.scale 	= gGameViewInfoPtr->yon * .85f;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	newObj->CustomDrawFunction = DrawCloudLayer;

	newObj->TextureTransformU =
	newObj->TextureTransformV = 0;

}


/******************* MOVE CLOUD LAYER *********************/

static void MoveCloudLayer(ObjNode *theNode)
{
#pragma unused (theNode)

	gCloudScroll.x += gFramesPerSecondFrac * .02f;
	gCloudScroll.y += gFramesPerSecondFrac * .03f;
}


/********************** DRAW CLOUD LAYER *************************/

static void DrawCloudLayer(ObjNode *theNode, const OGLSetupOutputType *setupInfo)
{
OGLPoint3D cameraCoord = setupInfo->cameraPlacement[gCurrentSplitScreenPane].cameraLocation;

	glDisable(GL_ALPHA_TEST);	//--------

		/* UPDATE CYCLORAMA COORD INFO */

	theNode->Coord.x = cameraCoord.x;
	theNode->Coord.y = 4000;
	theNode->Coord.z = cameraCoord.z;
	UpdateObjectTransforms(theNode);

		/* UPDATE SCROLLING */

	theNode->TextureTransformU = cameraCoord.x * .0001 + gCloudScroll.x;
	theNode->TextureTransformV = cameraCoord.z * -.0001 + gCloudScroll.y;

	glMatrixMode(GL_TEXTURE);					// set texture matrix
	glTranslatef(theNode->TextureTransformU, theNode->TextureTransformV, 0);
	glMatrixMode(GL_MODELVIEW);


			/* DRAW THE OBJECT */

	MO_DrawObject(theNode->BaseGroup, setupInfo);



				/* RESET UV MATRIX */

	glMatrixMode(GL_TEXTURE);
	glLoadIdentity();
	glMatrixMode(GL_MODELVIEW);

	glEnable(GL_ALPHA_TEST);	//--------

}


#pragma mark -




/************************* ADD ROCK *********************************/

Boolean AddRock(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*newObj;
short	base;
long	rot = itemPtr->parm[1];

	switch(gLevelNum)
	{
		case	LEVEL_NUM_ADVENTURE1:
		case	LEVEL_NUM_FLAG2:
		case	LEVEL_NUM_BATTLE1:
				base = 	LEVEL1_ObjType_Rock1;
				break;

		case	LEVEL_NUM_ADVENTURE2:
		case	LEVEL_NUM_RACE2:
		case	LEVEL_NUM_BATTLE2:
				base = 	LEVEL2_ObjType_Rock_Small1;
				break;

		default:
				DoFatalAlert("AddRock: brian needs to assign rocks to this level");
				return(false);
	}

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= base + itemPtr->parm[0];
	gNewObjectDefinition.scale 		= 2.0 + RandomFloat2() * .3f;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= GetMinTerrainY(x,z, gNewObjectDefinition.group, gNewObjectDefinition.type, gNewObjectDefinition.scale) -
									 gObjectGroupBBoxList[gNewObjectDefinition.group][gNewObjectDefinition.type].min.y;
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits;
	gNewObjectDefinition.slot 		= 491;
	gNewObjectDefinition.moveCall 	= MoveStaticObject;
	if (rot == 0)
		gNewObjectDefinition.rot 	= RandomFloat()*PI2;
	else
		gNewObjectDefinition.rot 	= (float)(rot-1) * (PI2/8.0f);
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list



			/* SET COLLISION STUFF */

	newObj->CType 			= CTYPE_SOLIDTOENEMY | CTYPE_PLAYERTEST | CTYPE_WEAPONTEST;
	newObj->CBits			= CBITS_ALLSOLID;
	CreateCollisionBoxFromBoundingBox_Rotated(newObj, .7, .8);


	return(true);													// item was added
}

/************************* ADD RIVER ROCK *********************************/

Boolean AddRiverRock(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*newObj;

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= LEVEL1_ObjType_RiverRock1 + itemPtr->parm[0];
	gNewObjectDefinition.scale 		= 2.0 + RandomFloat2() * .3f;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= GetMinTerrainY(x,z, gNewObjectDefinition.group, gNewObjectDefinition.type, gNewObjectDefinition.scale) -
									 gObjectGroupBBoxList[gNewObjectDefinition.group][gNewObjectDefinition.type].min.y;
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits;
	gNewObjectDefinition.slot 		= 491;
	gNewObjectDefinition.moveCall 	= MoveStaticObject;
	gNewObjectDefinition.rot 		= RandomFloat()*PI2;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list



			/* SET COLLISION STUFF */

	newObj->CType 			= CTYPE_SOLIDTOENEMY | CTYPE_PLAYERTEST | CTYPE_WEAPONTEST;
	newObj->CBits			= CBITS_ALLSOLID;
	CreateCollisionBoxFromBoundingBox_Rotated(newObj, 1, 1);


	return(true);													// item was added
}


#pragma mark -


/************************* ADD GAS MOUND *********************************/

Boolean AddGasMound(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*newObj;


	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= LEVEL1_ObjType_GasMound1 + itemPtr->parm[0];
	gNewObjectDefinition.scale 		= 3.0 + RandomFloat2() * .3f;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= GetMinTerrainY(x,z, gNewObjectDefinition.group, gNewObjectDefinition.type, gNewObjectDefinition.scale) -
									 gObjectGroupBBoxList[gNewObjectDefinition.group][gNewObjectDefinition.type].min.y;
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits;
	gNewObjectDefinition.slot 		= 197;
	gNewObjectDefinition.moveCall 	= MoveGasMound;
	gNewObjectDefinition.rot 		= RandomFloat()*PI2;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list

	newObj->Kind = itemPtr->parm[0];

			/* SET COLLISION STUFF */

	newObj->CType 			= CTYPE_SOLIDTOENEMY | CTYPE_PLAYERTEST | CTYPE_WEAPONTEST;
	newObj->CBits			= CBITS_ALLSOLID;
	CreateCollisionBoxFromBoundingBox_Rotated(newObj, 1, 1);


	return(true);													// item was added
}



/****************** MOVE GAS MOUND ****************************/

static void MoveGasMound(ObjNode *theNode)
{
int		i;
float	fps = gFramesPerSecondFrac;
int		particleGroup,magicNum;
NewParticleGroupDefType	groupDef;
NewParticleDefType	newParticleDef;
OGLVector3D			d;
OGLPoint3D			p;

	if (TrackTerrainItem(theNode))							// just check to see if it's gone
	{
		DeleteObject(theNode);
		return;
	}



	/* SEE IF SMOKE HITS PLAYER */

	for (i = 0; i < gNumPlayers; i++)
	{
		if (!gPlayerIsDead[i])								// ingore dead players
		{
			float   dist = CalcQuickDistance(theNode->Coord.x, theNode->Coord.z, gPlayerInfo[i].coord.x, gPlayerInfo[i].coord.z);

			if (dist < 150.0f)
			{
				dist = gPlayerInfo[i].coord.y - theNode->Coord.y;
				if (dist < 700.0f)
				{
					if (gPlayerInfo[i].objNode->Skeleton->AnimNum != PLAYER_ANIM_DISORIENTED)		// play effect on 1st hit
						PlayEffect3D(EFFECT_BODYHIT, &gPlayerInfo[i].coord);

					PlayerLoseHealth(i, fps * .1f, PLAYER_DEATH_TYPE_DEATHDIVE, nil, true);
				}
			}
		}
	}


		/**************/
		/* MAKE SMOKE */
		/**************/

	theNode->ParticleTimer -= fps;											// see if add smoke
	if (theNode->ParticleTimer <= 0.0f)
	{
		theNode->ParticleTimer += .05;										// reset timer

		particleGroup 	= theNode->ParticleGroup;
		magicNum 		= theNode->ParticleMagicNum;

		if ((particleGroup == -1) || (!VerifyParticleGroupMagicNum(particleGroup, magicNum)))
		{
			theNode->ParticleMagicNum = magicNum = MyRandomLong();			// generate a random magic num

			groupDef.magicNum				= magicNum;
			groupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
			groupDef.flags					= PARTICLE_FLAGS_DONTCHECKGROUND;
			groupDef.gravity				= 100;
			groupDef.magnetism				= 0;
			groupDef.baseScale				= 15.0f;
			groupDef.decayRate				=  -2.5f;
			groupDef.fadeRate				= .25;
			groupDef.particleTextureNum		= PARTICLE_SObjType_GasCloud;
			groupDef.srcBlend				= GL_SRC_ALPHA;
			groupDef.dstBlend				= GL_ONE_MINUS_SRC_ALPHA;
			theNode->ParticleGroup = particleGroup = NewParticleGroup(&groupDef);
		}

		if (particleGroup != -1)
		{
			float	x,y,z;
			const OGLPoint3D ventOff[3] =
			{
				{2.163, 125.091, -1.907},
				{19.385, 69.243, 2.243},
				{5.189, 22.168, -5.504}
			};

			OGLPoint3D_Transform(&ventOff[theNode->Kind], &theNode->BaseTransformMatrix, &p);

			x = p.x;
			y = p.y;
			z = p.z;

			for (i = 0; i < 2; i++)
			{
				p.x = x + RandomFloat2() * 15.0f;
				p.y = y + RandomFloat() * 10.0f;
				p.z = z + RandomFloat2() * 15.0f;

				d.x = RandomFloat2() * 30.0f;
				d.y = 300.0f + RandomFloat() * 150.0f;
				d.z = RandomFloat2() * 30.0f;

				newParticleDef.groupNum		= particleGroup;
				newParticleDef.where		= &p;
				newParticleDef.delta		= &d;
				newParticleDef.scale		= RandomFloat() + 1.0f;
				newParticleDef.rotZ			= RandomFloat() * PI2;
				newParticleDef.rotDZ		= RandomFloat2() * 2.0f;
				newParticleDef.alpha		= .6;
				if (AddParticleToGroup(&newParticleDef))
				{
					theNode->ParticleGroup = -1;
					break;
				}
			}
		}
	}


}



#pragma mark -

/******************** TRIGGER CALLBACK:  MISC SMACKABLE OBJECT ************************/
//
// Returns TRUE if want to handle hit as a solid
//

Boolean DoTrig_MiscSmackableObject(ObjNode *trigger, ObjNode *theNode)
{
	if (PlayerSmackedIntoObject(theNode, trigger, PLAYER_DEATH_TYPE_EXPLODE))
		return(false);

	return(true);
}



#pragma mark -

/************************* ADD ASTEROID *********************************/

Boolean AddAsteroid(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*newObj;


	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= LEVEL3_ObjType_Asteroid_Cracked + itemPtr->parm[0];
	gNewObjectDefinition.scale 		= 4.0 + RandomFloat2() * 1.0f;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= GetMinTerrainY(x,z, gNewObjectDefinition.group, gNewObjectDefinition.type, gNewObjectDefinition.scale) -
									 gObjectGroupBBoxList[gNewObjectDefinition.group][gNewObjectDefinition.type].min.y;
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits;
	gNewObjectDefinition.slot 		= 197;
	gNewObjectDefinition.moveCall 	= nil;
	gNewObjectDefinition.rot 		= RandomFloat()*PI2;
	newObj = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list

	newObj->Kind = itemPtr->parm[0];

			/* SET COLLISION STUFF */

	newObj->CType 			= CTYPE_SOLIDTOENEMY | CTYPE_PLAYERTEST | CTYPE_WEAPONTEST;
	newObj->CBits			= CBITS_ALLSOLID;
	CreateCollisionBoxFromBoundingBox_Rotated(newObj, 1, 1);


	return(true);													// item was added
}


























