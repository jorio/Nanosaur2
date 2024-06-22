/****************************/
/*      FILE ROUTINES       */
/* By Brian Greenstone      */
/* (c)2003 Pangea Software  */
/* (c)2022 Iliyas Jorio     */
/****************************/


/***************/
/* EXTERNALS   */
/***************/

#include <time.h>
#include "game.h"
#include "stb_image.h"

/****************************/
/*    PROTOTYPES            */
/****************************/

static void ReadDataFromSkeletonFile(SkeletonDefType *skeleton, FSSpec *fsSpec, int skeletonType);
static void ReadDataFromPlayfieldFile(FSSpec *specPtr);

/****************************/
/*    CONSTANTS             */
/****************************/

#define	SKELETON_FILE_VERS_NUM	0x0110			// v1.1

		/* PLAYFIELD HEADER */

typedef struct
{
	NumVersion	version;							// version of file
	int32_t		numItems;							// # items in map
	int32_t		mapWidth;							// width of map
	int32_t		mapHeight;							// height of map
	float		tileSize;							// 3D unit size of a tile
	float		minY,maxY;							// min/max height values
	int32_t		numSplines;							// # splines
	int32_t		numFences;							// # fences
	int32_t		numUniqueSuperTiles;				// # unique supertile
	int32_t		numWaterPatches;                    // # water patches
	int32_t		numCheckpoints;						// # checkpoints
	int32_t		unused[10];
}PlayfieldHeaderType;


		/* FENCE STRUCTURE IN FILE */
		//
		// note: we copy this data into our own fence list
		//		since the game uses a slightly different
		//		data structure.
		//

typedef	struct
{
	int32_t			x,z;
}FencePointType;


typedef struct
{
	uint16_t			type;				// type of fence
	short			numNubs;			// # nubs in fence
	int32_t			junk;			// handle to nub list
	Rect			bBox;				// bounding box of fence area
}FileFenceDefType;




/**********************/
/*     VARIABLES      */
/**********************/


static	PrefsType gDiskShadowPrefs;

float	g3DTileSize, g3DMinY, g3DMaxY;




/******************* LOAD SKELETON *******************/
//
// Loads a skeleton file & creates storage for it.
//
// NOTE: Skeleton types 0..NUM_CHARACTERS-1 are reserved for player character skeletons.
//		Skeleton types NUM_CHARACTERS and over are for other skeleton entities.
//
// OUTPUT:	Ptr to skeleton data
//

SkeletonDefType *LoadSkeletonFile(short skeletonType)
{
QDErr		iErr;
short		fRefNum;
FSSpec		fsSpecSkeleton;
FSSpec		fsSpecBG3D;
SkeletonDefType	*skeleton;
char		pathBuf[128];
const char*	modelNames[MAX_SKELETON_TYPES] =
{
	[SKELETON_TYPE_PLAYER]			= "nano",
	[SKELETON_TYPE_WORMHOLE]		= "wormhole",
	[SKELETON_TYPE_RAPTOR]			= "raptor",
	[SKELETON_TYPE_BONUSWORMHOLE]	= "bonusworm",
	[SKELETON_TYPE_BRACH]			= "brach",
	[SKELETON_TYPE_WORM]			= "worm",
	[SKELETON_TYPE_RAMPHOR]			= "ramphor",
};

	GAME_ASSERT(skeletonType >= 0);
	GAME_ASSERT(skeletonType < MAX_SKELETON_TYPES);
	const char* modelName = modelNames[skeletonType];

	snprintf(pathBuf, sizeof(pathBuf), ":Skeletons:%s.skeleton", modelName);
	FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, pathBuf, &fsSpecSkeleton);

	snprintf(pathBuf, sizeof(pathBuf), ":Skeletons:%s.bg3d", modelName);
	FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, pathBuf, &fsSpecBG3D);


			/* OPEN THE FILE'S REZ FORK */

	fRefNum = FSpOpenResFile(&fsSpecSkeleton, fsRdPerm);
	GAME_ASSERT(fRefNum != -1);

	UseResFile(fRefNum);
	GAME_ASSERT(noErr == ResError());


			/* ALLOC MEMORY FOR SKELETON INFO STRUCTURE */

	skeleton = (SkeletonDefType *) AllocPtrClear(sizeof(SkeletonDefType));
	GAME_ASSERT(skeleton);


			/* READ SKELETON RESOURCES */

	ReadDataFromSkeletonFile(skeleton, &fsSpecBG3D, skeletonType);
	PrimeBoneData(skeleton);

			/* CLOSE REZ FILE */

	CloseResFile(fRefNum);

	return(skeleton);
}


/************* READ DATA FROM SKELETON FILE *******************/
//
// Current rez file is set to the file.
//

