/****************************/
/*			HOLES.C		    */
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

static void MoveHole(ObjNode *theNode);
static void MakeHoleWorm(ObjNode *hole);
static void MoveHoleWorm(ObjNode *worm);
static void UpdateWormJoints(ObjNode *theNode, short splineNum, int splineIndex);
static void SpewDirtFromHole(ObjNode *hole);


/****************************/
/*    CONSTANTS             */
/****************************/

enum
{
	HOLE_MODE_INACTIVE,
	HOLE_MODE_SOURCE,
	HOLE_MODE_DEST
};

#define	MAX_HOLE_TARGETS	11


/*********************/
/*    VARIABLES      */
/*********************/

#define SrcHole		Special[0]
#define DestHole	Special[1]
#define DirtTimer   SpecialF[0]
#define DidDirt		Flag[0]

/************************* ADD HOLE *********************************/

Boolean AddHole(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*newObj;

	gNewObjectDefinition.genre = EVENT_GENRE;
	gNewObjectDefinition.coord.x 	= x;
	gNewObjectDefinition.coord.z 	= z;
	gNewObjectDefinition.coord.y 	= itemPtr->terrainY;
	gNewObjectDefinition.flags 		= 0;
	gNewObjectDefinition.slot		= SLOT_OF_DUMB + 50;
	gNewObjectDefinition.moveCall 	= MoveHole;
	newObj = MakeNewObject(&gNewObjectDefinition);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list

	newObj->What = WHAT_HOLE;
	newObj->Kind = itemPtr->parm[0];							// remember hole group #

	newObj->Mode = HOLE_MODE_INACTIVE;
	newObj->Timer = RandomFloat() * 2.0f;						// delay until worm

	return(true);													// item was added
}


/*********************** MOVE HOLE ***************************/

static void MoveHole(ObjNode *theNode)
{
float	fps = gFramesPerSecondFrac;


	switch(theNode->Mode)
	{
			/*******************************/
			/* SEE IF SHOULD MAKE NEW WORM */
			/*******************************/

		case	HOLE_MODE_INACTIVE:

				/* SEE IF CAN DELETE */

				if (TrackTerrainItem(theNode))
				{
					DeleteObject(theNode);
					return;
				}

				/* CHECK TIMER */

				theNode->Timer -= fps;
				if (theNode->Timer <= 0.0f)
				{
					MakeHoleWorm(theNode);							// try to make worm come out of here
					theNode->Timer = 1.0f + RandomFloat() * 1.0f;   // delay for next time
				}
				break;


			/***********************/
			/* DO SOURCE HOLE DIRT */
			/***********************/

		case	HOLE_MODE_SOURCE:
		case	HOLE_MODE_DEST:
				if (theNode->DidDirt)
				{
					theNode->DirtTimer += fps;
					if (theNode->DirtTimer < 1.0f)
					{
						SpewDirtFromHole(theNode);
					}
				}
				break;
	}

}



/********************** MAKE HOLE WORM ***************************/

