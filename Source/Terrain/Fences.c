/**********************/
/*   	FENCES.C      */
/**********************/


#include "game.h"

/***************/
/* EXTERNALS   */
/***************/

/****************************/
/*    PROTOTYPES            */
/****************************/

static void DrawFences(ObjNode *theNode);
static void MakeFenceGeometry(void);


/****************************/
/*    CONSTANTS             */
/****************************/



#define	FENCE_SINK_FACTOR	30.0f

enum
{
	FENCE_TYPE_PINETREES,
	FENCE_TYPE_INVISIBLEBLOCKENEMY,

	NUM_FENCE_TYPES
};


/**********************/
/*     VARIABLES      */
/**********************/

long			gNumFences = 0;
short			gNumFencesDrawn;
FenceDefType	*gFenceList = nil;


static const short			gFenceTexture[NUM_FENCE_TYPES][2] =
{
	{SPRITE_GROUP_LEVELSPECIFIC,	LEVEL1_SObjType_Fence_PineTree},		// pine trees
	{0,	0},															// invisible enemy blocker
};


static const float			gFenceHeight[NUM_FENCE_TYPES] =
{
	MAX_ALTITUDE_DIFF + 100.0f,	// pine trees
	300,					// invisible enemy blocker
};


static const float			gFenceSink[NUM_FENCE_TYPES] =
{
	FENCE_SINK_FACTOR,					// pine trees
	FENCE_SINK_FACTOR,					// invisible enemy blocker
};

static const Boolean			gFenceIsLit[NUM_FENCE_TYPES] =
{
	true,					// pine trees
	false,					// invisible enemy blocker
};

static MOMaterialObject			*gFenceMaterials[MAX_FENCES];				// illegal refs to material for each fence in terrain


typedef struct										// we group all the vertex arrays into a stuct so that we can easily allocate it to the Vertex Array Range engine
{
	MOTriangleIndecies		fenceTriangles[MAX_FENCES][MAX_NUBS_IN_FENCE*2];
	OGLPoint3D				fencePoints[MAX_FENCES][MAX_NUBS_IN_FENCE*2];
	OGLTextureCoord			fenceUVs[MAX_FENCES][MAX_NUBS_IN_FENCE*2];
	OGLColorRGBA			fenceColors[MAX_FENCES][MAX_NUBS_IN_FENCE*2];
}FenceVertexArraysType;

static FenceVertexArraysType	gFenceVertexArrays[2];						// double-buffered VAR data
MOVertexArrayData				gFenceTriMeshData[MAX_FENCES][2];


static	ObjNode	*gFenceObj = nil;

/********************* PRIME FENCES ***********************/
//
// Called during terrain prime function to initialize
//

