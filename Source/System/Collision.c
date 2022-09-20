/****************************/
/*   	COLLISION.c		    */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/***************/
/* EXTERNALS   */
/***************/

#include "game.h"


extern	OGLPoint3D	gCoord;
extern	OGLVector3D	gDelta;
extern	OGLMatrix4x4	gWorkMatrix;
extern	ObjNode		*gFirstNodePtr;
extern	float		gFramesPerSecond,gFramesPerSecondFrac;
extern	Boolean			gPlayerIsDead[];


/****************************/
/*    PROTOTYPES            */
/****************************/



/****************************/
/*    CONSTANTS             */
/****************************/

#define	MAX_COLLISIONS				60


/****************************/
/*    VARIABLES             */
/****************************/


CollisionRec	gCollisionList[MAX_COLLISIONS];
short			gNumCollisions = 0;
Byte			gTotalSides;
Boolean			gSolidTriggerKeepDelta;
Byte			gTriggerSides;


/******************* COLLISION DETECT *********************/
//
// INPUT: startNumCollisions = value to start gNumCollisions at should we need to keep existing data in collision list
//

void CollisionDetect(ObjNode *baseNode, uint32_t CType, short startNumCollisions)
{
ObjNode 	*thisNode;
uint32_t		sideBits,cBits,cType;
short		numBaseBoxes,targetNumBoxes,target;
CollisionBoxType *baseBoxList;
CollisionBoxType *targetBoxList;
float		leftSide,rightSide,frontSide,backSide,bottomSide,topSide;

	gNumCollisions = startNumCollisions;								// clear list

			/* GET BASE BOX INFO */

	numBaseBoxes = baseNode->NumCollisionBoxes;
	if (numBaseBoxes == 0)
		return;
	baseBoxList = baseNode->CollisionBoxes;

	leftSide 		= baseBoxList->left;
	rightSide 		= baseBoxList->right;
	frontSide 		= baseBoxList->front;
	backSide 		= baseBoxList->back;
	bottomSide 		= baseBoxList->bottom;
	topSide 		= baseBoxList->top;


			/****************************/
			/* SCAN AGAINST ALL OBJECTS */
			/****************************/

	thisNode = gFirstNodePtr;									// start on 1st node

	do
	{
		cType = thisNode->CType;
		if (cType == INVALID_NODE_FLAG)							// see if something went wrong
			break;

		if (thisNode->Slot >= SLOT_OF_DUMB)						// see if reach end of usable list
			break;

		if (!(cType & CType))									// see if we want to check this Type
			goto next;

		if (thisNode->StatusBits & STATUS_BIT_NOCOLLISION)		// don't collide against these
			goto next;

		if (thisNode == baseNode)								// dont collide against itself
			goto next;

		if (baseNode->ChainNode == thisNode)					// don't collide against its own chained object
			goto next;

				/******************************/
				/* NOW DO COLLISION BOX CHECK */
				/******************************/

		targetNumBoxes = thisNode->NumCollisionBoxes;			// see if target has any boxes
		if (targetNumBoxes)
		{
			targetBoxList = thisNode->CollisionBoxes;


				/******************************************/
				/* CHECK BASE BOX AGAINST EACH TARGET BOX */
				/*******************************************/

			for (target = 0; target < targetNumBoxes; target++)
			{
						/* DO RECTANGLE INTERSECTION */

				if (rightSide < targetBoxList[target].left)
					continue;

				if (leftSide > targetBoxList[target].right)
					continue;

				if (frontSide < targetBoxList[target].back)
					continue;

				if (backSide > targetBoxList[target].front)
					continue;

				if (bottomSide > targetBoxList[target].top)
					continue;

				if (topSide < targetBoxList[target].bottom)
					continue;


						/* THERE HAS BEEN A COLLISION SO CHECK WHICH SIDE PASSED THRU */

				sideBits = 0;
				cBits = thisNode->CBits;					// get collision info bits

				if (!(cBits & CBITS_ALLSOLID))				// if not a solid, then add it without side info
					goto got_sides;


								/* CHECK FRONT COLLISION */

				if (cBits & SIDE_BITS_BACK)											// see if target has solid back
				{
					if (baseBoxList->oldFront < targetBoxList[target].oldBack)		// get old & see if already was in target (if so, skip)
					{
						if ((baseBoxList->front >= targetBoxList[target].back) &&	// see if currently in target
							(baseBoxList->front <= targetBoxList[target].front))
						{
							sideBits = SIDE_BITS_FRONT;
						}
					}
				}

								/* CHECK BACK COLLISION */

				if (cBits & SIDE_BITS_FRONT)										// see if target has solid front
				{
					if (baseBoxList->oldBack > targetBoxList[target].oldFront)		// get old & see if already was in target
					{
						if ((baseBoxList->back <= targetBoxList[target].front) &&	// see if currently in target
							(baseBoxList->back >= targetBoxList[target].back))
						{
							sideBits = SIDE_BITS_BACK;
						}
					}
				}


								/* CHECK RIGHT COLLISION */


				if (cBits & SIDE_BITS_LEFT)											// see if target has solid left
				{
					if (baseBoxList->oldRight < targetBoxList[target].oldLeft)		// get old & see if already was in target
					{
						if ((baseBoxList->right >= targetBoxList[target].left) &&	// see if currently in target
							(baseBoxList->right <= targetBoxList[target].right))
						{
							sideBits |= SIDE_BITS_RIGHT;
						}
					}
				}


							/* CHECK COLLISION ON LEFT */

				if (cBits & SIDE_BITS_RIGHT)										// see if target has solid right
				{
					if (baseBoxList->oldLeft > targetBoxList[target].oldRight)		// get old & see if already was in target
					{
						if ((baseBoxList->left <= targetBoxList[target].right) &&	// see if currently in target
							(baseBoxList->left >= targetBoxList[target].left))
						{
							sideBits |= SIDE_BITS_LEFT;
						}
					}
				}

								/* CHECK TOP COLLISION */

				if (cBits & SIDE_BITS_BOTTOM)										// see if target has solid bottom
				{
					if (baseBoxList->oldTop < targetBoxList[target].oldBottom)		// get old & see if already was in target
					{
						if ((baseBoxList->top >= targetBoxList[target].bottom) &&	// see if currently in target
							(baseBoxList->top <= targetBoxList[target].top))
						{
							sideBits |= SIDE_BITS_TOP;
						}
					}
				}

							/* CHECK COLLISION ON BOTTOM */


				if (cBits & SIDE_BITS_TOP)											// see if target has solid top
				{
					if (baseBoxList->oldBottom > targetBoxList[target].oldTop)		// get old & see if already was in target
					{
						if ((baseBoxList->bottom <= targetBoxList[target].top) &&	// see if currently in target
							(baseBoxList->bottom >= targetBoxList[target].bottom))
						{
							sideBits |= SIDE_BITS_BOTTOM;
						}
					}
				}

					/*********************************************/
					/* SEE IF ANYTHING TO ADD OR IF IMPENETRABLE */
					/*********************************************/

				if (!sideBits)														// if 0 then no new sides passed thru this time
				{
					if (cBits & CBITS_IMPENETRABLE)									// if its impenetrable, add to list regardless of sides
					{
						if (gCoord.x < thisNode->Coord.x)							// try to assume some side info based on which side we're on relative to the target
							sideBits |= SIDE_BITS_RIGHT;
						else
							sideBits |= SIDE_BITS_LEFT;

						if (gCoord.z < thisNode->Coord.z)
							sideBits |= SIDE_BITS_FRONT;
						else
							sideBits |= SIDE_BITS_BACK;

//						if (gCoord.y > thisNode->Coord.y)
//							sideBits |= SIDE_BITS_BOTTOM;

						goto got_sides;
					}

					if (cBits & CBITS_ALWAYSTRIGGER)								// also always add if always trigger
						goto got_sides;

					continue;
				}

						/* ADD TO COLLISION LIST */
got_sides:
				gCollisionList[gNumCollisions].baseBox 		= 0;
				gCollisionList[gNumCollisions].targetBox 	= target;
				gCollisionList[gNumCollisions].sides 		= sideBits;
				gCollisionList[gNumCollisions].type 		= COLLISION_TYPE_OBJ;
				gCollisionList[gNumCollisions].objectPtr 	= thisNode;
				gNumCollisions++;
				gTotalSides |= sideBits;											// remember total of this
			}
		}
next:
		thisNode = thisNode->NextNode;												// next target node
	}while(thisNode != nil);

	if (gNumCollisions > MAX_COLLISIONS)											// see if overflowed (memory corruption ensued)
		DoFatalAlert("CollisionDetect: gNumCollisions > MAX_COLLISIONS");
}


