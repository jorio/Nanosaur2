/**********************/
/*   	WATER.C      */
/**********************/


#include "game.h"
#include "infobar.h"

/***************/
/* EXTERNALS   */
/***************/


/****************************/
/*    PROTOTYPES            */
/****************************/

static void MoveWater(ObjNode *theNode);
static void DrawWater(ObjNode *theNode, const OGLSetupOutputType *setupInfo);
static void MakeWaterGeometry(void);

static void InitRipples(void);
static void DrawRipples(ObjNode *theNode, const OGLSetupOutputType *setupInfo);
static void MoveRippleEvent(ObjNode *theNode);


/****************************/
/*    CONSTANTS             */
/****************************/

#define MAX_WATER			60
#define	MAX_NUBS_IN_WATER	80


#define	MAX_RIPPLES	100

typedef struct
{
	Boolean		isUsed;
	OGLPoint3D	coord;
	float		alpha, fadeRate;
	float		scale,scaleSpeed;
}RippleType;




/**********************/
/*     VARIABLES      */
/**********************/

long			gNumWaterPatches = 0;
short			gNumWaterDrawn;
WaterDefType	**gWaterListHandle = nil;
WaterDefType	*gWaterList;

static float					gWaterInitY[MAX_WATER];


typedef struct				// we group all the vertex arrays into a stuct so that we can easily allocate it to the Vertex Array Range engine
{
	MOTriangleIndecies		triangles[MAX_WATER][MAX_NUBS_IN_WATER*2];
	OGLPoint3D				points[MAX_WATER][MAX_NUBS_IN_WATER*2];
	OGLTextureCoord			uvs1[MAX_WATER][MAX_NUBS_IN_WATER*2];
	OGLTextureCoord			uvs2[MAX_WATER][MAX_NUBS_IN_WATER*2];
}WaterVertexArraysType;

static WaterVertexArraysType	gWaterVertexArrays;
MOVertexArrayData				gWaterTriMeshData[MAX_WATER];

OGLBoundingBox					gWaterBBox[MAX_WATER];


		/* UV'S FOR WATER TYPES */

static OGLTextureCoord	gWaterUVs[NUM_WATER_TYPES][2];			// [2] is for the two layers we can have



		/* RIPPLES */

static	int			gNumRipples;
static	ObjNode		*gRippleEventObj = nil;

static	RippleType	gRippleList[MAX_RIPPLES];




/*******************/
/*     TABLES      */
/*******************/

static const short	gWaterTextureType[NUM_WATER_TYPES] =
{
	GLOBAL_SObjType_GreenWater,				// green water
	GLOBAL_SObjType_BlueWater,				// blue water
	GLOBAL_SObjType_LavaWater,				// lava water
	GLOBAL_SObjType_LavaWater,				// lava water 0
	GLOBAL_SObjType_LavaWater,				// lava water 1
	GLOBAL_SObjType_LavaWater,				// lava water 2
	GLOBAL_SObjType_LavaWater,				// lava water 3
	GLOBAL_SObjType_LavaWater,				// lava water 4
	GLOBAL_SObjType_LavaWater,				// lava water 5
	GLOBAL_SObjType_LavaWater,				// lava water 6
	GLOBAL_SObjType_LavaWater,				// lava water 7
};

static const float gWaterTransparency[NUM_WATER_TYPES] =
{
	.8,				// green water
	.6,				// blue water
	1.0,			// lava water
	1.0,			// lava water 0
	1.0,			// lava water 1
	1.0,			// lava water 2
	1.0,			// lava water 3
	1.0,			// lava water 4
	1.0,			// lava water 5
	1.0,			// lava water 6
	1.0,			// lava water 7
};

static const Boolean gWaterGlow[NUM_WATER_TYPES] =
{
	false,				// green water
	false,				// blue water
	false,				// lava water
	false,				// lava water 0
	false,				// lava water 1
	false,				// lava water 2
	false,				// lava water 3
	false,				// lava water 4
	false,				// lava water 5
	false,				// lava water 6
	false,				// lava water 7
};


