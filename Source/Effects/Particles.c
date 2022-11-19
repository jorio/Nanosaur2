/****************************/
/*   	PARTICLES.C		    */
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

static void DeleteParticleGroup(long groupNum);
static void MoveParticleGroups(ObjNode *theNode);
static void PurgePendingParticleGroups(Boolean forcePurgeNow);
static void UpdateParticleGroupsGeometry(void);
static void DrawParticleGroups(ObjNode *theNode);

static void MoveSmoker(ObjNode *theNode);
static void DrawFlame(ObjNode *theNode);
static void MoveFlame(ObjNode *theNode);

static void MoveFireRing(ObjNode *theNode);
static void DrawFireRing(ObjNode *theNode);


/****************************/
/*    CONSTANTS             */
/****************************/

#define	FIRE_BLAST_RADIUS			(gTerrainPolygonSize * 1.5f)

#define	FIRE_TIMER	.05f
#define	SMOKE_TIMER	.07f


/*********************/
/*    VARIABLES      */
/*********************/

ParticleGroupType	*gParticleGroups[MAX_PARTICLE_GROUPS];

static float	gGravitoidDistBuffer[MAX_PARTICLES][MAX_PARTICLES];

NewParticleGroupDefType	gNewParticleGroupDef;

short			gNumActiveParticleGroups = 0;

#define	RippleTimer	SpecialF[0]

#define FlameFrame Special[0]
#define FlameSpeed SpecialF[0]


/************************ INIT PARTICLE SYSTEM **************************/

void InitParticleSystem(void)
{
			/* INIT GROUP ARRAY */

	for (int i = 0; i < MAX_PARTICLE_GROUPS; i++)
		gParticleGroups[i] = nil;

	gNumActiveParticleGroups = 0;



			/* LOAD SPRITES */

	LoadSpriteGroup(SPRITE_GROUP_PARTICLES, ":sprites:particle.sprites", 0);

	BlendAllSpritesInGroup(SPRITE_GROUP_PARTICLES);


		/*************************************************************************/
		/* CREATE DUMMY CUSTOM OBJECT TO CAUSE PARTICLE DRAWING AT THE DESIRED TIME */
		/*************************************************************************/
		//
		// The particles need to be drawn after the fences object, but before any sprite or font objects.
		//

	NewObjectDefinitionType def =
	{
		.genre		= CUSTOM_GENRE,
		.slot		= PARTICLE_SLOT,
		.scale		= 1,
		.flags		= STATUS_BIT_DOUBLESIDED|STATUS_BIT_NOLIGHTING|STATUS_BIT_NOZWRITES|STATUS_BIT_NOFOG|STATUS_BIT_GLOW,
		.moveCall	= MoveParticleGroups,
		.drawCall	= DrawParticleGroups,
	};
	ObjNode* obj = MakeNewObject(&def);
	obj->VertexArrayMode = VERTEX_ARRAY_RANGE_TYPE_PARTICLES1;
}


/******************** DISPOSE PARTICLE SYSTEM **********************/

void DisposeParticleSystem(void)
{
	DisposeSpriteGroup(SPRITE_GROUP_PARTICLES);
}


/******************** DELETE ALL PARTICLE GROUPS *********************/

void DeleteAllParticleGroups(void)
{
long	i;

	for (i = 0; i < MAX_PARTICLE_GROUPS; i++)
	{
		DeleteParticleGroup(i);
	}

	PurgePendingParticleGroups(true);			// force it to purge immediately!
}


/******************* DELETE PARTICLE GROUP ***********************/
//
// With vertex arrays ranges we've got to be careful.  We cannot immediately delete the data
// and allow it to be re-allocated since it might still be in use by the GPU.
//
// Therefore, we actually put the particle group into a purge queue so that there's time for the
// GPU to finish with it.
//

static void DeleteParticleGroup(long groupNum)
{
	if (gParticleGroups[groupNum])
	{
		gParticleGroups[groupNum]->inPurgeQueue = true;
		gParticleGroups[groupNum]->purgeTimer = 2;
	}
}


/****************** PURGE PENDING PARTICLE GROUPS ********************/
//
// Checks all deleted particle groups to see if they're ok to be purged now (see above).
//

static void PurgePendingParticleGroups(Boolean forcePurgeNow)
{
short	i, g;

	for (g = 0; g < MAX_PARTICLE_GROUPS; g++)
	{
		if (gParticleGroups[g])							// does this pg exist?
		{
			if (gParticleGroups[g]->inPurgeQueue)		// is it in the purge queue?
			{
				gParticleGroups[g]->purgeTimer--;

				if (forcePurgeNow || (gParticleGroups[g]->purgeTimer <= 0))	// time to purge?
				{
						/* NUKE GEOMETRY DATA */

					for (i = 0; i < gNumPlayers; i++)
					{
						MO_DisposeObjectReference(gParticleGroups[g]->geometryObj[0][i]);
						MO_DisposeObjectReference(gParticleGroups[g]->geometryObj[1][i]);
					}


							/* NUKE GROUP ITSELF */

					SafeDisposePtr((Ptr)gParticleGroups[g]);
					gParticleGroups[g] = nil;

					gNumActiveParticleGroups--;
				}
			}
		}
	}
}


#pragma mark -


/********************** NEW PARTICLE GROUP *************************/
//
// INPUT:	type 	=	group type to create
//
// OUTPUT:	group ID#
//

