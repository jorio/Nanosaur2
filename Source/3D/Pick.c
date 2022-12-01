/****************************/
/*   		PICK.C    	    */
/* (c)2003 Pangea Software  */
/* By Brian Greenstone      */
/****************************/


/****************************/
/*    EXTERNALS             */
/****************************/


#include "game.h"


/****************************/
/*    PROTOTYPES            */
/****************************/

static Boolean	OGL_DoesRayIntersectMesh(OGLRay *ray, MOVertexArrayData *mesh, OGLPoint3D *intersectionPt, OGLVector3D *triangleNormal);

static void OGLTriangle_3D2DComponentProjectionPoints(const OGLVector3D *triangleNormal,	const OGLPoint3D *point3D, const OGLPoint3D	*triPoints,
													 OGLPoint2D *point2D, OGLPoint2D *verts2D);


static Boolean OGL_DoesRayIntersectSphere(OGLRay *ray, OGLPoint3D *sphereCenter, double sphereRadius, OGLPoint3D *intersectPt);
static Boolean OGL_RayGetHitInfo_Skeleton(OGLRay *ray, ObjNode *theNode, OGLPoint3D *worldHitCoord, OGLVector3D	*hitVector);




static Boolean	OGL_DoesLineSegIntersectMesh(const OGLLineSegment *lineSeg, OGLVector3D *lineVec, MOVertexArrayData *mesh,
											OGLPoint3D *intersectionPt, OGLVector3D *hitNormal, float *distToIntersection);

static Boolean	OGL_DoesLineSegIntersectMesh2(const OGLLineSegment *lineSeg, OGLVector3D *lineVec, OGLPlaneEquation *planeEQ, MOVertexArrayData *mesh,
												OGLPoint3D *intersectionPt, OGLVector3D *hitNormal, float *distToIntersection);

static Boolean OGL_LineSegGetHitInfo_DisplayGroup(const OGLLineSegment *lineSeg, ObjNode *theNode, OGLPoint3D *worldHitCoord,
												OGLVector3D *hitNormal, float *distToHit);

static Boolean	OGL_LineSegIntersectsTriangle(const OGLLineSegment *lineSeg, OGLVector3D *lineVector, OGLPoint3D *trianglePoints, OGLPoint3D *intersectPt,
											OGLVector3D *hitNormal, float *distFromP1ToPlane);

static Boolean	OGL_LineSegIntersectsTriangle2(const OGLLineSegment *lineSeg, OGLVector3D *lineVector, OGLPlaneEquation *planeEQ,
												OGLPoint3D *trianglePoints, OGLPoint3D *intersectPt, float *distFromP1ToPlane);

static Boolean OGL_DoesLineSegIntersectTrianglePlane(const OGLLineSegment *lineSeg, OGLVector3D *lineVec, OGLPoint3D	triWorldPoints[],
													float *distFromP1ToPlane, OGLVector3D *planeNormal);

static Boolean OGL_DoesLineSegIntersectTrianglePlane2(const OGLLineSegment *lineSeg, OGLVector3D *lineVec, OGLPlaneEquation *planeEQ, float *distFromP1ToPlane);

static Boolean OGL_LineSegGetHitInfo_Skeleton(const OGLLineSegment *lineSeg, ObjNode *theNode,
											OGLPoint3D *worldHitCoord, OGLVector3D *hitNormal, float *hitDist);

static Boolean OGL_DoesLineSegmentIntersectBBox_Approx(const OGLLineSegment *lineSeg, const OGLBoundingBox *bbox);


static Boolean OGL_DoesSphereIntersectSphere(const OGLBoundingSphere *sphere1, const OGLBoundingSphere *sphere2);
static Boolean OGL_IsPointInSphere(const OGLPoint3D *p, const OGLBoundingSphere *sphere);

static Boolean OGL_DoesSkeletonIntersectSphere(const OGLBoundingSphere *sphere, const ObjNode *theNode);
static Boolean	OGL_DoesSphereIntersectMesh(const OGLBoundingSphere *sphere, const MOVertexArrayData *mesh);
static Boolean OGL_DoesDisplayGroupIntersectSphere(const OGLBoundingSphere *sphere, ObjNode *theNode);



/****************************/
/*    CONSTANTS             */
/****************************/

#define	EmVector3D_Member_Dot(_nx,_ny,_nz,_p)							\
			((_nx * _p.x) + (_ny * _p.y) + (_nz * _p.z))

#define	GRID_SKIP_RANGE		2						// how many grid units away to just skip collisions between objects


/*********************/
/*    VARIABLES      */
/*********************/

Boolean		gPickAllTrianglesAsDoubleSided = false;						// set to true if we want our OGL_DoesLineSegIntersectTrianglePlane() functions to accept hits on backfaces



#pragma mark ======= RAY COLLISION ========

/**************** OGL: DO RAY COLLISION ON OBJNODES ************************/
//
// Checks to see if the input ray hits any eligible and visible objNodes in the scene.
//
// INPUT: 	ray = world-space ray to collide with
//			statusFilter = STATUS_BIT flags used for filtering out objects we don't care about (like hidden or culled objects)
//			cTypes = which objects do we want to collide against?
//
// OUTPUT:  ObjNode of object picked or nil
//			worldHitCoord = world-space coords of the pick intersection
//			hitNormal = normal of the triangle we hit (or nil)
//			ray->distance = distance from ray origin to the intersection point
//

ObjNode *OGL_DoRayCollision_ObjNodes(OGLRay *ray, uint32_t statusFilter, uint32_t cTypes, OGLPoint3D *worldHitCoord, OGLVector3D *hitNormal)
{
ObjNode		*thisNodePtr;
ObjNode		*bestObj = nil;
float		bestDist = 1000000;
OGLPoint3D	hitPt;
OGLVector3D	normal;

	thisNodePtr = gFirstNodePtr;

	do
	{
				/* VERIFY NODE */

		if (thisNodePtr->Slot >= SLOT_OF_DUMB)												// stop here
			break;

		if (thisNodePtr->CType == INVALID_NODE_FLAG)										// make sure the node is even valid
			goto next;
		if (thisNodePtr->StatusBits & statusFilter)											// used to optionally filter out hidden stuff, etc.
			goto next;

		if (thisNodePtr->CType & cTypes)													// only if pickable
		{
					/*************************************************************************************/
					/* IF THE PICK RAY HITS THE OBJECT'S BOUNDING SPHERE THEN SEE IF WE HIT THE GEOMETRY */
					/*************************************************************************************/

			if (OGL_DoesRayIntersectSphere(ray, &thisNodePtr->Coord, thisNodePtr->BoundingSphereRadius, nil))
			{
						/* NOW PARSE THE OBJNODE AND DO RAY-TRIANGLE TESTS TO SEE WHERE WE HIT */

				switch(thisNodePtr->Genre)
				{
					case	SKELETON_GENRE:
							if (OGL_RayGetHitInfo_Skeleton(ray, thisNodePtr, &hitPt, &normal))	// does ray intersect skeleton?
							{
								if (ray->distance < bestDist)									// is this the best hit so far?
								{
									bestDist = ray->distance;
									bestObj = thisNodePtr;
									if (worldHitCoord)
										*worldHitCoord = hitPt;
									if (hitNormal)
										*hitNormal = normal;
								}
							}
							break;

					case	DISPLAY_GROUP_GENRE:
							if (OGL_RayGetHitInfo_DisplayGroup(ray, thisNodePtr, &hitPt, &normal))	// does ray hit display group geometry?
							{
								if (ray->distance < bestDist)								// is this the best hit so far?
								{
									bestDist = ray->distance;
									bestObj = thisNodePtr;
									if (worldHitCoord)
										*worldHitCoord = hitPt;
									if (hitNormal)
										*hitNormal = normal;
								}
							}
							break;

					case	CUSTOM_GENRE:													// ignore this or do custom handling
							break;

					default:
							DoFatalAlert("OGL_DoRayCollision: unsupported genre");
				}
			}
		}

next:
		thisNodePtr = thisNodePtr->NextNode;												// next node
	}
	while (thisNodePtr != nil);

	ray->distance = bestDist;								// return the best distance in the ray

	return(bestObj);
}


/****************** OGL:  DO RAY COLLISION ON TERRAIN ************************/
//
// Determines if the input ray intersects any terrain geometry
//
// OUTPUT:
//			ray->distance = distance from ray origin to the intersection point
//

