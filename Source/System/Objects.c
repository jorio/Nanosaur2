/*********************************/
/*    OBJECT MANAGER 		     */
/* (c)2003 Pangea Software  	 */
/* By Brian Greenstone      	 */
/*********************************/


/***************/
/* EXTERNALS   */
/***************/

#include "game.h"


/****************************/
/*    PROTOTYPES            */
/****************************/

static void FlushObjectDeleteQueue(void);
static void DrawCollisionBoxes(ObjNode *theNode, Boolean old);
static void DrawBoundingBoxes(ObjNode *theNode);
static void DrawBoundingSpheres(ObjNode *theNode);
static void CreateDummyInitObject(void);


/****************************/
/*    CONSTANTS             */
/****************************/

#define	OBJ_DEL_Q_SIZE	1500

#define MAX_OBJECTS		5000

/**********************/
/*     VARIABLES      */
/**********************/

static ObjNode		gObjectList[MAX_OBJECTS];

ObjNode		*gFirstNodePtr = nil;

ObjNode		*gCurrentNode,*gMostRecentlyAddedNode,*gNextNode;


OGLPoint3D	gCoord;
OGLVector3D	gDelta;

long		gNumObjsInDeleteQueue = 0;
ObjNode		*gObjectDeleteQueue[OBJ_DEL_Q_SIZE];

float		gAutoFadeStartDist,gAutoFadeEndDist,gAutoFadeRange_Frac;

int			gNumObjectNodes;
int			gNumObjectNodesPeak = 0;

static  ObjNode *gClearedObj;

//============================================================================================================
//============================================================================================================
//============================================================================================================

#pragma mark ----- OBJECT CREATION ------

/************************ INIT OBJECT MANAGER **********************/

void InitObjectManager(void)
{
int		i;


			/* MARK ALL OBJECTS AS NOT USED */

	for (i = 0; i < MAX_OBJECTS; i++)
	{
		gObjectList[i].isUsed = false;
	}


	CreateDummyInitObject();



				/* INIT LINKED LIST */


	gCurrentNode = nil;

					/* CLEAR ENTIRE OBJECT LIST */

	gFirstNodePtr = nil;									// no node yet

	gNumObjectNodes = 0;
}


/******************** CREATE DUMMY INIT OBJECT **********************/
//
// We make a dummy ObjNode which is initialized to the default settings
// so that we can quickly initialize new ObjNode's simply by BlockMoving
// this dummy node into them.
//

static void CreateDummyInitObject(void)
{
int   i;

	gClearedObj = AllocPtrClear(sizeof(ObjNode));		// make a dummy objNode which is cleared to 0's

	for (i = 0; i < MAX_NODE_SPARKLES; i++)								// no sparkles
		gClearedObj->Sparkles[i] = -1;

	gClearedObj->LocalBBox.isEmpty =
	gClearedObj->WorldBBox.isEmpty = true;

	gClearedObj->BoundingSphereRadius = 100;

	gClearedObj->VertexArrayMode = VERTEX_ARRAY_RANGE_TYPE_BG3DMODELS;		// assume this object's vertex data is in the cached/static mode

	gClearedObj->EffectChannel = -1;						// no streaming sound effect
	gClearedObj->ParticleGroup = -1;						// no particle group

	for (i = 0; i < MAX_CONTRAILS_PER_OBJNODE; i++)			// no contrails
		gClearedObj->ContrailSlot[i] = -1;

	gClearedObj->SplineObjectIndex = -1;					// no index yet

	gClearedObj->ColorFilter.r =
	gClearedObj->ColorFilter.g =
	gClearedObj->ColorFilter.b =
	gClearedObj->ColorFilter.a = 1.0;
}



/*********************** MAKE NEW OBJECT ******************/
//
// MAKE NEW OBJECT & RETURN PTR TO IT
//
// The linked list is sorted from smallest to largest!
//

ObjNode	*MakeNewObject(NewObjectDefinitionType *newObjDef)
{
ObjNode	*newNodePtr;
long	slot,i;
uint32_t flags = newObjDef->flags;

#if _DEBUG
	if (newObjDef->scale == 0)
		DoAlert("newObjDef->scale == 0, are you sure?");
#endif

			/************************/
			/* FIND NEW FREE OBJECT */
			/************************/
			//
			// For speed, we try to find a free object in our big object array.
			// But if nothing is free then we malloc one as a last resort to keep
			// the game from just crashing.
			//

	for (i = 0; i < MAX_OBJECTS; i++)
	{
		if (!gObjectList[i].isUsed)
		{
			newNodePtr = &gObjectList[i];					// point to object from list
			goto got_it;
		}
	}

			/* NOTHING AVAILBLE IN LIST, SO MALLOC A NEW ONE */

	newNodePtr = (ObjNode *) AllocPtrClear(sizeof(ObjNode));
	i = -1;

got_it:

			/********************************/
			/* CLEAR THE OBJNODE & SET DATA */
			/********************************/

	*newNodePtr = *gClearedObj;								// copy the cleared/initied obj into here

	newNodePtr->objectNum = i;								// not from gObjectList array
	newNodePtr->isUsed = true;


	newNodePtr->Cookie	= MyRandomLong();							// give each object a unique cookie


			/* INITIALIZE ALL OF THE FIELDS */

	slot = newObjDef->slot;

	newNodePtr->Slot 		= slot;
	newNodePtr->Type 		= newObjDef->type;
	newNodePtr->Group 		= newObjDef->group;
	newNodePtr->MoveCall 	= newObjDef->moveCall;
	newNodePtr->CustomDrawFunction = newObjDef->drawCall;

	if (flags & STATUS_BIT_ONSPLINE)
		newNodePtr->SplineMoveCall = newObjDef->moveCall;				// save spline move routine

	newNodePtr->Genre = newObjDef->genre;
	newNodePtr->Coord = newNodePtr->InitCoord = newNodePtr->OldCoord = newObjDef->coord;		// save coords

	newNodePtr->GridX = (int)newNodePtr->Coord.x / GRID_SIZE;			// set initial grid position
	newNodePtr->GridY = (int)newNodePtr->Coord.y / GRID_SIZE;
	newNodePtr->GridZ = (int)newNodePtr->Coord.z / GRID_SIZE;

	newNodePtr->StatusBits = flags;

	newNodePtr->Rot.y =  newObjDef->rot;
	newNodePtr->Scale.x =
	newNodePtr->Scale.y =
	newNodePtr->Scale.z = newObjDef->scale;


			/* MAKE SURE SCALE != 0 */

	if (newNodePtr->Scale.x == 0.0f)
		newNodePtr->Scale.x = 0.0001f;
	if (newNodePtr->Scale.y == 0.0f)
		newNodePtr->Scale.y = 0.0001f;
	if (newNodePtr->Scale.z == 0.0f)
		newNodePtr->Scale.z = 0.0001f;



				/* INSERT NODE INTO LINKED LIST */

	newNodePtr->StatusBits |= STATUS_BIT_DETACHED;		// its not attached to linked list yet
	AttachObject(newNodePtr, false);

	gNumObjectNodes++;

	if (gNumObjectNodes > gNumObjectNodesPeak)
	{
		gNumObjectNodesPeak = gNumObjectNodes;
#if _DEBUG
		if (gNumObjectNodesPeak > MAX_OBJECTS)
		{
			SDL_Log("[%d] WARNING: New object count peak: %d. Consider raising MAX_OBJECTS!", gGameFrameNum, gNumObjectNodesPeak);
		}
#endif
	}


				/* CLEANUP */

	gMostRecentlyAddedNode = newNodePtr;					// remember this
	return(newNodePtr);
}