static void ReadDataFromSkeletonFile(SkeletonDefType *skeleton, FSSpec *fsSpecBG3D, int skeletonType)
{
Handle				hand;
int					i,k,j;
long				numJoints,numAnims,numKeyframes;
SkeletonFile_Header_Type	*headerPtr;
short				version;
AliasHandle				alias;
OSErr					iErr;
FSSpec					target;
Boolean					wasChanged;
OGLPoint3D				*pointPtr;


			/************************/
			/* READ HEADER RESOURCE */
			/************************/

	hand = GetResource('Hedr',1000);
	if (hand == nil)
		DoFatalAlert("ReadDataFromSkeletonFile: Error reading header resource!");
	headerPtr = (SkeletonFile_Header_Type *)*hand;
	version = SwizzleShort(&headerPtr->version);
	if (version != SKELETON_FILE_VERS_NUM)
		DoFatalAlert("Skeleton file has wrong version #");

	numAnims = skeleton->NumAnims = SwizzleShort(&headerPtr->numAnims);			// get # anims in skeleton
	numJoints = skeleton->NumBones = SwizzleShort(&headerPtr->numJoints);		// get # joints in skeleton
	ReleaseResource(hand);

	if (numJoints > MAX_JOINTS)										// check for overload
		DoFatalAlert("ReadDataFromSkeletonFile: numJoints > MAX_JOINTS");


				/* ALLOCATE MEMORY FOR SKELETON DATA */

	AllocSkeletonDefinitionMemory(skeleton);



		/********************************/
		/* 	LOAD THE REFERENCE GEOMETRY */
		/********************************/

#if 1
	// Source port change: original game used to resolve path to BG3D via alias resource within skeleton rez fork.
	// Instead, we're forcing the BG3D's filename (sans extension) to match the skeleton's.
	LoadBonesReferenceModel(fsSpecBG3D, skeleton, skeletonType);
#else
	alias = (AliasHandle)GetResource(rAliasType,1000);				// alias to geometry BG3D file
	if (alias != nil)
	{
		iErr = ResolveAlias(fsSpec, alias, &target, &wasChanged);	// try to resolve alias
		if (!iErr)
			LoadBonesReferenceModel(&target,skeleton, skeletonType);
		else
			DoFatalAlert("ReadDataFromSkeletonFile: Cannot find Skeleton's BG3D file!");
 		ReleaseResource((Handle)alias);
	}
	else
		DoFatalAlert("ReadDataFromSkeletonFile: file is missing the Alias resource");
#endif


		/***********************************/
		/*  READ BONE DEFINITION RESOURCES */
		/***********************************/

	for (i=0; i < numJoints; i++)
	{
		File_BoneDefinitionType	*bonePtr;
		uint16_t					*indexPtr;

			/* READ BONE DATA */

		hand = GetResource('Bone',1000+i);
		if (hand == nil)
			DoFatalAlert("Error reading Bone resource!");
		HLock(hand);
		bonePtr = (File_BoneDefinitionType *)*hand;

			/* COPY BONE DATA INTO ARRAY */

		skeleton->Bones[i].parentBone = SwizzleLong(&bonePtr->parentBone);					// index to previous bone
		skeleton->Bones[i].coord.x = SwizzleFloat(&bonePtr->coord.x);						// absolute coord (not relative to parent!)
		skeleton->Bones[i].coord.y = SwizzleFloat(&bonePtr->coord.y);
		skeleton->Bones[i].coord.z = SwizzleFloat(&bonePtr->coord.z);
		skeleton->Bones[i].numPointsAttachedToBone = SwizzleUShort(&bonePtr->numPointsAttachedToBone);		// # vertices/points that this bone has
		skeleton->Bones[i].numNormalsAttachedToBone = SwizzleUShort(&bonePtr->numNormalsAttachedToBone);	// # vertex normals this bone has
		ReleaseResource(hand);

			/* ALLOC THE POINT & NORMALS SUB-ARRAYS */

		skeleton->Bones[i].pointList = (uint16_t *) AllocPtrClear(sizeof(uint16_t) * (int)skeleton->Bones[i].numPointsAttachedToBone);
		if (skeleton->Bones[i].pointList == nil)
			DoFatalAlert("ReadDataFromSkeletonFile: AllocPtr/pointList failed!");

		skeleton->Bones[i].normalList = (uint16_t *) AllocPtrClear(sizeof(uint16_t) * (int)skeleton->Bones[i].numNormalsAttachedToBone);
		if (skeleton->Bones[i].normalList == nil)
			DoFatalAlert("ReadDataFromSkeletonFile: AllocPtr/normalList failed!");

			/* READ POINT INDEX ARRAY */

		hand = GetResource('BonP',1000+i);
		if (hand == nil)
			DoFatalAlert("Error reading BonP resource!");
		HLock(hand);
		indexPtr = (uint16_t *)(*hand);

			/* COPY POINT INDEX ARRAY INTO BONE STRUCT */

		for (j=0; j < skeleton->Bones[i].numPointsAttachedToBone; j++)
			skeleton->Bones[i].pointList[j] = SwizzleUShort(&indexPtr[j]);
		ReleaseResource(hand);


			/* READ NORMAL INDEX ARRAY */

		hand = GetResource('BonN',1000+i);
		if (hand == nil)
			DoFatalAlert("Error reading BonN resource!");
		HLock(hand);
		indexPtr = (uint16_t *)(*hand);

			/* COPY NORMAL INDEX ARRAY INTO BONE STRUCT */

		for (j=0; j < skeleton->Bones[i].numNormalsAttachedToBone; j++)
			skeleton->Bones[i].normalList[j] = SwizzleUShort(&indexPtr[j]);
		ReleaseResource(hand);

	}


		/*******************************/
		/* READ POINT RELATIVE OFFSETS */
		/*******************************/
		//
		// The "relative point offsets" are the only things
		// which do not get rebuilt in the ModelDecompose function.
		// We need to restore these manually.

	hand = GetResource('RelP', 1000);
	if (hand == nil)
		DoFatalAlert("Error reading RelP resource!");
	HLock(hand);
	pointPtr = (OGLPoint3D *)*hand;

	i = (int) (GetHandleSize(hand) / sizeof(OGLPoint3D));
	if (i != skeleton->numDecomposedPoints)
		DoFatalAlert("# of points in Reference Model has changed!");
	else
	{
		for (i = 0; i < skeleton->numDecomposedPoints; i++)
		{
			skeleton->decomposedPointList[i].boneRelPoint.x = SwizzleFloat(&pointPtr[i].x);
			skeleton->decomposedPointList[i].boneRelPoint.y = SwizzleFloat(&pointPtr[i].y);
			skeleton->decomposedPointList[i].boneRelPoint.z = SwizzleFloat(&pointPtr[i].z);
		}
	}
	ReleaseResource(hand);


			/*********************/
			/* READ ANIM INFO   */
			/*********************/

	for (i=0; i < numAnims; i++)
	{
		AnimEventType		*animEventPtr;
		SkeletonFile_AnimHeader_Type	*animHeaderPtr;

				/* READ ANIM HEADER */

		hand = GetResource('AnHd',1000+i);
		if (hand == nil)
			DoFatalAlert("Error getting anim header resource");
		HLock(hand);
		animHeaderPtr = (SkeletonFile_AnimHeader_Type *)*hand;

		skeleton->NumAnimEvents[i] = SwizzleShort(&animHeaderPtr->numAnimEvents);			// copy # anim events in anim
		ReleaseResource(hand);

			/* READ ANIM-EVENT DATA */

		hand = GetResource('Evnt',1000+i);
		if (hand == nil)
			DoFatalAlert("Error reading anim-event data resource!");
		animEventPtr = (AnimEventType *)*hand;
		for (j=0;  j < skeleton->NumAnimEvents[i]; j++)
		{
			skeleton->AnimEventsList[i][j] = *animEventPtr++;							// copy whole thing
			skeleton->AnimEventsList[i][j].time = SwizzleShort(&skeleton->AnimEventsList[i][j].time);	// then swizzle the 16-bit short value
		}
		ReleaseResource(hand);


			/* READ # KEYFRAMES PER JOINT IN EACH ANIM */

		hand = GetResource('NumK',1000+i);									// read array of #'s for this anim
		if (hand == nil)
			DoFatalAlert("Error reading # keyframes/joint resource!");
		for (j=0; j < numJoints; j++)
			skeleton->JointKeyframes[j].numKeyFrames[i] = (*hand)[j];
		ReleaseResource(hand);
	}


	for (j=0; j < numJoints; j++)
	{
		JointKeyframeType	*keyFramePtr;

				/* ALLOC 2D ARRAY FOR KEYFRAMES */

		Alloc_2d_array(JointKeyframeType,skeleton->JointKeyframes[j].keyFrames,	numAnims,MAX_KEYFRAMES);

		if ((skeleton->JointKeyframes[j].keyFrames == nil) || (skeleton->JointKeyframes[j].keyFrames[0] == nil))
			DoFatalAlert("ReadDataFromSkeletonFile: Error allocating Keyframe Array.");

					/* READ THIS JOINT'S KF'S FOR EACH ANIM */

		for (i=0; i < numAnims; i++)
		{
			numKeyframes = skeleton->JointKeyframes[j].numKeyFrames[i];					// get actual # of keyframes for this joint
			if (numKeyframes > MAX_KEYFRAMES)
				DoFatalAlert("Error: numKeyframes > MAX_KEYFRAMES");

					/* READ A JOINT KEYFRAME */

			hand = GetResource('KeyF',1000+(i*100)+j);
			if (hand == nil)
				DoFatalAlert("Error reading joint keyframes resource!");
			keyFramePtr = (JointKeyframeType *)*hand;
			for (k = 0; k < numKeyframes; k++)												// copy this joint's keyframes for this anim
			{
				skeleton->JointKeyframes[j].keyFrames[i][k].tick				= SwizzleLong(&keyFramePtr->tick);
				skeleton->JointKeyframes[j].keyFrames[i][k].accelerationMode	= SwizzleLong(&keyFramePtr->accelerationMode);
				skeleton->JointKeyframes[j].keyFrames[i][k].coord.x				= SwizzleFloat(&keyFramePtr->coord.x);
				skeleton->JointKeyframes[j].keyFrames[i][k].coord.y				= SwizzleFloat(&keyFramePtr->coord.y);
				skeleton->JointKeyframes[j].keyFrames[i][k].coord.z				= SwizzleFloat(&keyFramePtr->coord.z);
				skeleton->JointKeyframes[j].keyFrames[i][k].rotation.x			= SwizzleFloat(&keyFramePtr->rotation.x);
				skeleton->JointKeyframes[j].keyFrames[i][k].rotation.y			= SwizzleFloat(&keyFramePtr->rotation.y);
				skeleton->JointKeyframes[j].keyFrames[i][k].rotation.z			= SwizzleFloat(&keyFramePtr->rotation.z);
				skeleton->JointKeyframes[j].keyFrames[i][k].scale.x				= SwizzleFloat(&keyFramePtr->scale.x);
				skeleton->JointKeyframes[j].keyFrames[i][k].scale.y				= SwizzleFloat(&keyFramePtr->scale.y);
				skeleton->JointKeyframes[j].keyFrames[i][k].scale.z				= SwizzleFloat(&keyFramePtr->scale.z);

				keyFramePtr++;
			}
			ReleaseResource(hand);
		}
	}

}

