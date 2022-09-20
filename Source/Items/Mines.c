/****************************/
/*   	MINES.C			    */
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

static void MoveAirMine(ObjNode *base);
static Boolean DoTrig_AirMine(ObjNode *mine, ObjNode *player);
static void ExplodeAirMine(ObjNode *mine);
static Boolean AirMineHitByWeaponCallback(ObjNode *bullet, ObjNode *mine, OGLPoint3D *hitCoord, OGLVector3D *hitTriangleNormal);
static void MoveAirMineFlareBall(ObjNode *flare);


/****************************/
/*    CONSTANTS             */
/****************************/

#define	AIRMINE_SCALE	1.2f


/*********************/
/*    VARIABLES      */
/*********************/

#define	WobbleX		SpecialF[0]


/************************* ADD AIR MINE *********************************/

Boolean AddAirMine(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*base, *mine, *chain;
short	typeB, typeM, typeC;
float	chainOff;
long	h = itemPtr->parm[0];

	if (h != 0)
	{
		h = 10-h;
		if (h < 0)
			h = 0;
	}

	switch(gLevelNum)
	{
		case	LEVEL_NUM_ADVENTURE1:
		case	LEVEL_NUM_FLAG2:
		case	LEVEL_NUM_BATTLE1:
				typeB = LEVEL1_ObjType_AirMine_Base;
				typeM = LEVEL1_ObjType_AirMine_Mine;
				typeC = LEVEL1_ObjType_AirMine_Chain;
				if (h == 0)
					chainOff = RandomFloat() * (600.0f * AIRMINE_SCALE);
				else
					chainOff = h * (800.0f/10.0f);
				break;

		case	LEVEL_NUM_ADVENTURE2:
				typeB = LEVEL2_ObjType_AirMine_Base;
				typeM = LEVEL2_ObjType_AirMine_Mine;
				typeC = LEVEL2_ObjType_AirMine_Chain;
				if (h == 0)
					chainOff = RandomFloat() * (1400.0f * AIRMINE_SCALE);
				else
					chainOff = h * (2300.0f/10.0f);
				break;

		case	LEVEL_NUM_ADVENTURE3:
		case	LEVEL_NUM_RACE1:
		case	LEVEL_NUM_FLAG1:
				typeB = LEVEL3_ObjType_AirMine_Base;
				typeM = LEVEL3_ObjType_AirMine_Mine;
				typeC = LEVEL3_ObjType_AirMine_Chain;
				if (h == 0)
					chainOff = RandomFloat() * (1400.0f * AIRMINE_SCALE);
				else
					chainOff = h * (2300.0f/10.0f);
				break;

		default:
				DoFatalAlert("AddAirMine: no mines here yet, call Brian!");
				return(false);
	}


				/**************/
				/* MAKE BASE  */
				/**************/

	gNewObjectDefinition.group 		= MODEL_GROUP_LEVELSPECIFIC;
	gNewObjectDefinition.type 		= typeB;
	gNewObjectDefinition.scale 		= AIRMINE_SCALE;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= GetMinTerrainY(x,z, gNewObjectDefinition.group, gNewObjectDefinition.type, gNewObjectDefinition.scale);
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits;
	gNewObjectDefinition.slot 		= SLOT_OF_DUMB - 200;
	gNewObjectDefinition.moveCall 	= MoveAirMine;
	gNewObjectDefinition.rot 		= 0;
	base = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	base->TerrainItemPtr = itemPtr;								// keep ptr to item list

			/* SET COLLISION STUFF */

	base->CType 			= CTYPE_MISC;
	base->CBits				= CBITS_ALLSOLID;
	CreateCollisionBoxFromBoundingBox(base, 1, 1);


				/**************/
				/* MAKE CHAIN */
				/**************/

	gNewObjectDefinition.type 		= typeC;
	gNewObjectDefinition.coord.y 	-= chainOff;
	gNewObjectDefinition.slot++;
	gNewObjectDefinition.moveCall 	= nil;
	gNewObjectDefinition.rot 		= RandomFloat() * PI2;
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits | STATUS_BIT_CLIPALPHA6 | STATUS_BIT_DOUBLESIDED;
	chain = MakeNewDisplayGroupObject(&gNewObjectDefinition);

	chain->WobbleX = RandomFloat() * PI2;

	base->ChainNode = chain;
	chain->ChainHead = base;



				/*************/
				/* MAKE MINE */
				/*************/

	gNewObjectDefinition.type 		= typeM;
	gNewObjectDefinition.slot++;
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits;
	mine = MakeNewDisplayGroupObject(&gNewObjectDefinition);

			/* SET COLLISION STUFF */

	mine->Damage = 1.0f;

	mine->CType 			= CTYPE_MISC | CTYPE_WEAPONTEST | CTYPE_TRIGGER;
	mine->CBits				= CBITS_ALLSOLID;
	CreateCollisionBoxFromBoundingBox(mine, .5, .9);

	mine->TriggerCallback = DoTrig_AirMine;
	mine->HitByWeaponHandler = AirMineHitByWeaponCallback;



	chain->ChainNode = mine;
	mine->ChainHead = chain;




		/* CALL THE MOVE FUNCTION ONCE TO ALIGN ALL THE PARTS */

	MoveAirMine(base);

	return(true);													// item was added
}