Boolean OGL_DoRayCollision_Terrain(OGLRay *ray, OGLPoint3D *worldHitCoord, OGLVector3D *terrainNormal)
{
short	i;
MOVertexArrayData	*mesh;
Boolean				hit, returnTrue = false;
OGLPoint3D			origin, sphereHitPt, hitCoord;
OGLVector3D			hitNormal;
float				radius;
float				bestDist = 1000000;

	radius = gTerrainSuperTileUnitSize * .5f;									// set the bounding sphere radius for all supertiles


	for (i = 0; i < MAX_SUPERTILES; i++)
	{
		if (gSuperTileMemoryList[i].mode == SUPERTILE_MODE_FREE)				// look for used / active supertiles
			continue;

			/* DOES RAY INTERSECT THIS SUPERTILE'S BOUNDING SPEHRE? */

		origin.x = gSuperTileMemoryList[i].x;									// get b-sphere coords
		origin.y = gSuperTileMemoryList[i].y;
		origin.z = gSuperTileMemoryList[i].z;

		hit = OGL_DoesRayIntersectSphere(ray, &origin, radius, &sphereHitPt);	// see if ray hits sphere
		if (hit)
		{
				/* SEE IF RAY HIT ANY SUPERTILE TRIANGLES */

			mesh = gSuperTileMemoryList[i].meshData;							// get ptr to supertile's mesh data

			hit = OGL_DoesRayIntersectMesh(ray, mesh, &hitCoord, &hitNormal);
			if (hit)
			{

						/* IS THIS THE CLOSEST HIT? */

				if (ray->distance < bestDist)
				{
							/* REMEMBER THIS HIT AS THE BEST SO FAR */

					bestDist = ray->distance;
					*worldHitCoord = hitCoord;
					if (terrainNormal)
						*terrainNormal = hitNormal;
					returnTrue = true;
				}
			}
		}
	}

	if (returnTrue)
		ray->distance = bestDist;							// return the distance to the best hit

	return(returnTrue);
}



/**************************** IS OBJECT IN FRONT OF RAY ****************************/

Boolean OGL_IsObjectInFrontOfRay(ObjNode *theNode, OGLRay *ray)
{
OGLVector3D	v;
float		dot, x, y, z, r;
OGLPoint3D	pt;

	x = theNode->Coord.x;
	y = theNode->Coord.y;
	z = theNode->Coord.z;

			/* FIRST JUST SEE IF THE OBJECT'S COORDS ARE IN FRONT */

	v.x = x - ray->origin.x;							// calc vector from origin to object coords
	v.y = y - ray->origin.y;
	v.z = z - ray->origin.z;
	OGLVector3D_Normalize(&v, &v);

	dot = OGLVector3D_Dot(&v, &ray->direction);			// calc angle between vectors
	if (dot < 0.0f)
		return(true);


			/* NOW SEE IF BOUNDING SPHERE IS ALSO IN FRONT OR NOT */

	r = theNode->BoundingSphereRadius;
	pt.x = x - (v.x * r);								// calc point on bounding sphere
	pt.y = y - (v.y * r);
	pt.z = z - (v.z * r);

	v.x = pt.x - ray->origin.x;							// calc vector from origin to sphere coords
	v.y = pt.y - ray->origin.y;
	v.z = pt.z - ray->origin.z;
	OGLVector3D_Normalize(&v, &v);

	dot = OGLVector3D_Dot(&v, &ray->direction);			// calc angle between vectors
	if (dot < 0.0f)
		return(true);

	return(false);
}

/******************** OGL:  DOES RAY INTERSECT SPHERE *************************/
//
// Returns TRUE if the input ray intersects the input sphere.
// also returns the intersect point if intersectPt != nil
//
//			ray->distance = distance from ray origin to the intersection point
//

static Boolean OGL_DoesRayIntersectSphere(OGLRay *ray, OGLPoint3D *sphereCenter, double sphereRadius, OGLPoint3D *intersectPt)
{
OGLVector3D			sphereToRay, intersectVector;
double				d, q, t, l2, r2, m2;


	// Prepare to intersect
	//
	// First calculate the vector from the sphere to the ray origin, its
	// length squared, the projection of this vector onto the ray direction,
	// and the squared radius of the sphere.

	OGLPoint3D_Subtract(sphereCenter, &ray->origin, &sphereToRay);
	l2 = OGLVector3D_Dot_NoPinDouble(&sphereToRay, &sphereToRay);			// the dot of itself gives us the length squared
	d  = OGLVector3D_Dot_NoPinDouble(&sphereToRay, &ray->direction);
	r2 = sphereRadius * sphereRadius;


	// If the sphere is behind the ray origin, they don't intersect

	if ((d < 0.0) && (l2 > r2))
		return(false);


	// Calculate the squared distance from the sphere center to the projection.
	// If it's greater than the radius then they don't intersect.

	m2 = (l2 - (d * d));
	if (m2 > r2)
		return(false);


	if (intersectPt != nil)
	{
		// Calculate the distance along the ray to the intersection point
		q = sqrt(r2 - m2);
		if (l2 > r2)
			t = d - q;
		else
			t = d + q;

		// Calculate the intersection point
		OGLVector3D_Scale(&ray->direction, t, &intersectVector);
		OGLPoint3D_Vector3D_Add(&ray->origin, &intersectVector, intersectPt);
	}

	return(true);
}



/******************** OGL: RAY GET HIT INFO: SKELETON *********************/
//
// Called from above when we know we've picked a Skeleton objNode.
// Now we just need to parse thru all of the Skeleton's triangles and see if our pick ray hits any.
// Then we keep track of the closest hit coord and that's what we'll return.
//

static Boolean OGL_RayGetHitInfo_Skeleton(OGLRay *ray, ObjNode *theNode, OGLPoint3D *worldHitCoord, OGLVector3D	*hitNormal)
{
short				i,numTriMeshes;
OGLPoint3D			where;
OGLVector3D			normal;
float				bestDist = 1000000;
Boolean				gotHit = false;
SkeletonObjDataType	*skeleton = theNode->Skeleton;
Byte				buffNum;

				/* GET SKELETON DATA */

	numTriMeshes = skeleton->skeletonDefinition->numDecomposedTriMeshes;

	buffNum = gGameViewInfoPtr->frameCount & 1;

			/***********************************/
			/* CHECK EACH MESH IN THE SKELETON */
			/***********************************/

	for (i = 0; i < numTriMeshes; i++)
	{
		if (OGL_DoesRayIntersectMesh(ray, &skeleton->deformedMeshes[buffNum][i], &where, &normal))
		{
				/* IS THIS INTERSECTION PT THE BEST ONE? */

			if (ray->distance < bestDist)
			{
				bestDist = ray->distance;
				*worldHitCoord = where;						// pass back the intersection point since it's the best one we've found so far.
				if (hitNormal)
					*hitNormal = normal;					// pass back the triangle normal
			}

			gotHit = true;
		}
	}

	ray->distance = bestDist;							// pass back the best dist too
	return(gotHit);
}


/******************* OGL:  DOES RAY INTERSECT MESH ***************************/
//
// ASSUMES THE MESH IS IN WORLD COORDINATES ALREADY!!!
//
// Determines if the input ray intersects any of the triangles in the input mesh,
// and returns the closest intersection coordinate if so.  We also return the
// distance to the intersection point.
//

static Boolean	OGL_DoesRayIntersectMesh(OGLRay *ray, MOVertexArrayData *mesh, OGLPoint3D *intersectionPt, OGLVector3D *triangleNormal)
{
int			numTriangles = mesh->numTriangles;
int			t,i;
OGLPoint3D	triPts[3];
OGLPoint3D	thisCoord;
OGLVector3D	thisNormal;
Boolean		gotHit = false;
float		bestDist = 1000000;

			/***************************/
			/* SCAN THRU ALL TRIANGLES */
			/***************************/

	for (t = 0; t < numTriangles; t++)
	{
				/* GET TRIANGLE POINTS */

		i = mesh->triangles[t].vertexIndices[0];
		triPts[0] = mesh->points[i];

		i = mesh->triangles[t].vertexIndices[1];
		triPts[1] = mesh->points[i];

		i = mesh->triangles[t].vertexIndices[2];
		triPts[2] = mesh->points[i];

				/* DOES OUR RAY HIT IT? */

		if (OGL_RayIntersectsTriangle(&triPts[0], ray, &thisCoord, &thisNormal))
		{
			if (ray->distance < bestDist)							// is this hit closer than any previous hit?
			{
				bestDist = ray->distance;
				*intersectionPt = thisCoord;						// pass back this intersection point since it's the best so far
				if (triangleNormal)									// do we want to return a triangle normal
					*triangleNormal = thisNormal;					// pass back the normal
			}
			gotHit = true;
		}
	}

	if (gotHit)
		ray->distance = bestDist;						// pass back the best distance

	return(gotHit);
}


/******************** OGL: RAY GET HIT INFO: DISPLAY GROUP *********************/
//
// Called from above when we know we've picked a Display Group genre objNode.
// Now we just need to see if our pick ray hits anything.
// Then we keep track of the closest hit coord and that's what we'll return.
//

