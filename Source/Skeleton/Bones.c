/****************************/
/*   	BONES.C	    	    */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/



/****************************/
/*    EXTERNALS             */
/****************************/

#include "game.h"

extern	BG3DFileContainer		*gBG3DContainerList[];

/****************************/
/*    PROTOTYPES            */
/****************************/

static void DecomposeVertexArrayGeometry(MOVertexArrayObject *theTriMesh);
static void DecompRefMo_Recurse(MetaObjectPtr inObj);
static void DecomposeReferenceModel(MetaObjectPtr theModel);
static void UpdateSkinnedGeometry_Recurse(short joint, short skelType);


/****************************/
/*    CONSTANTS             */
/****************************/


/*********************/
/*    VARIABLES      */
/*********************/


SkeletonDefType		*gCurrentSkeleton;
SkeletonObjDataType	*gCurrentSkelObjData;

static	OGLMatrix4x4		gMatrix;

static	OGLBoundingBox		*gBBox;

static	OGLVector3D			gTransformedNormals[MAX_DECOMPOSED_NORMALS];	// temporary buffer for holding transformed normals before they're applied to their trimeshes


/******************** LOAD BONES REFERENCE MODEL *********************/
//
// INPUT: inSpec = spec of 3dmf file to load or nil to StdDialog it.
//

void LoadBonesReferenceModel(FSSpec	*inSpec, SkeletonDefType *skeleton, int skeletonType, OGLSetupOutputType *setupInfo)
{
int				g;
MetaObjectPtr	model;

	gCurrentSkeleton = skeleton;

	g = MODEL_GROUP_SKELETONBASE+skeletonType;						// calc group # to store model into
	ImportBG3D(inSpec, g, setupInfo, -1);							// load skeleton model (no VAR memory)

	model = gBG3DContainerList[g]->root;							// point to base group

	DecomposeReferenceModel(model);
}


/****************** DECOMPOSE REFERENCE MODEL ************************/

static void DecomposeReferenceModel(MetaObjectPtr theModel)
{
	gCurrentSkeleton->numDecomposedTriMeshes = 0;
	gCurrentSkeleton->numDecomposedPoints = 0;
	gCurrentSkeleton->numDecomposedNormals = 0;


		/* DO SUBRECURSIVE SCAN */

	DecompRefMo_Recurse(theModel);

}


/***************** DECOM REF MO: RECURSE ***************************/

static void DecompRefMo_Recurse(MetaObjectPtr inObj)
{
MetaObjectHeader	*head;

	head = inObj;												// convert to header ptr

				/* SEE IF FOUND GEOMETRY */

	if (head->type == MO_TYPE_GEOMETRY)
	{
		if (head->subType == MO_GEOMETRY_SUBTYPE_VERTEXARRAY)
			DecomposeVertexArrayGeometry(inObj);
		else
			DoFatalAlert("DecompRefMo_Recurse: unknown geometry subtype");
	}
	else

			/* SEE IF RECURSE SUB-GROUP */

	if (head->type == MO_TYPE_GROUP)
 	{
 		MOGroupObject	*groupObj;
 		MOGroupData		*groupData;
		int				i;

 		groupObj = inObj;
 		groupData = &groupObj->objectData;							// point to group data

  		for (i = 0; i < groupData->numObjectsInGroup; i++)			// scan all objects in group
 		{
 			MetaObjectPtr	subObj;

 			subObj = groupData->groupContents[i];					// get illegal ref to object in group
    		DecompRefMo_Recurse(subObj);							// sub-recurse this object
  		}
	}
}


/******************* DECOMPOSE VERTEX ARRAY GEOMETRY ***********************/

