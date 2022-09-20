/****************************/
/*   	SKELETON.C    	    */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/

#include "3DMath.h"

extern	EventRecord			gTheEvent;
extern	NewObjectDefinitionType	gNewObjectDefinition;
extern	OGLSetupOutputType		*gGameViewInfoPtr;


/****************************/
/*    PROTOTYPES            */
/****************************/

static SkeletonObjDataType *MakeNewSkeletonBaseData(short sourceSkeletonNum);
static void DisposeSkeletonDefinitionMemory(SkeletonDefType *skeleton);


/****************************/
/*    CONSTANTS             */
/****************************/


/*********************/
/*    VARIABLES      */
/*********************/

static SkeletonDefType		*gLoadedSkeletonsList[MAX_SKELETON_TYPES];

static short	    gNumDecomposedTriMeshesInSkeleton[MAX_SKELETON_TYPES];


/**************** INIT SKELETON MANAGER *********************/

void InitSkeletonManager(void)
{
short	i;

	CalcAccelerationSplineCurve();									// calc accel curve

	for (i =0; i < MAX_SKELETON_TYPES; i++)
		gLoadedSkeletonsList[i] = nil;

}


/******************** LOAD A SKELETON ****************************/

void LoadASkeleton(Byte num, OGLSetupOutputType *setupInfo)
{
	if (num >= MAX_SKELETON_TYPES)
		DoFatalAlert("\pLoadASkeleton: MAX_SKELETON_TYPES exceeded!");

	if (gLoadedSkeletonsList[num] != nil)								// check if already loaded
		DoFatalAlert("\pLoadASkeleton:  skeleton already loaded!");


				/* LOAD THE SKELETON FILE */

	gLoadedSkeletonsList[num] = LoadSkeletonFile(num, setupInfo);


	gNumDecomposedTriMeshesInSkeleton[num] = gLoadedSkeletonsList[num]->numDecomposedTriMeshes;		// keep easy access version of this value
}





/****************** FREE SKELETON FILE **************************/
//
// Disposes of all memory used by a skeleton file (from File.c)
//

void FreeSkeletonFile(Byte skeletonType)
{
short	i;

	if (gLoadedSkeletonsList[skeletonType])										// make sure this really exists
	{
		for (i=0; i < gNumDecomposedTriMeshesInSkeleton[skeletonType]; i++)		// dispose of the local copies of the decomposed trimeshes
		{
//			MO_DeleteObjectInfo_Geometry_VertexArray(&gLocalTriMeshesOfSkelType[skeletonType][i]);	// delete the data
		}

		DisposeSkeletonDefinitionMemory(gLoadedSkeletonsList[skeletonType]);	// free skeleton data
		gLoadedSkeletonsList[skeletonType] = nil;
	}
}


/*************** FREE ALL SKELETON FILES ***************************/
//
// Free's all except for the input type (-1 == none to skip)
//

void FreeAllSkeletonFiles(short skipMe)
{
short	i;

	for (i = 0; i < MAX_SKELETON_TYPES; i++)
	{
		if (i != skipMe)
	 		FreeSkeletonFile(i);
	}
}

#pragma mark -

/***************** MAKE NEW SKELETON OBJECT *******************/
//
// This routine simply initializes the blank object.
// The function CopySkeletonInfoToNewSkeleton actually attaches the specific skeleton
// file to this ObjNode.
//

ObjNode	*MakeNewSkeletonObject(NewObjectDefinitionType *newObjDef)
{
ObjNode	*newNode;
int		type;
float	scale;

	type = newObjDef->type;
	scale = newObjDef->scale;

			/* CREATE NEW OBJECT NODE */

	newObjDef->genre = SKELETON_GENRE;
	newNode = MakeNewObject(newObjDef);
	if (newNode == nil)
		return(nil);


			/* LOAD SKELETON FILE INTO OBJECT */

	newNode->Skeleton = MakeNewSkeletonBaseData(type); 			// alloc & set skeleton data
	if (newNode->Skeleton == nil)
		DoFatalAlert("\pMakeNewSkeletonObject: MakeNewSkeletonBaseData == nil");

	UpdateObjectTransforms(newNode);


			/*  SET INITIAL DEFAULT POSITION */

	SetSkeletonAnim(newNode->Skeleton, newObjDef->animNum);
	UpdateSkeletonAnimation(newNode);
	UpdateSkinnedGeometry(newNode);								// prime the trimesh

	CalcObjectRadiusFromBBox(newNode);							// set correct bounding sphere


	newNode->VertexArrayMode = VERTEX_ARRAY_RANGE_TYPE_SKELETONS;

	return(newNode);
}




/***************** ALLOC SKELETON DEFINITION MEMORY **********************/
//
// Allocates all of the sub-arrays for a skeleton file's definition data.
// ONLY called by ReadDataFromSkeletonFile in file.c.
//
// NOTE: skeleton has already been allocated by LoadSkeleton!!!
//