/************* MAKE NEW DISPLAY GROUP OBJECT *************/
//
// This is an ObjNode who's BaseGroup is a group, therefore these objects
// can be transformed (scale,rot,trans).
//

ObjNode *MakeNewDisplayGroupObject(NewObjectDefinitionType *newObjDef)
{
ObjNode	*newObj;
Byte	group,type;


	newObjDef->genre = DISPLAY_GROUP_GENRE;

	newObj = MakeNewObject(newObjDef);
	if (newObj == nil)
		DoFatalAlert("MakeNewDisplayGroupObject: MakeNewObject failed!");

			/* MAKE BASE GROUP & ADD GEOMETRY TO IT */

	CreateBaseGroup(newObj);											// create group object
	group = newObjDef->group;											// get group #
	type = newObjDef->type;												// get type #

	if (type >= gNumObjectsInBG3DGroupList[group])							// see if illegal
	{
		DoFatalAlert("MakeNewDisplayGroupObject: type > gNumObjectsInGroupList[]! group=%d type=%d", group, type);
	}

	AttachGeometryToDisplayGroupObject(newObj,gBG3DGroupList[group][type]);


			/* SET BOUNDING BOX & SPHERE */

	newObj->LocalBBox = gObjectGroupBBoxList[group][type];	// get this model's local bounding box

	newObj->BoundingSphereRadius = gObjectGroupBSphereList[newObj->Group][newObj->Type] * newObj->Scale.x;


	return(newObj);
}


/******************** CALC OBJECT RADIUS FROM BBOX ***********************/

void CalcObjectRadiusFromBBox(ObjNode *theNode)
{
float	max,n;

	max = fabs(theNode->LocalBBox.max.x);							// get radius to right
	n = fabs(theNode->LocalBBox.min.x);								// get radius to left
	if (n > max)
		max = n;

	n = fabs(theNode->LocalBBox.min.z);			// get radius to back
	if (n > max)
		max = n;
	n = fabs(theNode->LocalBBox.max.z);			// get radius to front
	if (n > max)
		max = n;

	n = fabs(theNode->LocalBBox.min.y);			// get radius to bottom
	if (n > max)
		max = n;
	n = fabs(theNode->LocalBBox.max.y);			// get radius to top
	if (n > max)
		max = n;

	max *= 1.41f;			// multiply by sqrt(2) to expand radius to include worst-case corners
							// be better way to do this would have been to just calculate the max vertex distance, but that's slower to do real-time

	if (theNode->Genre == DISPLAY_GROUP_GENRE)
		max *= theNode->Scale.x;				// scale to object's scale (skeleton's are already scaled)

	theNode->BoundingSphereRadius = max;
}


/******************* RESET DISPLAY GROUP OBJECT *********************/
//
// If the ObjNode's "Type" field has changed, call this to dispose of
// the old BaseGroup and create a new one with the correct model attached.
//

void ResetDisplayGroupObject(ObjNode *theNode)
{
short	i;

	DisposeObjectBaseGroup(theNode);									// dispose of old group
	CreateBaseGroup(theNode);											// create new group object

	if (theNode->Type >= gNumObjectsInBG3DGroupList[theNode->Group])							// see if illegal
		DoFatalAlert("ResetDisplayGroupObject: type > gNumObjectsInGroupList[]!");

	AttachGeometryToDisplayGroupObject(theNode,gBG3DGroupList[theNode->Group][theNode->Type]);	// attach geometry to group

			/* SET BOUNDING BOX */

	theNode->LocalBBox = gObjectGroupBBoxList[theNode->Group][theNode->Type];


			/* IF HAD WORLD DATA, NUKE IT */

	for (i = 0; i < MAX_MESHES_IN_MODEL; i++)		// delete the arrays since the sizes may have changed with new object
	{
		if (theNode->WorldMeshes[i].points)
		{
			SafeDisposePtr(theNode->WorldMeshes[i].points);
			theNode->WorldMeshes[i].points = nil;
		}

		if (theNode->WorldPlaneEQs[i])
		{
			SafeDisposePtr(theNode->WorldPlaneEQs[i]);
			theNode->WorldPlaneEQs[i] = nil;
		}
	}
	theNode->HasWorldPoints = false;
}



/************************* ADD GEOMETRY TO DISPLAY GROUP OBJECT ***********************/
//
// Attaches a geometry object to the BaseGroup object. MakeNewDisplayGroupObject must have already been
// called which made the group & transforms.
//

void AttachGeometryToDisplayGroupObject(ObjNode *theNode, MetaObjectPtr geometry)
{
	MO_AppendToGroup(theNode->BaseGroup, geometry);
}



/***************** CREATE BASE GROUP **********************/
//
// The base group contains the base transform matrix plus any other objects you want to add into it.
// This routine creates the new group and then adds a transform matrix.
//
// The base is composed of BaseGroup & BaseTransformObject.
//

void CreateBaseGroup(ObjNode *theNode)
{
OGLMatrix4x4			transMatrix,scaleMatrix,rotMatrix;
MOMatrixObject			*transObject;


				/* CREATE THE BASE GROUP OBJECT */

	theNode->BaseGroup = MO_CreateNewObjectOfType(MO_TYPE_GROUP, 0, nil);
	if (theNode->BaseGroup == nil)
		DoFatalAlert("CreateBaseGroup: MO_CreateNewObjectOfType failed!");


					/* SETUP BASE MATRIX */

	if ((theNode->Scale.x == 0) || (theNode->Scale.y == 0) || (theNode->Scale.z == 0))
		DoFatalAlert("CreateBaseGroup: A scale component == 0");


	OGLMatrix4x4_SetScale(&scaleMatrix, theNode->Scale.x, theNode->Scale.y,		// make scale matrix
							theNode->Scale.z);

	OGLMatrix4x4_SetRotate_XYZ(&rotMatrix, theNode->Rot.x, theNode->Rot.y,		// make rotation matrix
								 theNode->Rot.z);

	OGLMatrix4x4_SetTranslate(&transMatrix, theNode->Coord.x, theNode->Coord.y,	// make translate matrix
							 theNode->Coord.z);

	OGLMatrix4x4_Multiply(&scaleMatrix,											// mult scale & rot matrices
						 &rotMatrix,
						 &theNode->BaseTransformMatrix);

	OGLMatrix4x4_Multiply(&theNode->BaseTransformMatrix,						// mult by trans matrix
						 &transMatrix,
						 &theNode->BaseTransformMatrix);


					/* CREATE A MATRIX XFORM */

	transObject = MO_CreateNewObjectOfType(MO_TYPE_MATRIX, 0, &theNode->BaseTransformMatrix);	// make matrix xform object
	if (transObject == nil)
		DoFatalAlert("CreateBaseGroup: MO_CreateNewObjectOfType/Matrix Failed!");

	MO_AttachToGroupStart(theNode->BaseGroup, transObject);						// add to base group
	theNode->BaseTransformObject = transObject;									// keep extra LEGAL ref (remember to dispose later)
}



