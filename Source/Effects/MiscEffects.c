/****************************/
/*   	MISC EFFECTS.C		*/
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

static void MoveShockwaveRing(ObjNode *theNode);


/****************************/
/*    CONSTANTS             */
/****************************/


/*********************/
/*    VARIABLES      */
/*********************/

#define	ShockwaveScaleSpeed		SpecialF[0]


/************************* INIT EFFECTS ***************************/

void InitEffects(void)
{

	InitParticleSystem();
	InitConfettiManager();
	InitShardSystem();

			/* SET SPRITE BLENDING FLAGS */

	BlendASprite(SPRITE_GROUP_PARTICLES, PARTICLE_SObjType_Splash);


			/* UPDATE SONG */

//	if (gSongMovie)
//		MoviesTask(gSongMovie, 0);

}


#pragma mark -


/******************** MAKE SHOCKWAVE RING ****************************/

ObjNode *MakeShockwaveRing(OGLPoint3D *coord, float scale)
{
	NewObjectDefinitionType def =
	{
		.group 		= MODEL_GROUP_GLOBAL,
		.type 		= GLOBAL_ObjType_ShockwaveRing,
		.scale 		= scale,
		.coord		= *coord,
		.flags 		= STATUS_BIT_GLOW | STATUS_BIT_DOUBLESIDED | STATUS_BIT_NOTEXTUREWRAP | STATUS_BIT_NOZWRITES,
		.slot 		= SLOT_OF_DUMB + 20,
		.moveCall 	= MoveShockwaveRing,
		.rot 		= RandomFloat()*PI2,
	};

	ObjNode* newObj = MakeNewDisplayGroupObject(&def);

	newObj->Rot.x = RandomFloat() * PI2;
	newObj->Rot.z = RandomFloat() * PI2;
	UpdateObjectTransforms(newObj);

	newObj->ColorFilter.a = 1.5;

	newObj->ShockwaveScaleSpeed = 1.0f + RandomFloat();

	return(newObj);
}


/********************* MOVE SHOCKWAVE RING ***************************/

static void MoveShockwaveRing(ObjNode *theNode)
{
float	fps = gFramesPerSecondFrac;
float	speed = theNode->ShockwaveScaleSpeed;

		/* FADE OUT */

	theNode->ColorFilter.a -= fps * 1.5f * speed;
	if (theNode->ColorFilter.a <= 0.0f)
	{
		DeleteObject(theNode);
		return;
	}


		/* SCALE */

	theNode->Scale.x = theNode->Scale.y = theNode->Scale.z += fps * 15.0f * speed;

	UpdateObjectTransforms(theNode);
}











