/****************************/
/*   	SPLINE ITEMS.C      */
/****************************/


#include "3DMath.h"

/***************/
/* EXTERNALS   */
/***************/

extern	u_char	gTerrainScrollBuffer[MAX_SUPERTILES_DEEP][MAX_SUPERTILES_WIDE];
extern	float	gFramesPerSecondFrac,gFramesPerSecond,gMapToUnitValue,gTerrainSuperTileUnitSizeFrac;
extern	SuperTileStatus	**gSuperTileStatusGrid;

/****************************/
/*    PROTOTYPES            */
/****************************/

static Boolean NilPrime(long splineNum, SplineItemType *itemPtr);


/****************************/
/*    CONSTANTS             */
/****************************/

#define	MAX_SPLINE_OBJECTS		100



/**********************/
/*     VARIABLES      */
/**********************/

SplineDefType	*gSplineList = nil;
long			gNumSplines = 0;

static long		gNumSplineObjects = 0;
static ObjNode	*gSplineObjectList[MAX_SPLINE_OBJECTS];


/**********************/
/*     TABLES         */
/**********************/

#define	MAX_SPLINE_ITEM_NUM		49				// for error checking!

Boolean (*gSplineItemPrimeRoutines[MAX_SPLINE_ITEM_NUM+1])(long, SplineItemType *) =
{
		NilPrime,							// My Start Coords
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		PrimeEnemy_Raptor,				// 15:  raptor enemy
		PrimeDustDevil,					// 16:
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		PrimeEnemy_Brach,				// 26:  brach
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		PrimeLaserOrb,					// 32: laser orb
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,						// 40:
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		NilPrime,
		PrimeEnemy_Ramphor,						// 48
		PrimeTimeDemoSpline						// 49

};



/********************* PRIME SPLINES ***********************/
//
// Called during terrain prime function to initialize
// all items on the splines and recalc spline coords
//

void PrimeSplines(void)
{
long			s,i,type;
SplineItemType 	*itemPtr;
Boolean			flag;
SplinePointType	*points;


			/* ADJUST SPLINE TO GAME COORDINATES */

	for (s = 0; s < gNumSplines; s++)
	{
		points = gSplineList[s].pointList;							// point to points list

		for (i = 0; i < gSplineList[s].numPoints; i++)
		{
			points[i].x *= gMapToUnitValue;
			points[i].z *= gMapToUnitValue;
		}

	}


				/* CLEAR SPLINE OBJECT LIST */

	gNumSplineObjects = 0;										// no items in spline object node list yet

	for (s = 0; s < gNumSplines; s++)
	{

				/* SCAN ALL ITEMS ON THIS SPLINE */

		for (i = 0; i < gSplineList[s].numItems; i++)
		{
			itemPtr = &gSplineList[s].itemList[i];					// point to this item
			type = itemPtr->type;								// get item type
			if (type > MAX_SPLINE_ITEM_NUM)
				DoFatalAlert("\pPrimeSplines: type > MAX_SPLINE_ITEM_NUM");

			flag = gSplineItemPrimeRoutines[type](s,itemPtr); 	// call item's Prime routine
			if (flag)
				itemPtr->flags |= ITEM_FLAGS_INUSE;				// set in-use flag
		}

			/* UPDATE SONG */

//	if (gSongMovie)
//		MoviesTask(gSongMovie, 0);

	}
}


/******************** NIL PRIME ***********************/
//
// nothing prime
//

static Boolean NilPrime(long splineNum, SplineItemType *itemPtr)
{
#pragma unused (splineNum, itemPtr)
	return(false);
}


/*********************** GET COORD ON SPLINE FROM INDEX **********************/

void GetCoordOnSplineFromIndex(SplineDefType *splinePtr, float findex, float *x, float *z)
{
SplinePointType	*points;
int				i,i2, numPointsInSpline;
float			ratio,oneMinusRatio;

			/* CALC INDEX OF THIS PT AND NEXT */

	numPointsInSpline = splinePtr->numPoints;					// get # points in the spline
	i = findex;													// round down to int
	i2 = i+1;
	if (i2 >= numPointsInSpline)								// make sure not go too far
		i2 = numPointsInSpline-1;

	points = splinePtr->pointList;								// point to point list


			/* INTERPOLATE */

	ratio = findex - (float)i;									// calc 0.0 - .999 remainder for weighing the points
	oneMinusRatio = 1.0f - ratio;

	*x = points[i].x * oneMinusRatio + points[i2].x * ratio;	// calc interpolated coord
	*z = points[i].z * oneMinusRatio + points[i2].z * ratio;
}


/*********************** GET COORD ON SPLINE **********************/

void GetCoordOnSpline(SplineDefType *splinePtr, float placement, float *x, float *z)
{
int				numPointsInSpline;
float			findex;

	numPointsInSpline = splinePtr->numPoints;					// get # points in the spline
	findex = (float)numPointsInSpline * placement;				// calc float index

	GetCoordOnSplineFromIndex(splinePtr, findex, x, z);
}


