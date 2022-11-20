/****************************/
/*   	DUST DEVIL.C	    */
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

static ObjNode *MakeDustDevil(float  x, float z);

static void DrawDustDevils(ObjNode *theNode);
static int FindFreeDustDevilSlot(void);
static void MoveDustDevil(ObjNode *theNode);

static void MakeDustDevilDust(ObjNode *theNode);
static void MoveDustDevilOnSpline(ObjNode *theNode);

static void SeeIfDustDevilHitsPlayer(ObjNode *devil);
static void PutPlayerInDirtDevil(ObjNode *player, ObjNode *dustDevil, float radius);


/****************************/
/*    CONSTANTS             */
/****************************/

#define	MAX_DEVILS			20

#define	NUM_DEVIL_SEGMENTS		14
#define	NUM_RIBS				(NUM_DEVIL_SEGMENTS+1)
#define	NUM_POINTS_PER_RIB		20										// remember that 1st and last point overlap
#define	NUM_POINTS_PER_SEGMENT	(NUM_POINTS_PER_RIB * 2)				// each segment has 2 ribs (top & bottom)
#define	NUM_POINTS_PER_DEVIL	(NUM_DEVIL_SEGMENTS * NUM_POINTS_PER_SEGMENT)

#define	NUM_TRIANGLES_PER_SEGMENT	(NUM_POINTS_PER_SEGMENT-2)
#define	NUM_TRIANGLES_PER_DEVIL		(NUM_TRIANGLES_PER_SEGMENT * NUM_DEVIL_SEGMENTS)




/*********************/
/*    VARIABLES      */
/*********************/

static short	gNumDustDevils = 0;

static	Boolean		gDustDevilIsUsed[MAX_DEVILS];
static	ObjNode		*gDustDevilObjects[MAX_DEVILS];


typedef struct										// we group all the vertex arrays into a stuct so that we can easily allocate it to the Vertex Array Range engine
{
	MOTriangleIndecies		triangles[NUM_TRIANGLES_PER_DEVIL];
	OGLPoint3D				points[NUM_POINTS_PER_DEVIL];
	OGLVector3D				normals[NUM_POINTS_PER_DEVIL];
	OGLTextureCoord			uvs[NUM_POINTS_PER_DEVIL];
}DustDevilVertexArraysType;


static 	DustDevilVertexArraysType	gDustDevilVertexArrays[2];		// double-buffered VAR data
static	MOVertexArrayData			gDustDevilMeshes[2];

static	OGLPoint3D		gRibOffset[NUM_RIBS][NUM_POINTS_PER_RIB];


/************************* INIT DUST DEVIL MEMORY ***********************/