static const float	gWaterFixedYCoord[] =
{
	400.0f,					// #0 swimming pool

};



/********************** DISPOSE WATER *********************/

void DisposeWater(void)
{

	if (!gWaterListHandle)
		return;

	DisposeHandle((Handle)gWaterListHandle);
	gWaterListHandle = nil;
	gWaterList = nil;
	gNumWaterPatches = 0;
}



/********************* PRIME WATER ***********************/
//
// Called during terrain prime function to initialize
//

void PrimeTerrainWater(void)
{
long					f,i,numNubs;
OGLPoint2D				*nubs;
ObjNode					*obj;
float					y,centerX,centerZ;

	InitRipples();

	if (gNumWaterPatches > MAX_WATER)
		DoFatalAlert("PrimeTerrainWater: gNumWaterPatches > MAX_WATER");

			/* INIT UVS */

	for (i = 0; i < NUM_WATER_TYPES; i++)
	{
		gWaterUVs[i][0].u = gWaterUVs[i][0].v = 0;
		gWaterUVs[i][1].u = gWaterUVs[i][1].v = 0;
	}

			/******************************/
			/* ADJUST TO GAME COORDINATES */
			/******************************/

	for (f = 0; f < gNumWaterPatches; f++)
	{
		nubs 				= &gWaterList[f].nubList[0];				// point to nub list
		numNubs 			= gWaterList[f].numNubs;					// get # nubs in water

		if (numNubs == 1)
			DoFatalAlert("PrimeTerrainWater: numNubs == 1");

		if (numNubs > MAX_NUBS_IN_WATER)
			DoFatalAlert("PrimeTerrainWater: numNubs > MAX_NUBS_IN_WATER");


				/* IF FIRST AND LAST NUBS ARE SAME, THEN ELIMINATE LAST */

		if ((nubs[0].x == nubs[numNubs-1].x) &&
			(nubs[0].y == nubs[numNubs-1].y))
		{
			numNubs--;
			gWaterList[f].numNubs = numNubs;
		}


				/* CONVERT TO WORLD COORDS */

		for (i = 0; i < numNubs; i++)
		{
			nubs[i].x *= gMapToUnitValue;
			nubs[i].y *= gMapToUnitValue;
		}


				/***********************/
				/* CREATE VERTEX ARRAY */
				/***********************/

				/* FIND HARD-WIRED Y */

		if (gWaterList[f].flags & WATER_FLAG_FIXEDHEIGHT)
		{
			y = gWaterFixedYCoord[gWaterList[f].height];
		}
				/* FIND Y @ HOT SPOT */
		else
		{
			gWaterList[f].hotSpotX *= gMapToUnitValue;
			gWaterList[f].hotSpotZ *= gMapToUnitValue;

			y =  GetTerrainY(gWaterList[f].hotSpotX, gWaterList[f].hotSpotZ);

//			switch(gLevelNum)
//			{
//				default:
//						y += 75.0f;
//			}
		}

		gWaterInitY[f] = y;									// save water's y coord


		for (i = 0; i < numNubs; i++)
		{
			gWaterVertexArrays.points[f][i].x = nubs[i].x;
			gWaterVertexArrays.points[f][i].y = y;
			gWaterVertexArrays.points[f][i].z = nubs[i].y;
		}

			/* APPEND THE CENTER POINT TO THE POINT LIST */

		centerX = centerZ = 0;											// calc average of points
		for (i = 0; i < numNubs; i++)
		{
			centerX += gWaterVertexArrays.points[f][i].x;
			centerZ += gWaterVertexArrays.points[f][i].z;
		}
		centerX /= (float)numNubs;
		centerZ /= (float)numNubs;

		gWaterVertexArrays.points[f][numNubs].x = centerX;
		gWaterVertexArrays.points[f][numNubs].z = centerZ;
		gWaterVertexArrays.points[f][numNubs].y = y;
	}

			/***********************/
			/* MAKE WATER GEOMETRY */
			/***********************/

	MakeWaterGeometry();


		/*************************************************************************/
		/* CREATE DUMMY CUSTOM OBJECT TO CAUSE WATER DRAWING AT THE DESIRED TIME */
		/*************************************************************************/

	gNewObjectDefinition.genre		= CUSTOM_GENRE;
	gNewObjectDefinition.slot 		= WATER_SLOT;
	gNewObjectDefinition.moveCall 	= MoveWater;
	gNewObjectDefinition.flags 		= STATUS_BIT_DOUBLESIDED|STATUS_BIT_NOLIGHTING|STATUS_BIT_DONTCULL;

	obj = MakeNewObject(&gNewObjectDefinition);
	obj->CustomDrawFunction = DrawWater;

	obj->VertexArrayMode = VERTEX_ARRAY_RANGE_TYPE_USER_WATER;


#if VERTEXARRAYRANGES
			/* ASSIGN MEMORY TO VERTEX ARRAY RANGE */
			//
			// Each double-buffer of fence geometry gets its own VAR range type
			//

	AssignVertexArrayRangeMemory(sizeof(WaterVertexArraysType), &gWaterVertexArrays, VERTEX_ARRAY_RANGE_TYPE_USER_WATER);
#endif
}