static void DecomposeVertexArrayGeometry(MOVertexArrayObject *theTriMesh)
{
unsigned long		numVertecies,vertNum;
OGLPoint3D			*vertexList;
long				i,n,refNum,pointNum;
OGLVector3D			*normalPtr;
DecomposedPointType	*decomposedPoint;
MOVertexArrayData	*data;

	n = gCurrentSkeleton->numDecomposedTriMeshes;										// get index into list of trimeshes
	if (n >= MAX_DECOMPOSED_TRIMESHES)
		DoFatalAlert("DecomposeATriMesh: gNumDecomposedTriMeshes > MAX_DECOMPOSED_TRIMESHES");


			/* GET TRIMESH DATA */

	gCurrentSkeleton->decomposedTriMeshes[n] = theTriMesh->objectData;					// copy vertex array geometry data
																						// NOTE that this also creates
																						// new ILLEGAL refs to any material objects
	data = &gCurrentSkeleton->decomposedTriMeshes[n];

	numVertecies = data->numPoints;														// get # verts in trimesh
	vertexList = data->points;															// point to vert list
	normalPtr  = data->normals; 															// point to normals


				/*******************************/
				/* EXTRACT VERTECIES & NORMALS */
				/*******************************/

	for (vertNum = 0; vertNum < numVertecies; vertNum++)
	{
			/* SEE IF THIS POINT IS ALREADY IN DECOMPOSED LIST */

		for (pointNum=0; pointNum < gCurrentSkeleton->numDecomposedPoints; pointNum++)
		{
			decomposedPoint = &gCurrentSkeleton->decomposedPointList[pointNum];					// point to this decomposed point

			if (PointsAreCloseEnough(&vertexList[vertNum],&decomposedPoint->realPoint))			// see if close enough to match
			{
					/* ADD ANOTHER REFERENCE */

				refNum = decomposedPoint->numRefs;												// get # refs for this point
				if (refNum >= MAX_POINT_REFS)
				{
					DoFatalAlert("DecomposeATriMesh: MAX_POINT_REFS exceeded! refNum %d", refNum);
				}

				decomposedPoint->whichTriMesh[refNum] = n;										// set triMesh #
				decomposedPoint->whichPoint[refNum] = vertNum;									// set point #
				decomposedPoint->numRefs++;														// inc counter
				goto added_vert;
			}
		}
				/* IT'S A NEW POINT SO ADD TO LIST */

		pointNum = gCurrentSkeleton->numDecomposedPoints;
		if (pointNum >= MAX_DECOMPOSED_POINTS)
			DoFatalAlert("DecomposeATriMesh: MAX_DECOMPOSED_POINTS exceeded!");

		refNum = 0;																			// it's the 1st entry (need refNum for below).

		decomposedPoint = &gCurrentSkeleton->decomposedPointList[pointNum];					// point to this decomposed point
		decomposedPoint->realPoint 				= vertexList[vertNum];						// add new point to list
		decomposedPoint->whichTriMesh[refNum] 	= n;										// set triMesh #
		decomposedPoint->whichPoint[refNum] 	= vertNum;									// set point #
		decomposedPoint->numRefs 				= 1;										// set # refs to 1

		gCurrentSkeleton->numDecomposedPoints++;											// inc # decomposed points

added_vert:


				/***********************************************/
				/* ADD THIS POINT'S NORMAL TO THE NORMALS LIST */
				/***********************************************/

					/* SEE IF NORMAL ALREADY IN LIST */

		for (i=0; i < gCurrentSkeleton->numDecomposedNormals; i++)
			if (VectorsAreCloseEnough(&normalPtr[vertNum],&gCurrentSkeleton->decomposedNormalsList[i]))	// if already in list, then dont add it again
				goto added_norm;


				/* ADD NEW NORMAL TO LIST */

		i = gCurrentSkeleton->numDecomposedNormals;										// get # decomposed normals already in list
		if (i >= MAX_DECOMPOSED_NORMALS)
			DoFatalAlert("DecomposeATriMesh: MAX_DECOMPOSED_NORMALS exceeded!");

		gCurrentSkeleton->decomposedNormalsList[i] = normalPtr[vertNum];				// add new normal to list
		gCurrentSkeleton->numDecomposedNormals++;										// inc # decomposed normals

added_norm:
					/* KEEP REF TO NORMAL IN POINT LIST */

		decomposedPoint->whichNormal[refNum] = i;										// save index to normal
	}

	gCurrentSkeleton->numDecomposedTriMeshes++;											// inc # of trimeshes in decomp list
}



