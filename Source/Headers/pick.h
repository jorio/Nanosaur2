//
// pick.h
//

#ifndef PICK_H
#define PICK_H


#define	GRID_SIZE	1024


			/* EXTERNS */

extern	Boolean	gPickAllTrianglesAsDoubleSided;

//=======================================================


Boolean OGLPoint3D_InsideTriangle3D(const OGLPoint3D *point3D, const OGLPoint3D *trianglePoints, const OGLVector3D	*triangleNormal);

Boolean OGL_DoesLineSegmentIntersectSphere(const OGLLineSegment *lineSeg, const OGLVector3D *segVector,
											 OGLPoint3D *sphereCenter, float sphereRadius, OGLPoint3D *intersectPt);

ObjNode *OGL_DoRayCollision_ObjNodes(OGLRay *ray, uint32_t statusFilter, uint32_t cTypes, OGLPoint3D *worldHitCoord, OGLVector3D *hitNormal);

Boolean OGL_RayGetHitInfo_DisplayGroup(OGLRay *ray, ObjNode *theNode, OGLPoint3D *worldHitCoord, OGLVector3D *hitNormal);
Boolean OGL_IsObjectInFrontOfRay(ObjNode *theNode, OGLRay *ray);

void OGL_GetWorldRayAtScreenPoint(OGLPoint2D *screenCoord, OGLRay *ray);
Boolean	OGL_RayIntersectsTriangle(OGLPoint3D *trianglePoints, OGLRay *ray, OGLPoint3D *intersectPt, OGLVector3D *triangleNormal);

ObjNode *OGL_DoLineSegmentCollision_ObjNodes(const OGLLineSegment *lineSeg, uint32_t statusFilter, uint32_t cTypes,
											 OGLPoint3D *worldHitCoord, OGLVector3D *worldHitFaceNormal, float *distToHit,
											 Boolean allowBBoxTests);

Boolean OGL_DoRayCollision_Terrain(OGLRay *ray, OGLPoint3D *worldHitCoord, OGLVector3D *terrainNormal);
Boolean OGL_LineSegmentCollision_Terrain(const OGLLineSegment *lineSeg, OGLPoint3D *worldHitCoord, OGLVector3D *terrainNormal, float *distToHit);

Boolean OGL_DoesRayIntersectTrianglePlane(const OGLPoint3D	triWorldPoints[], OGLRay *ray, OGLPlaneEquation	*planeEquation);
Boolean OGL_LineSegmentCollision_Fence(const OGLLineSegment *lineSeg, OGLPoint3D *worldHitCoord, OGLVector3D *hitNormal, float *distToHit);
Boolean OGL_LineSegmentCollision_Water(const OGLLineSegment *lineSeg, OGLPoint3D *worldHitCoord, OGLVector3D *hitNormal, float *distToHit);


ObjNode *OGL_DoSphereCollision_ObjNodes(const OGLBoundingSphere *sphere, uint32_t statusFilter, uint32_t cTypes);

#endif