#pragma mark -



/******************** LOAD PREFS **********************/

OSErr LoadPrefs(void)
{
	OSErr iErr = LoadUserDataFile(PREFS_FILENAME, PREFS_MAGIC, sizeof(gGamePrefs), (Ptr) &gGamePrefs);

	if (noErr != iErr)
	{
		InitDefaultPrefs();
	}

	memcpy(&gDiskShadowPrefs, &gGamePrefs, sizeof(PrefsType));

	return iErr;
}



/******************** SAVE PREFS **********************/

OSErr SavePrefs(void)
{
	if (0 == memcmp(&gDiskShadowPrefs, &gGamePrefs, sizeof(PrefsType)))
	{
		return noErr;
	}

	memcpy(&gDiskShadowPrefs, &gGamePrefs, sizeof(PrefsType));

	return SaveUserDataFile(PREFS_FILENAME, PREFS_MAGIC, sizeof(gGamePrefs), (Ptr) &gGamePrefs);
}



#pragma mark -

/******************* LOAD PLAYFIELD *******************/

void LoadPlayfield(FSSpec *specPtr)
{

	gDisableHiccupTimer = true;

			/* READ PLAYFIELD RESOURCES */

	ReadDataFromPlayfieldFile(specPtr);


				/* DO ADDITIONAL SETUP */

	CreateSuperTileMemoryList();		// allocate memory for the supertile geometry
	CalculateSplitModeMatrix();					// precalc the tile split mode matrix
	InitSuperTileGrid();						// init the supertile state grid

	BuildTerrainItemList();						// build list of items & find player start coords


			/* CAST ITEM SHADOWS */

	DoItemShadowCasting();
}


/********************** READ DATA FROM PLAYFIELD FILE ************************/