void InitDustDevilMemory(void)
{
float	rot,scale;
OGLVector3D		ribNormals[NUM_RIBS][NUM_POINTS_PER_RIB];
OGLPoint3D	*ribPts;
OGLVector3D	*normals;
MOTriangleIndecies	*tris;

	gNumDustDevils = 0;											// none build yet

	for (int d = 0; d < MAX_DEVILS; d++)
		gDustDevilIsUsed[d] = false;							// this one is available


			/*********************/
			/* MAKE DUMMY OBJECT */
			/*********************/
			//
			// This dummy object is used to determine when in the event queue we
			// went to draw all the dirt devils.
			//

	{
		NewObjectDefinitionType def =
		{
			.genre		= CUSTOM_GENRE,
			.slot		= PARTICLE_SLOT-1,
			.moveCall	= nil,
			.drawCall	= DrawDustDevils,
			.flags		= STATUS_BIT_DONTCULL | STATUS_BIT_NOZWRITES,
			.scale		= 1,
		};
		MakeNewObject(&def);
	}

			/****************************/
			/* CREATE RIB OFFSET TABLES */
			/****************************/

	scale = 200.0f;

	for (int seg = 0; seg < NUM_RIBS; seg++)
	{
		rot = 0;
		for (int j = 0; j < NUM_POINTS_PER_RIB; j++)
		{
			ribNormals[seg][j].x = -sin(rot);
			ribNormals[seg][j].z = cos(rot);
			ribNormals[seg][j].y = 0;

			gRibOffset[seg][j].x = ribNormals[seg][j].x * scale;
			gRibOffset[seg][j].z = ribNormals[seg][j].z * scale;
			gRibOffset[seg][j].y = seg * 250.0f;

			rot += PI2 / (float)(NUM_POINTS_PER_RIB-1);
		}

		scale *= 1.23f;
	}


#if VERTEXARRAYRANGES
			/* ASSIGN MEMORY TO VERTEX ARRAY RANGE */
			//
			// Each double-buffer of fence geometry gets its own VAR range type
			//

	AssignVertexArrayRangeMemory(sizeof(DustDevilVertexArraysType), &gDustDevilVertexArrays[0], VERTEX_ARRAY_RANGE_TYPE_USER_DUSTDEVIL);
	AssignVertexArrayRangeMemory(sizeof(DustDevilVertexArraysType), &gDustDevilVertexArrays[1], VERTEX_ARRAY_RANGE_TYPE_USER_DUSTDEVIL);
#endif



	for (int b = 0; b < 2; b++)									// make geometry for each double-buffer
	{
		MOVertexArrayData	*mesh = &gDustDevilMeshes[b];		// point to trimesh data

			/***********************/
			/* INIT TRIMESH STRUCT */
			/***********************/


		mesh->VARtype 		= VERTEX_ARRAY_RANGE_TYPE_USER_DUSTDEVIL;

		mesh->numMaterials 	= -1;
		mesh->materials[0] 	= nil;

		mesh->numPoints 	= NUM_POINTS_PER_DEVIL;
		mesh->numTriangles 	= NUM_TRIANGLES_PER_DEVIL;

		mesh->points 		= &gDustDevilVertexArrays[b].points[0];
		mesh->triangles 	= &gDustDevilVertexArrays[b].triangles[0];
		mesh->normals		= &gDustDevilVertexArrays[b].normals[0];
		mesh->uvs[0]		= &gDustDevilVertexArrays[b].uvs[0];
		mesh->colorsFloat	= nil;



					/*****************/
					/* INIT UV ARRAY */
					/*****************/

		{
			float v = 0;
			int i = 0;
			for (int seg = 0; seg < NUM_DEVIL_SEGMENTS; seg++)
			{
				float u = 0;
				for (int j = 0; j < NUM_POINTS_PER_RIB; j++)
				{
					int q = i+j;

					gDustDevilVertexArrays[b].uvs[q].u 						= u;						// bottom rib
					gDustDevilVertexArrays[b].uvs[q+NUM_POINTS_PER_RIB].u 	= u;						// top rib

					gDustDevilVertexArrays[b].uvs[q].v 						= 1-v;
					gDustDevilVertexArrays[b].uvs[q+NUM_POINTS_PER_RIB].v 	= 1-(v + 1.0f / (float)NUM_DEVIL_SEGMENTS);

					u += 1.0f / (float)(NUM_POINTS_PER_RIB-1);
				}

				i += NUM_POINTS_PER_SEGMENT;

				v += 1.0f / (float)NUM_DEVIL_SEGMENTS;
			}
		}



					/***************/
					/* INIT POINTS */
					/***************/

		ribPts = &gDustDevilVertexArrays[b].points[0];

		for (int i = 0; i < NUM_DEVIL_SEGMENTS; i++)
		{
					/* SET LOWER RIB POINTS */

			BlockMove(&gRibOffset[i][0], ribPts, sizeof(OGLPoint3D) * NUM_POINTS_PER_RIB);
			ribPts += NUM_POINTS_PER_RIB;


					/* SET UPPER RIB POINTS */

			BlockMove(&gRibOffset[i+1][0], ribPts, sizeof(OGLPoint3D) * NUM_POINTS_PER_RIB);
			ribPts += NUM_POINTS_PER_RIB;
		}


					/****************/
					/* INIT NORMALS */
					/****************/

		normals =  &gDustDevilVertexArrays[b].normals[0];

		for (int i = 0; i < NUM_DEVIL_SEGMENTS; i++)
		{
					/* SET LOWER RIB POINTS */

			BlockMove(&ribNormals[i][0], normals, sizeof(OGLPoint3D) * NUM_POINTS_PER_RIB);
			normals += NUM_POINTS_PER_RIB;


					/* SET UPPER RIB POINTS */

			BlockMove(&ribNormals[i+1][0], normals, sizeof(OGLPoint3D) * NUM_POINTS_PER_RIB);
			normals += NUM_POINTS_PER_RIB;
		}


					/******************/
					/* INIT TRIANGLES */
					/******************/

		tris =  &gDustDevilVertexArrays[b].triangles[0];

		for (int seg = 0; seg < NUM_DEVIL_SEGMENTS; seg++)
		{
			int	pointNum = seg * NUM_POINTS_PER_SEGMENT;

			for (int j = 0; j < (NUM_POINTS_PER_RIB-1); j++)
			{
				int	j2 = j + 1;

				tris->vertexIndices[0] = pointNum + j;
				tris->vertexIndices[1] = pointNum + j + NUM_POINTS_PER_RIB;
				tris->vertexIndices[2] = pointNum + j2;
				tris++;

				tris->vertexIndices[0] = pointNum + j2;
				tris->vertexIndices[1] = pointNum + j + NUM_POINTS_PER_RIB;
				tris->vertexIndices[2] = pointNum + j2 + NUM_POINTS_PER_RIB;
				tris++;
			}
		}
	} //  for b




}