/***************** HANDLE COLLISIONS ********************/
//
// This is a generic collision handler.  Takes care of
// all processing.
//
// INPUT:  cType = CType bit mask for collision matching
//
// OUTPUT: totalSides
//

Byte HandleCollisions(ObjNode *theNode, uint32_t cType, float deltaBounce)
{
Byte		totalSides;
short		i;
float		originalX,originalY,originalZ;
float		offset,maxOffsetX,maxOffsetZ,maxOffsetY;
float		offXSign,offZSign,offYSign;
Byte		base,target;
ObjNode		*targetObj;
CollisionBoxType *baseBoxPtr,*targetBoxPtr = nil;
float		leftSide,rightSide,frontSide,backSide,bottomSide;
CollisionBoxType *boxList;
short		numSolidHits, numPasses = 0;
Boolean		hitImpenetrable = false;
short		oldNumCollisions;
Boolean		previouslyOnGround, hitMPlatform = false;
Boolean		hasTriggered = false;
ObjNode		*trigger = nil;

	if (deltaBounce > 0.0f)									// make sure Brian entered a (-) bounce value!
		deltaBounce = -deltaBounce;

	if (theNode->StatusBits & STATUS_BIT_ONGROUND)			// remember if was on ground or not
		previouslyOnGround = true;
	else
		previouslyOnGround = false;

	theNode->StatusBits &= ~STATUS_BIT_ONGROUND;			// assume not on anything now

	gNumCollisions = oldNumCollisions = 0;
	totalSides = 0;

again:
	originalX = gCoord.x;									// remember starting coords
	originalY = gCoord.y;
	originalZ = gCoord.z;

	numSolidHits = 0;

	CalcObjectBoxFromGlobal(theNode);						// calc current collision box

			/**************************/
			/* GET THE COLLISION LIST */
			/**************************/

	CollisionDetect(theNode,cType, gNumCollisions);			// get collision info

	maxOffsetX = maxOffsetZ = maxOffsetY = -10000;
	offXSign = offYSign = offZSign = 0;

			/* GET BASE BOX INFO */

	if (theNode->NumCollisionBoxes == 0)					// it's gotta have a collision box
		return(0);
	boxList 	= theNode->CollisionBoxes;
	leftSide 	= boxList->left;
	rightSide 	= boxList->right;
	frontSide 	= boxList->front;
	backSide 	= boxList->back;
	bottomSide 	= boxList->bottom;

			/*************************************/
			/* SCAN THRU ALL RETURNED COLLISIONS */
			/*************************************/

	for (i=oldNumCollisions; i < gNumCollisions; i++)		// handle all collisions
	{
		base 		= gCollisionList[i].baseBox;			// get collision box index for base & target
		target 		= gCollisionList[i].targetBox;
		targetObj 	= gCollisionList[i].objectPtr;			// get ptr to target objnode

		baseBoxPtr 	= boxList + base;						// calc ptrs to base & target collision boxes
		if (targetObj)
		{
			targetBoxPtr = targetObj->CollisionBoxes;
			targetBoxPtr += target;
		}

					/********************************/
					/* HANDLE OBJECT COLLISIONS 	*/
					/********************************/

		if (gCollisionList[i].type == COLLISION_TYPE_OBJ)
		{
				/* SEE IF THIS OBJECT HAS SINCE BECOME INVALID */

			uint32_t	targetCType = targetObj->CType;						// get ctype of hit obj
			if (targetCType == INVALID_NODE_FLAG)
				continue;

						/* HANDLE TRIGGERS */

			if (((targetCType & CTYPE_TRIGGER) && (cType & CTYPE_TRIGGER)) ||	// target must be trigger and we must have been looking for them as well
				((targetCType & CTYPE_TRIGGER2) && (cType & CTYPE_TRIGGER2)))
	  		{
	  			gSolidTriggerKeepDelta = false;									// assume solid triggers will cause delta to stop below

	  			if (targetObj->TriggerCallback != nil)							// make sure there's a callback installed
	  			{
	  				gTriggerSides = gCollisionList[i].sides;					// set this global in case the trigger handler needs it (rather than passing it to the trigger func)
 					if (!targetObj->TriggerCallback(targetObj,theNode))			// returns false if handle as non-solid trigger
						gCollisionList[i].sides = 0;

					trigger = targetObj;										// remember which obj we triggered
				}

				numSolidHits++;

				maxOffsetX = gCoord.x - originalX;								// see if trigger caused a move
				if (maxOffsetX < 0.0f)
				{
					maxOffsetX = -maxOffsetX;
					offXSign = -1;
				}
				else
				if (maxOffsetX > 0.0f)
					offXSign = 1;

				maxOffsetZ = gCoord.z - originalZ;
				if (maxOffsetZ < 0.0f)
				{
					maxOffsetZ = -maxOffsetZ;
					offZSign = -1;
				}
				else
				if (maxOffsetZ > 0.0f)
					offZSign = 1;

				hasTriggered = true;									// dont allow multi-pass collision once there is a trigger (to avoid multiple hits on the same trigger)


				if (gSolidTriggerKeepDelta)							// if trigger's callback set this then set delta bounce to 1.0 so it'll no affect the deltas
					deltaBounce = 1.0f;
			}


					/*******************/
					/* DO SOLID FIXING */
					/*******************/

			if (gCollisionList[i].sides & ALL_SOLID_SIDES)						// see if object with any solidness
			{
				numSolidHits++;

				if (targetObj->CBits & CBITS_IMPENETRABLE)							// if this object is impenetrable, then throw out any other collision offsets
				{
					hitImpenetrable = true;
					maxOffsetX = maxOffsetZ = maxOffsetY = -10000;
					offXSign = offYSign = offZSign = 0;
				}

				if (gCollisionList[i].sides & SIDE_BITS_BACK)						// SEE IF BACK HIT
				{
					offset = (targetBoxPtr->front - baseBoxPtr->back)+.01f;		// see how far over it went
					if (offset > maxOffsetZ)
					{
						maxOffsetZ = offset;
						offZSign = 1;
					}
					gDelta.z *= deltaBounce;
				}
				else
				if (gCollisionList[i].sides & SIDE_BITS_FRONT)						// SEE IF FRONT HIT
				{
					offset = (baseBoxPtr->front - targetBoxPtr->back)+.01f;		// see how far over it went
					if (offset > maxOffsetZ)
					{
						maxOffsetZ = offset;
						offZSign = -1;
					}
					gDelta.z *= deltaBounce;
				}

				if (gCollisionList[i].sides & SIDE_BITS_LEFT)						// SEE IF HIT LEFT
				{
					offset = (targetBoxPtr->right - baseBoxPtr->left)+.01f;		// see how far over it went
					if (offset > maxOffsetX)
					{
						maxOffsetX = offset;
						offXSign = 1;
					}
					gDelta.x *= deltaBounce;
				}
				else
				if (gCollisionList[i].sides & SIDE_BITS_RIGHT)						// SEE IF HIT RIGHT
				{
					offset = (baseBoxPtr->right - targetBoxPtr->left)+.01f;		// see how far over it went
					if (offset > maxOffsetX)
					{
						maxOffsetX = offset;
						offXSign = -1;
					}
					gDelta.x *= deltaBounce;
				}

				if (gCollisionList[i].sides & SIDE_BITS_BOTTOM)						// SEE IF HIT BOTTOM
				{
					offset = (targetBoxPtr->top - baseBoxPtr->bottom)+.01f;		// see how far over it went
					if (offset > maxOffsetY)
					{
						maxOffsetY = offset;
						offYSign = 1;
					}
					gDelta.y = -150;					// keep some downward momentum!!
				}
				else
				if (gCollisionList[i].sides & SIDE_BITS_TOP)						// SEE IF HIT TOP
				{
					offset = (baseBoxPtr->top - targetBoxPtr->bottom)+1.0f;			// see how far over it went
					if (offset > maxOffsetY)
					{
						maxOffsetY = offset;
						offYSign = -1;
					}
					gDelta.y =0;
				}
			}
		}

		totalSides |= gCollisionList[i].sides;				// keep sides info

		if (hitImpenetrable)								// if that was impenetrable, then we dont need to check other collisions
			break;
	}

		/* IF THERE WAS A SOLID HIT, THEN WE NEED TO UPDATE AND TRY AGAIN */

	if (numSolidHits > 0)
	{
				/* ADJUST MAX AMOUNTS */

		gCoord.x = originalX + (maxOffsetX * offXSign);
		gCoord.z = originalZ + (maxOffsetZ * offZSign);
		gCoord.y = originalY + (maxOffsetY * offYSign);			// y is special - we do some additional rouding to avoid the jitter problem


				/* SEE IF NEED TO SET GROUND FLAG */

		if (totalSides & SIDE_BITS_BOTTOM)
		{
			if (!previouslyOnGround)							// if not already on ground, then add some friction upon landing
			{
				if (hitMPlatform)								// special case landing on moving platforms - stop deltas
				{
					gDelta.x *= .8f;
					gDelta.z *= .8f;
				}
			}
			theNode->StatusBits |= STATUS_BIT_ONGROUND;
		}


				/* SEE IF DO ANOTHER PASS */

		numPasses++;
		if ((numPasses < 3) && (!hitImpenetrable) && (!hasTriggered))	// see if can do another pass and havnt hit anything impenetrable
			goto again;
	}


			/* SEE IF UPDATE TRIGGER INFO */

	if (trigger)													// did we hit a trigger this time?
		theNode->CurrentTriggerObj = trigger;						// yep, so remember it
	else
		theNode->CurrentTriggerObj = false;


				/*************************/
				/* CHECK FENCE COLLISION */
				/*************************/

	if (cType & CTYPE_FENCE)
	{
		if (DoFenceCollision(theNode))
		{
			totalSides |= ALL_SOLID_SIDES;
			numPasses++;
			if (numPasses < 3)
				goto again;
		}
	}

			/******************************************/
			/* SEE IF DO AUTOMATIC TERRAIN GROUND HIT */
			/******************************************/

	if (cType & CTYPE_TERRAIN)
	{
		float	y = GetTerrainY(gCoord.x, gCoord.z);			// get terrain Y

		if (bottomSide <= y)										// see if bottom is under ground
		{
			gCoord.y += y - bottomSide;

			if (gDelta.y < 0.0f)								// if was going down then bounce y
			{
				gDelta.y *= deltaBounce;
				if (fabs(gDelta.y) < 30.0f)						// if small enough just make zero
					gDelta.y = 0;
			}

			theNode->StatusBits |= STATUS_BIT_ONGROUND;

			totalSides |= SIDE_BITS_BOTTOM;
		}
	}

			/* SEE IF DO WATER COLLISION TEST */

	if (cType & CTYPE_WATER)
	{
		int	patchNum;

		DoWaterCollisionDetect(theNode, gCoord.x, gCoord.y, gCoord.z, &patchNum);
	}


	gTotalSides = totalSides;
	return(totalSides);
}