void AllocSkeletonDefinitionMemory(SkeletonDefType *skeleton)
{
long	numAnims,numJoints;

	numJoints = skeleton->NumBones;														// get # joints in skeleton
	numAnims = skeleton->NumAnims;														// get # anims in skeleton

				/***************************/
				/* ALLOC ANIM EVENTS LISTS */
				/***************************/

	skeleton->NumAnimEvents = (Byte *)AllocPtr(sizeof(Byte)*numAnims);					// array which holds # events for each anim
	Alloc_2d_array(AnimEventType, skeleton->AnimEventsList, numAnims, MAX_ANIM_EVENTS);


			/* ALLOC BONE INFO */

	skeleton->Bones = (BoneDefinitionType *)AllocPtr(sizeof(BoneDefinitionType)*numJoints);


		/* ALLOC DECOMPOSED DATA */

	skeleton->decomposedPointList = (DecomposedPointType *)AllocPtr(sizeof(DecomposedPointType)*MAX_DECOMPOSED_POINTS);
	skeleton->decomposedNormalsList = (OGLVector3D *)AllocPtr(sizeof(OGLVector3D)*MAX_DECOMPOSED_NORMALS);
}


/*************** DISPOSE SKELETON DEFINITION MEMORY ***************************/
//
// Disposes of all alloced memory (from above) used by a skeleton file definition.
//

static void DisposeSkeletonDefinitionMemory(SkeletonDefType *skeleton)
{
short	j,numAnims,numJoints;

	if (skeleton == nil)
		return;

	numAnims = skeleton->NumAnims;										// get # anims in skeleton
	numJoints = skeleton->NumBones;

			/* NUKE THE SKELETON BONE POINT & NORMAL INDEX ARRAYS */

	for (j=0; j < numJoints; j++)
	{
		if (skeleton->Bones[j].pointList)
			SafeDisposePtr(skeleton->Bones[j].pointList);
		if (skeleton->Bones[j].normalList)
			SafeDisposePtr(skeleton->Bones[j].normalList);
	}
	SafeDisposePtr((Ptr)skeleton->Bones);									// free bones array
	skeleton->Bones = nil;

				/* DISPOSE ANIM EVENTS LISTS */

	SafeDisposePtr((Ptr)skeleton->NumAnimEvents);

	Free_2d_array(skeleton->AnimEventsList);


			/* DISPOSE JOINT INFO */

	for (j=0; j < numJoints; j++)
	{
		Free_2d_array(skeleton->JointKeyframes[j].keyFrames);		// dispose 2D array of keyframe data

		skeleton->JointKeyframes[j].keyFrames = nil;
	}

			/* DISPOSE DECOMPOSED DATA ARRAYS */

//	for (j = 0; j < skeleton->numDecomposedTriMeshes; j++)			// first dispose of the trimesh data in there
//	{
//		MO_DisposeObject_Geometry_VertexArray(&skeleton->decomposedTriMeshes[j]);		// dispose of material refs
//		MO_DeleteObjectInfo_Geometry_VertexArray(&skeleton->decomposedTriMeshes[j]);	// free the arrays
//	}

	if (skeleton->decomposedPointList)
	{
		SafeDisposePtr((Ptr)skeleton->decomposedPointList);
		skeleton->decomposedPointList = nil;
	}

	if (skeleton->decomposedNormalsList)
	{
		SafeDisposePtr((Ptr)skeleton->decomposedNormalsList);
		skeleton->decomposedNormalsList = nil;
	}

			/* DISPOSE OF MASTER DEFINITION BLOCK */

	SafeDisposePtr((Ptr)skeleton);
}

#pragma mark -


/****************** MAKE NEW SKELETON OBJECT DATA *********************/
//
// Allocates & inits the Skeleton data for an ObjNode.
//

