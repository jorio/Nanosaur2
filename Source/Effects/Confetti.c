/****************************/
/*   	CONFETTI.C		    */
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

static void DeleteConfettiGroup(long groupNum);
static void MoveConfettiGroups(ObjNode *theNode);
static void DrawConfettiGroups(ObjNode *theNode, const OGLSetupOutputType *setupInfo);

/****************************/
/*    CONSTANTS             */
/****************************/


/*********************/
/*    VARIABLES      */
/*********************/

ConfettiGroupType	*gConfettiGroups[MAX_CONFETTI_GROUPS];

NewConfettiGroupDefType	gNewConfettiGroupDef;

short			gNumActiveConfettiGroups = 0;



/************************ INIT CONFETTI MANAGER **************************/
//
// NOTE:  This uses the sprites in the particle.sprites file which is loaded
//		in particles.c
//

void InitConfettiManager(void)
{
short	i;
ObjNode	*obj;


			/* INIT GROUP ARRAY */

	for (i = 0; i < MAX_CONFETTI_GROUPS; i++)
		gConfettiGroups[i] = nil;

	gNumActiveConfettiGroups = 0;


		/*************************************************************************/
		/* CREATE DUMMY CUSTOM OBJECT TO CAUSE CONFETTI DRAWING AT THE DESIRED TIME */
		/*************************************************************************/
		//
		// The confettis need to be drawn after the fences object, but before any sprite or font objects.
		//

	gNewObjectDefinition.genre		= CUSTOM_GENRE;
	gNewObjectDefinition.slot 		= CONFETTI_SLOT;
	gNewObjectDefinition.moveCall 	= MoveConfettiGroups;
	gNewObjectDefinition.scale 		= 1;
	gNewObjectDefinition.flags 		= STATUS_BIT_DOUBLESIDED|STATUS_BIT_DONTCULL;

	obj = MakeNewObject(&gNewObjectDefinition);
	obj->CustomDrawFunction = DrawConfettiGroups;

}


/******************** DELETE ALL CONFETTI GROUPS *********************/

void DeleteAllConfettiGroups(void)
{
long	i;

	for (i = 0; i < MAX_CONFETTI_GROUPS; i++)
	{
		DeleteConfettiGroup(i);
	}
}


/******************* DELETE CONFETTI GROUP ***********************/

static void DeleteConfettiGroup(long groupNum)
{
	if (gConfettiGroups[groupNum])
	{
			/* NUKE GEOMETRY DATA */

		MO_DisposeObjectReference(gConfettiGroups[groupNum]->geometryObj);


				/* NUKE GROUP ITSELF */

		SafeDisposePtr((Ptr)gConfettiGroups[groupNum]);
		gConfettiGroups[groupNum] = nil;

		gNumActiveConfettiGroups--;
	}
}


#pragma mark -


/********************** NEW CONFETTI GROUP *************************/
//
// INPUT:	type 	=	group type to create
//
// OUTPUT:	group ID#
//