#pragma mark -

/****************** IS POINT IN POLY ****************************/
/*
 * Quadrants:
 *    1 | 0
 *    -----
 *    2 | 3
 */
//
//	INPUT:	pt_x,pt_y	:	point x,y coords
//			cnt			:	# points in poly
//			polypts		:	ptr to array of 2D points
//

Boolean IsPointInPoly2D(float pt_x, float pt_y, Byte numVerts, OGLPoint2D *polypts)
{
Byte 		oldquad,newquad;
float 		thispt_x,thispt_y,lastpt_x,lastpt_y;
signed char	wind;										// current winding number
Byte		i;

			/************************/
			/* INIT STARTING VALUES */
			/************************/

	wind = 0;
    lastpt_x = polypts[numVerts-1].x;  					// get last point's coords
    lastpt_y = polypts[numVerts-1].y;

	if (lastpt_x < pt_x)								// calc quadrant of the last point
	{
    	if (lastpt_y < pt_y)
    		oldquad = 2;
 		else
 			oldquad = 1;
 	}
 	else
    {
    	if (lastpt_y < pt_y)
    		oldquad = 3;
 		else
 			oldquad = 0;
	}


			/***************************/
			/* WIND THROUGH ALL POINTS */
			/***************************/

    for (i=0; i<numVerts; i++)
    {
   			/* GET THIS POINT INFO */

		thispt_x = polypts[i].x;						// get this point's coords
		thispt_y = polypts[i].y;

		if (thispt_x < pt_x)							// calc quadrant of this point
		{
	    	if (thispt_y < pt_y)
	    		newquad = 2;
	 		else
	 			newquad = 1;
	 	}
	 	else
	    {
	    	if (thispt_y < pt_y)
	    		newquad = 3;
	 		else
	 			newquad = 0;
		}

				/* SEE IF QUADRANT CHANGED */

        if (oldquad != newquad)
        {
			if (((oldquad+1)&3) == newquad)				// see if advanced
            	wind++;
			else
        	if (((newquad+1)&3) == oldquad)				// see if backed up
				wind--;
    		else
			{
				float	a,b;

             		/* upper left to lower right, or upper right to lower left.
             		   Determine direction of winding  by intersection with x==0. */

    			a = (lastpt_y - thispt_y) * (pt_x - lastpt_x);
                b = lastpt_x - thispt_x;
                a += lastpt_y * b;
                b *= pt_y;

				if (a > b)
                	wind += 2;
 				else
                	wind -= 2;
    		}
  		}

  				/* MOVE TO NEXT POINT */

   		lastpt_x = thispt_x;
   		lastpt_y = thispt_y;
   		oldquad = newquad;
	}


	return(wind); 										// non zero means point in poly
}





