/****************************/
/*   	SPLINE MANAGER.C    */
/* (c)2004 Pangea Software  */
/* By Brian Greenstone      */
/****************************/
//
// This is not code for the terrain splines!  This does other custom spline management.
//


/****************************/
/*    EXTERNALS             */
/****************************/

#include "game.h"


/****************************/
/*    PROTOTYPES            */
/****************************/


/****************************/
/*    CONSTANTS             */
/****************************/


/*********************/
/*    VARIABLES      */
/*********************/

CustomSplineType	gCustomSplines[MAX_CUSTOM_SPLINES];


/************************* INIT SPLINE MANAGER ***********************/

void InitSplineManager(void)
{
	SDL_memset(gCustomSplines, 0, sizeof(gCustomSplines));

	for (int i = 0; i < MAX_CUSTOM_SPLINES; i++)
	{
		gCustomSplines[i].isUsed = false;
		gCustomSplines[i].splinePoints = nil;
	}
}


/******************* FREE ALL CUSTOM SPLINES **********************/

void FreeAllCustomSplines(void)
{
	for (int i = 0; i < MAX_CUSTOM_SPLINES; i++)
	{
		FreeACustomSpline(i);
	}
}


/******************* FREE A CUSTOM SPLINE *********************/

void FreeACustomSpline(short splineNum)
{
	if (gCustomSplines[splineNum].isUsed)
	{
		SafeDisposePtr(gCustomSplines[splineNum].splinePoints);
		gCustomSplines[splineNum].splinePoints = nil;
		gCustomSplines[splineNum].isUsed = false;
	}
}


/*********************** GENERATE CUSTOM SPLINE *************************/

short GenerateCustomSpline(short numNubs, OGLPoint3D *nubPoints, long pointsPerSpan)
{
OGLPoint3D	**space,*splinePoints;
OGLPoint3D 	*a, *b, *c, *d;
OGLPoint3D 	*h0, *h1, *h2, *h3, *hi_a;
short 		imax;
float 		t, dt;
long		i,i1,numPoints,slot, maxPoints;
long		nub;


		/* FIND FREE SLOT */

	for (slot = 0; slot < MAX_CUSTOM_SPLINES; slot++)
	{
		if (!gCustomSplines[slot].isUsed)
			goto got_slot;
	}
	return(-1);

got_slot:

	gCustomSplines[slot].isUsed = true;


				/* ALLOCATE 2D ARRAY FOR CALCULATIONS */

	Alloc_2d_array(OGLPoint3D, space, 8, numNubs);


				/* ALLOC POINT ARRAY */

	maxPoints = pointsPerSpan * numNubs;
	splinePoints = gCustomSplines[slot].splinePoints = AllocPtrClear(sizeof(OGLPoint3D) * maxPoints);


		/*******************************************************/
		/* DO MAGICAL CUBIC SPLINE CALCULATIONS ON CONTROL PTS */
		/*******************************************************/

	h0 = space[0];
	h1 = space[1];
	h2 = space[2];
	h3 = space[3];

	a = space[4];
	b = space[5];
	c = space[6];
	d = space[7];


				/* COPY CONTROL POINTS INTO ARRAY */

	for (i = 0; i < numNubs; i++)
		d[i] = nubPoints[i];


	for (i = 0, imax = numNubs - 2; i < imax; i++)
	{
		h2[i].x = h2[i].y = h2[i].z = 1;
		h3[i].x = 3 *(d[i+ 2].x - 2 * d[i+ 1].x + d[i].x);
		h3[i].y = 3 *(d[i+ 2].y - 2 * d[i+ 1].y + d[i].y);
		h3[i].z = 3 *(d[i+ 2].z - 2 * d[i+ 1].z + d[i].z);
	}
  	h2[numNubs - 3].x = h2[numNubs - 3].z = 0;

	a[0].x = a[0].y = a[0].z = 4;
	h1[0].x = h3[0].x / a[0].x;
	h1[0].y = h3[0].y / a[0].y;
	h1[0].z = h3[0].z / a[0].z;

	for (i = 1, i1 = 0, imax = numNubs - 2; i < imax; i++, i1++)
	{
		h0[i1].x = h2[i1].x / a[i1].x;
		a[i].x = 4.0f - h0[i1].x;
		h1[i].x = (h3[i].x - h1[i1].x) / a[i].x;

		h0[i1].y = h2[i1].y / a[i1].y;
		a[i].y = 4.0f - h0[i1].y;
		h1[i].y = (h3[i].y - h1[i1].y) / a[i].y;

		h0[i1].z = h2[i1].z / a[i1].z;
		a[i].z = 4.0f - h0[i1].z;
		h1[i].z = (h3[i].z - h1[i1].z) / a[i].z;
	}

	b[numNubs - 3] = h1[numNubs - 3];

	for (i = numNubs - 4; i >= 0; i--)
	{
 		b[i].x = h1[i].x - h0[i].x * b[i+ 1].x;
 		b[i].y = h1[i].y - h0[i].y * b[i+ 1].y;
 		b[i].z = h1[i].z - h0[i].z * b[i+ 1].z;
 	}

	for (i = numNubs - 2; i >= 1; i--)
		b[i] = b[i - 1];

	b[0].x = b[numNubs - 1].x =
	b[0].y = b[numNubs - 1].y =
	b[0].z = b[numNubs - 1].z = 0;
	hi_a = a + numNubs - 1;

	for (; a < hi_a; a++, b++, c++, d++)
	{
		c->x = ((d+1)->x - d->x) -(2.0f * b->x + (b+1)->x) * (1.0f/3.0f);
		a->x = ((b+1)->x - b->x) * (1.0f/3.0f);

		c->y = ((d+1)->y - d->y) -(2.0f * b->y + (b+1)->y) * (1.0f/3.0f);
		a->y = ((b+1)->y - b->y) * (1.0f/3.0f);

		c->z = ((d+1)->z - d->z) -(2.0f * b->z + (b+1)->z) * (1.0f/3.0f);
		a->z = ((b+1)->z - b->z) * (1.0f/3.0f);
	}

		/***********************************/
		/* NOW CALCULATE THE SPLINE POINTS */
		/***********************************/

	a = space[4];
	b = space[5];
	c = space[6];
	d = space[7];

  	numPoints = 0;
	for (nub = 0; a < hi_a; a++, b++, c++, d++, nub++)
	{
				/* CALC THIS SPAN */

		dt = 1.0f / pointsPerSpan;
		for (t = 0; t < (1.0f - EPS); t += dt)
		{
			if (numPoints >= maxPoints)				// see if overflow
				DoFatalAlert("GenerateCustomSpline: numPoints >= maxPoints");

 			splinePoints[numPoints].x = ((a->x * t + b->x) * t + c->x) * t + d->x;		// save point
 			splinePoints[numPoints].y = ((a->y * t + b->y) * t + c->y) * t + d->y;
 			splinePoints[numPoints].z = ((a->z * t + b->z) * t + c->z) * t + d->z;


 			numPoints++;
 		}
	}


		/* END */


	gCustomSplines[slot].numPoints = numPoints;
	Free_2d_array(space);


	return(slot);
}