/*************** MAKE WATER GEOMETRY *********************/

static void MakeWaterGeometry(void)
{
int						f;
u_short					type, numNubs;
short					i;
WaterDefType			*water;
float					minX,minY,minZ,maxX,maxY,maxZ;
double					x,y,z;
MOMaterialObject	*mat;

	for (f = 0; f < gNumWaterPatches; f++)
	{
				/* GET WATER INFO */

		water = &gWaterList[f];								// point to this water
		numNubs = water->numNubs;							// get # nubs in water (note:  this is the # from the file, not including the extra center point we added earlier!)
		if (numNubs < 3)
			DoFatalAlert("MakeWaterGeometry: numNubs < 3");
		type = water->type;									// get water type


					/***************************/
					/* SET VERTEX ARRAY HEADER */
					/***************************/

		gWaterTriMeshData[f].VARtype					= VERTEX_ARRAY_RANGE_TYPE_USER_WATER;
		gWaterTriMeshData[f].points 					= &gWaterVertexArrays.points[f][0];
		gWaterTriMeshData[f].triangles					= &gWaterVertexArrays.triangles[f][0];
		gWaterTriMeshData[f].uvs[0]						= &gWaterVertexArrays.uvs1[f][0];
		gWaterTriMeshData[f].uvs[1]						= &gWaterVertexArrays.uvs2[f][0];
		gWaterTriMeshData[f].normals					= nil;
		gWaterTriMeshData[f].colorsFloat				= nil;
		gWaterTriMeshData[f].numPoints 					= numNubs+1;					// +1 is to include the extra center point
		gWaterTriMeshData[f].numTriangles 				= numNubs;


				/* BUILD TRIANGLE INFO */

		for (i = 0; i < gWaterTriMeshData[f].numTriangles; i++)
		{
			gWaterVertexArrays.triangles[f][i].vertexIndices[0] = numNubs;							// vertex 0 is always the radial center that we appended to the end of the list
			gWaterVertexArrays.triangles[f][i].vertexIndices[1] = i + 0;
			gWaterVertexArrays.triangles[f][i].vertexIndices[2] = i + 1;

			if (gWaterVertexArrays.triangles[f][i].vertexIndices[2] == numNubs)						// check for wrap back
				 gWaterVertexArrays.triangles[f][i].vertexIndices[2] = 0;
		}


				/* SET TEXTURE */

		mat = gSpriteGroupList[SPRITE_GROUP_GLOBAL][gWaterTextureType[type]].materialObject;		// get material obj

		gWaterTriMeshData[f].numMaterials	= 2;
		gWaterTriMeshData[f].materials[0] 	= 														// set illegal ref to material
		gWaterTriMeshData[f].materials[1] 	= mat;

		mat->objectData.flags |= BG3D_MATERIALFLAG_MULTITEXTURE;									// set flags for multi-texture
		mat->objectData.multiTextureCombine	= MULTI_TEXTURE_COMBINE_MODULATE;							// set combining mode


				/*************/
				/* CALC BBOX */
				/*************/

		maxX = maxY = maxZ = -1000000;									// build new bboxes while we do this
		minX = minY = minZ = -maxX;

		for (i = 0; i < numNubs; i++)
		{

					/* GET COORDS */

			x = gWaterVertexArrays.points[f][i].x;
			y = gWaterVertexArrays.points[f][i].y;
			z = gWaterVertexArrays.points[f][i].z;

					/* CHECK BBOX */

			if (x < minX)	minX = x;									// find min/max bounds for bbox
			if (x > maxX)	maxX = x;
			if (z < minZ)	minZ = z;
			if (z > maxZ)	maxZ = z;
			if (y < minY)	minY = y;
			if (y > maxY)	maxY = y;
		}

				/* SET CALCULATED BBOX */

		gWaterBBox[f].min.x = minX;
		gWaterBBox[f].max.x = maxX;
		gWaterBBox[f].min.y = minY;
		gWaterBBox[f].max.y = maxY;
		gWaterBBox[f].min.z = minZ;
		gWaterBBox[f].max.z = maxZ;
		gWaterBBox[f].isEmpty = false;


				/**************/
				/* BUILD UV's */
				/**************/

		for (i = 0; i <= numNubs; i++)
		{
			x = gWaterVertexArrays.points[f][i].x;
			y = gWaterVertexArrays.points[f][i].y;
			z = gWaterVertexArrays.points[f][i].z;

			gWaterVertexArrays.uvs1[f][i].u 	= x * .0005;
			gWaterVertexArrays.uvs1[f][i].v 	= z * .0005;
			gWaterVertexArrays.uvs2[f][i].u 	= x * .0004;
			gWaterVertexArrays.uvs2[f][i].v 	= z * .0004;
		}
	}
}