void PrimeFences(void)
{
long					f,i,numNubs,type, group, sprite;
FenceDefType			*fence;
OGLPoint3D				*nubs;
float					sink;

	if (gNumFences > MAX_FENCES)
		DoFatalAlert("PrimeFences: gNumFences > MAX_FENCES");


			/******************************/
			/* ADJUST TO GAME COORDINATES */
			/******************************/

	for (f = 0; f < gNumFences; f++)
	{
		fence 				= &gFenceList[f];					// point to this fence
		nubs 				= fence->nubList;					// point to nub list
		numNubs 			= fence->numNubs;					// get # nubs in fence
		type 				= fence->type;						// get fence type

		group = gFenceTexture[type][0];							// get sprite info
		sprite = gFenceTexture[type][1];						// get sprite info

		if (sprite > gNumSpritesInGroupList[group])
			DoFatalAlert("PrimeFences: illegal fence sprite");

		if (numNubs == 1)
			DoFatalAlert("PrimeFences: numNubs == 1");

		if (numNubs > MAX_NUBS_IN_FENCE)
			DoFatalAlert("PrimeFences: numNubs > MAX_NUBS_IN_FENCE");

		sink = gFenceSink[type];								// get fence sink factor

		for (i = 0; i < numNubs; i++)							// adjust nubs
		{
			nubs[i].x *= gMapToUnitValue;
			nubs[i].z *= gMapToUnitValue;
			nubs[i].y = GetTerrainY(nubs[i].x,nubs[i].z) - sink;	// calc Y
		}

		/* CALCULATE VECTOR FOR EACH SECTION */

		fence->sectionVectors = (OGLVector2D *)AllocPtr(sizeof(OGLVector2D) * (numNubs-1));		// alloc array to hold vectors
		if (fence->sectionVectors == nil)
			DoFatalAlert("PrimeFences: AllocPtr failed!");

		for (i = 0; i < (numNubs-1); i++)
		{
			fence->sectionVectors[i].x = nubs[i+1].x - nubs[i].x;
			fence->sectionVectors[i].y = nubs[i+1].z - nubs[i].z;

			OGLVector2D_Normalize(&fence->sectionVectors[i], &fence->sectionVectors[i]);
		}


		/* CALCULATE NORMALS FOR EACH SECTION */

		fence->sectionNormals = (OGLVector2D *)AllocPtr(sizeof(OGLVector2D) * (numNubs-1));		// alloc array to hold vectors
		if (fence->sectionNormals == nil)
			DoFatalAlert("PrimeFences: AllocPtr failed!");

		for (i = 0; i < (numNubs-1); i++)
		{
			OGLVector3D	v;

			v.x = fence->sectionVectors[i].x;					// get section vector (as calculated above)
			v.z = fence->sectionVectors[i].y;

			fence->sectionNormals[i].x = -v.z;					//  reduced cross product to get perpendicular normal
			fence->sectionNormals[i].y = v.x;
			OGLVector2D_Normalize(&fence->sectionNormals[i], &fence->sectionNormals[i]);
		}

	}

			/* UPDATE SONG */

//	if (gSongMovie)
//		MoviesTask(gSongMovie, 0);


			/***********************/
			/* MAKE FENCE GEOMETRY */
			/***********************/

	MakeFenceGeometry();


		/*************************************************************************/
		/* CREATE DUMMY CUSTOM OBJECT TO CAUSE FENCE DRAWING AT THE DESIRED TIME */
		/*************************************************************************/
		//
		// The fences need to be drawn after the Cyc object, but before any sprite or font objects.
		//

	gNewObjectDefinition.genre		= CUSTOM_GENRE;
	gNewObjectDefinition.slot 		= FENCE_SLOT;
	gNewObjectDefinition.moveCall 	= nil;
	gNewObjectDefinition.flags 		= STATUS_BIT_DOUBLESIDED|STATUS_BIT_NOLIGHTING|STATUS_BIT_DONTCULL|STATUS_BIT_CLIPALPHA6;

	gFenceObj = MakeNewObject(&gNewObjectDefinition);
	gFenceObj->CustomDrawFunction = DrawFences;

	gFenceObj->VertexArrayMode = VERTEX_ARRAY_RANGE_TYPE_USER_FENCES;


#if VERTEXARRAYRANGES
			/* ASSIGN MEMORY TO VERTEX ARRAY RANGE */
			//
			// Each double-buffer of fence geometry gets its own VAR range type
			//

	AssignVertexArrayRangeMemory(sizeof(FenceVertexArraysType), &gFenceVertexArrays[0], VERTEX_ARRAY_RANGE_TYPE_USER_FENCES);
	AssignVertexArrayRangeMemory(sizeof(FenceVertexArraysType), &gFenceVertexArrays[1], VERTEX_ARRAY_RANGE_TYPE_USER_FENCES2);
#endif
}



/*************** MAKE FENCE GEOMETRY *********************/