Boolean OGL_RayGetHitInfo_DisplayGroup(OGLRay *ray, ObjNode *theNode, OGLPoint3D *worldHitCoord, OGLVector3D *hitNormal)
{
int	i;
float	bestDist = 1000000;
OGLPoint3D	point;
OGLVector3D	normal;
Boolean	gotHit = false;

		/* MAKE SURE WE HAVE WORLD-SPACE DATA FOR THIS OBJNODE */

	if (!theNode->HasWorldPoints)
		CalcDisplayGroupWorldPoints(theNode);



			/* SCAN THRU OBJNODE'S WORLD-SPACE DATA FOR A HIT */

	for (i = 0; i < MAX_MESHES_IN_MODEL; i++)
	{
		if (theNode->WorldMeshes[i].points)														// does this mesh exist?
		{
			if (OGL_DoesRayIntersectMesh(ray, &theNode->WorldMeshes[i], &point, &normal))		// does the ray hit this mesh?
			{
				if (ray->distance < bestDist)													// is this the closest hit so far?
				{
					bestDist = ray->distance;													// remember some info about this hit
					*worldHitCoord = point;														// pass back hit pt
					if (hitNormal)
						*hitNormal = normal;													// pass back hit normal
					gotHit = true;
				}
			}
		}
	}



	if (gotHit)
	{
		ray->distance = bestDist;					// pass back the best dist in the ray
		return(true);
	}


	return(false);

}


#pragma mark -


/*************** OGL: GET WORLD RAY AT SCREEN POINT *********************/
//
// Used for picking, this function returns the world-space ray at the screenCoord.
// screenCoord is in grafPort coordinates.
//

void OGL_GetWorldRayAtScreenPoint(OGLPoint2D *screenCoord, OGLRay *ray)
{
#if 0
GLdouble	model_view[16];
GLdouble	projection[16];
GLint		viewport[4];
float		realy;
double		dx,dy,dz;

			/* GET STATE DATA */

	glGetDoublev(GL_MODELVIEW_MATRIX, model_view);
	glGetDoublev(GL_PROJECTION_MATRIX, projection);
	glGetIntegerv(GL_VIEWPORT, viewport);


			/* FLIP Y */

	realy = (viewport[3] - (GLint)screenCoord->y) - 1;			// flip Y ([3] is the height value)


		/* GET 3D COORDINATES @ BACK PLANE */

	gluUnProject(screenCoord->x, realy, 1.0, model_view, projection, viewport, &dx, &dy ,&dz);

			/* CONVERT TO RAY */

	ray->origin = gGameViewInfoPtr->cameraPlacement[0].cameraLocation;		// ray origin @ camera location
	ray->direction.x = dx - ray->origin.x;							// calc vector of ray
	ray->direction.y = dy - ray->origin.y;
	ray->direction.z = dz - ray->origin.z;
	OGLVector3D_Normalize(&ray->direction, &ray->direction);		// normalize the ray vector
#else
		/* GET 3D COORDINATES @ BACK PLANE */

	float realy = (gGameWindowHeight - screenCoord->y) - 1.0f;	// flip Y ([3] is the height value)

	OGLPoint3D	winPt		= { screenCoord->x, realy, 1.0 };
	OGLVector2D	vpSize		= { gGameWindowWidth, gGameWindowHeight };
	OGLPoint2D	vpOffset	= { 0, 0 };
	OGLPoint3D	result		= { 0, 0, 0 };

	OGL_GluUnProject(
			&winPt,
			&gWorldToViewMatrix,		// modelview
			&gViewToFrustumMatrix,		// projection
			&vpOffset,
			&vpSize,
			&result);

		/* CONVERT TO RAY */

	ray->origin = gGameViewInfoPtr->cameraPlacement[0].cameraLocation;	// ray origin @ camera location
	ray->direction.x = result.x - ray->origin.x;						// calc vector of ray
	ray->direction.y = result.y - ray->origin.y;
	ray->direction.z = result.z - ray->origin.z;
	OGLVector3D_Normalize(&ray->direction, &ray->direction);		// normalize the ray vector
#endif
}


/******************** OGL: RAY INTERSECTS TRIANGLE ************************/

Boolean	OGL_RayIntersectsTriangle(OGLPoint3D *trianglePoints, OGLRay *ray, OGLPoint3D *intersectPt, OGLVector3D *triangleNormal)
{
OGLPlaneEquation	planeEquation;
float				distance;

	 			/* SEE IF RAY INTERSECTS THE TRIANGLE'S PLANE */

	if (OGL_DoesRayIntersectTrianglePlane(trianglePoints, ray, &planeEquation))
	{
					/* CALC INTERSECTION POINT ON PLANE */

		distance = ray->distance;
		intersectPt->x = ray->origin.x + ray->direction.x * distance;
		intersectPt->y = ray->origin.y + ray->direction.y * distance;
		intersectPt->z = ray->origin.z + ray->direction.z * distance;


				/* IS THE INTERSECTION PT INSIDE THE TRIANGLE? */

		if (OGLPoint3D_InsideTriangle3D(intersectPt, trianglePoints, &planeEquation.normal))
		{
			*triangleNormal = planeEquation.normal;						// pass back the triangle's normal
			return (true);
		}
	}

	return (false);

}


//******************** OGL: DOES RAY INTERSECT TRIANGLE PLANE ***********************/
//
// Returns true if the input ray intersects the plane of the triangle.
//

Boolean OGL_DoesRayIntersectTrianglePlane(const OGLPoint3D	triWorldPoints[], OGLRay *ray, OGLPlaneEquation	*planeEquation)
{
float	nDotD, nDotO,t;
float	nx, ny, nz;

 	OGL_ComputeTrianglePlaneEquation(triWorldPoints, planeEquation);

	nx = planeEquation->normal.x;
	ny = planeEquation->normal.y;
	nz = planeEquation->normal.z;

	nDotD = EmVector3D_Member_Dot(nx, ny, nz, ray->direction);

	if (OGLIsZero(nDotD))								// is ray parallel to plane?
		return (false);

	nDotO = EmVector3D_Member_Dot(nx, ny, nz, ray->origin);

	t = -(planeEquation->constant + nDotO) / nDotD;
	if (t < 0.0f)
		return(false);

	ray->distance = t;

	return (true);
}




/**************** OGL POINT3D: INSIDE TRIANGLE 3D *************************/
//
// Is the point which lies on the triangle plane insdie the triangle?

Boolean OGLPoint3D_InsideTriangle3D(const OGLPoint3D *point3D, const OGLPoint3D *trianglePoints, const OGLVector3D	*triangleNormal)
{
OGLPoint2D			point2D, verts[3];
Boolean				intersects;
float				alpha, beta;
float				u0, u1, u2, v0, v1, v2;

	OGLTriangle_3D2DComponentProjectionPoints(triangleNormal, point3D, trianglePoints, &point2D, verts);

	intersects = false;

	u0 = point2D.x  - verts[0].x;
	v0 = point2D.y  - verts[0].y;
	u1 = verts[1].x - verts[0].x;
	v1 = verts[1].y - verts[0].y;
	u2 = verts[2].x - verts[0].x;
	v2 = verts[2].y - verts[0].y;

	if (OGLIsZero(u1))
	{
		beta = u0 / u2;

		if ((-EPS <= beta) && (beta <= (1.0f + EPS)))								/* Test if 0.0 <= beta <= 1.0 */
		{
			alpha = (v0 - beta * v2) / v1;
			intersects = ((alpha >= -EPS) && ((alpha + beta) <= (1.0f + EPS))) ? true : false;
		}
	}
	else
	{
		beta = (v0 * u1 - u0 * v1) / (v2 * u1 - u2 * v1);

		if ( (-EPS <= beta) && (beta <= (1.0f + EPS)) )								/* Test if  0.0 <= beta <= 1.0 */
		{
			alpha = (u0 - beta * u2) / u1;

			intersects = ((alpha >= -EPS) && ((alpha + beta) <= (1.0f + EPS))) ? true : false;
		}
	}

	return intersects;
}


/*********** OGL TRIANGLE 3D3D COMPONENT PROJECTION POINTS ****************/

static void OGLTriangle_3D2DComponentProjectionPoints(const OGLVector3D *triangleNormal,	const OGLPoint3D *point3D, const OGLPoint3D	*triPoints,
													 OGLPoint2D *point2D, OGLPoint2D *verts2D)
{
float 	xComp, yComp, zComp;

	xComp = fabs(triangleNormal->x);
	yComp = fabs(triangleNormal->y);
	zComp = fabs(triangleNormal->z);

	if (xComp > yComp)
	{
		if (xComp > zComp)
		{
			/* Maximal X */
			point2D->x = point3D->y;
			point2D->y = point3D->z;

			verts2D[0].x = triPoints[0].y;
			verts2D[0].y = triPoints[0].z;

			verts2D[1].x = triPoints[1].y;
			verts2D[1].y = triPoints[1].z;

			verts2D[2].x = triPoints[2].y;
			verts2D[2].y = triPoints[2].z;
		}
		else
		{
			/* Maximal Z */
			point2D->x = point3D->x;
			point2D->y = point3D->y;

			verts2D[0].x = triPoints[0].x;
			verts2D[0].y = triPoints[0].y;

			verts2D[1].x = triPoints[1].x;
			verts2D[1].y = triPoints[1].y;

			verts2D[2].x = triPoints[2].x;
			verts2D[2].y = triPoints[2].y;
		}
	}
	else
	{
		if (yComp > zComp)
		{
			/* Maximal Y */
			point2D->x = point3D->z;
			point2D->y = point3D->x;

			verts2D[0].x = triPoints[0].z;
			verts2D[0].y = triPoints[0].x;

			verts2D[1].x = triPoints[1].z;
			verts2D[1].y = triPoints[1].x;

			verts2D[2].x = triPoints[2].z;
			verts2D[2].y = triPoints[2].x;
		}
		else
		{
			/* Maximal Z */
			point2D->x = point3D->x;
			point2D->y = point3D->y;

			verts2D[0].x = triPoints[0].x;
			verts2D[0].y = triPoints[0].y;

			verts2D[1].x = triPoints[1].x;
			verts2D[1].y = triPoints[1].y;

			verts2D[2].x = triPoints[2].x;
			verts2D[2].y = triPoints[2].y;
		}
	}
}


