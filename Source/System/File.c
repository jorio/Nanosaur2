/****************************/
/*      FILE ROUTINES       */
/* By Brian Greenstone      */
/* (c)2003 Pangea Software  */
/* (c)2022 Iliyas Jorio     */
/****************************/


/***************/
/* EXTERNALS   */
/***************/

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

#define	BASE_PATH_TILE		900					// tile # of 1st path tile

#define	PICT_HEADER_SIZE	512

#define	SKELETON_FILE_VERS_NUM	0x0110			// v1.1

#define	SAVE_GAME_VERSION	0x0100		// 1.0

		/* SAVE GAME */

typedef struct
{
	uint32_t		version;
	short		level;
	short		numLives;
	float		health;
	float		jetpackFuel;
	float		shieldPower;
	short		weaponQuantity[NUM_WEAPON_TYPES];
}SaveGameType;


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
	u_short			type;				// type of fence
	short			numNubs;			// # nubs in fence
	int32_t			junk;			// handle to nub list
	Rect			bBox;				// bounding box of fence area
}FileFenceDefType;




/**********************/
/*     VARIABLES      */
/**********************/


float	g3DTileSize, g3DMinY, g3DMaxY;

static 	FSSpec		gSavedGameSpec;


/****************** SET DEFAULT DIRECTORY ********************/
//
// This function needs to be called for OS X because OS X doesnt automatically
// set the default directory to the application directory.
//

void SetDefaultDirectory(void)
{
OSErr	iErr;
#if 0
ProcessSerialNumber serial;
ProcessInfoRec info;
FSSpec	app_spec;
static WDPBRec wpb;

	serial.highLongOfPSN = 0;
	serial.lowLongOfPSN = kCurrentProcess;


	info.processInfoLength = sizeof(ProcessInfoRec);
	info.processName = NULL;
	info.processAppSpec = &app_spec;

	iErr = GetProcessInformation(&serial, &info);

	wpb.ioVRefNum = &app_spec.vRefNum;
	wpb.ioWDDirID = &app_spec.parID;
	wpb.ioNamePtr = NULL;

	iErr = PBHSetVolSync(&wpb);
#endif


		/* ALSO SET SAVED GAME SPEC TO DESKTOP */

	iErr = FindFolder(kOnSystemDisk,kDesktopFolderType,kDontCreateFolder,			// locate the desktop folder
					&gSavedGameSpec.vRefNum,&gSavedGameSpec.parID);
	gSavedGameSpec.cName[0] = 0;

}



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
FSSpec		fsSpec;
SkeletonDefType	*skeleton;
const char*	fileNames[MAX_SKELETON_TYPES] =
{
	":Skeletons:nano.skeleton",
	":Skeletons:wormhole.skeleton",
	":Skeletons:raptor.skeleton",
	":Skeletons:bonusworm.skeleton",
	":Skeletons:brach.skeleton",
	":Skeletons:worm.skeleton",
	":Skeletons:ramphor.skeleton",
};


	if (skeletonType < MAX_SKELETON_TYPES)
		FSMakeFSSpec(gDataSpec.vRefNum, gDataSpec.parID, fileNames[skeletonType], &fsSpec);
	else
		DoFatalAlert("LoadSkeleton: Unknown skeletonType!");


			/* OPEN THE FILE'S REZ FORK */

	fRefNum = FSpOpenResFile(&fsSpec,fsRdPerm);
	if (fRefNum == -1)
	{
		iErr = ResError();
		DoFatalAlert("Error opening Skel Rez file: Error %d", iErr);
	}

	UseResFile(fRefNum);
	if (ResError())
		DoFatalAlert("Error using Rez file! Error %d", ResError());


			/* ALLOC MEMORY FOR SKELETON INFO STRUCTURE */

	skeleton = (SkeletonDefType *)AllocPtr(sizeof(SkeletonDefType));
	if (skeleton == nil)
		DoFatalAlert("Cannot alloc SkeletonInfoType");


			/* READ SKELETON RESOURCES */

	ReadDataFromSkeletonFile(skeleton, &fsSpec, skeletonType);
	PrimeBoneData(skeleton);

			/* CLOSE REZ FILE */

	CloseResFile(fRefNum);

	return(skeleton);
}