#pragma mark -

/********************* MOVE WATER **************************/

static void MoveWater(ObjNode *theNode)
{
float	fps = gFramesPerSecondFrac;
short	i;
#pragma unused (theNode)

	for (i = 0; i < NUM_WATER_TYPES; i++)
	{
		switch (i)
		{
			case	WATER_TYPE_GREEN:
			case	WATER_TYPE_BLUE:
					gWaterUVs[i][0].u += .02f * fps;
					gWaterUVs[i][0].v += .02f * fps;

					gWaterUVs[i][1].u -= .015f * fps;
					gWaterUVs[i][1].v += .025f * fps;
					break;

			case	WATER_TYPE_LAVA:
					gWaterUVs[i][0].u += .08f * fps;
					gWaterUVs[i][0].v += .03f * fps;

					gWaterUVs[i][1].u -= .06f * fps;
					gWaterUVs[i][1].v += .05f * fps;
					break;

			case	WATER_TYPE_LAVA_DIR0:
					gWaterUVs[i][0].v += .02f * fps;
					gWaterUVs[i][1].v += .03f * fps;
					break;
			case	WATER_TYPE_LAVA_DIR4:
					gWaterUVs[i][0].v -= .02f * fps;
					gWaterUVs[i][1].v -= .03f * fps;
					break;

			case	WATER_TYPE_LAVA_DIR2:
					gWaterUVs[i][0].u -= .02f * fps;
					gWaterUVs[i][1].u -= .03f * fps;
					break;
			case	WATER_TYPE_LAVA_DIR6:
					gWaterUVs[i][0].u += .02f * fps;
					gWaterUVs[i][1].u += .03f * fps;
					break;

			case	WATER_TYPE_LAVA_DIR1:
					gWaterUVs[i][0].u -= .02f * fps;
					gWaterUVs[i][0].v += .02f * fps;
					gWaterUVs[i][1].u -= .03f * fps;
					gWaterUVs[i][1].v += .03f * fps;
					break;
			case	WATER_TYPE_LAVA_DIR3:
					gWaterUVs[i][0].u -= .02f * fps;
					gWaterUVs[i][0].v -= .02f * fps;
					gWaterUVs[i][1].u -= .03f * fps;
					gWaterUVs[i][1].v -= .03f * fps;
					break;
			case	WATER_TYPE_LAVA_DIR5:
					gWaterUVs[i][0].u += .02f * fps;
					gWaterUVs[i][0].v -= .02f * fps;
					gWaterUVs[i][1].u += .03f * fps;
					gWaterUVs[i][1].v -= .03f * fps;
					break;
			case	WATER_TYPE_LAVA_DIR7:
					gWaterUVs[i][0].u += .02f * fps;
					gWaterUVs[i][0].v += .02f * fps;
					gWaterUVs[i][1].u += .03f * fps;
					gWaterUVs[i][1].v += .03f * fps;
					break;


		}
	}
}