static void MakeFenceGeometry(void)
{
int						f, group, sprite;
uint16_t					type;
float					u,height,aspectRatio,textureUOff;
long					i,numNubs,j;
FenceDefType			*fence;
OGLPoint3D				*nubs;
float					minX,minY,minZ,maxX,maxY,maxZ;
Byte					b;

	for (f = 0; f < gNumFences; f++)
	{
				/******************/
				/* GET FENCE INFO */
				/******************/

		fence = &gFenceList[f];								// point to this fence
		nubs = fence->nubList;								// point to nub list
		numNubs = fence->numNubs;							// get # nubs in fence
		type = fence->type;									// get fence type
		height = gFenceHeight[type];						// get fence height

		group = gFenceTexture[type][0];						// get sprite info
		sprite = gFenceTexture[type][1];

		if (group == SPRITE_GROUP_NULL)
		{
			aspectRatio = 1;
			gFenceMaterials[f] = NULL;
		}
		else
		{
			aspectRatio = gSpriteGroupList[group][sprite].aspectRatio;	// get aspect ratio
			gFenceMaterials[f] = gSpriteGroupList[group][sprite].materialObject;	// keep illegal ref to the material
		}

		textureUOff = 1.0f / height * aspectRatio;			// calc UV offset


					/***************************/
					/* SET VERTEX ARRAY HEADER */
					/***************************/

		for (b = 0; b < 2; b++)								// make geometry for each double-buffer
		{
			gFenceTriMeshData[f][b].VARtype					= VERTEX_ARRAY_RANGE_TYPE_USER_FENCES + b;

			gFenceTriMeshData[f][b].numMaterials		 	= -1;										// we submit these manually
			gFenceTriMeshData[f][b].materials[0]			= nil;
			gFenceTriMeshData[f][b].points 					= &gFenceVertexArrays[b].fencePoints[f][0];
			gFenceTriMeshData[f][b].triangles				= &gFenceVertexArrays[b].fenceTriangles[f][0];
			gFenceTriMeshData[f][b].uvs[0]					= &gFenceVertexArrays[b].fenceUVs[f][0];
			gFenceTriMeshData[f][b].normals					= nil;
			gFenceTriMeshData[f][b].colorsFloat				= &gFenceVertexArrays[b].fenceColors[f][0];
			gFenceTriMeshData[f][b].numPoints 				= numNubs * 2;				// 2 vertices per nub
			gFenceTriMeshData[f][b].numTriangles 			= (numNubs-1) * 2;			// 2 faces per nub (minus 1st)


					/* BUILD TRIANGLE INFO */

			for (i = j = 0; i < MAX_NUBS_IN_FENCE; i++, j+=2)
			{
				gFenceVertexArrays[b].fenceTriangles[f][j].vertexIndices[0] = 1 + j;
				gFenceVertexArrays[b].fenceTriangles[f][j].vertexIndices[1] = 0 + j;
				gFenceVertexArrays[b].fenceTriangles[f][j].vertexIndices[2] = 3 + j;

				gFenceVertexArrays[b].fenceTriangles[f][j+1].vertexIndices[0] = 3 + j;
				gFenceVertexArrays[b].fenceTriangles[f][j+1].vertexIndices[1] = 0 + j;
				gFenceVertexArrays[b].fenceTriangles[f][j+1].vertexIndices[2] = 2 + j;

			}

					/* INIT VERTEX COLORS */

			for (i = 0; i < (MAX_NUBS_IN_FENCE*2); i++)
			{
				gFenceVertexArrays[b].fenceColors[f][i].a =
				gFenceVertexArrays[b].fenceColors[f][i].r =
				gFenceVertexArrays[b].fenceColors[f][i].g =
				gFenceVertexArrays[b].fenceColors[f][i].b = 1.0f;
			}


					/**********************/
					/* BUILD POINTS, UV's */
					/**********************/

			maxX = maxY = maxZ = -1000000;									// build new bboxes while we do this
			minX = minY = minZ = -maxX;

			u = 0;
			for (i = j = 0; i < numNubs; i++, j+=2)
			{
				float		x,y,z,y2;

						/* GET COORDS */

				x = nubs[i].x;
				z = nubs[i].z;
				y = nubs[i].y;
				y2 = y + height;

						/* CHECK BBOX */

				if (x < minX)	minX = x;									// find min/max bounds for bbox
				if (x > maxX)	maxX = x;
				if (z < minZ)	minZ = z;
				if (z > maxZ)	maxZ = z;
				if (y < minY)	minY = y;
				if (y2 > maxY)	maxY = y2;


					/* SET COORDS */

				gFenceVertexArrays[b].fencePoints[f][j].x = x;
				gFenceVertexArrays[b].fencePoints[f][j].y = y;
				gFenceVertexArrays[b].fencePoints[f][j].z = z;

				gFenceVertexArrays[b].fencePoints[f][j+1].x = x;
				gFenceVertexArrays[b].fencePoints[f][j+1].y = y2;
				gFenceVertexArrays[b].fencePoints[f][j+1].z = z;


					/* CALC UV COORDS */

				if (i > 0)
				{
					u += OGLPoint3D_Distance(&gFenceVertexArrays[b].fencePoints[f][j], &gFenceVertexArrays[b].fencePoints[f][j-2]) * textureUOff;
				}

				gFenceVertexArrays[b].fenceUVs[f][j].v 	= 0;									// bottom
				gFenceVertexArrays[b].fenceUVs[f][j+1].v 	= 1.0;									// top
				gFenceVertexArrays[b].fenceUVs[f][j].u 	= gFenceVertexArrays[b].fenceUVs[f][j+1].u = u;
			}
		}
				/* SET CALCULATED BBOX */

		fence->bBox.min.x = minX;
		fence->bBox.max.x = maxX;
		fence->bBox.min.y = minY;
		fence->bBox.max.y = maxY;
		fence->bBox.min.z = minZ;
		fence->bBox.max.z = maxZ;
		fence->bBox.isEmpty = false;
	}
}


