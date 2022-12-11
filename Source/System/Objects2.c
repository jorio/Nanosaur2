/*********************************/
/*    OBJECT MANAGER 		     */
/* (c)2002 Pangea Software  	*/
/* By Brian Greenstone      	 */
/*********************************/


/***************/
/* EXTERNALS   */
/***************/

#include "game.h"


/****************************/
/*    PROTOTYPES            */
/****************************/

static void DrawShadow(ObjNode *theNode);

static void MO_CalcWorldPoints_Object(ObjNode *theNode, const MetaObjectPtr object);
static void MO_CalcWorldPoints_Group(ObjNode *theNode, const MOGroupObject *object);
static void MO_CalcWorldPoints_Matrix(const MOMatrixObject *matObj);
static void MO_CalcWorldPoints_VertexArray(ObjNode *theNode, MOVertexArrayData *data);

/****************************/
/*    CONSTANTS             */
/****************************/

#define	SHADOW_Y_OFF	2.1f

/**********************/
/*     VARIABLES      */
/**********************/


static	int		gMeshNum;

int		gNumWorldCalcsThisFrame;


//============================================================================================================
//============================================================================================================
//============================================================================================================

#pragma mark ----- OBJECT COLLISION ------

/******************* ADD COLLISION BOX TO OBJECT ************************/

void AddCollisionBoxToObject(ObjNode *theNode, float top, float bottom, float left,
							 float right, float front, float back)
{
int	i;
CollisionBoxType *boxPtr = &theNode->CollisionBoxes[0];

	i = theNode->NumCollisionBoxes++;					// inc # collision boxes

	boxPtr[i].left 		= theNode->Coord.x + left;
	boxPtr[i].right 	= theNode->Coord.x + right;
	boxPtr[i].top 		= theNode->Coord.y + top;
	boxPtr[i].bottom 	= theNode->Coord.y + bottom;
	boxPtr[i].back 		= theNode->Coord.z + back;
	boxPtr[i].front 	= theNode->Coord.z + front;

	KeepOldCollisionBoxes(theNode);
}



/***************** CREATE COLLISION BOX FROM BOUNDING BOX ********************/

void CreateCollisionBoxFromBoundingBox(ObjNode *theNode, float tweakXZ, float tweakY)
{
OGLBoundingBox	*bBox;
float			sx,sy,sz;

	theNode->NumCollisionBoxes = 1;


	if (theNode->Genre == SKELETON_GENRE)
	{
		sx = sz = tweakXZ;
		sy = 1.0;
	}
	else
	{
		sx = theNode->Scale.x * tweakXZ;
		sy = theNode->Scale.y;
		sz = theNode->Scale.z * tweakXZ;
	}

			/* CONVERT TO COLLISON BOX */

	bBox =  &theNode->LocalBBox;

	theNode->LeftOff 	= bBox->min.x * sx;
	theNode->RightOff 	= bBox->max.x * sx;
	theNode->FrontOff 	= bBox->max.z * sz;
	theNode->BackOff 	= bBox->min.z * sz;
	theNode->BottomOff 	= bBox->min.y * sy;
	theNode->TopOff 	= theNode->BottomOff + (bBox->max.y - bBox->min.y) * sy * tweakY;

	CalcObjectBoxFromNode(theNode);
	KeepOldCollisionBoxes(theNode);
}


/***************** CREATE COLLISION BOX FROM BOUNDING BOX: UPDATE ********************/
//
// Same as above, but does not touch the old boxes
//

void CreateCollisionBoxFromBoundingBox_Update(ObjNode *theNode, float tweakXZ, float tweakY)
{
OGLBoundingBox	*bBox;
float			sx,sy,sz;

	theNode->NumCollisionBoxes = 1;


	if (theNode->Genre == SKELETON_GENRE)
	{
		sx = sz = tweakXZ;
		sy = 1.0;
	}
	else
	{
		sx = theNode->Scale.x * tweakXZ;
		sy = theNode->Scale.y;
		sz = theNode->Scale.z * tweakXZ;
	}

			/* CONVERT TO COLLISON BOX */

	bBox =  &theNode->LocalBBox;

	theNode->LeftOff 	= bBox->min.x * sx;
	theNode->RightOff 	= bBox->max.x * sx;
	theNode->FrontOff 	= bBox->max.z * sz;
	theNode->BackOff 	= bBox->min.z * sz;
	theNode->BottomOff 	= bBox->min.y * sy;
	theNode->TopOff 	= theNode->BottomOff + (bBox->max.y - bBox->min.y) * sy * tweakY;

	CalcObjectBoxFromNode(theNode);
}