/************************** UPDATE SKINNED GEOMETRY *******************************/
//
// Updates all of the points in the local trimesh data to coordinate with the
// current joint transforms.
//

void UpdateSkinnedGeometry(ObjNode *theNode)
{
long	skelType;
SkeletonObjDataType	*currentSkelObjData;

	gCurrentSkelObjData = currentSkelObjData = theNode->Skeleton;
	if (currentSkelObjData == nil)
		return;

	gCurrentSkeleton = currentSkelObjData->skeletonDefinition;
	if (gCurrentSkeleton == nil)
		DoFatalAlert("UpdateSkinnedGeometry: gCurrentSkeleton is invalid!");


			/* TOGGLE VERTEX ARRAY DOUBLE-BUFFER */

	theNode->VertexArrayMode = VERTEX_ARRAY_RANGE_TYPE_SKELETONS + (gGameViewInfoPtr->frameCount & 1);


				/* INIT BBOX */
				//
				// For skeletons, we want to build a world-space Bounding Box.
				// This makes our LineSegment->triangle collision functions faster
				// since we don't have to do our lineseg->sphere tests.  The
				// lineseg->bbox test is faster and more accurate.
				//

	gBBox = &theNode->WorldBBox;															// point objnode's world-space bbox

	gBBox->min.x = gBBox->min.y = gBBox->min.z = 10000000;
	gBBox->max.x = gBBox->max.y = gBBox->max.z = -gBBox->min.x;								// init bounding box calc

	if (gCurrentSkeleton->Bones[0].parentBone != NO_PREVIOUS_JOINT)
		DoFatalAlert("UpdateSkinnedGeometry: joint 0 isnt base - fix code Brian!");

	skelType = theNode->Type;

				/****************************/
				/* DO RECURSION TO BUILD IT */
				/****************************/

	if (currentSkelObjData->JointsAreGlobal)
		OGLMatrix4x4_SetIdentity(&gMatrix);
	else
		gMatrix = theNode->BaseTransformMatrix;


				/* CALL RECURSION */

	UpdateSkinnedGeometry_Recurse(0, skelType);									// start @ base



				/* ALSO CALC LOCAL BBOX */
				//
				// We need the local-space bbox for cull tests
				//

	theNode->LocalBBox.min.x = gBBox->min.x - theNode->Coord.x;
	theNode->LocalBBox.max.x = gBBox->max.x - theNode->Coord.x;
	theNode->LocalBBox.min.y = gBBox->min.y - theNode->Coord.y;
	theNode->LocalBBox.max.y = gBBox->max.y - theNode->Coord.y;
	theNode->LocalBBox.min.z = gBBox->min.z - theNode->Coord.z;
	theNode->LocalBBox.max.z = gBBox->max.z - theNode->Coord.z;

	gBBox->isEmpty =
	theNode->LocalBBox.isEmpty = false;
}


/******************** UPDATE SKINNED GEOMETRY: RECURSE ************************/