static SkeletonObjDataType *MakeNewSkeletonBaseData(short skeletonNum)
{
SkeletonDefType		*skeletonDefPtr;
SkeletonObjDataType	*skeletonData;
int					i, numDecomp;


	skeletonDefPtr = gLoadedSkeletonsList[skeletonNum];				// get ptr to source skeleton definition info
	if (skeletonDefPtr == nil)
	{
		DoAlert("\pMakeNewSkeletonBaseData: Skeleton data isnt loaded!");
		ShowSystemErr(skeletonNum);
	}


			/* ALLOC MEMORY FOR NEW SKELETON OBJECT DATA STRUCTURE */

	skeletonData = (SkeletonObjDataType *)AllocPtrClear(sizeof(SkeletonObjDataType));


			/* INIT NEW SKELETON */

	skeletonData->skeletonDefinition	= skeletonDefPtr;					// point to source skeletal data
	skeletonData->AnimSpeed 			= 1.0;
	skeletonData->JointsAreGlobal 		= false;

	for (i = 0; i < MAX_DECOMPOSED_TRIMESHES; i++)
		skeletonData->overrideTexture[i] = nil;								// assume no override texture.. yet.


			/****************************************/
			/* MAKE COPY OF TRIMESHES FOR LOCAL USE */
			/****************************************/
			//
			// Each ObjNode's Skeleton Def will have it's own triMesh copies
			// of the actual skeleton's geometry.  There are 2 copies because we
			// double-buffer it for VAR.  These local copies are what
			// we can modify to perform deformation animation on.
			//

	numDecomp = gNumDecomposedTriMeshesInSkeleton[skeletonNum];		// how many trimeshes in this skeleton's geometry?

	for (i=0; i < numDecomp; i++)
	{
		MO_DuplicateVertexArrayData(&gLoadedSkeletonsList[skeletonNum]->decomposedTriMeshes[i],
									&skeletonData->deformedMeshes[0][i], VERTEX_ARRAY_RANGE_TYPE_SKELETONS);

		MO_DuplicateVertexArrayData(&gLoadedSkeletonsList[skeletonNum]->decomposedTriMeshes[i],
									&skeletonData->deformedMeshes[1][i], VERTEX_ARRAY_RANGE_TYPE_SKELETONS+1);
	}


		/* CREATE AN OPENGL "FENCE" SO THAT WE CAN TELL WHEN DRAWING THE SKELETON IS DONE */
		//
		// NOTE:  We only use these fences for determinine when it is safe do delete a skeleton.
		// 			We do NOT use this fence for determining when it is safe to modify the geometry
		//			because we are using double-buffered vertex array data for each skeleton.
		//

	if (gUsingVertexArrayRange)
	{
		glGenFencesAPPLE(1, &skeletonData->oglFence);
		skeletonData->oglFenceIsActive = false;
	}


	return(skeletonData);
}


/************************ FREE SKELETON BASE DATA ***************************/

void FreeSkeletonBaseData(SkeletonObjDataType *skeletonData, short skeletonType)
{
short	numDecomp, i;

		/* WAIT FOR OPENGL FENCE MARKER BEFORE DELETING VAR'S */
		//
		// The geometry might still be in the GPU, so be sure it's finished before
		// deleting it.  Deleting it isn't bad, but if something else uses the same memory
		// on this same frame, then that could be bad.
		//

	if (gUsingVertexArrayRange)
	{
		if (skeletonData->oglFenceIsActive)
			glFinishFenceAPPLE(skeletonData->oglFence);

			/* DISPOSE OF THE OPENGL "FENCE" */

		glDeleteFencesAPPLE(1, &skeletonData->oglFence);
		skeletonData->oglFence = nil;
		skeletonData->oglFenceIsActive = false;
	}


		/* FREE OUR LOCAL COPY OF THE SKELETON'S TRIMESH */

	numDecomp = gNumDecomposedTriMeshesInSkeleton[skeletonType];					// how many trimeshes in this skeleton's geometry?

	for (i = 0; i < numDecomp; i++)
	{
		MO_DeleteObjectInfo_Geometry_VertexArray(&skeletonData->deformedMeshes[0][i]);		// free both double-buffers
		MO_DeleteObjectInfo_Geometry_VertexArray(&skeletonData->deformedMeshes[1][i]);
	}



		/* FREE THE SKELETON DATA STRUCT */

	SafeDisposePtr(skeletonData);
}



#pragma mark -

/*************************** DRAW SKELETON ******************************/

void DrawSkeleton(ObjNode *theNode, const OGLSetupOutputType *setupInfo)
{
short				i,numTriMeshes;
short				skelType;
MOMaterialObject	*overrideTexture, *oldTexture = nil;
SkeletonObjDataType	*skeleton = theNode->Skeleton;
Byte				buffNum;

	buffNum = setupInfo->frameCount & 1;

	skelType = theNode->Type;
	numTriMeshes = gNumDecomposedTriMeshesInSkeleton[skelType];						// get # trimeshes to draw

	for (i = 0; i < numTriMeshes; i++)												// submit each trimesh of it
	{
		MOVertexArrayData *triMesh = &skeleton->deformedMeshes[buffNum][i];			// point to triMesh

		overrideTexture = skeleton->overrideTexture[i];								// get any override texture ref (illegal ref)
		if (overrideTexture)														// set override texture
		{
			if (triMesh->numMaterials > 0)
			{
				oldTexture = triMesh->materials[0];									// get the real texture for this mesh
				triMesh->materials[0] = overrideTexture;							// set the override texture (temporarily)
			}
		}

					/* SUBMIT IT */

		MO_DrawGeometry_VertexArray(triMesh, setupInfo);


		if (overrideTexture && oldTexture)											// see if need to set texture back to normal
			triMesh->materials[0] = oldTexture;
	}


		/* INSERT AN OPENGL "FENCE" INTO THE DATA STREAM SO THAT WE CAN DETECT WHEN DRAWING THIS SKELETON IS COMPLETE */

	if (gCurrentSplitScreenPane == (gNumPlayers-1))				// only submit the fence on the last pane to be drawn
	{
		glSetFenceAPPLE(skeleton->oglFence);
		skeleton->oglFenceIsActive = true;						// it's ok to call glTestFenceAPPLE or glFinishFenceAPPLE now that we've set it
	}

}