/***************** CREATE COLLISION BOX FROM BOUNDING BOX MAXIMIZED ********************/
//
// Same as above except it expands the x/z box to the max of x or z so object can rotate without problems.
//

void CreateCollisionBoxFromBoundingBox_Maximized(ObjNode *theNode, float scaleMag)
{
OGLBoundingBox	*bBox;
float			s;
float			maxSide,off;

	theNode->NumCollisionBoxes = 1;

			/* POINT TO BOUNDING BOX */

	bBox =  &theNode->LocalBBox;


			/* DETERMINE LARGEST SIDE */

	if (theNode->Genre == SKELETON_GENRE)
		s = 1.0f;										// skeleton bboxes are already scaled correctly
	else
		s = theNode->Scale.x;

	s *= scaleMag;

	maxSide = fabs(bBox->min.x * s);
	off = fabs(bBox->max.x * s);
	if (off > maxSide)
		maxSide = off;
	off = fabs(bBox->max.z * s);
	if (off > maxSide)
		maxSide = off;
	off = fabs(bBox->min.z) * s;
	if (off > maxSide)
		maxSide = off;


			/* CONVERT TO COLLISON BOX */

	theNode->LeftOff 	= -maxSide;
	theNode->RightOff 	= maxSide;
	theNode->FrontOff 	= maxSide;
	theNode->BackOff 	= -maxSide;
	theNode->TopOff 	= bBox->max.y * s;
	theNode->BottomOff 	= bBox->min.y * s;
	theNode->TopOff 	= theNode->BottomOff + (bBox->max.y - bBox->min.y) * s;

	CalcObjectBoxFromNode(theNode);
	KeepOldCollisionBoxes(theNode);
}



/***************** CREATE COLLISION BOX FROM BOUNDING BOX ROTATED ********************/

void CreateCollisionBoxFromBoundingBox_Rotated(ObjNode *theNode, float tweakXZ, float tweakY)
{
OGLBoundingBox	bBox;
float			s;
OGLMatrix4x4	m;

	theNode->NumCollisionBoxes = 1;


			/* CALC ROTATED BBOX */

	OGLMatrix4x4_SetRotate_XYZ(&m, theNode->Rot.x, theNode->Rot.y, theNode->Rot.z);							// make rot matrix

	if (theNode->Genre == SKELETON_GENRE)																	// calc bbox
		MO_CalcBoundingBox(gBG3DGroupList[MODEL_GROUP_SKELETONBASE+theNode->Type][0], &bBox, &m);
	else
		MO_CalcBoundingBox(gBG3DGroupList[theNode->Group][theNode->Type], &bBox, &m);


			/* CONVERT TO COLLISON BOX */

	s = theNode->Scale.x;

	theNode->LeftOff 	= bBox.min.x * (s * tweakXZ);
	theNode->RightOff 	= bBox.max.x * (s * tweakXZ);
	theNode->FrontOff 	= bBox.max.z * (s * tweakXZ);
	theNode->BackOff 	= bBox.min.z * (s * tweakXZ);

	theNode->BottomOff 	= bBox.min.y * s;
	theNode->TopOff 	= theNode->BottomOff + (bBox.max.y - bBox.min.y) * s * tweakY;

	CalcObjectBoxFromNode(theNode);
	KeepOldCollisionBoxes(theNode);
}




/*******************************  KEEP OLD COLLISION BOXES **************************/
//
// Also keeps old coordinate and stuff
//