//============================================================================================================
//============================================================================================================
//============================================================================================================

#pragma mark ----- OBJECT PROCESSING ------


/*******************************  MOVE OBJECTS **************************/

void MoveObjects(void)
{
ObjNode		*thisNodePtr;

	if (gFirstNodePtr == nil)								// see if there are any objects
		return;

	thisNodePtr = gFirstNodePtr;

	do
	{
				/* VERIFY NODE */

		if (thisNodePtr->CType == INVALID_NODE_FLAG)
			DoFatalAlert("MoveObjects: CType == INVALID_NODE_FLAG");

		gCurrentNode = thisNodePtr;							// set current object node
		gNextNode	 = thisNodePtr->NextNode;				// get next node now (cuz current node might get deleted)


				/* SEE IF SHOULD SKIP WHEN PAUSED */

		if (gGamePaused && !(thisNodePtr->StatusBits & STATUS_BIT_MOVEINPAUSE))
			goto next;


				/* UPDATE SKELETON ANIMATION */

		if (thisNodePtr->Skeleton)
			UpdateSkeletonAnimation(thisNodePtr);


					/* NEXT TRY TO MOVE IT */

		if (!(thisNodePtr->StatusBits & STATUS_BIT_ONSPLINE))		// make sure don't call a move call if on spline
		{
			if ((!(thisNodePtr->StatusBits & STATUS_BIT_NOMOVE)) &&	(thisNodePtr->MoveCall != nil))
			{
				KeepOldCollisionBoxes(thisNodePtr);					// keep old boxes & other stuff
				thisNodePtr->MoveCall(thisNodePtr);				// call object's move routine
			}
		}


				/* UPDATE SKELETON'S MESH */

		if (thisNodePtr->CType != INVALID_NODE_FLAG)
			if (thisNodePtr->Skeleton)
				UpdateSkinnedGeometry(thisNodePtr);

next:
		thisNodePtr = gNextNode;							// next node
	}
	while (thisNodePtr != nil);



			/* FLUSH THE DELETE QUEUE */

	FlushObjectDeleteQueue();
}



/**************************** DRAW OBJECTS ***************************/