#pragma mark -



#pragma mark -
#pragma mark ==== LINE SEG COLLISION =====


/**************** OGL: DO LINE SEGMENT COLLISION ON OBJNODES ************************/
//
// Checks to see if the input line segment hits any eligible and visible objNodes in the scene.
//
// INPUT: 	p1/p2 = world-space line seg to collide with
//			cTypes = which objects do we want to collide against?
//
// OUTPUT:  ObjNode of object picked or nil
//			worldHitCoord = world-space coords of the pick intersection
//			ray->distance = distance from ray origin to the intersection point
//

ObjNode *OGL_DoLineSegmentCollision_ObjNodes(const OGLLineSegment *lineSeg, uint32_t statusFilter, uint32_t cTypes,
											 OGLPoint3D *worldHitCoord, OGLVector3D *worldHitFaceNormal, float *distToHit,
											 Boolean allowBBoxTests)
{
ObjNode		*thisNodePtr;
ObjNode		*bestObj = nil;
float		bestDist = 10000000;
OGLPoint3D	hitPt;
OGLVector3D	segVec, hitNormal;
float		hitDist;
int			gridX1, gridX2, gridY1, gridY2, gridZ1, gridZ2;
Boolean		hit;

			/* CALC GRID COORDS OF ENDPOINTS */
			//
			// If we're allowing the estimated bbox tests then let's assume the line segment
			// is fairly short.  Therefore, we can do this grid test to quickly
			// eliminate objects which are not within grid range.
			//
			// Otherwise, if we're not allowing bbox tests (using sphere tests instead),
			// then the line segment might be very large, so don't do the grid test.
			//

//	if (allowBBoxTests)
	{
		gridX1 = (int)lineSeg->p1.x / GRID_SIZE;
		gridY1 = (int)lineSeg->p1.y / GRID_SIZE;
		gridZ1 = (int)lineSeg->p1.z / GRID_SIZE;

		gridX2 = (int)lineSeg->p2.x / GRID_SIZE;
		gridY2 = (int)lineSeg->p2.y / GRID_SIZE;
		gridZ2 = (int)lineSeg->p2.z / GRID_SIZE;
	}

			/* CALCULATE THE LINE SEGMENT VECTOR */

	segVec.x = lineSeg->p2.x - lineSeg->p1.x;
	segVec.y = lineSeg->p2.y - lineSeg->p1.y;
	segVec.z = lineSeg->p2.z - lineSeg->p1.z;
	OGLVector3D_Normalize(&segVec, &segVec);


			/******************************************/
			/* TEST LINE SEGMENT AGAINST ALL OBJNODES */
			/******************************************/

	thisNodePtr = gFirstNodePtr;

	do
	{
				/* VERIFY NODE */

		if (thisNodePtr->Slot >= SLOT_OF_DUMB)								// stop here
			break;

		if (thisNodePtr->CType == INVALID_NODE_FLAG)						// make sure the node is even valid
			goto next;

		if (thisNodePtr->StatusBits & statusFilter)							// skip it if hidden
			goto next;

		if (thisNodePtr->CType & cTypes)									// only if pickable
		{
					/* CHECK THE GRID TO SEE IF CLOSE ENOUGH */

			if (allowBBoxTests)
			{
				if ((abs(thisNodePtr->GridX - gridX1) > GRID_SKIP_RANGE) &&					// either endpoint must be within n grid units
					(abs(thisNodePtr->GridX - gridX2) > GRID_SKIP_RANGE))
					goto next;

				if ((abs(thisNodePtr->GridY - gridY1) > GRID_SKIP_RANGE) &&
					(abs(thisNodePtr->GridY - gridY2) > GRID_SKIP_RANGE))
					goto next;

				if ((abs(thisNodePtr->GridZ - gridZ1) > GRID_SKIP_RANGE) &&
					(abs(thisNodePtr->GridZ - gridZ2) > GRID_SKIP_RANGE))
					goto next;
			}


					/* HANDLE SKELETONS, MODELS, & CUSTOM */

			switch(thisNodePtr->Genre)
			{
				case	SKELETON_GENRE:
						if (allowBBoxTests)
							hit = OGL_DoesLineSegmentIntersectBBox_Approx(lineSeg, &thisNodePtr->WorldBBox);		// skeletons have world-space bboxes which we can use for fast approx line->bbox tests
						else
							hit = OGL_DoesLineSegmentIntersectSphere(lineSeg, &segVec, &thisNodePtr->Coord, thisNodePtr->BoundingSphereRadius, nil);

						if (hit)
						{
							if (OGL_LineSegGetHitInfo_Skeleton(lineSeg, thisNodePtr, &hitPt, &hitNormal, &hitDist))		// does ray intersect skeleton?
							{
								if (hitDist < bestDist)								// is this the best hit so far?
								{
									bestDist = hitDist;
									bestObj = thisNodePtr;
									if (worldHitCoord)
										*worldHitCoord = hitPt;
									if (worldHitFaceNormal)
										*worldHitFaceNormal = hitNormal;
								}
							}
						}
						break;

				case	DISPLAY_GROUP_GENRE:
						if (OGL_DoesLineSegmentIntersectSphere(lineSeg, &segVec, &thisNodePtr->Coord, thisNodePtr->BoundingSphereRadius, nil))
						{
							if (OGL_LineSegGetHitInfo_DisplayGroup(lineSeg, thisNodePtr, &hitPt, &hitNormal, &hitDist))	// does line seg hit display group geometry?
							{
								if (hitDist < bestDist)						// is this the best hit so far?
								{
									bestDist = hitDist;
									bestObj = thisNodePtr;
									if (worldHitCoord)
										*worldHitCoord = hitPt;
									if (worldHitFaceNormal)
										*worldHitFaceNormal = hitNormal;
								}
							}
						}
						break;

				case	CUSTOM_GENRE:									// ignore this or do custom handling
						break;

				default:
						DoFatalAlert("OGL_DoLineSegmentCollision: unsupported genre");
			}
		}

next:
		thisNodePtr = thisNodePtr->NextNode;								// next node
	}
	while (thisNodePtr != nil);

	if (distToHit)
		*distToHit = bestDist;

	return(bestObj);
}



/****************** OGL:  LINE SEGMENT COLLISION ON TERRAIN ************************/
//
// Determines if the input line segment intersects any terrain geometry
//

Boolean OGL_LineSegmentCollision_Terrain(const OGLLineSegment *lineSeg, OGLPoint3D *worldHitCoord, OGLVector3D *terrainNormal, float *distToHit)
{
short	i;
MOVertexArrayData	*mesh;
Boolean				hit = false;
OGLPoint3D			hitCoord;
OGLVector3D			hitNormal;
float				dist;
float				bestDist = 10000000;
OGLVector3D			segVec;


			/* CALCULATE THE LINE SEGMENT VECTOR */

	segVec.x = lineSeg->p2.x - lineSeg->p1.x;
	segVec.y = lineSeg->p2.y - lineSeg->p1.y;
	segVec.z = lineSeg->p2.z - lineSeg->p1.z;
	OGLVector3D_Normalize(&segVec, &segVec);


			/*******************************/
			/* TEST AGAINST ALL SUPERTILES */
			/*******************************/

	for (i = 0; i < MAX_SUPERTILES; i++)
	{
		OGLBoundingBox		*bbox;

		if (gSuperTileMemoryList[i].mode == SUPERTILE_MODE_FREE)				// look for used / active supertiles
			continue;

				/* SEE IF LINE SEGMENT INTERSECTS THE BBOX */
				//
				// Remember tha the bbox test is approximate and can give false positives!
				//
#if 1

		bbox = &gSuperTileMemoryList[i].bBox;
		if (!OGL_DoesLineSegmentIntersectBBox_Approx(lineSeg, bbox))
			continue;

#else

	{
		float				radius;
		float				sqrt2 = 1.4142135f;
		OGLPoint3D			origin;

			/********************************************************/
			/* DOES RAY INTERSECT THIS SUPERTILE'S BOUNDING SPEHRE? */
			/********************************************************/

					/* CALCULATE THE SUPERTILE RADIUS */

		dist = gSuperTileMemoryList[i].bBox.max.y - gSuperTileMemoryList[i].bBox.min.y;		// is height taller than supertile width/depth size?
		if (dist > gTerrainSuperTileUnitSize)
			radius = dist;
		else
			radius = gTerrainSuperTileUnitSize;

		radius = radius * .5f * sqrt2;


					/* DOES LINE HIT THE SPHERE? */

		origin.x = gSuperTileMemoryList[i].x;									// get b-sphere coords
		origin.y = gSuperTileMemoryList[i].y;
		origin.z = gSuperTileMemoryList[i].z;

		if (!OGL_DoesLineSegmentIntersectSphere(lineSeg, &segVec, &origin, radius, nil))	// see if ray hit sphere
			continue;
	}
#endif

			/******************************************/
			/* SEE IF RAY HIT ANY SUPERTILE TRIANGLES */
			/******************************************/

		mesh = gSuperTileMemoryList[i].meshData;								// get ptr to supertile's mesh data

		if (!OGL_DoesLineSegIntersectMesh(lineSeg, &segVec, mesh, &hitCoord, &hitNormal, &dist))
			continue;

		if (dist < bestDist)													 // is this the closest hit so far?
		{
					/* REMEMBER THIS HIT AS THE BEST SO FAR */

			bestDist = dist;
			*worldHitCoord = hitCoord;
			if (terrainNormal)
				*terrainNormal = hitNormal;

			hit = true;
		}
	}

	if (distToHit)
		*distToHit = bestDist;							// return the distance to the best hit

	return(hit);
}



