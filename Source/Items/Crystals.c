/****************************/
/*   	CRYSTALS.C		    */
/* (c)2004 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/


#include "game.h"


/****************************/
/*    PROTOTYPES            */
/****************************/


static Boolean CrystalHitByWeaponCallback(ObjNode *bullet, ObjNode *crystal, OGLPoint3D *hitCoord, OGLVector3D *hitTriangleNormal);
static void MoveCrystalShockwave(ObjNode *theNode);


/****************************/
/*    CONSTANTS             */
/****************************/



/*********************/
/*    VARIABLES      */
/*********************/



/************************* ADD CRYSTAL *********************************/

Boolean AddCrystal(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*base, *crystal;

	if (itemPtr->parm[0] > 2)
		DoFatalAlert("AddCrystal: illegal subtype");


			/*************/
			/* MAKE BASE */
			/*************/
	NewObjectDefinitionType def =
	{
		.group 		= MODEL_GROUP_LEVELSPECIFIC,
		.type 		= LEVEL2_ObjType_Crystal1Base + itemPtr->parm[0],
		.scale 		= 1.5f + RandomFloat2() * .5f,
		.coord.x 	= x,
		.coord.z 	= z,
		.coord.y 	= itemPtr->terrainY,
		.flags 		= gAutoFadeStatusBits,
		.slot 		= SLOT_OF_DUMB-50,
		.moveCall 	= MoveStaticObject,
		.rot 		= RandomFloat()*PI2,
	};

	base = MakeNewDisplayGroupObject(&def);

	base->TerrainItemPtr = itemPtr;								// keep ptr to item list

	RotateOnTerrain(base, -2, nil);							// keep flat on terrain
	SetObjectTransformMatrix(base);


	if (!(itemPtr->flags & ITEM_FLAGS_USER1))					// did we blow up the crystal previously?
	{

				/****************/
				/* MAKE CRYSTAL */
				/****************/

		def.type 		= LEVEL2_ObjType_Crystal1 + itemPtr->parm[0];
		def.slot 		= SLOT_OF_DUMB-3;
		def.moveCall 	= nil;
		crystal = MakeNewDisplayGroupObject(&def);


				/* SET COLLISION STUFF */

		crystal->CType 			= CTYPE_SOLIDTOENEMY | CTYPE_PLAYERTEST | CTYPE_WEAPONTEST | CTYPE_MISC;
		crystal->CBits			= CBITS_ALLSOLID;
		CalcObjectBoxFromNode(crystal);

		crystal->HitByWeaponHandler 	= CrystalHitByWeaponCallback;

		crystal->HeatSeekHotSpotOff.x = 0;
		crystal->HeatSeekHotSpotOff.y = 50.0f;
		crystal->HeatSeekHotSpotOff.z = 0;



		crystal->BaseTransformMatrix = base->BaseTransformMatrix;
		SetObjectTransformMatrix(crystal);


		base->ChainNode = crystal;
		crystal->ChainHead = base;
	}

	return(true);													// item was added
}





/*************************** CRYSTAL HIT BY WEAPON CALLBACK *****************************/
//
// Returns true if object should stop bullet.
//

static Boolean CrystalHitByWeaponCallback(ObjNode *bullet, ObjNode *crystal, OGLPoint3D *hitCoord, OGLVector3D *hitTriangleNormal)
{
ObjNode	*base = crystal->ChainHead;
long					pg,i;
OGLVector3D				d;
OGLPoint3D				pt;
NewParticleDefType		newParticleDef;

#pragma unused (hitCoord, hitTriangleNormal, bullet)

	PlayEffect_Parms3D(EFFECT_CRYSTALSHATTER, &crystal->Coord, NORMAL_CHANNEL_RATE + (MyRandomLong() & 0x3fff), 2.0);


		/***************/
		/* MAKE SPARKS */
		/***************/

	gNewParticleGroupDef.magicNum				= 0;
	gNewParticleGroupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
	gNewParticleGroupDef.flags					= PARTICLE_FLAGS_DONTCHECKGROUND;
	gNewParticleGroupDef.gravity				= 500;
	gNewParticleGroupDef.magnetism				= 0;
	gNewParticleGroupDef.baseScale				= 15;
	gNewParticleGroupDef.decayRate				=  .5;
	gNewParticleGroupDef.fadeRate				= 1.0;
	gNewParticleGroupDef.particleTextureNum		= PARTICLE_SObjType_BlueSpark;
	gNewParticleGroupDef.srcBlend				= GL_SRC_ALPHA;
	gNewParticleGroupDef.dstBlend				= GL_ONE;
	pg = NewParticleGroup(&gNewParticleGroupDef);
	if (pg != -1)
	{
		float	x,y,z;

		x = base->Coord.x;
		y = base->Coord.y;
		z = base->Coord.z;

		for (i = 0; i < 220; i++)
		{
			d.x = RandomFloat2() * 800.0f;
			d.y = RandomFloat2() * 500.0f;
			d.z = RandomFloat2() * 800.0f;

			pt.x = x + d.x * .05f;
			pt.y = y + RandomFloat() * 150.0f;
			pt.z = z + d.z * .05f;

			newParticleDef.groupNum		= pg;
			newParticleDef.where		= &pt;
			newParticleDef.delta		= &d;
			newParticleDef.scale		= RandomFloat() + 1.0f;
			newParticleDef.rotZ			= 0;
			newParticleDef.rotDZ		= 0;
			newParticleDef.alpha		= 1.0f + (RandomFloat() * .3f);
			AddParticleToGroup(&newParticleDef);
		}
	}



		/* FRAGMENT */

	ExplodeGeometry(crystal, 600, SHARD_MODE_FROMORIGIN, 1, 1.0);


			/* SHOCKWAVE */

	NewObjectDefinitionType def =
	{
		.group 		= MODEL_GROUP_WEAPONS,
		.type 		= WEAPONS_ObjType_BombShockwave,
		.coord		= base->Coord,
		.flags 		= STATUS_BIT_NOZWRITES|STATUS_BIT_NOFOG|STATUS_BIT_NOLIGHTING,
		.slot 		= SLOT_OF_DUMB + 40,
		.moveCall 	= MoveCrystalShockwave,
		.rot 		= 0,
		.scale 		= 1.0,
	};

	ObjNode* newObj = MakeNewDisplayGroupObject(&def);

	newObj->ColorFilter.a = .8;

	newObj->Damage = .8f;



			/* DELETE  */

	base->ChainNode = nil;								// separate crystal from base

	base->TerrainItemPtr->flags |= ITEM_FLAGS_USER1;	// set flag so next time the crystal won't be created

	DeleteObject(crystal);


	return(true);
}


/*********************** MOVE CRYSTAL SHOCKWAVE *******************/

static void MoveCrystalShockwave(ObjNode *theNode)
{
float fps = gFramesPerSecondFrac;

			/* FADE */

	theNode->ColorFilter.a -= fps * 1.4f;
	if (theNode->ColorFilter.a <= 0.0f)
	{
		DeleteObject(theNode);
		return;
	}

	theNode->Scale.x =
	theNode->Scale.y =
	theNode->Scale.z += fps * 220.0f;

	UpdateObjectTransforms(theNode);


	CauseBombShockwaveDamage(theNode, CTYPE_PLAYER1 | CTYPE_PLAYER2 | CTYPE_ENEMY | CTYPE_WEAPONTEST);
}