/****************** IS POINT IN TRIANGLE ****************************/
/*
 * Quadrants:
 *    1 | 0
 *    -----
 *    2 | 3
 */
//
//	INPUT:	pt_x,pt_y	:	point x,y coords
//			cnt			:	# points in poly
//			polypts		:	ptr to array of 2D points
//

Boolean IsPointInTriangle(float pt_x, float pt_y, float x0, float y0, float x1, float y1, float x2, float y2)
{
Byte 		oldquad,newquad;
float		m;
signed char	wind;										// current winding number

			/*********************/
			/* DO TRIVIAL REJECT */
			/*********************/

	m = x0;												// see if to left of triangle
	if (x1 < m)
		m = x1;
	if (x2 < m)
		m = x2;
	if (pt_x < m)
		return(false);

	m = x0;												// see if to right of triangle
	if (x1 > m)
		m = x1;
	if (x2 > m)
		m = x2;
	if (pt_x > m)
		return(false);

	m = y0;												// see if to back of triangle
	if (y1 < m)
		m = y1;
	if (y2 < m)
		m = y2;
	if (pt_y < m)
		return(false);

	m = y0;												// see if to front of triangle
	if (y1 > m)
		m = y1;
	if (y2 > m)
		m = y2;
	if (pt_y > m)
		return(false);


			/*******************/
			/* DO WINDING TEST */
			/*******************/

		/* INIT STARTING VALUES */


	if (x2 < pt_x)								// calc quadrant of the last point
	{
    	if (y2 < pt_y)
    		oldquad = 2;
 		else
 			oldquad = 1;
 	}
 	else
    {
    	if (y2 < pt_y)
    		oldquad = 3;
 		else
 			oldquad = 0;
	}


			/***************************/
			/* WIND THROUGH ALL POINTS */
			/***************************/

	wind = 0;


//=============================================

	if (x0 < pt_x)									// calc quadrant of this point
	{
    	if (y0 < pt_y)
    		newquad = 2;
 		else
 			newquad = 1;
 	}
 	else
    {
    	if (y0 < pt_y)
    		newquad = 3;
 		else
 			newquad = 0;
	}

			/* SEE IF QUADRANT CHANGED */

    if (oldquad != newquad)
    {
		if (((oldquad+1)&3) == newquad)				// see if advanced
        	wind++;
		else
    	if (((newquad+1)&3) == oldquad)				// see if backed up
			wind--;
		else
		{
			float	a,b;

         		/* upper left to lower right, or upper right to lower left.
         		   Determine direction of winding  by intersection with x==0. */

			a = (y2 - y0) * (pt_x - x2);
            b = x2 - x0;
            a += y2 * b;
            b *= pt_y;

			if (a > b)
            	wind += 2;
			else
            	wind -= 2;
		}
	}

	oldquad = newquad;

//=============================================

	if (x1 < pt_x)							// calc quadrant of this point
	{
    	if (y1 < pt_y)
    		newquad = 2;
 		else
 			newquad = 1;
 	}
 	else
    {
    	if (y1 < pt_y)
    		newquad = 3;
 		else
 			newquad = 0;
	}

			/* SEE IF QUADRANT CHANGED */

    if (oldquad != newquad)
    {
		if (((oldquad+1)&3) == newquad)				// see if advanced
        	wind++;
		else
    	if (((newquad+1)&3) == oldquad)				// see if backed up
			wind--;
		else
		{
			float	a,b;

         		/* upper left to lower right, or upper right to lower left.
         		   Determine direction of winding  by intersection with x==0. */

			a = (y0 - y1) * (pt_x - x0);
            b = x0 - x1;
            a += y0 * b;
            b *= pt_y;

			if (a > b)
            	wind += 2;
			else
            	wind -= 2;
		}
	}

	oldquad = newquad;

//=============================================

	if (x2 < pt_x)							// calc quadrant of this point
	{
    	if (y2 < pt_y)
    		newquad = 2;
 		else
 			newquad = 1;
 	}
 	else
    {
    	if (y2 < pt_y)
    		newquad = 3;
 		else
 			newquad = 0;
	}

			/* SEE IF QUADRANT CHANGED */

    if (oldquad != newquad)
    {
		if (((oldquad+1)&3) == newquad)				// see if advanced
        	wind++;
		else
    	if (((newquad+1)&3) == oldquad)				// see if backed up
			wind--;
		else
		{
			float	a,b;

         		/* upper left to lower right, or upper right to lower left.
         		   Determine direction of winding  by intersection with x==0. */

			a = (y1 - y2) * (pt_x - x1);
            b = x1 - x2;
            a += y1 * b;
            b *= pt_y;

			if (a > b)
            	wind += 2;
			else
            	wind -= 2;
		}
	}

	return(wind); 										// non zero means point in poly
}