void KeepOldCollisionBoxes(ObjNode *theNode)
{
long	i;

	for (i = 0; i < theNode->NumCollisionBoxes; i++)
	{
		theNode->CollisionBoxes[i].oldTop = theNode->CollisionBoxes[i].top;
		theNode->CollisionBoxes[i].oldBottom = theNode->CollisionBoxes[i].bottom;
		theNode->CollisionBoxes[i].oldLeft = theNode->CollisionBoxes[i].left;
		theNode->CollisionBoxes[i].oldRight = theNode->CollisionBoxes[i].right;
		theNode->CollisionBoxes[i].oldFront = theNode->CollisionBoxes[i].front;
		theNode->CollisionBoxes[i].oldBack = theNode->CollisionBoxes[i].back;
	}


	theNode->OldCoord = theNode->Coord;			// remember coord also
}


/**************** CALC OBJECT BOX FROM NODE ******************/
//
// This does a simple 1 box calculation for basic objects.
//
// Box is calculated based on theNode's coords.
//

void CalcObjectBoxFromNode(ObjNode *theNode)
{
CollisionBoxType *boxPtr;

	if (theNode->NumCollisionBoxes > 0)
	{
		boxPtr = &theNode->CollisionBoxes[0];					// get ptr to 1st box (presumed only box)

		boxPtr->left 	= theNode->Coord.x + theNode->LeftOff;
		boxPtr->right 	= theNode->Coord.x + theNode->RightOff;
		boxPtr->top 	= theNode->Coord.y + theNode->TopOff;
		boxPtr->bottom 	= theNode->Coord.y + theNode->BottomOff;
		boxPtr->back 	= theNode->Coord.z + theNode->BackOff;
		boxPtr->front 	= theNode->Coord.z + theNode->FrontOff;
	}
}


/**************** CALC OBJECT BOX FROM GLOBAL ******************/
//
// This does a simple 1 box calculation for basic objects.
//
// Box is calculated based on gCoord
//

void CalcObjectBoxFromGlobal(ObjNode *theNode)
{
CollisionBoxType *boxPtr;

	if (theNode == nil)
		return;

	boxPtr = theNode->CollisionBoxes;					// get ptr to 1st box (presumed only box)

	boxPtr->left 	= gCoord.x  + theNode->LeftOff;
	boxPtr->right 	= gCoord.x  + theNode->RightOff;
	boxPtr->back 	= gCoord.z  + theNode->BackOff;
	boxPtr->front 	= gCoord.z  + theNode->FrontOff;
	boxPtr->top 	= gCoord.y  + theNode->TopOff;
	boxPtr->bottom 	= gCoord.y  + theNode->BottomOff;
}


/******************* SET OBJECT COLLISION BOUNDS **********************/
//
// Sets an object's collision offset/bounds.  Adjust accordingly for input rotation 0..3 (clockwise)
//

void SetObjectCollisionBounds(ObjNode *theNode, float top, float bottom, float left,
							 float right, float front, float back)
{

	theNode->NumCollisionBoxes = 1;					// 1 collision box
	theNode->TopOff 		= top;
	theNode->BottomOff 		= bottom;
	theNode->LeftOff 		= left;
	theNode->RightOff 		= right;
	theNode->FrontOff 		= front;
	theNode->BackOff 		= back;

	CalcObjectBoxFromNode(theNode);
	KeepOldCollisionBoxes(theNode);
}

/******************** CALC NEW TARGET OFFSETS **********************/

void CalcNewTargetOffsets(ObjNode *theNode, float scale)
{
	theNode->TargetOff.x = RandomFloat2() * scale;
	theNode->TargetOff.z = RandomFloat2() * scale;
}


//============================================================================================================
//============================================================================================================
//============================================================================================================

#pragma mark ----- OBJECT SHADOWS ------



/******************* ATTACH SHADOW TO OBJECT ************************/

ObjNode	*AttachShadowToObject(ObjNode *theNode, int shadowType, float scaleX, float scaleZ, Boolean checkBlockers)
{
	float x = theNode->Coord.x;
	float z = theNode->Coord.z;
	float y = GetTerrainY(x, z) + SHADOW_Y_OFF;

	NewObjectDefinitionType def =
	{
		.genre		= CUSTOM_GENRE,
		.coord		= {x,y,z},
		.scale		= scaleX,
		.rot		= theNode->Rot.y,
		.flags		= STATUS_BIT_NOZWRITES | STATUS_BIT_NOLIGHTING | gAutoFadeStatusBits,
		.slot		=  (theNode->Slot >= SLOT_OF_DUMB+1) ? (theNode->Slot+1) : (SLOT_OF_DUMB+1),	// shadow *must* be after parent!
		.moveCall	= nil,
		.drawCall	= DrawShadow,
	};

	ObjNode* shadowObj = MakeNewObject(&def);

	if (shadowObj == nil)
		return(nil);

	theNode->ShadowNode = shadowObj;

	shadowObj->ShadowScaleX = scaleX;							// need to remeber scales for update
	shadowObj->ShadowScaleZ = scaleZ;
	shadowObj->CheckForBlockers = checkBlockers;
	shadowObj->Kind = shadowType;							// remember the shadow type

	return(shadowObj);
}