short NewParticleGroup(NewParticleGroupDefType *def)
{
short					p,i,j,k,b;
OGLTextureCoord			*uv;
MOVertexArrayData 		vertexArrayData;
MOTriangleIndecies		*t;


			/*************************/
			/* SCAN FOR A FREE GROUP */
			/*************************/

	for (i = 0; i < MAX_PARTICLE_GROUPS; i++)
	{
		if (gParticleGroups[i] == nil)
		{
				/* ALLOCATE NEW GROUP */

			gParticleGroups[i] = (ParticleGroupType *)AllocPtr(sizeof(ParticleGroupType));
			if (gParticleGroups[i] == nil)
				return(-1);									// out of memory


				/* INITIALIZE THE GROUP */

			gParticleGroups[i]->type = def->type;						// set type
			for (p = 0; p < MAX_PARTICLES; p++)							// mark all unused
				gParticleGroups[i]->isUsed[p] = false;

			gParticleGroups[i]->inPurgeQueue		= false;

			gParticleGroups[i]->flags 				= def->flags;
			gParticleGroups[i]->gravity 			= def->gravity;
			gParticleGroups[i]->magnetism 			= def->magnetism;
			gParticleGroups[i]->baseScale 			= def->baseScale;
			gParticleGroups[i]->decayRate 			= def->decayRate;
			gParticleGroups[i]->fadeRate 			= def->fadeRate;
			gParticleGroups[i]->magicNum 			= def->magicNum;
			gParticleGroups[i]->particleTextureNum 	= def->particleTextureNum;

			gParticleGroups[i]->srcBlend 			= def->srcBlend;
			gParticleGroups[i]->dstBlend 			= def->dstBlend;

				/*****************************/
				/* INIT THE GROUP'S GEOMETRY */
				/*****************************/
				//
				// We create 4 separate vertex arrary objects because we double buffer this, once for each player.
				// This way we can modify one VAR while the GPU is still drawing the other VAR.
				// Doing this should be more efficient than using OpenGL Fences because we won't
				// have to wait for the previous frame to complete drawing before we can modify
				// this frame's particle geometry.
				//

			for (b = 0; b < 2; b++)
			{
				short	playerNum;

				for (playerNum = 0; playerNum < gNumPlayers; playerNum++)
				{
							/* SET THE DATA */

					vertexArrayData.VARtype			= VERTEX_ARRAY_RANGE_TYPE_PARTICLES1 + b;

					vertexArrayData.numMaterials 	= 1;
					vertexArrayData.materials[0]	= gSpriteGroupList[SPRITE_GROUP_PARTICLES][def->particleTextureNum].materialObject;	// set illegal ref because it is made legit below

					vertexArrayData.numPoints 		= 0;
					vertexArrayData.numTriangles 	= 0;
					vertexArrayData.points 			= OGL_AllocVertexArrayMemory(sizeof(OGLPoint3D) * MAX_PARTICLES * 4, vertexArrayData.VARtype);
					vertexArrayData.normals 		= nil;
					vertexArrayData.uvs[0]	 		= OGL_AllocVertexArrayMemory(sizeof(OGLTextureCoord) * MAX_PARTICLES * 4, vertexArrayData.VARtype);
					vertexArrayData.colorsFloat		= OGL_AllocVertexArrayMemory(sizeof(OGLColorRGBA) * MAX_PARTICLES * 4, vertexArrayData.VARtype);
					vertexArrayData.triangles		= OGL_AllocVertexArrayMemory(sizeof(MOTriangleIndecies) * MAX_PARTICLES * 2, vertexArrayData.VARtype);


							/* INIT UV ARRAYS */

					uv = vertexArrayData.uvs[0];
					for (j=0; j < (MAX_PARTICLES*4); j+=4)
					{
						uv[j].u = 0;									// upper left
						uv[j].v = 1;
						uv[j+1].u = 0;									// lower left
						uv[j+1].v = 0;
						uv[j+2].u = 1;									// lower right
						uv[j+2].v = 0;
						uv[j+3].u = 1;									// upper right
						uv[j+3].v = 1;
					}

							/* INIT TRIANGLE ARRAYS */

					t = vertexArrayData.triangles;
					for (j = k = 0; j < (MAX_PARTICLES*2); j+=2, k+=4)
					{
						t[j].vertexIndices[0] = k;							// triangle A
						t[j].vertexIndices[1] = k+1;
						t[j].vertexIndices[2] = k+2;

						t[j+1].vertexIndices[0] = k;							// triangle B
						t[j+1].vertexIndices[1] = k+2;
						t[j+1].vertexIndices[2] = k+3;
					}


						/* CREATE NEW GEOMETRY OBJECT */

					gParticleGroups[i]->geometryObj[b][playerNum] = MO_CreateNewObjectOfType(MO_TYPE_GEOMETRY, MO_GEOMETRY_SUBTYPE_VERTEXARRAY, &vertexArrayData);
				}
			}

			gNumActiveParticleGroups++;

			return(i);
		}
	}

			/* NOTHING FREE */

//	DoFatalAlert("NewParticleGroup: no free groups!");
	return(-1);
}


/******************** ADD PARTICLE TO GROUP **********************/
//
// Returns true if particle group was invalid or is full.
//

Boolean AddParticleToGroup(const NewParticleDefType *def)
{
short	p,group;

	group = def->groupNum;

	if ((group < 0) || (group >= MAX_PARTICLE_GROUPS))
		DoFatalAlert("AddParticleToGroup: illegal group #");

	if (gParticleGroups[group] == nil)
	{
		return(true);
	}


			/* SCAN FOR FREE SLOT */

	for (p = 0; p < MAX_PARTICLES; p++)
	{
		if (!gParticleGroups[group]->isUsed[p])
			goto got_it;
	}

			/* NO FREE SLOTS */

	return(true);


			/* INIT PARAMETERS */
got_it:
	gParticleGroups[group]->alpha[p] = def->alpha;
	gParticleGroups[group]->scale[p] = def->scale;
	gParticleGroups[group]->coord[p] = *def->where;
	gParticleGroups[group]->delta[p] = *def->delta;
	gParticleGroups[group]->rotZ[p] = def->rotZ;
	gParticleGroups[group]->rotDZ[p] = def->rotDZ;
	gParticleGroups[group]->isUsed[p] = true;



	return(false);
}


/****************** MOVE PARTICLE GROUPS *********************/

static void MoveParticleGroups(ObjNode *theNode)
{
uint32_t		flags;
long		i,n,p,j;
float		fps = gFramesPerSecondFrac;
float		y,baseScale,oneOverBaseScaleSquared,gravity;
float		decayRate,magnetism,fadeRate;
OGLPoint3D	*coord;
OGLVector3D	*delta;
short		buffNum, varMode;

				/* FIRST UPDATE THE PURGE QUEUE */

	PurgePendingParticleGroups(false);


				/* GET VAR BUFFER & UPDATE PARTICLES */

	buffNum = gGameViewInfoPtr->frameCount & 1;								// which VAR buffer to use?

	varMode = theNode->VertexArrayMode = VERTEX_ARRAY_RANGE_TYPE_PARTICLES1 + buffNum;	// update the VAR range info


	for (i = 0; i < MAX_PARTICLE_GROUPS; i++)
	{
		if (gParticleGroups[i])
		{
			if (gParticleGroups[i]->inPurgeQueue)							// is this particle group pending purging?
				continue;

			OGL_SetVertexArrayRangeDirty(varMode);							// VAR is being updated

			baseScale 	= gParticleGroups[i]->baseScale;					// get base scale
			oneOverBaseScaleSquared = 1.0f/(baseScale*baseScale);
			gravity 	= gParticleGroups[i]->gravity;						// get gravity
			decayRate 	= gParticleGroups[i]->decayRate;					// get decay rate
			fadeRate 	= gParticleGroups[i]->fadeRate;						// get fade rate
			magnetism 	= gParticleGroups[i]->magnetism;					// get magnetism
			flags 		= gParticleGroups[i]->flags;

			n = 0;															// init counter
			for (p = 0; p < MAX_PARTICLES; p++)
			{
				if (!gParticleGroups[i]->isUsed[p])							// make sure this particle is used
					continue;

				n++;														// inc counter
				delta = &gParticleGroups[i]->delta[p];						// get ptr to deltas
				coord = &gParticleGroups[i]->coord[p];						// get ptr to coords

							/* ADD GRAVITY */

				delta->y -= gravity * fps;									// add gravity


						/* DO ROTATION */

				gParticleGroups[i]->rotZ[p] += gParticleGroups[i]->rotDZ[p] * fps;




				switch(gParticleGroups[i]->type)
				{
							/* FALLING SPARKS */

					case	PARTICLE_TYPE_FALLINGSPARKS:
							coord->x += delta->x * fps;						// move it
							coord->y += delta->y * fps;
							coord->z += delta->z * fps;
							break;


							/* GRAVITOIDS */
							//
							// Every particle has gravity pull on other particle
							//

					case	PARTICLE_TYPE_GRAVITOIDS:
							for (j = MAX_PARTICLES-1; j >= 0; j--)
							{
								float		dist,temp,x,z;
								OGLVector3D	v;

								if (p==j)									// dont check against self
									continue;
								if (!gParticleGroups[i]->isUsed[j])			// make sure this particle is used
									continue;

								x = gParticleGroups[i]->coord[j].x;
								y = gParticleGroups[i]->coord[j].y;
								z = gParticleGroups[i]->coord[j].z;

										/* calc 1/(dist2) */

								if (i < j)									// see if calc or get from buffer
								{
									temp = coord->x - x;					// dx squared
									dist = temp*temp;
									temp = coord->y - y;					// dy squared
									dist += temp*temp;
									temp = coord->z - z;					// dz squared
									dist += temp*temp;

									dist = sqrt(dist);						// 1/dist2
									if (dist != 0.0f)
										dist = 1.0f / (dist*dist);

									if (dist > oneOverBaseScaleSquared)		// adjust if closer than radius
										dist = oneOverBaseScaleSquared;

									gGravitoidDistBuffer[i][j] = dist;		// remember it
								}
								else
								{
									dist = gGravitoidDistBuffer[j][i];		// use from buffer
								}

											/* calc vector to particle */

								if (dist != 0.0f)
								{
									x = x - coord->x;
									y = y - coord->y;
									z = z - coord->z;
									FastNormalizeVector(x, y, z, &v);
								}
								else
								{
									v.x = v.y = v.z = 0;
								}

								delta->x += v.x * (dist * magnetism * fps);		// apply gravity to particle
								delta->y += v.y * (dist * magnetism * fps);
								delta->z += v.z * (dist * magnetism * fps);
							}

							coord->x += delta->x * fps;						// move it
							coord->y += delta->y * fps;
							coord->z += delta->z * fps;
							break;
				}

					/********************/
					/* SEE IF HAS MAX Y */
					/********************/

				if (flags & PARTICLE_FLAGS_HASMAXY)
				{
					if (coord->y > gParticleGroups[i]->maxY)
					{
						gParticleGroups[i]->isUsed[p] = false;
					}
				}


				/*****************/
				/* SEE IF BOUNCE */
				/*****************/

				if (!(flags & PARTICLE_FLAGS_DONTCHECKGROUND))
				{
					y = GetTerrainY(coord->x, coord->z)+10.0f;					// get terrain coord at particle x/z

					if (flags & PARTICLE_FLAGS_BOUNCE)
					{
						if (delta->y < 0.0f)									// if moving down, see if hit floor
						{
							if (coord->y < y)
							{
								coord->y = y;
								delta->y *= -.4f;

								delta->x += gRecentTerrainNormal.x * 300.0f;	// reflect off of surface
								delta->z += gRecentTerrainNormal.z * 300.0f;

								if (flags & PARTICLE_FLAGS_DISPERSEIFBOUNCE)	// see if disperse on impact
								{
									delta->y *= .4f;
									delta->x *= 5.0f;
									delta->z *= 5.0f;
								}
							}
						}
					}

					/***************/
					/* SEE IF GONE */
					/***************/

					else
					{
						if (coord->y < y)									// if hit floor then nuke particle
						{
							gParticleGroups[i]->isUsed[p] = false;
						}
					}
				}


					/* DO SCALE */

				gParticleGroups[i]->scale[p] -= decayRate * fps;			// shrink it
				if (gParticleGroups[i]->scale[p] <= 0.0f)					// see if gone
					gParticleGroups[i]->isUsed[p] = false;

					/* DO FADE */

				gParticleGroups[i]->alpha[p] -= fadeRate * fps;				// fade it
				if (gParticleGroups[i]->alpha[p] <= 0.0f)					// see if gone
					gParticleGroups[i]->isUsed[p] = false;


			}

				/* SEE IF GROUP WAS EMPTY, THEN DELETE */

			if (n == 0)
			{
				DeleteParticleGroup(i);
			}
		}
	}


			/***************************************/
			/* UPDATE ALL PARTICLE GROUPS GEOMETRY */
			/***************************************/

	UpdateParticleGroupsGeometry();
}




