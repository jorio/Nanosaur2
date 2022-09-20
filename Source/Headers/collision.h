//
// collision.h
//

#ifndef COLL_H
#define COLL_H

enum
{
	COLLISION_TYPE_OBJ,						// box
	COLLISION_TYPE_TILE
};




					/* COLLISION STRUCTURES */
struct CollisionRec
{
	Byte			baseBox,targetBox;
	unsigned short	sides;
	Byte			type;
	ObjNode			*objectPtr;			// object that collides with (if object type)
	float			planeIntersectY;	// where intersected triangle
};
typedef struct CollisionRec CollisionRec;



				/* EXTERNS */

extern	short			gNumCollisions;
extern	CollisionRec	gCollisionList[];
extern   Byte			gTotalSides;


//=================================

void CollisionDetect(ObjNode *baseNode, uint32_t CType, short startNumCollisions);

Byte HandleCollisions(ObjNode *theNode, uint32_t cType, float deltaBounce);
extern	Boolean IsPointInPoly2D( float,  float ,  Byte ,  OGLPoint2D *);
extern	Boolean IsPointInTriangle(float pt_x, float pt_y, float x0, float y0, float x1, float y1, float x2, float y2);
short DoSimplePointCollision(OGLPoint3D *thePoint, uint32_t cType, ObjNode *except);
short DoSimpleBoxCollision(float top, float bottom, float left, float right,
						float front, float back, uint32_t cType);



Boolean DoSimplePointCollisionAgainstPlayer(short playerNum, OGLPoint3D *thePoint);
Boolean DoSimpleBoxCollisionAgainstPlayer(short playerNum, float top, float bottom, float left, float right,
										float front, float back);
Boolean DoSimpleBoxCollisionAgainstObject(float top, float bottom, float left, float right,
										float front, float back, ObjNode *targetNode);
float FindHighestCollisionAtXZ(float x, float z, uint32_t cType);



Boolean	HandleLineSegmentCollision(const OGLLineSegment *lineSeg, ObjNode **hitObj, OGLPoint3D *hitPt,
									OGLVector3D *hitNormal, uint32_t *cTypes, Boolean	allowBBoxTests);

Boolean	HandleRayCollision(OGLRay *ray, ObjNode **hitObj, OGLPoint3D *hitPt,OGLVector3D *hitNormal, uint32_t *cTypes);

#endif