/********************** DISPOSE FENCES *********************/

void DisposeFences(void)
{
int		f;

	if (!gFenceList)
		return;

#if VERTEXARRAYRANGES
	ReleaseVertexArrayRangeMemory(VERTEX_ARRAY_RANGE_TYPE_USER_FENCES);
	ReleaseVertexArrayRangeMemory(VERTEX_ARRAY_RANGE_TYPE_USER_FENCES2);
#endif

	for (f = 0; f < gNumFences; f++)
	{
		if (gFenceList[f].sectionVectors)
			SafeDisposePtr((Ptr)gFenceList[f].sectionVectors);			// nuke section vectors
		gFenceList[f].sectionVectors = nil;

		if (gFenceList[f].sectionNormals)
			SafeDisposePtr((Ptr)gFenceList[f].sectionNormals);			// nuke normal vectors
		gFenceList[f].sectionNormals = nil;

		if (gFenceList[f].nubList)
			SafeDisposePtr((Ptr)gFenceList[f].nubList);
		gFenceList[f].nubList = nil;
	}

	SafeDisposePtr((Ptr)gFenceList);
	gFenceList = nil;
	gNumFences = 0;


}





#pragma mark -


/******************** UPDATE FENCES ************************/

void UpdateFences(void)
{
float					dist,alpha, autoFadeStart = gAutoFadeStartDist;
float					autoFadeEndDist = gAutoFadeEndDist;
float					autoFadeRangeFrac = gAutoFadeRange_Frac;
long					i,numNubs,j;
FenceDefType			*fence;
OGLPoint3D				*nubs;
Byte					buffNum;
short					f;

			/* UPDATE VAR TYPE FOR THE CURRENT FRAME'S DOUBLE-BUFFER */

	buffNum = gGameViewInfoPtr->frameCount & 1;											// which VAR buffer to use?
	gFenceObj->VertexArrayMode = VERTEX_ARRAY_RANGE_TYPE_USER_FENCES + buffNum;


		/***************************************/
		/* UPDATE THE AUTO-FADE FOR EACH FENCE */
		/***************************************/
		//
		// NOTE:  we cannot do this in split-screen mode while using VAR because
		// 		the fades are different for each pane which means we'd have to wait
		//		for P1's drawing to complete before modifying P2's fence.
		//
		//

	if ((gAutoFadeStatusBits != 0) && (gNumPlayers == 1))
	{
		float	camX, camZ;

		camX = gGameViewInfoPtr->cameraPlacement[0].cameraLocation.x;			// get camera coords
		camZ = gGameViewInfoPtr->cameraPlacement[0].cameraLocation.z;


		for (f = 0; f < gNumFences; f++)
		{
			fence = &gFenceList[f];										// point to this fence
			nubs = fence->nubList;										// point to nub list
			numNubs = fence->numNubs;									// get # nubs in fence

			if (fence->type == FENCE_TYPE_INVISIBLEBLOCKENEMY)			// dont bother with invisible fences
				continue;

			for (i = j = 0; i < numNubs; i++, j+=2)
			{
					/* CALC & SET TRANSPARENCY */

				dist = CalcQuickDistance(camX, camZ, nubs[i].x, nubs[i].z);		// see if in fade zone
				if (dist < autoFadeStart)
					alpha = 1.0;
				else
				if (dist >= autoFadeEndDist)
					alpha = 0.0;
				else
				{
					dist -= autoFadeStart;										// calc xparency %
					dist *= autoFadeRangeFrac;
					if (dist < 0.0f)
						alpha = 0;
					else
						alpha = 1.0f - dist;
				}

				gFenceVertexArrays[buffNum].fenceColors[f][j].a = gFenceVertexArrays[buffNum].fenceColors[f][j+1].a = alpha;
			}

			OGL_SetVertexArrayRangeDirty(gFenceObj->VertexArrayMode);				// we've updated the VAR
		}
	}
}