static void ReadDataFromPlayfieldFile(FSSpec *specPtr)
{
Handle					hand;
PlayfieldHeaderType		**header;
float					yScale;
short					fRefNum;
OSErr					iErr;

#if 0
			/* USE 16-BIT IF IN LOW-QUALITY RENDER MODES OR LOW ON VRAM */

	if (gGamePrefs.lowRenderQuality || (gGamePrefs.depth != 32) || (gVRAMAfterBuffers < 0x6000000))
		gTerrainIs32Bit = false;
	else
		gTerrainIs32Bit = true;
#endif


				/* OPEN THE REZ-FORK */

	fRefNum = FSpOpenResFile(specPtr,fsRdPerm);
	if (fRefNum == -1)
		DoFatalAlert("LoadPlayfield: FSpOpenResFile failed.  You seem to have a corrupt or missing file.  Please reinstall the game.");
	UseResFile(fRefNum);


			/************************/
			/* READ HEADER RESOURCE */
			/************************/

	hand = GetResource('Hedr',1000);
	if (hand == nil)
	{
		DoAlert("ReadDataFromPlayfieldFile: Error reading header resource!");
		return;
	}

	header = (PlayfieldHeaderType **)hand;
	gNumTerrainItems		= SwizzleLong(&(**header).numItems);
	gTerrainTileWidth		= SwizzleLong(&(**header).mapWidth);
	gTerrainTileDepth		= SwizzleLong(&(**header).mapHeight);
	g3DTileSize				= SwizzleFloat(&(**header).tileSize);
	g3DMinY					= SwizzleFloat(&(**header).minY);
	g3DMaxY					= SwizzleFloat(&(**header).maxY);
	gNumSplines				= SwizzleLong(&(**header).numSplines);
	gNumFences				= SwizzleLong(&(**header).numFences);
	gNumWaterPatches		= SwizzleLong(&(**header).numWaterPatches);
	gNumUniqueSuperTiles	= SwizzleLong(&(**header).numUniqueSuperTiles);
	gNumLineMarkers			= SwizzleLong(&(**header).numCheckpoints);

	ReleaseResource(hand);

	if ((gTerrainTileWidth % SUPERTILE_SIZE) != 0)		// terrain must be non-fractional number of supertiles in w/h
		DoFatalAlert("ReadDataFromPlayfieldFile: terrain width not a supertile multiple");
	if ((gTerrainTileDepth % SUPERTILE_SIZE) != 0)
		DoFatalAlert("ReadDataFromPlayfieldFile: terrain depth not a supertile multiple");


				/* CALC SOME GLOBALS HERE */

	gTerrainTileWidth = (gTerrainTileWidth/SUPERTILE_SIZE)*SUPERTILE_SIZE;		// round size down to nearest supertile multiple
	gTerrainTileDepth = (gTerrainTileDepth/SUPERTILE_SIZE)*SUPERTILE_SIZE;
	gTerrainUnitWidth = gTerrainTileWidth*gTerrainPolygonSize;					// calc world unit dimensions of terrain
	gTerrainUnitDepth = gTerrainTileDepth*gTerrainPolygonSize;
	gNumSuperTilesDeep = gTerrainTileDepth/SUPERTILE_SIZE;						// calc size in supertiles
	gNumSuperTilesWide = gTerrainTileWidth/SUPERTILE_SIZE;


			/*******************************/
			/* SUPERTILE RELATED RESOURCES */
			/*******************************/

			/* READ SUPERTILE GRID MATRIX */

	if (gSuperTileTextureGrid)														// free old array
		Free_2d_array(gSuperTileTextureGrid);
	Alloc_2d_array(short, gSuperTileTextureGrid, gNumSuperTilesDeep, gNumSuperTilesWide);

	hand = GetResource('STgd',1000);												// load grid from rez
	if (hand == nil)
		DoFatalAlert("ReadDataFromPlayfieldFile: Error reading supertile rez resource!");
	else																			// copy rez into 2D array
	{
		short *src = (short *)*hand;

#if _DEBUG
		int* stNumUses = AllocPtrClear(gNumUniqueSuperTiles * sizeof(int));
#endif

		for (int row = 0; row < gNumSuperTilesDeep; row++)
		{
			for (int col = 0; col < gNumSuperTilesWide; col++)
			{
				short stId = SwizzleShort(src++);
				gSuperTileTextureGrid[row][col] = stId;

#if _DEBUG
				if (stId != -1)
				{
					printf("%03d ", stId);
					stNumUses[stId]++;
					GAME_ASSERT(stNumUses[stId] == 1);  // make sure it's only used ONCE
				}
				else
				{
					printf("--- ");
				}
#endif
			}

#if _DEBUG
			printf("\n");
#endif
		}

#if _DEBUG
		SafeDisposePtr(stNumUses);
#endif

		ReleaseResource(hand);
	}


			/* READ HEIGHT DATA MATRIX */

	yScale = gTerrainPolygonSize / g3DTileSize;											// need to scale original geometry units to game units

	Alloc_2d_array(float, gMapYCoords, gTerrainTileDepth+1, gTerrainTileWidth+1);			// alloc 2D array for map
	Alloc_2d_array(float, gMapYCoordsOriginal, gTerrainTileDepth+1, gTerrainTileWidth+1);	// and the copy of it

	hand = GetResource('YCrd',1000);
	if (hand == nil)
		DoAlert("ReadDataFromPlayfieldFile: Error reading height data resource!");
	else
	{
		float *src = (float *)*hand;
		for (int row = 0; row <= gTerrainTileDepth; row++)
		{
			for (int col = 0; col <= gTerrainTileWidth; col++)
			{
				gMapYCoordsOriginal[row][col] = gMapYCoords[row][col] = SwizzleFloat(src++) * yScale;
			}
		}
		ReleaseResource(hand);
	}

				/**************************/
				/* ITEM RELATED RESOURCES */
				/**************************/

				/* READ ITEM LIST */

	hand = GetResource('Itms',1000);
	if (hand == nil)
		DoFatalAlert("ReadDataFromPlayfieldFile: Error reading itemlist resource!");
	else
	{
		File_TerrainItemEntryType   *rezItems;
		HLock(hand);
		rezItems = (File_TerrainItemEntryType *)*hand;


					/* COPY INTO OUR STRUCT */

		gMasterItemList = AllocPtrClear(sizeof(TerrainItemEntryType) * gNumTerrainItems);			// alloc array of items

		for (int i = 0; i < gNumTerrainItems; i++)
		{
			gMasterItemList[i].x = SwizzleULong(&rezItems[i].x) * gMapToUnitValue;								// convert coordinates
			gMasterItemList[i].y = SwizzleULong(&rezItems[i].y) * gMapToUnitValue;

			gMasterItemList[i].type = SwizzleUShort(&rezItems[i].type);
			gMasterItemList[i].parm[0] = rezItems[i].parm[0];
			gMasterItemList[i].parm[1] = rezItems[i].parm[1];
			gMasterItemList[i].parm[2] = rezItems[i].parm[2];
			gMasterItemList[i].parm[3] = rezItems[i].parm[3];
			gMasterItemList[i].flags = SwizzleUShort(&rezItems[i].flags);
		}

		ReleaseResource(hand);																// nuke the rez
	}



			/****************************/
			/* SPLINE RELATED RESOURCES */
			/****************************/

			/* READ SPLINE LIST */

	hand = GetResource('Spln',1000);
	if (hand)
	{
		File_SplineDefType	*splinePtr = (File_SplineDefType *)*hand;

		gSplineList = AllocPtrClear(sizeof(SplineDefType) * gNumSplines);				// allocate memory for spline data

		for (int i = 0; i < gNumSplines; i++)
		{
			gSplineList[i].numNubs = SwizzleShort(&splinePtr[i].numNubs);
			gSplineList[i].numPoints = SwizzleLong(&splinePtr[i].numPoints);
			gSplineList[i].numItems = SwizzleShort(&splinePtr[i].numItems);

			gSplineList[i].bBox.top = SwizzleShort(&splinePtr[i].bBox.top);
			gSplineList[i].bBox.bottom = SwizzleShort(&splinePtr[i].bBox.bottom);
			gSplineList[i].bBox.left = SwizzleShort(&splinePtr[i].bBox.left);
			gSplineList[i].bBox.right = SwizzleShort(&splinePtr[i].bBox.right);
		}

		ReleaseResource(hand);																// nuke the rez
	}
	else
	{
		gNumSplines = 0;
		gSplineList = nil;
	}




			/* READ SPLINE POINT LIST */

	for (int i = 0; i < gNumSplines; i++)
	{
		SplineDefType	*spline = &gSplineList[i];									// point to Nth spline

		hand = GetResource('SpPt',1000+i);											// read this point list
		if (hand)
		{
			SplinePointType	*ptList = (SplinePointType *)*hand;

			spline->pointList = AllocPtrClear(sizeof(SplinePointType) * spline->numPoints);	// alloc memory for point list

			for (int j = 0; j < spline->numPoints; j++)			// swizzle
			{
				spline->pointList[j].x = SwizzleFloat(&ptList[j].x);
				spline->pointList[j].z = SwizzleFloat(&ptList[j].z);
			}
			ReleaseResource(hand);																// nuke the rez
		}
		else
			DoFatalAlert("ReadDataFromPlayfieldFile: cant get spline points rez");
	}


			/* READ SPLINE ITEM LIST */

	for (int i = 0; i < gNumSplines; i++)
	{
		SplineDefType	*spline = &gSplineList[i];									// point to Nth spline

		hand = GetResource('SpIt',1000+i);
		if (hand)
		{
			GAME_ASSERT(GetHandleSize(hand) == (Size) (sizeof(SplineItemType) * spline->numItems));

			SplineItemType	*itemList = (SplineItemType *)*hand;

			spline->itemList = AllocPtrClear(sizeof(SplineItemType) * spline->numItems);	// alloc memory for item list

			for (int j = 0; j < spline->numItems; j++)			// swizzle
			{
				memcpy(spline->itemList[j].parm, itemList[j].parm, sizeof(itemList[j].parm));

				spline->itemList[j].placement = SwizzleFloat(&itemList[j].placement);
				spline->itemList[j].type	= SwizzleUShort(&itemList[j].type);
				spline->itemList[j].flags	= SwizzleUShort(&itemList[j].flags);
			}
			ReleaseResource(hand);																// nuke the rez
		}
		else
			DoFatalAlert("ReadDataFromPlayfieldFile: cant get spline items rez");
	}

			/****************************/
			/* FENCE RELATED RESOURCES */
			/****************************/

			/* READ FENCE LIST */

	hand = GetResource('Fenc',1000);
	if (hand)
	{
		FileFenceDefType *inData;

		gFenceList = (FenceDefType *) AllocPtrClear(sizeof(FenceDefType) * gNumFences);	// alloc new ptr for fence data
		if (gFenceList == nil)
			DoFatalAlert("ReadDataFromPlayfieldFile: AllocPtr failed");

		inData = (FileFenceDefType *)*hand;								// get ptr to input fence list

		for (int i = 0; i < gNumFences; i++)								// copy data from rez to new list
		{
			gFenceList[i].type 		= SwizzleUShort(&inData[i].type);
			gFenceList[i].numNubs 	= SwizzleShort(&inData[i].numNubs);
			gFenceList[i].nubList 	= nil;
			gFenceList[i].sectionVectors = nil;
		}
		ReleaseResource(hand);
	}
	else
		gNumFences = 0;


			/* READ FENCE NUB LIST */

	for (int i = 0; i < gNumFences; i++)
	{
		hand = GetResource('FnNb',1000+i);					// get rez
		HLock(hand);
		if (hand)
		{
   			FencePointType *fileFencePoints = (FencePointType *)*hand;

			gFenceList[i].nubList = (OGLPoint3D *) AllocPtrClear(sizeof(FenceDefType) * gFenceList[i].numNubs);	// alloc new ptr for nub array
			if (gFenceList[i].nubList == nil)
				DoFatalAlert("ReadDataFromPlayfieldFile: AllocPtr failed");



			for (int j = 0; j < gFenceList[i].numNubs; j++)		// convert x,z to x,y,z
			{
				gFenceList[i].nubList[j].x = SwizzleLong(&fileFencePoints[j].x);
				gFenceList[i].nubList[j].z = SwizzleLong(&fileFencePoints[j].z);
				gFenceList[i].nubList[j].y = 0;
			}
			ReleaseResource(hand);
		}
		else
			DoFatalAlert("ReadDataFromPlayfieldFile: cant get fence nub rez");
	}


			/****************************/
			/* WATER RELATED RESOURCES */
			/****************************/


			/* READ WATER LIST */

	hand = GetResource('Liqd',1000);
	if (hand)
	{
		DetachResource(hand);
		HLockHi(hand);
		gWaterListHandle = (WaterDefType **)hand;
		gWaterList = *gWaterListHandle;

		for (int i = 0; i < gNumWaterPatches; i++)						// swizzle
		{
			gWaterList[i].type = SwizzleUShort(&gWaterList[i].type);
			gWaterList[i].flags = SwizzleULong(&gWaterList[i].flags);
			gWaterList[i].height = SwizzleLong(&gWaterList[i].height);
			gWaterList[i].numNubs = SwizzleShort(&gWaterList[i].numNubs);

			gWaterList[i].hotSpotX = SwizzleFloat(&gWaterList[i].hotSpotX);
			gWaterList[i].hotSpotZ = SwizzleFloat(&gWaterList[i].hotSpotZ);

			gWaterList[i].bBox.top = SwizzleShort(&gWaterList[i].bBox.top);
			gWaterList[i].bBox.bottom = SwizzleShort(&gWaterList[i].bBox.bottom);
			gWaterList[i].bBox.left = SwizzleShort(&gWaterList[i].bBox.left);
			gWaterList[i].bBox.right = SwizzleShort(&gWaterList[i].bBox.right);

			for (int j = 0; j < gWaterList[i].numNubs; j++)
			{
				gWaterList[i].nubList[j].x = SwizzleFloat(&gWaterList[i].nubList[j].x);
				gWaterList[i].nubList[j].y = SwizzleFloat(&gWaterList[i].nubList[j].y);
			}
		}
	}
	else
		gNumWaterPatches = 0;


			/*************************/
			/* LINE MARKER RESOURCES */
			/*************************/

	if (gNumLineMarkers > 0)
	{
		if (gNumLineMarkers > MAX_LINEMARKERS)
			DoFatalAlert("ReadDataFromPlayfieldFile: gNumLineMarkers > MAX_LINEMARKERS");

				/* READ CHECKPOINT LIST */

		hand = GetResource('CkPt',1000);
		if (hand)
		{
			HLock(hand);
			BlockMove(*hand, &gLineMarkerList[0], GetHandleSize(hand));
			ReleaseResource(hand);

						/* CONVERT COORDINATES */

			for (int i = 0; i < gNumLineMarkers; i++)
			{
				LineMarkerDefType	*lm = &gLineMarkerList[i];

				lm->infoBits = SwizzleShort(&gLineMarkerList[i].infoBits);			// swizzle data
				lm->x[0] = SwizzleFloat(&lm->x[0]);
				lm->x[1] = SwizzleFloat(&lm->x[1]);
				lm->z[0] = SwizzleFloat(&lm->z[0]);
				lm->z[1] = SwizzleFloat(&lm->z[1]);

				gLineMarkerList[i].x[0] *= gMapToUnitValue;
				gLineMarkerList[i].z[0] *= gMapToUnitValue;
				gLineMarkerList[i].x[1] *= gMapToUnitValue;
				gLineMarkerList[i].z[1] *= gMapToUnitValue;
			}
		}
		else
			gNumLineMarkers = 0;
	}



			/* CLOSE REZ FILE */

	CloseResFile(fRefNum);



		/********************************************/
		/* READ SUPERTILE IMAGE DATA FROM DATA FORK */
		/********************************************/



				/* OPEN THE DATA FORK */

	iErr = FSpOpenDF(specPtr, fsRdPerm, &fRefNum);
	if (iErr)
		DoFatalAlert("ReadDataFromPlayfieldFile: FSpOpenDF failed!");


#if !(HQ_TERRAIN)

	for (int i = 0; i < gNumUniqueSuperTiles; i++)
	{
		Ptr superTilePixels = LoadSuperTilePixelBuffer(fRefNum);
		gSuperTileTextureObjects[i] = LoadSuperTileTexture(superTilePixels, SUPERTILE_TEXMAP_SIZE);

		SafeDisposePtr(superTilePixels);

			/* UPDATE LOADING THERMOMETER */

		DrawLoading(i / (float)gNumUniqueSuperTiles);
	}

#else

	GAME_ASSERT_MESSAGE(gSuperTilePixelBuffers == NULL, "gSuperTilePixelBuffers already allocated!");
	gSuperTilePixelBuffers = AllocPtrClear(sizeof(Ptr) * gNumUniqueSuperTiles);

	Ptr seamlessTextureCanvas = AllocPtrClear(4 * (SUPERTILE_TEXMAP_SIZE+2) * (SUPERTILE_TEXMAP_SIZE+2));

	for (int row = 0; row < gNumSuperTilesDeep + 4; row++)		// go 4 rows beyond terrain height so all 3 passes can run to completion
	{
		// We could do the three passes below separately, but weaving them in a single for loop
		// lets us keep memory pressure low while assembling the seamless textures.

		int rowPass1 = row;		// 1st pass: load JPEG images
		int rowPass2 = row - 2;	// 2nd pass: assemble seamless textures (2 rows behind, b/c need data from 1 row below + 1 column across)
		int rowPass3 = row - 4;	// 3rd pass: free up memory (4 rows behind)

		for (int col = 0; col < gNumSuperTilesWide; col++)
		{
			// 1st pass: load JPEG textures
			if (0 <= rowPass1 && rowPass1 < gNumSuperTilesDeep)
			{
				short stId = gSuperTileTextureGrid[rowPass1][col];
				if (stId >= 0)
				{
					gSuperTilePixelBuffers[stId] = LoadSuperTilePixelBuffer(fRefNum);

					// Update loading screen here
					DrawLoading(stId/(float)(gNumUniqueSuperTiles));
				}
			}

			// 2nd pass: assemble seamless textures
			if (0 <= rowPass2 && rowPass2 < gNumSuperTilesDeep)
			{
				short stId = gSuperTileTextureGrid[rowPass2][col];
				if (stId >= 0)
				{
					AssembleSeamlessSuperTileTexture(rowPass2, col, seamlessTextureCanvas);
					gSuperTileTextureObjects[stId] = LoadSuperTileTexture(seamlessTextureCanvas, 2+SUPERTILE_TEXMAP_SIZE);
				}
			}

			// 3rd pass: free up pixel buffers from rows that we won't need to look at again
			if (0 <= rowPass3 && rowPass3 < gNumSuperTilesDeep)
			{
				short stId = gSuperTileTextureGrid[rowPass3][col];
				if (stId >= 0)
				{
					SafeDisposePtr(gSuperTilePixelBuffers[stId]);
					gSuperTilePixelBuffers[stId] = NULL;
				}
			}
		}
	}

	SafeDisposePtr(seamlessTextureCanvas);
	seamlessTextureCanvas = NULL;

	// Check that we have all the textures we need and that we freed all temporary images
	for (int i = 0; i < gNumUniqueSuperTiles; i++)
	{
		GAME_ASSERT_MESSAGE(gSuperTileTextureObjects[i], "2nd pass incomplete: not all textures were loaded");
		GAME_ASSERT_MESSAGE(!gSuperTilePixelBuffers[i], "3rd pass incomplete: not all buffers were freed");
	}

	SafeDisposePtr(gSuperTilePixelBuffers);
	gSuperTilePixelBuffers = NULL;
#endif

	DrawLoading(1.0);


			/* CLOSE THE FILE */

	FSClose(fRefNum);
}