/******************* ATTACH STATIC SHADOW TO OBJECT ************************/
//
// For creating shadows whic are never going to call UpdateShadow()
//

ObjNode	*AttachStaticShadowToObject(ObjNode *theNode, int shadowType, float scaleX, float scaleZ)
{
ObjNode	*shadowObj;

	float x = theNode->Coord.x;
	float z = theNode->Coord.z;
	float y = GetTerrainY(x, z) + SHADOW_Y_OFF;

	NewObjectDefinitionType def =
	{
		.genre		= CUSTOM_GENRE,
		.coord		= { x,y,z },
		.flags		= STATUS_BIT_NOZWRITES|STATUS_BIT_NOLIGHTING|STATUS_BIT_NOFOG|gAutoFadeStatusBits,
		.slot		= (theNode->Slot >= SLOT_OF_DUMB+1) ? (theNode->Slot+1) : (SLOT_OF_DUMB+1),					// shadow *must* be after parent!
		.moveCall	= nil,
		.drawCall	= DrawShadow,
		.rot		= theNode->Rot.y,
		.scale		= scaleX,
	};

	shadowObj = MakeNewObject(&def);

	theNode->ShadowNode = shadowObj;

	shadowObj->Kind = shadowType;							// remember the shadow type
	shadowObj->Scale.x = scaleX;
	shadowObj->Scale.z = scaleZ;
	RotateOnTerrain(shadowObj, SHADOW_Y_OFF, nil);							// set transform matrix

	return(shadowObj);
}


/************************ UPDATE SHADOW *************************/