/********************** MOVE AIR MINE ***********************/

static void MoveAirMine(ObjNode *base)
{
ObjNode	*chain = base->ChainNode;
ObjNode	*mine = chain->ChainNode;
OGLPoint3D		origin;
OGLMatrix4x4	m, m2;
long			i;
const OGLPoint3D	mineOff = {0,1000,0};
const OGLPoint3D	mineOff2 = {0,2000,0};
const OGLPoint3D	lightOff = {0,1100,0};
const OGLPoint3D	lightOff2 = {0,2100,0};

		/* SEE IF GONE */

	if (TrackTerrainItem(base))
	{
		DeleteObject(base);
		return;
	}


			/*********************/
			/* MAKE CHAIN WOBBLE */
			/*********************/

	chain->WobbleX +=  gFramesPerSecondFrac * 1.1f;
	chain->Rot.x = sin(chain->WobbleX) * .15f;


		/* CALC MATRIX TO ROTATE CHAIN AROUND THE HING POINT */

	origin.x = base->Coord.x;										// set coord to swivel about
	origin.y = base->Coord.y + (40.0f * AIRMINE_SCALE);
	origin.z = base->Coord.z;

	OGLMatrix4x4_SetRotateAboutPoint(&m, &origin, chain->Rot.x, chain->Rot.y, 0);

	OGLMatrix4x4_SetScale(&m2, chain->Scale.x, chain->Scale.y, chain->Scale.z);
	m2.value[M03] = chain->Coord.x;
	m2.value[M13] = chain->Coord.y;
	m2.value[M23] = chain->Coord.z;

	OGLMatrix4x4_Multiply(&m2, &m, &chain->BaseTransformMatrix);

	SetObjectTransformMatrix(chain);


		/****************************/
		/* PUT MINE ON END OF CHAIN */
		/****************************/

	mine->Rot.x = chain->Rot.x;													// match x rot

	switch(gLevelNum)
	{
		case	LEVEL_NUM_ADVENTURE1:
		case	LEVEL_NUM_FLAG2:
		case	LEVEL_NUM_BATTLE1:
				OGLPoint3D_Transform(&mineOff, &chain->BaseTransformMatrix, &mine->Coord);	// calc coord of mine @ end of chain
				break;

		default:
				OGLPoint3D_Transform(&mineOff2, &chain->BaseTransformMatrix, &mine->Coord);
				break;
	}

	UpdateObjectTransforms(mine);
	CalcObjectBoxFromNode(mine);


		/************************/
		/* UPDATE LIGHT ON MINE */
		/************************/

		/* CALC COORD OF LIGHT */

	switch(gLevelNum)
	{
		case	LEVEL_NUM_ADVENTURE1:
		case	LEVEL_NUM_FLAG2:
		case	LEVEL_NUM_BATTLE1:
				OGLPoint3D_Transform(&lightOff, &chain->BaseTransformMatrix, &origin);
				break;

		default:
				OGLPoint3D_Transform(&lightOff2, &chain->BaseTransformMatrix, &origin);
				break;
	}

		/* MAKE NEW SPARKLE */

	if (mine->Sparkles[0] == -1)
	{
		i = mine->Sparkles[0] = GetFreeSparkle(mine);			// make new sparkle
		if (i != -1)
		{
			gSparkles[i].flags = SPARKLE_FLAG_OMNIDIRECTIONAL | SPARKLE_FLAG_FLICKER;
			gSparkles[i].where = origin;

			gSparkles[i].color.r = 1;
			gSparkles[i].color.g = 1;
			gSparkles[i].color.b = 1;
			gSparkles[i].color.a = 1;

			gSparkles[i].scale 	= 100.0f;
			gSparkles[i].separation = 300.0f;

			gSparkles[i].textureNum = PARTICLE_SObjType_RedGlint;
		}
	}

		/* UPDATE EXISTING SPARKLE */

	else
	{
		i = mine->Sparkles[0];
		gSparkles[i].where = origin;
	}


}