/************* READ DATA FROM SKELETON FILE *******************/
//
// Current rez file is set to the file.
//

static void ReadDataFromSkeletonFile(SkeletonDefType *skeleton, FSSpec *fsSpec, int skeletonType)
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



		/***********************************/
		/*  READ BONE DEFINITION RESOURCES */
		/***********************************/

	for (i=0; i < numJoints; i++)
	{
		File_BoneDefinitionType	*bonePtr;
		u_short					*indexPtr;

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

		skeleton->Bones[i].pointList = (u_short *)AllocPtr(sizeof(u_short) * (int)skeleton->Bones[i].numPointsAttachedToBone);
		if (skeleton->Bones[i].pointList == nil)
			DoFatalAlert("ReadDataFromSkeletonFile: AllocPtr/pointList failed!");

		skeleton->Bones[i].normalList = (u_short *)AllocPtr(sizeof(u_short) * (int)skeleton->Bones[i].numNormalsAttachedToBone);
		if (skeleton->Bones[i].normalList == nil)
			DoFatalAlert("ReadDataFromSkeletonFile: AllocPtr/normalList failed!");

			/* READ POINT INDEX ARRAY */

		hand = GetResource('BonP',1000+i);
		if (hand == nil)
			DoFatalAlert("Error reading BonP resource!");
		HLock(hand);
		indexPtr = (u_short *)(*hand);

			/* COPY POINT INDEX ARRAY INTO BONE STRUCT */

		for (j=0; j < skeleton->Bones[i].numPointsAttachedToBone; j++)
			skeleton->Bones[i].pointList[j] = SwizzleUShort(&indexPtr[j]);
		ReleaseResource(hand);


			/* READ NORMAL INDEX ARRAY */

		hand = GetResource('BonN',1000+i);
		if (hand == nil)
			DoFatalAlert("Error reading BonN resource!");
		HLock(hand);
		indexPtr = (u_short *)(*hand);

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

	i = GetHandleSize(hand) / sizeof(OGLPoint3D);
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
//
// Load in standard preferences
//

OSErr LoadPrefs(PrefsType *prefBlock)
{
OSErr		iErr;
short		refNum;
FSSpec		file;
long		count;
Boolean		retry;

				/*************/
				/* READ FILE */
				/*************/

try_again:

	retry = false;

	FSMakeFSSpec(gPrefsFolderVRefNum, gPrefsFolderDirID, ":Nanosaur2:Preferences", &file);
	iErr = FSpOpenDF(&file, fsRdPerm, &refNum);
	if (iErr)
		return(iErr);

	count = sizeof(PrefsType);
	iErr = FSRead(refNum, &count,  (Ptr)prefBlock);		// read data from file
	if (iErr)
	{
		FSClose(refNum);
		return(iErr);
	}

	FSClose(refNum);

			/****************/
			/* VERIFY PREFS */
			/****************/

	if ((gGamePrefs.depth != 16) && (gGamePrefs.depth != 32))
		goto err;

	if (gGamePrefs.version != CURRENT_PREFS_VERS)
	{
		retry = true;
		goto err;
	}

		/* THEY'RE GOOD, SO ALSO RESTORE THE HID CONTROL SETTINGS */

	RestoreHIDControlSettings(&gGamePrefs.controlSettings);

	return(noErr);

err:
	InitDefaultPrefs();
	SavePrefs();

	if (retry)
		goto try_again;

	return(noErr);
}



/******************** SAVE PREFS **********************/

void SavePrefs(void)
{
FSSpec				file;
OSErr				iErr;
short				refNum;
long				count;

		/* GET THE CURRENT CONTROL SETTINGS */

	if (!gHIDInitialized)								// can't save prefs unless HID is initialized!
		return;

	SOFTIMPME;
//	BuildHIDControlSettings(&gGamePrefs.controlSettings);


				/* CREATE BLANK FILE */

	FSMakeFSSpec(gPrefsFolderVRefNum, gPrefsFolderDirID, ":Nanosaur2:Preferences", &file);
	FSpDelete(&file);															// delete any existing file
	iErr = FSpCreate(&file, kGameID, 'Pref', smSystemScript);					// create blank file
	if (iErr)
		return;

				/* OPEN FILE */

	iErr = FSpOpenDF(&file, fsRdWrPerm, &refNum);
	if (iErr)
	{
		FSpDelete(&file);
		return;
	}

				/* WRITE DATA */

	count = sizeof(PrefsType);
	FSWrite(refNum, &count, (Ptr) &gGamePrefs);
	FSClose(refNum);


}

#pragma mark -




/**************** DRAW PICTURE INTO GWORLD ***********************/
//
// Uses Quicktime to load any kind of picture format file and draws
// it into the GWorld
//
//
// INPUT: myFSSpec = spec of image file
//
// OUTPUT:	theGWorld = gworld contining the drawn image.
//

OSErr DrawPictureIntoGWorld(FSSpec *myFSSpec, GWorldPtr *theGWorld, short depth)
{
	SOFTIMPME;
	return unimpErr;
#if 0
OSErr						iErr;
GraphicsImportComponent		gi;
Rect						r;
ComponentResult				result;


			/* PREP IMPORTER COMPONENT */

	result = GetGraphicsImporterForFile(myFSSpec, &gi);		// load importer for this image file
	if (result != noErr)
	{
		DoAlert("DrawPictureIntoGWorld: GetGraphicsImporterForFile failed!  One of Quicktime's importer components is missing.  You should reinstall OS X to fix this.");
		return(result);
	}
	if (GraphicsImportGetBoundsRect(gi, &r) != noErr)		// get dimensions of image
		DoFatalAlert("DrawPictureIntoGWorld: GraphicsImportGetBoundsRect failed!");


			/* MAKE GWORLD */

	iErr = NewGWorld(theGWorld, depth, &r, nil, nil, 0);					// try app mem
	if (iErr)
	{
		DoAlert("DrawPictureIntoGWorld: using temp mem");
		iErr = NewGWorld(theGWorld, depth, &r, nil, nil, useTempMem);		// try sys mem
		if (iErr)
		{
			DoAlert("DrawPictureIntoGWorld: MakeMyGWorld failed");
			return(1);
		}
	}

//	if (depth == 32)
//	{
//		hPixMap = GetGWorldPixMap(*theGWorld);				// get gworld's pixmap
//		(**hPixMap).cmpCount = 4;							// we want full 4-component argb (defaults to only rgb)
//	}


			/* DRAW INTO THE GWORLD */

	DoLockPixels(*theGWorld);
	GraphicsImportSetGWorld(gi, *theGWorld, nil);			// set the gworld to draw image into
	GraphicsImportSetQuality(gi,codecLosslessQuality);		// set import quality

	result = GraphicsImportDraw(gi);						// draw into gworld
	CloseComponent(gi);										// cleanup
	if (result != noErr)
	{
		DoAlert("DrawPictureIntoGWorld: GraphicsImportDraw failed!");
		ShowSystemErr(result);
		DisposeGWorld (*theGWorld);
		*theGWorld= nil;
		return(result);
	}
	return(noErr);
#endif
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
int						row,col,j,i,texSize;
long					size;
float					yScale;
short					fRefNum;
OSErr					iErr;
Ptr						textureBuffer32 = nil;
Ptr						textureBuffer16 = nil;
GWorldPtr				buffGWorld = nil;
Rect					toRect, srcRect;

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

		for (row = 0; row < gNumSuperTilesDeep; row++)
			for (col = 0; col < gNumSuperTilesWide; col++)
			{
				gSuperTileTextureGrid[row][col] = SwizzleShort(src++);
			}
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
		for (row = 0; row <= gTerrainTileDepth; row++)
			for (col = 0; col <= gTerrainTileWidth; col++)
			{
				gMapYCoordsOriginal[row][col] = gMapYCoords[row][col] = SwizzleFloat(src++) * yScale;
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

		gMasterItemList = AllocPtr(sizeof(TerrainItemEntryType) * gNumTerrainItems);			// alloc array of items

		for (i = 0; i < gNumTerrainItems; i++)
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

		gSplineList = AllocPtr(sizeof(SplineDefType) * gNumSplines);				// allocate memory for spline data

		for (i = 0; i < gNumSplines; i++)
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

	for (i = 0; i < gNumSplines; i++)
	{
		SplineDefType	*spline = &gSplineList[i];									// point to Nth spline

		hand = GetResource('SpPt',1000+i);											// read this point list
		if (hand)
		{
			SplinePointType	*ptList = (SplinePointType *)*hand;

			spline->pointList = AllocPtr(sizeof(SplinePointType) * spline->numPoints);	// alloc memory for point list

			for (j = 0; j < spline->numPoints; j++)			// swizzle
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

	for (i = 0; i < gNumSplines; i++)
	{
		SplineDefType	*spline = &gSplineList[i];									// point to Nth spline

		hand = GetResource('SpIt',1000+i);
		if (hand)
		{
			SplineItemType	*itemList = (SplineItemType *)*hand;

			spline->itemList = AllocPtr(sizeof(SplineItemType) * spline->numItems);	// alloc memory for item list

			for (j = 0; j < spline->numItems; j++)			// swizzle
			{
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

		gFenceList = (FenceDefType *)AllocPtr(sizeof(FenceDefType) * gNumFences);	// alloc new ptr for fence data
		if (gFenceList == nil)
			DoFatalAlert("ReadDataFromPlayfieldFile: AllocPtr failed");

		inData = (FileFenceDefType *)*hand;								// get ptr to input fence list

		for (i = 0; i < gNumFences; i++)								// copy data from rez to new list
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

	for (i = 0; i < gNumFences; i++)
	{
		hand = GetResource('FnNb',1000+i);					// get rez
		HLock(hand);
		if (hand)
		{
   			FencePointType *fileFencePoints = (FencePointType *)*hand;

			gFenceList[i].nubList = (OGLPoint3D *)AllocPtr(sizeof(FenceDefType) * gFenceList[i].numNubs);	// alloc new ptr for nub array
			if (gFenceList[i].nubList == nil)
				DoFatalAlert("ReadDataFromPlayfieldFile: AllocPtr failed");



			for (j = 0; j < gFenceList[i].numNubs; j++)		// convert x,z to x,y,z
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

		for (i = 0; i < gNumWaterPatches; i++)						// swizzle
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

			for (j = 0; j < gWaterList[i].numNubs; j++)
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

			for (i = 0; i < gNumLineMarkers; i++)
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

				/* ALLOC BUFFERS */
//	if (gLowRAM)
//		texSize = SUPERTILE_TEXMAP_SIZE / 4;
//	else
	texSize = SUPERTILE_TEXMAP_SIZE;


	textureBuffer32 = AllocPtr(texSize * texSize * 4);		// alloc for 32bit pixels


				/* OPEN THE DATA FORK */

	iErr = FSpOpenDF(specPtr, fsRdPerm, &fRefNum);
	if (iErr)
		DoFatalAlert("ReadDataFromPlayfieldFile: FSpOpenDF failed!");


	for (i = 0; i < gNumUniqueSuperTiles; i++)
	{
		int32_t					dataSize;
		long					descSize;
		MOMaterialData			matData;
		Ptr						tempBuff, imageDataPtr;


				/* READ THE SIZE OF THE NEXT COMPRESSED SUPERTILE TEXTURE */

		size = sizeof(int32_t);
		iErr = FSRead(fRefNum, &size, (Ptr) &dataSize);
		if (iErr)
			DoFatalAlert("ReadDataFromPlayfieldFile: FSRead failed!");

		dataSize = SwizzleLong(&dataSize);

		tempBuff = AllocPtr(dataSize);


				/* READ THE IMAGE DESC DATA + THE COMPRESSED IMAGE DATA */

		size = dataSize;
		iErr = FSRead(fRefNum, &size, tempBuff);
		if (iErr)
			DoFatalAlert("ReadDataFromPlayfieldFile: FSRead failed!");


				/* DECOMPRESS THE IMAGE */

		DecompressQTImage(
				tempBuff,
				dataSize,
				textureBuffer32,
				texSize,
				texSize
		);
		SafeDisposePtr(tempBuff);													// free the temp buff
		tempBuff = nil;


//		SetAlphaInARGBBuffer(texSize, texSize, (uint32_t *)textureBuffer32);
//		SwizzleARGBtoBGRA(texSize,texSize, (uint32_t *)textureBuffer32);



				/**************************/
				/* CREATE MATERIAL OBJECT */
				/**************************/

		matData.pixelSrcFormat 	= GL_UNSIGNED_INT_8_8_8_8_REV;
		matData.pixelDstFormat 	= GL_RGBA8;
		matData.textureName[0] 	= OGL_TextureMap_Load(textureBuffer32, texSize, texSize,
												 GL_RGBA8, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, false);


		matData.setupInfo				= gGameViewInfoPtr;							// remember which draw context this material is assigned to
		matData.flags 					= 	BG3D_MATERIALFLAG_CLAMP_U|
											BG3D_MATERIALFLAG_CLAMP_V|
											BG3D_MATERIALFLAG_TEXTURED;

		matData.multiTextureMode		= MULTI_TEXTURE_MODE_REFLECTIONSPHERE;
		matData.multiTextureCombine		= MULTI_TEXTURE_COMBINE_ADD;
		matData.diffuseColor.r			= 1;
		matData.diffuseColor.g			= 1;
		matData.diffuseColor.b			= 1;
		matData.diffuseColor.a			= 1;
		matData.numMipmaps				= 1;										// 1 texture
		matData.width					= texSize;
		matData.height					= texSize;
		matData.texturePixels[0] 		= nil;										// the original pixels are gone (or will be soon)
		gSuperTileTextureObjects[i] 	= MO_CreateNewObjectOfType(MO_TYPE_MATERIAL, 0, &matData);		// create the new object


			/* PRE-LOAD */
			//
			// By drawing a phony triangle using this texture we can get it pre-loaded into VRAM.
			//

		SetInfobarSpriteState(0);
		MO_DrawMaterial(gSuperTileTextureObjects[i]);
		glBegin(GL_TRIANGLES);
		glVertex3f(0,1,0);
		glVertex3f(0,0,0);
		glVertex3f(1,0,0);
		glEnd();


			/* UPDATE LOADING THERMOMETER */

		if ((i & 0x3) == 0)
			DrawLoading((float)i / (float)(gNumUniqueSuperTiles));
	}

	DrawLoading(1.0);


			/* CLOSE THE FILE */

	FSClose(fRefNum);

	if (textureBuffer32)
		SafeDisposePtr(textureBuffer32);
}


#pragma mark -


#if 0
/******************** NAV SERVICES: GET DOCUMENT ***********************/

static OSErr GetFileWithNavServices(FSSpec *documentFSSpec)
{
NavDialogOptions 	dialogOptions;
AEDesc 				defaultLocation;
NavObjectFilterUPP filterProc 	= nil; //NewNavObjectFilterUPP(myFilterProc);
OSErr 				anErr 		= noErr;

			/* Specify default options for dialog box */

	anErr = NavGetDefaultDialogOptions(&dialogOptions);
	if (anErr == noErr)
	{
			/* Adjust the options to fit our needs */

		dialogOptions.dialogOptionFlags |= kNavSelectDefaultLocation;	// Set default location option
		dialogOptions.dialogOptionFlags ^= kNavAllowPreviews;			// Clear preview option
		dialogOptions.dialogOptionFlags ^= kNavAllowMultipleFiles;		// Clear multiple files option

		dialogOptions.location.h = dialogOptions.location.v = -1;		// use default position
		CopyPStr("Select A Saved Game File", dialogOptions.windowTitle);

				/* make descriptor for default location */

		anErr = AECreateDesc(typeFSS,&gSavedGameSpec, sizeof(FSSpec), &defaultLocation);
//		if (anErr ==noErr)
		{
			/* Get 'open'resource.  A nil handle being returned is OK, this simply means no automatic file filtering. */

			static NavTypeList	typeList = {kGameID, 0, 1, 'N2sv'};		// set types to filter
			NavTypeListPtr 		typeListPtr = &typeList;
			NavReplyRecord 		reply;


			/* Call NavGetFile() with specified options and declare our app-defined functions and type list */

			anErr = NavGetFile(&defaultLocation, &reply, &dialogOptions, nil, nil, filterProc, &typeListPtr,nil);
			if ((anErr == noErr) && (reply.validRecord))
			{
					/* Deal with multiple file selection */

				long 	count;

				anErr = AECountItems(&(reply.selection),&count);


					/* Set up index for file list */

				if (anErr == noErr)
				{
					long i;

					for (i = 1; i <= count; i++)
					{
						AEKeyword 	theKeyword;
						DescType 	actualType;
						Size 		actualSize;

						/* Get a pointer to selected file */

						anErr = AEGetNthPtr(&(reply.selection), i, typeFSS,&theKeyword, &actualType,
											documentFSSpec, sizeof(FSSpec), &actualSize);
					}
				}


				/* Dispose of NavReplyRecord,resources,descriptors */

				anErr = NavDisposeReply(&reply);
			}

			(void)AEDisposeDesc(&defaultLocation);
		}
	}


		/* CLEAN UP */

	if (filterProc)
	{
		DisposeNavObjectFilterUPP(filterProc);
		filterProc = nil;
	}

	return anErr;
}


/********************** PUT FILE WITH NAV SERVICES *************************/

static OSErr PutFileWithNavServices(NavReplyRecord *reply, FSSpec *outSpec)
{
OSErr 				anErr 			= noErr;
NavDialogOptions 	dialogOptions;
OSType 				fileTypeToSave 	='PSav';
OSType 				creatorType 	= kGameID;
const Str255		name = "Nanosaur 2 Saved Game";
AEDesc 				defaultLocation;

	anErr = NavGetDefaultDialogOptions(&dialogOptions);
	if (anErr == noErr)
	{
		CopyPStr(name, dialogOptions.savedFileName);					// set default name

		dialogOptions.location.h = dialogOptions.location.v = -1;		// use default position


				/* TRY TO CREATE DEFAULT LOCATION */

		AECreateDesc(typeFSS,&gSavedGameSpec, sizeof(gSavedGameSpec), &defaultLocation);

					/* PUT FILE */

		anErr = NavPutFile(&defaultLocation, reply, &dialogOptions, nil, fileTypeToSave, creatorType, nil);
		if ((anErr == noErr) && (reply->validRecord))
		{
			AEKeyword	theKeyword;
			DescType 	actualType;
			Size 		actualSize;

			anErr = AEGetNthPtr(&(reply->selection),1,typeFSS, &theKeyword,&actualType, outSpec, sizeof(FSSpec), &actualSize);
		}
	}

	return anErr;
}
#endif


#pragma mark -


/***************************** SAVE GAME ********************************/
//
// Returns true if saving was successful
//

Boolean SaveGame(void)
{
SaveGameType	saveData;
short			fRefNum;
FSSpec			*specPtr;
long			count, i;
Boolean			success = false;

	Enter2D();

			/*************************/
			/* CREATE SAVE GAME DATA */
			/*************************/
			//
			// Swizzle as we save so that we always save Big-Endian
			//

	saveData.version		= SAVE_GAME_VERSION;				// save file version #
	saveData.version = SwizzleULong(&saveData.version);

	saveData.level			= SwizzleShort(&gLevelNum);						// save @ beginning of next level
	saveData.numLives 		= SwizzleShort(&gPlayerInfo[0].numFreeLives);
	saveData.health			= SwizzleFloat(&gPlayerInfo[0].health);
	saveData.jetpackFuel	= SwizzleFloat(&gPlayerInfo[0].jetpackFuel);
	saveData.shieldPower	= SwizzleFloat(&gPlayerInfo[0].shieldPower);
	for (i = 0; i < NUM_WEAPON_TYPES; i++)
		saveData.weaponQuantity[i]	= SwizzleShort(&gPlayerInfo[0].weaponQuantity[i]);


		/*******************/
		/* DO NAV SERVICES */
		/*******************/

	IMPME;
#if 0
	if (PutFileWithNavServices(&navReply, &gSavedGameSpec))
		goto bail;
	specPtr = &gSavedGameSpec;
	if (navReply.replacing)										// see if delete old
		FSpDelete(specPtr);


				/* CREATE & OPEN THE REZ-FORK */

	if (FSpCreate(specPtr, kGameID,'N2sv',nil) != noErr)
	{
		DoAlert("Error creating Save file");
		goto bail;
	}

	FSpOpenDF(specPtr,fsRdWrPerm, &fRefNum);
	if (fRefNum == -1)
	{
		DoAlert("Error opening Save file");
		goto bail;
	}


				/* WRITE TO FILE */

	count = sizeof(SaveGameType);
	if (FSWrite(fRefNum, &count, (Ptr)&saveData) != noErr)
	{
		DoAlert("Error writing Save file");
		FSClose(fRefNum);
		goto bail;
	}

			/* CLOSE FILE */

	FSClose(fRefNum);


			/* CLEANUP NAV SERVICES */

	NavCompleteSave(&navReply, kNavTranslateInPlace);

	success = true;

bail:
	NavDisposeReply(&navReply);
	HideCursor();
	Exit2D();
#endif
	return(success);
}


/***************************** LOAD SAVED GAME ********************************/

Boolean LoadSavedGame(void)
{
SaveGameType	saveData;
short			fRefNum;
long			count, i;
Boolean			success = false;
//short			oldSong;

//	oldSong = gCurrentSong;							// turn off playing music to get around bug in OS X
//	KillSong();

	Enter2D();
	MyFlushEvents();


				/* GET FILE WITH NAVIGATION SERVICES */

	IMPME;
//	if (GetFileWithNavServices(&gSavedGameSpec) != noErr)
//		goto bail;


				/* OPEN THE REZ-FORK */

	FSpOpenDF(&gSavedGameSpec,fsRdPerm, &fRefNum);
	if (fRefNum == -1)
	{
		DoAlert("Error opening Save file");
		goto bail;
	}

				/* READ FROM FILE */

	count = sizeof(SaveGameType);
	if (FSRead(fRefNum, &count, (Ptr) &saveData) != noErr)
	{
		DoAlert("Error reading Save file");
		FSClose(fRefNum);
		goto bail;
	}

			/* CLOSE FILE */

	FSClose(fRefNum);


			/**********************/
			/* USE SAVE GAME DATA */
			/**********************/

	gLevelNum						= SwizzleShort(&saveData.level);
	gPlayerInfo[0].numFreeLives 	= SwizzleShort(&saveData.numLives);
	gPlayerInfo[0].health			= SwizzleFloat(&saveData.health);
	gPlayerInfo[0].jetpackFuel		= SwizzleFloat(&saveData.jetpackFuel);
	gPlayerInfo[0].shieldPower		= SwizzleFloat(&saveData.shieldPower);

	for (i = 0; i < NUM_WEAPON_TYPES; i++)
		gPlayerInfo[0].weaponQuantity[i] = SwizzleShort(&saveData.weaponQuantity[i]);


	success = true;


bail:
	Exit2D();
	HideCursor();

//	if (!success)								// user cancelled, so start song again before returning
//		PlaySong(oldSong, true);

	return(success);
}



#pragma mark -


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
	GAME_ASSERT_MESSAGE(!err, path);

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



void DecompressQTImage(
		const char* data,
		int dataSize,
		char* outputBuffer,
		int w,
		int h)
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

	uint8_t* out = (uint8_t*) outputBuffer;
	for (int p = 0; p < 4*w*h; p += 4)
	{
		uint8_t r = pixelData[p+0];
		uint8_t g = pixelData[p+1];
		uint8_t b = pixelData[p+2];
		uint8_t a = pixelData[p+3];
		out[p+0] = b;
		out[p+1] = g;
		out[p+2] = r;
		out[p+3] = a;
	}

	free(pixelData);
	pixelData = NULL;
}