/********************* DRAW WATER ***********************/

static void DrawWater(ObjNode *theNode, const OGLSetupOutputType *setupInfo)
{
long	f, i;
long	prevType = -1;
#pragma unused (theNode)


			/*******************/
			/* DRAW EACH WATER */
			/*******************/

	gNumWaterDrawn = 0;

	for (f = 0; f < gNumWaterPatches; f++)
	{
		long	waterType = gWaterList[f].type;

				/* DO BBOX CULLING */

		if (OGL_IsBBoxVisible(&gWaterBBox[f], nil))
		{
			gGlobalTransparency = gWaterTransparency[waterType];

			if (gWaterGlow[waterType])										// set glow
				OGL_BlendFunc(GL_SRC_ALPHA, GL_ONE);
			else
				OGL_BlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);


				/* SET TEXTURE SCROLL FOR BOTH TEXTURE LAYERS */

			if (waterType != prevType)										// only update UV's if this is a different water type than the last loop
			{
				glMatrixMode(GL_TEXTURE);									// set texture matrix
				OGL_ActiveTextureUnit(GL_TEXTURE0);
				glLoadIdentity();
				glTranslatef(gWaterUVs[waterType][0].u, gWaterUVs[waterType][0].v, 0);
				OGL_ActiveTextureUnit(GL_TEXTURE1);
				glLoadIdentity();
				glTranslatef(gWaterUVs[waterType][1].u, gWaterUVs[waterType][1].v, 0);
				glMatrixMode(GL_MODELVIEW);
				OGL_ActiveTextureUnit(GL_TEXTURE0);
			}
					/* DRAW IT */

			MO_DrawGeometry_VertexArray(&gWaterTriMeshData[f], setupInfo);
			gNumWaterDrawn++;

			prevType = waterType;
		}
	}


			/* CLEANUP */

	gGlobalTransparency = 1.0;
	OGL_BlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);


		/* RESTORE ALL TEXTURE MATRICES */

	glMatrixMode(GL_TEXTURE);					// set texture matrix
	for (i = 0; i < 2; i++)
	{
		OGL_ActiveTextureUnit(GL_TEXTURE0 + i);
		glLoadIdentity();
	}
	glMatrixMode(GL_MODELVIEW);
	OGL_ActiveTextureUnit(GL_TEXTURE0);

}





#pragma mark -

/**************** DO WATER COLLISION DETECT ********************/

Boolean DoWaterCollisionDetect(ObjNode *theNode, float x, float y, float z, int *patchNum)
{
int	i;

	for (i = 0; i < gNumWaterPatches; i++)
	{
				/* QUICK CHECK TO SEE IF IS IN BBOX */

		if ((x < gWaterBBox[i].min.x) || (x > gWaterBBox[i].max.x) ||
			(z < gWaterBBox[i].min.z) || (z > gWaterBBox[i].max.z) ||
			(y > gWaterBBox[i].max.y))
			continue;

					/* NOW CHECK IF INSIDE THE POLYGON */
					//
					// note: this really isn't necessary since the bbox should
					// 		be accurate enough
					//

//		if (!IsPointInPoly2D(x, z, gWaterList[i].numNubs, gWaterList[i].nubList))
//			continue;


					/* WE FOUND A HIT */

		theNode->StatusBits |= STATUS_BIT_UNDERWATER;
		if (patchNum)
			*patchNum = i;
		return(true);
	}

				/* NOT IN WATER */

	theNode->StatusBits &= ~STATUS_BIT_UNDERWATER;
	if (patchNum)
		*patchNum = 0;
	return(false);
}