void DrawObjects(void)
{
ObjNode		*theNode;
unsigned long	statusBits;
Boolean			noLighting = false;
Boolean			noZBuffer = false;
Boolean			noZWrites = false;
Boolean			texWrap = false;
Boolean			clipAlpha= false;
float			cameraX, cameraZ;
Byte			playerNum = gCurrentSplitScreenPane;			// get the player # who's draw context is being drawn


	if (gFirstNodePtr == nil)									// see if there are any objects
		return;


				/* FIRST DO OUR CULLING */

	CullTestAllObjects();

	theNode = gFirstNodePtr;


			/* GET CAMERA COORDS */

	cameraX = gGameViewInfoPtr->cameraPlacement[gCurrentSplitScreenPane].cameraLocation.x;
	cameraZ = gGameViewInfoPtr->cameraPlacement[gCurrentSplitScreenPane].cameraLocation.z;


	bool isOverlayPane = gCurrentSplitScreenPane == GetOverlayPaneNumber();

			/***********************/
			/* MAIN NODE TASK LOOP */
			/***********************/
	do
	{
		statusBits = theNode->StatusBits;						// get obj's status bits

		if (statusBits & ((STATUS_BIT_ISCULLED1 << gCurrentSplitScreenPane) | STATUS_BIT_HIDDEN))	// see if is culled or hidden
			goto next;

		if (statusBits & STATUS_BIT_ONLYSHOWTHISPLAYER)			// see if only show for current player's draw context
		{
			if (theNode->PlayerNum != playerNum)
				goto next;
		}
		else
		if (isOverlayPane)										// if drawing overlay pane, only look at nodes explicitly setting STATUS_BIT_ONLYSHOWTHISPLAYER
		{
			goto next;
		}



		if (theNode->CType == INVALID_NODE_FLAG)				// see if already deleted
			goto next;

		gGlobalTransparency = theNode->ColorFilter.a;			// get global transparency
		if (gGlobalTransparency <= 0.0f)						// see if invisible
			goto next;

		gGlobalColorFilter.r = theNode->ColorFilter.r;			// set color filter
		gGlobalColorFilter.g = theNode->ColorFilter.g;
		gGlobalColorFilter.b = theNode->ColorFilter.b;


			/******************/
			/* CHECK AUTOFADE */
			/******************/

		if (gAutoFadeStartDist != 0.0f)							// see if this level has autofade
		{
			if (statusBits & STATUS_BIT_AUTOFADE)
			{
				float		dist;

				dist = CalcQuickDistance(cameraX, cameraZ, theNode->Coord.x, theNode->Coord.z);			// see if in fade zone

				if (theNode->Skeleton == nil)														// if not a skeleton object...
				{
					if (!theNode->LocalBBox.isEmpty)
						dist += (theNode->LocalBBox.max.x - theNode->LocalBBox.min.x) * .2f;		// adjust dist based on size of object in order to fade big objects closer
				}

				if (dist >= gAutoFadeStartDist)
				{
					dist -= gAutoFadeStartDist;							// calc xparency %
					dist *= gAutoFadeRange_Frac;
					if (dist < 0.0f)
						goto next;

					gGlobalTransparency -= dist;
					if (gGlobalTransparency <= 0.0f)
					{
						theNode->StatusBits |= (STATUS_BIT_ISCULLED1 << gCurrentSplitScreenPane);		// set culled flag so that any related Sparkles wont be drawn either
						goto next;
					}
				}
			}
		}


			/*******************/
			/* CHECK BACKFACES */
			/*******************/

		if (statusBits & STATUS_BIT_DOUBLESIDED)
			OGL_DisableCullFace();
		else
			OGL_EnableCullFace();


			/*********************/
			/* CHECK NULL SHADER */
			/*********************/

		if (statusBits & STATUS_BIT_NOLIGHTING)
		{
			if (!noLighting)
			{
				OGL_DisableLighting();
				noLighting = true;
			}
		}
		else
		if (noLighting)
		{
			noLighting = false;
			OGL_EnableLighting();
		}

 			/****************/
			/* CHECK NO FOG */
			/****************/

		if (gGameViewInfoPtr->useFog)
		{
			if (statusBits & STATUS_BIT_NOFOG)
				OGL_DisableFog();
			else
				OGL_EnableFog();
		}

			/********************/
			/* CHECK GLOW BLEND */
			/********************/

		if (statusBits & STATUS_BIT_GLOW)
		{
			gGlobalMaterialFlags |= BG3D_MATERIALFLAG_ALWAYSBLEND;			// this will make sure blending is on for the glow
			OGL_BlendFunc(GL_SRC_ALPHA, GL_ONE);
		}
		else
		{
			gGlobalMaterialFlags &= ~BG3D_MATERIALFLAG_ALWAYSBLEND;
		    OGL_BlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		}

			/**********************/
			/* CHECK TEXTURE WRAP */
			/**********************/

		if (statusBits & STATUS_BIT_NOTEXTUREWRAP)
		{
			if (!texWrap)
			{
				gGlobalMaterialFlags |= BG3D_MATERIALFLAG_CLAMP_U|BG3D_MATERIALFLAG_CLAMP_V;
				texWrap = true;
			}
		}
		else
		if (texWrap)
		{
			texWrap = false;
		    gGlobalMaterialFlags &= ~(BG3D_MATERIALFLAG_CLAMP_U|BG3D_MATERIALFLAG_CLAMP_V);
		}




			/****************/
			/* CHECK ZWRITE */
			/****************/

		if (statusBits & STATUS_BIT_NOZWRITES)
		{
			if (!noZWrites)
			{
				glDepthMask(GL_FALSE);
				noZWrites = true;
			}
		}
		else
		if (noZWrites)
		{
			glDepthMask(GL_TRUE);
			noZWrites = false;
		}


			/*****************/
			/* CHECK ZBUFFER */
			/*****************/

		if (statusBits & STATUS_BIT_NOZBUFFER)
		{
			if (!noZBuffer)
			{
				glDisable(GL_DEPTH_TEST);
				noZBuffer = true;
			}
		}
		else
		if (noZBuffer)
		{
			noZBuffer = false;
			glEnable(GL_DEPTH_TEST);
		}


			/*****************************/
			/* CHECK EDGE ALPHA CLIPPING */
			/*****************************/

		if ((statusBits & STATUS_BIT_CLIPALPHA6) && (gGlobalTransparency == 1.0f))
		{
			if (!clipAlpha)
			{
//				glAlphaFunc(GL_EQUAL, 1);	// draw any pixel who's Alpha == 1, skip semi-transparent pixels
				glAlphaFunc(GL_GREATER, .6);	// draw any pixel who's Alpha > .6 (effectivly trims low alpha pixels).
				clipAlpha = true;
//				glEnable(GL_ALPHA_TEST);	//--------
			}
		}
		else
		if (clipAlpha)
		{
			clipAlpha = false;
			glAlphaFunc(GL_NOTEQUAL, 0);	// draw any pixel who's Alpha != 0

//			glDisable(GL_ALPHA_TEST);	//--------
		}


			/* AIM AT CAMERA */

		if (statusBits & STATUS_BIT_AIMATCAMERA)
		{
			theNode->Rot.y = PI+CalcYAngleFromPointToPoint(theNode->Rot.y,
														theNode->Coord.x, theNode->Coord.z,
														cameraX, cameraZ);

			UpdateObjectTransforms(theNode);

		}



			/************************/
			/* SHOW COLLISION BOXES */
			/************************/

		if (gDebugMode == 2)
		{
			DrawCollisionBoxes(theNode,false);
//			DrawBoundingSpheres(theNode);
//			DrawBoundingBoxes(theNode);


		}


					// THE FOLLOWING IS A HACK
					// which fixes a rare bug that some people were reporting where objects would fade in/out randomly.
					// It appears that this might be a bug in certain older hardware where glColor gets messed up.
					// Beta testers have reported that the following fixes it - it's basically a forced reset of the glColor mode.
					// We cannot call our OGL_SetColor4f() function since it thinks the color is alredy 1,1,1,1, so we just force it here.
					//

		glColor4f(1, 1, 1, 1);
		gMyState_Color.r = 1;
		gMyState_Color.g = 1;
		gMyState_Color.b = 1;
		gMyState_Color.a = 1;



			/***************************/
			/* SEE IF DO U/V TRANSFORM */
			/***************************/

		if (statusBits & STATUS_BIT_UVTRANSFORM)
		{
			glMatrixMode(GL_TEXTURE);					// set texture matrix
			glTranslatef(theNode->TextureTransformU, theNode->TextureTransformV, 0);
			glMatrixMode(GL_MODELVIEW);
		}


			/***********************/
			/* SUBMIT THE GEOMETRY */
			/***********************/

#if VERTEXARRAYRANGES
		if (gUsingVertexArrayRange)
		{
			glBindVertexArrayAPPLE(gVertexArrayRangeObjects[theNode->VertexArrayMode]);		// bind to the correct vertex array range
		}
#endif

 		if (noLighting || (theNode->Scale.y == 1.0f))				// if scale == 1 or no lighting, then dont need to normalize vectors
 			glDisable(GL_NORMALIZE);
 		else
 			glEnable(GL_NORMALIZE);

		if (theNode->CustomDrawFunction)							// if has custom draw function, then override and use that
			goto custom_draw;

		switch(theNode->Genre)
		{
			case	EVENT_GENRE:
					break;

			case	SKELETON_GENRE:
					DrawSkeleton(theNode);
					break;

			case	DISPLAY_GROUP_GENRE:
			case	QUADMESH_GENRE:
					if (theNode->BaseGroup)
					{
						MO_DrawObject(theNode->BaseGroup);
					}
					break;


			case	SPRITE_GENRE:
					if (theNode->SpriteMO)
					{
						OGL_PushState();										// keep state

						SetInfobarSpriteState(theNode->AnaglyphZ, 1);

						theNode->SpriteMO->objectData.coord = theNode->Coord;	// update Meta Object's coord info
						theNode->SpriteMO->objectData.scaleX = theNode->Scale.x;
						theNode->SpriteMO->objectData.scaleY = theNode->Scale.y;
						theNode->SpriteMO->objectData.rot = theNode->Rot.y;

						MO_DrawObject(theNode->SpriteMO);
						OGL_PopState();											// restore state
					}
					break;


			case	TEXTMESH_GENRE:
					if (theNode->BaseGroup)
					{
						OGL_PushState();	//--
						SetInfobarSpriteState(theNode->AnaglyphZ, 1);	//--

						MO_DrawObject(theNode->BaseGroup);

						if (gDebugMode >= 2)
						{
							TextMesh_DrawExtents(theNode);
						}

						OGL_PopState();	//--
					}
					break;


			case	CUSTOM_GENRE:
custom_draw:
					if (theNode->CustomDrawFunction)
					{
						theNode->CustomDrawFunction(theNode);
					}
					break;


			default:
#if _DEBUG
					SDL_Log("Unsupported draw for genre %d", theNode->Genre);
#endif
					break;
		}


				/***************************/
				/* SEE IF END UV TRANSFORM */
				/***************************/

		if (statusBits & STATUS_BIT_UVTRANSFORM)
		{
			glMatrixMode(GL_TEXTURE);					// set texture matrix
			glLoadIdentity();
			glMatrixMode(GL_MODELVIEW);
		}



			/* NEXT NODE */
next:

		theNode = (ObjNode *)theNode->NextNode;
	}while (theNode != nil);


				/*****************************/
				/* RESET SETTINGS TO DEFAULT */
				/*****************************/


	if (noZBuffer)
		glEnable(GL_DEPTH_TEST);

	if (noZWrites)
		glDepthMask(GL_TRUE);

	OGL_EnableCullFace();
	OGL_BlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);


	if (texWrap)
	    gGlobalMaterialFlags &= ~(BG3D_MATERIALFLAG_CLAMP_U|BG3D_MATERIALFLAG_CLAMP_V);

	if (clipAlpha)
		glAlphaFunc(GL_NOTEQUAL, 0);


	gGlobalTransparency = 			// reset this in case it has changed
	gGlobalColorFilter.r =
	gGlobalColorFilter.g =
	gGlobalColorFilter.b = 1.0;
	gGlobalMaterialFlags = 0;

	glEnable(GL_NORMALIZE);
}


