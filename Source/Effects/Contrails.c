/****************************/
/*   	CONTRAILS.C			*/
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/

#include "game.h"

extern	OGLPoint3D				gCoord;
extern	OGLVector3D				gDelta;
extern	NewObjectDefinitionType	gNewObjectDefinition;
extern	float					gFramesPerSecondFrac,gBestCheckpointAim[];
extern	short					gNumCollisions;
extern	CollisionRec			gCollisionList[];
extern	OGLSetupOutputType		*gGameViewInfoPtr;
extern	uint32_t 					gAutoFadeStatusBits,gScores[];
extern	int						gScratch;
extern	Boolean				gGameOver, gUsingVertexArrayRange;
extern	float				gGlobalTransparency;
extern	PrefsType			gGamePrefs;
extern	SparkleType			gSparkles[];
extern	SpriteType			*gSpriteGroupList[];
extern	float				gCameraDistFromMe;
extern	OGLBoundingBox		gWaterBBox[];
extern	MetaObjectPtr			gBG3DGroupList[MAX_BG3D_GROUPS][MAX_OBJECTS_IN_GROUP];

/****************************/
/*    PROTOTYPES            */
/****************************/

static void MoveContrails(ObjNode *dummy);
static void DrawContrails(ObjNode *dummy, const OGLSetupOutputType *setupInfo);


/****************************/
/*    CONSTANTS             */
/****************************/

#define	MAX_CONTRAILS				15
#define	MAX_REF_POINTS_IN_CONTRAIL	50


typedef struct
{
	Boolean		isUsed;											// is this contrail slot used?

	float		width;											// width of contrail
	short		*indexPtr;										// ptr to short which contains this contrail's index

	short		numPoints;										// # reference points in contrail
	short		nextPointIndex;									// where in the list to put the next contrail ref point
	OGLPoint3D	refPoints[MAX_REF_POINTS_IN_CONTRAIL];
	float		alphas[MAX_REF_POINTS_IN_CONTRAIL];
	OGLVector3D	aimVectors[MAX_REF_POINTS_IN_CONTRAIL];			// direction of the contrail at this pt

	MOVertexArrayData	meshData[2];							// mesh, double buffered for VAR

}ContrailType;



#define	PLAYER_WING_CONTRAIL_ALPHA	.6f


/*********************/
/*    VARIABLES      */
/*********************/

static ContrailType	gContrails[MAX_CONTRAILS];


/************************** INIT CONTRAILS ****************************/
//
// Called at the beginning of each level.
//

void InitContrails(void)
{
short				i, b;
MOVertexArrayData	*mesh;
ObjNode				*obj;

		/***************************/
		/* INIT THE CONTRAIL LISTS */
		/***************************/

	for (i = 0; i < MAX_CONTRAILS; i++)
	{
		gContrails[i].isUsed = false;								// mark as free

				/* INIT THE DOUBLE-BUFFERED MESH DATA */

		for (b = 0; b < 2; b++)
		{
			mesh = &gContrails[i].meshData[b];

			mesh->VARtype		= VERTEX_ARRAY_RANGE_TYPE_CONTRAILS1 + b;

			mesh->numMaterials 	= 0;
			mesh->numPoints 	= 0;
			mesh->numTriangles	= 0;
			mesh->normals		= nil;
			mesh->colorsFloat	= nil;
			mesh->uvs[0] 		= nil;
			mesh->uvs[1] 		= nil;

			mesh->points 		= 	OGL_AllocVertexArrayMemory(sizeof(OGLPoint3D) * MAX_REF_POINTS_IN_CONTRAIL * 2, mesh->VARtype);
			mesh->colorsFloat	=	OGL_AllocVertexArrayMemory(sizeof(OGLColorRGBA) * MAX_REF_POINTS_IN_CONTRAIL * 2, mesh->VARtype);
			mesh->triangles		=	OGL_AllocVertexArrayMemory(sizeof(MOTriangleIndecies) * MAX_REF_POINTS_IN_CONTRAIL * 2 - 2, mesh->VARtype);
		}
	}


		/*****************************/
		/* CREATE OBJECT FOR DRAWING */
		/*****************************/

	gNewObjectDefinition.genre		= CUSTOM_GENRE;
	gNewObjectDefinition.slot 		= CONTRAIL_SLOT;
	gNewObjectDefinition.moveCall 	= MoveContrails;
	gNewObjectDefinition.scale 		= 1;
	gNewObjectDefinition.flags 		= STATUS_BIT_NOLIGHTING | STATUS_BIT_DOUBLESIDED | STATUS_BIT_DONTCULL | STATUS_BIT_NOZWRITES | STATUS_BIT_GLOW;

	obj = MakeNewObject(&gNewObjectDefinition);
	obj->CustomDrawFunction = DrawContrails;

	obj->VertexArrayMode = VERTEX_ARRAY_RANGE_TYPE_CONTRAILS1;


			/* UPDATE SONG */

//	if (gSongMovie)
//		MoviesTask(gSongMovie, 0);

}