/********************* LOAD A SINGLE SUPERTILE TEXTURE *********************/

Ptr LoadSuperTilePixelBuffer(short fRefNum)
{
	int texSize = SUPERTILE_TEXMAP_SIZE;
	// if (gLowRam) texSize /= 4;

				/* READ THE SIZE OF THE NEXT COMPRESSED SUPERTILE TEXTURE */

	int32_t dataSize = 0;
	
	long size = sizeof(int32_t);
	OSErr iErr = FSRead(fRefNum, &size, (Ptr) &dataSize);
	GAME_ASSERT(!iErr);

	dataSize = SwizzleLong(&dataSize);

				/* ALLOCATE JPEG BUFFER */

	Ptr jpegBuffer = AllocPtrClear(dataSize);

				/* READ THE IMAGE DESC DATA + THE COMPRESSED IMAGE DATA */

	size = dataSize;
	iErr = FSRead(fRefNum, &size, jpegBuffer);
	GAME_ASSERT(!iErr);

				/* DECOMPRESS THE IMAGE */

	Ptr textureBuffer = DecompressQTImage(jpegBuffer, dataSize, texSize, texSize);

	SafeDisposePtr(jpegBuffer);
	jpegBuffer = NULL;

				/* FLIP IT VERTICALLY */
				//
				// Texture pixel rows are stored bottom-up in the .ter file.
				// We could just flip the V's, but it's easier to reason
				// about top-down images when we're stitching together the
				// seamless textures.
				//

	int rowBytes = texSize*4;
	Ptr topRowPixelsCopy = AllocPtrClear(rowBytes);

	int topRow = 0;
	int bottomRow = texSize-1;
	while (topRow < bottomRow)
	{
		Ptr topRowPixels = textureBuffer + topRow * rowBytes;
		Ptr bottomRowPixels = textureBuffer + bottomRow * rowBytes;

		memcpy(topRowPixelsCopy, topRowPixels, rowBytes);
		memcpy(topRowPixels, bottomRowPixels, rowBytes);
		memcpy(bottomRowPixels, topRowPixelsCopy, rowBytes);

		topRow++;
		bottomRow--;
	}

	SafeDisposePtr(topRowPixelsCopy);

	return textureBuffer;
}