/****************** OGL:  LINE SEGMENT COLLISION ON FENCES ************************/
//
// Determines if the input line segment intersects any fence geometry
//

Boolean OGL_LineSegmentCollision_Fence(const OGLLineSegment *lineSeg, OGLPoint3D *worldHitCoord, OGLVector3D *hitNormal, float *distToHit)
{
Boolean				hit = false;
OGLPoint3D			hitCoord;
OGLVector3D			normal;
float				dist;
float				bestDist = 10000000;
OGLVector3D			segVec, bestNormal;
OGLBoundingBox		*bbox;

	gPickAllTrianglesAsDoubleSided = true;							// we want to allow backfaces to get hit


			/* CALCULATE THE LINE SEGMENT VECTOR */

	segVec.x = lineSeg->p2.x - lineSeg->p1.x;
	segVec.y = lineSeg->p2.y - lineSeg->p1.y;
	segVec.z = lineSeg->p2.z - lineSeg->p1.z;
	OGLVector3D_Normalize(&segVec, &segVec);


			/***************************/
			/* TEST AGAINST ALL FENCES */
			/***************************/

	for (int i = 0; i < gNumFences; i++)
	{
				/* SKIP FENCE_TYPE_INVISIBLEBLOCKENEMY */
				//
				// Nano2 source port HACK: Only projectiles (Turrets, Blaster, HeatSeeker, Bomb)
				// ever call this function, and we DON'T want them to explode when colliding with
				// an invisible fence.
				//

		if (gFenceList[i].type == FENCE_TYPE_INVISIBLEBLOCKENEMY)
		{
			continue;
		}

				/* SEE IF LINE SEGMENT INTERSECTS THE BBOX */
				//
				// Remember tha the bbox test is approximate and can give false positives!
				//

		bbox = &gFenceList[i].bBox;
		if (!OGL_DoesLineSegmentIntersectBBox_Approx(lineSeg, bbox))
			continue;


			/***************************************/
			/* SEE IF LINE HIT ANY FENCE TRIANGLES */
			/***************************************/

		if (!OGL_DoesLineSegIntersectMesh(lineSeg, &segVec, &gFenceTriMeshData[i][0], &hitCoord, &normal, &dist))
			continue;

		if (dist < bestDist)													 // is this the closest hit so far?
		{
					/* REMEMBER THIS HIT AS THE BEST SO FAR */

			bestDist = dist;
			*worldHitCoord = hitCoord;
			bestNormal = normal;
			hit = true;
		}
	}


			/* SINCE FENCES DO DOUBLE-SIDED COLLISION WE NEED TO FIX THE NORMAL */
			//
			//	When a backface is hit the normal is actually going to be facing away from the direction of our line segment.
			//	This might cause problems for certain hit functions, so we need to flip the normal to make sure it is always
			// 	facing the line segment vector (p1 -> p2).
			//

	gPickAllTrianglesAsDoubleSided = false;							// always set this to FALSE when exiting!

	if (hitNormal)													// only bother if we're returning the normal
	{
		if (OGLVector3D_Dot_NoPin(&segVec, &bestNormal) > 0.0f)		// if normal is facing away then flip it
		{
			bestNormal.x = -bestNormal.x;
			bestNormal.y = -bestNormal.y;
			bestNormal.z = -bestNormal.z;
		}
		*hitNormal = bestNormal;							// pass back the normal
	}




			/* RETURN */

	if (distToHit)
		*distToHit = bestDist;							// return the distance to the best hit


	return(hit);
}


/****************** OGL:  LINE SEGMENT COLLISION ON WATER ************************/
//
// Determines if the input line segment intersects any water geometry
//

Boolean OGL_LineSegmentCollision_Water(const OGLLineSegment *lineSeg, OGLPoint3D *worldHitCoord, OGLVector3D *hitNormal, float *distToHit)
{
short	i;
Boolean				hit = false;
OGLPoint3D			hitCoord;
OGLVector3D			normal;
float				dist;
float				bestDist = 10000000;
OGLVector3D			segVec, bestNormal;

	gPickAllTrianglesAsDoubleSided = true;							// we want to allow backfaces to get hit


			/* CALCULATE THE LINE SEGMENT VECTOR */

	segVec.x = lineSeg->p2.x - lineSeg->p1.x;
	segVec.y = lineSeg->p2.y - lineSeg->p1.y;
	segVec.z = lineSeg->p2.z - lineSeg->p1.z;
	OGLVector3D_Normalize(&segVec, &segVec);


			/***************************/
			/* TEST AGAINST ALL FENCES */
			/***************************/

	for (i = 0; i < gNumWaterPatches; i++)
	{
				/* SEE IF LINE SEGMENT INTERSECTS THE BBOX */
				//
				// Remember tha the bbox test is approximate and can give false positives!
				//

		if (!OGL_DoesLineSegmentIntersectBBox_Approx(lineSeg, &gWaterBBox[i]))
			continue;


			/***************************************/
			/* SEE IF LINE HIT ANY FENCE TRIANGLES */
			/***************************************/

		if (!OGL_DoesLineSegIntersectMesh(lineSeg, &segVec, &gWaterTriMeshData[i], &hitCoord, &normal, &dist))
			continue;

		if (dist < bestDist)													 // is this the closest hit so far?
		{
					/* REMEMBER THIS HIT AS THE BEST SO FAR */

			bestDist = dist;
			*worldHitCoord = hitCoord;
			bestNormal = normal;
			hit = true;
		}
	}


			/* SINCE WATER DO DOUBLE-SIDED COLLISION WE NEED TO FIX THE NORMAL */
			//
			//	When a backface is hit the normal is actually going to be facing away from the direction of our line segment.
			//	This might cause problems for certain hit functions, so we need to flip the normal to make sure it is always
			// 	facing the line segment vector (p1 -> p2).
			//

	gPickAllTrianglesAsDoubleSided = false;							// always set this to FALSE when exiting!

	if (hitNormal)													// only bother if we're returning the normal
	{
		if (OGLVector3D_Dot_NoPin(&segVec, &bestNormal) > 0.0f)		// if normal is facing away then flip it
		{
			bestNormal.x = -bestNormal.x;
			bestNormal.y = -bestNormal.y;
			bestNormal.z = -bestNormal.z;
		}
		*hitNormal = bestNormal;							// pass back the normal
	}




			/* RETURN */

	if (distToHit)
		*distToHit = bestDist;							// return the distance to the best hit


	return(hit);
}



/******************** OGL: PICK AND GET HIT INFO: DISPLAY GROUP *********************/
//
// Called from above when we know we've picked a Display Group genre objNode.
// Now we just need to traverse the Base Group, transform the data to world-space, and and see if our pick ray hits anything.
// Then we keep track of the closest hit coord and that's what we'll return.
//