/************************ DRAW COLLISION BOXES ****************************/

static void DrawCollisionBoxes(ObjNode *theNode, Boolean old)
{
int					n,i;
CollisionBoxType	*c;
float				left,right,top,bottom,front,back;


			/* SET LINE MATERIAL */

	OGL_DisableTexture2D();


		/* SCAN EACH COLLISION BOX */

	n = theNode->NumCollisionBoxes;							// get # collision boxes
	c = &theNode->CollisionBoxes[0];						// pt to array

	for (i = 0; i < n; i++)
	{
			/* GET BOX PARAMS */

		if (old)
		{
			left 	= c[i].oldLeft;
			right 	= c[i].oldRight;
			top 	= c[i].oldTop;
			bottom 	= c[i].oldBottom;
			front 	= c[i].oldFront;
			back 	= c[i].oldBack;
		}
		else
		{
			left 	= c[i].left;
			right 	= c[i].right;
			top 	= c[i].top;
			bottom 	= c[i].bottom;
			front 	= c[i].front;
			back 	= c[i].back;
		}

			/* DRAW TOP */

		glBegin(GL_LINE_LOOP);
		OGL_SetColor4f(1,0,0,1);
		glVertex3f(left, top, back);
		OGL_SetColor4f(1,1,0,1);
		glVertex3f(left, top, front);
		glVertex3f(right, top, front);
		OGL_SetColor4f(1,0,0,1);
		glVertex3f(right, top, back);
		glEnd();

			/* DRAW BOTTOM */

		glBegin(GL_LINE_LOOP);
		OGL_SetColor4f(1,0,0,1);
		glVertex3f(left, bottom, back);
		OGL_SetColor4f(1,1,0,1);
		glVertex3f(left, bottom, front);
		glVertex3f(right, bottom, front);
		OGL_SetColor4f(1,0,0,1);
		glVertex3f(right, bottom, back);
		glEnd();


			/* DRAW LEFT */

		glBegin(GL_LINE_LOOP);
		OGL_SetColor4f(1,0,0,1);
		glVertex3f(left, top, back);
		OGL_SetColor4f(1,0,0,1);
		glVertex3f(left, bottom, back);
		OGL_SetColor4f(1,1,0,1);
		glVertex3f(left, bottom, front);
		glVertex3f(left, top, front);
		glEnd();


			/* DRAW RIGHT */

		glBegin(GL_LINE_LOOP);
		OGL_SetColor4f(1,0,0,1);
		glVertex3f(right, top, back);
		glVertex3f(right, bottom, back);
		OGL_SetColor4f(1,1,0,1);
		glVertex3f(right, bottom, front);
		glVertex3f(right, top, front);
		glEnd();

	}

	OGL_SetColor4f(1,1,1,1);
}

/************************ DRAW BOUNDING BOXES ****************************/

static void DrawBoundingBoxes(ObjNode *theNode)
{
float	left,right,top,bottom,front,back;
int		i;

			/* SET LINE MATERIAL */

	OGL_DisableTexture2D();


			/***************************/
			/* TRANSFORM BBOX TO WORLD */
			/***************************/

	if (theNode->Genre == SKELETON_GENRE)			// skeletons are already oriented, just need translation
	{
		left 	= theNode->LocalBBox.min.x + theNode->Coord.x;
		right 	= theNode->LocalBBox.max.x + theNode->Coord.x;
		top 	= theNode->LocalBBox.max.y + theNode->Coord.y;
		bottom 	= theNode->LocalBBox.min.y + theNode->Coord.y;
		front 	= theNode->LocalBBox.max.z + theNode->Coord.z;
		back 	= theNode->LocalBBox.min.z + theNode->Coord.z;
	}
	else											// non-skeletons need full transform
	{
		OGLPoint3D	corners[8];

		corners[0].x = theNode->LocalBBox.min.x;			// top far left
		corners[0].y = theNode->LocalBBox.max.y;
		corners[0].z = theNode->LocalBBox.min.z;

		corners[1].x = theNode->LocalBBox.max.x;			// top far right
		corners[1].y = theNode->LocalBBox.max.y;
		corners[1].z = theNode->LocalBBox.min.z;

		corners[2].x = theNode->LocalBBox.max.x;			// top near right
		corners[2].y = theNode->LocalBBox.max.y;
		corners[2].z = theNode->LocalBBox.max.z;

		corners[3].x = theNode->LocalBBox.min.x;			// top near left
		corners[3].y = theNode->LocalBBox.max.y;
		corners[3].z = theNode->LocalBBox.max.z;

		corners[4].x = theNode->LocalBBox.min.x;			// bottom far left
		corners[4].y = theNode->LocalBBox.min.y;
		corners[4].z = theNode->LocalBBox.min.z;

		corners[5].x = theNode->LocalBBox.max.x;			// bottom far right
		corners[5].y = theNode->LocalBBox.min.y;
		corners[5].z = theNode->LocalBBox.min.z;

		corners[6].x = theNode->LocalBBox.max.x;			// bottom near right
		corners[6].y = theNode->LocalBBox.min.y;
		corners[6].z = theNode->LocalBBox.max.z;

		corners[7].x = theNode->LocalBBox.min.x;			// bottom near left
		corners[7].y = theNode->LocalBBox.min.y;
		corners[7].z = theNode->LocalBBox.max.z;

		OGLPoint3D_TransformArray(corners, &theNode->BaseTransformMatrix, corners, 8);

					/* FIND NEW BOUNDS */

		left 	= corners[0].x;
		for (i = 1; i < 8; i ++)
			if (corners[i].x < left)
				left = corners[i].x;

		right 	= corners[0].x;
		for (i = 1; i < 8; i ++)
			if (corners[i].x > right)
				right = corners[i].x;

		bottom 	= corners[0].y;
		for (i = 1; i < 8; i ++)
			if (corners[i].y < bottom)
				bottom = corners[i].y;

		top 	= corners[0].y;
		for (i = 1; i < 8; i ++)
			if (corners[i].y > top)
				top = corners[i].y;

		back 	= corners[0].z;
		for (i = 1; i < 8; i ++)
			if (corners[i].z < back)
				back = corners[i].z;


		front 	= corners[0].z;
		for (i = 1; i < 8; i ++)
			if (corners[i].z > front)
				front = corners[i].z;
	}


		/* DRAW TOP */

	glBegin(GL_LINE_LOOP);
	OGL_SetColor4f(1,0,0,1);
	glVertex3f(left, top, back);
	OGL_SetColor4f(1,1,0,1);
	glVertex3f(left, top, front);
	glVertex3f(right, top, front);
	OGL_SetColor4f(1,0,0,1);
	glVertex3f(right, top, back);
	glEnd();

		/* DRAW BOTTOM */

	glBegin(GL_LINE_LOOP);
	OGL_SetColor4f(1,0,0,1);
	glVertex3f(left, bottom, back);
	OGL_SetColor4f(1,1,0,1);
	glVertex3f(left, bottom, front);
	glVertex3f(right, bottom, front);
	OGL_SetColor4f(1,0,0,1);
	glVertex3f(right, bottom, back);
	glEnd();


		/* DRAW LEFT */

	glBegin(GL_LINE_LOOP);
	OGL_SetColor4f(1,0,0,1);
	glVertex3f(left, top, back);
	OGL_SetColor4f(1,0,0,1);
	glVertex3f(left, bottom, back);
	OGL_SetColor4f(1,1,0,1);
	glVertex3f(left, bottom, front);
	glVertex3f(left, top, front);
	glEnd();


		/* DRAW RIGHT */

	glBegin(GL_LINE_LOOP);
	OGL_SetColor4f(1,0,0,1);
	glVertex3f(right, top, back);
	glVertex3f(right, bottom, back);
	OGL_SetColor4f(1,1,0,1);
	glVertex3f(right, bottom, front);
	glVertex3f(right, top, front);
	glEnd();
}