static void MakeHoleWorm(ObjNode *hole)
{
ObjNode *worm, *thisNode, *theTarget;
ObjNode	*targets[MAX_HOLE_TARGETS];
short	numTargets = 0;
short   splineNum,p;
float   dist, minY, maxY;
OGLPoint3D  nubs[5];

		/***************************************/
		/* SCAN FOR AVAILABLE DESTINATION HOLE */
		/***************************************/

	/* BUILD LIST OF ELIGIBLE TARGET ELECTRODES */

	thisNode = gFirstNodePtr;
	do
	{
		if (thisNode != hole)											// dont target itself
		{
			if (thisNode->What == WHAT_HOLE)							// only look for holes
			{
				if (thisNode->Kind == hole->Kind)						// in same group?
				{
					if (thisNode->Mode == HOLE_MODE_INACTIVE)			// only allow inactive holes
					{
						targets[numTargets++] = thisNode;
						if (numTargets >= MAX_HOLE_TARGETS)
							break;
					}
				}
			}
		}
		thisNode = thisNode->NextNode;
	}while(thisNode != nil);


			/* CHOOSE A RANDOM TARGET */

	if (numTargets == 0)
		return;

	theTarget = targets[RandomRange(0, numTargets-1)];

	dist = CalcQuickDistance(theTarget->Coord.x, theTarget->Coord.z, hole->Coord.x, hole->Coord.z);		// calc dist between targets
	minY = dist * .25f;
	maxY = hole->Coord.y + (dist * .8f);

			/************************************/
			/* CONSTRUCT A SPLINE BETWEEN HOLES */
			/************************************/

			/* CALC "FROM" NUBS */

	nubs[0] = nubs[1] = hole->Coord;
	nubs[0].y -= dist * 1.5f;


			/* CALC "TO" NUBS */

	nubs[3] = nubs[4] = theTarget->Coord;
	nubs[4].y -= dist * 1.5f; 										// last nub is a dummy nub, so move it down to set angle of spline


		/* CALC TOP OF ARCH NUB */

	nubs[2].x = (hole->Coord.x + theTarget->Coord.x) * .5f;
	nubs[2].z = (hole->Coord.z + theTarget->Coord.z) * .5f;

	nubs[2].y = (hole->Coord.y + theTarget->Coord.y) * .5f;

	CalcDistanceToClosestPlayer(&hole->Coord, &p);
	if ((gPlayerInfo[p].coord.y - hole->Coord.y) < minY)
		nubs[2].y += minY;											// set to min height
	else
	{
		float   temp = gPlayerInfo[p].coord.y * .95f;				// calc desired y

		if (temp > maxY)
			temp = maxY;
		nubs[2].y = temp;											// set height to player's
	}



			/* TRY TO GENERATE A SPLINE */

	splineNum = GenerateCustomSpline(5, nubs, 800);
	if (splineNum == -1)
		return;



			/********************/
			/* MAKE WORM OBJECT */
			/********************/

	gNewObjectDefinition.type 		= SKELETON_TYPE_WORM;
	gNewObjectDefinition.animNum 	= 0;
	gNewObjectDefinition.scale 		= 6.0;
	gNewObjectDefinition.coord		= hole->Coord;
	gNewObjectDefinition.flags 		= gAutoFadeStatusBits;
	gNewObjectDefinition.slot 		= 491;
	gNewObjectDefinition.moveCall 	= MoveHoleWorm;
	gNewObjectDefinition.rot 		= 0;
	worm = MakeNewSkeletonObject(&gNewObjectDefinition);

	worm->Skeleton->JointsAreGlobal = true;


	worm->SplineNum = splineNum;
	worm->SplinePlacement = .04;

	worm->SrcHole = (u_long)hole;
	worm->DestHole = (u_long)theTarget;

			/* SET COLLISION STUFF */

	worm->CType 			= CTYPE_WEAPONTEST | CTYPE_PLAYERTEST;
	worm->CBits				= 0;
	worm->Damage			= .2f;

		/*****************/
		/* SET HOLE INFO */
		/*****************/

	hole->Mode		= HOLE_MODE_SOURCE;
	theTarget->Mode = HOLE_MODE_DEST;

	hole->DidDirt		= false;									// holes have not spewed dirt yet
	theTarget->DidDirt  = false;


			/* PRIME IT */

	UpdateWormJoints(worm, splineNum, 0);
	UpdateSkinnedGeometry(worm);
}


/******************* MOVE HOLE WORM ********************/

static void MoveHoleWorm(ObjNode *worm)
{
float   fps = gFramesPerSecondFrac;
float   splineIndex, numPointsInSpline;
int		i;
short   splineNum = worm->SplineNum;
ObjNode *from, *to;

	from = (ObjNode *)worm->SrcHole;							// get from-to hole ObjNodes
	to = (ObjNode *)worm->DestHole;

	GetObjectInfo(worm);

	numPointsInSpline = gCustomSplines[splineNum].numPoints;
	splineIndex = worm->SplinePlacement += fps * .19f;

			/* SEE IF @ END OF SPLINE */

	if (splineIndex >= .98f)
	{
		FreeACustomSpline(splineNum);

		from->Mode = HOLE_MODE_INACTIVE;
		to->Mode = HOLE_MODE_INACTIVE;

		DeleteObject(worm);
		return;
	}


			/* GET NEW COORD ON SPLINE */

	i = splineIndex * numPointsInSpline;

	gCoord = gCustomSplines[splineNum].splinePoints[i];


			/* UPDATE JOINTS ON SPLINE */

	UpdateWormJoints(worm, splineNum, i);


			/*********************/
			/* SEE IF START DIRT */
			/*********************/

			/* SEE IF START @ FROM */

	if (!from->DidDirt)
	{
		float dist = fabs(from->Coord.y - gCoord.y);
		if (dist < 300.0f)
		{
			from->DidDirt = true;
			from->DirtTimer = 0;
			PlayEffect_Parms3D(EFFECT_DIRT, &from->Coord, NORMAL_CHANNEL_RATE - (MyRandomLong() & 0x1fff), 2.0);
		}
	}

			/* SEE IF START @ TO */

	else
	if ((!to->DidDirt) && (from->DirtTimer > .5f))
	{
		float dist = fabs(to->Coord.y - gCoord.y);
		if (dist < 250.0f)
		{
			to->DidDirt = true;
			to->DirtTimer = 0;
			PlayEffect_Parms3D(EFFECT_DIRT, &to->Coord, NORMAL_CHANNEL_RATE - (MyRandomLong() & 0x1fff), 2.0);
		}
	}

	UpdateObject(worm);
}