static Boolean OGL_LineSegGetHitInfo_DisplayGroup(const OGLLineSegment *lineSeg, ObjNode *theNode, OGLPoint3D *worldHitCoord,
												OGLVector3D *hitNormal, float *distToHit)
{
int		i;
OGLPoint3D	coord;
OGLVector3D	normal, lineVec;
float		dist;
float		bestDist = 10000000;
Boolean		gotHit = false;

		/* CREATE A GLOBAL RAY */

	lineVec.x = lineSeg->p2.x - lineSeg->p1.x;
	lineVec.y = lineSeg->p2.y - lineSeg->p1.y;
	lineVec.z = lineSeg->p2.z - lineSeg->p1.z;
	OGLVector3D_Normalize(&lineVec, &lineVec);


		/* MAKE SURE WE HAVE WORLD-SPACE DATA FOR THIS OBJNODE */

	if (!theNode->HasWorldPoints)
		CalcDisplayGroupWorldPoints(theNode);

			/* SCAN THRU OBJNODE'S WORLD-SPACE DATA FOR A HIT */

	for (i = 0; i < MAX_MESHES_IN_MODEL; i++)
	{
		if (theNode->WorldMeshes[i].points)														// does this mesh exist?
		{
			if (OGL_DoesLineSegIntersectMesh2(lineSeg, &lineVec, theNode->WorldPlaneEQs[i], &theNode->WorldMeshes[i],
											 &coord, &normal, &dist))							// does the line segment hit this mesh?
			{
				if (dist < bestDist)															// is this the closest hit so far?
				{
					bestDist = dist;															// remember some info about this hit
					*worldHitCoord = coord;
					if (hitNormal)
						*hitNormal = normal;
					gotHit = true;
				}
			}
		}
	}


	if (gotHit)
	{
		*distToHit = bestDist;
		return(true);
	}

	return(false);
}

/******************** OGL:  DOES LINE SEGMENT INTERSECT SPHERE *************************/
//
// Returns TRUE if the input line seg intersects the input sphere.
// also returns the intersect point if intersectPt != nil
//
// This is actually a variant of the Ray intersect function above.  A line segment
// is actually 2 opposite rays.
//

Boolean OGL_DoesLineSegmentIntersectSphere(const OGLLineSegment *lineSeg, const OGLVector3D *segVector,
											 OGLPoint3D *sphereCenter, float sphereRadius, OGLPoint3D *intersectPt)
{
OGLVector3D			sphereToEndpoint, intersectVector, rayDir;
double				d, l2, r2, m2;
double				l2b, db;

					/*********************************************************************/
					/* DO THE USUAL RAY->SPHERE INTERSECT TEST WITH ONE OF THE ENDPOINTS */
					/*********************************************************************/

	// create a ray vector from p1 -> p2

	if (segVector == nil)
	{
		rayDir.x = lineSeg->p2.x - lineSeg->p1.x;
		rayDir.y = lineSeg->p2.y - lineSeg->p1.y;
		rayDir.z = lineSeg->p2.z - lineSeg->p1.z;
		OGLVector3D_Normalize(&rayDir, &rayDir);
	}
	else
		rayDir = *segVector;


	// Calculate the vector from the sphere to the p1 endpoint, its
	// length squared, the projection of this vector onto the ray direction,
	// and the squared radius of the sphere.

	OGLPoint3D_Subtract(sphereCenter, &lineSeg->p1, &sphereToEndpoint);
	l2 = OGLVector3D_Dot_NoPinDouble(&sphereToEndpoint, &sphereToEndpoint);			// the dot of itself gives us the length squared
	d  = OGLVector3D_Dot_NoPinDouble(&sphereToEndpoint, &rayDir);
	r2 = sphereRadius * sphereRadius;



	// If the sphere is behind the endpoint, they don't intersect
	if (d < 0.0 && l2 > r2)
		return(false);



	// Calculate the squared distance from the sphere center to the projection.
	// If it's greater than the radius then they don't intersect.
	m2 = (l2 - (d * d));
	if (m2 > r2)
		return(false);



				/******************************/
				/* NOW CHECK THE 2ND ENDPOINT */
				/******************************/
				//
				// We now know that the ray from p1->p2 does intersect
				// the sphere, so if p2 is also good then we have a line seg hit
				//

	{
		rayDir.x = -rayDir.x;													// negate the ray direction
		rayDir.y = -rayDir.y;
		rayDir.z = -rayDir.z;

		OGLPoint3D_Subtract(sphereCenter, &lineSeg->p2, &sphereToEndpoint);
		l2b = OGLVector3D_Dot_NoPinDouble(&sphereToEndpoint, &sphereToEndpoint);		// the dot of itself gives us the length squared
		db  = OGLVector3D_Dot_NoPinDouble(&sphereToEndpoint, &rayDir);

		if (db < 0.0 && l2b > r2)												// If the sphere is behind the endpoint, they don't intersect
			return(false);
	}


				/*****************/
				/* WE HAVE A HIT */
				/*****************/

	if (intersectPt != nil)
	{
		double	t;
		double 	q = sqrt(r2 - m2);							// Calculate the distance along the p1 ray to the intersection point
		if (l2 > r2)
			t = d - q;
		else
			t = d + q;

		// Calculate the intersection point
		OGLVector3D_Scale(&rayDir, t, &intersectVector);
		OGLPoint3D_Vector3D_Add(&lineSeg->p1, &intersectVector, intersectPt);
	}

	return(true);
}


/****************** OGL:  DOES LINE SEGMENT INTERSECT BOUNDING BOX (APPROX) *****************************/
//
// IMPORTANT:  This function can return false positives!  In the case where a line segment crosses 2 planes
//				of any side of the bbox it will return TRUE when this might not actually be a hit:
//
//					 		o
//							  x
// 							    x				<<====== THIS CASE WILL FAIL!
//				o-------------o  x
//				|             |    x
//				|             |		o
//				|             |
//				|             |
//				|             |
//				o-------------o
//
//	So, this function should only be used when we know the line segments are relatively short.  This way any false
//	positives will not be a big deal;  the collision will proceed to do polygon-level tests which will throw out any
//	non-hits anyway.
//

static Boolean OGL_DoesLineSegmentIntersectBBox_Approx(const OGLLineSegment *lineSeg, const OGLBoundingBox *bbox)
{
const OGLPoint3D *p1 = &lineSeg->p1;
const OGLPoint3D *p2 = &lineSeg->p2;

	if ((p1->x < bbox->min.x) && (p2->x < bbox->min.x))			// if both endpoints are to the left of the bbox...
		return(false);
	if ((p1->x > bbox->max.x) && (p2->x > bbox->max.x))			// if both endpoints are to the right of the bbox...
		return(false);

	if ((p1->z < bbox->min.z) && (p2->z < bbox->min.z))			// if both endpoints are in back of the bbox...
		return(false);
	if ((p1->z > bbox->max.z) && (p2->z > bbox->max.z))			// if both endpoints are in front of the bbox...
		return(false);

	if ((p1->y < bbox->min.y) && (p2->y < bbox->min.y))			// if both endpoints are in under the bbox...
		return(false);
	if ((p1->y > bbox->max.y) && (p2->y > bbox->max.y))			// if both endpoints are in above the bbox...
		return(false);

	return(true);
}


/******************* OGL:  DOES LINE SEGMENT INTERSECT MESH ***************************/
//
// ASSUMES THE MESH IS IN WORLD COORDINATES ALREADY!!!
//
// Determines if the global seg intersects any of the triangles in the input mesh,
// and returns the closest intersection coordinate if so.  We also return the
// distance to the intersection point.
//

static Boolean	OGL_DoesLineSegIntersectMesh(const OGLLineSegment *lineSeg, OGLVector3D *lineVec, MOVertexArrayData *mesh,
											OGLPoint3D *intersectionPt, OGLVector3D *hitNormal, float *distToIntersection)
{
int			numTriangles = mesh->numTriangles;
int			t,i;
OGLPoint3D	triPts[3];
OGLPoint3D	thisCoord;
Boolean		gotHit = false;
float		bestDist = 10000000;
float		distFromP1ToPlane;
OGLVector3D	normal;

			/***************************/
			/* SCAN THRU ALL TRIANGLES */
			/***************************/

	for (t = 0; t < numTriangles; t++)
	{
				/* GET TRIANGLE POINTS */

		i = mesh->triangles[t].vertexIndices[0];
		triPts[0] = mesh->points[i];

		i = mesh->triangles[t].vertexIndices[1];
		triPts[1] = mesh->points[i];

		i = mesh->triangles[t].vertexIndices[2];
		triPts[2] = mesh->points[i];

				/* DOES OUR LINE HIT IT? */

		if (OGL_LineSegIntersectsTriangle(lineSeg, lineVec, &triPts[0], &thisCoord, &normal, &distFromP1ToPlane))
		{
			if (distFromP1ToPlane < bestDist)							// is this hit closer than any previous hit?
			{
				bestDist = distFromP1ToPlane;
				if (hitNormal)
					*hitNormal = normal;								// keep the best face normal that we've hit
				*intersectionPt = thisCoord;							// pass back this intersection point since it's the best so far
			}
			gotHit = true;
		}
	}

	*distToIntersection = bestDist;									// pass back the best distance that we found (if any)
	return(gotHit);
}


/******************* OGL:  DOES LINE SEGMENT INTERSECT MESH 2***************************/
//
// Same as above, but also takes an PlaneEQ array
//