/********************* DRAW FENCES ***********************/

static void DrawFences(ObjNode *theNode)
{
long		f,type;
Byte		buffNum;

#pragma unused	(theNode)

	buffNum = gGameViewInfoPtr->frameCount & 1;				// which VAR buffer to use?


			/* SET GLOBAL MATERIAL FLAGS */

	gGlobalMaterialFlags = BG3D_MATERIALFLAG_CLAMP_V|BG3D_MATERIALFLAG_ALWAYSBLEND;


			/*******************/
			/* DRAW EACH FENCE */
			/*******************/

	gNumFencesDrawn = 0;

	for (f = 0; f < gNumFences; f++)
	{
		type = gFenceList[f].type;							// get type

		if (type == FENCE_TYPE_INVISIBLEBLOCKENEMY)			// dont bother with invisible fences
			continue;

					/* DO BBOX CULLING */

		if (OGL_IsBBoxVisible(&gFenceList[f].bBox, nil))
		{
					/* CHECK LIGHTING */

			if (gFenceIsLit[type])
				OGL_EnableLighting();
			else
				OGL_DisableLighting();


					/* SUBMIT IT */

			MO_DrawMaterial(gFenceMaterials[f]);
			MO_DrawGeometry_VertexArray(&gFenceTriMeshData[f][buffNum]);

			gNumFencesDrawn++;

//			if (gDebugMode == 2)
//				DrawFenceNormals(f);
		}
	}

	gGlobalMaterialFlags = 0;
}

#if 0
/****************** DRAW FENCE NORMALS ***************************/

static void DrawFenceNormals(short f)
{
int				i,numNubs;
OGLPoint3D		*nubs;
OGLVector2D		*normals;
float			x,y,z,nx,nz;

	OGL_PushState();
	OGL_DisableTexture2D();
	OGL_SetColor4f(1,0,0,1);
	glLineWidth(3);

	numNubs  	= gFenceList[f].numNubs - 1;					// get # nubs in fence minus 1
	nubs  		= gFenceList[f].nubList;						// get ptr to nub list
	normals 	= gFenceList[f].sectionNormals;					// get ptr to normals

	for (i = 0; i < numNubs; i++)
	{
		glBegin(GL_LINES);

		x = nubs[i].x;
		y = nubs[i].y + 200.0f;			// show normal up a ways
		z = nubs[i].z;

		nx = normals[i].x * 150.0f;
		nz = normals[i].y * 150.0f;

		glVertex3f(x-nx,y,z-nz);
		glVertex3f(x + nx,y, z + nz);

		glEnd();
	}
	OGL_PopState();
	glLineWidth(1);

}
#endif