void UpdateShadow(ObjNode *theNode)
{
ObjNode *shadowNode,*thisNodePtr;
float	x,bottom,z,y;
float	dist,scaleX,scaleZ;
Boolean	onBlocker = false;

	if (theNode == nil)
		return;

	shadowNode = theNode->ShadowNode;
	if (shadowNode == nil)
		return;

	if (theNode->StatusBits & STATUS_BIT_HIDDEN)					// hide shadow if parent hidden
		shadowNode->StatusBits |= STATUS_BIT_HIDDEN;
	else
		shadowNode->StatusBits &= ~STATUS_BIT_HIDDEN;


	shadowNode->ColorFilter.a = theNode->ColorFilter.a * .9f;		// match fade and decay a little to adjust it how we want it

	x = theNode->Coord.x;
	bottom = theNode->Coord.y + theNode->BottomOff;
	z = theNode->Coord.z;

	shadowNode->Coord = theNode->Coord;
	shadowNode->Rot.y = theNode->Rot.y;

		/****************************************************/
		/* SEE IF SHADOW IS ON BLOCKER OBJECT OR ON TERRAIN */
		/****************************************************/

	if (shadowNode->CheckForBlockers)
	{
		float 	top = theNode->Coord.y + theNode->TopOff;							// init top
		float	highestY = -100000;


			/* SEE IF ON WATER */

		if (GetWaterY(x, z, &y))
		{
			top = y + SHADOW_Y_OFF;
			if (top > GetTerrainY(x, z))									// make sure water is above terrain
			{
				onBlocker = true;
				highestY = y;
			}
		}

			/* SEE IF ON OBJNODE */

		thisNodePtr = gFirstNodePtr;
		do
		{
			if (thisNodePtr->Slot >= SLOT_OF_DUMB)
				break;

			if (thisNodePtr->CType & CTYPE_BLOCKSHADOW)						// look for things which can block the shadow
			{
				int		i;
				for (i = 0; i < thisNodePtr->NumCollisionBoxes; i++)		// check all collision boxes
				{
					if (x < thisNodePtr->CollisionBoxes[i].left)
						continue;
					if (x > thisNodePtr->CollisionBoxes[i].right)
						continue;
					if (z > thisNodePtr->CollisionBoxes[i].front)
						continue;
					if (z < thisNodePtr->CollisionBoxes[i].back)
						continue;

					if ((bottom < thisNodePtr->CollisionBoxes[i].top) &&	// if bottom & top of owner is below top of blocker, then skip
						(top < thisNodePtr->CollisionBoxes[i].top))
						continue;

						/* SHADOW IS ON OBJECT  */

					if (thisNodePtr->CollisionBoxes[i].top > highestY)		// is this higher than anything else we've found?
						highestY = thisNodePtr->CollisionBoxes[i].top;

					onBlocker = true;
				}
			}
			thisNodePtr = (ObjNode *)thisNodePtr->NextNode;				// next node
		}
		while (thisNodePtr != nil);


				/* SET SHADOW'S Y */

		if (onBlocker)
			shadowNode->Coord.y = highestY + SHADOW_Y_OFF;				// set shadow's Y


					/* IF WE WERE ON ONE THEN FINISH AND BAIL */

		if (onBlocker)
		{
			shadowNode->Scale.x = shadowNode->ShadowScaleX;					// use preset scale
			shadowNode->Scale.z = shadowNode->ShadowScaleZ;
			UpdateObjectTransforms(shadowNode);
			return;
		}
	}

			/************************/
			/* SHADOW IS ON TERRAIN */
			/************************/

	RotateOnTerrain(shadowNode, SHADOW_Y_OFF, nil);							// set transform matrix



			/* CALC SCALE OF SHADOW */

	dist = (bottom - shadowNode->Coord.y) * (1.0f/1000.0f);					// as we go higher, shadow gets smaller
	if (dist < 0.0f)
		dist = 0;

	dist = 1.0f - dist;

	scaleX = dist * shadowNode->ShadowScaleX;
	scaleZ = dist * shadowNode->ShadowScaleZ;

	if (scaleX < 0.0f)
		scaleX = 0;
	if (scaleZ < 0.0f)
		scaleZ = 0;

	shadowNode->Scale.x = scaleX;				// this scale wont get updated until next frame (RotateOnTerrain).
	shadowNode->Scale.z = scaleZ;
}


/******************* DRAW SHADOW ******************/

static void DrawShadow(ObjNode *theNode)
{
int	shadowType = theNode->Kind;

	OGL_PushState();
	OGL_DisableCullFace();

			/* SUBMIT THE MATRIX */

	glMultMatrixf(theNode->BaseTransformMatrix.value);


			/* SUBMIT SHADOW TEXTURE */

	gGlobalTransparency = theNode->ColorFilter.a;

	MO_DrawMaterial(gSpriteGroupList[SPRITE_GROUP_GLOBAL][GLOBAL_SObjType_Shadow_Circular+shadowType].materialObject);


			/* DRAW THE SHADOW */

	glBegin(GL_QUADS);
	glTexCoord2f(0,0);	glVertex3f(-20, 0, 20);
	glTexCoord2f(1,0);	glVertex3f(20, 0, 20);
	glTexCoord2f(1,1);	glVertex3f(20, 0, -20);
	glTexCoord2f(0,1);	glVertex3f(-20, 0, -20);
	glEnd();

	OGL_PopState();
	gGlobalTransparency = 1.0;

}


//============================================================================================================
//============================================================================================================
//============================================================================================================

#pragma mark ----- OBJECT CULLING ------


/**************** CULL TEST ALL OBJECTS *******************/