/*********************** DISPOSE CONTRAILS ****************************/

void DisposeContrails(void)
{


}


/************************ MAKE NEW CONTRAIL ****************************/
//
// Returns index into contrail list, or -1 if none available.
//

void MakeNewContrail(float width, short *contrailNum)
{
short	i, j;

		/* SCAN FOR A FREE CONTRAIL */

	for (i = 0; i < MAX_CONTRAILS; i++)
		if (!gContrails[i].isUsed)
			goto got_it;

	*contrailNum = -1;
	return;															// no free contrails, so bail

got_it:

		/* INIT THIS CONTRAIL SLOT */

	gContrails[i].isUsed 			= true;							// make this slot as used
	gContrails[i].numPoints 		= 0;
	gContrails[i].nextPointIndex	= 0;
	gContrails[i].width				= width;
	gContrails[i].indexPtr			= contrailNum;

	for (j = 0; j < MAX_REF_POINTS_IN_CONTRAIL; j++)
		gContrails[i].alphas[j] = 0;							// clear all alpha values

	*contrailNum = i;
}


/********************** ADD POINT TO CONTRAIL *************************/

void AddPointToContrail(short contrailNum, OGLPoint3D *where, OGLVector3D *aim, float alpha)
{
long	p;

	if (!gContrails[contrailNum].isUsed)
		DoFatalAlert("AddPointToContrail:  bad contrailNum");

	p = gContrails[contrailNum].nextPointIndex;				// get index into ref point list

	gContrails[contrailNum].alphas[p] 		= alpha;		// set initial alpha for this ref pt.
	gContrails[contrailNum].refPoints[p] 	= *where;		// set coord of ref pt.
	gContrails[contrailNum].aimVectors[p] 	= *aim;			// remember the aim vector at this pt


			/* INC REF PT INDEX */

	p++;
	if (p >= MAX_REF_POINTS_IN_CONTRAIL)					// see if wrap around
		p = 0;

	gContrails[contrailNum].nextPointIndex = p;				// set where next pt will go
}


/******************* MODIFY CONTRAIL'S PREVIOUS ADDITION ***********************/

void ModifyContrailPreviousAddition(short contrailNum, OGLPoint3D *where)
{
long	p;

	if (contrailNum < 0)
		DoFatalAlert("ModifyContrailPreviousAddition:  bad contrailNum");
	if (!gContrails[contrailNum].isUsed)
		DoFatalAlert("ModifyContrailPreviousAddition:  bad contrailNum");

	p = gContrails[contrailNum].nextPointIndex - 1;				// get index into ref point list, then back 1
	if (p < 0)
		p = MAX_REF_POINTS_IN_CONTRAIL-1;

	gContrails[contrailNum].refPoints[p] = *where;			// set coord of ref pt.
}


/********************* DISCONNECT CONTRAIL *****************************/
//
// Normally each contrail has a pointer back to the ObjNode's short record which contains the index.
// The Contail function can set that short to -1 when a contrail completes.  However, sometimes
// we need to disconnect it and we don't want the short being set to -1.
//

void DisconnectContrail(short contrailNum)
{
	if (contrailNum != -1)
		gContrails[contrailNum].indexPtr = nil;
}


#pragma mark -

/*********************** MOVE CONTRAILS *******************************/