static void Blit32(
		const char*			src,
		int					srcWidth,
		int					srcHeight,
		int					srcRectX,
		int					srcRectY,
		int					srcRectWidth,
		int					srcRectHeight,
		char*				dst,
		int 				dstWidth,
		int 				dstHeight,
		int					dstRectX,
		int					dstRectY
		)
{
	if (!src)
		return;

	const int bpp = 4;

	src += bpp * (srcRectX + srcWidth*srcRectY);
	dst += bpp * (dstRectX + dstWidth*dstRectY);

	for (int row = 0; row < srcRectHeight; row++)
	{
		memcpy(dst, src, bpp * srcRectWidth);
		src += bpp * srcWidth;
		dst += bpp * dstWidth;
	}
}

static Ptr GetSuperTileImage(int row, int col)
{
	if (row < 0 || row > gNumSuperTilesDeep-1		// row out of bounds
		|| col < 0 || col > gNumSuperTilesWide-1)	// column out of bounds
	{
		return NULL;
	}

	short superTileId = gSuperTileTextureGrid[row][col];

	if (superTileId < 0)							// blank texture
	{
		return NULL;
	}

	Ptr image = gSuperTilePixelBuffers[superTileId];
	GAME_ASSERT(image);

	return image;
}

void AssembleSeamlessSuperTileTexture(int row, int col, Ptr canvas)
{
	GAME_ASSERT(GetSuperTileImage(row, col));	// make sure we're not trying to do assemble a blank texture

	const int tw = SUPERTILE_TEXMAP_SIZE;		// supertile width & height
	const int th = SUPERTILE_TEXMAP_SIZE;
	const int cw = tw + 2;						// canvas width & height
	const int ch = th + 2;

	// Clear canvas to black
	memset(canvas, 0, cw * ch * 4);				// *4 => 32-bit RBGA

	// Blit supertile image to middle of canvas
	Blit32(GetSuperTileImage(row, col), tw, th, 0, 0, tw, th, canvas, cw, ch, 1, 1);

	// Stitch edges from neighboring supertiles on each side
	//     srcBuf                           sW  sH    sX    sY  rW  rH  dstBuf  dW  dH    dX    dY
	Blit32(GetSuperTileImage(row-1, col  ), tw, th,    0, th-1, tw,  1, canvas, cw, ch,    1,    0);
	Blit32(GetSuperTileImage(row+1, col  ), tw, th,    0,    0, tw,  1, canvas, cw, ch,    1, ch-1);
	Blit32(GetSuperTileImage(row  , col-1), tw, th, tw-1,    0,  1, th, canvas, cw, ch,    0,    1);
	Blit32(GetSuperTileImage(row  , col+1), tw, th,    0,    0,  1, th, canvas, cw, ch, cw-1,    1);

	// Copy 1px corners from diagonal neighbors
	//     srcBuf                           sW  sH    sX    sY  rW  rH  dstBuf  dW  dH    dX    dY
	Blit32(GetSuperTileImage(row-1, col+1), tw, th,    0, th-1,  1,  1, canvas, cw, ch, cw-1,    0);
	Blit32(GetSuperTileImage(row-1, col-1), tw, th, tw-1, th-1,  1,  1, canvas, cw, ch,    0,    0);
	Blit32(GetSuperTileImage(row+1, col-1), tw, th, tw-1,    0,  1,  1, canvas, cw, ch,    0, ch-1);
	Blit32(GetSuperTileImage(row+1, col+1), tw, th,    0,    0,  1,  1, canvas, cw, ch, cw-1, ch-1);
}