static void UpdateSkinnedGeometry_Recurse(short joint, short skelType)
{
long						numChildren,numPoints,p,i,numRefs,r,triMeshNum,p2,c,numNormals,n;
OGLMatrix4x4				oldM;
OGLVector3D					*normalAttribs;
BoneDefinitionType			*bonePtr;
float						minX,maxX,maxY,minY,maxZ,minZ;
long						numDecomposedPoints,numDecomposedNormals;
register float				m00,m01,m02,m10,m11,m12,m20,m21,m22,m30,m31,m32;
float						newX,newY,newZ;
SkeletonObjDataType			*currentSkelObjData = gCurrentSkelObjData;
const SkeletonDefType		*currentSkeleton = gCurrentSkeleton;
OGLMatrix4x4				*matPtr;
const MOVertexArrayData		*localTriMeshes;
Byte						buffNum;
const u_short						*normalIndexList, *pointIndexList;
const OGLVector3D					*decomposedNormalsList;
const DecomposedPointType	*decomposedPointList;

	buffNum = gGameViewInfoPtr->frameCount & 1;


	localTriMeshes = &currentSkelObjData->deformedMeshes[buffNum][0];	// get ptr to skeleton's triMeshes

	minX = gBBox->min.x;												// calc local bbox with registers for speed
	minY = gBBox->min.y;
	minZ = gBBox->min.z;
	maxX = gBBox->max.x;
	maxY = gBBox->max.y;
	maxZ = gBBox->max.z;

	numDecomposedPoints = currentSkeleton->numDecomposedPoints;
	numDecomposedNormals = currentSkeleton->numDecomposedNormals;

				/*********************************/
				/* FACTOR IN THIS JOINT'S MATRIX */
				/*********************************/

	if (gCurrentSkelObjData->JointsAreGlobal)
	{
		matPtr = &currentSkelObjData->jointTransformMatrix[joint];
	}
	else
	{
		const OGLMatrix4x4 *jointMat = &currentSkelObjData->jointTransformMatrix[joint];
		matPtr = &gMatrix;
		OGLMatrix4x4_Multiply(jointMat, matPtr, matPtr);
	}

				/* LOAD THE MATRIX INTO REGISTERS */
				//
				// note:  we load the bottom row later when we need it for point transforms.
				//

	m00 = matPtr->value[M00];	m01 = matPtr->value[M10];	m02 = matPtr->value[M20];
	m10 = matPtr->value[M01];	m11 = matPtr->value[M11];	m12 = matPtr->value[M21];
	m20 = matPtr->value[M02];	m21 = matPtr->value[M12];	m22 = matPtr->value[M22];
//	m30 = matPtr->value[M03];	m31 = matPtr->value[M13];	m32 = matPtr->value[M23];


			/*************************/
			/* TRANSFORM THE NORMALS */
			/*************************/

		/* APPLY MATRIX TO EACH NORMAL VECTOR */

	bonePtr = &currentSkeleton->Bones[joint];									// point to bone def
	numNormals = bonePtr->numNormalsAttachedToBone;								// get # normals attached to this bone
	normalIndexList = &bonePtr->normalList[0];									// get ptr to list of normal indecies
	decomposedNormalsList = &currentSkeleton->decomposedNormalsList[0];			// get ptr to actual normals

	for (p=0; p < numNormals; p++)
	{
		i = normalIndexList[p];												// get index to normal in gDecomposedNormalsList

		float x = decomposedNormalsList[i].x;								// get xyz of normal
		float y = decomposedNormalsList[i].y;
		float z = decomposedNormalsList[i].z;

		gTransformedNormals[i].x = (m00*x) + (m10*y) + (m20*z);					// transform the normal
		gTransformedNormals[i].y = (m01*x) + (m11*y) + (m21*z);
		gTransformedNormals[i].z = (m02*x) + (m12*y) + (m22*z);
	}



			/* APPLY TRANSFORMED VECTORS TO ALL REFERENCES */

	numPoints = bonePtr->numPointsAttachedToBone;								// get # points attached to this bone
	pointIndexList = &bonePtr->pointList[0];									// get ptr to list of point indecies
	decomposedPointList = &currentSkeleton->decomposedPointList[0];				// get ptr to actual points

	for (p = 0; p < numPoints; p++)
	{
		const DecomposedPointType *decomposedPt;

		i = pointIndexList[p];													// get index to point in gDecomposedPointList
		decomposedPt = &decomposedPointList[i];

		numRefs = decomposedPt->numRefs;										// get # times this point is referenced
		for (r = 0; r < numRefs; r++)
		{
			triMeshNum 	= decomposedPt->whichTriMesh[r];						// get triMesh # that uses this point
			p2 			= decomposedPt->whichPoint[r];							// get point # in the triMesh
			n 			= decomposedPt->whichNormal[r];							// get index into gDecomposedNormalsList

			normalAttribs = localTriMeshes[triMeshNum].normals;					// point to normals list
			normalAttribs[p2] = gTransformedNormals[n];							// copy transformed normal into triMesh
		}
	}

			/************************/
			/* TRANSFORM THE POINTS */
			/************************/

			/* LOAD THE REMAINING MATRIX VALUES */

	m30 = matPtr->value[M03];	m31 = matPtr->value[M13];	m32 = matPtr->value[M23];

	for (p = 0; p < numPoints; p++)
	{
		float	x,y,z;
		const DecomposedPointType *decomposedPt;

		i = bonePtr->pointList[p];													// get index to point in gDecomposedPointList

		decomposedPt = &decomposedPointList[i];

		x = decomposedPt->boneRelPoint.x;											// get xyz of point
		y = decomposedPt->boneRelPoint.y;
		z = decomposedPt->boneRelPoint.z;

					/* TRANSFORM */

		newX = (m00*x) + (m10*y) + (m20*z) + m30;										// transform x value
		newY = (m01*x) + (m11*y) + (m21*z) + m31;										// transform y
		newZ = (m02*x) + (m12*y) + (m22*z) + m32;										// transform z

				/* TRANSFORM & UPDATE BBOX */


#if defined (__ppc__)
			// Using fsel is a much faster way to do this!
			// It avoids any branches will kill the instruction pipeline
			//
			// fsel:  if (test >= 0) return a; else return b;
			//

		x = newX - minX;
		minX = __fsel(x, minX, newX);
		x = newX - maxX;
		maxX = __fsel(x, newX, maxX);

		y = newY - minY;
		minY = __fsel(y, minY, newY);
		y = newY - maxY;
		maxY = __fsel(y, newY, maxY);

		z = newZ - minZ;
		minZ = __fsel(z, minZ, newZ);
		z = newZ - maxZ;
		maxZ = __fsel(z, newZ, maxZ);
#else

		if (newX < minX)																// update bbox X
			minX = newX;
		if (newX > maxX)
			maxX = newX;

		if (newY < minY)																// update bbox Y
			minY = newY;
		if (newY > maxY)
			maxY = newY;

		if (newZ > maxZ)																// update bbox Z
			maxZ = newZ;
		if (newZ < minZ)
			minZ = newZ;
#endif

				/* APPLY NEW POINT TO ALL REFERENCES */

		numRefs = decomposedPt->numRefs;												// get # times this point is referenced
		for (r = 0; r < numRefs; r++)
		{
			triMeshNum = decomposedPt->whichTriMesh[r];
			p2 = decomposedPt->whichPoint[r];

			localTriMeshes[triMeshNum].points[p2].x = newX;
			localTriMeshes[triMeshNum].points[p2].y = newY;
			localTriMeshes[triMeshNum].points[p2].z = newZ;
		}
	}

				/* UPDATE GLOBAL BBOX */

	gBBox->min.x = minX;
	gBBox->min.y = minY;
	gBBox->min.z = minZ;
	gBBox->max.x = maxX;
	gBBox->max.y = maxY;
	gBBox->max.z = maxZ;


			/* RECURSE THRU ALL CHILDREN */

	numChildren = currentSkeleton->numChildren[joint];									// get # children
	for (c = 0; c < numChildren; c++)
	{
		oldM = gMatrix;																	// push matrix
		UpdateSkinnedGeometry_Recurse(currentSkeleton->childIndecies[joint][c], skelType);
		gMatrix = oldM;																	// pop matrix
	}


	gForceVertexArrayUpdate[VERTEX_ARRAY_RANGE_TYPE_SKELETONS + buffNum] = true;		// remember to update VAR
}


/******************* PRIME BONE DATA *********************/
//
// After a skeleton file is loaded, this will calc some other needed things.
//

void PrimeBoneData(SkeletonDefType *skeleton)
{
long	i,b,j;

	if (skeleton->NumBones == 0)
		DoFatalAlert("PrimeBoneData: # = 0??");


			/* SET THE FORWARD LINKS */

	for (b = 0; b < skeleton->NumBones; b++)
	{
		skeleton->numChildren[b] = 0;								// init child counter

		for (i = 0; i < skeleton->NumBones; i++)					// look for a child
		{
			if (skeleton->Bones[i].parentBone == b)					// is this "i" a child of "b"?
			{
				j = skeleton->numChildren[b];						// get # children
				if (j >= MAX_CHILDREN)
					DoFatalAlert("CreateSkeletonFromBones: MAX_CHILDREN exceeded!");

				skeleton->childIndecies[b][j] = i;					// set index to child

				skeleton->numChildren[b]++;							// inc # children
			}
		}
	}
}