short NewConfettiGroup(NewConfettiGroupDefType *def)
{
short					p,i,j,k;
OGLTextureCoord			*uv;
MOVertexArrayData 		vertexArrayData;
MOTriangleIndecies		*t;


			/*************************/
			/* SCAN FOR A FREE GROUP */
			/*************************/

	for (i = 0; i < MAX_CONFETTI_GROUPS; i++)
	{
		if (gConfettiGroups[i] == nil)
		{
				/* ALLOCATE NEW GROUP */

			gConfettiGroups[i] = (ConfettiGroupType *)AllocPtr(sizeof(ConfettiGroupType));
			if (gConfettiGroups[i] == nil)
				return(-1);									// out of memory


				/* INITIALIZE THE GROUP */

			for (p = 0; p < MAX_CONFETTIS; p++)						// mark all unused
				gConfettiGroups[i]->isUsed[p] = false;

			gConfettiGroups[i]->flags 				= def->flags;
			gConfettiGroups[i]->gravity 			= def->gravity;
			gConfettiGroups[i]->baseScale 			= def->baseScale;
			gConfettiGroups[i]->decayRate 			= def->decayRate;
			gConfettiGroups[i]->fadeRate 			= def->fadeRate;
			gConfettiGroups[i]->magicNum 			= def->magicNum;
			gConfettiGroups[i]->confettiTextureNum 	= def->confettiTextureNum;


				/*****************************/
				/* INIT THE GROUP'S GEOMETRY */
				/*****************************/

					/* SET THE DATA */

			vertexArrayData.VARtype			= -1;

			vertexArrayData.numMaterials 	= 1;
			vertexArrayData.materials[0]	= gSpriteGroupList[SPRITE_GROUP_PARTICLES][def->confettiTextureNum].materialObject;	// set illegal ref because it is made legit below

			vertexArrayData.numPoints 		= 0;
			vertexArrayData.numTriangles 	= 0;
			vertexArrayData.points 			= (OGLPoint3D *)AllocPtr(sizeof(OGLPoint3D) * MAX_CONFETTIS * 4);
			vertexArrayData.normals 		= nil;
			vertexArrayData.uvs[0]	 		= (OGLTextureCoord *)AllocPtr(sizeof(OGLTextureCoord) * MAX_CONFETTIS * 4);
			vertexArrayData.colorsFloat 		= (OGLColorRGBA *)AllocPtr(sizeof(OGLColorRGBA) * MAX_CONFETTIS * 4);
//			vertexArrayData.colorsByte		= nil;
			vertexArrayData.triangles		= (MOTriangleIndecies *)AllocPtr(sizeof(MOTriangleIndecies) * MAX_CONFETTIS * 2);


					/* INIT UV ARRAYS */

			uv = vertexArrayData.uvs[0];
			for (j=0; j < (MAX_CONFETTIS*4); j+=4)
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
			for (j = k = 0; j < (MAX_CONFETTIS*2); j+=2, k+=4)
			{
				t[j].vertexIndices[0] = k;							// triangle A
				t[j].vertexIndices[1] = k+1;
				t[j].vertexIndices[2] = k+2;

				t[j+1].vertexIndices[0] = k;							// triangle B
				t[j+1].vertexIndices[1] = k+2;
				t[j+1].vertexIndices[2] = k+3;
			}


				/* CREATE NEW GEOMETRY OBJECT */

			gConfettiGroups[i]->geometryObj = MO_CreateNewObjectOfType(MO_TYPE_GEOMETRY, MO_GEOMETRY_SUBTYPE_VERTEXARRAY, &vertexArrayData);

			gNumActiveConfettiGroups++;

			return(i);
		}
	}

			/* NOTHING FREE */

//	DoFatalAlert("NewConfettiGroup: no free groups!");
	return(-1);
}


/******************** ADD CONFETTI TO GROUP **********************/
//
// Returns true if confetti group was invalid or is full.
//

Boolean AddConfettiToGroup(NewConfettiDefType *def)
{
short	p,group;

	group = def->groupNum;

	if ((group < 0) || (group >= MAX_CONFETTI_GROUPS))
		DoFatalAlert("AddConfettiToGroup: illegal group #");

	if (gConfettiGroups[group] == nil)
	{
		return(true);
	}


			/* SCAN FOR FREE SLOT */

	for (p = 0; p < MAX_CONFETTIS; p++)
	{
		if (!gConfettiGroups[group]->isUsed[p])
			goto got_it;
	}

			/* NO FREE SLOTS */

	return(true);


			/* INIT PARAMETERS */
got_it:
	gConfettiGroups[group]->fadeDelay[p] 	= 	def->fadeDelay;
	gConfettiGroups[group]->alpha[p] 	= 	def->alpha;
	gConfettiGroups[group]->scale[p] 	= 	def->scale;
	gConfettiGroups[group]->coord[p] 	= 	*def->where;
	gConfettiGroups[group]->delta[p] 	= 	*def->delta;
	gConfettiGroups[group]->rot[p] 		= 	def->rot;
	gConfettiGroups[group]->deltaRot[p] = 	def->deltaRot;
	gConfettiGroups[group]->isUsed[p] 	= 	true;


	return(false);
}


/****************** MOVE CONFETTI GROUPS *********************/