/*********************** IS XZ OVER WATER **************************/
//
// Returns true if x/z coords are over a water bbox
//

Boolean IsXZOverWater(float x, float z)
{
int	i;

	for (i = 0; i < gNumWaterPatches; i++)
	{
				/* QUICK CHECK TO SEE IF IS IN BBOX */

		if ((x > gWaterBBox[i].min.x) && (x < gWaterBBox[i].max.x) &&
			(z > gWaterBBox[i].min.z) && (z < gWaterBBox[i].max.z))
			return(true);
	}

	return(false);
}



/**************** GET WATER Y  ********************/
//
// returns TRUE if over water.
//

Boolean GetWaterY(float x, float z, float *y)
{
int	i;

	for (i = 0; i < gNumWaterPatches; i++)
	{
				/* QUICK CHECK TO SEE IF IS IN BBOX */

		if ((x < gWaterBBox[i].min.x) || (x > gWaterBBox[i].max.x) ||
			(z < gWaterBBox[i].min.z) || (z > gWaterBBox[i].max.z))
			continue;

					/* WE FOUND A HIT */

		*y = gWaterBBox[i].max.y;						// return y
		return(true);
	}

				/* NOT IN WATER */

	*y = 0;
	return(false);
}


#pragma mark -
#pragma mark ======= RIPPLE ===========
#pragma mark -


/************************** INIT RIPPLES ****************************/

static void InitRipples(void)
{
int	i;

	gNumRipples = 0;
	gRippleEventObj = nil;

	for (i = 0; i < MAX_RIPPLES; i++)
			gRippleList[i].isUsed = false;

}


/********************** CREATE NEW RIPPLE ************************/

void CreateNewRipple(const OGLPoint3D *where, float baseScale, float scaleSpeed, float fadeRate)
{
float	x,y,z;
int		i;

	x = where->x;
	y = where->y;
	z = where->z;

			/* GET Y COORD FOR WATER */

//	if (!GetWaterY(x, z, &y2))
//		return;													// bail if not actually on water

	y += .5f;													// raise ripple off water

		/* CREATE RIPPLE EVENT OBJECT */

	if (gRippleEventObj == nil)
	{
		gNewObjectDefinition.genre		= EVENT_GENRE;
		gNewObjectDefinition.flags 		= STATUS_BIT_DOUBLESIDED | STATUS_BIT_NOZWRITES | STATUS_BIT_NOLIGHTING | STATUS_BIT_GLOW | STATUS_BIT_NOFOG;
		gNewObjectDefinition.slot 		= SLOT_OF_DUMB+1;
		gNewObjectDefinition.moveCall 	= MoveRippleEvent;
		gRippleEventObj = MakeNewObject(&gNewObjectDefinition);

		gRippleEventObj->CustomDrawFunction = DrawRipples;
	}

		/**********************/
		/* ADD TO RIPPLE LIST */
		/**********************/

		/* SCAN FOR FREE RIPPLE SLOT */

	for (i = 0; i < MAX_RIPPLES; i++)
	{
		if (!gRippleList[i].isUsed)
			goto got_it;
	}
	return;												// no free slots

got_it:

	gRippleList[i].isUsed = true;
	gRippleList[i].coord.x = x;
	gRippleList[i].coord.y = y;
	gRippleList[i].coord.z = z;

	gRippleList[i].scale = baseScale + RandomFloat() * 30.0f;
	gRippleList[i].scaleSpeed = scaleSpeed;
	gRippleList[i].alpha = .999f - (RandomFloat() * .2f);
	gRippleList[i].fadeRate = fadeRate;

	gNumRipples++;
}



/********************** CREATE MULTIPLE RIPPLES ************************/