#pragma mark -


/******************** TRIGGER CALLBACK:  AIR MINE ************************/
//
// Returns TRUE if want to handle hit as a solid
//

static Boolean DoTrig_AirMine(ObjNode *mine, ObjNode *player)
{
short	playerNum = player->PlayerNum;


				/* DOES PLAYER HAVE SHIELD? */

	if (gPlayerInfo[playerNum].shieldPower > 0.0f)
		HitPlayerShield(playerNum, MAX_SHIELD_POWER, 2.5, true);			// completely drain shield


				/* NO SHIELD, SO KABOOM */

	else
	if (!gGamePrefs.kiddieMode)												// dont hurt in kiddie mode
		PlayerSmackedIntoObject(player, mine, PLAYER_DEATH_TYPE_DEATHDIVE);


	ExplodeAirMine(mine);

	return(false);
}


/*************************** AIR MINE HIT BY WEAPON CALLBACK *****************************/
//
// Returns true if object should stop bullet.
//

static Boolean AirMineHitByWeaponCallback(ObjNode *bullet, ObjNode *mine, OGLPoint3D *hitCoord, OGLVector3D *hitTriangleNormal)
{
#pragma unused (bullet, hitCoord, hitTriangleNormal)

	ExplodeAirMine(mine);

	return(true);
}



/************************** EXPLODE AIR MINE ***************************/

static void ExplodeAirMine(ObjNode *mine)
{
long					pg,i,j;
OGLVector3D				d;
OGLPoint3D				pt;
NewParticleDefType		newParticleDef;
float					x,y,z;

ObjNode	*chain = mine->ChainHead;
ObjNode *base = chain->ChainHead;


		/*********************/
		/* FIRST MAKE SPARKS */
		/*********************/

	gNewParticleGroupDef.magicNum				= 0;
	gNewParticleGroupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
	gNewParticleGroupDef.flags					= PARTICLE_FLAGS_BOUNCE;
	gNewParticleGroupDef.gravity				= 900;
	gNewParticleGroupDef.magnetism				= 0;
	gNewParticleGroupDef.baseScale				= 10;
	gNewParticleGroupDef.decayRate				=  .4;
	gNewParticleGroupDef.fadeRate				= .7;
	gNewParticleGroupDef.particleTextureNum		= PARTICLE_SObjType_BlueSpark;
	gNewParticleGroupDef.srcBlend				= GL_SRC_ALPHA;
	gNewParticleGroupDef.dstBlend				= GL_ONE;
	pg = NewParticleGroup(&gNewParticleGroupDef);
	if (pg != -1)
	{
		x = mine->Coord.x;
		y = mine->Coord.y;
		z = mine->Coord.z;

		for (i = 0; i < 70; i++)
		{
			d.x = RandomFloat2() * 800.0f;
			d.y = RandomFloat2() * 800.0f;
			d.z = RandomFloat2() * 800.0f;

			pt.x = x + d.x * .05f;
			pt.y = y + d.y * .05f;
			pt.z = z + d.z * .05f;

			newParticleDef.groupNum		= pg;
			newParticleDef.where		= &pt;
			newParticleDef.delta		= &d;
			newParticleDef.scale		= RandomFloat() + 1.5f;
			newParticleDef.rotZ			= 0;
			newParticleDef.rotDZ		= 0;
			newParticleDef.alpha		= FULL_ALPHA + (RandomFloat() * .3f);
			AddParticleToGroup(&newParticleDef);
		}
	}

		/********************/
		/* MAKE FLARE BALLS */
		/********************/

	for (j = 0; j < 10; j++)
	{
		ObjNode	*flare;
		float	dx,dy,dz;

		gNewObjectDefinition.genre		= CUSTOM_GENRE;
		gNewObjectDefinition.slot 		= SLOT_OF_DUMB + 20;
		gNewObjectDefinition.moveCall 	= MoveAirMineFlareBall;
		gNewObjectDefinition.flags 		= STATUS_BIT_DONTCULL;

		flare = MakeNewObject(&gNewObjectDefinition);

				/* SET RANDOM TRAJECTORY */

		dx = RandomFloat2();
		dy = RandomFloat2() + .5f;
		dz = RandomFloat2();

		FastNormalizeVector(dx, dy, dz, &flare->Delta);

					/* AND COORD */

		flare->Coord.x = mine->Coord.x + flare->Delta.x * 50.0f;
		flare->Coord.y = mine->Coord.y + flare->Delta.y * 50.0f;
		flare->Coord.z = mine->Coord.z + flare->Delta.z * 50.0f;

		flare->Delta.x *= 800.0f;
		flare->Delta.y *= 800.0f;
		flare->Delta.z *= 800.0f;



		flare->Health = 1.2f + RandomFloat() * .3f;


			/* MAKE NEW SPARKLE */

		i = flare->Sparkles[0] = GetFreeSparkle(flare);
		if (i != -1)
		{
			gSparkles[i].flags = SPARKLE_FLAG_OMNIDIRECTIONAL;
			gSparkles[i].where = mine->Coord;

			gSparkles[i].color.r = 1;
			gSparkles[i].color.g = 1;
			gSparkles[i].color.b = 1;
			gSparkles[i].color.a = 1;

			gSparkles[i].scale 	= 120.0f;
			gSparkles[i].separation = 0.0f;

			gSparkles[i].textureNum = PARTICLE_SObjType_YellowGlint;
		}
	}



			/* EXPLODE GEOMETRY */

	ExplodeGeometry(mine, 600, SHARD_MODE_FROMORIGIN, 1, 1.0);

	PlayEffect3D(EFFECT_MINEEXPLODE, &gCoord);


		/**********************************/
		/* DELETE MINE & CLEANUP LINKAGES */
		/**********************************/

	base->TerrainItemPtr = nil;								// don't come back

	DeleteObject(mine);
	DeleteObject(chain);

	base->ChainNode = nil;

	base->MoveCall = MoveStaticObject;

}