/**************** UPDATE PARTICLE GROUPS GEOMETRY *********************/

static void UpdateParticleGroupsGeometry(void)
{
float				scale,baseScale;
OGLColorRGBA		*vertexColors;
MOVertexArrayData	*geoData;
OGLPoint3D			v[4],*coord;
static const OGLVector3D up = {0,1,0};
const OGLPoint3D	*camCoords;
short				paneNum;


	int buffNum = gGameViewInfoPtr->frameCount & 1;			// which VAR buffer to use?


	v[0].z = 												// init z's to 0
	v[1].z =
	v[2].z =
	v[3].z = 0;


			/*****************************************/
			/* BUILD GEOMETRY FOR EACH PLAYER'S PANE */
			/*****************************************/

	for (paneNum = 0; paneNum < gNumPlayers; paneNum++)
	{
				/* GET CAMERA INFO FOR THIS PANE */

		camCoords = &gGameViewInfoPtr->cameraPlacement[paneNum].cameraLocation;

					/******************************/
					/* UPDATE EACH PARTICLE GROUP */
					/******************************/

		for (int g = 0; g < MAX_PARTICLE_GROUPS; g++)
		{
			float	minX,minY,minZ,maxX,maxY,maxZ;
			uint32_t	allAim;

			if (gParticleGroups[g])
			{
				if (gParticleGroups[g]->inPurgeQueue)							// skip if it's in the purge queue
					continue;

				allAim 		= gParticleGroups[g]->flags & PARTICLE_FLAGS_ALLAIM;

				geoData 	= &gParticleGroups[g]->geometryObj[buffNum][paneNum]->objectData;	// get pointer to geometry object data
				vertexColors = geoData->colorsFloat;							// get pointer to vertex color array
				baseScale 	= gParticleGroups[g]->baseScale;					// get base scale


						/********************************/
						/* ADD ALL PARTICLES TO TRIMESH */
						/********************************/

				minX = minY = minZ = 100000000;									// init bbox
				maxX = maxY = maxZ = -minX;

				int n = 0;
				for (int p = 0; p < MAX_PARTICLES; p++)
				{
					float			rot;
					OGLMatrix4x4	m;

					if (!gParticleGroups[g]->isUsed[p])							// make sure this particle is used
						continue;

								/* CREATE VERTEX DATA */

					scale = gParticleGroups[g]->scale[p] * baseScale;

					v[0].x = -scale;
					v[0].y = scale;

					v[1].x = -scale;
					v[1].y = -scale;

					v[2].x = scale;
					v[2].y = -scale;

					v[3].x = scale;
					v[3].y = scale;


						/* TRANSFORM THIS PARTICLE'S VERTICES & ADD TO TRIMESH */

					coord = &gParticleGroups[g]->coord[p];						// get particle's coord

					if ((n == 0) || allAim)										// only set the look-at matrix for the 1st particle unless we want to force it for all (optimization technique)
						SetLookAtMatrixAndTranslate(&m, &up, coord, camCoords);	// aim at camera & translate
					else
					{
						m.value[M03] = coord->x;								// update just the translate
						m.value[M13] = coord->y;
						m.value[M23] = coord->z;
					}

					rot = gParticleGroups[g]->rotZ[p];							// get z rotation
					if (rot != 0.0f)											// see if need to apply rotation matrix
					{
						OGLMatrix4x4	rm;

						OGLMatrix4x4_SetRotate_Z(&rm, rot);
						OGLMatrix4x4_Multiply(&rm, &m, &rm);
						OGLPoint3D_TransformArray(&v[0], &rm, &geoData->points[n*4], 4);	// transform w/ rot
					}
					else
						OGLPoint3D_TransformArray(&v[0], &m, &geoData->points[n*4], 4);		// transform no-rot


								/* UPDATE BBOX */

					for (int i = 0; i < 4; i++)
					{
						int j = n*4+i;

						if (geoData->points[j].x < minX)
							minX = geoData->points[j].x;
						if (geoData->points[j].x > maxX)
							maxX = geoData->points[j].x;
						if (geoData->points[j].y < minY)
							minY = geoData->points[j].y;
						if (geoData->points[j].y > maxY)
							maxY = geoData->points[j].y;
						if (geoData->points[j].z < minZ)
							minZ = geoData->points[j].z;
						if (geoData->points[j].z > maxZ)
							maxZ = geoData->points[j].z;
					}

						/* UPDATE COLOR/TRANSPARENCY */

					int temp = n*4;
					for (int i = temp; i < (temp+4); i++)
					{
						vertexColors[i].r =
						vertexColors[i].g =
						vertexColors[i].b = 1.0;
						vertexColors[i].a = gParticleGroups[g]->alpha[p];		// set transparency alpha
					}

					n++;											// inc particle count
				}

				if (n == 0)											// if no particles, then skip
					continue;

					/* UPDATE FINAL VALUES */

				geoData->numTriangles = n*2;
				geoData->numPoints = n*4;


					/* SET BBOX FOR CULLING DURING DRAW */

				gParticleGroups[g]->bbox.min.x = minX;				// build bbox for culling test
				gParticleGroups[g]->bbox.min.y = minY;
				gParticleGroups[g]->bbox.min.z = minZ;
				gParticleGroups[g]->bbox.max.x = maxX;
				gParticleGroups[g]->bbox.max.y = maxY;
				gParticleGroups[g]->bbox.max.z = maxZ;

//				gParticleGroups[g]->isCulled[paneNum] = !OGL_IsBBoxVisible(&bbox, nil);
			}
		}
	}		// for paneNum


}