/******************** DO SIMPLE POINT COLLISION *********************************/
//
// INPUT:  except == objNode to skip
//
// OUTPUT: # collisions detected
//

short DoSimplePointCollision(OGLPoint3D *thePoint, uint32_t cType, ObjNode *except)
{
ObjNode	*thisNode;
short	targetNumBoxes,target;
CollisionBoxType *targetBoxList;

	gNumCollisions = 0;

	thisNode = gFirstNodePtr;									// start on 1st node

	do
	{
		if (thisNode->Slot >= SLOT_OF_DUMB)						// see if reach end of usable list
			break;

		if (thisNode == except)									// see if skip this one
			goto next;

		if (!(thisNode->CType & cType))							// see if we want to check this Type
			goto next;

		if (thisNode->StatusBits & STATUS_BIT_NOCOLLISION)	// don't collide against these
			goto next;

		if (!thisNode->CBits)									// see if this obj doesn't need collisioning
			goto next;


				/* GET BOX INFO FOR THIS NODE */

		targetNumBoxes = thisNode->NumCollisionBoxes;			// if target has no boxes, then skip
		if (targetNumBoxes == 0)
			goto next;
		targetBoxList = thisNode->CollisionBoxes;


			/***************************************/
			/* CHECK POINT AGAINST EACH TARGET BOX */
			/***************************************/

		for (target = 0; target < targetNumBoxes; target++)
		{
					/* DO RECTANGLE INTERSECTION */

			if (thePoint->x < targetBoxList[target].left)
				continue;

			if (thePoint->x > targetBoxList[target].right)
				continue;

			if (thePoint->z < targetBoxList[target].back)
				continue;

			if (thePoint->z > targetBoxList[target].front)
				continue;

			if (thePoint->y > targetBoxList[target].top)
				continue;

			if (thePoint->y < targetBoxList[target].bottom)
				continue;


					/* THERE HAS BEEN A COLLISION */

			gCollisionList[gNumCollisions].targetBox = target;
			gCollisionList[gNumCollisions].type = COLLISION_TYPE_OBJ;
			gCollisionList[gNumCollisions].objectPtr = thisNode;
			gNumCollisions++;
		}

next:
		thisNode = thisNode->NextNode;							// next target node
	}while(thisNode != nil);

	return(gNumCollisions);
}