/************************ DRAW BOUNDING SPHERES ****************************/

static void DrawBoundingSpheres(ObjNode *theNode)
{

			/* SET LINE MATERIAL */

	OGL_DisableTexture2D();


	glBegin(GL_LINES);
	glVertex3f(theNode->Coord.x - theNode->BoundingSphereRadius, theNode->Coord.y, theNode->Coord.z);
	glVertex3f(theNode->Coord.x + theNode->BoundingSphereRadius, theNode->Coord.y, theNode->Coord.z);
	glEnd();

	glBegin(GL_LINES);
	glVertex3f(theNode->Coord.x, theNode->Coord.y, theNode->Coord.z - theNode->BoundingSphereRadius);
	glVertex3f(theNode->Coord.x, theNode->Coord.y, theNode->Coord.z + theNode->BoundingSphereRadius);
	glEnd();

	glBegin(GL_LINES);
	glVertex3f(theNode->Coord.x, theNode->Coord.y + theNode->BoundingSphereRadius, theNode->Coord.z);
	glVertex3f(theNode->Coord.x, theNode->Coord.y - theNode->BoundingSphereRadius, theNode->Coord.z);
	glEnd();

}



/********************* MOVE STATIC OBJECT **********************/

void MoveStaticObject(ObjNode *theNode)
{

	if (TrackTerrainItem(theNode))							// just check to see if it's gone
	{
		DeleteObject(theNode);
		return;
	}

	UpdateShadow(theNode);										// prime it
}

/********************* MOVE STATIC OBJECT2 **********************/
//
// Keeps object conformed to terrain curves
//

void MoveStaticObject2(ObjNode *theNode)
{

	if (TrackTerrainItem(theNode))							// just check to see if it's gone
	{
		DeleteObject(theNode);
		return;
	}

	RotateOnTerrain(theNode, 0, nil);							// set transform matrix
	SetObjectTransformMatrix(theNode);

	CalcObjectBoxFromNode(theNode);

	UpdateShadow(theNode);										// prime it
}


/********************* MOVE STATIC OBJECT 3 **********************/
//
// Keeps at current terrain height
//

void MoveStaticObject3(ObjNode *theNode)
{

	if (TrackTerrainItem(theNode))							// just check to see if it's gone
	{
		DeleteObject(theNode);
		return;
	}

	theNode->Coord.y = GetTerrainY(theNode->Coord.x, theNode->Coord.z) - (theNode->LocalBBox.min.y * theNode->Scale.y);

	UpdateObjectTransforms(theNode);

	if (theNode->NumCollisionBoxes > 0)
		CalcObjectBoxFromNode(theNode);

	UpdateShadow(theNode);										// prime it
}



//============================================================================================================
//============================================================================================================
//============================================================================================================

#pragma mark ----- OBJECT DELETING ------


/******************** DELETE ALL OBJECTS ********************/

void DeleteAllObjects(void)
{
	while (gFirstNodePtr != nil)
		DeleteObject(gFirstNodePtr);

	FlushObjectDeleteQueue();
}


/************************ DELETE OBJECT ****************/

void DeleteObject(ObjNode	*theNode)
{
int		i;

	if (theNode == nil)								// see if passed a bogus node
		return;

	if (theNode->CType == INVALID_NODE_FLAG)		// see if already deleted
	{
#if 0
		Str255	errString;

		DebugStr("Double Delete Object");	//-------
		DoAlert("Attempted to Double Delete an Object.  Object was already deleted!");
		NumToString(theNode->Genre,errString);		//------------
		DoAlert(errString);					//---------
		NumToString(theNode->Group,errString);		//------------
		DoAlert(errString);					//---------
		NumToString(theNode->Type,errString);		//------------
		DoFatalAlert(errString);					//---------
#else
		return;
#endif
	}

			/* CALL CUSTOM DESTRUCTOR */

	if (theNode->Destructor)
		theNode->Destructor(theNode);

			/* RECURSIVE DELETE OF CHAIN NODE & SHADOW NODE */
			//
			// should do these first so that base node will have appropriate nextnode ptr
			// since it's going to be used next pass thru the moveobjects loop.  This
			// assumes that all chained nodes are later in list.
			//

	if (theNode->ChainNode)
		DeleteObject(theNode->ChainNode);

	if (theNode->ShadowNode)
		DeleteObject(theNode->ShadowNode);

//	if (theNode->TwitchNode)
//		DeleteObject(theNode->TwitchNode);


			/* SEE IF NEED TO FREE UP SPECIAL MEMORY */

	switch(theNode->Genre)
	{
		case	SKELETON_GENRE:
				FreeSkeletonBaseData(theNode->Skeleton, theNode->Type);		// purge all alloced memory for skeleton data
				theNode->Skeleton = nil;
				break;

		case	SPRITE_GENRE:
				MO_DisposeObjectReference(theNode->SpriteMO);	// dispose reference to sprite meta object
		   		theNode->SpriteMO = nil;
				break;
	}

	for (i = 0; i < MAX_NODE_SPARKLES; i++)				// free sparkles
	{
		if (theNode->Sparkles[i] != -1)
		{
			DeleteSparkle(theNode->Sparkles[i]);
			theNode->Sparkles[i] = -1;
		}
	}

			/* SEE IF STOP SOUND CHANNEL */

	StopAChannel(&theNode->EffectChannel);


		/* SEE IF NEED TO DEREFERENCE A BG3D OBJECT */

	DisposeObjectBaseGroup(theNode);

	for (i = 0; i < MAX_MESHES_IN_MODEL; i++)			// delete world point arrays
	{
		if (theNode->WorldMeshes[i].points)
		{
			SafeDisposePtr(theNode->WorldMeshes[i].points);
			theNode->WorldMeshes[i].points = nil;
		}

		if (theNode->WorldPlaneEQs[i])
		{
			SafeDisposePtr(theNode->WorldPlaneEQs[i]);
			theNode->WorldPlaneEQs[i] = nil;
		}

	}
	theNode->HasWorldPoints = false;



			/* REMOVE NODE FROM LINKED LIST */

	DetachObject(theNode, false);


			/* SEE IF MARK AS NOT-IN-USE IN ITEM LIST */

	if (theNode->TerrainItemPtr)
	{
		theNode->TerrainItemPtr->flags &= ~ITEM_FLAGS_INUSE;		// clear the "in use" flag
	}

		/* OR, IF ITS A SPLINE ITEM, THEN UPDATE SPLINE OBJECT LIST */

	if (theNode->StatusBits & STATUS_BIT_ONSPLINE)
	{
		RemoveFromSplineObjectList(theNode);
	}


			/* DELETE THE NODE BY ADDING TO DELETE QUEUE */

	theNode->CType = INVALID_NODE_FLAG;							// INVALID_NODE_FLAG indicates its deleted
	theNode->Cookie = 0;

	gObjectDeleteQueue[gNumObjsInDeleteQueue++] = theNode;
	if (gNumObjsInDeleteQueue >= OBJ_DEL_Q_SIZE)
		FlushObjectDeleteQueue();

}