void CreateMultipleNewRipples(float x, float z, float baseScale, float scaleSpeed, float fadeRate, short numRipples)
{
float	y2,y;
long	i, j;

			/* GET Y COORD FOR WATER */

	if (!GetWaterY(x, z, &y2))
		return;													// bail if not actually on water

	y = y2+.5f;													// raise ripple off water


		/******************************/
		/* CREATE RIPPLE EVENT OBJECT */
		/******************************/

	if (gRippleEventObj == nil)
	{
		gNewObjectDefinition.genre		= EVENT_GENRE;
		gNewObjectDefinition.flags 		= STATUS_BIT_DOUBLESIDED | STATUS_BIT_NOZWRITES | STATUS_BIT_NOLIGHTING | STATUS_BIT_GLOW | STATUS_BIT_NOFOG;
		gNewObjectDefinition.slot 		= SLOT_OF_DUMB+11;
		gNewObjectDefinition.moveCall 	= MoveRippleEvent;
		gRippleEventObj = MakeNewObject(&gNewObjectDefinition);

		gRippleEventObj->CustomDrawFunction = DrawRipples;
	}



		/***********************/
		/* ADD TO RIPPLES LIST */
		/***********************/

	for (j = 0; j < numRipples; j++)
	{
			/* SCAN FOR FREE RIPPLE SLOT */

		for (i = 0; i < MAX_RIPPLES; i++)
		{
			if (!gRippleList[i].isUsed)
				goto got_it;
		}
		return;												// no free slots

	got_it:

		gRippleList[i].isUsed = true;
		gRippleList[i].coord.x = x;
		gRippleList[i].coord.y = y;
		gRippleList[i].coord.z = z;

		gRippleList[i].scale = baseScale + RandomFloat() * baseScale * 2.0f;
		gRippleList[i].scaleSpeed = scaleSpeed + RandomFloat() * scaleSpeed * 3.0f;
		gRippleList[i].alpha = .999f - (RandomFloat() * .3f);
		gRippleList[i].fadeRate = fadeRate;

		gNumRipples++;
	}
}



/******************** MOVE RIPPLE EVENT ****************************/

static void MoveRippleEvent(ObjNode *theNode)
{
int		i;
float	fps = gFramesPerSecondFrac;

	for (i = 0; i < MAX_RIPPLES; i++)
	{
		if (!gRippleList[i].isUsed)									// see if this ripple slot active
			continue;

		gRippleList[i].scale += fps * gRippleList[i].scaleSpeed;
		gRippleList[i].alpha -= fps * gRippleList[i].fadeRate;
		if (gRippleList[i].alpha <= 0.0f)							// see if done
		{
			gRippleList[i].isUsed = false;							// kill this slot
			gNumRipples--;
		}
	}

	if (gNumRipples <= 0)											// see if all done
	{
		DeleteObject(theNode);
		gRippleEventObj = nil;
	}

}


/******************** DRAW RIPPLES ***************************/

static void DrawRipples(ObjNode *theNode, const OGLSetupOutputType *setupInfo)
{
int			i;
float		s,x,y,z;

#pragma unused (theNode)

		/* ACTIVATE MATERIAL */

	MO_DrawMaterial(gSpriteGroupList[SPRITE_GROUP_GLOBAL][GLOBAL_SObjType_WaterRipple].materialObject, setupInfo);


		/* DRAW EACH RIPPLE */

	for (i = 0; i < MAX_RIPPLES; i++)
	{
		if (!gRippleList[i].isUsed)									// see if this ripple slot active
			continue;

		x = gRippleList[i].coord.x;									// get coord
		y = gRippleList[i].coord.y;
		z = gRippleList[i].coord.z;

		s = gRippleList[i].scale;									// get scale
		OGL_SetColor4f(1,1,1,gRippleList[i].alpha);						// get/set alpha

		glBegin(GL_QUADS);
		glTexCoord2f(0,0);	glVertex3f(x - s, y, z - s);
		glTexCoord2f(1,0);	glVertex3f(x + s, y, z - s);
		glTexCoord2f(1,1);	glVertex3f(x + s, y, z + s);
		glTexCoord2f(0,1);	glVertex3f(x - s, y, z + s);
		glEnd();
	}

	OGL_SetColor4f(1,1,1,1);
	gGlobalTransparency = 1.0f;
}