/******************** DO SIMPLE BOX COLLISION *********************************/
//
// OUTPUT: # collisions detected
//

short DoSimpleBoxCollision(float top, float bottom, float left, float right,
						float front, float back, uint32_t cType)
{
ObjNode			*thisNode;
short			targetNumBoxes,target;
CollisionBoxType *targetBoxList;

	gNumCollisions = 0;

	thisNode = gFirstNodePtr;									// start on 1st node

	do
	{
		if (thisNode->Slot >= SLOT_OF_DUMB)						// see if reach end of usable list
			break;

		if (!(thisNode->CType & cType))							// see if we want to check this Type
			goto next;

		if (thisNode->StatusBits & STATUS_BIT_NOCOLLISION)	// don't collide against these
			goto next;

//		if (!thisNode->CBits)									// see if this obj doesn't need collisioning
//			goto next;


				/* GET BOX INFO FOR THIS NODE */

		targetNumBoxes = thisNode->NumCollisionBoxes;			// if target has no boxes, then skip
		if (targetNumBoxes == 0)
			goto next;
		targetBoxList = thisNode->CollisionBoxes;


			/*********************************/
			/* CHECK AGAINST EACH TARGET BOX */
			/*********************************/

		for (target = 0; target < targetNumBoxes; target++)
		{
					/* DO RECTANGLE INTERSECTION */

			if (right < targetBoxList[target].left)
				continue;

			if (left > targetBoxList[target].right)
				continue;

			if (front < targetBoxList[target].back)
				continue;

			if (back > targetBoxList[target].front)
				continue;

			if (bottom > targetBoxList[target].top)
				continue;

			if (top < targetBoxList[target].bottom)
				continue;


					/* THERE HAS BEEN A COLLISION */

			gCollisionList[gNumCollisions].targetBox = target;
			gCollisionList[gNumCollisions].type = COLLISION_TYPE_OBJ;
			gCollisionList[gNumCollisions].objectPtr = thisNode;
			gNumCollisions++;
			goto bail;
		}

next:
		thisNode = thisNode->NextNode;							// next target node
	}while(thisNode != nil);

bail:
	return(gNumCollisions);
}


/******************** DO SIMPLE BOX COLLISION AGAINST PLAYER *********************************/

Boolean DoSimpleBoxCollisionAgainstPlayer(short playerNum, float top, float bottom, float left, float right,
										float front, float back)
{
short			targetNumBoxes,target;
CollisionBoxType *targetBoxList;

	if (gPlayerIsDead[playerNum])									// if dead then blown up and can't be hit
		return(false);


			/* GET BOX INFO FOR THIS NODE */

	targetNumBoxes = gPlayerInfo[playerNum].objNode->NumCollisionBoxes;			// if target has no boxes, then skip
	if (targetNumBoxes == 0)
		return(false);
	targetBoxList = gPlayerInfo[playerNum].objNode->CollisionBoxes;


		/***************************************/
		/* CHECK POINT AGAINST EACH TARGET BOX */
		/***************************************/

	for (target = 0; target < targetNumBoxes; target++)
	{
				/* DO RECTANGLE INTERSECTION */

		if (right < targetBoxList[target].left)
			continue;

		if (left > targetBoxList[target].right)
			continue;

		if (front < targetBoxList[target].back)
			continue;

		if (back > targetBoxList[target].front)
			continue;

		if (bottom > targetBoxList[target].top)
			continue;

		if (top < targetBoxList[target].bottom)
			continue;

		return(true);
	}

	return(false);
}