#pragma mark -

/********************* UPDATE WORM JOINTS *************************/

static void UpdateWormJoints(ObjNode *theNode, short splineNum, int splineIndex)
{
SkeletonObjDataType	*skeleton = theNode->Skeleton;
SkeletonDefType		*skeletonDef;
short				jointNum, numJoints;
float				scale;

	skeletonDef = skeleton->skeletonDefinition;

	numJoints = skeletonDef->NumBones;								// get # joints in this skeleton

	scale = theNode->Scale.x;

			/***************************************/
			/* TRANSFORM EACH JOINT TO WORLD-SPACE */
			/***************************************/
			//
			// NOTE:  to get the head aimed correctly, we create a 1st dummy joint.
			//			The dummy joint isn't part of the worm - it's just a "leader".
			//

	for (jointNum = -1; jointNum < numJoints; jointNum++)
	{
		OGLPoint3D		coord,prevCoord;


				/* GET COORDS OF THIS SEGMENT */

		coord = gCustomSplines[splineNum].splinePoints[splineIndex];

		splineIndex -= 6.0f * scale;										// prepare for next segment's index
		if (splineIndex < 0)
			splineIndex = 0;


		if (jointNum != -1)
		{
			const OGLVector3D   up = {.99, .01, 0};			// NOTE:  we must use a slightly off-axis up vector to avoid getting parallel vectors below
			OGLMatrix4x4	m2, m;

					/* TRANSFORM JOINT'S MATRIX TO WORLD COORDS */

			OGLMatrix4x4_SetScale(&m, scale, scale, scale);
			SetLookAtMatrixAndTranslate(&m2, &up, &coord, &prevCoord);
			OGLMatrix4x4_Multiply(&m, &m2, &skeleton->jointTransformMatrix[jointNum]);
		}

		prevCoord = coord;
	}
}


#pragma mark -

/******************** SPEW DIRT FROM HOLE *************************/

static void SpewDirtFromHole(ObjNode *theNode)
{
int		i;
float	fps = gFramesPerSecondFrac;
int		particleGroup,magicNum;
NewParticleGroupDefType	groupDef;
NewParticleDefType	newParticleDef;
OGLVector3D			d;
OGLPoint3D			p;

	theNode->ParticleTimer -= fps;
	if (theNode->ParticleTimer <= 0.0f)
	{
		theNode->ParticleTimer += .03f;										// reset timer

		particleGroup 	= theNode->ParticleGroup;
		magicNum 		= theNode->ParticleMagicNum;

		if ((particleGroup == -1) || (!VerifyParticleGroupMagicNum(particleGroup, magicNum)))
		{

			theNode->ParticleMagicNum = magicNum = MyRandomLong();			// generate a random magic num

			groupDef.magicNum				= magicNum;
			groupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
			groupDef.flags					= PARTICLE_FLAGS_BOUNCE;
			groupDef.gravity				= 2000;
			groupDef.magnetism				= 0;
			groupDef.baseScale				= 70.0f;
			groupDef.decayRate				=  .9;
			groupDef.fadeRate				= .5;
			groupDef.particleTextureNum		= PARTICLE_SObjType_SwampDirt;
			groupDef.srcBlend				= GL_SRC_ALPHA;
			groupDef.dstBlend				= GL_ONE_MINUS_SRC_ALPHA;
			theNode->ParticleGroup = particleGroup = NewParticleGroup(&groupDef);
		}

		if (particleGroup != -1)
		{
			float   x,y,z;

			x = theNode->Coord.x;
			y = theNode->Coord.y;
			z = theNode->Coord.z;

			for (i = 0; i < 4; i++)
			{
				p.x = x + RandomFloat2() * 160.0f;
				p.y = y;
				p.z = z + RandomFloat2() * 160.0f;

				d.x = RandomFloat2() * 450.0f;
				d.y = 900.0f + RandomFloat() * 300.0f;
				d.z = RandomFloat2() * 450.0f;

				newParticleDef.groupNum		= particleGroup;
				newParticleDef.where		= &p;
				newParticleDef.delta		= &d;
				newParticleDef.scale		= RandomFloat() * 1.5f + 1.0f;
				newParticleDef.rotZ			= RandomFloat() * PI2;
				newParticleDef.rotDZ		= RandomFloat2() * 5.0f;
				newParticleDef.alpha		= 1.0;
				if (AddParticleToGroup(&newParticleDef))
				{
					theNode->ParticleGroup = -1;
					break;
				}
			}
		}
	}
}





