/*********************** UPDATE DUST DEVIL UV ANIMATION ************************/
//
// We directly modify the UVS in the mesh, but since this is double buffered for VAR, we
// need to modify this buffer's UV's based on the other buffer's UV's.  So, we read from the
// old to modify the new.
//

void UpdateDustDevilUVAnimation(void)
{
OGLTextureCoord	*uvs, *uvs2;
long	i, p;
float	n, fps = gFramesPerSecondFrac;
Byte	buffNum;

	if (gNumDustDevils > 0)							// only bother if there are dirt devils around
	{
		buffNum = gGameViewInfoPtr->frameCount & 1;										// which VAR buffer to use?

		n = 4.0f;																		// uv scroll speed for bottom segment

		for (i = 0; i < NUM_DEVIL_SEGMENTS; i++)
		{
			uvs = &gDustDevilVertexArrays[buffNum].uvs[i * NUM_POINTS_PER_SEGMENT];		// point to this segment's UV's
			uvs2 = &gDustDevilVertexArrays[buffNum^1].uvs[i * NUM_POINTS_PER_SEGMENT];

			for (p = 0; p < NUM_POINTS_PER_SEGMENT; p++)
			{
				uvs[p].u = uvs2[p].u + n * fps;
			}

			n *= .70f;																	// next segment will scroll a little slower
		}
	}
}


#pragma mark -


/************************* ADD DUST DEVIL *********************************/

Boolean AddDustDevil(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*newObj;

	newObj = MakeDustDevil(x, z);
	if (!newObj)
		return(false);

	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list
	newObj->MoveCall = MoveDustDevil;

	return(true);													// item was added
}


/************************* MAKE DUST DEVIL *********************************/