static Boolean	OGL_DoesLineSegIntersectMesh2(const OGLLineSegment *lineSeg, OGLVector3D *lineVec, OGLPlaneEquation *planeEQ, MOVertexArrayData *mesh,
												OGLPoint3D *intersectionPt, OGLVector3D *hitNormal, float *distToIntersection)
{
int			numTriangles = mesh->numTriangles;
int			t,i;
OGLPoint3D	triPts[3];
OGLPoint3D	thisCoord;
Boolean		gotHit = false;
float		bestDist = 10000000;
float		distFromP1ToPlane;

			/***************************/
			/* SCAN THRU ALL TRIANGLES */
			/***************************/

	for (t = 0; t < numTriangles; t++)
	{
				/* GET TRIANGLE POINTS */

		i = mesh->triangles[t].vertexIndices[0];
		triPts[0] = mesh->points[i];

		i = mesh->triangles[t].vertexIndices[1];
		triPts[1] = mesh->points[i];

		i = mesh->triangles[t].vertexIndices[2];
		triPts[2] = mesh->points[i];

				/* DOES OUR RAY HIT IT? */

		if (OGL_LineSegIntersectsTriangle2(lineSeg, lineVec, &planeEQ[t], &triPts[0], &thisCoord, &distFromP1ToPlane))
		{
			if (distFromP1ToPlane < bestDist)							// is this hit closer than any previous hit?
			{
				bestDist = distFromP1ToPlane;
				if (hitNormal)
					*hitNormal = planeEQ[t].normal;						// keep the best face normal that we've hit
				*intersectionPt = thisCoord;							// pass back this intersection point since it's the best so far
			}
			gotHit = true;
		}
	}

	*distToIntersection = bestDist;									// pass back the best distance that we found (if any)
	return(gotHit);
}


/******************** OGL: LINE SEGMENT INTERSECTS TRIANGLE ************************/

static Boolean	OGL_LineSegIntersectsTriangle(const OGLLineSegment *lineSeg, OGLVector3D *lineVector, OGLPoint3D *trianglePoints, OGLPoint3D *intersectPt,
											OGLVector3D *hitNormal, float *distFromP1ToPlane)
{

	 			/* SEE IF LINE SEG INTERSECTS THE TRIANGLE'S PLANE */
	 			//
	 			// Calling this also computes the plane's normal and passes it back in hitNormal
	 			//

	if (OGL_DoesLineSegIntersectTrianglePlane(lineSeg, lineVector, trianglePoints, distFromP1ToPlane, hitNormal))
	{

					/* CALC INTERSECTION POINT ON PLANE */

		intersectPt->x = lineSeg->p1.x + lineVector->x * *distFromP1ToPlane;
		intersectPt->y = lineSeg->p1.y + lineVector->y * *distFromP1ToPlane;
		intersectPt->z = lineSeg->p1.z + lineVector->z * *distFromP1ToPlane;


				/* IS THE INTERSECTION PT INSIDE THE TRIANGLE? */

		if (OGLPoint3D_InsideTriangle3D(intersectPt, trianglePoints, hitNormal))
			return (true);
	}

	return (false);

}


/******************** OGL: LINE SEGMENT INTERSECTS TRIANGLE 2************************/
//
// This version is passed the plane EQ
//

static Boolean	OGL_LineSegIntersectsTriangle2(const OGLLineSegment *lineSeg, OGLVector3D *lineVector, OGLPlaneEquation *planeEQ,
												OGLPoint3D *trianglePoints, OGLPoint3D *intersectPt, float *distFromP1ToPlane)
{
	 			/* SEE IF RAY INTERSECTS THE TRIANGLE'S PLANE */

	if (OGL_DoesLineSegIntersectTrianglePlane2(lineSeg, lineVector, planeEQ, distFromP1ToPlane))
	{
					/* CALC INTERSECTION POINT ON PLANE */

		intersectPt->x = lineSeg->p1.x + lineVector->x * *distFromP1ToPlane;
		intersectPt->y = lineSeg->p1.y + lineVector->y * *distFromP1ToPlane;
		intersectPt->z = lineSeg->p1.z + lineVector->z * *distFromP1ToPlane;


				/* IS THE INTERSECTION PT INSIDE THE TRIANGLE? */

		if (OGLPoint3D_InsideTriangle3D(intersectPt, trianglePoints, &planeEQ->normal))
			return (true);
	}

	return (false);

}



//******************** OGL: DOES LINE SEGMENT INTERSECT TRIANGLE PLANE ***********************/
//
// Returns true if the global line data intersects the plane of the triangle.
//
// NOTE:  this only works for DIRECTIONAL line segments!!!  Line segments which go from P1 to P2.
//		Line segments which intersect from P2 to P1 will not return a valid hit.
//

static Boolean OGL_DoesLineSegIntersectTrianglePlane(const OGLLineSegment *lineSeg, OGLVector3D *lineVec, OGLPoint3D	triWorldPoints[],
													float *distFromP1ToPlane, OGLVector3D *planeNormal)
{
float				nDotD, nDotO,t;
float				nx, ny, nz, oneOverDotD;
OGLPlaneEquation	planeEQ;

			/* GET TRIANGLE NORMAL */

 	OGL_ComputeTrianglePlaneEquation(triWorldPoints, &planeEQ);
	nx = planeEQ.normal.x;
	ny = planeEQ.normal.y;
	nz = planeEQ.normal.z;

	if (planeNormal)
		*planeNormal = planeEQ.normal;										// pass the normal back

			/* IS PARALLEL TO OR BEHIND PLANE? */

	nDotD = EmVector3D_Member_Dot(nx, ny, nz, (*lineVec));					// calc dot between normal and the line ray

	if (!gPickAllTrianglesAsDoubleSided)									// do we want to allow backface hits?
	{
		if (nDotD >= EPS)													// if ray is pointing away from plane then bail since we're not interested in rays hitting the triangle from behind
			return (false);
	}

	oneOverDotD = -1.0f / nDotD;											// let's calculate the -1/d since we use it twice


			/* SEE IF RAY FROM P1 HITS IT */

	nDotO = EmVector3D_Member_Dot(nx, ny, nz, (lineSeg->p1));
	t = (planeEQ.constant + nDotO) * oneOverDotD;
	if (t < 0.0f)
		return(false);

	*distFromP1ToPlane = t;


		/* IF P2 ALSO HITS THEN BOTH PTS ARE ON SAME SIDE OF PLANE, THUS NO INTERSECT */
		//
		// We know that the vector from p1 intersects the plane, but if the same vector from p2
		// also hits the plane then both endpoints were in front of the plane.  The line segment
		// can only be intersecting the plane if each endpoint is on opposite sides.
		//

	nDotO = EmVector3D_Member_Dot(nx, ny, nz, (lineSeg->p2));
	t = (planeEQ.constant + nDotO) * oneOverDotD;
	if (t >= 0.0f)
		return(false);


	return (true);
}

//******************** OGL: DOES LINE SEGMENT INTERSECT TRIANGLE PLANE 2 ***********************/
//
// Returns true if the global line data intersects the plane of the triangle.
//
// NOTE:  this only works for DIRECTIONAL line segments!!!  Line segments which go from P1 to P2.
//		Line segments which intersect from P2 to P1 will not return a valid hit.
//

static Boolean OGL_DoesLineSegIntersectTrianglePlane2(const OGLLineSegment *lineSeg, OGLVector3D *lineVec, OGLPlaneEquation *planeEQ, float *distFromP1ToPlane)
{
float	nDotD, nDotO,t;
float	nx, ny, nz, oneOverDotD;

	nx = planeEQ->normal.x;
	ny = planeEQ->normal.y;
	nz = planeEQ->normal.z;


			/* IS PARALLEL TO OR BEHIND PLANE? */

	nDotD = EmVector3D_Member_Dot(nx, ny, nz, (*lineVec));				// calc dot between normal and the line ray
	if (!gPickAllTrianglesAsDoubleSided)								// do we want to allow backface hits?
	{
		if (nDotD >= EPS)												// if ray is pointing away from plane then bail since we're not interested in rays hitting the triangle from behind
			return (false);
	}

	oneOverDotD = -1.0f / nDotD;										// let's calculate the -1/d since we use it twice

			/* SEE IF RAY FROM P1 HITS IT */

	nDotO = EmVector3D_Member_Dot(nx, ny, nz, (lineSeg->p1));
	t = (planeEQ->constant + nDotO) * oneOverDotD;
	if (t < 0.0f)
		return(false);

	*distFromP1ToPlane = t;


		/* IF P2 ALSO HITS THEN BOTH PTS ARE ON SAME SIDE OF PLANE, THUS NO INTERSECT */
		//
		// We know that the vector from p1 intersects the plane, but if the same vector from p2
		// also hits the plane then both endpoints were in front of the plane.  The line segment
		// can only be intersecting the plane if each endpoint is on opposite sides.
		//

	nDotO = EmVector3D_Member_Dot(nx, ny, nz, (lineSeg->p2));
	t = (planeEQ->constant + nDotO) * oneOverDotD;
	if (t >= 0.0f)
		return(false);


	return (true);
}