#pragma mark -

/******************** DO FENCE COLLISION **************************/
//
// returns True if hit a fence
//

Boolean DoFenceCollision(ObjNode *theNode)
{
double			fromX,fromZ,toX,toZ;
long			f,numFenceSegments,i,numReScans;
double			segFromX,segFromZ,segToX,segToZ;
OGLPoint3D		*nubs;
Boolean			intersected;
float			intersectX,intersectZ;
OGLVector2D		lineNormal;
double			radius;
double			oldX,oldZ,newX,newZ;
Boolean			hit = false,letGoOver, letGoUnder;
Boolean			isEnemy;

			/* SEE IF WE HAVE AN ENEMY */

	if (theNode->CType & CTYPE_ENEMY)
		isEnemy = true;
	else
		isEnemy = false;


			/* CALC MY MOTION LINE SEGMENT */

	oldX = theNode->OldCoord.x;						// from old coord
	oldZ = theNode->OldCoord.z;
	newX = gCoord.x;								// to new coord
	newZ = gCoord.z;
	radius = theNode->BoundingSphereRadius;


			/****************************************/
			/* SCAN THRU ALL FENCES FOR A COLLISION */
			/****************************************/

	for (f = 0; f < gNumFences; f++)
	{
		int		type;
		float	temp;
		float	r2 = radius + 20.0f;								// tweak a little to be safe

		if ((oldX == newX) && (oldZ == newZ))						// if no movement, then don't check anything
			break;


				/* SEE IF CAN GO OVER POSSIBLY */

		type = gFenceList[f].type;

		if (!isEnemy)										// make sure non-enemies skip the invisible enemy fences
			if (type == FENCE_TYPE_INVISIBLEBLOCKENEMY)
				continue;

		switch(type)
		{
//			case	FENCE_TYPE_LAWNEDGING:					// things can go over this
//					letGoOver = true;
//					letGoUnder = false;
//					break;

			default:
					letGoOver = false;
					letGoUnder = false;
		}


		/* QUICK CHECK TO SEE IF OLD & NEW COORDS (PLUS RADIUS) ARE OUTSIDE OF FENCE'S BBOX */

		temp = gFenceList[f].bBox.min.x - r2;
		if ((oldX < temp) && (newX < temp))
			continue;
		temp = gFenceList[f].bBox.max.x + r2;
		if ((oldX > temp) && (newX > temp))
			continue;

		temp = gFenceList[f].bBox.min.z - r2;
		if ((oldZ < temp) && (newZ < temp))
			continue;
		temp = gFenceList[f].bBox.max.z + r2;
		if ((oldZ > temp) && (newZ > temp))
			continue;

		nubs = gFenceList[f].nubList;				// point to nub list
		numFenceSegments = gFenceList[f].numNubs-1;	// get # line segments in fence



				/**********************************/
				/* SCAN EACH SECTION OF THE FENCE */
				/**********************************/

		numReScans = 0;
		for (i = 0; i < numFenceSegments; i++)
		{
			float	cross;

					/* GET LINE SEG ENDPOINTS */

			segFromX = nubs[i].x;
			segFromZ = nubs[i].z;
			segToX = nubs[i+1].x;
			segToZ = nubs[i+1].z;

					/* SEE IF ROUGHLY CAN GO OVER */

			if (letGoOver)
			{
				float y = GetTerrainY(segFromX,segFromZ);
				float y2 = GetTerrainY(segToX,segToZ);

				if (y2 < y)									// use lowest endpoint for this
					y = y2;

				y += gFenceHeight[type];					// calc top of fence
				if ((gCoord.y + theNode->BottomOff) >= y)	// see if bottom of the object is over it
					continue;
			}

					/* SEE IF ROUGHLY CAN GO UNDER */
			else
			if (letGoUnder)
			{
				float y = GetTerrainY(segFromX,segFromZ);

				y -= gFenceSink[type];						// calc bottom of fence
				if ((gCoord.y + theNode->TopOff) <= y)		// see if top of the object is under it
					continue;
			}


					/* CALC NORMAL TO THE LINE */
					//
					// We need to find the point on the bounding sphere which is closest to the line
					// in order to do good collision checks
					//

			lineNormal.x = oldX - segFromX;						// calc normalized vector from ref pt. to section endpoint 0
			lineNormal.y = oldZ - segFromZ;
			OGLVector2D_Normalize(&lineNormal, &lineNormal);
			cross = OGLVector2D_Cross(&gFenceList[f].sectionVectors[i], &lineNormal);	// calc cross product to determine which side we're on

			if (cross < 0.0f)
			{
				lineNormal.x = -gFenceList[f].sectionNormals[i].x;		// on the other side, so flip vector
				lineNormal.y = -gFenceList[f].sectionNormals[i].y;
			}
			else
			{
				lineNormal = gFenceList[f].sectionNormals[i];			// use pre-calculated vector
			}


					/* CALC FROM-TO POINTS OF MOTION */

			fromX = oldX - (lineNormal.x * radius);
			fromZ = oldZ - (lineNormal.y * radius);
			toX = newX - (lineNormal.x * radius);
			toZ = newZ - (lineNormal.y * radius);

					/* SEE IF THE LINES INTERSECT */

			intersected = IntersectLineSegments(fromX,  fromZ, toX, toZ,
						                     segFromX, segFromZ, segToX, segToZ,
				                             &intersectX, &intersectZ);

			if (intersected)
			{
				hit = true;

						/***************************/
						/* HANDLE THE INTERSECTION */
						/***************************/
						//
						// Move so edge of sphere would be tangent, but also a bit
						// farther so it isnt tangent.
						//

				gCoord.x = intersectX + (lineNormal.x * radius) + (lineNormal.x * 8.0f);
				gCoord.z = intersectZ + (lineNormal.y * radius) + (lineNormal.y * 8.0f);


						/* BOUNCE OFF WALL */

				{
					OGLVector2D deltaV;

					deltaV.x = gDelta.x;
					deltaV.y = gDelta.z;
					ReflectVector2D(&deltaV, &lineNormal, &deltaV);
					gDelta.x = deltaV.x * .6f;
					gDelta.z = deltaV.y * .6f;
				}

						/* UPDATE COORD & SCAN AGAIN */

				newX = gCoord.x;
				newZ = gCoord.z;
				if (++numReScans < 4)
					i = -1;							// reset segment index to scan all again (will ++ to 0 on next loop)
				else
				{
					if (!letGoOver)					// we don't want to get stuck inside the fence (from having landed on it)
					{
						gCoord.x = oldX;				// woah!  there were a lot of hits, so let's just reset the coords to be safe!
						gCoord.z = oldZ;
					}
					break;
				}
			}

			/**********************************************/
			/* NO INTERSECT, DO SAFETY CHECK FOR /\ CASES */
			/**********************************************/
			//
			// The above check may fail when the sphere is going thru
			// the tip of a tee pee /\ intersection, so this is a hack
			// to get around it.
			//

			else
			{
					/* SEE IF EITHER ENDPOINT IS IN SPHERE */

				if ((CalcQuickDistance(segFromX, segFromZ, newX, newZ) <= radius) ||
					(CalcQuickDistance(segToX, segToZ, newX, newZ) <= radius))
				{
					OGLVector2D deltaV;

					hit = true;

					gCoord.x = oldX;
					gCoord.z = oldZ;

						/* BOUNCE OFF WALL */

					deltaV.x = gDelta.x;
					deltaV.y = gDelta.z;
					ReflectVector2D(&deltaV, &lineNormal, &deltaV);
					gDelta.x = deltaV.x * .5f;
					gDelta.z = deltaV.y * .5f;
					return(hit);
				}
				else
					continue;
			}
		} // for i
	}

	return(hit);
}