static ObjNode *MakeDustDevil(float  x, float z)
{
ObjNode	*newObj;
int	devilNum;

			/* FIND FREE SLOT */

	devilNum = FindFreeDustDevilSlot();
	if (devilNum == -1)
		return(nil);


			/* MAKE CUSTOM OBJECT */

	NewObjectDefinitionType def =
	{
		.genre		= CUSTOM_GENRE,
		.slot		= PARTICLE_SLOT-1,
		.moveCall 	= nil,
		.coord.x	= x,
		.coord.z	= z,
		.coord.y	= GetTerrainY(x,z),
		.flags		= STATUS_BIT_DONTCULL | STATUS_BIT_HIDDEN,
		.scale		= 1,
	};

	newObj = MakeNewObject(&def);

	newObj->Mode = devilNum;

	gNumDustDevils++;

	gDustDevilObjects[devilNum] = newObj;

	return(newObj);
}



/********************** FIND FREE DUST DEVIL SLOT ***********************/

static int FindFreeDustDevilSlot(void)
{
	for (int i = 0; i < MAX_DEVILS; i++)
	{
		if (gDustDevilIsUsed[i] == false)
		{
			gDustDevilIsUsed[i] = true;
			return(i);
		}
	}

	return(-1);
}



/********************** DRAW DUST DEVILS *************************/

static void DrawDustDevils(ObjNode *dummyNode)
{
const MOVertexArrayData	*mesh;													// point to trimesh data
OGLMatrix4x4	m;
Byte	buffNum;
long	d;
ObjNode	*theNode;
#pragma unused (dummyNode)

	if (gNumDustDevils == 0)
		return;

	buffNum = gGameViewInfoPtr->frameCount & 1;									// which VAR buffer to use?
	mesh = &gDustDevilMeshes[buffNum];											// point to trimesh data


			/*******************************/
			/* DRAW EACH ACTIVE DUST DEVIL */
			/*******************************/

	gGlobalMaterialFlags = BG3D_MATERIALFLAG_CLAMP_V;


	for (d = 0; d < MAX_DEVILS; d++)
	{
		if (!gDustDevilIsUsed[d])												// is this one used?
			continue;

		theNode = gDustDevilObjects[d];											// get ptr to this devil's objNode


		glPushMatrix();

		MO_DrawMaterial(gSpriteGroupList[SPRITE_GROUP_LEVELSPECIFIC][LEVEL2_SObjType_DustDevil].materialObject);		// activate material


					/* TRANSLATE */

		OGLMatrix4x4_SetTranslate(&m, theNode->Coord.x, theNode->Coord.y, theNode->Coord.z);
		glMultMatrixf(m.value);

					/* SCALE DOWN AND DRAW INNER SHELL */

		if (!gGamePrefs.lowRenderQuality)
		{
			glPushMatrix();
			OGL_SetColor4f(1,1,1,.5);

			OGLMatrix4x4_SetScale(&m, .8, 1, .8);
			glMultMatrixf(m.value);

			OGLMatrix4x4_SetRotate_Y(&m, PI);
			glMultMatrixf(m.value);

			MO_DrawGeometry_VertexArray(mesh);

			OGL_SetColor4f(1,1,1,1);
			glPopMatrix();
		}


					/* DRAW OUTER SHELL */


		MO_DrawGeometry_VertexArray(mesh);


		glPopMatrix();
	}


	gGlobalMaterialFlags = 0;
}


#pragma mark -

/****************** MOVE DUST DEVIL ****************************/

static void MoveDustDevil(ObjNode *theNode)
{
short	devilNum = theNode->Mode;


	if (TrackTerrainItem(theNode))							// just check to see if it's gone
	{
		gDustDevilIsUsed[devilNum] = false;
		gNumDustDevils--;
		DeleteObject(theNode);
		return;
	}

	MakeDustDevilDust(theNode);

	SeeIfDustDevilHitsPlayer(theNode);


				/* UPDATE EFFECT */

	if (theNode->EffectChannel == -1)
		theNode->EffectChannel = PlayEffect_Parms3D(EFFECT_DUSTDEVIL, &theNode->Coord, NORMAL_CHANNEL_RATE + (MyRandomLong() & 0x1fff), 1.0);
	else
		Update3DSoundChannel(EFFECT_DUSTDEVIL, &theNode->EffectChannel, &theNode->Coord);


}