void CullTestAllObjects(void)
{
int			i;
ObjNode		*theNode;
float		m00,m01,m02,m03;
float		m10,m11,m12,m13;
float		m20,m21,m22,m23;
float		m30,m31,m32,m33;
float		minX,minY,minZ,maxX,maxY,maxZ;
OGLBoundingBox		*bBox;
uint32_t		clipFlags;				// Clip in/out tests for point
uint32_t		clipCodeAND;			// Clip test for entire object


	theNode = gFirstNodePtr;														// get & verify 1st node
	if (theNode == nil)
		return;

					/* PROCESS EACH OBJECT */

	do
	{
		if (theNode->StatusBits & STATUS_BIT_HIDDEN)			// if hidden then skip
			goto next;

		if (theNode->StatusBits & STATUS_BIT_DONTCULL)			// see if dont want to use our culling
			goto draw_on;

		bBox = &theNode->LocalBBox;
		if (bBox->isEmpty)											// skip culling if no bbox
			goto draw_on;

				/*******************************************************/
				/* CALCULATE THE LOCAL->FRUSTUM MATRIX FOR THIS OBJECT */
				/*******************************************************/
				//
				// NOTE: 	I load the matrices into registers inside the "if" statements instead
				// 			of at the end because this tricks CodeWarrior into really pre-loading
				//			the registers.  Otherwise, CodeWarrior loads them each pass in the loop
				//			below.
				//

						/* MATRIX FOR SKELETON OBJECT */

		if (theNode->Genre == SKELETON_GENRE)			// skeletons are already oriented, just need translation
		{
			OGLMatrix4x4	m,m2;
			OGLMatrix4x4_SetTranslate(&m2, theNode->Coord.x, theNode->Coord.y, theNode->Coord.z);
			OGLMatrix4x4_Multiply(&m2, &gWorldToFrustumMatrix, &m);

			m00 = m.value[M00];							// load matrix into registers
			m01 = m.value[M01];
			m02 = m.value[M02];
			m03 = m.value[M03];
			m10 = m.value[M10];
			m11 = m.value[M11];
			m12 = m.value[M12];
			m13 = m.value[M13];
			m20 = m.value[M20];
			m21 = m.value[M21];
			m22 = m.value[M22];
			m23 = m.value[M23];
			m30 = m.value[M30];
			m31 = m.value[M31];
			m32 = m.value[M32];
			m33 = m.value[M33];
		}

				/* MATRIX FOR NON-SKELETON OBJECT */

		else											// non-skeletons need full transform
		{
			OGLMatrix4x4	m;

			OGLMatrix4x4_Multiply(&theNode->BaseTransformMatrix, &gWorldToFrustumMatrix, &m);

			m00 = m.value[M00];							// load matrix into registers
			m01 = m.value[M01];
			m02 = m.value[M02];
			m03 = m.value[M03];
			m10 = m.value[M10];
			m11 = m.value[M11];
			m12 = m.value[M12];
			m13 = m.value[M13];
			m20 = m.value[M20];
			m21 = m.value[M21];
			m22 = m.value[M22];
			m23 = m.value[M23];
			m30 = m.value[M30];
			m31 = m.value[M31];
			m32 = m.value[M32];
			m33 = m.value[M33];
		}


					/******************************/
					/* TRANSFORM THE BOUNDING BOX */
					/******************************/

		minX = bBox->min.x;								// load bbox into registers
		minY = bBox->min.y;
		minZ = bBox->min.z;
		maxX = bBox->max.x;
		maxY = bBox->max.y;
		maxZ = bBox->max.z;

		clipCodeAND = ~0u;

		for (i = 0; i < 8; i++)
		{
			float		lX, lY, lZ;				// Local space co-ordinates
			float		hX, hY, hZ, hW;			// Homogeneous co-ordinates
			float		minusHW;				// -hW

			switch (i)							// load current bbox corner in IX,IY,IZ
			{
				default:
				case	0:	lX = minX;	lY = minY;	lZ = minZ;	break;
				case	1:	lX = minX;	lY = minY;	lZ = maxZ;	break;
				case	2:	lX = minX;	lY = maxY;	lZ = minZ;	break;
				case	3:	lX = minX;	lY = maxY;	lZ = maxZ;	break;
				case	4:	lX = maxX;	lY = minY;	lZ = minZ;	break;
				case	5:	lX = maxX;	lY = minY;	lZ = maxZ;	break;
				case	6:	lX = maxX;	lY = maxY;	lZ = minZ;	break;
				case	7:	lX = maxX;	lY = maxY;	lZ = maxZ;  break;
			}

			hW = lX * m30 + lY * m31 + lZ * m32 + m33;
			hY = lX * m10 + lY * m11 + lZ * m12 + m13;
			hZ = lX * m20 + lY * m21 + lZ * m22 + m23;
			hX = lX * m00 + lY * m01 + lZ * m02 + m03;

			minusHW = -hW;

					/* CHECK Y */

			if (hY < minusHW)
				clipFlags = 0x8;
			else
			if (hY > hW)
				clipFlags = 0x4;
			else
				clipFlags = 0;


					/* CHECK Z */

			if (hZ > hW)
				clipFlags |= 0x20;
			else
			if (hZ < 0.0f)
				clipFlags |= 0x10;


					/* CHECK X */

			if (hX < minusHW)
				clipFlags |= 0x2;
			else
			if (hX > hW)
				clipFlags |= 0x1;

			clipCodeAND &= clipFlags;
		}

		/****************************/
		/* SEE IF WAS CULLED OR NOT */
		/****************************/

		if (clipCodeAND)															// check for case #2
		{
//draw_off:
			theNode->StatusBits |= (STATUS_BIT_ISCULLED1 << gCurrentSplitScreenPane);		// set cull bit for this pane/player
		}
		else
		{
draw_on:
			theNode->StatusBits &= ~(STATUS_BIT_ISCULLED1 << gCurrentSplitScreenPane);		// clear cull bit
		}



				/* NEXT NODE */
next:
		theNode = theNode->NextNode;		// next node
	}
	while (theNode != nil);
}