/***************** MOVE AIR MINE FLARE BALL **********************/

static void MoveAirMineFlareBall(ObjNode *flare)
{
float	fps = gFramesPerSecondFrac;
short	i;

	flare->Health -= fps;
	if (flare->Health <= 0.0f)
	{
		DeleteObject(flare);
		return;
	}

	GetObjectInfo(flare);


	gDelta.y -= 500.0f * fps;

	gCoord.x += gDelta.x * fps;
	gCoord.y += gDelta.y * fps;
	gCoord.z += gDelta.z * fps;

	i = flare->Sparkles[0];
	if (i != -1)
		gSparkles[i].where = gCoord;


	flare->Delta = gDelta;
	flare->Coord = gCoord;

//	UpdateObject(flare);


		/************************/
		/* UPDATE SPARKLE TRAIL */
		/************************/

	flare->ParticleTimer -= fps;
	if (flare->ParticleTimer <= 0.0f)
	{
		int						particleGroup,magicNum;
		NewParticleGroupDefType	groupDef;
		NewParticleDefType		newParticleDef;

		flare->ParticleTimer += .03f;										// reset timer

		particleGroup 	= flare->ParticleGroup;
		magicNum 		= flare->ParticleMagicNum;

		if ((particleGroup == -1) || (!VerifyParticleGroupMagicNum(particleGroup, magicNum)))
		{
			flare->ParticleMagicNum = magicNum = MyRandomLong();			// generate a random magic num

			groupDef.magicNum				= magicNum;
			groupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
			groupDef.flags					= PARTICLE_FLAGS_DONTCHECKGROUND;
			groupDef.gravity				= -200;
			groupDef.magnetism				= 0;
			groupDef.baseScale				= 10.0f;
			groupDef.decayRate				=  0;
			groupDef.fadeRate				= .6;
			groupDef.particleTextureNum		= PARTICLE_SObjType_RedSpark;
			groupDef.srcBlend				= GL_SRC_ALPHA;
			groupDef.dstBlend				= GL_ONE;
			flare->ParticleGroup = particleGroup = NewParticleGroup(&groupDef);
		}

		if (particleGroup != -1)
		{
			OGLVector3D		d;
			OGLPoint3D		p;

			for (i = 0; i < 4; i++)
			{

				d.x = RandomFloat2() * 30.0f;
				d.y = RandomFloat2() * 30.0f;
				d.z = RandomFloat2() * 30.0f;

				p = gCoord;

				newParticleDef.groupNum		= particleGroup;
				newParticleDef.where		= &p;
				newParticleDef.delta		= &d;
				newParticleDef.scale		= RandomFloat() + 1.0f;
				newParticleDef.rotZ			= RandomFloat() * PI2;
				newParticleDef.rotDZ		= RandomFloat2();
				newParticleDef.alpha		= 1.0;
				if (AddParticleToGroup(&newParticleDef))
				{
					flare->ParticleGroup = -1;
					break;
				}
			}
		}
	}







}






