/****************** DETACH OBJECT ***************************/
//
// Simply detaches the objnode from the linked list, patches the links
// and keeps the original objnode intact.
//

void DetachObject(ObjNode *theNode, Boolean subrecurse)
{
	if (theNode == nil)
		return;

	if (theNode->StatusBits & STATUS_BIT_DETACHED)	// make sure not already detached
		return;

	if (theNode == gNextNode)						// if its the next node to be moved, then fix things
		gNextNode = theNode->NextNode;

	if (theNode->PrevNode == nil)					// special case 1st node
	{
		gFirstNodePtr = theNode->NextNode;
		if (gFirstNodePtr)
			gFirstNodePtr->PrevNode = nil;
	}
	else
	if (theNode->NextNode == nil)					// special case last node
	{
		theNode->PrevNode->NextNode = nil;
	}
	else											// generic middle deletion
	{
		theNode->PrevNode->NextNode = theNode->NextNode;
		theNode->NextNode->PrevNode = theNode->PrevNode;
	}

	theNode->PrevNode = nil;						// seal links on original node
	theNode->NextNode = nil;

	theNode->StatusBits |= STATUS_BIT_DETACHED;

			/* SUBRECURSE CHAINS & SHADOW */

	if (subrecurse)
	{
		if (theNode->ChainNode)
			DetachObject(theNode->ChainNode, subrecurse);

		if (theNode->ShadowNode)
			DetachObject(theNode->ShadowNode, subrecurse);
	}
}


/****************** ATTACH OBJECT ***************************/

void AttachObject(ObjNode *theNode, Boolean recurse)
{
short	slot;

	if (theNode == nil)
		return;

	if (!(theNode->StatusBits & STATUS_BIT_DETACHED))		// see if already attached
		return;

	slot = theNode->Slot;

	if (gFirstNodePtr == nil)						// special case only entry
	{
		gFirstNodePtr = theNode;
		theNode->PrevNode = nil;
		theNode->NextNode = nil;
	}

			/* INSERT AS FIRST NODE */
	else
	if (slot < gFirstNodePtr->Slot)
	{
		theNode->PrevNode = nil;					// no prev
		theNode->NextNode = gFirstNodePtr; 			// next pts to old 1st
		gFirstNodePtr->PrevNode = theNode; 			// old pts to new 1st
		gFirstNodePtr = theNode;
	}
		/* SCAN FOR INSERTION PLACE */
	else
	{
		ObjNode	 *reNodePtr, *scanNodePtr;

		reNodePtr = gFirstNodePtr;
		scanNodePtr = gFirstNodePtr->NextNode;		// start scanning for insertion slot on 2nd node

		while (scanNodePtr != nil)
		{
			if (slot < scanNodePtr->Slot)					// INSERT IN MIDDLE HERE
			{
				theNode->NextNode = scanNodePtr;
				theNode->PrevNode = reNodePtr;
				reNodePtr->NextNode = theNode;
				scanNodePtr->PrevNode = theNode;
				goto out;
			}
			reNodePtr = scanNodePtr;
			scanNodePtr = scanNodePtr->NextNode;			// try next node
		}

		theNode->NextNode = nil;							// TAG TO END
		theNode->PrevNode = reNodePtr;
		reNodePtr->NextNode = theNode;
	}
out:


	theNode->StatusBits &= ~STATUS_BIT_DETACHED;



			/* SUBRECURSE CHAINS & SHADOW */

	if (recurse)
	{
		if (theNode->ChainNode)
			AttachObject(theNode->ChainNode, recurse);

		if (theNode->ShadowNode)
			AttachObject(theNode->ShadowNode, recurse);
	}

}


/***************** FLUSH OBJECT DELETE QUEUE ****************/

static void FlushObjectDeleteQueue(void)
{
long	i,num;

	num = gNumObjsInDeleteQueue;

	gNumObjectNodes -= num;


	for (i = 0; i < num; i++)
	{
		if (gObjectDeleteQueue[i]->objectNum == -1)					// see if dispose by freeing memory...
			SafeDisposePtr((Ptr)gObjectDeleteQueue[i]);
		else
			gObjectDeleteQueue[i]->isUsed = false;					//.. or just return to gObjectList array
	}

	gNumObjsInDeleteQueue = 0;
}


/****************** DISPOSE OBJECT BASE GROUP **********************/

void DisposeObjectBaseGroup(ObjNode *theNode)
{
	if (theNode->BaseGroup != nil)
	{
		MO_DisposeObjectReference(theNode->BaseGroup);

		theNode->BaseGroup = nil;
	}

	if (theNode->BaseTransformObject != nil)							// also nuke extra ref to transform object
	{
		MO_DisposeObjectReference(theNode->BaseTransformObject);
		theNode->BaseTransformObject = nil;
	}
}




//============================================================================================================
//============================================================================================================
//============================================================================================================

#pragma mark ----- OBJECT INFORMATION ------


/********************** GET OBJECT INFO *********************/

void GetObjectInfo(ObjNode *theNode)
{
	gCoord = theNode->Coord;
	gDelta = theNode->Delta;

}


/********************** UPDATE OBJECT *********************/

void UpdateObject(ObjNode *theNode)
{
	if (theNode->CType == INVALID_NODE_FLAG)		// see if already deleted
		return;

	theNode->Coord = gCoord;
	theNode->Delta = gDelta;
	UpdateObjectTransforms(theNode);

	FastNormalizeVector(gDelta.x, gDelta.y, gDelta.z, &theNode->MotionVector);

	CalcObjectBoxFromNode(theNode);


		/* UPDATE ANY SHADOWS */

	UpdateShadow(theNode);
}