/******************** MAKE DUST DEVIL DUST **********************/

static void MakeDustDevilDust(ObjNode *theNode)
{
int		i;
int		particleGroup,magicNum;
NewParticleGroupDefType	groupDef;
NewParticleDefType	newParticleDef;
OGLVector3D			d;
OGLPoint3D			p;

float	fps = gFramesPerSecondFrac;

	GetObjectInfo(theNode);


		/*************/
		/* MAKE DUST */
		/*************/

	theNode->ParticleTimer -= fps;											// see if add smoke
	if (theNode->ParticleTimer <= 0.0f)
	{
		theNode->ParticleTimer += .08;										// reset timer

		particleGroup 	= theNode->ParticleGroup;
		magicNum 		= theNode->ParticleMagicNum;

		if ((particleGroup == -1) || (!VerifyParticleGroupMagicNum(particleGroup, magicNum)))
		{
			theNode->ParticleMagicNum = magicNum = MyRandomLong();			// generate a random magic num

			groupDef.magicNum				= magicNum;
			groupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
			groupDef.flags					= PARTICLE_FLAGS_DONTCHECKGROUND;
			groupDef.gravity				= 10;
			groupDef.magnetism				= 0;
			groupDef.baseScale				= 35.0f;
			groupDef.decayRate				=  -8.0f;
			groupDef.fadeRate				= .25;
			groupDef.particleTextureNum		= PARTICLE_SObjType_GasCloud;
			groupDef.srcBlend				= GL_SRC_ALPHA;
			groupDef.dstBlend				= GL_ONE_MINUS_SRC_ALPHA;
			theNode->ParticleGroup = particleGroup = NewParticleGroup(&groupDef);
		}

		if (particleGroup != -1)
		{
			float	x,y,z;

			x = gCoord.x;
			y = gCoord.y;
			z = gCoord.z;

			for (i = 0; i < 2; i++)
			{
				p.x = x + RandomFloat2() * 190.0f;
				p.y = y + RandomFloat() * 30.0f;
				p.z = z + RandomFloat2() * 190.0f;

				d.x = p.x - x;
				d.y = p.y - y;
				d.z = p.z - z;
				FastNormalizeVector(d.x, d.y, d.z, &d);

				d.x *= 250.0f;
				d.y *= 250.0f;
				d.z *= 250.0f;

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

/************************ PRIME DUST DEVIL *************************/

Boolean PrimeDustDevil(long splineNum, SplineItemType *itemPtr)
{
ObjNode			*newObj;
float			x,z,placement;

			/* GET SPLINE INFO */

	placement = itemPtr->placement;
	GetCoordOnSpline(&gSplineList[splineNum], placement, &x, &z);


				/* MAKE IT */

	newObj = MakeDustDevil(x, z);

				/* SET BETTER INFO */

	newObj->StatusBits		|= STATUS_BIT_ONSPLINE;
	newObj->SplineItemPtr 	= itemPtr;
	newObj->SplineNum 		= splineNum;
	newObj->SplinePlacement = placement;
	newObj->SplineMoveCall 	= MoveDustDevilOnSpline;					// set move call


			/* ADD SPLINE OBJECT TO SPLINE OBJECT LIST */

	DetachObject(newObj, true);										// detach this object from the linked list
	AddToSplineObjectList(newObj, true);

	return(true);
}


/******************** MOVE DUST DEVIL ON SPLINE ***************************/

static void MoveDustDevilOnSpline(ObjNode *theNode)
{
Boolean isInRange;

	isInRange = IsSplineItemOnActiveTerrain(theNode);					// update its visibility

		/* MOVE ALONG THE SPLINE */

	IncreaseSplineIndex(theNode, 65);
	GetObjectCoordOnSpline(theNode);


			/* UPDATE STUFF IF IN RANGE */

	if (isInRange)
	{
		theNode->Rot.y = CalcYAngleFromPointToPoint(theNode->Rot.y, theNode->OldCoord.x, theNode->OldCoord.z,			// calc y rot aim
												theNode->Coord.x, theNode->Coord.z);

		theNode->Coord.y = GetTerrainY(theNode->Coord.x, theNode->Coord.z) - theNode->BottomOff;	// calc y coord


		MakeDustDevilDust(theNode);
		SeeIfDustDevilHitsPlayer(theNode);

					/* UPDATE EFFECT */

		if (theNode->EffectChannel == -1)
			theNode->EffectChannel = PlayEffect_Parms3D(EFFECT_DUSTDEVIL, &theNode->Coord, NORMAL_CHANNEL_RATE - (MyRandomLong() & 0x1fff), 2.0);
		else
			Update3DSoundChannel(EFFECT_DUSTDEVIL, &theNode->EffectChannel, &theNode->Coord);

	}
}


#pragma mark -


/********************* SEE IF DUST DEVIL HITS PLAYER **********************/

static void SeeIfDustDevilHitsPlayer(ObjNode *devil)
{
short	p, r;
ObjNode	*player;
float	distXZ, playerX, playerY, playerZ;

	for (p = 0; p < gNumPlayers; p++)
	{
				/* SEE IF WE CARE ABOUT THIS PLAYER */

		if (gPlayerIsDead[p])										// skip dead players
			continue;

		player = gPlayerInfo[p].objNode;							// get player ObjNode


		switch(player->Skeleton->AnimNum)
		{
			case	PLAYER_ANIM_DEATHDIVE:
			case	PLAYER_ANIM_APPEARWORMHOLE:
			case	PLAYER_ANIM_ENTERWORMHOLE:
			case	PLAYER_ANIM_DUSTDEVIL:
					goto next_p;
		}


			/*******************************************/
			/* SEE IF PLAYER IS IN RANGE OF DUST DEVIL */
			/*******************************************/

		playerX = player->Coord.x;
		playerY = player->Coord.y;
		playerZ = player->Coord.z;
		distXZ = CalcDistance(playerX, playerZ, devil->Coord.x, devil->Coord.z);	// calc XZ dist to center of dust devil


					/* SCAN ONE RIB AT A TIME */

		for (r = 0; r < NUM_RIBS; r++)
		{
			float ribY = gRibOffset[r][0].y + devil->Coord.y;				// calc y coord of rib

			if (playerY > ribY)												// is player above this rib?
			{
				float radius = gRibOffset[r][0].z + 50.0f;					// get radius of rib from first point's z offset (plus a tweak factor)

				if (distXZ < radius)										// is player within this rib's radius?
				{
						/**************/
						/* IT'S A HIT */
						/**************/

					PutPlayerInDirtDevil(player, devil, distXZ);

				}
			}
		}
next_p:;
	}
}



/*********************** PUT PLAYER IN DUST DEVIL ***********************/

static void PutPlayerInDirtDevil(ObjNode *player, ObjNode *dustDevil, float radius)
{
short	p = player->PlayerNum;

	DropEgg_NoWormhole(p);
	JetpackOff(p);

	MorphToSkeletonAnim(player->Skeleton, PLAYER_ANIM_DUSTDEVIL, 3.0);

	player->Timer = 4.0f;									// set duration of time in dust devil

	gPlayerInfo[p].dustDevilObj = dustDevil;
	gPlayerInfo[p].dustDevilRotSpeed = 0;

	gPlayerInfo[p].dustDevilRot = CalcYAngleFromPointToPoint(0, dustDevil->Coord.x, dustDevil->Coord.z,
																	player->Coord.x, player->Coord.z);


	gPlayerInfo[p].radiusFromDustDevil = radius;

	gPlayerInfo[p].ejectedFromDustDevil = false;

}

