MOMaterialObject* LoadSuperTileTexture(Ptr textureBuffer, int texSize)
{
				/* LOAD GL TEXTURE */

	GLuint textureName = OGL_TextureMap_Load(textureBuffer, texSize, texSize, GL_RGBA, GL_RGBA, GL_UNSIGNED_BYTE);

				/**************************/
				/* CREATE MATERIAL OBJECT */
				/**************************/

	MOMaterialData matData =
	{
		.flags					= BG3D_MATERIALFLAG_CLAMP_U | BG3D_MATERIALFLAG_CLAMP_V | BG3D_MATERIALFLAG_TEXTURED,
		.multiTextureMode		= MULTI_TEXTURE_MODE_REFLECTIONSPHERE,
		.multiTextureCombine	= MULTI_TEXTURE_COMBINE_ADD,
		.diffuseColor			= {1,1,1,1},
		.numMipmaps				= 1,														// 1 texture
		.width					= texSize,
		.height					= texSize,
		.textureName			= {textureName},
	};

	return (MOMaterialObject*) MO_CreateNewObjectOfType(MO_TYPE_MATERIAL, 0, &matData);		// create the new object


#if 0
			/* PRE-LOAD */
			//
			// By drawing a phony triangle using this texture we can get it pre-loaded into VRAM.
			//

	SetInfobarSpriteState(0, 1);
	MO_DrawMaterial(superTileMaterialObject);
	glBegin(GL_TRIANGLES);
	glVertex3f(0,1,0);
	glVertex3f(0,0,0);
	glVertex3f(1,0,0);
	glEnd();
#endif
}


#pragma mark -


/***************************** SAVE GAME ********************************/
//
// Returns true if saving was successful
//

Boolean SaveGame(int fileSlot)
{
	char path[256];
	snprintf(path, sizeof(path), "File%c", 'A' + fileSlot);

			/* CREATE SAVE GAME DATA */

	SaveGameType saveData =
	{
		.timestamp		= time(NULL),
		.level			= gLevelNum,						// save @ beginning of next level
		.numLives 		= gPlayerInfo[0].numFreeLives,
		.health			= gPlayerInfo[0].health,
		.jetpackFuel	= gPlayerInfo[0].jetpackFuel,
		.shieldPower	= gPlayerInfo[0].shieldPower,
	};

	for (int i = 0; i < NUM_WEAPON_TYPES; i++)
		saveData.weaponQuantity[i]	= gPlayerInfo[0].weaponQuantity[i];

			/* SAVE IT TO DISK */


	return noErr == SaveUserDataFile(path, SAVEGAME_MAGIC, sizeof(SaveGameType), (Ptr) &saveData);
}


/***************************** LOAD SAVED GAME ********************************/

Boolean LoadSavedGame(int fileSlot, SaveGameType* outData)
{
	char path[256];
	snprintf(path, sizeof(path), "File%c", 'A' + fileSlot);

	SaveGameType scratch = {0};

	if (noErr != LoadUserDataFile(path, SAVEGAME_MAGIC, sizeof(SaveGameType), (Ptr) &scratch))
	{
		return false;
	}

	memcpy(outData, &scratch, sizeof(SaveGameType));
	return true;
}

/***************************** DELETE SAVED GAME ********************************/

Boolean DeleteSavedGame(int fileSlot)
{
	char path[32];
	snprintf(path, sizeof(path), "File%c", 'A' + fileSlot);

	OSErr iErr = DeleteUserDataFile(path);

	return iErr == noErr;
}

/********************** USE SAVED GAME DATA *****************************/

void UseSaveGame(const SaveGameType* saveData)
{
	gLevelNum						= saveData->level;
	gPlayerInfo[0].numFreeLives 	= saveData->numLives;
	gPlayerInfo[0].health			= saveData->health;
	gPlayerInfo[0].jetpackFuel		= saveData->jetpackFuel;
	gPlayerInfo[0].shieldPower		= saveData->shieldPower;

	for (int i = 0; i < NUM_WEAPON_TYPES; i++)
		gPlayerInfo[0].weaponQuantity[i] = saveData->weaponQuantity[i];
}



#pragma mark -

OSErr InitPrefsFolder(Boolean createIt)
{
	long createdDirID;

	OSErr iErr = FindFolder(kOnSystemDisk, kPreferencesFolderType, kDontCreateFolder,			// locate the folder
					  &gPrefsFolderVRefNum, &gPrefsFolderDirID);
	if (iErr != noErr)
		DoAlert("Warning: Cannot locate the Preferences folder.");

	if (createIt)
	{
		iErr = DirCreate(gPrefsFolderVRefNum, gPrefsFolderDirID, PREFS_FOLDER_NAME, &createdDirID);	// make folder in there
	}

	return iErr;
}

static OSErr MakeFSSpecForUserDataFile(const char* filename, FSSpec* spec)
{
	char path[256];
	snprintf(path, sizeof(path), ":%s:%s", PREFS_FOLDER_NAME, filename);

	return FSMakeFSSpec(gPrefsFolderVRefNum, gPrefsFolderDirID, path, spec);
}


/********* LOAD STRUCT FROM USER FILE IN PREFS FOLDER ***********/

OSErr LoadUserDataFile(const char* filename, const char* magic, long payloadLength, Ptr payloadPtr)
{
OSErr		iErr;
short		refNum;
FSSpec		file;
long		count;
long		eof = 0;
char		fileMagic[64];
long		magicLength = (long) strlen(magic) + 1;		// including null-terminator
Ptr			payloadCopy = NULL;

	GAME_ASSERT(magicLength < (long) sizeof(fileMagic));

				/* INIT PREFS FOLDER FSSPEC FIRST */

	InitPrefsFolder(false);


				/*************/
				/* READ FILE */
				/*************/

	MakeFSSpecForUserDataFile(filename, &file);
	iErr = FSpOpenDF(&file, fsRdPerm, &refNum);
	if (iErr)
		return iErr;

				/* CHECK FILE LENGTH */

	GetEOF(refNum, &eof);

	if (eof != magicLength + payloadLength)
	{
		goto fileIsCorrupt;
	}

				/* READ HEADER */

	count = magicLength;
	iErr = FSRead(refNum, &count, fileMagic);
	if (iErr ||
		count != magicLength ||
		0 != strncmp(magic, fileMagic, magicLength-1))
	{
		goto fileIsCorrupt;
	}

				/* READ PAYLOAD */

	payloadCopy = AllocPtrClear(payloadLength);

	count = payloadLength;
	iErr = FSRead(refNum, &count, payloadCopy);
	if (iErr || count != payloadLength)
	{
		goto fileIsCorrupt;
	}

				/* COMMIT PAYLOAD AND FINISH */

	BlockMove(payloadCopy, payloadPtr, payloadLength);
	iErr = noErr;
	goto cleanup;

fileIsCorrupt:
	printf("File '%s' appears to be corrupt!\n", file.cName);
	iErr = badFileFormat;
	goto cleanup;

cleanup:
	if (payloadCopy)
	{
		SafeDisposePtr(payloadCopy);
		payloadCopy = nil;
	}
	FSClose(refNum);
	return iErr;
}