static void MoveConfettiGroups(ObjNode *theNode)
{
uint32_t		flags;
long		i,n,p;
float		fps = gFramesPerSecondFrac;
float		y,baseScale,oneOverBaseScaleSquared,gravity;
float		decayRate,fadeRate;
OGLPoint3D	*coord;
OGLVector3D	*delta;

#pragma unused(theNode)

	for (i = 0; i < MAX_CONFETTI_GROUPS; i++)
	{
		if (gConfettiGroups[i])
		{
			baseScale 	= gConfettiGroups[i]->baseScale;					// get base scale
			oneOverBaseScaleSquared = 1.0f/(baseScale*baseScale);
			gravity 	= gConfettiGroups[i]->gravity;						// get gravity
			decayRate 	= gConfettiGroups[i]->decayRate;					// get decay rate
			fadeRate 	= gConfettiGroups[i]->fadeRate;						// get fade rate
			flags 		= gConfettiGroups[i]->flags;


			n = 0;															// init counter
			for (p = 0; p < MAX_CONFETTIS; p++)
			{
				if (!gConfettiGroups[i]->isUsed[p])							// make sure this confetti is used
					continue;

				n++;														// inc counter
				delta = &gConfettiGroups[i]->delta[p];						// get ptr to deltas
				coord = &gConfettiGroups[i]->coord[p];						// get ptr to coords

							/* ADD GRAVITY */

				delta->y -= gravity * fps;									// add gravity


						/* DO ROTATION & MOTION */

				gConfettiGroups[i]->rot[p].x += gConfettiGroups[i]->deltaRot[p].x * fps;
				gConfettiGroups[i]->rot[p].y += gConfettiGroups[i]->deltaRot[p].y * fps;
				gConfettiGroups[i]->rot[p].z += gConfettiGroups[i]->deltaRot[p].z * fps;

				coord->x += delta->x * fps;									// move it
				coord->y += delta->y * fps;
				coord->z += delta->z * fps;


				/*****************/
				/* SEE IF BOUNCE */
				/*****************/

				if (!(flags & PARTICLE_FLAGS_DONTCHECKGROUND))
				{
					y = GetTerrainY(coord->x, coord->z);						// get terrain coord at confetti x/z
					if (y == ILLEGAL_TERRAIN_Y)									// bounce for Win screen
						y = 0.0f;
					y += 10.0f;

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
						if (coord->y < y)									// if hit floor then nuke confetti
						{
							gConfettiGroups[i]->isUsed[p] = false;
						}
					}
				}


					/* DO SCALE */

				gConfettiGroups[i]->scale[p] -= decayRate * fps;			// shrink it
				if (gConfettiGroups[i]->scale[p] <= 0.0f)					// see if gone
					gConfettiGroups[i]->isUsed[p] = false;

					/* DO FADE */

				gConfettiGroups[i]->fadeDelay[p] -= fps;
				if (gConfettiGroups[i]->fadeDelay[p] <= 0.0f)
				{
					gConfettiGroups[i]->alpha[p] -= fadeRate * fps;				// fade it
					if (gConfettiGroups[i]->alpha[p] <= 0.0f)					// see if gone
						gConfettiGroups[i]->isUsed[p] = false;
				}


			}

				/* SEE IF GROUP WAS EMPTY, THEN DELETE */

			if (n == 0)
			{
				DeleteConfettiGroup(i);
			}
		}
	}
}


/**************** DRAW CONFETTI GROUPS *********************/

static void DrawConfettiGroups(ObjNode *theNode, const OGLSetupOutputType *setupInfo)
{
float				scale,baseScale;
long				g,p,n,i;
OGLColorRGBA		*vertexColors;
MOVertexArrayData	*geoData;
OGLPoint3D		v[4];
OGLBoundingBox	bbox;

#pragma unused(theNode)

	v[0].z = 												// init z's to 0
	v[1].z =
	v[2].z =
	v[3].z = 0;

				/* SETUP ENVIRONTMENT */

	OGL_PushState();
	glLightModeli(GL_LIGHT_MODEL_TWO_SIDE, GL_TRUE);		// we want double sided lighting


	OGL_SetColor4f(1,1,1,1);										// full white & alpha to start with

	for (g = 0; g < MAX_CONFETTI_GROUPS; g++)
	{
		float	minX,minY,minZ,maxX,maxY,maxZ;
		int		temp;

		if (gConfettiGroups[g])
		{
			geoData 		= &gConfettiGroups[g]->geometryObj->objectData;			// get pointer to geometry object data
			vertexColors 	= geoData->colorsFloat;									// get pointer to vertex color array
			baseScale 		= gConfettiGroups[g]->baseScale;						// get base scale

					/********************************/
					/* ADD ALL CONFETTIS TO TRIMESH */
					/********************************/

			minX = minY = minZ = 100000000;									// init bbox
			maxX = maxY = maxZ = -minX;

			for (p = n = 0; p < MAX_CONFETTIS; p++)
			{
				OGLMatrix4x4	m;

				if (!gConfettiGroups[g]->isUsed[p])							// make sure this confetti is used
					continue;

							/* SET VERTEX COORDS */

				scale = gConfettiGroups[g]->scale[p] * baseScale;

				v[0].x = -scale;
				v[0].y = scale;

				v[1].x = -scale;
				v[1].y = -scale;

				v[2].x = scale;
				v[2].y = -scale;

				v[3].x = scale;
				v[3].y = scale;


					/* TRANSFORM THIS CONFETTI'S VERTICES & ADD TO TRIMESH */

				OGLMatrix4x4_SetRotate_XYZ(&m, gConfettiGroups[g]->rot[p].x, gConfettiGroups[g]->rot[p].y, gConfettiGroups[g]->rot[p].z);
				m.value[M03] = gConfettiGroups[g]->coord[p].x;								// set translate
				m.value[M13] = gConfettiGroups[g]->coord[p].y;
				m.value[M23] = gConfettiGroups[g]->coord[p].z;
				OGLPoint3D_TransformArray(&v[0], &m, &geoData->points[n*4], 4);				// transform


							/* UPDATE BBOX */

				for (i = 0; i < 4; i++)
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

				temp = n*4;
				for (i = temp; i < (temp+4); i++)
				{
					vertexColors[i].r =
					vertexColors[i].g =
					vertexColors[i].b = 1.0;
					vertexColors[i].a = gConfettiGroups[g]->alpha[p];		// set transparency alpha
				}

				n++;											// inc confetti count
			}

			if (n == 0)											// if no confettis, then skip
				continue;

				/* UPDATE FINAL VALUES */

			geoData->numTriangles = n*2;
			geoData->numPoints = n*4;

			if (geoData->numPoints < 20)						// if small then just skip cull test
				goto drawme;

			bbox.min.x = minX;									// build bbox for culling test
			bbox.min.y = minY;
			bbox.min.z = minZ;
			bbox.max.x = maxX;
			bbox.max.y = maxY;
			bbox.max.z = maxZ;

			if (OGL_IsBBoxVisible(&bbox, nil))						// do cull test on it
			{
drawme:
					/* DRAW IT */

				MO_DrawObject(gConfettiGroups[g]->geometryObj, setupInfo);						// draw geometry
			}
		}
	}

			/* RESTORE MODES */

	OGL_PopState();
	OGL_SetColor4f(1,1,1,1);										// reset this
	glLightModeli(GL_LIGHT_MODEL_TWO_SIDE, GL_FALSE);


}