static void MoveContrails(ObjNode *theNode)
{
short				i, refP, startRefP, vertexIndex;
short				numActivePts, t;
float				fps = gFramesPerSecondFrac;
MOVertexArrayData	*mesh;
OGLPoint3D			*points;
MOTriangleIndecies	*triangles;
OGLColorRGBA		*colors;
float				alphaFade;
short				buffNum;



	buffNum = gGameViewInfoPtr->frameCount & 1;								// which VAR buffer to use?

	theNode->VertexArrayMode = VERTEX_ARRAY_RANGE_TYPE_CONTRAILS1 + buffNum;	// update the VAR range info


	for (i = 0; i < MAX_CONTRAILS; i++)
	{
		if (!gContrails[i].isUsed)
			continue;

			/* GET INDEX TO MOST RECENTLY ADDED REF PT */

		startRefP = gContrails[i].nextPointIndex - 1;
		if (startRefP < 0)
			startRefP = MAX_REF_POINTS_IN_CONTRAIL-1;


			/*********************************************/
			/* DEC THE ALPHA OF THE REF PT & COUNT # PTS */
			/*********************************************/

		numActivePts = 0;											// init ref pt counter
		refP = startRefP;

		while(gContrails[i].alphas[refP] > 0.0f)
		{
			gContrails[i].alphas[refP] -= fps * .5f;				// dec this alpha
			if (gContrails[i].alphas[refP] <= 0.0f)					// if the alpha has gone to zero then this is the tail end of the contrail
				break;

			numActivePts++;

			refP--;													// dec ref pt index
			if (refP < 0)											// see if wrap around
				refP = MAX_REF_POINTS_IN_CONTRAIL-1;
			if (refP == startRefP)									// if wrapped back to start then exit loop
				break;
		}

			/* IF NO ACTIVE PTS THEN DISABLE THE CONTRAIL */

		if (numActivePts == 0)
		{
			gContrails[i].isUsed = false;								// not used anymore
			if (gContrails[i].indexPtr)
				*gContrails[i].indexPtr = -1;							// pass -1 back to the index


			continue;
		}

				/******************/
				/* BUILD GEOMETRY */
				/******************/

		mesh = &gContrails[i].meshData[buffNum];						// get ptr to mesh struct

		if (numActivePts < 2)											// it takes at least 2 ref pts to build any geometry
		{
			mesh->numPoints = 0;
			mesh->numTriangles = 0;
			continue;
		}


				/* SET MESH BASIC INFO */

		mesh->numPoints 	= numActivePts * 2;							// set # pts in geometry
		mesh->numTriangles	= numActivePts * 2 - 2;						// set # triangles in geometry

		points 		= mesh->points;										// get ptrs to vertex arrays
		triangles 	= mesh->triangles;
		colors 		= mesh->colorsFloat;

		refP = startRefP;

		alphaFade = 0.0f;
		vertexIndex = t = 0;

		for (; numActivePts > 0; numActivePts--)						// loop thru all active ref pts to build geometry from
		{
			OGLVector3D	cross, *v;
			float		refX, refY, refZ;
			short		nextRefP;

			nextRefP = refP - 1;										// get index to next ref pt, for vector calculations below
			if (nextRefP < 0)
				nextRefP = MAX_REF_POINTS_IN_CONTRAIL-1;


				/**************************/
				/* CALCULATE THE VERTICES */
				/**************************/

			refX = gContrails[i].refPoints[refP].x;						// get ref pt coords
			refY = gContrails[i].refPoints[refP].y;
			refZ = gContrails[i].refPoints[refP].z;

			v = &gContrails[i].aimVectors[refP];							// get ptr to ref pt's aim vector


				/* CALC CROSS PRODUCT TO GIVE US THE SIDE VECTOR (AND MULTIPLY BY WIDTH) */

			cross.x = -v->z * gContrails[i].width;
			cross.z = v->x * gContrails[i].width;


				/* SET THE COORDS OF THE LEFT & RIGHT VERTICES */

			points[vertexIndex].x = refX + cross.x;							// left vertex coord
			points[vertexIndex].z = refZ + cross.z;
			points[vertexIndex].y = refY;

			points[vertexIndex+1].x = refX - cross.x;						// right vertex coord
			points[vertexIndex+1].z = refZ - cross.z;
			points[vertexIndex+1].y = refY;


					/*********************/
					/* SET VERTEX COLORS */
					/*********************/

				/* SET ALPHA TO TRANSPARENT ON END TIPS */

			if ((vertexIndex == 0) || (numActivePts == 1))
			{
				colors[vertexIndex].a =
				colors[vertexIndex+1].a = 0;
			}

				/* OTHERWISE USE CALCULATION */

			else
			{
				colors[vertexIndex].a = gContrails[i].alphas[refP] * alphaFade;
				colors[vertexIndex+1].a =  gContrails[i].alphas[refP] * alphaFade;

				alphaFade += .05f;
				if (alphaFade > 1.0f)
					alphaFade = 1.0f;
			}


					/* SET CONTRAIL COLOR */

			colors[vertexIndex].r =
			colors[vertexIndex].g =
			colors[vertexIndex].b =
			colors[vertexIndex+1].r =
			colors[vertexIndex+1].g =
			colors[vertexIndex+1].b = 1.0f;



				/*******************/
				/* BUILD TRIANGLES */
				/*******************/

			if (vertexIndex > 0)
			{
				triangles[t].vertexIndices[0] = vertexIndex-2;				// back left vert
				triangles[t].vertexIndices[1] = vertexIndex-1;				// back right vert
				triangles[t].vertexIndices[2] = vertexIndex;				// fore left vert
				t++;

				triangles[t].vertexIndices[0] = vertexIndex;				// fore left vert
				triangles[t].vertexIndices[1] = vertexIndex-1;				// back right vert
				triangles[t].vertexIndices[2] = vertexIndex+1;				// fore right vert
				t++;
			}


			vertexIndex += 2;
			refP--;
			if (refP < 0)
				refP = MAX_REF_POINTS_IN_CONTRAIL-1;
		}


		gForceVertexArrayUpdate[theNode->VertexArrayMode] = true;		// we modified some geometry so we'll need an update
	}
}