/******************** DO SIMPLE POINT COLLISION AGAINST PLAYER *********************************/

Boolean DoSimplePointCollisionAgainstPlayer(short playerNum, OGLPoint3D *thePoint)
{
short	targetNumBoxes,target;
CollisionBoxType *targetBoxList;


	if (gPlayerIsDead[playerNum])									// if dead then blown up and can't be hit
		return(false);

			/* GET BOX INFO FOR THIS NODE */

	targetNumBoxes = gPlayerInfo[playerNum].objNode->NumCollisionBoxes;			// if target has no boxes, then skip
	if (targetNumBoxes == 0)
		return(false);
	targetBoxList = gPlayerInfo[playerNum].objNode->CollisionBoxes;


		/***************************************/
		/* CHECK POINT AGAINST EACH TARGET BOX */
		/***************************************/

	for (target = 0; target < targetNumBoxes; target++)
	{
				/* DO RECTANGLE INTERSECTION */

		if (thePoint->x < targetBoxList[target].left)
			continue;

		if (thePoint->x > targetBoxList[target].right)
			continue;

		if (thePoint->z < targetBoxList[target].back)
			continue;

		if (thePoint->z > targetBoxList[target].front)
			continue;

		if (thePoint->y > targetBoxList[target].top)
			continue;

		if (thePoint->y < targetBoxList[target].bottom)
			continue;

		return(true);
	}

	return(false);
}

/******************** DO SIMPLE BOX COLLISION AGAINST OBJECT *********************************/

Boolean DoSimpleBoxCollisionAgainstObject(float top, float bottom, float left, float right,
										float front, float back, ObjNode *targetNode)
{
short			targetNumBoxes,target;
CollisionBoxType *targetBoxList;


			/* GET BOX INFO FOR THIS NODE */

	targetNumBoxes = targetNode->NumCollisionBoxes;			// if target has no boxes, then skip
	if (targetNumBoxes == 0)
		return(false);
	targetBoxList = targetNode->CollisionBoxes;


		/***************************************/
		/* CHECK POINT AGAINST EACH TARGET BOX */
		/***************************************/

	for (target = 0; target < targetNumBoxes; target++)
	{
				/* DO RECTANGLE INTERSECTION */

		if (right < targetBoxList[target].left)
			continue;

		if (left > targetBoxList[target].right)
			continue;

		if (front < targetBoxList[target].back)
			continue;

		if (back > targetBoxList[target].front)
			continue;

		if (bottom > targetBoxList[target].top)
			continue;

		if (top < targetBoxList[target].bottom)
			continue;

		return(true);
	}

	return(false);
}



/************************ FIND HIGHEST COLLISION AT XZ *******************************/
//
// Given the XY input, this returns the highest Y coordinate of any collision
// box here.
//

float FindHighestCollisionAtXZ(float x, float z, uint32_t cType)
{
ObjNode	*thisNode;
short	targetNumBoxes,target;
CollisionBoxType *targetBoxList;
float	topY = -10000000;

	thisNode = gFirstNodePtr;									// start on 1st node

	do
	{
		if (thisNode->Slot >= SLOT_OF_DUMB)						// see if reach end of usable list
			break;

		if (!(thisNode->CType & cType))							// matching ctype
			goto next;

		if (!(thisNode->CBits & CBITS_TOP))						// only top solid objects
			goto next;


				/* GET BOX INFO FOR THIS NODE */

		targetNumBoxes = thisNode->NumCollisionBoxes;			// if target has no boxes, then skip
		if (targetNumBoxes == 0)
			goto next;
		targetBoxList = thisNode->CollisionBoxes;


			/***************************************/
			/* CHECK POINT AGAINST EACH TARGET BOX */
			/***************************************/

		for (target = 0; target < targetNumBoxes; target++)
		{
			if (targetBoxList[target].top < topY)				// check top
				continue;

					/* DO RECTANGLE INTERSECTION */

			if (x < targetBoxList[target].left)
				continue;

			if (x > targetBoxList[target].right)
				continue;

			if (z < targetBoxList[target].back)
				continue;

			if (z > targetBoxList[target].front)
				continue;

			topY = targetBoxList[target].top + .1f;					// save as highest Y

		}

next:
		thisNode = thisNode->NextNode;							// next target node
	}while(thisNode != nil);

			/*********************/
			/* NOW CHECK TERRAIN */
			/*********************/

	if (cType & CTYPE_TERRAIN)
	{
		float	ty = GetTerrainY(x,z);

		if (ty > topY)
			topY = ty;
	}

			/*******************/
			/* NOW CHECK WATER */
			/*******************/

	if (cType & CTYPE_WATER)
	{
		float	wy;

		if (GetWaterY(x, z, &wy))
		{
			if (wy > topY)
				topY = wy;
		}
	}


	return(topY);
}


#pragma mark -