/*********************** GET NEXT COORD ON SPLINE **********************/
//
// Same as above except returns coord of the next point on the spline instead of the exact
// current one.
//

void GetNextCoordOnSpline(SplineDefType *splinePtr, float placement, float *x, float *z)
{
float			numPointsInSpline;
float			findex;

	numPointsInSpline = splinePtr->numPoints;					// get # points in the spline

	findex = (float)numPointsInSpline * placement;				// get index
	findex += 1.0f;												// bump it up +1

	if (findex >= (float)numPointsInSpline)						// see if wrap around
		findex = 0;

	GetCoordOnSplineFromIndex(splinePtr, findex, x, z);
}


/*********************** GET COORD ON SPLINE 2 **********************/
//
// Same as above except takes in input spline index offset
//

void GetCoordOnSpline2(SplineDefType *splinePtr, float placement, float offset, float *x, float *z)
{
float			numPointsInSpline;
int				findex;

	numPointsInSpline = splinePtr->numPoints;					// get # points in the spline

	findex = (float)numPointsInSpline * placement;				// get index
	findex += offset;											// bump it up

	if (findex >= (float)numPointsInSpline)						// see if wrap around
		findex -= (float)numPointsInSpline;

	GetCoordOnSplineFromIndex(splinePtr, findex, x, z);
}


/********************* IS SPLINE ITEM ON ACTIVE TERRAIN ********************/
//
// Returns true if the input objnode is in visible range.
// Also, this function handles the attaching and detaching of the objnode
// as needed.
//

Boolean IsSplineItemOnActiveTerrain(ObjNode *theNode)
{
Boolean	visible = true;
long	row,col;


			/* IF IS ON AN ACTIVE SUPERTILE, THEN ASSUME VISIBLE */

	row = theNode->Coord.z * gTerrainSuperTileUnitSizeFrac;	// calc supertile row,col
	col = theNode->Coord.x * gTerrainSuperTileUnitSizeFrac;

	if ((row < 0) || (row >= gNumSuperTilesDeep) || (col < 0) || (col >= gNumSuperTilesWide))		// make sure in bounds
		visible = false;
	else
	{
		if (gSuperTileStatusGrid[row][col].playerHereFlags)
			visible = true;
		else
			visible = false;
	}
			/* HANDLE OBJNODE UPDATES */

	if (visible)
	{
		if (theNode->StatusBits & STATUS_BIT_DETACHED)			// see if need to insert into linked list
		{
			AttachObject(theNode, true);
		}
	}
	else
	{
		if (!(theNode->StatusBits & STATUS_BIT_DETACHED))		// see if need to remove from linked list
		{
			DetachObject(theNode, true);
		}
	}

	return(visible);
}


#pragma mark ======= SPLINE OBJECTS ================

/******************* ADD TO SPLINE OBJECT LIST ***************************/
//
// Called by object's primer function to add the detached node to the spline item master
// list so that it can be maintained.
//

void AddToSplineObjectList(ObjNode *theNode, Boolean setAim)
{

	if (gNumSplineObjects >= MAX_SPLINE_OBJECTS)
		DoFatalAlert("\pAddToSplineObjectList: too many spline objects");

	theNode->SplineObjectIndex = gNumSplineObjects;					// remember where in list this is

	gSplineObjectList[gNumSplineObjects++] = theNode;


			/* SET INITIAL AIM */

	if (setAim)
		SetSplineAim(theNode);
}

/************************ SET SPLINE AIM ***************************/

void SetSplineAim(ObjNode *theNode)
{
float	x,z;

	GetCoordOnSpline2(&gSplineList[theNode->SplineNum], theNode->SplinePlacement, 3, &x, &z);			// get coord of next point on spline
	theNode->Rot.y = CalcYAngleFromPointToPoint(theNode->Rot.y, theNode->Coord.x, theNode->Coord.z,x,z);	// calc y rot aim


}

/****************** REMOVE FROM SPLINE OBJECT LIST **********************/
//
// OUTPUT:  true = the obj was on a spline and it was removed from it
//			false = the obj was not on a spline.
//

Boolean RemoveFromSplineObjectList(ObjNode *theNode)
{
	theNode->StatusBits &= ~STATUS_BIT_ONSPLINE;		// make sure this flag is off

	if (theNode->SplineObjectIndex != -1)
	{
		gSplineObjectList[theNode->SplineObjectIndex] = nil;			// nil out the entry into the list
		theNode->SplineObjectIndex = -1;
		theNode->SplineItemPtr = nil;
		theNode->SplineMoveCall = nil;
		return(true);
	}
	else
	{
		return(false);
	}
}


/**************** EMPTY SPLINE OBJECT LIST ***********************/
//
// Called by level cleanup to dispose of the detached ObjNode's in this list.
//

void EmptySplineObjectList(void)
{
int	i;
ObjNode	*o;

	for (i = 0; i < gNumSplineObjects; i++)
	{
		o = gSplineObjectList[i];
		if (o)
			DeleteObject(o);			// This will dispose of all memory used by the node.
										// RemoveFromSplineObjectList will be called by it.
	}
	gNumSplineObjects = 0;
}