/**************** VERIFY CONFETTI GROUP MAGIC NUM ******************/

Boolean VerifyConfettiGroupMagicNum(short group, uint32_t magicNum)
{
	if (gConfettiGroups[group] == nil)
		return(false);

	if (gConfettiGroups[group]->magicNum != magicNum)
		return(false);

	return(true);
}


#pragma mark -

/********************* MAKE CONFETTI EXPLOSION ***********************/

void MakeConfettiExplosion(float x, float y, float z, float force, float scale, short texture, short quantity)
{
long					pg,i;
OGLVector3D				delta,v;
OGLPoint3D				pt;
NewConfettiDefType		newConfettiDef;
float					radius = 1.0f * scale;

	gNewConfettiGroupDef.magicNum				= 0;
	gNewConfettiGroupDef.flags					= PARTICLE_FLAGS_BOUNCE;
	gNewConfettiGroupDef.gravity				= 250;
	gNewConfettiGroupDef.baseScale				= 4.5f * scale;
	gNewConfettiGroupDef.decayRate				= 0;
	gNewConfettiGroupDef.fadeRate				= 1.0;
	gNewConfettiGroupDef.confettiTextureNum		= texture;

	pg = NewConfettiGroup(&gNewConfettiGroupDef);
	if (pg != -1)
	{
		for (i = 0; i < quantity; i++)
		{
			pt.x = x + RandomFloat2() * radius;
			pt.y = y + RandomFloat2() * radius;
			pt.z = z + RandomFloat2() * radius;

			v.x = pt.x - x;
			v.y = pt.y - y;
			v.z = pt.z - z;
			FastNormalizeVector(v.x,v.y,v.z,&v);

			delta.x = v.x * (force * scale);
			delta.y = v.y * (force * scale);
			delta.z = v.z * (force * scale);

			newConfettiDef.groupNum		= pg;
			newConfettiDef.where		= &pt;
			newConfettiDef.delta		= &delta;
			newConfettiDef.scale		= 1.0f + RandomFloat()  * .5f;
			newConfettiDef.rot.x		= RandomFloat()*PI2;
			newConfettiDef.rot.y		= RandomFloat()*PI2;
			newConfettiDef.rot.z		= RandomFloat()*PI2;
			newConfettiDef.deltaRot.x	= RandomFloat2()*5.0f;
			newConfettiDef.deltaRot.y	= RandomFloat2()*5.0f;
			newConfettiDef.deltaRot.z	= RandomFloat2()*5.0f;
			newConfettiDef.alpha		= FULL_ALPHA;
			newConfettiDef.fadeDelay	= .5f + RandomFloat();
			if (AddConfettiToGroup(&newConfettiDef))
				break;
		}
	}
}