/**************** DRAW PARTICLE GROUPS *********************/

static void DrawParticleGroups(ObjNode *theNode)
{
long				g, buffNum;
short				paneNum = gCurrentSplitScreenPane;
Boolean				isVisible;

#pragma unused(theNode)


			/* DRAW SOME OTHER GOODIES WHILE WE'RE HERE */

	DrawSparkles();												// draw light sparkles


				/* SETUP ENVIRONTMENT */

	OGL_PushState();
	OGL_EnableBlend();
	OGL_SetColor4f(1,1,1,1);												// full white & alpha to start with

	buffNum = gGameViewInfoPtr->frameCount & 1;								// which VAR buffer to use?

	for (g = 0; g < MAX_PARTICLE_GROUPS; g++)
	{
		if (gParticleGroups[g])
		{
			if (gParticleGroups[g]->inPurgeQueue)							// skip if it's in the purge queue
				continue;


			isVisible = OGL_IsBBoxVisible(&gParticleGroups[g]->bbox, nil);


			if (isVisible)													// if not culled then draw it
			{
				GLint	src,dst;

				src = gParticleGroups[g]->srcBlend;
				dst = gParticleGroups[g]->dstBlend;


					/* DRAW IT */

				OGL_BlendFunc(src, dst);														// set blending mode
				MO_DrawObject(gParticleGroups[g]->geometryObj[buffNum][paneNum]);	// draw geometry
			}
		}
	}

			/* RESTORE MODES */

	OGL_PopState();
	OGL_SetColor4f(1,1,1,1);										// reset this

}



#pragma mark -

/**************** VERIFY PARTICLE GROUP MAGIC NUM ******************/

Boolean VerifyParticleGroupMagicNum(short group, uint32_t magicNum)
{
	if (gParticleGroups[group] == nil)
		return(false);

	if (gParticleGroups[group]->magicNum != magicNum)
		return(false);

	return(true);
}


/************* PARTICLE HIT OBJECT *******************/
//
// INPUT:	inFlags = flags to check particle types against
//

Boolean ParticleHitObject(ObjNode *theNode, uint16_t inFlags)
{
int		i,p;
uint32_t	flags;
OGLPoint3D	*coord;

	for (i = 0; i < MAX_PARTICLE_GROUPS; i++)
	{
		if (!gParticleGroups[i])									// see if group active
			continue;

		if (inFlags)												// see if check flags
		{
			flags = gParticleGroups[i]->flags;
			if (!(inFlags & flags))
				continue;
		}

		for (p = 0; p < MAX_PARTICLES; p++)
		{
			if (!gParticleGroups[i]->isUsed[p])						// make sure this particle is used
				continue;

			if (gParticleGroups[i]->alpha[p] < .4f)				// if particle is too decayed, then skip
				continue;

			coord = &gParticleGroups[i]->coord[p];					// get ptr to coords
			if (DoSimpleBoxCollisionAgainstObject(coord->y+40.0f,coord->y-40.0f,
												coord->x-40.0f, coord->x+40.0f,
												coord->z+40.0f, coord->z-40.0f,
												theNode))
			{
				return(true);
			}
		}
	}
	return(false);
}

#pragma mark -

/********************* MAKE PUFF ***********************/

void MakePuff(short numPuffs, OGLPoint3D *where, float scale, short texNum, GLint src, GLint dst, float decayRate)
{
long					pg,i;
OGLVector3D				delta;
OGLPoint3D				pt;
NewParticleDefType		newParticleDef;
float					x,y,z;

			/* white sparks */

	gNewParticleGroupDef.magicNum				= 0;
	gNewParticleGroupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
	gNewParticleGroupDef.flags					= PARTICLE_FLAGS_BOUNCE|PARTICLE_FLAGS_ALLAIM;
	gNewParticleGroupDef.gravity				= -80;
	gNewParticleGroupDef.magnetism				= 0;
	gNewParticleGroupDef.baseScale				= scale;
	gNewParticleGroupDef.decayRate				=  -1.6;
	gNewParticleGroupDef.fadeRate				= decayRate;
	gNewParticleGroupDef.particleTextureNum		= texNum;
	gNewParticleGroupDef.srcBlend				= src;
	gNewParticleGroupDef.dstBlend				= dst;

	pg = NewParticleGroup(&gNewParticleGroupDef);
	if (pg != -1)
	{
		x = where->x;
		y = where->y;
		z = where->z;

		for (i = 0; i < numPuffs; i++)
		{
			pt.x = x + RandomFloat2() * (2.0f * scale);
			pt.y = y + RandomFloat() * 2.0f * scale;
			pt.z = z + RandomFloat2() * (2.0f * scale);

			delta.x = RandomFloat2() * (3.0f * scale);
			delta.y = RandomFloat() * (2.0f  * scale);
			delta.z = RandomFloat2() * (3.0f * scale);


			newParticleDef.groupNum		= pg;
			newParticleDef.where		= &pt;
			newParticleDef.delta		= &delta;
			newParticleDef.scale		= 1.0f + RandomFloat2() * .2f;
			newParticleDef.rotZ			= RandomFloat() * PI2;
			newParticleDef.rotDZ		= RandomFloat2() * 4.0f;
			newParticleDef.alpha		= FULL_ALPHA;
			AddParticleToGroup(&newParticleDef);
		}
	}
}


/********************* MAKE SPARK EXPLOSION ***********************/

void MakeSparkExplosion(const OGLPoint3D *coord, float force, float scale, short sparkTexture, short quantityLimit, float fadeRate)
{
long					pg,i,n;
OGLVector3D				delta,v;
OGLPoint3D				pt;
NewParticleDefType		newParticleDef;
float					x,y,z;

	x = coord->x;
	y = coord->y;
	z = coord->z;


	n = force * .3f;

	if (quantityLimit)
		if (n > quantityLimit)
			n = quantityLimit;


			/* white sparks */

	gNewParticleGroupDef.magicNum				= 0;
	gNewParticleGroupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
	gNewParticleGroupDef.flags					= PARTICLE_FLAGS_BOUNCE;
	gNewParticleGroupDef.gravity				= 200;
	gNewParticleGroupDef.magnetism				= 0;
	gNewParticleGroupDef.baseScale				= 15.0f * scale;
	gNewParticleGroupDef.decayRate				=  0;
	gNewParticleGroupDef.fadeRate				= fadeRate;
	gNewParticleGroupDef.particleTextureNum		= sparkTexture;
	gNewParticleGroupDef.srcBlend				= GL_SRC_ALPHA;
	gNewParticleGroupDef.dstBlend				= GL_ONE;

	pg = NewParticleGroup(&gNewParticleGroupDef);
	if (pg != -1)
	{
		for (i = 0; i < n; i++)
		{
			pt.x = x + RandomFloat2() * (30.0f * scale);
			pt.y = y + RandomFloat2() * (30.0f * scale);
			pt.z = z + RandomFloat2() * (30.0f * scale);

			v.x = pt.x - x;
			v.y = pt.y - y;
			v.z = pt.z - z;
			FastNormalizeVector(v.x,v.y,v.z,&v);

			delta.x = v.x * (force * scale);
			delta.y = v.y * (force * scale);
			delta.z = v.z * (force * scale);


			newParticleDef.groupNum		= pg;
			newParticleDef.where		= &pt;
			newParticleDef.delta		= &delta;
			newParticleDef.scale		= 1.0f + RandomFloat()  * .5f;
			newParticleDef.rotZ			= 0;
			newParticleDef.rotDZ		= 0;
			newParticleDef.alpha		= FULL_ALPHA;
			if (AddParticleToGroup(&newParticleDef))
				break;
		}
	}
}