/****************** UPDATE OBJECT TRANSFORMS *****************/
//
// This updates the skeleton object's base translate & rotate transforms
//

void UpdateObjectTransforms(ObjNode *theNode)
{
OGLMatrix4x4	m,m2;
OGLMatrix4x4	mx,my,mz,mxz;
uint32_t			bits;

	if (theNode->CType == INVALID_NODE_FLAG)		// see if already deleted
		return;

				/********************/
				/* SET SCALE MATRIX */
				/********************/

	OGLMatrix4x4_SetScale(&m, theNode->Scale.x,	theNode->Scale.y, theNode->Scale.z);


			/*****************************/
			/* NOW ROTATE & TRANSLATE IT */
			/*****************************/

	bits = theNode->StatusBits;

				/* USE ALIGNMENT MATRIX */

	if (bits & STATUS_BIT_USEALIGNMENTMATRIX)
	{
		m2 = theNode->AlignmentMatrix;
	}
	else
	{
					/* DO XZY ROTATION */

		if (bits & STATUS_BIT_ROTXZY)
		{

			OGLMatrix4x4_SetRotate_X(&mx, theNode->Rot.x);
			OGLMatrix4x4_SetRotate_Y(&my, theNode->Rot.y);
			OGLMatrix4x4_SetRotate_Z(&mz, theNode->Rot.z);

			OGLMatrix4x4_Multiply(&mx,&mz, &mxz);
			OGLMatrix4x4_Multiply(&mxz,&my, &m2);
		}
					/* DO YZX ROTATION */

		else
		if (bits & STATUS_BIT_ROTYZX)
		{
			OGLMatrix4x4_SetRotate_X(&mx, theNode->Rot.x);
			OGLMatrix4x4_SetRotate_Y(&my, theNode->Rot.y);
			OGLMatrix4x4_SetRotate_Z(&mz, theNode->Rot.z);

			OGLMatrix4x4_Multiply(&my,&mz, &mxz);
			OGLMatrix4x4_Multiply(&mxz,&mx, &m2);
		}

					/* DO ZXY ROTATION */

		else
		if (bits & STATUS_BIT_ROTZXY)
		{
			OGLMatrix4x4_SetRotate_X(&mx, theNode->Rot.x);
			OGLMatrix4x4_SetRotate_Y(&my, theNode->Rot.y);
			OGLMatrix4x4_SetRotate_Z(&mz, theNode->Rot.z);

			OGLMatrix4x4_Multiply(&mz,&mx, &mxz);
			OGLMatrix4x4_Multiply(&mxz,&my, &m2);
		}

					/* STANDARD XYZ ROTATION */
		else
		{
			OGLMatrix4x4_SetRotate_XYZ(&m2, theNode->Rot.x, theNode->Rot.y, theNode->Rot.z);
		}
	}


	m2.value[M03] = theNode->Coord.x;
	m2.value[M13] = theNode->Coord.y;
	m2.value[M23] = theNode->Coord.z;

	OGLMatrix4x4_Multiply(&m,&m2, &theNode->BaseTransformMatrix);


				/* UPDATE TRANSFORM OBJECT */

	SetObjectTransformMatrix(theNode);



}

/********************* SET OBJECT GRID LOCATION **********************/

void SetObjectGridLocation(ObjNode *theNode)
{
	theNode->GridX = (int)theNode->Coord.x / GRID_SIZE;				// n unit sized grid
	theNode->GridY = (int)theNode->Coord.y / GRID_SIZE;
	theNode->GridZ = (int)theNode->Coord.z / GRID_SIZE;


}


/***************** SET OBJECT TRANSFORM MATRIX *******************/
//
// This call simply resets the base transform object so that it uses the latest
// base transform matrix
//

void SetObjectTransformMatrix(ObjNode *theNode)
{
MOMatrixObject	*mo = theNode->BaseTransformObject;

	if (theNode->CType == INVALID_NODE_FLAG)		// see if invalid
		return;

	if (mo)				// see if this has a trans obj
	{
		mo->matrix =  theNode->BaseTransformMatrix;
	}

	theNode->HasWorldPoints = false;				// these need to be recalculated now that we've updated the matrix


	SetObjectGridLocation(theNode);
}


/***************** TOGGLE OBJECT VISIBILITY *******************/

Boolean SetObjectVisible(ObjNode* theNode, Boolean visible)
{
	if (visible)
	{
		theNode->StatusBits &= ~STATUS_BIT_HIDDEN;
	}
	else
	{
		theNode->StatusBits |= STATUS_BIT_HIDDEN;
	}

	return visible;
}

#pragma mark - Advanced node chaining

int GetNodeChainLength(ObjNode* node)
{
	for (int length = 0; length <= 0x7FFF; length++)
	{
		if (!node)
			return length;

		node = node->ChainNode;
	}

	DoFatalAlert("Circular chain?");
}

ObjNode* GetNthChainedNode(ObjNode* start, int targetIndex, ObjNode** outPrevNode)
{
	ObjNode* pNode = NULL;
	ObjNode* node = start;

	if (start != NULL)
	{
		int currentIndex;
		for (currentIndex = 0; (node != NULL) && (currentIndex < targetIndex); currentIndex++)
		{
			pNode = node;
			node = pNode->ChainNode;

			if (pNode && node)
			{
				GAME_ASSERT_MESSAGE(pNode->Slot <= node->Slot, "the game assumes that chained nodes are sorted after their parent");
			}
		}

		if (currentIndex != targetIndex)
		{
			node = NULL;
		}
	}

	if (outPrevNode)
	{
		*outPrevNode = pNode;
	}

	return node;
}

ObjNode* GetChainTailNode(ObjNode* start)
{
	ObjNode* pNode = NULL;
	ObjNode* node = start;

	while (node != NULL)
	{
		pNode = node;
		node = pNode->ChainNode;

		if (node)
			GAME_ASSERT(node->Slot > pNode->Slot);
	}

	return pNode;
}

void AppendNodeToChain(ObjNode* first, ObjNode* newTail)
{
	ObjNode* oldTail = GetChainTailNode(first);
	oldTail->ChainNode = newTail;

	newTail->ChainHead = first->ChainHead;
	if (!newTail->ChainHead)
		newTail->ChainHead = first;

	GAME_ASSERT(newTail->Slot > oldTail->Slot);
}

void UnchainNode(ObjNode* theNode)
{
	if (theNode == NULL)
		return;

	ObjNode* chainHead = theNode->ChainHead;
	ObjNode* chainNext = theNode->ChainNode;

	for (ObjNode* node = chainHead; node != NULL; node = node->ChainNode)
	{
		if (node == theNode)
			continue;

		if (node->ChainNode == theNode)
		{
			node->ChainNode = chainNext;
		}

		if (node->ChainHead == theNode)		// rewrite ChainHead
		{
			node->ChainHead = chainNext;
		}
	}
}


#pragma mark - Overlay pane

void SendNodeToOverlayPane(ObjNode* theNode)
{
	theNode->StatusBits |= STATUS_BIT_ONLYSHOWTHISPLAYER;
	theNode->PlayerNum = GetOverlayPaneNumber();
}