/******************* MOVE SPLINE OBJECTS **********************/

void MoveSplineObjects(void)
{
long	i;
ObjNode	*theNode;

	for (i = 0; i < gNumSplineObjects; i++)
	{
		theNode = gSplineObjectList[i];
		if (theNode)
		{
					/* UPDATE SKELETON ANIMATION */

			if (theNode->Skeleton)
				UpdateSkeletonAnimation(theNode);

					/* CALL SPLINE MOVE */

			if (theNode->SplineMoveCall)
			{
				KeepOldCollisionBoxes(theNode);					// keep old boxes & other stuff
				theNode->SplineMoveCall(theNode);				// call object's spline move routine
			}

				/* UPDATE SKELETON'S MESH */

			if (theNode->CType != INVALID_NODE_FLAG)
				if (theNode->Skeleton)
					UpdateSkinnedGeometry(theNode);

		}
	}
}


/*********************** GET OBJECT COORD ON SPLINE **********************/
//
// OUTPUT: 	x,y = coords
//

void GetObjectCoordOnSpline(ObjNode *theNode)
{
float			placement;
SplineDefType	*splinePtr;

	placement = theNode->SplinePlacement;						// get placement
	if (placement < 0.0f)
		placement = 0;
	else
	if (placement >= 1.0f)
		placement = .999f;

	splinePtr = &gSplineList[theNode->SplineNum];			// point to the spline

	GetCoordOnSpline(splinePtr, placement, &theNode->Coord.x, &theNode->Coord.z);		// get coord

	theNode->Delta.x = (theNode->Coord.x - theNode->OldCoord.x) * gFramesPerSecond;		// calc delta
	theNode->Delta.z = (theNode->Coord.z - theNode->OldCoord.z) * gFramesPerSecond;
	theNode->Delta.y = 0;
}


/*********************** GET OBJECT COORD ON SPLINE 2 **********************/

void GetObjectCoordOnSpline2(ObjNode *theNode, float *x, float *z)
{
float			placement;
SplineDefType	*splinePtr;

	placement = theNode->SplinePlacement;						// get placement
	if (placement < 0.0f)
		placement = 0;
	else
	if (placement >= 1.0f)
		placement = .999f;

	splinePtr = &gSplineList[theNode->SplineNum];			// point to the spline

	GetCoordOnSpline(splinePtr, placement, x, z);		// get coord
}



/******************* INCREASE SPLINE INDEX *********************/
//
// Moves objects on spline at given speed
//
// Returns true if increase caused item to wrap to beginning of spline
//

Boolean IncreaseSplineIndex(ObjNode *theNode, float speed)
{
SplineDefType	*splinePtr;
float			numPointsInSpline;

	speed *= gFramesPerSecondFrac;

	splinePtr = &gSplineList[theNode->SplineNum];			// point to the spline
	numPointsInSpline = splinePtr->numPoints;					// get # points in the spline

	theNode->SplinePlacement += speed / numPointsInSpline;
	if (theNode->SplinePlacement > .999f)
	{
		theNode->SplinePlacement -= .999f;
		if (theNode->SplinePlacement > .999f)			// see if it wrapped somehow
			theNode->SplinePlacement = 0;
		return(true);
	}
	return(false);
}


/******************* INCREASE SPLINE INDEX ZIGZAG *********************/
//
// Moves objects on spline at given speed, but zigzags
//

void IncreaseSplineIndexZigZag(ObjNode *theNode, float speed)
{
SplineDefType	*splinePtr;
float			numPointsInSpline;

	speed *= gFramesPerSecondFrac;

	splinePtr = &gSplineList[theNode->SplineNum];			// point to the spline
	numPointsInSpline = splinePtr->numPoints;					// get # points in the spline

			/* GOING BACKWARD */

	if (theNode->StatusBits & STATUS_BIT_REVERSESPLINE)			// see if going backward
	{
		theNode->SplinePlacement -= speed / numPointsInSpline;
		if (theNode->SplinePlacement <= 0.0f)
		{
			theNode->SplinePlacement = 0;
			theNode->StatusBits ^= STATUS_BIT_REVERSESPLINE;	// toggle direction
		}
	}

		/* GOING FORWARD */

	else
	{
		theNode->SplinePlacement += speed / numPointsInSpline;
		if (theNode->SplinePlacement >= .999f)
		{
			theNode->SplinePlacement = .999f;
			theNode->StatusBits ^= STATUS_BIT_REVERSESPLINE;	// toggle direction
		}
	}
}


/******************** DETACH OBJECT FROM SPLINE ***********************/

void DetachObjectFromSpline(ObjNode *theNode, void *moveCall)
{

	if (!(theNode->StatusBits & STATUS_BIT_ONSPLINE))
		return;

		/***********************************************/
		/* MAKE SURE ALL COMPONENTS ARE IN LINKED LIST */
		/***********************************************/

	AttachObject(theNode, true);


			/* REMOVE FROM SPLINE */

	RemoveFromSplineObjectList(theNode);

	theNode->InitCoord  = theNode->Coord;			// remember where started

	theNode->MoveCall = moveCall;

}