/****************** MAKE STEAM ************************/

void MakeSteam(ObjNode *theNode, float x, float y, float z)
{
int		i;
float	fps = gFramesPerSecondFrac;
int		particleGroup,magicNum;
NewParticleGroupDefType	groupDef;
NewParticleDefType	newParticleDef;
OGLVector3D			d;
OGLPoint3D			p;
const float scale = 1.8f;

		/**************/
		/* MAKE SMOKE */
		/**************/

	theNode->ParticleTimer -= fps;													// see if add smoke
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
			groupDef.gravity				= 0;
			groupDef.magnetism				= 0;
			groupDef.baseScale				= 20.0f * scale;
			groupDef.decayRate				=  -.2f;
			groupDef.fadeRate				= .2;
			groupDef.particleTextureNum		= PARTICLE_SObjType_GreySmoke;
			groupDef.srcBlend				= GL_SRC_ALPHA;
			groupDef.dstBlend				= GL_ONE_MINUS_SRC_ALPHA;
			theNode->ParticleGroup = particleGroup = NewParticleGroup(&groupDef);
		}

		if (particleGroup != -1)
		{
			for (i = 0; i < 2; i++)
			{
				p.x = x + RandomFloat2() * (40.0f * scale);
				p.y = y + RandomFloat() * (50.0f * scale);
				p.z = z + RandomFloat2() * (40.0f * scale);

				d.x = RandomFloat2() * (20.0f * scale);
				d.y = 150.0f + RandomFloat() * (40.0f * scale);
				d.z = RandomFloat2() * (20.0f * scale);

				newParticleDef.groupNum		= particleGroup;
				newParticleDef.where		= &p;
				newParticleDef.delta		= &d;
				newParticleDef.scale		= RandomFloat() + 1.0f;
				newParticleDef.rotZ			= RandomFloat() * PI2;
				newParticleDef.rotDZ		= RandomFloat2();
				newParticleDef.alpha		= .7;
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


/************** MAKE BOMB EXPLOSION *********************/

void MakeBombExplosion(float x, float z, OGLVector3D *delta)
{
long					pg,i;
OGLVector3D				d;
OGLPoint3D				pt;
NewParticleDefType		newParticleDef;
float					y;
float					dx,dz;
OGLPoint3D				where;

	where.x = x;
	where.z = z;
	where.y = GetTerrainY(x,z);

		/*********************/
		/* FIRST MAKE SPARKS */
		/*********************/

	gNewParticleGroupDef.magicNum				= 0;
	gNewParticleGroupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
	gNewParticleGroupDef.flags					= PARTICLE_FLAGS_BOUNCE;
	gNewParticleGroupDef.gravity				= 900;
	gNewParticleGroupDef.magnetism				= 0;
	gNewParticleGroupDef.baseScale				= 190;
	gNewParticleGroupDef.decayRate				=  .4;
	gNewParticleGroupDef.fadeRate				= .7;
	gNewParticleGroupDef.particleTextureNum		= PARTICLE_SObjType_WhiteSpark3;
	gNewParticleGroupDef.srcBlend				= GL_SRC_ALPHA;
	gNewParticleGroupDef.dstBlend				= GL_ONE;
	pg = NewParticleGroup(&gNewParticleGroupDef);
	if (pg != -1)
	{
		x = where.x;
		y = where.y;
		z = where.z;
		dx = delta->x * .2f;
		dz = delta->z * .2f;


		for (i = 0; i < 20; i++)
		{
			pt.x = x + (RandomFloat()-.5f) * 200.0f;
			pt.y = y + RandomFloat() * 60.0f;
			pt.z = z + (RandomFloat()-.5f) * 200.0f;

			d.y = RandomFloat() * 1500.0f;
			d.x = (RandomFloat()-.5f) * d.y * 3.0f + dx;
			d.z = (RandomFloat()-.5f) * d.y * 3.0f + dz;


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


}




#pragma mark -

/********************* MAKE SPLASH ***********************/

void MakeSplash(OGLPoint3D *where, float scale)
{
long	pg,i;
OGLVector3D	delta;
OGLPoint3D	pt;
NewParticleDefType		newParticleDef;
float	x,z;

	x = where->x;
	z = where->z;
	pt.y = where->y;

	gNewParticleGroupDef.magicNum				= 0;
	gNewParticleGroupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
	gNewParticleGroupDef.flags					= PARTICLE_FLAGS_ALLAIM;
	gNewParticleGroupDef.gravity				= 400;
	gNewParticleGroupDef.magnetism				= 0;
	gNewParticleGroupDef.baseScale				= 15.0f * scale;
	gNewParticleGroupDef.decayRate				=  -.6;
	gNewParticleGroupDef.fadeRate				= .8;
	gNewParticleGroupDef.particleTextureNum		= PARTICLE_SObjType_Splash;
	gNewParticleGroupDef.srcBlend				= GL_SRC_ALPHA;
	gNewParticleGroupDef.dstBlend				= GL_ONE;


	pg = NewParticleGroup(&gNewParticleGroupDef);
	if (pg != -1)
	{
		for (i = 0; i < 30; i++)
		{
			pt.x = x + RandomFloat2() * (30.0f * scale);
			pt.z = z + RandomFloat2() * (30.0f * scale);

			delta.x = RandomFloat2() * (200.0f * scale);
			delta.y = RandomFloat() * (150.0f * scale);
			delta.z = RandomFloat2() * (200.0f * scale);

			newParticleDef.groupNum		= pg;
			newParticleDef.where		= &pt;
			newParticleDef.delta		= &delta;
			newParticleDef.scale		= RandomFloat() + 1.0f;
			newParticleDef.rotZ			= 0;
			newParticleDef.rotDZ		= RandomFloat2()*PI2;
			newParticleDef.alpha		= FULL_ALPHA;
			AddParticleToGroup(&newParticleDef);
		}
	}


			/* MAKE RIPPLE */

	CreateNewRipple(where, 25.0, 150.0, .5);



			/* PLAY SPLASH SOUND */

	PlayEffect_Parms3D(EFFECT_SPLASH, where, NORMAL_CHANNEL_RATE, 1.5);
}


/***************** SPRAY WATER *************************/

void SprayWater(ObjNode *theNode, float x, float y, float z)
{
float	fps = gFramesPerSecondFrac;
int		particleGroup, magicNum;
short	i;

	theNode->ParticleTimer -= fps;				// see if time to spew water
	if (theNode->ParticleTimer <= 0.0f)
	{
		theNode->ParticleTimer += .05f;

		particleGroup 	= theNode->ParticleGroup;
		magicNum 		= theNode->ParticleMagicNum;

		if ((particleGroup == -1) || (!VerifyParticleGroupMagicNum(particleGroup, magicNum)))
		{
			theNode->SmokeParticleMagic = magicNum = MyRandomLong();			// generate a random magic num

			gNewParticleGroupDef.magicNum				= magicNum;
			gNewParticleGroupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
			gNewParticleGroupDef.flags					= 0;
			gNewParticleGroupDef.gravity				= 800;
			gNewParticleGroupDef.magnetism				= 0;
			gNewParticleGroupDef.baseScale				= 10;
			gNewParticleGroupDef.decayRate				=  -1.7f;
			gNewParticleGroupDef.fadeRate				= 1.5;
			gNewParticleGroupDef.particleTextureNum		= PARTICLE_SObjType_Splash;
			gNewParticleGroupDef.srcBlend				= GL_SRC_ALPHA;
			gNewParticleGroupDef.dstBlend				= GL_ONE;
			theNode->SmokeParticleGroup = particleGroup = NewParticleGroup(&gNewParticleGroupDef);
		}


					/* ADD PARTICLE TO GROUP */

		if (particleGroup != -1)
		{
			OGLPoint3D	pt;
			OGLVector3D delta;
			NewParticleDefType		newParticleDef;

			for (i = 0; i < 6; i++)
			{
				delta.x = theNode->MotionVector.x * 200.0f;
				delta.y = theNode->MotionVector.y * 200.0f;
				delta.z = theNode->MotionVector.z * 200.0f;

				delta.x += RandomFloat2() * 40.0f;						// spray delta
				delta.z += RandomFloat2() * 40.0f;
				delta.y = 200.0f + RandomFloat() * 200.0f;

				pt.x = x + RandomFloat2() * 20.0f;					// random noise to coord
				pt.y = y;
				pt.z = z + RandomFloat2() * 20.0f;


				newParticleDef.groupNum		= particleGroup;
				newParticleDef.where		= &pt;
				newParticleDef.delta		= &delta;
				newParticleDef.scale		= 1.0f + RandomFloat() * .5f;
				newParticleDef.rotZ			= 0;
				newParticleDef.rotDZ		= 0;
				newParticleDef.alpha		= FULL_ALPHA;
				if (AddParticleToGroup(&newParticleDef))
					break;
			}
		}
	}
}





#pragma mark -



/****************** BURN FIRE ************************/

void BurnFire(ObjNode *theNode, float x, float y, float z, Boolean doSmoke,
			short particleType, float scale, uint32_t moreFlags)
{
int		i;
float	fps = gFramesPerSecondFrac;
int		particleGroup;
uint32_t magicNum;
NewParticleGroupDefType	groupDef;
NewParticleDefType	newParticleDef;
OGLVector3D			d;
OGLPoint3D			p;


		/**************/
		/* MAKE SMOKE */
		/**************/

	if (doSmoke && (gFramesPerSecond > 20.0f))										// only do smoke if running at good frame rate
	{
		theNode->SmokeTimer -= fps;													// see if add smoke
		if (theNode->SmokeTimer <= 0.0f)
		{
			theNode->SmokeTimer += SMOKE_TIMER;										// reset timer

			particleGroup 	= theNode->SmokeParticleGroup;
			magicNum 		= theNode->SmokeParticleMagic;

			if ((particleGroup == -1) || (!VerifyParticleGroupMagicNum(particleGroup, magicNum)))
			{

				theNode->SmokeParticleMagic = magicNum = MyRandomLong();			// generate a random magic num

				groupDef.magicNum				= magicNum;
				groupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
				groupDef.flags					= PARTICLE_FLAGS_DONTCHECKGROUND|moreFlags;
				groupDef.gravity				= 0;
				groupDef.magnetism				= 0;
				groupDef.baseScale				= 20.0f * scale;
				groupDef.decayRate				=  -.2f;
				groupDef.fadeRate				= .2;
				groupDef.particleTextureNum		= PARTICLE_SObjType_BlackSmoke;
				groupDef.srcBlend				= GL_SRC_ALPHA;
				groupDef.dstBlend				= GL_ONE_MINUS_SRC_ALPHA;
				theNode->SmokeParticleGroup = particleGroup = NewParticleGroup(&groupDef);
			}

			if (particleGroup != -1)
			{
				for (i = 0; i < 3; i++)
				{
					p.x = x + RandomFloat2() * (40.0f * scale);
					p.y = y + 200.0f + RandomFloat() * (50.0f * scale);
					p.z = z + RandomFloat2() * (40.0f * scale);

					d.x = RandomFloat2() * (20.0f * scale);
					d.y = 150.0f + RandomFloat() * (40.0f * scale);
					d.z = RandomFloat2() * (20.0f * scale);

					newParticleDef.groupNum		= particleGroup;
					newParticleDef.where		= &p;
					newParticleDef.delta		= &d;
					newParticleDef.scale		= RandomFloat() + 1.0f;
					newParticleDef.rotZ			= RandomFloat() * PI2;
					newParticleDef.rotDZ		= RandomFloat2();
					newParticleDef.alpha		= .7;
					if (AddParticleToGroup(&newParticleDef))
					{
						theNode->SmokeParticleGroup = -1;
						break;
					}
				}
			}
		}
	}

		/*************/
		/* MAKE FIRE */
		/*************/

	theNode->FireTimer -= fps;													// see if add fire
	if (theNode->FireTimer <= 0.0f)
	{
		theNode->FireTimer += FIRE_TIMER;										// reset timer

		particleGroup 	= theNode->ParticleGroup;
		magicNum 		= theNode->ParticleMagicNum;

		if ((particleGroup == -1) || (!VerifyParticleGroupMagicNum(particleGroup, magicNum)))
		{
			theNode->ParticleMagicNum = magicNum = MyRandomLong();			// generate a random magic num

			groupDef.magicNum				= magicNum;
			groupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
			groupDef.flags					= PARTICLE_FLAGS_DONTCHECKGROUND|moreFlags;
			groupDef.gravity				= -200;
			groupDef.magnetism				= 0;
			groupDef.baseScale				= 30.0f * scale;
			groupDef.decayRate				=  0;
			groupDef.fadeRate				= .8;
			groupDef.particleTextureNum		= particleType;
			groupDef.srcBlend				= GL_SRC_ALPHA;
			groupDef.dstBlend				= GL_ONE;
			theNode->ParticleGroup = particleGroup = NewParticleGroup(&groupDef);
		}

		if (particleGroup != -1)
		{
			for (i = 0; i < 3; i++)
			{
				p.x = x + RandomFloat2() * (30.0f * scale);
				p.y = y + RandomFloat() * (50.0f * scale);
				p.z = z + RandomFloat2() * (30.0f * scale);

				d.x = RandomFloat2() * (50.0f * scale);
				d.y = 50.0f + RandomFloat() * (60.0f * scale);
				d.z = RandomFloat2() * (50.0f * scale);

				newParticleDef.groupNum		= particleGroup;
				newParticleDef.where		= &p;
				newParticleDef.delta		= &d;
				newParticleDef.scale		= RandomFloat() + 1.0f;
				newParticleDef.rotZ			= RandomFloat() * PI2;
				newParticleDef.rotDZ		= RandomFloat2();
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






#pragma mark -

/************** MAKE FIRE EXPLOSION *********************/

void MakeFireExplosion(OGLPoint3D *where)
{
long					pg,i;
OGLVector3D				d;
OGLPoint3D				pt;
NewParticleDefType		newParticleDef;
float					x,y,z;


		/*********************/
		/* FIRST MAKE FLAMES */
		/*********************/

	gNewParticleGroupDef.magicNum				= 0;
	gNewParticleGroupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
	gNewParticleGroupDef.flags					= PARTICLE_FLAGS_BOUNCE;
	gNewParticleGroupDef.gravity				= -120;
	gNewParticleGroupDef.magnetism				= 0;
	gNewParticleGroupDef.baseScale				= 18;
	gNewParticleGroupDef.decayRate				=  -1.0;
	gNewParticleGroupDef.fadeRate				= 1.0;
	gNewParticleGroupDef.particleTextureNum		= PARTICLE_SObjType_Fire;
	gNewParticleGroupDef.srcBlend				= GL_SRC_ALPHA;
	gNewParticleGroupDef.dstBlend				= GL_ONE;
	pg = NewParticleGroup(&gNewParticleGroupDef);
	if (pg != -1)
	{
		x = where->x;
		y = where->y;
		z = where->z;


		for (i = 0; i < 150; i++)
		{
			pt.x = x + RandomFloat2() * 20.0f;
			pt.y = y + RandomFloat2() * 20.0f;
			pt.z = z + RandomFloat2() * 20.0f;

			d.y = RandomFloat2() * 300.0f;
			d.x = RandomFloat2() * 350.0f;
			d.z = RandomFloat2() * 350.0f;


			newParticleDef.groupNum		= pg;
			newParticleDef.where		= &pt;
			newParticleDef.delta		= &d;
			newParticleDef.scale		= RandomFloat() + 1.0f;
			newParticleDef.rotZ			= 0;
			newParticleDef.rotDZ		= RandomFloat2() * 10.0f;
			newParticleDef.alpha		= FULL_ALPHA + (RandomFloat() * .3f);
			AddParticleToGroup(&newParticleDef);
		}
	}


}


#pragma mark -

/******************** ADD SMOKER ****************************/

Boolean AddSmoker(TerrainItemEntryType *itemPtr, float  x, float z)
{
ObjNode	*newObj;

	newObj = MakeSmoker(x,z, itemPtr->parm[0]);
	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list

	return(true);
}


/****************** MAKE SMOKER **********************/

ObjNode *MakeSmoker(float  x, float z, int kind)
{
ObjNode	*newObj;

	NewObjectDefinitionType def =
	{
		.genre		= EVENT_GENRE,
		.coord.x	= x,
		.coord.z	= z,
		.coord.y	= FindHighestCollisionAtXZ(x,z, CTYPE_TERRAIN | CTYPE_WATER),
		.flags		= STATUS_BIT_DONTCULL,
		.slot		= SLOT_OF_DUMB+10,
		.moveCall	= MoveSmoker,
		.scale		= 1,
	};

	newObj = MakeNewObject(&def);
	newObj->Kind = kind;								// save smoke kind
	return(newObj);
}


/******************** MOVE SMOKER ************************/

static void MoveSmoker(ObjNode *theNode)
{
float				fps = gFramesPerSecondFrac;
int					i,t;
int					particleGroup,magicNum;
NewParticleGroupDefType	groupDef;
NewParticleDefType	newParticleDef;
OGLVector3D			d;
OGLPoint3D			p;
short				smokeType;

static const short	textures[] =
{
	PARTICLE_SObjType_BlackSmoke,
	PARTICLE_SObjType_GreySmoke,
	PARTICLE_SObjType_RedFumes,
	PARTICLE_SObjType_GreenFumes
};

static const Boolean	glow[] =
{
	false,
	false,
	true,
	true
};

		/* SEE IF OUT OF RANGE */

	if (TrackTerrainItem(theNode))							// just check to see if it's gone
	{
		DeleteObject(theNode);
		return;
	}


	theNode->Coord.y = GetTerrainY(theNode->Coord.x, theNode->Coord.z);		// make sure on ground (for when volcanos grow over it)


		/**************/
		/* MAKE SMOKE */
		/**************/

	theNode->Timer -= fps;													// see if add smoke
	if (theNode->Timer <= 0.0f)
	{
		theNode->Timer += .06f;												// reset timer

		t = textures[smokeType = theNode->Kind];										// get texture #

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
			groupDef.baseScale				= 25;
			groupDef.decayRate				= -.7;
			groupDef.fadeRate				= .3;
			groupDef.particleTextureNum		= t;
			groupDef.srcBlend				= GL_SRC_ALPHA;
			if (glow[smokeType])
				groupDef.dstBlend				= GL_ONE;
			else
				groupDef.dstBlend				= GL_ONE_MINUS_SRC_ALPHA;
			theNode->ParticleGroup = particleGroup = NewParticleGroup(&groupDef);
		}

		if (particleGroup != -1)
		{
			float				x,y,z;

			x = theNode->Coord.x;
			y = theNode->Coord.y;
			z = theNode->Coord.z;

			for (i = 0; i < 2; i++)
			{
				p.x = x + RandomFloat2() * 50.0f;
				p.y = y + RandomFloat() * 10.0f;
				p.z = z + RandomFloat2() * 50.0f;

				d.x = RandomFloat2() * 80.0f;
				d.y = 300.0f + RandomFloat() * 75.0f;
				d.z = RandomFloat2() * 80.0f;

				newParticleDef.groupNum		= particleGroup;
				newParticleDef.where		= &p;
				newParticleDef.delta		= &d;
				newParticleDef.scale		= RandomFloat() + 1.0f;
				newParticleDef.rotZ			= RandomFloat() * PI2;
				newParticleDef.rotDZ		= RandomFloat2() * 1.2f;
				newParticleDef.alpha		= .8;
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

/****************** DO PLAYER GROUND SCRAPE *********************/

void DoPlayerGroundScrape(ObjNode *player, short playerNum)
{
float	fps = gFramesPerSecondFrac;
short	i;

#pragma unused (player)

	gPlayerInfo[playerNum].dirtParticleTimer -= fps;													// see if add bubbles
	if (gPlayerInfo[playerNum].dirtParticleTimer <= 0.0f)
	{
		int					particleGroup,magicNum;
		NewParticleGroupDefType	groupDef;
		NewParticleDefType	newParticleDef;

		gPlayerInfo[playerNum].dirtParticleTimer += .04f;												// reset timer

		particleGroup 	= gPlayerInfo[playerNum].dirtParticleGroup;
		magicNum 		= gPlayerInfo[playerNum].dirtParticleMagicNum;

		if ((particleGroup == -1) || (!VerifyParticleGroupMagicNum(particleGroup, magicNum)))
		{

			gPlayerInfo[playerNum].dirtParticleMagicNum = magicNum = MyRandomLong();					// generate a random magic num

			groupDef.magicNum				= magicNum;
			groupDef.type					= PARTICLE_TYPE_FALLINGSPARKS;
			groupDef.flags					= PARTICLE_FLAGS_BOUNCE | PARTICLE_FLAGS_ALLAIM;
			groupDef.gravity				= 1000;
			groupDef.magnetism				= 0;
			groupDef.baseScale				= 10;
			groupDef.decayRate				= -2.0;
			groupDef.fadeRate				= 1.0;
			groupDef.particleTextureNum		= PARTICLE_SObjType_CokeSpray;
			groupDef.srcBlend				= GL_SRC_ALPHA;
			groupDef.dstBlend				= GL_ONE_MINUS_SRC_ALPHA;
			gPlayerInfo[playerNum].dirtParticleGroup = particleGroup = NewParticleGroup(&groupDef);
		}

		if (particleGroup != -1)
		{
			float	x,y,z;
			OGLPoint3D	p;
			OGLVector3D	d;

			x = gCoord.x;
			z = gCoord.z;
			y = GetTerrainY(x,z) + 10.0f;

			for (i = 0; i < 3; i++)
			{
				d.x = RandomFloat2() * 90.0f;
				d.y = RandomFloat() * 400.0f;
				d.z = RandomFloat2() * 90.0f;

				p.x = x + RandomFloat2() * 5.0f;
				p.y = y + RandomFloat() * 5.0f;
				p.z = z + RandomFloat2() * 5.0f;


				newParticleDef.groupNum		= particleGroup;
				newParticleDef.where		= &p;
				newParticleDef.delta		= &d;
				newParticleDef.scale		= 1.0f + RandomFloat() * .5f;
				newParticleDef.rotZ			= RandomFloat() * PI2;
				newParticleDef.rotDZ		= RandomFloat2() * 10.0f;
				newParticleDef.alpha		= .4f + RandomFloat() * .2f;
				if (AddParticleToGroup(&newParticleDef))
				{
					gPlayerInfo[playerNum].dirtParticleGroup = -1;
					break;
				}
			}
		}
	}

}





#pragma mark -

/************************* ADD FLAME *********************************/

Boolean AddFlame(TerrainItemEntryType *itemPtr, float  x, float z)
{
				/* MAKE CUSTOM OBJECT */

	NewObjectDefinitionType def =
	{
		.genre		= CUSTOM_GENRE,
		.slot 		= WATER_SLOT + 1,
		.coord.x	= x,
		.coord.z	= z,
		.coord.y 	= FindHighestCollisionAtXZ(x,z, CTYPE_TERRAIN | CTYPE_WATER),
		.scale		= 1.0f + RandomFloat() * .8f,
		.flags		= STATUS_BIT_DOUBLESIDED | STATUS_BIT_GLOW | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOZWRITES | STATUS_BIT_DONTCULL | STATUS_BIT_NOTEXTUREWRAP,
		.moveCall 	= MoveFlame,
		.drawCall	= DrawFlame,
	};

	ObjNode* newObj = MakeNewObject(&def);
	newObj->TerrainItemPtr = itemPtr;								// keep ptr to item list
	newObj->FlameFrame = RandomRange(0, 10);						// start on random frame
	newObj->FlameSpeed = 20.0f + RandomFloat() * 2.0f;				// set anim speed
	newObj->Timer = 0;

	return(true);													// item was added
}


/******************* MOVE FLAME ****************************/

static void MoveFlame(ObjNode *theNode)
{
	if (TrackTerrainItem(theNode))							// just check to see if it's gone
	{
		DeleteObject(theNode);
		return;
	}

			/* NEXT FRAME */

	theNode->Timer -= theNode->FlameSpeed * gFramesPerSecondFrac;
	if (theNode->Timer <= 0.0f)
	{
		theNode->Timer += 1.0f;
		theNode->FlameFrame++;
		if (theNode->FlameFrame > 10)
			theNode->FlameFrame = 0;
	}


}


/****************** DRAW FLAME ***********************/

static void DrawFlame(ObjNode *theNode)
{
OGLMatrix4x4	m;
const OGLVector3D	up = {0,1,0};
OGLPoint3D	frame[4];
short				paneNum = gCurrentSplitScreenPane;
float	s;

	s = theNode->Scale.x;

	frame[0].x = -100.0f * s;
	frame[0].y = 200.0f * s;
	frame[0].z = 0;

	frame[1].x = 100.0f * s;
	frame[1].y = 200.0f * s;
	frame[1].z = 0;

	frame[2].x = 100.0f * s;
	frame[2].y = 0;
	frame[2].z = 0;

	frame[3].x = -100.0f * s;
	frame[3].y = 0;
	frame[3].z = 0;



			/* CALC VERTEX COORDS */

	SetLookAtMatrixAndTranslate(&m, &up, &theNode->Coord, &gGameViewInfoPtr->cameraPlacement[paneNum].cameraLocation);	// aim at camera & translate
	OGLPoint3D_TransformArray(&frame[0], &m, frame, 4);


			/* SUBMIT TEXTURE */

	gGlobalColorFilter.r = 1.0;
	gGlobalColorFilter.g = .8;
	gGlobalColorFilter.b = .8;

	MO_DrawMaterial(gSpriteGroupList[SPRITE_GROUP_PARTICLES][PARTICLE_SObjType_Flame0 + theNode->FlameFrame].materialObject);


			/* DRAW QUAD */

	glBegin(GL_QUADS);
	glTexCoord2f(0,.99);	glVertex3fv(&frame[0].x);
	glTexCoord2f(.99,.99);	glVertex3fv(&frame[1].x);
	glTexCoord2f(.99,0);	glVertex3fv(&frame[2].x);
	glTexCoord2f(0,0);		glVertex3fv(&frame[3].x);
	glEnd();

	gGlobalColorFilter.r =gGlobalColorFilter.g = gGlobalColorFilter.b = 1;
}

#pragma mark -


/************************* MAKE FIRE RING *********************************/

ObjNode *MakeFireRing(float x, float y, float z)
{
				/* MAKE CUSTOM OBJECT */

	NewObjectDefinitionType def =
	{
		.genre		= CUSTOM_GENRE,
		.slot		= PARTICLE_SLOT + 2,
		.coord		= {x,y,z},
		.scale		= 100.0f,
		.flags		= STATUS_BIT_DOUBLESIDED | STATUS_BIT_GLOW | STATUS_BIT_NOLIGHTING | STATUS_BIT_NOZWRITES | STATUS_BIT_DONTCULL | STATUS_BIT_NOTEXTUREWRAP,
		.moveCall	= MoveFireRing,
		.drawCall	= DrawFireRing,
	};

	ObjNode* newObj = MakeNewObject(&def);
	newObj->ColorFilter.a = 1.5f;
	return(newObj);													// item was added
}


/******************* MOVE FIRE RING ****************************/

static void MoveFireRing(ObjNode *theNode)
{
float	fps = gFramesPerSecondFrac;

	theNode->ColorFilter.a -= fps * 2.0f;
	if (theNode->ColorFilter.a <= 0.0f)
	{
		DeleteObject(theNode);
		return;
	}

	theNode->Scale.x =
	theNode->Scale.y =
	theNode->Scale.z += fps * 1500.0f;

//	theNode->Rot.y = RandomFloat() * PI2;
}


/****************** DRAW FIRE RING ***********************/

static void DrawFireRing(ObjNode *theNode)
{
OGLPoint3D	verts[4];
float		x,y,z,s;

	x = theNode->Coord.x;
	y = theNode->Coord.y;
	z = theNode->Coord.z;

	s = theNode->Scale.x;

	verts[0].x = x - s;
	verts[0].y = y;
	verts[0].z = z + s;

	verts[1].x = x - s;
	verts[1].y = y;
	verts[1].z = z - s;

	verts[2].x = x + s;
	verts[2].y = y;
	verts[2].z = z - s;

	verts[3].x = x + s;
	verts[3].y = y;
	verts[3].z = z + s;


			/* SUBMIT TEXTURE */

	gGlobalTransparency = theNode->ColorFilter.a;

	MO_DrawMaterial(gSpriteGroupList[SPRITE_GROUP_PARTICLES][PARTICLE_SObjType_FireRing].materialObject);


			/* DRAW QUAD */

	glBegin(GL_QUADS);
	glTexCoord2f(0,.99);	glVertex3fv(&verts[0].x);
	glTexCoord2f(.99,.99);	glVertex3fv(&verts[1].x);
	glTexCoord2f(.99,0);	glVertex3fv(&verts[2].x);
	glTexCoord2f(0,0);		glVertex3fv(&verts[3].x);
	glEnd();

	gGlobalTransparency = 1.0f;
}





