/******************* IS OBJECT TOTALLY CULLED ************************/
//
// Returns true if object is culled in all panes
//

Boolean	IsObjectTotallyCulled(ObjNode *theNode)
{
uint32_t	culledThisPane;
short	i;

	for (i = 0; i < gNumPlayers; i++)
	{
		culledThisPane = theNode->StatusBits & (STATUS_BIT_ISCULLED1 << i);
		if (!culledThisPane)
			return(false);
	}

	return(true);
}






//============================================================================================================
//============================================================================================================
//============================================================================================================


#pragma mark -


/********************* CALC DISPLAY GROUP WORLD POINTS *******************************/

void CalcDisplayGroupWorldPoints(ObjNode *theNode)
{
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glLoadIdentity();

	gMeshNum = 0;

	MO_CalcWorldPoints_Object(theNode, theNode->BaseGroup);

	glPopMatrix();

	theNode->HasWorldPoints = true;
	gNumWorldCalcsThisFrame++;
}


/******************** MO: CALC WORLD POINTS: OBJECT ***********************/

static void MO_CalcWorldPoints_Object(ObjNode *theNode, const MetaObjectPtr object)
{
MetaObjectHeader	*objHead = object;
MOVertexArrayObject	*vObj;

			/* VERIFY COOKIE */

	if (objHead->cookie != MO_COOKIE)
		DoFatalAlert("MO_CalcWorldPoints_Object: cookie is invalid!");


			/* HANDLE TYPE */

	switch(objHead->type)
	{
		case	MO_TYPE_GEOMETRY:
				vObj = object;
				MO_CalcWorldPoints_VertexArray(theNode, &vObj->objectData);
				break;

		case	MO_TYPE_GROUP:
				MO_CalcWorldPoints_Group(theNode, object);
				break;

		case	MO_TYPE_MATRIX:
				MO_CalcWorldPoints_Matrix(object);
				break;
	}
}

/******************** MO_CALC WORLD POINTS GROUP *************************/

static void MO_CalcWorldPoints_Group(ObjNode *theNode, const MOGroupObject *object)
{
int	numChildren,i;


		/* PUSH MATRIES WITH OPENGL */

	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();


				/***************/
				/* PARSE GROUP */
				/***************/

	numChildren = object->objectData.numObjectsInGroup;			// get # objects in group

	for (i = 0; i < numChildren; i++)
	{
		MO_CalcWorldPoints_Object(theNode, object->objectData.groupContents[i]);
	}


		/* RETREIVE OPENGL MATRICES */

	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();
}


/************************ OGL CALC WORLD POINTS MATRIX **************************/

static void MO_CalcWorldPoints_Matrix(const MOMatrixObject *matObj)
{
const OGLMatrix4x4		*m;

	m = &matObj->matrix;							// point to matrix

				/* MULTIPLY CURRENT MATRIX BY THIS */

	glMultMatrixf((GLfloat *)m);
}