/*********************** DRAW CONTRAILS **************************/

static void DrawContrails(ObjNode *dummy, const OGLSetupOutputType *setupInfo)
{
short		i;
Boolean		drewSomething = false;
short		buffNum = setupInfo->frameCount & 1;					// which VAR buffer to use?

#pragma unused (dummy)


	OGL_EnableBlend();
	OGL_DisableTexture2D();

	for (i = 0; i < MAX_CONTRAILS; i++)
	{
		if (gContrails[i].isUsed)
		{
			if (gContrails[i].meshData[buffNum].numTriangles > 0)
			{
				MO_DrawGeometry_VertexArray(&gContrails[i].meshData[buffNum], setupInfo);
				drewSomething = true;
			}
		}
	}

}








#pragma mark -

/********************** UPDATE PLAYER CONTRAILS **************************/

void UpdatePlayerContrails(ObjNode *player)
{
Byte	i, p;
OGLPoint3D	pt;
OGLVector3D	aim;
static OGLPoint3D tipOff[2] =
{
	{35,0,3},
	{-35,0,3}
};


	p = player->PlayerNum;


			/*******************************/
			/* SEE IF DO CONTRAIL ON WINGS */
			/*******************************/

	switch(player->Skeleton->AnimNum)										// no contrails in certain aims
	{
		case	PLAYER_ANIM_FLAP:
		case	PLAYER_ANIM_DEATHDIVE:
		case	PLAYER_ANIM_DUSTDEVIL:
		case	PLAYER_ANIM_READY2GRAB:
				goto dont_do_it;
	}

	if ((player->Rot.z > (PI/10)) && (gPlayerInfo[p].analogControlX < 0.0f))				// hard right bank
		goto do_it;

	if ((player->Rot.z < (-PI/10)) && (gPlayerInfo[p].analogControlX > 0.0f))			// hard left bank
		goto do_it;

	if ((player->Rot.x > (PI/8)) && (gPlayerInfo[p].analogControlZ > 0.0f))				// hard bow
		goto do_it;

	if ((player->Rot.x < (-PI/8)) && (gPlayerInfo[p].analogControlZ < 0.0f))			// hard lift
		goto do_it;


			/* DON'T DO CONTRAILS */

dont_do_it:
	DisconnectContrail(player->ContrailSlot[0]);		// disconnect the contrail from ContrailSlot[n]
	DisconnectContrail(player->ContrailSlot[1]);

	player->ContrailSlot[0] =							// terminate any existing contrails and then bail
	player->ContrailSlot[1] = -1;
	return;


			/**************************************/
			/* UPDATE CONTRAILS ON BOTH WING TIPS */
			/**************************************/

do_it:

	FastNormalizeVector(player->Delta.x, player->Delta.y, player->Delta.z, &aim);					// calc aim vector


	for (i = 0; i < 2; i++)
	{

			/* CALC WING TIP COORD */

		if (i == 0)
			FindCoordOnJoint(player, PLAYER_JOINT_RIGHT_WINGTIP, &tipOff[i], &pt);
		else
			FindCoordOnJoint(player, PLAYER_JOINT_LEFT_WINGTIP, &tipOff[i], &pt);


				/* START NEW CONTRAIL IF NEEDED */

		if (player->ContrailSlot[i] == -1)
			MakeNewContrail(1.1f, &player->ContrailSlot[i]);


			/* CHECK IF WE'VE GONE FAR ENOUGH TO ADD A NEW REF PT TO EXISTING CONTRAIL */

		else
		{
			float dist = OGLPoint3D_Distance(&pt, &gPlayerInfo[p].previousWingContrailPt[i]);	// calc dist from prev contrail pt to this
			if (dist < 15.0f)
			{
				ModifyContrailPreviousAddition(player->ContrailSlot[i], &pt);		// instead of adding a new ref pt, just modify the last one so we don't get the popping effect
				continue;
			}
		}


			/* ADD NEW POINT TO CONTRAIL */

		if (player->ContrailSlot[i] != -1)
		{
			AddPointToContrail(player->ContrailSlot[i], &pt, &aim, PLAYER_WING_CONTRAIL_ALPHA);
			gPlayerInfo[p].previousWingContrailPt[i] = pt;
		}
	}
}