/************************* HANDLE LINE SEGMENT COLLISION ********************************/
//
// Does linesegment-triangle picking on all scene elements to test for collisions.
//
// OUTPUT: 	hitObj = objNode that was hit, or nil if hit something other than an objNode.
//			hitPt = coordinate of the hit
//			TRUE if a collision occurred
//			cTypes = set to CTYPE_TERRAIN or CTYPE_FENCE or left alone depending on what we hit
//

Boolean	HandleLineSegmentCollision(const OGLLineSegment *lineSeg, ObjNode **hitObj, OGLPoint3D *hitPt,
									OGLVector3D *hitNormal, uint32_t *cTypes, Boolean	allowBBoxTests)
{
OGLPoint3D	coord;
OGLVector3D	normal;
float		dist;
float		bestDist = 1000000;
Boolean		hit = false;
uint32_t		inCType = *cTypes;							// get the input CType mask


	*cTypes = 0;										// clear the output CType mask


			/* FIRST SEE IF RAY HITS ANY OBJNODES */

	*hitObj = OGL_DoLineSegmentCollision_ObjNodes(lineSeg, STATUS_BIT_HIDDEN, inCType, hitPt, hitNormal, &bestDist, allowBBoxTests);
	if (*hitObj)
		hit = true;


			/* NEXT SEE IF HIT TERRAIN */

	if (inCType & CTYPE_TERRAIN)
	{
		if (OGL_LineSegmentCollision_Terrain(lineSeg, &coord, &normal, &dist))
		{
			if (dist < bestDist)
			{
				bestDist = dist;
				*hitPt = coord;
				*hitNormal = normal;
				hit = true;
				*cTypes = CTYPE_TERRAIN;							// let caller know that we hit terrain
			}
		}
	}

		/* SEE IF HIT FENCE */

	if (inCType & CTYPE_FENCE)
	{
		if (OGL_LineSegmentCollision_Fence(lineSeg, &coord, &normal, &dist))
		{
			if (dist < bestDist)
			{
				bestDist = dist;
				*hitPt = coord;
				*hitNormal = normal;
				hit = true;
				*cTypes = CTYPE_FENCE;							// let caller know that we hit a fence
			}
		}
	}


		/* SEE IF HIT WATER */

	if (inCType & CTYPE_WATER)
	{
		if (OGL_LineSegmentCollision_Water(lineSeg, &coord, &normal, &dist))
		{
			if (dist < bestDist)
			{
				bestDist = dist;
				*hitPt = coord;
				*hitNormal = normal;
				hit = true;
				*cTypes = CTYPE_WATER;							// let caller know that we hit water
			}
		}
	}


	return(hit);
}




/************************* HANDLE RAY COLLISION ********************************/
//
// Does ray-triangle picking on all scene elements to test for collisions.
//
// OUTPUT: 	hitObj = objNode that was hit, or nil if hit something other than an objNode.
//			hitPt = coordinate of the hit
//			TRUE if a collision occurred
//			cTypes = set to CTYPE_TERRAIN or CTYPE_FENCE or left alone depending on what we hit
//

Boolean	HandleRayCollision(OGLRay *ray, ObjNode **hitObj, OGLPoint3D *hitPt,OGLVector3D *hitNormal, uint32_t *cTypes)
{
OGLPoint3D	coord;
OGLVector3D	normal;
float		bestDist = 1000000;
Boolean		hit = false;
uint32_t		inCType = *cTypes;							// get the input CType mask


	*cTypes = 0;										// clear the output CType mask


			/* FIRST SEE IF RAY HITS ANY OBJNODES */

	*hitObj = OGL_DoRayCollision_ObjNodes(ray, STATUS_BIT_HIDDEN, inCType, hitPt, hitNormal);
	if (*hitObj)
	{
		bestDist = ray->distance;
		hit = true;
	}


			/* NEXT SEE IF HIT TERRAIN */

	if (inCType & CTYPE_TERRAIN)
	{
		if (OGL_DoRayCollision_Terrain(ray, &coord, &normal))
		{
			if (ray->distance < bestDist)
			{
				bestDist = ray->distance;
				*hitPt = coord;
				*hitNormal = normal;
				hit = true;
				*cTypes = CTYPE_TERRAIN;							// let caller know that we hit terrain
				*hitObj = nil;										// nullify any obj hit from above
			}
		}
	}

		/* SEE IF HIT FENCE */

#if 0
	if (inCType & CTYPE_FENCE)
	{
		if (OGL_LineSegmentCollision_Fence(lineSeg, &coord, &normal, &dist))
		{
			if (dist < bestDist)
			{
				bestDist = dist;
				*hitPt = coord;
				*hitNormal = normal;
				hit = true;
				*cTypes = CTYPE_FENCE;							// let caller know that we hit a fence
				*hitObj = nil;										// nullify any obj hit from above
			}
		}
	}


		/* SEE IF HIT WATER */

	if (inCType & CTYPE_WATER)
	{
		if (OGL_LineSegmentCollision_Water(lineSeg, &coord, &normal, &dist))
		{
			if (dist < bestDist)
			{
				bestDist = dist;
				*hitPt = coord;
				*hitNormal = normal;
				hit = true;
				*cTypes = CTYPE_WATER;							// let caller know that we hit water
				*hitObj = nil;										// nullify any obj hit from above
			}
		}
	}
#endif


	if (hit)
		ray->distance = bestDist;					// pass back the best dist

	return(hit);
}