/******************** OGL: LINE SEGMENT GET HIT INFO: SKELETON *********************/
//
// Called from above when we know we've picked a Skeleton objNode.
// Now we just need to parse thru all of the Skeleton's triangles and see if our line seg hits any.
// Then we keep track of the closest hit coord and that's what we'll return.
//

static Boolean OGL_LineSegGetHitInfo_Skeleton(const OGLLineSegment *lineSeg, ObjNode *theNode,
											OGLPoint3D *worldHitCoord, OGLVector3D *hitNormal, float *hitDist)
{
OGLPoint3D	where;
float		thisDist, bestDist = 100000000;
Boolean		gotHit = false;
OGLVector3D	thisNormal, lineVec;
Byte		buffNum;

		/* CREATE A GLOBAL RAY */

	lineVec.x = lineSeg->p2.x - lineSeg->p1.x;
	lineVec.y = lineSeg->p2.y - lineSeg->p1.y;
	lineVec.z = lineSeg->p2.z - lineSeg->p1.z;
	OGLVector3D_Normalize(&lineVec, &lineVec);


				/* GET SKELETON DATA */

	int numTriMeshes = theNode->Skeleton->skeletonDefinition->numDecomposedTriMeshes;
//	skelType = theNode->Type;

//	buffNum = theNode->Skeleton->activeBuffer;
	buffNum = gGameViewInfoPtr->frameCount & 1;

			/***********************************/
			/* CHECK EACH MESH IN THE SKELETON */
			/***********************************/

	for (int i = 0; i < numTriMeshes; i++)
	{
		if (OGL_DoesLineSegIntersectMesh(lineSeg, &lineVec, &theNode->Skeleton->deformedMeshes[buffNum][i],
										&where, &thisNormal, &thisDist))
		{
				/* IS THIS INTERSECTION PT THE BEST ONE? */

			if (thisDist < bestDist)
			{
				bestDist = thisDist;
				*worldHitCoord = where;							// pass back the intersection point since it's the best one we've found so far.

				if (hitNormal)
					*hitNormal = thisNormal;
			}

			gotHit = true;
		}
	}

	*hitDist = bestDist;

	return(gotHit);
}


#pragma mark -
#pragma mark ====== SPHERE COLLISION =======


/**************** OGL: DO SPHERE COLLISION ON OBJNODES ************************/
//
// Checks to see if the input bounding sphere hits any eligible objNodes in the scene.
//

ObjNode *OGL_DoSphereCollision_ObjNodes(const OGLBoundingSphere *sphere, uint32_t statusFilter, uint32_t cTypes)
{
ObjNode		*thisNodePtr;
int			gridX, gridY, gridZ;
OGLBoundingSphere	sphere2;

			/* CALC GRID COORDS OF ENDPOINTS */

	gridX = (int)sphere->origin.x / GRID_SIZE;
	gridY = (int)sphere->origin.y / GRID_SIZE;
	gridZ = (int)sphere->origin.z / GRID_SIZE;




			/********************************************/
			/* TEST SPHERE SEGMENT AGAINST ALL OBJNODES */
			/********************************************/

	thisNodePtr = gFirstNodePtr;

	do
	{
				/* VERIFY NODE */

		if (thisNodePtr->Slot >= SLOT_OF_DUMB)								// stop here
			break;

		if (thisNodePtr->CType == INVALID_NODE_FLAG)						// make sure the node is even valid
			goto next;

		if (thisNodePtr->StatusBits & statusFilter)							// skip it if hidden
			goto next;

		if (thisNodePtr->CType & cTypes)									// only if pickable
		{
					/* CHECK THE GRID TO SEE IF CLOSE ENOUGH */

			if (abs(thisNodePtr->GridX - gridX) > GRID_SKIP_RANGE)			// sphere origin must be within grid range of object's center
				goto next;

			if (abs(thisNodePtr->GridY - gridY) > GRID_SKIP_RANGE)
				goto next;

			if (abs(thisNodePtr->GridZ - gridZ) > GRID_SKIP_RANGE)
				goto next;


					/* DO THE BOUNDING SPHERES INTERSECT? */

			sphere2.radius = thisNodePtr->BoundingSphereRadius;				// build a sphere for the target node
			sphere2.origin = thisNodePtr->Coord;

			if (OGL_DoesSphereIntersectSphere(sphere, &sphere2))
			{
						/* HANDLE SKELETONS, MODELS, & CUSTOM */

				switch(thisNodePtr->Genre)
				{
					case	SKELETON_GENRE:
							if (OGL_DoesSkeletonIntersectSphere(sphere, thisNodePtr))		// does sphere intersect skeleton?
								return(thisNodePtr);
							break;

					case	DISPLAY_GROUP_GENRE:
							if (OGL_DoesDisplayGroupIntersectSphere(sphere, thisNodePtr))	// does sphere hit display group geometry?
								return(thisNodePtr);
							break;

					case	CUSTOM_GENRE:									// ignore this or do custom handling
							break;

					default:
							DoFatalAlert("OGL_DoSphereCollision_ObjNodes: unsupported genre");
				}
			}
		}

next:
		thisNodePtr = thisNodePtr->NextNode;								// next node
	}
	while (thisNodePtr != nil);

	return(nil);
}


/******************** OGL: DOES SKELETON INTERSECT SPHERE *********************/

static Boolean OGL_DoesSkeletonIntersectSphere(const OGLBoundingSphere *sphere, const ObjNode *theNode)
{
short				i,numTriMeshes;
SkeletonObjDataType	*skeleton = theNode->Skeleton;
Byte				buffNum;

				/* GET SKELETON DATA */

	numTriMeshes = skeleton->skeletonDefinition->numDecomposedTriMeshes;
//	buffNum = skeleton->activeBuffer;
	buffNum = gGameViewInfoPtr->frameCount & 1;

			/***********************************/
			/* CHECK EACH MESH IN THE SKELETON */
			/***********************************/

	for (i = 0; i < numTriMeshes; i++)
	{
		if (OGL_DoesSphereIntersectMesh(sphere, &skeleton->deformedMeshes[buffNum][i]))
			return(true);

	}

	return(false);
}

/******************** OGL: DOES DISPLAY GROUP INTERSECT SPHERE *********************/

static Boolean OGL_DoesDisplayGroupIntersectSphere(const OGLBoundingSphere *sphere, ObjNode *theNode)
{
int	i;

		/* MAKE SURE WE HAVE WORLD-SPACE DATA FOR THIS OBJNODE */

	if (!theNode->HasWorldPoints)
		CalcDisplayGroupWorldPoints(theNode);


			/* SCAN THRU OBJNODE'S WORLD-SPACE DATA FOR A HIT */

	for (i = 0; i < MAX_MESHES_IN_MODEL; i++)
	{
		if (theNode->WorldMeshes[i].points)														// does this mesh exist?
		{
			if (OGL_DoesSphereIntersectMesh(sphere, &theNode->WorldMeshes[i]))					// does the sphere hit this mesh?
				return(true);
		}
	}

	return(false);

}




/******************* OGL:  DOES SPHERE INTERSECT MESH ***************************/
//
// ASSUMES THE MESH IS IN WORLD COORDINATES ALREADY!!!
//

static Boolean	OGL_DoesSphereIntersectMesh(const OGLBoundingSphere *sphere, const MOVertexArrayData *mesh)
{
int			numPoints = mesh->numPoints;
int			p;

			/************************/
			/* SCAN THRU ALL POINTS */
			/************************/

	for (p = 0; p < numPoints; p++)
	{
				/* IS THE POINT IN THE SPHERE? */

		if (OGL_IsPointInSphere(&mesh->points[p], sphere))
			return(true);

	}

	return(false);
}




/*********************** OGL:  DOES SPHERE INTERSECT SPHERE *************************/

static Boolean OGL_DoesSphereIntersectSphere(const OGLBoundingSphere *sphere1, const OGLBoundingSphere *sphere2)
{
float		d2, rd;
OGLVector3D	v;

	v.x = sphere1->origin.x - sphere2->origin.x;					// calc vector between origins
	v.y = sphere1->origin.y - sphere2->origin.y;
	v.z = sphere1->origin.z - sphere2->origin.z;
	d2 = (v.x * v.x) + (v.y * v.y) + (v.z * v.z);					// calculate distance squared between origins

	rd = sphere1->radius + sphere2->radius;							// calc lenght of both radii
	rd *= rd;														// square it

	if (d2 < rd)													// is distance between origins less than sum of radii?
		return(true);

	return(false);
}


/*********************** OGL:  IS POINT IN SPHERE *************************/

static Boolean OGL_IsPointInSphere(const OGLPoint3D *p, const OGLBoundingSphere *sphere)
{
float		r2, d2;
OGLVector3D	v;

	v.x = sphere->origin.x - p->x;					// calc vector between points
	v.y = sphere->origin.y - p->y;
	v.z = sphere->origin.z - p->z;

	d2 = (v.x * v.x) + (v.y * v.y) + (v.z * v.z);	// calculate distance squared

	r2 = sphere->radius * sphere->radius;			// calc radius squared

	if (d2 < r2)
		return(true);

	return(false);
}





