/********* SAVE STRUCT TO USER FILE IN PREFS FOLDER ***********/

OSErr SaveUserDataFile(const char* filename, const char* magic, long payloadLength, Ptr payloadPtr)
{
FSSpec				file;
OSErr				iErr;
short				refNum;
long				count;

	InitPrefsFolder(true);

				/* CREATE BLANK FILE */

	MakeFSSpecForUserDataFile(filename, &file);
	FSpDelete(&file);															// delete any existing file
	iErr = FSpCreate(&file, kGameID, 'Pref', smSystemScript);					// create blank file
	if (iErr)
	{
		return iErr;
	}

				/* OPEN FILE */

	iErr = FSpOpenDF(&file, fsRdWrPerm, &refNum);
	if (iErr)
	{
		FSpDelete(&file);
		return iErr;
	}

				/* WRITE MAGIC */

	count = (long) strlen(magic) + 1;
	iErr = FSWrite(refNum, &count, (Ptr) magic);
	if (iErr)
	{
		FSClose(refNum);
		return iErr;
	}

				/* WRITE DATA */

	count = payloadLength;
	iErr = FSWrite(refNum, &count, payloadPtr);
	FSClose(refNum);

	printf("Wrote %s\n", file.cName);

	return iErr;
}

/********* DELETE USER FILE IN PREFS FOLDER ********************/

OSErr DeleteUserDataFile(const char* filename)
{
	FSSpec file;
	OSErr iErr;

	InitPrefsFolder(true);
	iErr = MakeFSSpecForUserDataFile(filename, &file);
	if (iErr == noErr)
		iErr = FSpDelete(&file);
	return iErr;
}

/*********************** LOAD DATA FILE INTO MEMORY ***********************************/
//
// Use SafeDisposePtr when done.
//

Ptr LoadDataFile(const char* path, long* outLength)
{
	FSSpec spec;
	OSErr err;
	short refNum;
	long fileLength = 0;
	long readBytes = 0;

	err = FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, path, &spec);
	if (err != noErr)
		return NULL;

	err = FSpOpenDF(&spec, fsRdPerm, &refNum);
	GAME_ASSERT_MESSAGE(!err, path);

	// Get number of bytes until EOF
	GetEOF(refNum, &fileLength);

	// Prep data buffer
	// Alloc 1 extra byte so LoadTextFile can return a null-terminated C string!
	Ptr data = AllocPtrClear(fileLength + 1);

	// Read file into data buffer
	readBytes = fileLength;
	err = FSRead(refNum, &readBytes, (Ptr) data);
	GAME_ASSERT_MESSAGE(err == noErr, path);
	FSClose(refNum);

	GAME_ASSERT_MESSAGE(fileLength == readBytes, path);

	if (outLength)
	{
		*outLength = fileLength;
	}

	return data;
}

/*********************** LOAD TEXT FILE INTO MEMORY ***********************************/
//
// Use SafeDisposePtr when done.
//

char* LoadTextFile(const char* spec, long* outLength)
{
	return LoadDataFile(spec, outLength);
}



#pragma mark -

/*********************** PARSE CSV *****************************/
//
// Call this function repeatedly to iterate over cells in a CSV table.
// THIS FUNCTION MODIFIES THE INPUT BUFFER!
//
// Sample usage:
//
//		char* csvText = LoadTextFile("hello.csv", NULL);
//		char* csvReader = csvText;
//		bool endOfLine = false;
//
//		while (csvReader != NULL)
//		{
//			char* column = CSVIterator(&csvReader, &endOfLine);
//			puts(column);
//		}
//
//		SafeDisposePtr(csvText);
//

char* CSVIterator(char** csvCursor, bool* eolOut)
{
	enum
	{
		kCSVState_Stop,
		kCSVState_WithinQuotedString,
		kCSVState_WithinUnquotedString,
		kCSVState_AwaitingSeparator,
	};

	const char SEPARATOR = ',';
	const char QUOTE_DELIMITER = '"';

	GAME_ASSERT(csvCursor);
	GAME_ASSERT(*csvCursor);

	const char* reader = *csvCursor;
	char* writer = *csvCursor;		// we'll write over the column as we read it
	char* columnStart = writer;
	bool eol = false;

	if (reader[0] == '\0')
	{
		reader = NULL;			// signify the parser should stop
		columnStart = NULL;		// signify nothing more to read
		eol = true;
	}
	else
	{
		int state;

		if (*reader == QUOTE_DELIMITER)
		{
			state = kCSVState_WithinQuotedString;
			reader++;
		}
		else
		{
			state = kCSVState_WithinUnquotedString;
		}

		while (*reader && state != kCSVState_Stop)
		{
			if (reader[0] == '\r' && reader[1] == '\n')
			{
				// windows CRLF -- skip the \r; we'll look at the \n later
				reader++;
				continue;
			}

			switch (state)
			{
				case kCSVState_WithinQuotedString:
					if (*reader == QUOTE_DELIMITER)
					{
						state = kCSVState_AwaitingSeparator;
					}
					else
					{
						*writer = *reader;
						writer++;
					}
					break;

				case kCSVState_WithinUnquotedString:
					if (*reader == SEPARATOR)
					{
						state = kCSVState_Stop;
					}
					else if (*reader == '\n')
					{
						eol = true;
						state = kCSVState_Stop;
					}
					else
					{
						*writer = *reader;
						writer++;
					}
					break;

				case kCSVState_AwaitingSeparator:
					if (*reader == SEPARATOR)
					{
						state = kCSVState_Stop;
					}
					else if (*reader == '\n')
					{
						eol = true;
						state = kCSVState_Stop;
					}
					else
					{
						GAME_ASSERT_MESSAGE(false, "unexpected token in CSV file");
					}
					break;
			}

			reader++;
		}
	}

	*writer = '\0';	// terminate string

	if (reader != NULL)
	{
		GAME_ASSERT_MESSAGE(reader >= writer, "writer went past reader!!!");
	}

	*csvCursor = (char*) reader;
	*eolOut = eol;
	return columnStart;
}

// Caller is responsible for freeing the pointer!
Ptr DecompressQTImage(const char* data, int dataSize, int w, int h)
{
	// The beginning of the buffer is an ImageDescription record.
	// The first int is an offset to the actual data.
	int offset = SwizzleLong((int32_t*) data);
	int payloadSize = dataSize - offset;
	const uint8_t* payload = (const uint8_t*) data + offset;

#if 0 && _DEBUG && !_WIN32
	{
		static int n = 0;
		char dumppath[256];
		snprintf(dumppath, sizeof(dumppath), "/tmp/nanosaur-%04d.jpg", n++);
		FILE* dump = fopen(dumppath, "wb");
		fwrite(payload, payloadSize, 1, dump);
		fclose(dump);
		puts(dumppath);
	}
#endif

	int actualW, actualH;
	uint8_t* pixelData = (uint8_t*) stbi_load_from_memory(payload, payloadSize, &actualW, &actualH, NULL, 4);
	GAME_ASSERT(pixelData);
	GAME_ASSERT(actualW == w);
	GAME_ASSERT(actualH == h);

	return (Ptr) pixelData;
}