/******************** MO: CALC WORLD POINTS - VERTEX ARRAY *************************/

static void MO_CalcWorldPoints_VertexArray(ObjNode *theNode, MOVertexArrayData *data)
{
int				numPoints,meshNum;
OGLPoint3D		*worldBuffer;
OGLMatrix4x4	localToWorld;
int				t, numTriangles ,i;
MOTriangleIndecies	*tris;

	numPoints = data->numPoints;									// get # points in this mesh
	meshNum = gMeshNum;

	if (meshNum >= MAX_MESHES_IN_MODEL)
		DoFatalAlert("MO_CalcWorldPoints_VertexArray: meshNum >= MAX_MESHES_IN_MODEL");


			/*  SEE IF NEED TO INIT THIS MESH COPY */

	if (theNode->WorldMeshes[meshNum].points == nil)
	{
		theNode->WorldMeshes[meshNum] = *data;												// copy the entire vertex array data struct
		theNode->WorldMeshes[meshNum].points = AllocPtrClear(sizeof(OGLPoint3D) * numPoints);	// assign a new points array, however
	}

	worldBuffer = theNode->WorldMeshes[meshNum].points;				// get ptr to the world-space point buffer


			/************************************************/
			/* TRANSFORM ALL OF THESE POINTS TO WORLD-SPACE */
			/************************************************/

				/* GET THE TRANSFORM MATRIX WE'VE BUILT */

	glGetFloatv(GL_MODELVIEW_MATRIX, localToWorld.value);

				/* TRANSFORM EACH POINT INTO THE BUFFER */

	OGLPoint3D_TransformArray(&data->points[0], &localToWorld,	worldBuffer,  numPoints);



			/***************************************************/
			/* CALCULATE THE PLANE EQ FOR ALL OF THE TRIANGLES */
			/***************************************************/

	numTriangles = data->numTriangles;									// get # triangles
	tris = data->triangles;												// get ptr to triangle array

	if (theNode->WorldPlaneEQs[meshNum] == nil)
		theNode->WorldPlaneEQs[meshNum] = AllocPtrClear(sizeof(OGLPlaneEquation) * numTriangles);	// alloc array for plane eq's

	for (t = 0; t < numTriangles; t++)
	{
		OGLPoint3D	pts[3];

		i = tris[t].vertexIndices[0];													// get the vertex world-coords
		pts[0] = worldBuffer[i];
		i = tris[t].vertexIndices[1];
		pts[1] = worldBuffer[i];
		i = tris[t].vertexIndices[2];
		pts[2] = worldBuffer[i];

		OGL_ComputeTrianglePlaneEquation(pts, &theNode->WorldPlaneEQs[meshNum][t]);	// calc plane eq

	}

	gMeshNum++;
}



#pragma mark -

/********************* HIDE OBJECT CHAIN ************************/

void HideObjectChain(ObjNode *theNode)
{
ObjNode	*node = theNode;

	while(node)
	{
		node->StatusBits |= STATUS_BIT_HIDDEN;
		node = node->ChainNode;
	}
}


/********************* SHOW OBJECT CHAIN ************************/

void ShowObjectChain(ObjNode *theNode)
{
ObjNode	*node = theNode;

	while(node)
	{
		node->StatusBits &= ~STATUS_BIT_HIDDEN;
		node = node->ChainNode;
	}
}











#pragma mark ----- BACKGROUND PICTURE OBJECT NODE ------

ObjNode* MakeBackgroundPictureObject(const char* imagePath)
{
	MOPictureObject* backgroundPicture = MO_CreateNewObjectOfType(MO_TYPE_PICTURE, 0, (void*) imagePath);

	NewObjectDefinitionType def =
	{
		.genre = DISPLAY_GROUP_GENRE,
		.slot = BGPIC_SLOT,
		.scale = 1.0f,
		.flags = STATUS_BITS_FOR_2D,
	};

	ObjNode* obj = MakeNewObject(&def);

	CreateBaseGroup(obj);
	MO_AppendToGroup(obj->BaseGroup, backgroundPicture);

	MO_DisposeObjectReference(backgroundPicture);
	return obj;
}