/******************** SEE IF LINE SEGMENT HITS FENCE **************************/
//
// returns True if hit a fence
//

Boolean SeeIfLineSegmentHitsFence(const OGLPoint3D *endPoint1, const OGLPoint3D *endPoint2, OGLPoint3D *intersect, Boolean *overTop, float *fenceTopY)
{
float			fromX,fromZ,toX,toZ;
long			f,numFenceSegments,i;
float			segFromX,segFromZ,segToX,segToZ;
OGLPoint3D		*nubs;
Boolean			intersected;


	fromX = endPoint1->x;
	fromZ = endPoint1->z;
	toX = endPoint2->x;
	toZ = endPoint2->z;

			/****************************************/
			/* SCAN THRU ALL FENCES FOR A COLLISION */
			/****************************************/

	for (f = 0; f < gNumFences; f++)
	{
		short	type;

				/* SEE IF IGNORE */

		type = gFenceList[f].type;
		switch(type)
		{
//			case	FENCE_TYPE_DOGHAIR:						// ignore these
//					continue;
		}


		/* QUICK CHECK TO SEE IF OLD & NEW COORDS (PLUS RADIUS) ARE OUTSIDE OF FENCE'S BBOX */

		if ((fromX < gFenceList[f].bBox.min.x) && (toX < gFenceList[f].bBox.min.x))
			continue;
		if ((fromX > gFenceList[f].bBox.max.x) && (toX > gFenceList[f].bBox.max.x))
			continue;

		if ((fromZ < gFenceList[f].bBox.min.z) && (toZ < gFenceList[f].bBox.min.z))
			continue;
		if ((fromZ > gFenceList[f].bBox.max.z) && (toZ > gFenceList[f].bBox.max.z))
			continue;

		nubs = gFenceList[f].nubList;				// point to nub list
		numFenceSegments = gFenceList[f].numNubs-1;	// get # line segments in fence


				/**********************************/
				/* SCAN EACH SECTION OF THE FENCE */
				/**********************************/

		for (i = 0; i < numFenceSegments; i++)
		{
			float	ix,iz;

					/* GET LINE SEG ENDPOINTS */

			segFromX = nubs[i].x;
			segFromZ = nubs[i].z;
			segToX = nubs[i+1].x;
			segToZ = nubs[i+1].z;


					/* SEE IF THE LINES INTERSECT */

			intersected = IntersectLineSegments(fromX,  fromZ, toX, toZ,
						                     segFromX, segFromZ, segToX, segToZ,
				                             &ix, &iz);

			if (intersected)
			{
				float	fenceTop,dy,d1,d2,ratio,iy;


						/* SEE IF INTERSECT OCCURS OVER THE TOP OF THE FENCE */

				if (overTop || intersect || fenceTopY)
				{
					fenceTop = GetTerrainY(ix, iz) + gFenceHeight[gFenceList[f].type];		// calc y coord @ top of fence here

					dy = endPoint2->y - endPoint1->y;					// get dy of line segment

					d1 = CalcDistance(fromX, fromZ, toX, toZ);
					d2 = CalcDistance(fromX, fromZ, ix, iz);

					ratio = d2/d1;

					iy = endPoint1->y + (dy * ratio);					// calc intersect y coord

					if (overTop)
					{
						if (iy >= fenceTop)
							*overTop = true;
						else
							*overTop = false;
					}

					if (intersect)
					{
						intersect->x = ix;						// pass back intersect coords
						intersect->y = iy;
						intersect->z = iz;
					}

					if (fenceTopY)
						*fenceTopY = fenceTop;
				}

				return(true);
			}

		}
	}

	return(false);
}




